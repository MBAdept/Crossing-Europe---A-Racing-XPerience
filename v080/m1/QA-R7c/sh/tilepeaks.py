#!/usr/bin/env python3
"""QA-R7c: per-tile frame-to-frame change of a clip region; a level switch shows as a one-frame spike in one tile while
motion changes smoothly. Prints the tiles x frames with the largest spike over the median of the +-3 neighbouring frames.
Usage: tilepeaks.py <frames dir> <x0> <x1> <y0> <y1> <tile px> [thr=40] [top=12]"""
import sys, glob
import numpy as np
from PIL import Image

d = sys.argv[1]
x0, x1, y0, y1, t = (int(v) for v in sys.argv[2:7])
thr = int(sys.argv[7]) if len(sys.argv) > 7 else 40
top = int(sys.argv[8]) if len(sys.argv) > 8 else 12
files = sorted(glob.glob(d + "/f_*.png"))
ny, nx = (y1 - y0) // t, (x1 - x0) // t
prev = None
series = []
for f in files:
    a = np.asarray(Image.open(f).convert("L"), dtype=np.int16)[y0:y0 + ny * t, x0:x0 + nx * t]
    if prev is None:
        series.append(np.zeros((ny, nx)))
    else:
        m = (np.abs(a - prev) > thr).reshape(ny, t, nx, t).mean(axis=(1, 3)) * 100.0
        series.append(m)
    prev = a
s = np.stack(series)  # frames x ny x nx
res = []
for i in range(2, len(s)):
    lo, hi = max(1, i - 3), min(len(s), i + 4)
    nb = np.concatenate([s[lo:i], s[i + 1:hi]])
    med = np.median(nb, axis=0)
    spike = s[i] - med
    k = np.unravel_index(np.argmax(spike), spike.shape)
    res.append((float(spike[k]), i, int(k[0]), int(k[1]), float(s[i][k])))
res.sort(reverse=True)
allsp = np.array([r[0] for r in res])
print("frames %d tiles %dx%d of %d px: spike p50 %.1f p95 %.1f p99 %.1f max %.1f (%% of tile pixels)" % (
    len(s), nx, ny, t, np.percentile(allsp, 50), np.percentile(allsp, 95), np.percentile(allsp, 99), allsp.max()))
for sp, i, ty, tx, c in res[:top]:
    print("frame %d (%s) tile x %d y %d (px %d,%d): change %.1f %%, spike +%.1f" % (i, files[i].split('/')[-1], tx, ty, x0 + tx * t, y0 + ty * t, c, sp))
