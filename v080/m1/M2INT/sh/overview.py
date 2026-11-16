#!/usr/bin/env python3
"""M2INT look review: one overview of a preset - per position a row Arcade | Modern ZS1 (gate1) | Modern M2INT.
usage: overview.py <absheet_dir> <preset: high|auto> <out.jpg> [positions...]"""
import sys
from PIL import Image, ImageDraw

D, PR, OUT = sys.argv[1:4]
POS = sys.argv[4:] or ["S1", "S2", "S3", "S4", "S5", "T1", "T4", "C1", "N1", "N2"]
GATE = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/gate1/ab_boegen"
zs1_name = {"high": "hoch", "auto": "rechner_niedrig"}[PR]
W, H, L = 640, 360, 18
out = Image.new("RGB", (3 * W + 8, len(POS) * (H + L + 4)), (16, 24, 44))
dr = ImageDraw.Draw(out)
for r, pos in enumerate(POS):
    y = r * (H + L + 4)
    try:
        arc = Image.open(f"{D}/{pos}_{PR}_arcade_00.png").convert("RGB")
        mod = Image.open(f"{D}/{pos}_{PR}_modern_00.png").convert("RGB")
    except FileNotFoundError:
        continue
    try:
        zs1 = Image.open(f"{GATE}/{pos}_{zs1_name}_00.jpg").convert("RGB").crop((1286, 44, 1286 + 1280, 764))
    except FileNotFoundError:
        zs1 = Image.new("RGB", (1280, 720), (40, 0, 0))
    for c, (im, label) in enumerate([(arc, "Arcade"), (zs1, "Modern ZS1"), (mod, "Modern M2INT")]):
        x = c * (W + 4)
        dr.text((x + 6, y + 3), f"{pos} {PR}: {label}", fill=(230, 235, 245))
        out.paste(im.resize((W, H), Image.LANCZOS), (x, y + L))
out.save(OUT, quality=85)
print(OUT, out.size)
