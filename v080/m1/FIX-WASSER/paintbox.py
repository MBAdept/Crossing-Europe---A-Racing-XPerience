#!/usr/bin/env python3
"""FIX-ZS1: box of the player's blue paint (as in tests/race3d/render/check_start_km0.gd) in A/B picture pairs.
usage: paintbox.py <prefix> [night]  -> per shot NN: Arcade box, Modern box, edge differences in % of Arcade's size"""
import sys
import numpy as np
from PIL import Image

prefix = sys.argv[1]
night = len(sys.argv) > 2
for nn in range(5):
    out = []
    boxes = []
    for mode in ("arcade", "modern"):
        try:
            im = np.asarray(Image.open("%s_%s_%02d.png" % (prefix, mode, nn)).convert("RGB")).astype(np.float32) / 255.0
        except FileNotFoundError:
            boxes = None
            break
        h, w, _ = im.shape
        y0 = int(0.45 * h) + 40
        x0, x1 = int(w * 0.3), int(w * 0.7)
        sub = im[y0:, x0:x1]
        r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
        if night:
            m = (b > 0.12) & (b - r > 0.06) & (b - g > 0.03)
        else:
            m = (b > 0.35) & (b - r > 0.18) & (b - g > 0.08)
        rows = np.where(m.sum(axis=1) >= 3)[0]
        cols = np.where(m.sum(axis=0) >= 3)[0]
        if len(rows) == 0 or len(cols) == 0:
            boxes.append(None)
            continue
        boxes.append((x0 + cols[0], y0 + rows[0], x0 + cols[-1] + 1, y0 + rows[-1] + 1))
    if boxes is None:
        continue
    a, m = boxes
    if a is None or m is None:
        print("%02d: Arcade %s Modern %s" % (nn, a, m))
        continue
    aw, ah = a[2] - a[0], a[3] - a[1]
    d = [(m[0] - a[0]) / aw * 100, (m[2] - a[2]) / aw * 100, (m[1] - a[1]) / ah * 100, (m[3] - a[3]) / ah * 100]
    print("%02d: Arcade %dx%d @(%d,%d)  Modern %dx%d @(%d,%d)  Kanten links/rechts/oben/unten %+.1f/%+.1f/%+.1f/%+.1f %%  Breite %+.1f %%  Hoehe %+.1f %%" % (
        nn, aw, ah, a[0], a[1], m[2] - m[0], m[3] - m[1], m[0], m[1], d[0], d[1], d[2], d[3],
        ((m[2] - m[0]) / aw - 1) * 100, ((m[3] - m[1]) / ah - 1) * 100))
