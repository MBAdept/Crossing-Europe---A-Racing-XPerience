"""boxlum.py <png> x0,y0,x1,y1 [...]: mean RGB and luma percentiles of boxes (excluding sky-blue pixels)."""
import sys
import numpy as np
from PIL import Image
im = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32)
for b in sys.argv[2:]:
    x0, y0, x1, y1 = map(int, b.split(","))
    t = im[y0:y1, x0:x1].reshape(-1, 3)
    R, G, B = t[:, 0], t[:, 1], t[:, 2]
    keep = ~((B > R + 25) & (B > G + 5))
    t = t[keep]
    y = 0.2126 * t[:, 0] + 0.7152 * t[:, 1] + 0.0722 * t[:, 2]
    p = np.percentile(y, [10, 50, 90])
    print("%-50s %s n=%6d rgb(%3d,%3d,%3d) luma p10 %5.1f p50 %5.1f p90 %5.1f mean %5.1f" % (sys.argv[1].split('/')[-1], b, len(y), *t.mean(axis=0), *p, y.mean()))
