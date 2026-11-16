#!/usr/bin/env python3
"""File-level measurements of every Modern music / UI file and of the v0.5.0 title theme (reference).
Writes res/files.json. Usage: nice -n 19 python3 measure_files.py <copy root> <out json> [name filter]"""
from __future__ import annotations

import json
import math
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402

SR = alib.SR
BANDS = [("sub_lt40", 0, 40), ("sub_40_60", 40, 60), ("bass_60_120", 60, 120), ("bass_120_250", 120, 250),
         ("lowmid_250_800", 250, 800), ("mid_800_2k", 800, 2000), ("presence_2k_5k", 2000, 5000),
         ("brill_5k_8k", 5000, 8000), ("air_8k_12k", 8000, 12000), ("air_gt12k", 12000, 22050)]
SBANDS = [("lt120", 0, 120), ("120_500", 120, 500), ("500_2k", 500, 2000), ("2k_5k", 2000, 5000),
          ("5k_10k", 5000, 10000), ("gt10k", 10000, 22050)]


def spectral(x: np.ndarray) -> dict:
    f, LL, RR, LR = alib.welch_cross(x)
    tot = LL + RR
    P = float(np.sum(tot))
    out = {"bands_rel_db": {}, "bands_abs_db": {}}
    for name, lo, hi in BANDS:
        p = alib.band_sum(f, tot, lo, hi)
        out["bands_rel_db"][name] = round(alib.pdb(p / P), 2)
        out["bands_abs_db"][name] = round(alib.pdb(p), 2)
    th = alib.thirds(f, tot)
    out["thirds_db"] = [round(alib.pdb(v), 2) for v in th]
    out["tilt_100_10k"] = round(alib.tilt_db_per_oct(np.array(out["thirds_db"]), 100, 10000), 2)
    out["tilt_1k_10k"] = round(alib.tilt_db_per_oct(np.array(out["thirds_db"]), 1000, 10000), 2)
    out["tilt_50_1k"] = round(alib.tilt_db_per_oct(np.array(out["thirds_db"]), 50, 1000), 2)
    st = {}
    for name, lo, hi in SBANDS:
        ll = alib.band_sum(f, LL, lo, hi)
        rr = alib.band_sum(f, RR, lo, hi)
        lr = float(np.real(np.sum(LR[(f >= lo) & (f < hi)])))
        mm = (ll + rr + 2 * lr) / 4.0
        ss = (ll + rr - 2 * lr) / 4.0
        st[name] = {"corr": round(lr / math.sqrt(max(ll * rr, 1e-30)), 3), "side_mid_db": round(alib.pdb(ss / max(mm, 1e-30)), 1),
                    "lr_balance_db": round(alib.pdb(ll / max(rr, 1e-30)), 2)}
    out["stereo"] = st
    ll, rr = float(np.sum(LL)), float(np.sum(RR))
    lr = float(np.real(np.sum(LR)))
    out["corr_all"] = round(lr / math.sqrt(ll * rr), 3)
    return out


def low_corr_over_time(x: np.ndarray, hi: float = 120.0, win_s: float = 0.1) -> dict:
    y = alib.band_filter(x, 20.0, hi)
    w = int(win_s * SR)
    n = len(y) // w
    a = y[:n * w, 0].reshape(n, w)
    b = y[:n * w, 1].reshape(n, w)
    e = np.sqrt(np.mean(a * a, 1) * np.mean(b * b, 1))
    c = np.mean(a * b, 1) / np.maximum(e, 1e-20)
    loud = e > np.max(e) * 1e-3
    c = c[loud]
    return {"corr_min": round(float(np.min(c)), 3), "corr_p1": round(float(np.percentile(c, 1)), 3),
            "share_below_0_5": round(float(np.mean(c < 0.5)), 4), "share_below_0": round(float(np.mean(c < 0.0)), 4)}


