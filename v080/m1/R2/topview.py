#!/usr/bin/env python3
"""Top views of the terrain at the reference positions from the dumps of tests/race3d/check_terrain_plan.gd.
usage: topview.py <plan_Tn.json> <out.png> [title]"""
import json
import math
import sys
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
W, H = 1500, 1100
PAD = 40
pts = []
for ch in d["chunks"]:
    for row in ch["rings"]:
        for p in row:
            pts.append((p[0], p[1]))
xs = [p[0] for p in pts]
zs = [p[1] for p in pts]
x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
scale = min((W - 2 * PAD) / (x1 - x0), (H - 2 * PAD - 60) / (z1 - z0))
cx, cz = (x0 + x1) / 2, (z0 + z1) / 2


def px(x, z):
    # world -Z (heading 0) points up in the picture
    return (W / 2 + (x - cx) * scale, (H + 40) / 2 + (z - cz) * scale)


far_y = d["far_y"]
img = Image.new("RGB", (W, H), (176, 196, 150))        # the far ground (pale: it is what lies beyond the ribbons)
dr = ImageDraw.Draw(img, "RGBA")
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
    big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
except OSError:
    font = small = big = ImageFont.load_default()

low = min(p[2] for ch in d["chunks"] for row in ch["rings"] for p in row)
high = max(p[2] for ch in d["chunks"] for row in ch["rings"] for p in row)


def shade(y, chunk):
    # height above the far ground: dark green low, light green high; chunks alternate slightly
    t = 0.0 if high == low else (y - low) / (high - low)
    g = 95 + 120 * t
    k = 1.0 if chunk % 2 == 0 else 0.93
    return (int((40 + 70 * t) * k), int(g * k), int((35 + 45 * t) * k), 255)


for ch in d["chunks"]:
    n = ch["ring_count"]
    rows = ch["rows"]
    rings = ch["rings"]
    for si in range(2):
        for i in range(rows - 1):
            if ch["road"][i][5]:
                continue                       # tunnel: no terrain
            a = rings[si * rows + i]
            b = rings[si * rows + i + 1]
            for r in range(n - 1):
                quad = [px(a[r][0], a[r][1]), px(a[r + 1][0], a[r + 1][1]), px(b[r + 1][0], b[r + 1][1]), px(b[r][0], b[r][1])]
                y = (a[r][2] + a[r + 1][2] + b[r + 1][2] + b[r][2]) / 4
                col = shade(y, ch["index"])
                if ch["road"][i][6]:
                    col = (70, 110, 140, 255)  # water
                dr.polygon(quad, fill=col)
    # ring lines and the outer edge
    for si in range(2):
        for r in range(n):
            line = [px(rings[si * rows + i][r][0], rings[si * rows + i][r][1]) for i in range(rows)]
            dr.line(line, fill=(20, 50, 20, 200 if r == n - 1 else 70), width=2 if r == n - 1 else 1)
        for i in (0,):
            row = rings[si * rows + i]
            dr.line([px(row[0][0], row[0][1]), px(row[n - 1][0], row[n - 1][1])], fill=(255, 255, 255, 110), width=1)
for ch in d["chunks"]:
    road = ch["road"]
    for i in range(len(road) - 1):
        a, b = road[i], road[i + 1]
        col = (40, 40, 44, 255) if a[5] else (95, 96, 104, 255)
        dr.polygon([px(a[0], a[1]), px(a[2], a[3]), px(b[2], b[3]), px(b[0], b[1])], fill=col)
counts = {"kept": 0, "corridor": 0, "ribbon": 0, "density": 0}
for ch in d["chunks"]:
    for p in ch["props"]:
        x, y = px(p[0], p[1])
        cls, reason, kind = p[2], p[3], p[4]
        if reason:
            counts[reason] = counts.get(reason, 0) + 1
            col = (220, 40, 40, 255) if reason == "corridor" else (240, 150, 30, 255)
            dr.line([(x - 4, y - 4), (x + 4, y + 4)], fill=col, width=2)
            dr.line([(x - 4, y + 4), (x + 4, y - 4)], fill=col, width=2)
            continue
        counts["kept"] += 1
        if cls in ("tree", "plant"):
            r = 4 if cls == "tree" else 2
            dr.ellipse([x - r, y - r, x + r, y + r], fill=(10, 60, 20, 255) if kind == 1 else (30, 110, 60, 255), outline=(0, 0, 0, 255))
        elif cls in ("building", "landmark"):
            dr.rectangle([x - 4, y - 4, x + 4, y + 4], fill=(170, 80, 60, 255), outline=(0, 0, 0, 255))
        elif cls == "rock":
            dr.polygon([(x, y - 4), (x + 4, y + 3), (x - 4, y + 3)], fill=(130, 130, 130, 255), outline=(0, 0, 0, 255))
        else:
            dr.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(200, 200, 210, 255), outline=(0, 0, 0, 255))
# camera and its view (focal 711 px at 1280 px width: half angle 42 degrees) up to the visibility
cam = d["camera"]
fx, fz = d["forward"]
ang = math.atan2(fx, -fz)
vis = d["visibility_m"]
c = px(cam[0], cam[1])
for da in (-math.atan(640 / 711), math.atan(640 / 711)):
    a = ang + da
    e = px(cam[0] + math.sin(a) * vis, cam[1] - math.cos(a) * vis)
    dr.line([c, e], fill=(255, 255, 255, 230), width=2)
arc = [px(cam[0] + math.sin(ang + t) * vis, cam[1] - math.cos(ang + t) * vis) for t in [(-0.733 + 1.466 * i / 40) for i in range(41)]]
dr.line(arc, fill=(255, 255, 255, 160), width=1)
dr.ellipse([c[0] - 6, c[1] - 6, c[0] + 6, c[1] + 6], fill=(255, 220, 0, 255), outline=(0, 0, 0, 255))
# title, scale bar, legend
title = sys.argv[3] if len(sys.argv) > 3 else d["id"]
dr.rectangle([0, 0, W, 54], fill=(16, 24, 44, 255))
dr.text((14, 6), "%s – %s km %.1f: Gelände in der Draufsicht (%d Stücke, Sicht %d m)" % (title, d["direction"].replace("__", " ab "), d["km"], len(d["chunks"]), vis),
        fill=(255, 255, 255, 255), font=big)
dr.text((14, 32), "Höhen %.0f … %.0f m, Fernboden %.1f m · Requisiten: %d gezeichnet, %d im Kurvenkorridor (rot ×), %d jenseits des Bands (orange ×)"
        % (low, high, far_y, counts["kept"], counts["corridor"], counts["ribbon"]), fill=(200, 210, 230, 255), font=small)
bar = 200
dr.line([(W - 60 - bar * scale, H - 30), (W - 60, H - 30)], fill=(0, 0, 0, 255), width=4)
dr.text((W - 60 - bar * scale, H - 52), "200 m", fill=(0, 0, 0, 255), font=font)
legend = [("dunkel = tief, hell = hoch; Stücke abwechselnd getönt; dunkle Linie = Außenkante (Talsohle, Schürze)", (20, 50, 20)),
          ("blass = Fernboden (Ebene %.1f m; schließt Spalt an der Mittelachse und Loch im Kurvenmittelpunkt)" % far_y, (90, 110, 70)),
          ("gelb = Kamera, weiß = Bildausschnitt bis zur Sichtweite", (120, 100, 0))]
for i, (t, col) in enumerate(legend):
    dr.text((14, H - 62 + i * 18), t, fill=col + (255,), font=small)
img.save(out)
print(out, counts)
