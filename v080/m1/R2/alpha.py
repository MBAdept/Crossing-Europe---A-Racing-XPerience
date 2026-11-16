import sys
from PIL import Image
import numpy as np
root = sys.argv[1]
for name in sys.argv[2:]:
    im = Image.open(root + '/assets/sprites/props/' + name + '.png').convert('RGBA')
    a = np.asarray(im).astype(np.float32) / 255.0
    h, w, _ = a.shape
    alpha = a[..., 3]
    lum = a[..., :3].mean(axis=2)
    semi = (alpha > 0.02) & (alpha < 0.98)
    dark_semi = semi & (lum < 0.2)
    print(name, im.size, 'opaque %.3f semi %.3f dark-semi %.3f' % ((alpha >= 0.98).mean(), semi.mean(), dark_semi.mean()))
    if dark_semi.any():
        v = alpha[dark_semi]
        print('   dark-semi alpha: min %.2f p50 %.2f p90 %.2f max %.2f; share > 0.5: %.3f' % (v.min(), np.percentile(v, 50), np.percentile(v, 90), v.max(), (v > 0.5).mean()))
        rows = np.where(dark_semi.any(axis=1))[0]
        print('   rows %d..%d of %d' % (rows.min(), rows.max(), h))
