#!/usr/bin/env python3
"""Scratch: mean colour of boxes in the Arcade and Modern picture of an A/B pair.
usage: probe.py <prefix> [x,y,w,h ...]   (prefix_arcade_00.png / prefix_modern_00.png)"""
import sys
from PIL import Image
import numpy as np

prefix = sys.argv[1]
boxes = sys.argv[2:] or ["250,560,60,30", "560,380,40,14", "880,430,50,20", "600,250,80,30", "150,430,60,20", "1100,400,80,30", "640,330,10,6"]
a = np.asarray(Image.open(prefix + "_arcade_00.png").convert("RGB")).astype(float)
m = np.asarray(Image.open(prefix + "_modern_00.png").convert("RGB")).astype(float)
for b in boxes:
    x, y, w, h = [int(v) for v in b.split(",")]
    ca = a[y:y + h, x:x + w].reshape(-1, 3).mean(0)
    cm = m[y:y + h, x:x + w].reshape(-1, 3).mean(0)
    la = ca @ np.array([0.299, 0.587, 0.114])
    lm = cm @ np.array([0.299, 0.587, 0.114])
    print("%-16s arcade %5.1f %5.1f %5.1f   modern %5.1f %5.1f %5.1f   lum %+5.1f %%" % (b, *ca, *cm, (lm / max(la, 1e-6) - 1) * 100))
