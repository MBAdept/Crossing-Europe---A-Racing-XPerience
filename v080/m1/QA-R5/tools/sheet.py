#!/usr/bin/env python3
"""sheet.py <out.jpg> <title> <label=png> ...: full frames side by side (each scaled to 50 %), labelled - the
deliverable A/B(/base) sheets of QA-R5."""
import sys
from PIL import Image, ImageDraw

out, title = sys.argv[1], sys.argv[2]
tiles = []
for arg in sys.argv[3:]:
    lbl, path = arg.split('=', 1)
    try:
        im = Image.open(path).convert('RGB')
    except Exception:
        continue
    im = im.resize((im.width * 3 // 5, im.height * 3 // 5), Image.LANCZOS)
    t = Image.new('RGB', (im.width, im.height + 24), (17, 17, 17))
    t.paste(im, (0, 24))
    ImageDraw.Draw(t).text((8, 5), lbl, fill=(255, 255, 255))
    tiles.append(t)
W = sum(t.width for t in tiles) + 4 * (len(tiles) - 1)
H = max(t.height for t in tiles) + 22
sheet = Image.new('RGB', (W, H), (40, 40, 40))
ImageDraw.Draw(sheet).text((8, H - 17), title, fill=(220, 220, 220))
xo = 0
for t in tiles:
    sheet.paste(t, (xo, 0))
    xo += t.width + 4
sheet.save(out, quality=88)
print(out, sheet.size)
