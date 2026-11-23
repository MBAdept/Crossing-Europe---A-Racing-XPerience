#!/usr/bin/env python3
"""grain.py <crop x,y,w,h> <png>...: share of pixels inside the crop that stand out from their 3x3 median by more than
24 luma steps (ordered dither of two LOD levels = isolated pixels) – a rough grain measure; only pixels that are not
sky-blue count (the crown)."""
import sys
import numpy as np
from PIL import Image, ImageFilter

x, y, w, h = (int(v) for v in sys.argv[1].split(","))
for p in sys.argv[2:]:
    im = Image.open(p).convert("RGB").crop((x, y, x + w, y + h))
    a = np.asarray(im).astype(np.float32)
    luma = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    med = np.asarray(Image.fromarray(luma.astype(np.uint8)).filter(ImageFilter.MedianFilter(3))).astype(np.float32)
    crown = (a[..., 1] > a[..., 2] + 10)          # green dominates blue: foliage, not sky
    out = (np.abs(luma - med) > 24) & crown
    print(f"{p.split('/')[-1]}: crown px {int(crown.sum())}, grain {100.0 * out.sum() / max(1, crown.sum()):.2f} %")
