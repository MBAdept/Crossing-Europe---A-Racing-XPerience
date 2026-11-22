#!/usr/bin/env python3
"""R7a: visible pixels of the red test car (qa_occl.gd) per position, distance and lane; mine against base; the F2
requirement: visible at every distance up to L (the sight line length of the corridor at the camera, probe/startdep.gd).
usage: occl_eval.py <occl dir>"""
import glob
import os
import re
import sys

import numpy as np
from PIL import Image

D = sys.argv[1]
L = {"T1": 263, "T2": 300, "T3": 119, "T4": 118, "C1": 300, "S0": 300, "S4": 300}
THR = 24
MIN_PX = 12      # a car counts as shown from this many changed pixels on
for pos in ["T4", "T3", "T1", "T2", "C1", "S0", "S4"]:
    rows = {}
    for v in ["mine", "base"]:
        tag = "%s_%s" % (pos, v)
        base = os.path.join(D, tag + "_none.png")
        if not os.path.exists(base):
            continue
        b = np.asarray(Image.open(base).convert("RGB")).astype(np.int16)
        for f in sorted(glob.glob(os.path.join(D, tag + "_d*_l*.png"))):
            m = re.search(r"_d(\d+)_l(-?\d+)\.png$", f)
            dist, lane = int(m.group(1)), int(m.group(2))
            a = np.asarray(Image.open(f).convert("RGB")).astype(np.int16)
            n = int((np.abs(a - b) > THR).any(axis=2).sum())
            rows.setdefault((dist, lane), {})[v] = n
    if not rows:
        continue
    need = min(L[pos], 270)
    bad = []
    print("%s (L = %d m, verlangt sichtbar bis %d m): d m / Spur: R7a [Basis]" % (pos, L[pos], need))
    line = []
    for key in sorted(rows):
        r = rows[key]
        mine = r.get("mine")
        base = r.get("base")
        line.append("%d/%+d: %s%s" % (key[0], key[1], mine, (" [%s]" % base) if base is not None else ""))
        if mine is not None and key[0] <= need and mine < MIN_PX:
            bad.append(key)
    for i in range(0, len(line), 6):
        print("   " + "   ".join(line[i:i + 6]))
    print("   -> %s" % ("F2 gehalten: an jeder verlangten Stelle sichtbar" if not bad else "VERDECKT bei %s" % bad))
