#!/usr/bin/env python3
"""KRITIK-R2-MESS: diagnostic picture (own inspection only): band levels over time of an audio file with marks.
usage: plot_levels.py <audio> <t0> <t1> <out.png> [mark=label ...]"""
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SR = 44100
BANDS = [(60, 250, "#2a78d6"), (250, 1000, "#1baf7a"), (1000, 2500, "#eda100"), (2500, 8000, "#e34948")]


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)


def band(m, lo, hi):
    n = len(m)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    h = 1.0 / np.sqrt(1.0 + (lo / f) ** 8) / np.sqrt(1.0 + (f / hi) ** 8)
    return np.fft.irfft(np.fft.rfft(m) * h, n)


def main():
    path, t0, t1, out = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
    marks = [a.split("=", 1) for a in sys.argv[5:]]
    x = decode(path)
    m = x[int(t0 * SR):int(t1 * SR)].mean(axis=1)
    W, H, L, R, T, B = 1600, 700, 70, 20, 30, 60
    img = Image.new("RGB", (W, H), "#fcfcfb")
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    ymin, ymax = -80.0, -10.0

    def px(t):
        return L + (t - t0) / (t1 - t0) * (W - L - R)

    def py(v):
        return T + (ymax - v) / (ymax - ymin) * (H - T - B)

    for v in range(int(ymin), int(ymax) + 1, 10):
        d.line([(L, py(v)), (W - R, py(v))], fill="#e1e0d9")
        d.text((5, py(v) - 7), f"{v}", fill="#52514e", font=font)
    step = 1.0 if t1 - t0 <= 30 else 2.0
    t = np.ceil(t0)
    while t <= t1:
        d.line([(px(t), T), (px(t), H - B)], fill="#e1e0d9")
        d.text((px(t) - 10, H - B + 5), f"{t:.0f}", fill="#52514e", font=font)
        t += step
    k = int(0.02 * SR)
    for lo, hi, col in BANDS:
        y = band(m, lo, hi)
        n = len(y) // k
        e = 20 * np.log10(np.sqrt(np.mean(y[:n * k].reshape(n, k) ** 2, axis=1)) + 1e-9)
        pts = [(px(t0 + i * 0.02), py(float(np.clip(v, ymin, ymax)))) for i, v in enumerate(e)]
        d.line(pts, fill=col, width=1)
    for i, (tm, lab) in enumerate(marks):
        tt = float(tm)
        d.line([(px(tt), T), (px(tt), H - B)], fill="#0b0b0b", width=1)
        d.text((px(tt) + 3, T + 2 + 14 * (i % 4)), lab, fill="#0b0b0b", font=font)
    for j, (lo, hi, col) in enumerate(BANDS):
        d.text((L + 10 + 160 * j, H - 25), f"{lo}-{hi} Hz", fill=col, font=font)
    img.save(out)


if __name__ == "__main__":
    main()
