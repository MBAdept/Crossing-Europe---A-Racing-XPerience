import sys
import numpy as np
from PIL import Image
# usage: carstat.py x0 x1 y0 y1 img...   luminance statistics of a picture region (pixels of the 1280x720 frame)
x0, x1, y0, y1 = [int(v) for v in sys.argv[1:5]]
for f in sys.argv[5:]:
    a = np.asarray(Image.open(f).convert('RGB')).astype(float)[y0:y1, x0:x1]
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    print("%-28s mean %6.1f  p95 %6.1f  p99 %6.1f  max %4.0f  rgb %s" % (f.split('/')[-1], lum.mean(), np.percentile(lum, 95),
          np.percentile(lum, 99), lum.max(), "/".join("%.0f" % v for v in a.reshape(-1, 3).mean(axis=0))))
