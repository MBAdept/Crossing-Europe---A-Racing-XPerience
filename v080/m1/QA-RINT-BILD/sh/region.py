"""region.py <x0> <y0> <x1> <y1> <png> [png ...] : mean luminance (0-255, Rec.709), mean saturation (HSV, 0-1), mean hue
(deg, weighted by saturation) and share of near-white pixels (all channels >= 235) of a region, per picture."""
import sys
import numpy as np
from PIL import Image

x0, y0, x1, y1 = map(int, sys.argv[1:5])
for p in sys.argv[5:]:
    a = np.asarray(Image.open(p).convert('RGB').crop((x0, y0, x1, y1))).astype(np.float64) / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    mx = a.max(axis=2)
    mn = a.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    # hue
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    w = sat * (mx - mn > 0.02)
    hx = (np.cos(np.radians(h)) * w).sum()
    hy = (np.sin(np.radians(h)) * w).sum()
    hue = (np.degrees(np.arctan2(hy, hx)) + 360) % 360
    white = ((a >= 235 / 255).all(axis=2)).mean()
    print('%-70s lum %6.1f  sat %.3f  hue %5.1f  white %.4f' % (p.split('/')[-1], lum.mean() * 255, sat.mean(), hue, white))
