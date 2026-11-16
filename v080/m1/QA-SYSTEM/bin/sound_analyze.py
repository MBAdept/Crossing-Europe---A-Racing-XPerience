#!/usr/bin/env python3
"""QA-SYSTEM: analysis of capture_mix.gd recordings.
For every WAV: dropouts (runs of digital silence inside sound), click candidates (blocks whose sample-to-sample
jump stands far above their neighbourhood), stereo balance and correlation, and a spectrogram PNG
(Arcade row above Modern row per car when both exist). Numbers are measured on the files; audibility is inferred.
Usage: sound_analyze.py <dir> <out_dir>
"""
import json
import os
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw


def read_wav(p):
    with wave.open(p, "rb") as w:
        n, ch, rate = w.getnframes(), w.getnchannels(), w.getframerate()
        x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768.0
    return x.reshape(-1, ch), rate


def dropouts(x, rate):
    mono = np.abs(x).max(axis=1)
    silent = mono < 1.0 / 32768.0
    runs = []
    i = 0
    n = len(silent)
    min_len = int(0.002 * rate)
    while i < n:
        if silent[i]:
            j = i
            while j < n and silent[j]:
                j += 1
            if j - i >= min_len and i > rate // 2 and j < n - rate // 2:
                pre = np.sqrt(np.mean(x[max(0, i - rate // 20):i] ** 2))
                post = np.sqrt(np.mean(x[j:j + rate // 20] ** 2))
                if pre > 1e-3 and post > 1e-3:
                    runs.append((i / rate, (j - i) / rate * 1000.0))
            i = j
        else:
            i += 1
    return runs


def clicks(x, rate):
    d = np.abs(np.diff(x, axis=0)).max(axis=1)
    blk = int(0.01 * rate)
    nb = len(d) // blk
    if nb < 60:
        return []
    m = d[: nb * blk].reshape(nb, blk).max(axis=1)
    out = []
    half = 25
    for b in range(max(half, int(2.0 * rate / blk)), nb - half):   # skip the start clip (first 2 s)
        neigh = np.concatenate([m[b - half:b - 1], m[b + 2:b + half]])
        ref = np.median(neigh)
        if m[b] > 0.05 and m[b] > 4.0 * max(ref, 1e-4):
            out.append((b * blk / rate, float(m[b]), float(ref)))
    return out


def spectrogram(x, rate, fmin=30.0, fmax=12000.0, width=900, height=220):
    """Log-frequency spectrogram (30 Hz .. 12 kHz), amplitude in dBFS of a sine, -96 .. -12 dB mapped dark -> bright."""
    mono = x.mean(axis=1)
    win = 4096
    hop = max(256, (len(mono) - win) // width)
    frames = max(1, (len(mono) - win) // hop)
    w = np.hanning(win)
    norm = w.sum() / 2.0
    freqs = np.fft.rfftfreq(win, 1.0 / rate)
    rows = np.geomspace(fmin, fmax, height)
    cols = np.empty((frames, height), dtype=np.float32)
    for i in range(frames):
        seg = mono[i * hop:i * hop + win] * w
        mag = np.abs(np.fft.rfft(seg)) / norm
        cols[i] = np.interp(rows, freqs, mag)
    s = 20 * np.log10(cols + 1e-9)
    s = np.clip((s + 96.0) / 84.0, 0.0, 1.0)
    img = (s.T[::-1] * 255).astype(np.uint8)
    im = Image.fromarray(img).resize((width, height), Image.BILINEAR)
    a = np.asarray(im).astype(np.float32) / 255.0
    # colour map: black -> blue -> magenta -> orange -> yellow
    r = np.clip(a * 2.0 - 0.6, 0, 1)
    g = np.clip(a * 2.2 - 1.2, 0, 1)
    b = np.clip(np.where(a < 0.5, a * 1.8, 1.8 - a * 1.8), 0, 1)
    return Image.fromarray((np.stack([r, g, b], axis=2) * 255).astype(np.uint8))


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    rows = {}
    report = {}
    for f in sorted(os.listdir(src)):
        if not f.endswith(".wav"):
            continue
        name = f[:-4]
        x, rate = read_wav(os.path.join(src, f))
        dur = len(x) / rate
        drop = dropouts(x, rate)
        clk = clicks(x, rate)
        l, r = x[:, 0], x[:, 1] if x.shape[1] > 1 else x[:, 0]
        rms_l = 20 * np.log10(np.sqrt(np.mean(l ** 2)) + 1e-9)
        rms_r = 20 * np.log10(np.sqrt(np.mean(r ** 2)) + 1e-9)
        corr = float(np.corrcoef(l, r)[0, 1]) if np.std(l) > 0 and np.std(r) > 0 else 1.0
        peak = 20 * np.log10(np.abs(x).max() + 1e-9)
        meta = {}
        jp = os.path.join(src, name + ".json")
        if os.path.exists(jp):
            meta = json.load(open(jp))
        report[name] = {"seconds": round(dur, 2), "dropouts": [(round(float(t), 3), round(float(ms), 1)) for t, ms in drop],
                        "click_candidates": [(round(t, 3), round(v, 3), round(rf, 4)) for t, v, rf in clk[:20]],
                        "n_clicks": len(clk), "rms_l_db": round(float(rms_l), 2), "rms_r_db": round(float(rms_r), 2),
                        "lr_corr": round(corr, 3), "peak_dbfs": round(float(peak), 2),
                        "phases": meta.get("phases", [])}
        print("%-32s %6.1f s  dropouts %3d  click-cand %3d  L/R %6.2f/%6.2f dB  corr %.3f  peak %.2f dBFS" % (
            name, dur, len(drop), len(clk), rms_l, rms_r, corr, peak))
        sp = spectrogram(x, rate)
        d = ImageDraw.Draw(sp)
        d.text((6, 4), name, fill=(255, 255, 255))
        for fq, lab in ((100.0, "100 Hz"), (1000.0, "1 kHz"), (10000.0, "10 kHz")):
            yy = int(sp.height - 1 - np.log(fq / 30.0) / np.log(12000.0 / 30.0) * (sp.height - 1))
            d.line([(0, yy), (12, yy)], fill=(200, 200, 200), width=1)
            d.text((14, yy - 6), lab, fill=(200, 200, 200))
        for ph in meta.get("phases", []):
            xp = int(ph["t0"] / dur * sp.width)
            d.line([(xp, 0), (xp, sp.height)], fill=(255, 255, 255), width=1)
            d.text((xp + 3, sp.height - 14), str(ph["name"]), fill=(255, 255, 255))
        sp.save(os.path.join(out, name + "_spec.png"))
        rows[name] = sp
    # sheets: per car arcade over modern
    cars = sorted({n.split("_drive_")[1] for n in rows if "_drive_" in n})
    if cars:
        tiles = []
        for c in cars:
            for prof in ("arcade", "modern"):
                k = "%s_drive_%s" % (prof, c)
                if k in rows:
                    tiles.append(rows[k])
        h = sum(t.height + 4 for t in tiles)
        sheet = Image.new("RGB", (900, h), (0, 0, 0))
        y = 0
        for t in tiles:
            sheet.paste(t, (0, y))
            y += t.height + 4
        sheet.save(os.path.join(out, "spektrogramme_motor.png"))
    json.dump(report, open(os.path.join(out, "sound_report.json"), "w"), indent=1)


main()
