"""AS4R scratch (M10 church): brightness of a plaster wall in a race picture.
python3 wall.py <png> x0 y0 x1 y1  -> wall pixels = near neutral (max - min < 35) and luminance > 120 inside the box
(the sky is blue, roof and windows are dark, trees green); prints count, mean and 95th percentile of the luminance."""
import sys

import numpy as np
from PIL import Image

a = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float64)
x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
t = a[y0:y1, x0:x1].reshape(-1, 3)
lum = t @ np.array([0.2126, 0.7152, 0.0722])
m = (t.max(axis=1) - t.min(axis=1) < 35) & (lum > 120)
v = lum[m]
print("%s: Wand %d px, Mittel %.0f, p95 %.0f, Farbe %s" % (
    sys.argv[1].split("/")[-1], m.sum(), v.mean() if len(v) else 0, np.percentile(v, 95) if len(v) else 0,
    np.round(t[m].mean(axis=0)).astype(int).tolist() if len(v) else "-"))
