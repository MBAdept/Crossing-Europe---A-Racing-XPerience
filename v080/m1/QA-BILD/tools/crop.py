#!/usr/bin/env python3
"""Side-by-side crop of two (or more) pictures, scaled with nearest neighbour, labelled.
usage: crop.py out.png x0 y0 x1 y1 scale img1[@label] img2[@label] ..."""
import sys
from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
scale = float(sys.argv[6])
items = sys.argv[7:]
crops = []
for it in items:
    if "@" in it:
        path, label = it.rsplit("@", 1)
    else:
        path, label = it, it.rsplit("/", 1)[-1]
    im = Image.open(path).convert("RGB").crop((x0, y0, x1, y1))
    im = im.resize((int((x1 - x0) * scale), int((y1 - y0) * scale)), Image.NEAREST)
    crops.append((im, label))
w = sum(c[0].width for c in crops) + 6 * (len(crops) - 1)
h = crops[0][0].height + 24
canvas = Image.new("RGB", (w, h), (16, 24, 44))
d = ImageDraw.Draw(canvas)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
except Exception:
    font = None
x = 0
for im, label in crops:
    canvas.paste(im, (x, 24))
    d.text((x + 4, 4), label, fill=(255, 255, 255), font=font)
    x += im.width + 6
canvas.save(out)
print(out, canvas.size)
