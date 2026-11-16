"""litpx.py <png> x0,y0,x1,y1 ...: share of warm lit window pixels (r > 170, r >= g >= b, r - b > 50) in a box, and
the mean colour of those pixels."""
import sys
import numpy as np
from PIL import Image
im = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32)
for b in sys.argv[2:]:
    x0, y0, x1, y1 = map(int, b.split(","))
    t = im[y0:y1, x0:x1].reshape(-1, 3)
    R, G, B = t[:, 0], t[:, 1], t[:, 2]
    lit = (R > 170) & (R >= G) & (G >= B) & (R - B > 50)
    n = int(lit.sum())
    mc = t[lit].mean(axis=0) if n else np.zeros(3)
    print("%-28s %s lit %5d px (%.2f %%) rgb(%d,%d,%d)" % (sys.argv[1].split('/')[-1], b, n, 100.0 * n / len(t), *mc))
