#!/usr/bin/env python3
"""Creates simple placeholder sprite sheets + manifest in the exact format of the Blender pipeline
(see ARCHITECTURE.md, section Sprites). Used until tools/blender renders the real assets.

Usage: python3 tools/placeholders/make_placeholders.py [output_dir]
Requires Pillow.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
ANGLES = ["l2", "l1", "c", "r1", "r2"]
manifest = {"version": 1, "generator": "placeholders", "sets": {}}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def car_cell(draw, ox, oy, cw, ch, angle, layer, body, width_m, height_m, img_w_m, heavy=False, police=None):
    ppm = cw / img_w_m
    w = width_m * ppm
    h = height_m * ppm
    base_y = oy + ch * 0.92
    cx = ox + cw / 2
    shift = {"l2": -0.22, "l1": -0.1, "c": 0.0, "r1": 0.1, "r2": 0.22}[angle]
    side = abs(shift) * w * 1.6
    x0 = cx - w / 2 - (side if shift < 0 else 0)
    x1 = cx + w / 2 + (side if shift > 0 else 0)
    if layer == "base":
        draw.ellipse([x0 - 4, base_y - 8, x1 + 4, base_y + 6], fill=(0, 0, 0, 70))
        if heavy:
            draw.rectangle([x0, base_y - h, x1, base_y - h * 0.12], fill=rgb(body))
            draw.rectangle([x0 + w * 0.08, base_y - h * 0.98, x1 - w * 0.08, base_y - h * 0.6], fill=rgb("#d9d9d9"))
        else:
            draw.rounded_rectangle([x0, base_y - h * 0.62, x1, base_y - h * 0.12], radius=int(h * 0.1), fill=rgb(body))
            rx0 = x0 + w * 0.16 + shift * w * 0.4
            rx1 = x1 - w * 0.16 + shift * w * 0.4
            draw.rounded_rectangle([rx0, base_y - h, rx1, base_y - h * 0.58], radius=int(h * 0.12), fill=rgb(body))
            draw.rectangle([rx0 + w * 0.05, base_y - h * 0.93, rx1 - w * 0.05, base_y - h * 0.64], fill=rgb("#26303a"))
        draw.rectangle([x0 + w * 0.06, base_y - h * 0.14, x0 + w * 0.22, base_y], fill=rgb("#151515"))
        draw.rectangle([x1 - w * 0.22, base_y - h * 0.14, x1 - w * 0.06, base_y], fill=rgb("#151515"))
        draw.rectangle([x0 + w * 0.05, base_y - h * 0.5, x0 + w * 0.2, base_y - h * 0.4], fill=rgb("#7a1010"))
        draw.rectangle([x1 - w * 0.2, base_y - h * 0.5, x1 - w * 0.05, base_y - h * 0.4], fill=rgb("#7a1010"))
        if police:
            draw.rectangle([x0, base_y - h * 0.42, x1, base_y - h * 0.32], fill=rgb(police))
            draw.rectangle([cx - w * 0.2, base_y - h * 1.08, cx + w * 0.2, base_y - h * 1.0], fill=rgb("#2b4fd8"))
    elif layer in ("tail", "brake"):
        a = 170 if layer == "tail" else 255
        for (lx0, lx1) in ((x0 + w * 0.05, x0 + w * 0.2), (x1 - w * 0.2, x1 - w * 0.05)):
            draw.rectangle([lx0 - 3, base_y - h * 0.52, lx1 + 3, base_y - h * 0.38], fill=(255, 40, 20, a // 2))
            draw.rectangle([lx0, base_y - h * 0.5, lx1, base_y - h * 0.4], fill=(255, 70, 40, a))
        if layer == "brake" and not heavy:
            draw.rectangle([cx - w * 0.1, base_y - h * 0.97, cx + w * 0.1, base_y - h * 0.93], fill=(255, 60, 40, 255))
    elif layer.startswith("beacon"):
        left = layer == "beacon_a"
        bx = cx - w * 0.12 if left else cx + w * 0.12
        draw.ellipse([bx - w * 0.16, base_y - h * 1.18, bx + w * 0.16, base_y - h * 0.9], fill=(60, 110, 255, 150))
        draw.ellipse([bx - w * 0.07, base_y - h * 1.09, bx + w * 0.07, base_y - h * 0.99], fill=(200, 220, 255, 255))


def make_vehicle(set_id, body, width_m, length_m, height_m, layers, tags, heavy=False, police=None, cell=(256, 200), img_w_m=2.9):
    cw, chh = cell
    img = Image.new("RGBA", (cw * len(ANGLES), chh * len(layers)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for row, layer in enumerate(layers):
        for col, angle in enumerate(ANGLES):
            car_cell(d, col * cw, row * chh, cw, chh, angle, layer, body, width_m, height_m, img_w_m, heavy, police)
    save(set_id, img, {
        "cell": [cw, chh], "angles": ANGLES, "layers": layers, "image_width_m": img_w_m,
        "anchor": [0.5, 0.92], "object": {"width_m": width_m, "length_m": length_m, "height_m": height_m}, "tags": tags,
    })


def save(set_id, img, meta):
    path = os.path.join(OUT, set_id + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    meta = dict(meta)
    meta["file"] = set_id + ".png"
    manifest["sets"][set_id] = meta


def make_prop(set_id, cell, img_w_m, painter, lights_painter=None, tags=None, obj=None):
    cw, chh = cell
    layers = ["base", "lights"] if lights_painter else ["base"]
    img = Image.new("RGBA", (cw, chh * len(layers)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ppm = cw / img_w_m
    painter(d, cw, chh, ppm, 0)
    if lights_painter:
        lights_painter(d, cw, chh, ppm, chh)
    save(set_id, img, {"cell": [cw, chh], "angles": ["c"], "layers": layers, "image_width_m": img_w_m,
                       "anchor": [0.5, 0.97], "object": obj or {}, "tags": tags or ["prop"]})


def tree(color, trunk="#5a3d22", crown="round", h_m=11.0, w_m=7.0):
    def p(d, cw, chh, ppm, oy):
        gy = oy + chh * 0.97
        cx = cw / 2
        d.ellipse([cx - w_m * 0.3 * ppm, gy - 6, cx + w_m * 0.3 * ppm, gy + 4], fill=(0, 0, 0, 60))
        d.rectangle([cx - 0.25 * ppm, gy - h_m * 0.45 * ppm, cx + 0.25 * ppm, gy], fill=rgb(trunk))
        if crown == "cone":
            for i in range(3):
                t = gy - h_m * (0.25 + i * 0.25) * ppm
                hw = w_m * (0.5 - i * 0.12) * ppm
                d.polygon([(cx - hw, t + h_m * 0.32 * ppm), (cx + hw, t + h_m * 0.32 * ppm), (cx, t - h_m * 0.1 * ppm)], fill=rgb(color))
        elif crown == "column":
            d.ellipse([cx - w_m * 0.25 * ppm, gy - h_m * ppm, cx + w_m * 0.25 * ppm, gy - h_m * 0.2 * ppm], fill=rgb(color))
        else:
            d.ellipse([cx - w_m * 0.5 * ppm, gy - h_m * ppm, cx + w_m * 0.5 * ppm, gy - h_m * 0.35 * ppm], fill=rgb(color))
    return p


def box(color, w_m, h_m, roof=None, windows=None):
    def p(d, cw, chh, ppm, oy):
        gy = oy + chh * 0.97
        cx = cw / 2
        d.rectangle([cx - w_m / 2 * ppm, gy - h_m * ppm, cx + w_m / 2 * ppm, gy], fill=rgb(color))
        if roof:
            d.polygon([(cx - w_m / 2 * ppm - 4, gy - h_m * ppm), (cx + w_m / 2 * ppm + 4, gy - h_m * ppm), (cx, gy - h_m * 1.45 * ppm)], fill=rgb(roof))
        if windows:
            rows = max(1, int(h_m / 3.2))
            cols = max(1, int(w_m / 3.0))
            for r in range(rows):
                for c in range(cols):
                    x0 = cx - w_m / 2 * ppm + (c + 0.3) * (w_m / cols) * ppm
                    y0 = gy - h_m * ppm + (r + 0.3) * (h_m / rows) * ppm
                    d.rectangle([x0, y0, x0 + 0.4 * (w_m / cols) * ppm, y0 + 0.35 * (h_m / rows) * ppm], fill=rgb(windows))
    return p


def window_lights(w_m, h_m):
    def p(d, cw, chh, ppm, oy):
        gy = oy + chh * 0.97
        cx = cw / 2
        rows = max(1, int(h_m / 3.2))
        cols = max(1, int(w_m / 3.0))
        for r in range(rows):
            for c in range(cols):
                if (r * 7 + c * 3) % 3 == 0:
                    continue
                x0 = cx - w_m / 2 * ppm + (c + 0.3) * (w_m / cols) * ppm
                y0 = gy - h_m * ppm + (r + 0.3) * (h_m / rows) * ppm
                d.rectangle([x0, y0, x0 + 0.4 * (w_m / cols) * ppm, y0 + 0.35 * (h_m / rows) * ppm], fill=(255, 214, 140, 235))
    return p


def pole(h_m, head=None, head_col="#c8c8c8", pole_col="#8a8f96"):
    def p(d, cw, chh, ppm, oy):
        gy = oy + chh * 0.97
        cx = cw / 2
        d.rectangle([cx - 0.08 * ppm, gy - h_m * ppm, cx + 0.08 * ppm, gy], fill=rgb(pole_col))
        if head:
            hw, hh = head
            d.rectangle([cx - hw / 2 * ppm, gy - h_m * ppm, cx + hw / 2 * ppm, gy - (h_m - hh) * ppm], fill=rgb(head_col))
    return p


def glow(cx_m, y_m, r_m, col=(255, 220, 150)):
    def p(d, cw, chh, ppm, oy):
        gy = oy + chh * 0.97
        cx = cw / 2 + cx_m * ppm
        y = gy - y_m * ppm
        d.ellipse([cx - r_m * 2.2 * ppm, y - r_m * 2.2 * ppm, cx + r_m * 2.2 * ppm, y + r_m * 2.2 * ppm], fill=col + (70,))
        d.ellipse([cx - r_m * ppm, y - r_m * ppm, cx + r_m * ppm, y + r_m * ppm], fill=col + (240,))
    return p


def multi(*painters):
    def p(d, cw, chh, ppm, oy):
        for q in painters:
            q(d, cw, chh, ppm, oy)
    return p


# --- vehicles ---------------------------------------------------------------------------------
PLAYER = {"kompakt": "#e2b21c", "kombi": "#2f8a4e", "limousine": "#2a5ab8", "sportwagen": "#d42a2a", "gran_turismo": "#b8bcc4"}
for vid, col in PLAYER.items():
    make_vehicle("player/" + vid, col, 1.85, 4.6, 1.45, ["base", "tail", "brake"], ["player"])
    img = Image.new("RGBA", (384, 240), (0, 0, 0, 0))
    car_cell(ImageDraw.Draw(img), 0, 0, 384, 240, "r1", "base", col, 1.85, 1.45, 3.4)
    save("showroom/" + vid, img, {"cell": [384, 240], "angles": ["c"], "layers": ["base"], "image_width_m": 3.4,
                                  "anchor": [0.5, 0.92], "object": {}, "tags": ["showroom"]})
for name, col in [("sedan_red", "#b52424"), ("sedan_blue", "#24509e"), ("sedan_silver", "#a7abb2"), ("hatch_green", "#3f8f43"), ("van_white", "#e6e6e6")]:
    make_vehicle("traffic/" + name, col, 1.8, 4.5, 1.5 if "van" not in name else 2.0, ["base", "tail", "brake"], ["traffic", "car"])
make_vehicle("traffic/truck_white", "#ececec", 2.5, 16.5, 3.9, ["base", "tail", "brake"], ["traffic", "heavy"], heavy=True, cell=(256, 288), img_w_m=3.4)
make_vehicle("police/de", "#d9dde2", 1.85, 4.8, 1.5, ["base", "tail", "brake", "beacon_a", "beacon_b"], ["police", "de"], police="#1f4fa8")
make_vehicle("police/nl", "#f2f2f2", 1.85, 4.8, 1.5, ["base", "tail", "brake", "beacon_a", "beacon_b"], ["police", "nl"], police="#e86a10")

# --- props ------------------------------------------------------------------------------------
make_prop("props/tree_oak", (256, 320), 9.0, tree("#3f7a2e"), obj={"width_m": 7, "height_m": 11})
make_prop("props/tree_beech", (256, 320), 9.0, tree("#4a8a34", h_m=12), obj={"width_m": 7, "height_m": 12})
make_prop("props/tree_birch", (192, 320), 6.0, tree("#7fb04a", trunk="#e8e8e0", h_m=10, w_m=4.5), obj={"width_m": 4.5, "height_m": 10})
make_prop("props/tree_spruce", (192, 384), 6.0, tree("#2b5a2a", crown="cone", h_m=15, w_m=5), obj={"width_m": 5, "height_m": 15})
make_prop("props/tree_poplar", (128, 384), 4.0, tree("#4f8c3a", crown="column", h_m=18, w_m=3.5), obj={"width_m": 3.5, "height_m": 18})
make_prop("props/rock_a", (256, 160), 5.0, lambda d, cw, chh, ppm, oy: d.ellipse([cw * 0.15, oy + chh * 0.45, cw * 0.85, oy + chh * 0.99], fill=rgb("#8a8780")))
make_prop("props/wind_turbine", (256, 512), 60.0, multi(pole(80, head=(4, 3), pole_col="#e9ecef", head_col="#e9ecef"),
          lambda d, cw, chh, ppm, oy: d.line([(cw / 2, oy + chh * 0.97 - 78 * ppm), (cw / 2 + 25 * ppm, oy + chh * 0.97 - 98 * ppm)], fill=rgb("#f2f2f2"), width=3)))
make_prop("props/farmhouse", (320, 256), 22.0, box("#b0573c", 16, 7, roof="#5b2f22", windows="#f1e3c0"), window_lights(16, 7))
make_prop("props/windmill", (256, 384), 18.0, multi(box("#6b5a4a", 7, 16, roof="#3a2f28"),
          lambda d, cw, chh, ppm, oy: d.line([(cw / 2 - 8 * ppm, oy + chh * 0.97 - 22 * ppm), (cw / 2 + 8 * ppm, oy + chh * 0.97 - 10 * ppm)], fill=rgb("#efe7d6"), width=5)))
make_prop("props/building_block_a", (320, 384), 22.0, box("#b9b2a5", 18, 21, windows="#4c5866"), window_lights(18, 21))
make_prop("props/building_tall", (256, 512), 24.0, box("#8a97a6", 20, 46, windows="#3c4856"), window_lights(20, 46))
make_prop("props/streetlight", (128, 384), 3.0, pole(9.0, head=(1.4, 0.3)), glow(0.0, 8.8, 0.35))
make_prop("props/delineator", (64, 128), 0.6, multi(pole(1.0, pole_col="#f4f4f4"),
          lambda d, cw, chh, ppm, oy: d.rectangle([cw / 2 - 0.08 * ppm, oy + chh * 0.97 - 0.95 * ppm, cw / 2 + 0.08 * ppm, oy + chh * 0.97 - 0.8 * ppm], fill=rgb("#111111"))),
          glow(0.0, 0.87, 0.04, (255, 160, 60)))
make_prop("props/fuel_station", (384, 256), 34.0, multi(box("#e8e8e8", 24, 5), box("#1d6fb8", 26, 1.2),
          lambda d, cw, chh, ppm, oy: d.rectangle([cw / 2 + 4 * ppm, oy + chh * 0.97 - 11 * ppm, cw / 2 + 7 * ppm, oy + chh * 0.97 - 6 * ppm], fill=rgb("#d22b2b"))),
          window_lights(24, 5))
make_prop("props/fuel_pump", (128, 192), 4.0, multi(box("#d9d9d9", 1.2, 1.9), lambda d, cw, chh, ppm, oy: d.rectangle([cw / 2 - 2 * ppm, oy + chh * 0.97 - 5.2 * ppm, cw / 2 + 2 * ppm, oy + chh * 0.97 - 4.6 * ppm], fill=rgb("#1d6fb8")),
          pole(4.8, pole_col="#9a9a9a")), glow(0.0, 4.9, 0.25))
make_prop("props/radar_camera", (96, 192), 1.6, multi(pole(2.2, pole_col="#6d7278"),
          lambda d, cw, chh, ppm, oy: d.rectangle([cw / 2 - 0.4 * ppm, oy + chh * 0.97 - 3.4 * ppm, cw / 2 + 0.4 * ppm, oy + chh * 0.97 - 2.2 * ppm], fill=rgb("#c9c9c9"))))
make_prop("props/customs_booth", (256, 192), 9.0, box("#dedede", 6, 3.2, roof="#7a7a7a", windows="#3e4a57"), window_lights(6, 3.2))

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=1, ensure_ascii=False)
print("sets:", len(manifest["sets"]))