def modulation(x: np.ndarray, bpm: float | None) -> dict:
    out = {}
    m = x.mean(axis=1)
    fr = SR / 220.0
    for name, lo, hi in (("low_lt200", 20, 200), ("mid_200_2k", 200, 2000), ("high_2k_8k", 2000, 8000),
                         ("air_gt8k", 8000, 20000), ("full", 20, 20000)):
        env = alib.envelope(alib.band_filter(m, lo, hi) if name != "full" else m)
        d = {"spec": {str(k): round(v, 3) for k, v in alib.mod_spectrum(env, fr).items()}}
        if bpm:
            fb = bpm / 60.0
            d["beat"] = round(alib.modulation_index(env, fr, fb), 3)
            d["eighth"] = round(alib.modulation_index(env, fr, 2 * fb), 3)
            d["sixteenth"] = round(alib.modulation_index(env, fr, 4 * fb), 3)
        out[name] = d
    return out


def hf_transients(x: np.ndarray) -> dict:
    m = x.mean(axis=1)
    h = alib.band_filter(m, 5000.0, 20000.0)
    env = alib.envelope(h, 110)            # 2.5 ms
    edb = 20 * np.log10(env + 1e-12)
    rise = np.diff(edb)
    # onsets: rise > 6 dB within 2.5 ms and above (median - 10 dB)
    thr = np.median(edb) - 10.0
    on = np.where((rise > 6.0) & (edb[1:] > thr))[0]
    if len(on):
        keep = [on[0]]
        for i in on[1:]:
            if i - keep[-1] > 20:      # 50 ms refractory
                keep.append(i)
        on = np.array(keep)
    rms = math.sqrt(float(np.mean(h * h)))
    pk = float(np.max(np.abs(h)))
    return {"onsets_per_s": round(len(on) / (len(m) / SR), 2), "crest_db": round(alib.db(pk / max(rms, 1e-20)), 1),
            "level_dbfs_rms": round(alib.db(rms), 1)}


def loudness(x: np.ndarray, a: int = 0, b: int | None = None) -> dict:
    L = alib.Loud(x[a:b])
    st = L.short_term()
    stg = st[st > -70]
    mo = L.momentary()
    xi = x[a:b]
    rms_c = [math.sqrt(float(np.mean(xi[:, c] ** 2))) for c in range(2)]
    pk_c = [float(np.max(np.abs(xi[:, c]))) for c in range(2)]
    # PSR: per 3 s window (hop 1 s) the sample peak over the short-term loudness
    w, h = 3 * SR, SR
    psr = []
    for s in range(0, max(len(xi) - w, 1), h):
        seg = xi[s:s + w]
        lv = alib._L(np.mean(L.p[s:s + w]))
        psr.append(alib.db(float(np.max(np.abs(seg)))) - float(lv))
    i = L.integrated()
    tp = alib.true_peak_db(xi)
    return {"lufs_i": round(i, 2), "st_max": round(float(np.max(st)), 2), "st_p95": round(float(np.percentile(stg, 95)), 2),
            "st_p50": round(float(np.percentile(stg, 50)), 2), "st_p10": round(float(np.percentile(stg, 10)), 2),
            "st_min": round(float(np.min(stg)), 2), "mom_max": round(float(np.max(mo)), 2), "lra": round(L.lra(), 2),
            "tp": round(tp, 2), "plr": round(tp - i, 2), "crest_db": [round(alib.db(pk_c[c] / rms_c[c]), 2) for c in range(2)],
            "rms_dbfs": [round(alib.db(v), 2) for v in rms_c], "psr_median": round(float(np.median(psr)), 2),
            "psr_p10": round(float(np.percentile(psr, 10)), 2)}


def bar_similarity(x: np.ndarray, start: int, n_bars: int, bar_frames: float) -> dict:
    m = x.mean(axis=1)
    feats = []
    for k in range(n_bars):
        a = int(start + k * bar_frames)
        b = int(start + (k + 1) * bar_frames)
        seg = m[a:b]
        ch = alib.chroma_bar(seg)
        X = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
        f = np.fft.rfftfreq(len(seg), 1.0 / SR)
        be = np.array([np.sum(X[(f >= lo) & (f < hi)]) for _n, lo, hi in BANDS])
        be = np.log10(be + 1e-12)
        be = (be - be.mean())
        feats.append(np.concatenate([ch, 0.15 * be / (np.linalg.norm(be) + 1e-12)]))
    F = np.array(feats)
    F = F / np.linalg.norm(F, axis=1, keepdims=True)
    S = F @ F.T
    np.fill_diagonal(S, -1)
    mx = S.max(axis=1)
    return {"bars": n_bars, "share_near_repeat_0_98": round(float(np.mean(mx >= 0.98)), 3),
            "share_near_repeat_0_95": round(float(np.mean(mx >= 0.95)), 3), "median_best_match": round(float(np.median(mx)), 3)}


