#!/usr/bin/env python3
"""R7D: Modern at the base (720eaf4) | Modern at the head, one sheet per position: base_sheet.py <base dir> <head dir> <out dir>
(the *_modern_00.png of tools/ab_shot.sh in both)."""
import sys, os, re
from PIL import Image, ImageDraw, ImageFont
bd, hd, od = sys.argv[1:4]
os.makedirs(od, exist_ok=True)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except OSError:
    font = ImageFont.load_default()
n = 0
for f in sorted(os.listdir(bd)):
    m = re.match(r"(.+)_modern_00\.png$", f)
    if not m or not os.path.exists(os.path.join(hd, f)):
        continue
    a = Image.open(os.path.join(bd, f)).convert("RGB")
    b = Image.open(os.path.join(hd, f)).convert("RGB")
    w, h = a.size
    sheet = Image.new("RGB", (2 * w + 6, h + 34), (16, 20, 34))
    sheet.paste(a, (0, 34)); sheet.paste(b, (w + 6, 34))
    d = ImageDraw.Draw(sheet)
    for x, t in ((w // 2, "Modern vor R7d (720eaf4)"), (w + 6 + w // 2, "Modern R7d")):
        tw = d.textlength(t, font=font)
        d.text((x - tw / 2, 5), t, fill=(235, 235, 235), font=font)
    sheet.save(os.path.join(od, m.group(1) + "_basis_kopf.jpg"), quality=88)
    n += 1
print(f"{n} Bögen in {od}")
