"""after_shares.py <png...>: the metric of check_tunnel_bridge exit_after (pure white share, snow share of the scene
band on a nearest-neighbour 320x180 copy, rows 45..143)."""
import sys
import numpy as np
from PIL import Image

for p in sys.argv[1:]:
    im = Image.open(p).convert('RGB')
    w, h = im.size
    xs = (np.arange(320) * w / 320).astype(int)
    ys = (np.arange(180) * h / 180).astype(int)
    a = np.asarray(im).astype(np.float64)[ys][:, xs] / 255.0
    band = a[45:144]
    r, g, b = band[..., 0], band[..., 1], band[..., 2]
    white = (r >= 240 / 255) & (g >= 240 / 255) & (b >= 240 / 255)
    hi = band.max(axis=2)
    lo = band.min(axis=2)
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    snow = (~white) & (lum >= 0.55) & (lum < 0.94) & (hi > 0) & ((hi - lo) / np.maximum(hi, 1e-6) < 0.15)
    print('%-50s white %.3f snow %.3f' % (p.split('/')[-1], white.mean(), snow.mean()))
