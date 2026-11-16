"""AS2R: mean displayed colour of the checked band (Battenburg) in two levels: the box of the saturated yellow pixels
of level A (supersampled tile), averaged in linear light and in sRGB.  usage: bandmean.py <dir> <tag> <dist> <A> <B>"""
import sys

import numpy as np
from PIL import Image

d, tag, dist, a, b = sys.argv[1:6]


def im(n):
    return np.asarray(Image.open(f"{d}/{n}.png").convert("RGB")).astype(float) / 255.0


def lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.clip(c, 0, None), 1 / 2.4) - 0.055)


for kind in ("ss4", ""):
    sfx = f"_{kind}" if kind else ""
    A = im(f"{tag}_{dist}_{a}{sfx}")
    B = im(f"{tag}_{dist}_{b}{sfx}")
    yel = (A[:, :, 0] > 0.7) & (A[:, :, 1] > 0.7) & (A[:, :, 2] < 0.45)
    ys, xs = np.nonzero(yel)
    if len(ys) == 0:
        print(kind or "1x", "no yellow pixels")
        continue
    y0, y1 = np.percentile(ys, 2), np.percentile(ys, 98)
    x0, x1 = np.percentile(xs, 2), np.percentile(xs, 98)
    y0, y1, x0, x1 = int(y0), int(y1) + 1, int(x0), int(x1) + 1
    ra = A[y0:y1, x0:x1].reshape(-1, 3)
    rb = B[y0:y1, x0:x1].reshape(-1, 3)
    for nm, r in ((a, ra), (b, rb)):
        ml = srgb(lin(r).mean(axis=0)) * 255
        ms = r.mean(axis=0) * 255
        print(f"{kind or '1x':4s} {nm}: box {x1 - x0}x{y1 - y0}  mean linear->sRGB ({ml[0]:.0f}, {ml[1]:.0f}, {ml[2]:.0f})"
              f"  mean sRGB ({ms[0]:.0f}, {ms[1]:.0f}, {ms[2]:.0f})")
