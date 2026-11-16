#!/usr/bin/env python3
"""FLACKER-NACHSTELLEN: picture sheet from probe_switch2.gd runs.

Each tile = "label|run dir|set id|phase(in/out/clip)|d" (the frame with the nearest d in that phase), or
"label|DIFF|<tile a index>|<tile b index>" (amplified difference x4 of two earlier tiles). The crop window (--win) of the
saved crop is enlarged by --scale (nearest). Rows of --cols tiles.

usage: sheet2.py <out.png> --title=... --cols=4 [--win=x0,y0,x1,y1] [--scale=3] tile tile ...
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def pick(run, set_id, phase, d):
    best = None
    for line in open(os.path.join(run, "log.jsonl")):
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "i" not in r or r["set"] != set_id or r["phase"] != phase:
            continue
        if best is None or abs(r["d"] - d) < abs(best["d"] - d):
            best = r
    return best


def main():
    out = sys.argv[1]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    specs = [a for a in sys.argv[2:] if not a.startswith("--")]
    win = [int(v) for v in opts.get("win", "130,70,320,225").split(",")]
    scale = int(opts.get("scale", 3))
    cols = int(opts.get("cols", 4))
    tiles = []
    for s in specs:
        p = s.split("|")
        if p[1] == "DIFF":
            a = np.asarray(tiles[int(p[2])][1], np.int16)
            b = np.asarray(tiles[int(p[3])][1], np.int16)
            d = np.abs(a - b).max(-1)
            tiles.append((p[0], Image.fromarray(np.clip(d * 4, 0, 255).astype(np.uint8)).convert("RGB")))
            continue
        label, run, set_id, phase, d = p[0], p[1], p[2], p[3], float(p[4])
        r = pick(run, set_id, phase, d)
        im = Image.open(os.path.join(run, set_id.replace("/", "_"), "f%04d.png" % r["i"])).convert("RGB")
        im = im.crop(tuple(win))
        lab = label.replace("{d}", "%.1f" % r["d"]).replace("{lod}", r.get("lod", "") or "Arcade")
        tiles.append((lab, im))
    w, h = tiles[0][1].size
    W, H = w * scale, h * scale
    rows = (len(tiles) + cols - 1) // cols
    pad = 40
    sheet = Image.new("RGB", (cols * (W + 8) + 8, 44 + rows * (H + pad + 8)), (24, 24, 24))
    dr = ImageDraw.Draw(sheet)
    dr.text((8, 8), opts.get("title", ""), fill=(255, 255, 255), font=font(20))
    for k, (lab, im) in enumerate(tiles):
        x = 8 + (k % cols) * (W + 8)
        y = 44 + (k // cols) * (H + pad + 8)
        for li, line in enumerate(lab.split("\\n")[:2]):
            dr.text((x, y + 2 + li * 18), line, fill=(255, 230, 120), font=font(15))
        sheet.paste(im.resize((W, H), Image.NEAREST), (x, y + pad))
    sheet.save(out)
    print("saved", out, sheet.size)


if __name__ == "__main__":
    main()
