"""AS2R: split the changed pixels of a lod0 -> lod1 swap (round tiles) into plate / glass / rest.
Plate = the grey far plate of lod1 (uniform, near-neutral, bright), grown by 1 px; glass = bluish dark pixels of either
level (B > R + 12, value < 150).  usage: pop_split.py <tiles dir> <type> <dist> [<dist> ...]"""
import sys

import numpy as np
from PIL import Image

d, typ = sys.argv[1], sys.argv[2]


def im(n):
    return np.asarray(Image.open(f"{d}/{n}.png").convert("RGB")).astype(int)


def grow(m):
    g = m.copy()
    g[1:, :] |= m[:-1, :]
    g[:-1, :] |= m[1:, :]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    return g


bg = im("empty_day")
for ds in sys.argv[3:]:
    A = im(f"{typ}_g{ds}_lod0_day")
    B = im(f"{typ}_g{ds}_lod1_day")
    car = (np.abs(A - bg).max(axis=2) > 10) | (np.abs(B - bg).max(axis=2) > 10)
    ch = (np.abs(A - B).max(axis=2) > 24) & car
    v = B.max(axis=2)
    sat = B.max(axis=2) - B.min(axis=2)
    plate = grow(grow((v > 165) & (sat < 14) & car))
    # keep only the largest bright neutral blob near the bottom half (the plate), drop paint highlights
    ys, xs = np.nonzero(car)
    ymid = (ys.min() + ys.max()) / 2
    plate &= (np.arange(A.shape[0])[:, None] > ymid)
    glass = (((A[:, :, 2] > A[:, :, 0] + 12) & (A.max(axis=2) < 150)) |
             ((B[:, :, 2] > B[:, :, 0] + 12) & (B.max(axis=2) < 150))) & car & ~plate
    n = int(car.sum())
    c = int(ch.sum())
    cp = int((ch & plate).sum())
    cg = int((ch & glass).sum())
    print(f"{typ:7s} {ds:>3s} m: {n:5d} px, changed {c:4d} = {100.0 * c / n:4.1f} % | plate {cp:4d} ({100.0 * cp / n:4.1f} %)"
          f" glass {cg:4d} ({100.0 * cg / n:4.1f} %) rest {c - cp - cg:4d} ({100.0 * (c - cp - cg) / n:4.1f} %)")
