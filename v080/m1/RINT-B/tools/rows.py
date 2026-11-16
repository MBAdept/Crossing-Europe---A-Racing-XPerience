#!/usr/bin/env python3
"""Print median colour per row for a column range of one or more PNGs (horizon analysis).
usage: rows.py y0 y1 x0 x1 a.png [b.png ...]"""
import sys
import numpy as np
from PIL import Image

y0, y1, x0, x1 = (int(v) for v in sys.argv[1:5])
imgs = [np.asarray(Image.open(p).convert("RGB")).astype(np.int32) for p in sys.argv[5:]]
print("row  " + "   ".join("%-14s" % p.split("/")[-1][:14] for p in sys.argv[5:]))
for y in range(y0, y1 + 1):
    cells = []
    for im in imgs:
        seg = im[y, x0:x1]
        m = np.median(seg, axis=0)
        cells.append("%3d %3d %3d     " % tuple(m))
    print("%3d  %s" % (y, "".join(cells)))
