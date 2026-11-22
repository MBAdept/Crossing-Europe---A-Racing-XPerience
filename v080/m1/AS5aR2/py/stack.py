"""AS5aR2: stack crops vertically with a label strip each: python3 stack.py <out> <width> <img>|<x0,y0,x1,y1|->|<label> ..."""
import sys

from PIL import Image, ImageDraw, ImageFont

out, width = sys.argv[1], int(sys.argv[2])
parts = []
for spec in sys.argv[3:]:
    path, crop, label = spec.split("|", 2)
    im = Image.open(path).convert("RGB")
    if crop != "-":
        im = im.crop([int(v) for v in crop.split(",")])
    if im.width != width:
        im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    parts.append((im, label))
try:
    f = ImageFont.truetype("DejaVuSans.ttf", 22)
except OSError:
    f = ImageFont.load_default()
H = sum(p[0].height + 34 for p in parts)
canvas = Image.new("RGB", (width, H), (27, 31, 39))
y = 0
d = ImageDraw.Draw(canvas)
for im, label in parts:
    d.text((10, y + 6), label, fill=(255, 255, 255), font=f)
    y += 34
    canvas.paste(im, (0, y))
    y += im.height
canvas.save(out, quality=88)
print(out, canvas.size)
