"""AS2b: LOD pop at the switch distance, measured as in AS1R / AS2a: share of the vehicle pixels that change by more
than 24 levels (any channel) when the level switches. Vehicle pixels: those that differ from the background (median
of their row over both tiles; the road is a vertical gradient) by more than 24 in either tile. The caption strip at
the bottom of a tile is left out.

usage: popmeasure.py <raw dir> name_a:name_b [...]"""
import sys

import numpy as np
from PIL import Image

CAPTION = 34          # px of the caption strip at the bottom of a contact-sheet tile
THR = 24


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def pop(a, b):
    h = min(a.shape[0], b.shape[0]) - CAPTION
    a, b = a[:h], b[:h]
    both = np.concatenate([a, b], axis=1)
    bg = np.median(both, axis=1, keepdims=True)
    car = (np.abs(a - bg).max(axis=2) > THR) | (np.abs(b - bg).max(axis=2) > THR)
    diff = np.abs(a - b).max(axis=2) > THR
    n = int(car.sum())
    return n, (float((diff & car).sum()) / n if n else 0.0)


def main():
    d = sys.argv[1]
    for pair in sys.argv[2:]:
        x, y = pair.split(":")
        n, f = pop(load("%s/%s.png" % (d, x)), load("%s/%s.png" % (d, y)))
        print("%-28s -> %-28s vehicle px %6d   changed %5.1f %%" % (x, y, n, 100.0 * f))


main()
