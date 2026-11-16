#!/usr/bin/env python3
"""carcrop.py <png>… – luminance median (0-255) and median HSV saturation of the player car crop (x 520-760,
y 470-700 at 1280x720), lamps (red-dominant) and the plate (very bright grey) left out, dark road (< 18/255) left out."""
import sys
import numpy as np
from PIL import Image
for p in sys.argv[1:]:
    a = np.asarray(Image.open(p).convert("RGB")).astype(float)
    h, w = a.shape[:2]
    sy = h / 720.0
    c = a[int(470 * sy):int(700 * sy), 520:760].reshape(-1, 3)
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    mx = c.max(1)
    mn = c.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    red = (r > 64) & (r > 1.5 * g) & (r > 1.5 * b)
    plate = (lum > 200) & (mx - mn < 30)
    m = (~red) & (~plate) & (lum > 18)
    print("%-60s n=%6d lum_med=%5.1f lum_p75=%5.1f sat_med=%.2f" % (p.split('/')[-1], m.sum(), np.median(lum[m]), np.percentile(lum[m], 75), np.median(sat[m])))
