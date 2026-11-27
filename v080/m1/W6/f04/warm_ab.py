#!/usr/bin/env python3
"""F-04: warm lit window pixels (warm2.py's rule: R>170, G>120, B<150, R>B+50) of an A/B pair, Arcade vs Modern,
in the picture below the HUD's top band (y 100 .. 560) and without the pixels both pictures share exactly (HUD,
signs: drawn identically by both modes).  warm_ab.py <prefix> [<prefix> ...]   (prefix_arcade_NN.png / _modern_NN.png)"""
import glob, sys
import numpy as np
from PIL import Image
def warm(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > 170) & (g > 120) & (b < 150) & (r > b + 50)
tot = {}
for pre in sys.argv[1:]:
    for pa in sorted(glob.glob(pre + "_arcade_[0-9][0-9].png")):
        pm = pa.replace("_arcade_", "_modern_")
        import os
        if not os.path.exists(pm):
            continue
        a = np.asarray(Image.open(pa).convert("RGB")).astype(int)[100:560]
        m = np.asarray(Image.open(pm).convert("RGB")).astype(int)[100:560]
        same = np.abs(a - m).max(axis=2) <= 2
        wa = (warm(a) & ~same).sum(); wm = (warm(m) & ~same).sum()
        print("%-34s arcade %6d  modern %6d  ratio %.2f" % (pa.split("/")[-1].replace("_arcade", ""), wa, wm, wm / max(1, wa)))
