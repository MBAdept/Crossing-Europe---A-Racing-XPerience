#!/usr/bin/env python3
"""KRITIK-R2-MESS: the marks of a preview's .txt against what is audible. Novelty of the spectrum (24 Bark bands,
20-ms frames, log energy; distance between the mean of 0.4 s after and 0.4 s before each frame, in dB RMS over the
bands, optionally only a band range) – for every mark the strongest novelty peak within +-win s and its offset.
Joints: transients of the 2.5-8 kHz envelope (5 ms) >= 8 dB above the median of the 200 ms before.
usage: ana_marks.py <file.mp3> <out.json> [--bands=lo-hi] mark_s=label ..."""
import json
import subprocess
import sys

import numpy as np

SR = 44100
EDGES = [20, 100, 200, 300, 400, 510, 630, 770, 920, 1080, 1270, 1480, 1720, 2000, 2320, 2700, 3150, 3700, 4400, 5300,
         6400, 7700, 9500, 12000, 15500]


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)


def bark_frames(m, frame_s=0.02, nfft=2048):
    hop = int(frame_s * SR)
    w = np.hanning(nfft)
    f = np.fft.rfftfreq(nfft, 1.0 / SR)
    idx = [((f >= lo) & (f < hi)) for lo, hi in zip(EDGES[:-1], EDGES[1:])]
    out = []
    for i in range(0, len(m) - nfft, hop):
        s = np.abs(np.fft.rfft(m[i:i + nfft] * w)) ** 2
        out.append([10 * np.log10(float(s[ix].sum()) + 1e-12) for ix in idx])
    return np.array(out), hop / SR, nfft / 2 / SR


def novelty(B, half):
    n = len(B)
    nov = np.zeros(n)
    for i in range(half, n - half):
        a = B[i - half:i].mean(axis=0)
        b = B[i:i + half].mean(axis=0)
        nov[i] = float(np.sqrt(np.mean((b - a) ** 2)))
    return nov


def main():
    path, out = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]
    blo, bhi = 0, len(EDGES) - 1
    win = 1.5
    marks = []
    for a in args:
        if a.startswith("--bands="):
            lo, hi = a.split("=", 1)[1].split("-")
            blo = max(i for i, e in enumerate(EDGES) if e <= float(lo))
            bhi = min(i for i, e in enumerate(EDGES) if e >= float(hi))
        elif a.startswith("--win="):
            win = float(a.split("=", 1)[1])
        else:
            t, lab = a.split("=", 1)
            marks.append((float(t), lab))
    x = decode(path)
    m = x.mean(axis=1)
    B, fs, off = bark_frames(m)
    B = B[:, blo:bhi]
    half = int(0.4 / fs)
    nov = novelty(B, half)
    res = {"file": path, "len_s": len(x) / SR, "marks": []}
    for t, lab in marks:
        i0, i1 = int((t - win) / fs), int((t + win) / fs)
        i0, i1 = max(i0, half), min(i1, len(nov) - half)
        seg = nov[i0:i1]
        j = int(np.argmax(seg))
        tm = (i0 + j) * fs + off
        # second strongest peak elsewhere in the window (ambiguity)
        mask = np.ones(len(seg), bool)
        mask[max(0, j - half):j + half] = False
        second = float(seg[mask].max()) if mask.any() else 0.0
        res["marks"].append({"label": lab, "txt_s": t, "audible_s": round(tm, 2), "diff_s": round(tm - t, 2),
                             "novelty_db": round(float(seg[j]), 1), "second_db": round(second, 1)})
        print(f"  {lab:28s} Text {t:7.2f} s  hörbar {tm:7.2f} s  ({tm - t:+.2f} s)  Neuheit {seg[j]:4.1f} dB (zweite {second:4.1f})")
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
