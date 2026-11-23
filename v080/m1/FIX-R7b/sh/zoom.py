#!/usr/bin/env python3
# zoom.py <out.png> <x> <y> <w> <h> <scale> <label=file> ... : crops of the same box side by side, labelled
import sys
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1]
x, y, w, h = map(int, sys.argv[2:6])
sc = float(sys.argv[6])
items = [a.split('=', 1) for a in sys.argv[7:]]
tiles = []
for lab, f in items:
    im = Image.open(f).convert('RGB').crop((x, y, x + w, y + h))
    im = im.resize((int(w * sc), int(h * sc)), Image.NEAREST)
    t = Image.new('RGB', (im.width, im.height + 26), (16, 24, 44))
    t.paste(im, (0, 26))
    d = ImageDraw.Draw(t)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
    except Exception:
        font = None
    d.text((6, 4), lab, fill=(255, 255, 255), font=font)
    tiles.append(t)
W = sum(t.width for t in tiles) + 6 * (len(tiles) - 1)
H = max(t.height for t in tiles)
sheet = Image.new('RGB', (W, H), (16, 24, 44))
cx = 0
for t in tiles:
    sheet.paste(t, (cx, 0))
    cx += t.width + 6
sheet.save(out)
print(out, sheet.size)
