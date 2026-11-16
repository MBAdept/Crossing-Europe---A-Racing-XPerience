"""AS2R: mean display colour of the rear number plate of two levels in the ss4 probe tiles. The plate of the
coarser level (a flat light field) is found as the largest bright, grey region in the lower 60 % of the car; both
levels are averaged over the same box (inset by 2 px).  usage: platemean.py <dir> <tag> <dist> <lodA> <lodB>"""
import sys

import numpy as np
from PIL import Image

d, tag, dist, a, b = sys.argv[1], sys.argv[2], int(float(sys.argv[3])), sys.argv[4], sys.argv[5]
A = np.asarray(Image.open(f"{d}/{tag}_{dist}_{a}_ss4.png").convert("RGB")).astype(float)
B = np.asarray(Image.open(f"{d}/{tag}_{dist}_{b}_ss4.png").convert("RGB")).astype(float)
_m = np.asarray(Image.open(f"{d}/{tag}_{dist}_{b}_mask_ss4.png").convert("RGB")).astype(int)
M = (_m[:, :, 0] > 150) & (_m[:, :, 1] < 90) & (_m[:, :, 2] < 90)
ys, xs = np.nonzero(M)
y0, y1 = ys.min(), ys.max()
grey = (B.min(axis=2) > 150) & ((B.max(axis=2) - B.min(axis=2)) < 25) & M
grey[: int(y0 + 0.4 * (y1 - y0))] = False
yy, xx = np.nonzero(grey)
if len(yy) == 0:
    print(tag, "no plate found")
    sys.exit(0)
# the plate: the bright grey pixels near the vertical centre line of the car
cx = 0.5 * (xs.min() + xs.max())
sel = np.abs(xx - cx) < 0.25 * (xs.max() - xs.min())
yy, xx = yy[sel], xx[sel]
box = (yy.min() + 2, yy.max() - 1, xx.min() + 2, xx.max() - 1)
pa = A[box[0]:box[1], box[2]:box[3]].reshape(-1, 3).mean(axis=0)
pb = B[box[0]:box[1], box[2]:box[3]].reshape(-1, 3).mean(axis=0)
print(f"{tag} {dist} m plate box {box[3]-box[2]}x{box[1]-box[0]} px: {a} {pa.round(1)}  {b} {pb.round(1)}  diff {(pa - pb).round(1)}")
