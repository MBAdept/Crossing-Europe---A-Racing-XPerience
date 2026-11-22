#!/usr/bin/env python3
"""R7a: triptych Arcade | Modern Basis | Modern R7a from two A/B sheets (tools/ab_shot.sh *_ab_NN.jpg).
usage: tri.py <mine_ab.jpg> <base_ab.jpg> <out.jpg> <title>"""
import sys
from PIL import Image, ImageDraw, ImageFont

mine = Image.open(sys.argv[1]).convert("RGB")
base = Image.open(sys.argv[2]).convert("RGB")
W, H = mine.size
half = W // 2
arc = mine.crop((0, 0, half, H))
new = mine.crop((half, 0, W, H))
old = base.crop((base.size[0] // 2, 0, base.size[0], base.size[1])).resize(new.size)
out = Image.new("RGB", (half * 3, H + 34), (16, 20, 36))
out.paste(arc, (0, 34))
out.paste(old, (half, 34))
out.paste(new, (half * 2, 34))
d = ImageDraw.Draw(out)
try:
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except OSError:
    f = ImageFont.load_default()
for i, t in enumerate(["Arcade", "Modern Basis (RINT-M2)", "Modern R7a (Sichtkorridor A-17)"]):
    d.text((i * half + 12, 6), t, fill=(240, 240, 240), font=f)
d.text((half * 3 - 12 - d.textlength(sys.argv[4], font=f), 6), sys.argv[4], fill=(255, 210, 90), font=f)
s = 2400 / out.size[0]
out = out.resize((2400, int(out.size[1] * s)), Image.LANCZOS)
out.save(sys.argv[3], quality=88)
print("wrote", sys.argv[3])
