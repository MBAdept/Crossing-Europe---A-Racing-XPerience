"""warm2.py <x0> <y0> <x1> <y1> <png> [png ...] : share of warm lit window pixels (R>170, G>120, B<150, R>B+50) of a
region per picture and their mean luminance (night window light)."""
import sys
import numpy as np
from PIL import Image

x0, y0, x1, y1 = map(int, sys.argv[1:5])
for p in sys.argv[5:]:
    a = np.asarray(Image.open(p).convert('RGB').crop((x0, y0, x1, y1))).astype(np.float64)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (r > 170) & (g > 120) & (b < 150) & (r > b + 50)
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    print('%-34s warm share %.4f  warm lum %5.1f  region lum %5.1f' % (p.split('/')[-1], m.mean(),
          lum[m].mean() if m.any() else 0.0, lum.mean()))
