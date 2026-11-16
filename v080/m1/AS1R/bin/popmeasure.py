"""AS1R: LOD pop - share of the car's pixels that change by more than 24 levels between two levels at the swap
distance (game camera, day tile = first tile of the chase sheet).  usage: popmeasure.py <tag> <lodA> <lodB>"""
import sys

import numpy as np
from PIL import Image

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R/out"
tag, a, b = sys.argv[1:4]
for m in ("sedan", "hatch", "wagon"):
    ia = np.asarray(Image.open("%s/pop_%s_%s_%s.png" % (S, tag, m, a)).convert("RGB"), dtype=np.int32)[:270, :480]
    ib = np.asarray(Image.open("%s/pop_%s_%s_%s.png" % (S, tag, m, b)).convert("RGB"), dtype=np.int32)[:270, :480]
    # background per row (sky and ground differ): the median of the outer 40 pixels on both sides of that row
    bg = np.median(np.concatenate([ia[:, :40], ia[:, -40:]], axis=1), axis=1)[:, None, :]
    car = (np.abs(ia - bg).max(axis=2) > 15) | (np.abs(ib - bg).max(axis=2) > 15)
    # the tile is magnified by a whole number k: count game pixels (blocks of k x k)
    rows = np.nonzero((np.abs(np.diff(ia[:, 240], axis=0)).max(axis=1) > 0))[0]
    k = 1
    if rows.size > 1:
        gaps = np.diff(rows)
        k = int(np.min(gaps[gaps > 0])) if (gaps > 0).any() else 1
    changed = (np.abs(ia - ib).max(axis=2) > 24) & car
    print("%-6s %s->%s  k=%d  car %5.0f px  changed %4.0f px  %5.1f %%" % (
        m, a, b, k, car.sum() / k / k, changed.sum() / k / k, 100.0 * changed.sum() / max(1, car.sum())))
