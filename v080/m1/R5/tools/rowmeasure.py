#!/usr/bin/env python3
"""R5: mean luminance (0-255, Rec. 709 luma of the sRGB values) of the pylon region of M2ZS1's night row
(x 500-780, y 150-350 at 1280 x 720; at 1280 x 800 the Arcade picture has bars: the region 40 rows lower).
usage: rowmeasure.py <dir> <prefix> [deck]   -> one line per shot: NN arcade modern"""
import sys, glob, os
from PIL import Image

def mean_lum(path, dy=0):
    im = Image.open(path).convert('RGB')
    box = (500, 150 + dy, 780, 350 + dy)
    px = list(im.crop(box).getdata())
    s = 0.0
    for r, g, b in px:
        s += 0.2126 * r + 0.7152 * g + 0.0722 * b
    return s / len(px)

d, prefix = sys.argv[1], sys.argv[2]
deck = len(sys.argv) > 3 and sys.argv[3] == 'deck'
for m in sorted(glob.glob(os.path.join(d, prefix + '_modern_[0-9][0-9].png'))):
    nn = m[-6:-4]
    a = os.path.join(d, prefix + '_arcade_' + nn + '.png')
    la = mean_lum(a, 40 if deck else 0) if os.path.exists(a) else float('nan')
    lm = mean_lum(m, 0)
    print('%s %s arcade %.1f modern %.1f' % (prefix, nn, la, lm))
