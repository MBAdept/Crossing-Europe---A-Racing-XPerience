"""snow_metric.py <sat_max> <lum_min> <row0> <row1> <png...>: share of snow pixels (not pure white, luminance >= lum_min,
saturation < sat_max) in rows row0..row1 of a nearest 320x180 copy; and pure white share of rows 45..143."""
import sys
import numpy as np
from PIL import Image

sat_max, lum_min = float(sys.argv[1]), float(sys.argv[2])
r0, r1 = int(sys.argv[3]), int(sys.argv[4])
for p in sys.argv[5:]:
    im = Image.open(p).convert('RGB')
    w, h = im.size
    xs = (np.arange(320) * w / 320).astype(int)
    ys = (np.arange(180) * h / 180).astype(int)
    a = np.asarray(im).astype(np.float64)[ys][:, xs] / 255.0
    def shares(band):
        r, g, b = band[..., 0], band[..., 1], band[..., 2]
        white = (r >= 240 / 255) & (g >= 240 / 255) & (b >= 240 / 255)
        hi = band.max(axis=2)
        lo = band.min(axis=2)
        lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        snow = (~white) & (lum >= lum_min) & (hi > 0) & ((hi - lo) / np.maximum(hi, 1e-6) < sat_max)
        return white.mean(), snow.mean()
    wb, _ = shares(a[45:144])
    _, sn = shares(a[r0:r1])
    print('%-50s white %.3f snow %.3f' % (p.split('/')[-1], wb, sn))
