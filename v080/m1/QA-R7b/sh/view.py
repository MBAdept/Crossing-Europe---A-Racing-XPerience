#!/usr/bin/env python3
"""QA-R7b: viewing helper for picture triples.
  view.py full <prefix> <out.jpg> [scale]                 Arcade | base | head side by side, scaled (default 0.5)
  view.py crop <prefix> <out.png> x0 y0 x1 y1 [zoom]      the same crop of the three pictures, zoomed (default 2)
  view.py diff <prefix> <out.png>                        |head - base| amplified, with the changed bounding box printed
"""
import sys
from PIL import Image, ImageChops, ImageDraw

mode, pre, out = sys.argv[1], sys.argv[2], sys.argv[3]
names = [('Arcade', pre + '_arcade_00.png'), ('Basis', pre + '_basis_00.png'), ('R7b', pre + '_modern_00.png')]
imgs = []
for label, p in names:
    try:
        imgs.append((label, Image.open(p).convert('RGB')))
    except FileNotFoundError:
        pass
if mode == 'full':
    sc = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
    ims = [(l, i.resize((int(i.width * sc), int(i.height * sc)), Image.LANCZOS)) for l, i in imgs]
elif mode == 'crop':
    x0, y0, x1, y1 = map(int, sys.argv[4:8])
    z = float(sys.argv[8]) if len(sys.argv) > 8 else 2.0
    ims = [(l, i.crop((x0, y0, x1, y1)).resize((int((x1 - x0) * z), int((y1 - y0) * z)), Image.LANCZOS)) for l, i in imgs]
elif mode == 'diff':
    b = dict(imgs)
    d = ImageChops.difference(b['Basis'], b['R7b'])
    bbox = d.point(lambda v: 255 if v > 12 else 0).getbbox()
    px = sum(1 for v in d.convert('L').getdata() if v > 12)
    print('diff bbox', bbox, 'pixels>12', px)
    ims = [('|R7b-Basis| x4', d.point(lambda v: min(255, v * 4)))]
else:
    sys.exit(2)
w = sum(i.width for _, i in ims) + 6 * (len(ims) - 1)
h = max(i.height for _, i in ims) + 22
canvas = Image.new('RGB', (w, h), (16, 24, 44))
dr = ImageDraw.Draw(canvas)
x = 0
for l, i in ims:
    canvas.paste(i, (x, 22))
    dr.text((x + 6, 4), l, fill=(255, 255, 255))
    x += i.width + 6
canvas.save(out, quality=90)
print(out, canvas.size)
