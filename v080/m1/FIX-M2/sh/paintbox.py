#!/usr/bin/env python3
"""QA-M2-BILD: paint of the player car in A/B pictures – pixels inside a box whose hue is near the paint hue
(saturation >= 0.25), mean value / saturation / luminance; per picture.
usage: paintbox.py <x0> <y0> <x1> <y1> <hue_deg> <hue_tol_deg> <label=png> [...]"""
import colorsys
import sys

import numpy as np
from PIL import Image

x0, y0, x1, y1 = (int(v) for v in sys.argv[1:5])
hue = float(sys.argv[5]) / 360.0
tol = float(sys.argv[6]) / 360.0
for a in sys.argv[7:]:
    lab, _, p = a.partition("=")
    im = np.asarray(Image.open(p).convert("RGB")).astype(np.float32)[y0:y1, x0:x1] / 255.0
    px = im.reshape(-1, 3)
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in px])
    dh = np.abs(hsv[:, 0] - hue)
    dh = np.minimum(dh, 1.0 - dh)
    m = (dh <= tol) & (hsv[:, 1] >= 0.25) & (hsv[:, 2] >= 0.08)
    if not m.any():
        print("%-28s no paint pixels" % lab)
        continue
    sel = px[m]
    lum = 0.2126 * sel[:, 0] + 0.7152 * sel[:, 1] + 0.0722 * sel[:, 2]
    print("%-28s paint px %6d  value %.3f  sat %.3f  lum %.3f (p90 %.3f)  mean RGB %s" % (
        lab, m.sum(), hsv[m, 2].mean(), hsv[m, 1].mean(), lum.mean(), np.percentile(lum, 90),
        tuple(int(v * 255) for v in sel.mean(axis=0))))
