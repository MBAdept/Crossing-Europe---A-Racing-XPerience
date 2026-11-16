"""AS4R scratch: window light in a crop of an A/B pair (M6): peak luminance, pixels above 150, mean of the 50
brightest pixels.   python3 lum.py <prefix> <NN> x0 y0 x1 y1   (crop in pixels of the 1280x720 pictures)"""
import sys

import numpy as np
from PIL import Image

pre, nn = sys.argv[1], sys.argv[2]
x0, y0, x1, y1 = (int(v) for v in sys.argv[3:7])
for mode in ("arcade", "modern"):
    a = np.asarray(Image.open("%s_%s_%s.png" % (pre, mode, nn)).convert("RGB"), dtype=np.float64)[y0:y1, x0:x1]
    lum = a @ np.array([0.2126, 0.7152, 0.0722])
    flat = np.sort(lum.reshape(-1))[::-1]
    hi = a.reshape(-1, 3)[np.argsort(lum.reshape(-1))[::-1][:50]].mean(axis=0)
    print("%-7s Spitze %5.1f  Pixel>150 %5d  Pixel>200 %5d  Mittel der 50 hellsten %5.1f  Farbe der 50 hellsten (%d,%d,%d)"
          % (mode, flat[0], int((lum > 150).sum()), int((lum > 200).sum()), flat[:50].mean(), hi[0], hi[1], hi[2]))
