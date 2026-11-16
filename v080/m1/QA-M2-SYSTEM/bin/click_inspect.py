#!/usr/bin/env python3
"""Characterises a click candidate: around time t, the largest sample step and how far it stands above the steps of
the 20 ms around it, the share of energy above 8 kHz in 5 ms before / at / after, and whether the step is a lone
discontinuity (one step far above its neighbours) or the onset of a transient (energy stays up afterwards).
Writes a small waveform PNG (±15 ms). Usage: click_inspect.py <wav> <t> [<t> …]"""
import math
import os
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw


def read(p):
    with wave.open(p, "rb") as w:
        n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
        x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768.0
    return x.reshape(-1, ch), sr


def hf_share(seg, sr):
    if len(seg) < 64:
        return float("nan")
    m = seg.mean(axis=1)
    sp = np.abs(np.fft.rfft(m * np.hanning(len(m)))) ** 2
    f = np.fft.rfftfreq(len(m), 1 / sr)
    return float(sp[f > 8000].sum() / (sp.sum() + 1e-20))


x, sr = read(sys.argv[1])
for ts in sys.argv[2:]:
    t = float(ts)
    a, b = int((t - 0.02) * sr), int((t + 0.03) * sr)
    seg = x[max(0, a):b]
    d = np.abs(np.diff(seg, axis=0)).max(axis=1)
    i = int(np.argmax(d))
    around = np.concatenate([d[max(0, i - 400):max(0, i - 3)], d[i + 3:i + 400]])
    ratio = float(d[i] / (np.percentile(around, 99) + 1e-9))
    c = max(0, a) + i
    w5 = int(0.005 * sr)
    pre, at, post = x[c - 2 * w5:c - w5], x[c - w5 // 2:c + w5 // 2], x[c + w5:c + 2 * w5]
    rms = lambda s: 20 * math.log10(np.sqrt(np.mean(s ** 2)) + 1e-12)
    print("t=%.3f  step %.4f at %.4f s = %.1f × p99 of ±9 ms;  rms pre/at/post %.1f/%.1f/%.1f dB;  HF>8k share pre/at/post %.3f/%.3f/%.3f" % (
        t, d[i], c / sr, ratio, rms(pre), rms(at), rms(post), hf_share(pre, sr), hf_share(at, sr), hf_share(post, sr)))
    # picture
    lo, hi = c - int(0.015 * sr), c + int(0.015 * sr)
    seg = x[lo:hi].mean(axis=1)
    W, H = 900, 200
    im = Image.new("RGB", (W, H), (16, 20, 32))
    dr = ImageDraw.Draw(im)
    pk = max(np.abs(seg).max(), 1e-6)
    pts = [(int(k * (W - 1) / (len(seg) - 1)), int(H / 2 - seg[k] / pk * (H / 2 - 10))) for k in range(len(seg))]
    dr.line(pts, fill=(120, 220, 255), width=1)
    xm = int((c - lo) * (W - 1) / (len(seg) - 1))
    dr.line([(xm, 0), (xm, H)], fill=(255, 80, 80))
    dr.text((6, 4), "%s t=%.3f s  ±15 ms  peak %.3f" % (os.path.basename(sys.argv[1]), c / sr, pk), fill=(255, 255, 255))
    im.save(os.path.splitext(sys.argv[1])[0] + "_click_%.2f.png" % t)
