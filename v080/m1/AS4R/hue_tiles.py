"""AS4R scratch (M3): pane hues per building in two close-up composites (640x360 tiles).
python3 hue_tiles.py <before.png> <cols_before> <after.png> <cols_after> <names,comma> [views]
Columns of the reviewer: front,oblique,road,roof,back; mine: front,oblique,road,back. Compared: front,oblique,road,back.
Dark pixels: max channel < 95 and max - min > 8 (coloured, not grey); brown 15-55 deg, blue 180-250 deg."""
import colorsys
import sys

import numpy as np
from PIL import Image

TW, TH = 640, 360
LABEL = 24  # skip the caption strip at the bottom of each tile


def shares(img, row, cols):
    sel_all = []
    for c in cols:
        t = img[row * TH:(row + 1) * TH - LABEL, c * TW:(c + 1) * TW].reshape(-1, 3)
        mx, mn = t.max(axis=1), t.min(axis=1)
        sel_all.append(t[(mx < 95) & (mx - mn > 8)])
    sel = np.concatenate(sel_all)
    if not len(sel):
        return 0, 0.0, 0.0
    h = np.array([colorsys.rgb_to_hsv(*(p / 255.0))[0] * 360.0 for p in sel[::4]])
    return len(sel), 100.0 * ((h >= 15) & (h <= 55)).mean(), 100.0 * ((h >= 180) & (h <= 250)).mean()


def main():
    a = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float64)
    b = np.asarray(Image.open(sys.argv[3]).convert("RGB"), dtype=np.float64)
    ca = [int(v) for v in sys.argv[2].split(",")]
    cb = [int(v) for v in sys.argv[4].split(",")]
    names = sys.argv[5].split(",")
    print("%-18s %28s %28s" % ("Modell", "vorher: n / braun / blau", "nachher: n / braun / blau"))
    for r, n in enumerate(names):
        na, ba, bla = shares(a, r, ca)
        nb, bb, blb = shares(b, r, cb)
        print("%-18s %10d %6.1f %% %6.1f %%   %10d %6.1f %% %6.1f %%" % (n, na, ba, bla, nb, bb, blb))


main()
