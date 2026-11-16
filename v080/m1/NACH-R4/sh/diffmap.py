#!/usr/bin/env python3
"""diffmap.py a.png b.png out.png – per-pixel max channel difference; prints stats per horizontal band and saves an amplified map"""
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.int16)
b = np.asarray(Image.open(sys.argv[2]).convert("RGB"), dtype=np.int16)
d = np.abs(a - b).max(axis=2)
print("changed px (>2): %d of %d; >8: %d; max %d" % (int((d > 2).sum()), d.size, int((d > 8).sum()), int(d.max())))
h = d.shape[0]
for y0 in range(0, h, 90):
    band = d[y0:y0 + 90]
    print("  rows %3d-%3d: >2 %6d  >8 %6d  mean %.2f" % (y0, y0 + 89, int((band > 2).sum()), int((band > 8).sum()), float(band.mean())))
Image.fromarray(np.clip(d * 8, 0, 255).astype(np.uint8)).save(sys.argv[3])
