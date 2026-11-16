#!/usr/bin/env python3
"""QA-M2-BILD: crops of the injected test cars (vehicle probe) – Arcade | ZS1 | M2 side by side, one row per car.
usage: vehcrop.py <veh dir> <hour 12|22> <out.jpg> [scenes…]   scenes default d20a d20b d20c d60a d60b d60c d150a d150b d150c
Screen positions come from the M2 log (QA-VEH lines, world_to_screen of the car centre at 0.7 m)."""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

d, hour, out = sys.argv[1], sys.argv[2], sys.argv[3]
scenes = sys.argv[4:] or ["d20a", "d20b", "d20c", "d60a", "d60b", "d60c", "d150a", "d150b", "d150c"]
cols = [("Arcade", "arc_h%s" % hour), ("ZS1", "zs1_h%s" % hour), ("vorher 6e48405", "m2_h%s" % hour), ("FIX-M2 515dd51", "nm2_h%s" % hour)]
pos = {}
for line in open(os.path.join(d, "m2_h%s.log" % hour), errors="replace"):
    m = re.match(r"QA-VEH (\w+) (\[.*\])\s*$", line)
    if m:
        pos[m.group(1)] = json.loads(m.group(2))
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
except Exception:  # noqa
    font = ImageFont.load_default()
TILE = (240, 152)
rows = []
for sc in scenes:
    for car in pos.get(sc, []):
        if "screen" not in car:
            continue
        x, y, dep = car["screen"]
        dist = car["z"]
        half_w = max(24, int(2600 / max(dist, 8)))       # window scales with 1/distance
        half_h = int(half_w * 0.62)
        box = (int(x - half_w), int(y - half_h * 1.15), int(x + half_w), int(y + half_h * 0.85))
        tiles = []
        for lab, tag in cols:
            p = os.path.join(d, "%s_%s.png" % (tag, sc))
            if not os.path.exists(p):
                tiles.append(None)
                continue
            im = Image.open(p).convert("RGB").crop(box).resize(TILE, Image.NEAREST)
            tiles.append(im)
        rows.append(("%s %s %.0f m" % (sc, car["set"].split("/")[-1], dist), tiles))
W = 160 + len(cols) * (TILE[0] + 4)
H = 24 + len(rows) * (TILE[1] + 4)
sheet = Image.new("RGB", (W, H), (16, 24, 44))
dr = ImageDraw.Draw(sheet)
for i, (lab, _) in enumerate(cols):
    dr.text((160 + i * (TILE[0] + 4) + 6, 4), lab + " (%s Uhr)" % hour, fill=(235, 240, 250), font=font)
for r, (lab, tiles) in enumerate(rows):
    y0 = 24 + r * (TILE[1] + 4)
    dr.text((6, y0 + 6), lab, fill=(235, 240, 250), font=font)
    for i, t in enumerate(tiles):
        if t is not None:
            sheet.paste(t, (160 + i * (TILE[0] + 4), y0))
sheet.save(out, quality=88)
print(out, len(rows), "rows")
