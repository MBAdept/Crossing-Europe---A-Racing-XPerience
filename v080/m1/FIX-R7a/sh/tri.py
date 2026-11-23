#!/usr/bin/env python3
"""FIX-R7a: side-by-side sheet of n pictures with labels. tri.py <out.jpg> <scale> <label=png>..."""
import sys
from PIL import Image, ImageDraw

out = sys.argv[1]
scale = float(sys.argv[2])
items = [a.split("=", 1) for a in sys.argv[3:]]
ims = []
for label, path in items:
    im = Image.open(path).convert("RGB")
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    ims.append((label, im))
w = sum(im.width for _, im in ims) + 4 * (len(ims) - 1)
h = max(im.height for _, im in ims) + 22
sheet = Image.new("RGB", (w, h), (20, 20, 20))
d = ImageDraw.Draw(sheet)
x = 0
for label, im in ims:
    sheet.paste(im, (x, 22))
    d.text((x + 6, 4), label, fill=(255, 255, 255))
    x += im.width + 4
sheet.save(out, quality=90)
print(out)
