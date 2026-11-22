"""carbody.py x0 y0 x1 y1 png...: p75 luminance (0-255) and median saturation of body pixels in a box (red lamp/glow
pixels r > 1.5 g excluded, near-black < 20 excluded)."""
import sys
import numpy as np
from PIL import Image
x0, y0, x1, y1 = map(int, sys.argv[1:5])
for p in sys.argv[5:]:
    a = np.asarray(Image.open(p).convert('RGB').crop((x0, y0, x1, y1))).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    mx = a.max(2); mn = a.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    m = (lum > 20) & ~((r > 1.5 * g) & (r > 60))
    print('%-28s p75 lum %6.1f  median lum %6.1f  sat %.2f  n %d' % (p.split('/')[-1], np.percentile(lum[m], 75), np.median(lum[m]), np.median(sat[m]), m.sum()))
