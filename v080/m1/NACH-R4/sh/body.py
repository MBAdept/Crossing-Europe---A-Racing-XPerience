#!/usr/bin/env python3
"""body.py <png...> – the GT's body at N2N (x 560-720, y 490-600; window and road excluded by L > 30 on the body mask):
median luminance and median saturation of the 'paint' pixels (L > 30, not red lamp: R < 1.4 max(G,B))"""
import sys, os
import numpy as np
from PIL import Image
box = [int(v) for v in os.environ.get("BOX", "560,490,720,600").split(",")]
for p in sys.argv[1:]:
    img = Image.open(p).convert("RGB")
    x0, y0, x1, y1 = box
    a = np.asarray(img, dtype=np.float32)[y0:y1, x0:x1]
    L = np.asarray(img.convert("L"), dtype=np.float32)[y0:y1, x0:x1]
    S = np.asarray(img.convert("HSV"), dtype=np.float32)[y0:y1, x0:x1, 1] / 255.0
    m = (L > float(os.environ.get("LMIN", "30"))) & (a[..., 0] < 1.4 * np.maximum(a[..., 1], a[..., 2]))
    print("%-40s body_L_median=%.1f p75=%.1f sat_median=%.3f n=%d" % (os.path.basename(p), float(np.median(L[m])), float(np.percentile(L[m], 75)), float(np.median(S[m])), int(m.sum())))
