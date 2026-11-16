#!/usr/bin/env python3
"""QA-ZS1: the dark START banner of the start gate per frame: rows with >= 250 dark pixels (the banner spans the road),
its top/bottom row and left/right column, Arcade vs Modern."""
import sys, glob
import numpy as np
from PIL import Image
def banner(p):
    img = np.asarray(Image.open(p).convert("RGB")).astype(np.int32)
    h, w, _ = img.shape
    y0, y1 = int(h * 0.14), int(h * 0.70)
    sub = img[y0:y1]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    m = (r < 45) & (g < 45) & (b < 52) & (np.abs(r - b) < 18)
    rows = np.nonzero(m.sum(axis=1) >= 250)[0]
    if len(rows) == 0:
        return None
    # the longest block of consecutive banner rows
    blocks, start = [], rows[0]
    for a, c in zip(rows, rows[1:]):
        if c != a + 1:
            blocks.append((start, a)); start = c
    blocks.append((start, rows[-1]))
    t, bt = max(blocks, key=lambda q: q[1] - q[0])
    cols = np.nonzero(m[t:bt + 1].sum(axis=0) >= max(2, (bt - t + 1) // 2))[0]
    return (int(cols[0]), int(t + y0), int(cols[-1]), int(bt + y0))
prefix = sys.argv[1]
for pa in sorted(glob.glob(prefix + "_arcade_[0-9][0-9].png")):
    nn = pa[-6:-4]
    a = banner(pa); m = banner(pa.replace("_arcade_", "_modern_"))
    f = lambda q: "-" if q is None else "x %4d..%4d  y %3d..%3d (%dx%d)" % (q[0], q[2], q[1], q[3], q[2]-q[0]+1, q[3]-q[1]+1)
    d = "" if a is None or m is None else "  dL %+d dR %+d dT %+d dB %+d" % (m[0]-a[0], m[2]-a[2], m[1]-a[1], m[3]-a[3])
    print("%s A %s | M %s%s" % (nn, f(a), f(m), d))
