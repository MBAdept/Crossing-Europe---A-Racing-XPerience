#!/usr/bin/env python3
"""QA-M2-BILD: visible pixels of the injected test car per distance and lane, Arcade vs Modern.
usage: occl_count.py <occl dir> <position> [variants...]   (variants default: arcade m2high zs1high)
A pixel counts when one channel changes by more than 24/255 against <tag>_none.png."""
import glob
import os
import re
import sys

import numpy as np
from PIL import Image

d = sys.argv[1]
pos = sys.argv[2]
variants = sys.argv[3:] or ["arcade", "m2high", "zs1high"]
THR = 24
res = {}
for v in variants:
    tag = "%s_%s" % (pos, v)
    base = os.path.join(d, tag + "_none.png")
    if not os.path.exists(base):
        continue
    b = np.asarray(Image.open(base).convert("RGB")).astype(np.int16)
    for f in sorted(glob.glob(os.path.join(d, tag + "_d*_l*.png"))):
        m = re.search(r"_d(\d+)_l(-?\d+)\.png$", f)
        dist, lane = int(m.group(1)), int(m.group(2))
        a = np.asarray(Image.open(f).convert("RGB")).astype(np.int16)
        diff = (np.abs(a - b) > THR).any(axis=2)
        n = int(diff.sum())
        if n:
            ys, xs = np.nonzero(diff)
            bbox = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
        else:
            bbox = None
        res.setdefault((dist, lane), {})[v] = (n, bbox)
print("%s: visible pixels of the red test car (lane -1 / 0 / +1)" % pos)
print("%6s %5s " % ("d m", "lane") + " ".join("%10s" % v for v in variants) + "   ratio m2/arcade")
for key in sorted(res):
    row = res[key]
    vals = [row.get(v, (None, None))[0] for v in variants]
    a = row.get("arcade", (None, None))[0]
    m2 = row.get("m2high", (None, None))[0]
    ratio = ("%.2f" % (m2 / a)) if a and m2 is not None else ("-" if not a else "")
    flag = ""
    if a and a >= 30 and (m2 is not None) and m2 < 0.5 * a:
        flag = "  <-- Modern zeigt weniger als die Hälfte"
    if a == 0 and m2:
        flag = "  (nur Modern)"
    print("%6d %5d " % key + " ".join("%10s" % ("-" if x is None else x) for x in vals) + "   " + ratio + flag)
