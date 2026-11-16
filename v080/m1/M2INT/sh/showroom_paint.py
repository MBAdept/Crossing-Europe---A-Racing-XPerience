#!/usr/bin/env python3
"""Mean paint colour of the real-time `show` level against the Cycles sprite in the showroom A/B sheet of
tools/models_contact_sheet.sh --showroom (5 rows: gran_turismo, kombi, kompakt, limousine, sportwagen; left real-time,
right sprite). usage: showroom_paint.py <sheet.png>"""
import sys

import numpy as np
from PIL import Image

im = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(float)
H, W, _ = im.shape
th, tw = H // 5, W // 2
# a box on the front door of each car (fractions of a tile): the same body panel in both pictures
boxes = {"gran_turismo": (0.27, 0.47, 0.36, 0.55), "kombi": (0.22, 0.38, 0.32, 0.46),
         "kompakt": (0.22, 0.40, 0.32, 0.50), "limousine": (0.22, 0.42, 0.32, 0.52),
         "sportwagen": (0.26, 0.42, 0.36, 0.52)}
for r, (name, b) in enumerate(boxes.items()):
    vals = []
    for c in (0, 1):
        x0, x1 = int(c * tw + b[0] * tw), int(c * tw + b[2] * tw)
        y0, y1 = int(r * th + b[1] * th), int(r * th + b[3] * th)
        reg = im[y0:y1, x0:x1].reshape(-1, 3)
        lum = reg.mean(axis=1)
        sel = reg[(lum > 30) & (lum < 245)]
        vals.append(sel.mean(axis=0))
    rt, sp = vals
    luma = lambda v: float(v @ np.array([0.2126, 0.7152, 0.0722]))
    sat = lambda v: float((v.max() - v.min()) / max(v.max(), 1.0))
    print("%-13s Echtzeit %s (Luma %.0f, Sätt. %.2f)  Sprite %s (Luma %.0f, Sätt. %.2f)  Luma x %.2f" % (
        name, rt.round(0), luma(rt), sat(rt), sp.round(0), luma(sp), sat(sp), luma(rt) / max(luma(sp), 1.0)))
