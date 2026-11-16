#!/usr/bin/env python3
"""region.py A.png M.png x0 y0 x1 y1 [maxlum] – trimmed mean Rec.709 luminance (0..1) of a box in both pictures."""
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(np.float64) / 255.0
m = np.asarray(Image.open(sys.argv[2]).convert('RGB')).astype(np.float64) / 255.0
x0, y0, x1, y1 = map(int, sys.argv[3:7])
mx = float(sys.argv[7]) if len(sys.argv) > 7 else 1.0
def lum(img):
    r = img[y0:y1, x0:x1]
    l = 0.2126 * r[..., 0] + 0.7152 * r[..., 1] + 0.0722 * r[..., 2]
    l = l[l <= mx].ravel()
    l.sort()
    k = int(len(l) * 0.05)
    return l[k:len(l) - k].mean() if len(l) > 2 * k else float('nan'), len(l)
la, na = lum(a)
lm, nm = lum(m)
print(f"Arcade {la:.4f} ({na} px)  Modern {lm:.4f} ({nm} px)  dev {100.0 * (lm - la) / la:+.1f} %")
