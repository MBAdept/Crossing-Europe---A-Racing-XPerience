#!/usr/bin/env python3
"""RINT-M2: difference of two pictures – changed pixels (> thr per channel) overall and in boxes; mean luminance in boxes.
usage: imgdiff.py a.png b.png [thr] [x0,y0,x1,y1 ...]"""
import sys

import numpy as np
from PIL import Image

a = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(int)
b = np.asarray(Image.open(sys.argv[2]).convert("RGB")).astype(int)
thr = int(sys.argv[3]) if len(sys.argv) > 3 and "," not in sys.argv[3] else 2
boxes = [s for s in sys.argv[3:] if "," in s]
d = np.abs(a - b).max(axis=2)
ys, xs = np.nonzero(d > thr)
print("changed > %d: %d px (max %d)" % (thr, len(ys), d.max()), "bbox", (xs.min(), ys.min(), xs.max(), ys.max()) if len(ys) else "-")
for bx in boxes:
    x0, y0, x1, y1 = (int(v) for v in bx.split(","))
    la = (0.2126 * a[y0:y1, x0:x1, 0] + 0.7152 * a[y0:y1, x0:x1, 1] + 0.0722 * a[y0:y1, x0:x1, 2]).mean()
    lb = (0.2126 * b[y0:y1, x0:x1, 0] + 0.7152 * b[y0:y1, x0:x1, 1] + 0.0722 * b[y0:y1, x0:x1, 2]).mean()
    print("box %s: changed %d px, mean L %.1f -> %.1f" % (bx, int((d[y0:y1, x0:x1] > thr).sum()), la, lb))
