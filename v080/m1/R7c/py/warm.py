#!/usr/bin/env python3
"""R7c: lit (warm) window pixels and mean luma in regions of game frames.  warm.py <png> [<png> ...]
Regions: left building, right buildings, centre (1280x720 frames, HUD left out as far as possible)."""
import sys
import numpy as np
from PIL import Image

BOXES = {"links": (0, 180, 330, 520), "rechts": (780, 130, 1280, 420), "mitte": (330, 150, 780, 330)}


def warm(p, box):
    im = np.array(Image.open(p).convert("RGB")).astype(int)
    x0, y0, x1, y1 = box
    r = im[y0:y1, x0:x1]
    R, G, B = r[..., 0], r[..., 1], r[..., 2]
    m = (R > 170) & (G > 120) & (R - B > 50)
    return int(m.sum()), round(float(np.mean(0.2126 * R + 0.7152 * G + 0.0722 * B)), 1)


for p in sys.argv[1:]:
    print(p.split("/shots/")[-1], "  ".join("%s %s" % (k, warm(p, b)) for k, b in BOXES.items()))
