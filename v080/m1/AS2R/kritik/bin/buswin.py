"""AS2R: mean colour of the bus rear window in two levels (supersampled probe tiles): the vehicle box from the mask
tile, the window = bluish dark pixels of level A in the upper part of the box.  usage: buswin.py <dir> <tag> <dist> <A> <B>"""
import sys

import numpy as np
from PIL import Image

d, tag, dist, a, b = sys.argv[1:6]


def im(n):
    return np.asarray(Image.open(f"{d}/{n}.png").convert("RGB")).astype(float)


def lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    return np.round((np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)) * 255)


mk = im(f"{tag}_{dist}_{a}_mask_ss4")
car = (mk[:, :, 0] > 150) & (mk[:, :, 1] < 90) & (mk[:, :, 2] < 90)
ys, xs = np.nonzero(car)
y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
h = y1 - y0
A = im(f"{tag}_{dist}_{a}_ss4")
B = im(f"{tag}_{dist}_{b}_ss4")
sub = (slice(y0 + int(0.04 * h), y0 + int(0.35 * h)), slice(x0 + int(0.08 * (x1 - x0)), x1 - int(0.08 * (x1 - x0))))
ra, rb = A[sub], B[sub]
m = (ra[:, :, 2] > ra[:, :, 0] + 15) & (ra.max(axis=2) < 200)
wa, wb = ra[m], rb[m]
print(f"{tag} {dist} m window px {m.sum()}: {a} {tuple(srgb(lin(wa).mean(axis=0)).astype(int))}  "
      f"{b} {tuple(srgb(lin(wb).mean(axis=0)).astype(int))}  changed>24 {100.0 * (np.abs(wa - wb).max(axis=1) > 24).mean():.1f} %")
