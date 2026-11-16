#!/usr/bin/env python3
"""Median colour of rectangular patches in several PNGs, and the relative difference to the first image.
usage: patch.py "x0,y0,x1,y1;x0,y0,x1,y1;..." ref.png other.png [...]"""
import sys
import numpy as np
from PIL import Image

rects = [tuple(int(v) for v in r.split(",")) for r in sys.argv[1].split(";") if r]
paths = sys.argv[2:]
imgs = [np.asarray(Image.open(p).convert("RGB")).astype(np.float64) for p in paths]
for r in rects:
    x0, y0, x1, y1 = r
    vals = [np.median(im[y0:y1, x0:x1].reshape(-1, 3), axis=0) for im in imgs]
    ref = vals[0]
    line = "patch %-22s" % (str(r),)
    for p, v in zip(paths, vals):
        lum = 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]
        rlum = 0.2126 * ref[0] + 0.7152 * ref[1] + 0.0722 * ref[2]
        line += "  %s %3.0f/%3.0f/%3.0f (%+5.1f%%)" % (p.split("/")[-2][-4:] + "/" + p.split("/")[-1][:10], v[0], v[1], v[2], (lum / max(rlum, 1e-6) - 1) * 100)
    print(line)
