#!/usr/bin/env python3
"""Review sheets for the rendered sprites (Pillow only, no Blender needed).

Usage: python3 tools/blender/contact_sheet.py [--src assets/sprites] [--out DIR] [--only PREFIX[,..]]

Writes per category (player, showroom, traffic, police, props, ui):
  <out>/contact_<category>.png  every set: base cells on an asphalt-grey background, then a night
                                composite (base darkened like the game + all light layers)
  <out>/lineup_vehicles.png     'c' cell of every vehicle scaled to the same pixels per metre and
                                standing on a common ground line (checks metric consistency/anchors)
  <out>/lineup_props.png        same for props
"""
import argparse
import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DAY_BG = (92, 94, 98, 255)
NIGHT_BG = (22, 24, 34, 255)
NIGHT_TINT = (0.24, 0.26, 0.38)
LABEL = (235, 235, 235, 255)


def load_manifest(src):
    with open(os.path.join(src, "manifest.json"), encoding="utf-8") as fh:
        return json.load(fh)["sets"]


def cell(img, s, angle, layer):
    cw, ch = s["cell"]
    col = s["angles"].index(angle)
    row = s["layers"].index(layer)
    return img.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))


def night(img, s, angle, extra_layers):
    base = cell(img, s, angle, "base")
    r, g, b, a = base.split()
    r = r.point(lambda v: int(v * NIGHT_TINT[0]))
    g = g.point(lambda v: int(v * NIGHT_TINT[1]))
    b = b.point(lambda v: int(v * NIGHT_TINT[2]))
    out = Image.new("RGBA", base.size, NIGHT_BG)
    out.alpha_composite(Image.merge("RGBA", (r, g, b, a)))
    for layer in extra_layers:
        if layer in s["layers"]:
            out.alpha_composite(cell(img, s, angle, layer))
    return out


def contact(src, sets, ids, title):
    rows = []
    for sid in ids:
        s = sets[sid]
        img = Image.open(os.path.join(src, s["file"])).convert("RGBA")
        cw, ch = s["cell"]
        n = len(s["angles"])
        lights = [l for l in s["layers"] if l != "base"]
        day = Image.new("RGBA", (cw * n, ch), DAY_BG)
        for i, a in enumerate(s["angles"]):
            day.alpha_composite(cell(img, s, a, "base"), (i * cw, 0))
        parts = [day]
        if lights:
            nt = Image.new("RGBA", (cw * n, ch), NIGHT_BG)
            for i, a in enumerate(s["angles"]):
                lay = [l for l in lights if l not in ("beacon_b",)] if "beacon_a" in lights else lights
                if "brake" in lay and i % 2 == 0:
                    lay = [l for l in lay if l != "brake"]
                nt.alpha_composite(night(img, s, a, lay), (i * cw, 0))
            parts.append(nt)
        w = sum(p.size[0] for p in parts) + 8 * (len(parts) - 1)
        row = Image.new("RGBA", (w, ch + 16), (40, 42, 46, 255))
        x = 0
        for p in parts:
            row.alpha_composite(p, (x, 16))
            x += p.size[0] + 8
        d = ImageDraw.Draw(row)
        o = s.get("object", {})
        d.text((4, 2), "%s  cell %dx%d  %.2f m  anchor %s  obj %s" % (
            sid, cw, ch, s["image_width_m"], s["anchor"], " ".join("%s=%s" % (k[0], v) for k, v in o.items())), fill=LABEL)
        rows.append(row)
    if not rows:
        return None
    W = max(r.size[0] for r in rows)
    Hh = sum(r.size[1] + 4 for r in rows) + 24
    sheet = Image.new("RGBA", (W, Hh), (30, 31, 34, 255))
    ImageDraw.Draw(sheet).text((6, 6), title, fill=LABEL)
    y = 24
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.size[1] + 4
    return sheet


def lineup(src, sets, ids, ppm=40.0, angle="c", max_w=4000):
    items = []
    for sid in ids:
        s = sets[sid]
        img = Image.open(os.path.join(src, s["file"])).convert("RGBA")
        a = angle if angle in s["angles"] else s["angles"][0]
        c = cell(img, s, a, "base")
        k = ppm / (s["cell"][0] / s["image_width_m"])
        c = c.resize((max(1, int(c.size[0] * k)), max(1, int(c.size[1] * k))), Image.LANCZOS)
        items.append((sid, c, s["anchor"]))
    if not items:
        return None
    above = max(int(c.size[1] * an[1]) for _, c, an in items) + 20
    below = max(int(c.size[1] * (1 - an[1])) for _, c, an in items) + 16
    rows, cur, x = [], [], 0
    for it in items:
        if x + it[1].size[0] > max_w and cur:
            rows.append(cur)
            cur, x = [], 0
        cur.append(it)
        x += it[1].size[0] + 6
    rows.append(cur)
    W = max(sum(c.size[0] + 6 for _, c, _ in r) for r in rows)
    out = Image.new("RGBA", (W, (above + below) * len(rows)), DAY_BG)
    d = ImageDraw.Draw(out)
    for ri, r in enumerate(rows):
        y0 = ri * (above + below)
        gy = y0 + above
        d.line([(0, gy), (W, gy)], fill=(200, 60, 60, 255))
        for m in range(0, W, int(ppm)):
            d.line([(m, gy), (m, gy + 4)], fill=(230, 230, 230, 255))
        x = 0
        for sid, c, an in r:
            out.alpha_composite(c, (x, gy - int(c.size[1] * an[1])))
            d.text((x + 2, y0 + 2), sid.split("/")[-1], fill=LABEL)
            d.line([(x + int(c.size[0] * an[0]), gy - 3), (x + int(c.size[0] * an[0]), gy + 3)], fill=(255, 255, 0, 255))
            x += c.size[0] + 6
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "assets", "sprites"))
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "sprite_review"))
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    sets = load_manifest(args.src)
    os.makedirs(args.out, exist_ok=True)
    cats = ["player", "showroom", "traffic", "police", "props", "ui"]
    if args.only:
        cats = [c for c in cats if any(c.startswith(p.rstrip("/")) or p.startswith(c) for p in args.only.split(","))]
    for cat in cats:
        ids = sorted(k for k in sets if k.startswith(cat + "/"))
        if args.only:
            ids = [i for i in ids if any(i.startswith(p) or p.rstrip("/") == cat for p in args.only.split(","))]
        sh = contact(args.src, sets, ids, "%s (%d sets)" % (cat, len(ids)))
        if sh is not None:
            p = os.path.join(args.out, "contact_%s.png" % cat)
            sh.save(p)
            print(p, sh.size)
    veh = sorted(k for k in sets if k.split("/")[0] in ("player", "traffic", "police"))
    lu = lineup(args.src, sets, veh, ppm=30.0)
    if lu is not None:
        lu.save(os.path.join(args.out, "lineup_vehicles.png"))
        print(os.path.join(args.out, "lineup_vehicles.png"), lu.size)
    pr = sorted(k for k in sets if k.startswith("props/") and k != "props/ferry_ship")
    lp = lineup(args.src, sets, pr, ppm=6.0)
    if lp is not None:
        lp.save(os.path.join(args.out, "lineup_props.png"))
        print(os.path.join(args.out, "lineup_props.png"), lp.size)


if __name__ == "__main__":
    main()
