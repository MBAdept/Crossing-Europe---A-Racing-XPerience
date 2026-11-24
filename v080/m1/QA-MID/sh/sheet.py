#!/usr/bin/env python3
"""QA-MID: contact sheets of a run's shots – sheet.py <shots dir of a tag> <out jpg> [cols]: 4 columns of 400x225 thumbs
with the km in the corner (the HUD stays: it shows hour, weather and km)."""
import sys, os, re
from PIL import Image, ImageDraw, ImageFont
d, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
fs = sorted(f for f in os.listdir(d) if f.endswith(".png"))
if not fs:
    sys.exit(0)
tw, th = 400, 225
rows = (len(fs) + cols - 1) // cols
sheet = Image.new("RGB", (cols * tw + (cols - 1) * 4, rows * th + (rows - 1) * 4 + 28), (16, 20, 34))
dr = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
    big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
except OSError:
    font = big = ImageFont.load_default()
dr.text((6, 4), os.path.basename(os.path.normpath(d)), fill=(235, 235, 235), font=big)
for i, f in enumerate(fs):
    im = Image.open(os.path.join(d, f)).convert("RGB").resize((tw, th))
    x = (i % cols) * (tw + 4); y = 28 + (i // cols) * (th + 4)
    sheet.paste(im, (x, y))
    m = re.search(r"km(\d+\.\d)", f)
    lab = ("km " + m.group(1).lstrip("0")) if m else f
    dr.rectangle((x, y + th - 22, x + 90, y + th), fill=(0, 0, 0))
    dr.text((x + 4, y + th - 21), lab, fill=(255, 230, 120), font=font)
sheet.save(out, quality=82)
print(out, len(fs))
