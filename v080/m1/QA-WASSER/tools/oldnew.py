#!/usr/bin/env python3
"""Old vs new frames of the same run (QA-WASSER): where and how much the picture changes.

usage: oldnew.py <old_prefix> <new_prefix> [--viz <frame NN> <out.jpg>]
For every NN with <old_prefix>_NN.png and <new_prefix>_NN.png: pixels that differ at all, pixels > 8/255, the rows
that contain them (first..last), the largest difference. --viz writes old | new | difference x4 for one frame.
"""
import glob
import sys

import numpy as np
from PIL import Image

old_p, new_p = sys.argv[1], sys.argv[2]
viz = None
if "--viz" in sys.argv:
    i = sys.argv.index("--viz")
    viz = (sys.argv[i + 1], sys.argv[i + 2])
for fo in sorted(glob.glob(old_p + "_[0-9][0-9].png")):
    nn = fo[-6:-4]
    fn = new_p + "_" + nn + ".png"
    a = np.asarray(Image.open(fo).convert("RGB")).astype(np.int16)
    b = np.asarray(Image.open(fn).convert("RGB")).astype(np.int16)
    d = np.abs(a - b).max(axis=2)
    any_ = d > 0
    big = d > 8
    rows = np.nonzero(big.any(axis=1))[0]
    print("frame %s: differ %6d px, >8/255 %6d px (%.3f %%), rows %s, max %3d" % (
        nn, int(any_.sum()), int(big.sum()), 100.0 * big.mean(),
        ("%d-%d" % (rows.min(), rows.max())) if len(rows) else "-", int(d.max())))
    if viz and viz[0] == nn:
        dv = np.clip(d * 4, 0, 255).astype(np.uint8)
        dimg = Image.fromarray(np.stack([dv, dv, dv], axis=2))
        w, h = dimg.size
        out = Image.new("RGB", (w, h * 3 + 8), (16, 24, 44))
        out.paste(Image.open(fo).convert("RGB"), (0, 0))
        out.paste(Image.open(fn).convert("RGB"), (0, h + 4))
        out.paste(dimg, (0, 2 * h + 8))
        out.save(viz[1], quality=90)
        print("viz", viz[1])
