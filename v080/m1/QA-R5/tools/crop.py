#!/usr/bin/env python3
"""crop.py <out.jpg> <x,y,w,h> <scale> <label=png> ... : the same crop of several pictures side by side, labelled."""
import sys
from PIL import Image, ImageDraw

out = sys.argv[1]
x, y, w, h = [int(v) for v in sys.argv[2].split(',')]
sc = float(sys.argv[3])
tiles = []
for arg in sys.argv[4:]:
    lbl, path = arg.split('=', 1) if '=' in arg else (arg.rsplit('/', 1)[-1], arg)
    im = Image.open(path).convert('RGB').crop((x, y, x + w, y + h))
    if sc != 1.0:
        im = im.resize((int(w * sc), int(h * sc)), Image.LANCZOS)
    t = Image.new('RGB', (im.width, im.height + 22), (17, 17, 17))
    t.paste(im, (0, 22))
    ImageDraw.Draw(t).text((6, 4), lbl, fill=(255, 255, 255))
    tiles.append(t)
W = sum(t.width for t in tiles) + 4 * (len(tiles) - 1)
H = max(t.height for t in tiles)
sheet = Image.new('RGB', (W, H), (40, 40, 40))
xo = 0
for t in tiles:
    sheet.paste(t, (xo, 0))
    xo += t.width + 4
sheet.save(out, quality=90)
print(out, sheet.size)
