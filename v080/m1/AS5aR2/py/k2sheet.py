#!/usr/bin/env python3
"""AS5aR2 K2 diagnosis sheet: lod0 at 60 m and 250 m with the shadows of the race (high, 200 m), with a shadow reach of
1000 m and without shadows, next to the sprite. Tiles cut from the lodcol sheets (320x260, cols lod0/lod1/sprite)."""
import sys
from PIL import Image, ImageDraw, ImageFont

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2"
out = sys.argv[1]
TW, TH = 320, 260
models = ["city_paris_haussmann", "city_swiss_chalet", "city_swiss_laube", "city_french_sud", "city_belgian_stone"]
pick = [0, 1, 2]  # Haussmann, Chalet, Lauben
dists = [0, 2]    # 60 m, 250 m
sheets = {k: Image.open(f"{S}/shots/k2/lodcol_{k}.png").convert("RGB") for k in ("race", "far", "off")}
cols = [("race", 0, "Rennen (Schatten bis 200 m)"), ("far", 0, "Schatten bis 1000 m"), ("off", 0, "ohne Schatten"),
        ("race", 2, "Sprite (Arcade)")]
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
except OSError:
    font = big = ImageFont.load_default()
head = 56
img = Image.new("RGB", (TW * len(cols), head + TH * len(pick) * len(dists)), (24, 28, 36))
d = ImageDraw.Draw(img)
d.text((8, 6), "K2-Ursache: Fernblässe kommt vom Ende der Echtzeitschatten, nicht von der Mip-Kette (lod0, 12 Uhr, Hoch)",
       fill=(240, 240, 240), font=big)
for c, (k, col, label) in enumerate(cols):
    d.text((c * TW + 8, 32), label, fill=(220, 220, 160), font=font)
r = 0
for m in pick:
    for di in dists:
        row = m * 3 + di
        for c, (k, col, label) in enumerate(cols):
            tile = sheets[k].crop((col * TW, row * TH, (col + 1) * TW, (row + 1) * TH))
            img.paste(tile, (c * TW, head + r * TH))
        r += 1
img.save(out, quality=90)
print(out, img.size)
