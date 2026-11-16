"""Scratch analysis helpers of AU-B (not part of the repo): numbers and pictures of offline engine renders."""
from __future__ import annotations
import json, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
STUDY = os.path.abspath(os.path.join(HERE, "..", "..", "..", "audio", "src"))
REPO = os.environ.get("CE_REPO", "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2")
sys.dont_write_bytecode = True
sys.path.insert(0, STUDY)
sys.path.insert(0, os.path.join(REPO, "tools", "audio", "qc"))
import alib  # noqa: E402
import qc_lib  # noqa: E402


def read(path: str):
    x, sr = qc_lib.read_wav(path)
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    tr = {}
    if os.path.exists(path + ".json"):
        tr = json.load(open(path + ".json", encoding="utf-8"))
    return x, sr, tr


def kpow(x, sr):
    xk = qc_lib.k_weight(x, sr)
    return np.mean(xk * xk, axis=0)


def lufs(x, sr) -> float:
    p = kpow(x, sr)
    return float(-0.691 + 10.0 * np.log10(max(float(np.sum(p)), 1e-20)))


def balance_db(x, sr) -> float:
    """K-weighted level right minus left (dB)."""
    p = kpow(x, sr)
    return float(10.0 * np.log10(max(p[1], 1e-20) / max(p[0], 1e-20)))


def mono_drop_db(x, sr) -> float:
    """Level of the mono sum (L + R) / 2 relative to the louder channel (dB, K-weighted)."""
    p = kpow(x, sr)
    m = (x[:, 0] + x[:, 1]) * 0.5
    pm = kpow(np.stack([m, m], axis=1), sr)[0]
    return float(10.0 * np.log10(max(pm, 1e-20) / max(float(np.max(p)), 1e-20)))


def corr(x) -> float:
    a, b = x[:, 0], x[:, 1]
    d = math.sqrt(float(np.mean(a * a)) * float(np.mean(b * b)))
    return float(np.mean(a * b) / d) if d > 0 else 1.0


