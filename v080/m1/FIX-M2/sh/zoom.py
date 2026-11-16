#!/usr/bin/env python3
"""QA-M2-BILD: same box from several pictures, enlarged side by side, with labels and signal-pixel counts.
usage: zoom.py <out.jpg> <scale> <x0,y0,x1,y1> <label=path> [label=path …]"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

out, scale, box = sys.argv[1], int(sys.argv[2]), tuple(int(v) for v in sys.argv[3].split(","))
items = [a.split("=", 1) for a in sys.argv[4:]]
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
except Exception:  # noqa
    font = ImageFont.load_default()
w, h = (box[2] - box[0]) * scale, (box[3] - box[1]) * scale
sheet = Image.new("RGB", (len(items) * (w + 4), h + 24), (16, 24, 44))
dr = ImageDraw.Draw(sheet)
for i, (lab, p) in enumerate(items):
    im = Image.open(p).convert("RGB").crop(box)
    a = np.asarray(im).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    red = int(((r > 170) & (g < 110) & (b < 110)).sum())
    blue = int(((b > 160) & (b - r > 50) & (b - g > 20)).sum())
    lum = (0.2126 * r + 0.7152 * g + 0.0722 * b)
    print("%s red=%d blue=%d lum=%.0f px>200=%d" % (lab, red, blue, lum.mean(), int((lum > 200).sum())))
    sheet.paste(im.resize((w, h), Image.NEAREST), (i * (w + 4), 24))
    dr.text((i * (w + 4) + 6, 4), "%s  rot %d" % (lab, red), fill=(235, 240, 250), font=font)
sheet.save(out, quality=90)
print(out)
