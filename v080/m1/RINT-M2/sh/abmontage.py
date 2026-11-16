#!/usr/bin/env python3
"""RINT-M2: stack A/B sheets (Arcade | Modern jpgs of tools/ab_shot.sh) for looking at them.
usage: abmontage.py <out.jpg> <width> <file> [file ...]"""
import sys
from PIL import Image

out, width = sys.argv[1], int(sys.argv[2])
ims = []
for f in sys.argv[3:]:
    im = Image.open(f).convert("RGB")
    h = int(im.height * width / im.width)
    ims.append(im.resize((width, h)))
H = sum(i.height for i in ims) + 6 * (len(ims) - 1)
O = Image.new("RGB", (width, H), (255, 255, 255))
y = 0
for i in ims:
    O.paste(i, (0, y))
    y += i.height + 6
O.save(out, quality=88)
print(out, O.size)
