"""AS2R: mean colour of the rear window of two levels in the supersampled probe tiles - the window = pixels that are
bluish-dark in the coarser level inside the upper half of the car box.  usage: winmean.py <dir> <tag> <dist> <lodA> <lodB>"""
import sys

import numpy as np
from PIL import Image

d, tag, dist, a, b = sys.argv[1], sys.argv[2], int(float(sys.argv[3])), sys.argv[4], sys.argv[5]
A = np.asarray(Image.open(f"{d}/{tag}_{dist}_{a}_ss4.png").convert("RGB")).astype(float)
B = np.asarray(Image.open(f"{d}/{tag}_{dist}_{b}_ss4.png").convert("RGB")).astype(float)
_m = np.asarray(Image.open(f"{d}/{tag}_{dist}_{b}_mask_ss4.png").convert("RGB")).astype(int)
M = (_m[:, :, 0] > 150) & (_m[:, :, 1] < 90) & (_m[:, :, 2] < 90)
ys, xs = np.nonzero(M)
y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
# window candidates in B: blue channel clearly above red, darkish, in the upper 60 % of the car
win = (B[:, :, 2] > B[:, :, 0] + 18) & (B.max(axis=2) < 200) & M
win[: y0] = False
win[int(y0 + 0.6 * (y1 - y0)):] = False
# erode by 3 px (no edge pixels)
def _erode(m):
    e = m.copy()
    e[1:] &= m[:-1]; e[:-1] &= m[1:]; e[:, 1:] &= m[:, :-1]; e[:, :-1] &= m[:, 1:]
    return e
win = _erode(_erode(_erode(win)))
n = int(win.sum())
ma, mb = A[win].mean(axis=0), B[win].mean(axis=0)
print(f"{tag} {dist} m window px {n}: {a} {ma.round(1)}  {b} {mb.round(1)}  diff {(ma - mb).round(1)}")
