#!/usr/bin/env python3
"""Review sheets for the rendered sprites (Pillow only, no Blender needed).

Usage: python3 tools/blender/contact_sheet.py [--src assets/sprites] [--out DIR] [--only PREFIX[,..]]
                                              [--every N]

Writes per category (player, showroom, traffic, police, props, landmarks, ui):
  <out>/contact_<category>.png  every set: base cells of all angles (every N-th angle with --every) on an
                                asphalt-grey background, then a night composite (base darkened like the
                                game + light layers; brake on every second angle)
  <out>/contact_boxes.png       box sets (trucks/buses): every face image and light overlay, labelled,
                                plus the faces folded into a rough 3/4 preview
  <out>/lineup_vehicles.png     straight view of every ortho vehicle scaled to the same pixels per
                                metre on a common ground line (checks metric consistency/anchors)
  <out>/lineup_props.png        same for props
  <out>/lineup_landmarks.png    same for the landmarks (real heights side by side)
Sprite cells are found through the grid layout (index = layer * len(angles) + angle, grid_cols).
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
    g = int(s.get("grid_cols", len(s["angles"])))
    i = s["layers"].index(layer) * len(s["angles"]) + s["angles"].index(angle)
    col, row = i % g, i // g
    return img.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))


def darken(im):
    r, g, b, a = im.split()
    r = r.point(lambda v: int(v * NIGHT_TINT[0]))
    g = g.point(lambda v: int(v * NIGHT_TINT[1]))
    b = b.point(lambda v: int(v * NIGHT_TINT[2]))
    return Image.merge("RGBA", (r, g, b, a))


def night(img, s, angle, extra_layers):
    base = cell(img, s, angle, "base")
    out = Image.new("RGBA", base.size, NIGHT_BG)
    out.alpha_composite(darken(base))
    for layer in extra_layers:
        if layer in s["layers"]:
            out.alpha_composite(cell(img, s, angle, layer))
    return out


def scaled(im, k):
    if k == 1.0:
        return im
    return im.resize((max(1, int(im.size[0] * k)), max(1, int(im.size[1] * k))), Image.LANCZOS)


def contact(src, sets, ids, title, every=1, max_cell_w=320):
    rows = []
    for sid in ids:
        s = sets[sid]
        if s.get("render") == "box":
            continue
        img = Image.open(os.path.join(src, s["file"])).convert("RGBA")
        cw, ch = s["cell"]
        k = min(1.0, max_cell_w / cw)
        angs = s["angles"][::every] if every > 1 else s["angles"]
        if "c" not in angs:
            angs = sorted(set(angs) | {"c"}, key=s["angles"].index)
        lights = [l for l in s["layers"] if l != "base"]
        tw, th = int(cw * k), int(ch * k)
        day = Image.new("RGBA", (tw * len(angs), th), DAY_BG)
        for i, a in enumerate(angs):
            day.alpha_composite(scaled(cell(img, s, a, "base"), k), (i * tw, 0))
        parts = [day]
        if lights:
            nt = Image.new("RGBA", (tw * len(angs), th), NIGHT_BG)
            for i, a in enumerate(angs):
                lay = [l for l in lights if l != "beacon_b"] if "beacon_a" in lights else list(lights)
                if "brake" in lay and i % 2 == 0:
                    lay = [l for l in lay if l != "brake"]
                nt.alpha_composite(scaled(night(img, s, a, lay), k), (i * tw, 0))
            parts.append(nt)
        w = max(p.size[0] for p in parts)
        row = Image.new("RGBA", (w, sum(p.size[1] for p in parts) + 16 + 4 * (len(parts) - 1)), (40, 42, 46, 255))
        y = 16
        for p in parts:
            row.alpha_composite(p, (0, y))
            y += p.size[1] + 4
        d = ImageDraw.Draw(row)
        o = s.get("object", {})
        extra = ""
        if s.get("projection") == "perspective":
            extra = "  perspective ss %s" % s.get("supersample")
        d.text((4, 2), "%s  cell %dx%d  grid %s  %s  anchor %s  pivot %s%s  obj %s" % (
            sid, cw, ch, s.get("grid_cols", "-"), "%d angles" % len(s["angles"]), s["anchor"], s.get("pivot", "-"),
            extra, " ".join("%s=%s" % (kk[0], v) for kk, v in o.items())), fill=LABEL)
        rows.append(row)
    return stack(rows, title)


def stack(rows, title, max_w=None):
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


def box_contact(src, sets, ids, scale=0.5):
    rows = []
    for sid in ids:
        s = sets[sid]
        if s.get("render") != "box":
            continue
        img = Image.open(os.path.join(src, s["file"])).convert("RGBA")
        tiles = []
        for p in s["parts"]:
            for f, r in p["faces"].items():
                x, y, w, h = r
                face = img.crop((x, y, x + w, y + h))
                t = Image.new("RGBA", face.size, DAY_BG)
                t.alpha_composite(face)
                tiles.append(("%s.%s %dx%d" % (p["name"], f, w, h), scaled(t, scale)))
        for layer, entries in s.get("lights", {}).items():
            for e in entries:
                x, y, w, h = e["rect"]
                part = [p for p in s["parts"] if p["name"] == e["part"]][0]
                fx, fy, fw, fh = part["faces"][e["face"]]
                t = Image.new("RGBA", (w, h), NIGHT_BG)
                t.alpha_composite(darken(img.crop((fx, fy, fx + fw, fy + fh))))
                t.alpha_composite(img.crop((x, y, x + w, y + h)))
                tiles.append(("%s %s.%s" % (layer, e["part"], e["face"]), scaled(t, scale)))
        W = 1800
        lines, cur, x = [], [], 0
        for lab, t in tiles:
            if x + t.size[0] > W and cur:
                lines.append(cur)
                cur, x = [], 0
            cur.append((lab, t))
            x += t.size[0] + 8
        lines.append(cur)
        Hh = sum(max(t.size[1] for _, t in ln) + 18 for ln in lines) + 20
        row = Image.new("RGBA", (W, Hh), (40, 42, 46, 255))
        d = ImageDraw.Draw(row)
        d.text((4, 2), "%s  sheet %dx%d  obj %s" % (sid, img.size[0], img.size[1], s["object"]), fill=LABEL)
        y = 20
        for ln in lines:
            x = 0
            for lab, t in ln:
                d.text((x + 2, y), lab, fill=LABEL)
                row.alpha_composite(t, (x, y + 14))
                x += t.size[0] + 8
            y += max(t.size[1] for _, t in ln) + 18
        rows.append(row)
    return stack(rows, "box sets (scale %.2f)" % scale)


def lineup(src, sets, ids, ppm=40.0, angle="c", max_w=4000):
    items = []
    for sid in ids:
        s = sets[sid]
        img = Image.open(os.path.join(src, s["file"])).convert("RGBA")
        if s.get("render") == "box":
            # rear face of the rearmost part at the common scale, standing on the ground line
            p = min(s["parts"], key=lambda q: q["z"][0])
            x, y, w, h = p["faces"]["rear"]
            c = img.crop((x, y, x + w, y + h))
            k = ppm / (w / (p["x"][1] - p["x"][0]))
            c = c.resize((max(1, int(c.size[0] * k)), max(1, int(c.size[1] * k))), Image.LANCZOS)
            items.append((sid, c, (0.5, 1.0)))
            continue
        if s.get("projection") == "perspective":
            continue
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
    ap.add_argument("--every", type=int, default=1, help="show every N-th angle")
    args = ap.parse_args()
    sets = load_manifest(args.src)
    os.makedirs(args.out, exist_ok=True)
    cats = ["player", "showroom", "traffic", "police", "props", "landmarks", "ui"]
    prefixes = [p for p in args.only.split(",") if p]
    if prefixes:
        cats = [c for c in cats if any(c.startswith(p.rstrip("/").split("/")[0]) for p in prefixes)]
    for cat in cats:
        ids = sorted(k for k in sets if k.startswith(cat + "/"))
        if prefixes:
            ids = [i for i in ids if any(i.startswith(p) or p.rstrip("/") == cat for p in prefixes)]
        sh = contact(args.src, sets, ids, "%s (%d sets)" % (cat, len(ids)), every=args.every)
        if sh is not None:
            p = os.path.join(args.out, "contact_%s.png" % cat)
            sh.save(p)
            print(p, sh.size)
        if cat == "traffic":
            bx = box_contact(args.src, sets, ids)
            if bx is not None:
                p = os.path.join(args.out, "contact_boxes.png")
                bx.save(p)
                print(p, bx.size)
    veh = sorted(k for k in sets if k.split("/")[0] in ("traffic", "police"))
    lu = lineup(args.src, sets, veh, ppm=30.0)
    if lu is not None:
        lu.save(os.path.join(args.out, "lineup_vehicles.png"))
        print(os.path.join(args.out, "lineup_vehicles.png"), lu.size)
    if not prefixes:
        pr = sorted(k for k in sets if k.startswith("props/") and k != "props/ferry_ship")
        lp = lineup(args.src, sets, pr, ppm=6.0)
        if lp is not None:
            lp.save(os.path.join(args.out, "lineup_props.png"))
            print(os.path.join(args.out, "lineup_props.png"), lp.size)
    if not prefixes or any(p.startswith("landmarks") for p in prefixes):
        lm = sorted(k for k in sets if k.startswith("landmarks/"))
        ll = lineup(args.src, sets, lm, ppm=1.6)
        if ll is not None:
            ll.save(os.path.join(args.out, "lineup_landmarks.png"))
            print(os.path.join(args.out, "lineup_landmarks.png"), ll.size)


if __name__ == "__main__":
    main()
