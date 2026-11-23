#!/usr/bin/env python3
"""QA-R7c: per combo and shot: share of pixels changed by > 40 levels and mean luma, base vs R7c (and 43a1fcc vs R7c),
plus Arcade/base/R7c mean luma of the scenery band (y 150..520 of 720, HUD bands excluded). Writes a difference picture
<combo>_diff_NN.jpg (|R7c - base| x 4) next to the pictures. Usage: picstats.py <raw dir> [combo ...]"""
import sys, glob, os
import numpy as np
from PIL import Image

d = sys.argv[1]
only = sys.argv[2:]


def L(f):
    return np.asarray(Image.open(f).convert("RGB")).astype(np.int16)


def luma(a):
    return float((0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]).mean())


for r in sorted(glob.glob(d + "/*_r7c_[0-9][0-9].png")):
    base = r.replace("_r7c_", "_base_")
    combo = os.path.basename(r).rsplit("_r7c_", 1)[0]
    nn = r[-6:-4]
    if only and combo not in only:
        continue
    if not os.path.exists(base):
        continue
    a = L(r)
    b = L(base)
    h = a.shape[0]
    y0, y1 = int(h * 0.21), int(h * 0.72)
    out = "%s %s: base->R7c %.2f %% px changed, luma %.1f -> %.1f" % (combo, nn, (np.abs(a - b).max(axis=2) > 40).mean() * 100,
                                                                   luma(b[y0:y1]), luma(a[y0:y1]))
    m = r.replace("_r7c_", "_merge_")
    if os.path.exists(m):
        c = L(m)
        out += " | 43a1fcc->R7c %.2f %%, luma %.1f" % ((np.abs(a - c).max(axis=2) > 40).mean() * 100, luma(c[y0:y1]))
    ar = r.replace("_r7c_", "_arcade_")
    if os.path.exists(ar):
        e = L(ar)
        if e.shape == a.shape:
            out += " | Arcade luma %.1f" % luma(e[y0:y1])
    print(out)
    diff = np.clip(np.abs(a - b) * 4, 0, 255).astype(np.uint8)
    Image.fromarray(diff).save(d + "/%s_diff_%s.jpg" % (combo, nn), quality=80)
