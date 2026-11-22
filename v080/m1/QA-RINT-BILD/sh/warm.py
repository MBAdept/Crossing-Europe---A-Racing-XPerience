"""warm.py <clipframe.jpg> <x0> <y0> <x1> <y1> : share of warm lit pixels (window light: R>170, G>120, B<150, R>B+50) and
their mean luminance in the same region of the Arcade (left) and Modern (right) half of an ab_clip frame (header 30 px)."""
import sys
import numpy as np
from PIL import Image

im = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(np.float64)
x0, y0, x1, y1 = map(int, sys.argv[2:6])
H0 = 30
for name, off in (('arcade', 0), ('modern', im.shape[1] // 2)):
    a = im[H0 + y0:H0 + y1, off + x0:off + x1]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (r > 170) & (g > 120) & (b < 150) & (r > b + 50)
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    print('%-7s warm share %.4f  warm mean lum %5.1f  region mean lum %5.1f' % (
        name, m.mean(), lum[m].mean() if m.any() else 0.0, lum.mean()))
