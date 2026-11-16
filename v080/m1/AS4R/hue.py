"""AS4R scratch: hues of the dark window panes in a picture (M3). python3 hue.py <png> [x0 y0 x1 y1]
Dark pixels (max channel < 95, max - min > 8): share with a brown hue (15-55 deg) and with a blue hue (180-250 deg)."""
import colorsys
import sys

import numpy as np
from PIL import Image

a = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float64)
if len(sys.argv) > 5:
    x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
    a = a[y0:y1, x0:x1]
px = a.reshape(-1, 3)
mx, mn = px.max(axis=1), px.min(axis=1)
sel = px[(mx < 95) & (mx - mn > 8)]
hues = np.array([colorsys.rgb_to_hsv(*(p / 255.0))[0] * 360.0 for p in sel])
brown = (hues >= 15) & (hues <= 55)
blue = (hues >= 180) & (hues <= 250)
print("%s: %d dunkle Pixel, braun %.1f %% (Mittel %s), blau %.1f %% (Mittel %s)" % (
    sys.argv[1].split("/")[-1], len(sel), 100.0 * brown.mean() if len(sel) else 0.0,
    np.round(sel[brown].mean(axis=0)).astype(int).tolist() if brown.any() else "-",
    100.0 * blue.mean() if len(sel) else 0.0, np.round(sel[blue].mean(axis=0)).astype(int).tolist() if blue.any() else "-"))
