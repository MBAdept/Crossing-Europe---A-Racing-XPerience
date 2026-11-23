#!/usr/bin/env python3
"""QA-R7c: frame-to-frame change of a clip's Modern half (scenery band, HUD excluded) and the peaks against the median of
+-5 neighbouring frames. Usage: clippeaks.py <frames dir> <x0> <x1> <y0> <y1> [thr=40] [top=8]"""
import sys, glob
import numpy as np
from PIL import Image

d = sys.argv[1]
x0, x1, y0, y1 = (int(v) for v in sys.argv[2:6])
thr = int(sys.argv[6]) if len(sys.argv) > 6 else 40
top = int(sys.argv[7]) if len(sys.argv) > 7 else 8
files = sorted(glob.glob(d + "/f_*.png"))
prev = None
ch = []
for f in files:
    a = np.asarray(Image.open(f).convert("L"), dtype=np.int16)[y0:y1, x0:x1]
    if prev is not None:
        ch.append(float((np.abs(a - prev) > thr).mean() * 100.0))
    else:
        ch.append(0.0)
    prev = a
ch = np.array(ch)
peaks = []
for i in range(1, len(ch)):
    lo, hi = max(1, i - 5), min(len(ch), i + 6)
    nb = np.concatenate([ch[lo:i], ch[i + 1:hi]])
    peaks.append((ch[i] - float(np.median(nb)), i, ch[i]))
peaks.sort(reverse=True)
print("frames %d  change median %.1f %%  p95 %.1f %%" % (len(ch), float(np.median(ch[1:])), float(np.percentile(ch[1:], 95))))
for p, i, c in peaks[:top]:
    print("peak frame %d (%s): change %.1f %%, +%.1f %% over neighbours" % (i, files[i].split("/")[-1], c, p))
