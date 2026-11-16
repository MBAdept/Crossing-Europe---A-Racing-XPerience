#!/usr/bin/env python3
"""Bounding box of the blue player car paint in the lower middle of a frame (QA-WASSER).

usage: carbox.py <frame.png>...   prints x0 x1 y0 y1, width, height and pixel count of the paint mask
(region x 320..960, y 360..H; paint = clearly blue: B > 110, B > R + 55, B > G + 25).
"""
import sys

import numpy as np
from PIL import Image

for f in sys.argv[1:]:
    a = np.asarray(Image.open(f).convert("RGB")).astype(np.int16)
    h, w, _ = a.shape
    sub = a[360:h, 320:960]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    m = (b > 110) & (b > r + 55) & (b > g + 25)
    # drop the HUD gauge ring etc.: keep the largest blob roughly by rows/cols with many pixels
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        print(f.split("/")[-1], "no paint")
        continue
    cols = np.bincount(xs, minlength=m.shape[1])
    rows = np.bincount(ys, minlength=m.shape[0])
    cx = np.nonzero(cols >= 8)[0]
    cy = np.nonzero(rows >= 8)[0]
    x0, x1 = cx.min() + 320, cx.max() + 320
    y0, y1 = cy.min() + 360, cy.max() + 360
    print("%-34s x %4d-%4d  y %4d-%4d  w %3d h %3d  px %6d" % (f.split("/")[-1], x0, x1, y0, y1, x1 - x0, y1 - y0, int(m.sum())))
