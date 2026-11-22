#!/usr/bin/env python3
"""R7c: Arcade | Basis | R7c side by side with labels.  three_up.py <arcade.png> <base_modern.png> <r7c_modern.png> <out.jpg> [title]"""
import sys

from PIL import Image, ImageDraw, ImageFont

a, b, c, out = sys.argv[1:5]
title = sys.argv[5] if len(sys.argv) > 5 else ""
ims = [Image.open(p).convert("RGB") for p in (a, b, c)]
w, h = ims[0].size
W = w * 3 // 2
H = h // 2
canvas = Image.new("RGB", (W, H + 36), (16, 20, 32))
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
except OSError:
    font = ImageFont.load_default()
d = ImageDraw.Draw(canvas)
for i, (im, lab) in enumerate(zip(ims, ["Arcade", "Modern Basis (RINT-M2)", "Modern R7c"])):
    canvas.paste(im.resize((w // 2, h // 2)), (i * w // 2, 36))
    d.text((i * w // 2 + 10, 8), lab, fill=(240, 240, 240), font=font)
if title:
    d.text((W - 10 - d.textlength(title, font=font), 8), title, fill=(200, 200, 120), font=font)
canvas.save(out, quality=88)
