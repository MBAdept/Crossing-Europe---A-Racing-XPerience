#!/usr/bin/env python3
"""M2INT look review: 2x2 panel per position - Arcade | Modern ZS1 (gate1 sheet) / Modern M2INT | |M2INT - ZS1| x 4.
usage: quad.py <absheet_dir> <pos> <preset: high|auto> <out.jpg>
The ZS1 Modern half is cut from deliver/gate1/ab_boegen/<pos>_<hoch|rechner_niedrig>_00.jpg (x 1286.., y 44..764)."""
import sys
from PIL import Image, ImageChops, ImageDraw

D, POS, PR, OUT = sys.argv[1:5]
GATE = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/gate1/ab_boegen"
zs1_name = {"high": "hoch", "auto": "rechner_niedrig"}[PR]
arc = Image.open(f"{D}/{POS}_{PR}_arcade_00.png").convert("RGB")
mod = Image.open(f"{D}/{POS}_{PR}_modern_00.png").convert("RGB")
try:
    sheet = Image.open(f"{GATE}/{POS}_{zs1_name}_00.jpg").convert("RGB")
    zs1 = sheet.crop((1286, 44, 1286 + 1280, 44 + 720))
except FileNotFoundError:
    zs1 = Image.new("RGB", (1280, 720), (40, 0, 0))
diff = ImageChops.difference(mod, zs1).point(lambda v: min(255, v * 4))
W, H = 960, 540
out = Image.new("RGB", (2 * W + 6, 2 * H + 6 + 2 * 26), (16, 24, 44))
dr = ImageDraw.Draw(out)
panels = [(arc, "Arcade"), (zs1, "Modern ZS1 (gate1)"), (mod, "Modern M2INT"), (diff, "|M2INT - ZS1| x4")]
for i, (im, label) in enumerate(panels):
    x = (i % 2) * (W + 6)
    y = (i // 2) * (H + 6 + 26)
    dr.text((x + 8, y + 6), f"{POS} {PR}: {label}", fill=(230, 235, 245))
    out.paste(im.resize((W, H), Image.LANCZOS), (x, y + 26))
out.save(OUT, quality=88)
print(OUT)
