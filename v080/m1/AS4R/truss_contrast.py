"""AS4R scratch (M10 truss): contrast of the truss portal against the sky in a d_bruecke composite tile.
python3 truss_contrast.py <composite.png> <row> <col> <zoom>
Tiles 360x300 (caption strip at the bottom). Sky rows only (above the first row with grass).
Per row the median luminance is the sky; portal pixels deviate by more than 12; contrast = their mean |dL|."""
import sys

import numpy as np
from PIL import Image

TW, TH, CAP = 360, 300, 26
a = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float64)
row, col, zoom = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
t = a[row * TH:(row + 1) * TH - CAP, col * TW:(col + 1) * TW]
lum = 0.2126 * t[..., 0] + 0.7152 * t[..., 1] + 0.0722 * t[..., 2]
grass = (t[..., 1] > t[..., 0] + 15) & (t[..., 1] > t[..., 2] + 5)
rows_grass = np.where(grass.mean(axis=1) > 0.3)[0]
horizon = rows_grass[0] if len(rows_grass) else lum.shape[0]
sky = lum[:max(horizon - 4, 1)]
med = np.median(sky, axis=1, keepdims=True)
d = np.abs(sky - med)
m = d > 12
print("%s r%d c%d: Horizont y %d, Portal %d px (%.0f Bildschirm-px), Kontrast %.1f" % (
    sys.argv[1].split("/")[-1], row, col, horizon, m.sum(), m.sum() / float(zoom * zoom), d[m].mean() if m.any() else 0.0))