def main() -> int:
    root, out = sys.argv[1], sys.argv[2]
    filt = sys.argv[3] if len(sys.argv) > 3 else ""
    man = json.load(open(os.path.join(root, "assets/audio/modern/music/manifest.json")))["sounds"]
    uman = json.load(open(os.path.join(root, "assets/audio/modern/ui/manifest.json")))["sounds"]
    items = []
    items.append(("REF_title_v050", os.path.join(root, "assets/audio/music/title_theme.ogg"), {"role": "reference", "bpm": 128.0}))
    for k, v in sorted(man.items()):
        if v.get("placeholder"):
            continue
        items.append((k, os.path.join(root, "assets/audio/modern/music", v["file"]), v))
    for k, v in sorted(uman.items()):
        if v.get("placeholder"):
            continue
        for fn in (v.get("files") or [v["file"]]):
            items.append(("ui:" + os.path.splitext(fn)[0], os.path.join(root, "assets/audio/modern/ui", fn), v))
    res = {}
    if os.path.exists(out):
        res = json.load(open(out))
    for name, path, meta in items:
        if filt and filt not in name:
            continue
        t0 = time.time()
        x = alib.read_audio(path)
        r = {"file": os.path.relpath(path, root), "role": meta.get("role"), "bpm": meta.get("bpm"), "dur_s": round(len(x) / SR, 2),
             "manifest_lufs": meta.get("lufs"), "manifest_tp": meta.get("true_peak_db")}
        r["all"] = loudness(x)
        r["all"].update(spectral(x))
        lp = meta.get("loop")
        bpm = meta.get("bpm")
        if name == "REF_title_v050":
            lp = None
        if lp and lp[1] > lp[0] + SR:
            a, b = int(lp[0]), int(lp[1])
            r["loop_s"] = round((b - a) / SR, 2)
            r["intro_s"] = round(a / SR, 2)
            r["loop"] = loudness(x, a, b)
            r["loop"].update(spectral(x[a:b]))
            r["intro"] = loudness(x, 0, a) if a > 3 * SR else {}
            bar = 4 * 60.0 / bpm * SR
            r["bar_s"] = round(bar / SR, 4)
            nb = int(round((b - a) / bar))
            r["loop"]["selfsim"] = bar_similarity(x, a, nb, bar)
            if meta.get("countin_beats"):
                cb = int(meta["countin_beats"]) // 4
                r["countin"] = loudness(x, 0, int(cb * bar)) if cb * bar > 0.5 * SR else {}
                r["a1"] = loudness(x, int(cb * bar), int((cb + 8) * bar))
            seg = x[a:b]
        else:
            seg = x
        if len(seg) > 10 * SR:
            r["lowcorr"] = low_corr_over_time(seg)
            r["mod"] = modulation(seg, bpm)
        r["hf"] = hf_transients(seg)
        r["mono_loss_db"] = round(alib.integrated_lufs(np.repeat(seg.mean(axis=1, keepdims=True), 2, axis=1)) -
                                  alib.integrated_lufs(seg), 2) if len(seg) > SR else None
        r["seconds"] = round(time.time() - t0, 1)
        res[name] = r
        print(f"{name:32s} {r['all']['lufs_i']:7.2f} LUFS (man {meta.get('lufs')}) TP {r['all']['tp']:6.2f} "
              f"LRA {r['all']['lra']:5.2f} tilt {r['all']['tilt_100_10k']:6.2f}  {r['seconds']} s", flush=True)
        with open(out, "w") as fh:
            json.dump(res, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