def spectrum(x, sr, nfft=8192):
    m = x.mean(axis=1) if x.ndim == 2 else x
    hop = nfft // 2
    w = np.hanning(nfft)
    acc = np.zeros(nfft // 2 + 1)
    n = 0
    for a in range(0, max(len(m) - nfft, 1), hop):
        seg = m[a:a + nfft]
        if len(seg) < nfft:
            break
        acc += np.abs(np.fft.rfft(seg * w)) ** 2
        n += 1
    return np.fft.rfftfreq(nfft, 1.0 / sr), acc / max(n, 1)


def centroid_hz(x, sr) -> float:
    f, p = spectrum(x, sr)
    sel = f >= 20.0
    return float(np.sum(f[sel] * p[sel]) / max(float(np.sum(p[sel])), 1e-30))


def share_db(x, sr, lo, hi) -> float:
    f, p = spectrum(x, sr)
    return float(10.0 * np.log10(max(float(np.sum(p[(f >= lo) & (f < hi)])) / max(float(np.sum(p)), 1e-30), 1e-12)))


def hnr_db(x, sr, rpm: float, cyl: int, nfft=32768) -> float:
    """Harmonic-to-noise ratio: power in narrow bands around the multiples of the half engine order (the cycle
    frequency rpm / 120) against the rest, 30 Hz .. 6 kHz. Harmonic bands are +-(0.2 x cycle frequency)."""
    m = x.mean(axis=1) if x.ndim == 2 else x
    f, p = spectrum(m, sr, nfft)
    f0 = rpm / 120.0
    sel = (f >= 30.0) & (f <= 6000.0)
    k = np.round(f / f0)
    near = np.abs(f - k * f0) <= 0.2 * f0
    harm = float(np.sum(p[sel & near]))
    noise = float(np.sum(p[sel & ~near]))
    # scale the noise to the full bandwidth (it is only seen in 60 % of it)
    noise = noise / 0.6
    harm = max(harm - noise * 0.4, 1e-30)
    return float(10.0 * np.log10(harm / max(noise, 1e-30)))


def modulation_db(x, sr, win_s=0.05) -> dict:
    """Level movement of a steady passage: std and p95-p5 of the 50-ms K-weighted level (dB)."""
    xk = qc_lib.k_weight(x, sr)
    n = int(win_s * sr)
    lv = []
    for a in range(0, len(xk) - n, n):
        lv.append(10.0 * math.log10(max(float(np.mean(np.sum(xk[a:a + n] ** 2, axis=1))), 1e-20)))
    lv = np.array(lv)
    return {"std": float(np.std(lv)), "range": float(np.percentile(lv, 95) - np.percentile(lv, 5))}


def band_levels(x, sr, win_s=0.25):
    """1/3-octave levels over time (for tonal-fatigue checks): returns centre freqs, (frames, bands) dB."""
    m = x.mean(axis=1)
    n = int(win_s * sr)
    fc = 1000.0 * 2.0 ** (np.arange(-15, 12) / 3.0)
    fc = fc[(fc > 30) & (fc < sr * 0.45)]
    out = []
    w = np.hanning(n)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    for a in range(0, len(m) - n, n // 2):
        p = np.abs(np.fft.rfft(m[a:a + n] * w)) ** 2
        out.append([10.0 * math.log10(max(float(np.sum(p[(f >= c / 2 ** (1 / 6)) & (f < c * 2 ** (1 / 6))])), 1e-20)) for c in fc])
    return fc, np.array(out)


def clicks(x, sr, near_s=0.1, guard=6):
    """Isolated discontinuities: second difference against the 99.9th percentile of its neighbourhood (+-near_s,
    without +-guard samples). Returns (max ratio, list of (time, ratio) with ratio > 4)."""
    worst = 0.0
    hits = []
    for c in range(x.shape[1]):
        e = np.abs(np.diff(x[:, c], 2))
        n = int(near_s * sr)
        # coarse: block maxima, then check candidates
        idx = np.argsort(e)[-200:]
        for i in idx:
            a, b = max(i - n, 0), min(i + n, len(e))
            nb = np.concatenate([e[a:max(i - guard, a)], e[min(i + guard, b):b]])
            if len(nb) < 100:
                continue
            ref = float(np.percentile(nb, 99.9))
            r = float(e[i]) / max(ref, 1e-6)
            if r > worst:
                worst = r
            if r > 4.0:
                hits.append((round(i / sr, 4), round(r, 1), c))
    return worst, sorted(set(hits))


def phase_table(path: str, phases=None) -> list:
    x, sr, tr = read(path)
    rows = []
    for ph in (phases or tr.get("phases", [])):
        a, b = int(ph["t0"] * sr), min(int(ph["t1"] * sr), len(x))
        seg = x[a:b]
        if len(seg) < sr // 4:
            continue
        rows.append({"name": ph["name"], "t0": ph["t0"], "t1": ph["t1"], "lufs": lufs(seg, sr), "peak": float(np.max(np.abs(seg))),
                     "bal": balance_db(seg, sr), "corr": corr(seg), "mono": mono_drop_db(seg, sr), "centroid": centroid_hz(seg, sr),
                     "hf2k": share_db(seg, sr, 2000, 16000), "hf5k": share_db(seg, sr, 5000, 16000), "lf60": share_db(seg, sr, 0, 60),
                     "mod": modulation_db(seg, sr)["std"]})
    return rows


def print_table(path: str) -> None:
    x, sr, tr = read(path)
    print("%s  (%s %s, %.1f s, gesamt %.1f LUFS, Spitze %.3f)" % (os.path.basename(path), tr.get("car", "?"), tr.get("profile", "?"),
                                                                 len(x) / sr, qc_lib.integrated_lufs(x, sr), float(np.max(np.abs(x)))))
    print("  Phase         t0     t1    LUFS   Spitze  R-L dB  Korr  Mono dB  Schwerp.  >2k    >5k   <60   Mod dB")
    for r in phase_table(path):
        print("  %-11s %5.1f  %5.1f  %6.1f  %5.3f  %+5.2f  %5.2f  %6.2f  %7.0f  %5.1f  %5.1f %5.1f  %5.2f" % (
            r["name"], r["t0"], r["t1"], r["lufs"], r["peak"], r["bal"], r["corr"], r["mono"], r["centroid"], r["hf2k"], r["hf5k"], r["lf60"], r["mod"]))
    w, hits = clicks(x, sr)
    print("  Knack-Kennzahl (2. Differenz / 99,9-Perzentil der Umgebung): max %.1f; über 4: %s" % (w, hits[:12]))


def spectro(paths: list, labels: list, out: str, title: str = "", fmax: float = 16000.0, dyn: float = 80.0) -> None:
    items = []
    ref = None
    for p, lab in zip(paths, labels):
        x, sr, _ = read(p)
        im, ref = alib.spectrogram_img(x, sr, w=1500, h=380, fmin=30.0, fmax=fmax, dyn_db=dyn, ref_db=ref)
        items.append((lab, im))
    alib.stack_images(items, out, title)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print_table(p)
