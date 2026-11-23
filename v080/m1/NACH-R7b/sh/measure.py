#!/usr/bin/env python3
# NACH-R7b: measures of a picture triple <prefix>_{arcade,basis,modern}_00.png
#   measure.py lum <prefix> x0 y0 x1 y1      mean / p90 luminance (Rec.709) in the box
#   measure.py red <prefix> [x0 y0 x1 y1]    red aviation-light pixels (QA-R7b: r >= 110, r > 1.8 g, r > 1.8 b), bbox
import sys
import numpy as np
from PIL import Image

mode, prefix = sys.argv[1], sys.argv[2]
box = list(map(int, sys.argv[3:7])) if len(sys.argv) > 6 else None
for tag in ("arcade", "basis", "modern"):
    try:
        a = np.asarray(Image.open(f"{prefix}_{tag}_00.png").convert("RGB")).astype(float)
    except FileNotFoundError:
        print(tag, "fehlt")
        continue
    if mode == "lum":
        x0, y0, x1, y1 = box
        c = a[y0:y1, x0:x1]
        lum = 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]
        print(f"{tag:7s} Ø {lum.mean():6.1f}  p90 {np.percentile(lum, 90):6.1f}  p99 {np.percentile(lum, 99):6.1f}")
    else:
        x0, y0, x1, y1 = box if box else (0, 0, a.shape[1], a.shape[0])
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        m = (r >= 110) & (r > 1.8 * g) & (r > 1.8 * b)
        bm = np.zeros_like(m)
        bm[y0:y1, x0:x1] = True
        m &= bm
        ys, xs = np.nonzero(m)
        bb = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())) if len(xs) else None
        print(f"{tag:7s} rote px {int(m.sum()):5d}  bbox {bb}")
