#!/usr/bin/env python3
"""FLACKER-NACHSTELLEN: contact sheet of the level switches of probe_switch.gd runs.

One row per switch (set, direction): Modern frame before | at | 2 after | Arcade at the same distance, plus the
difference image (before vs at, amplified x4). Crops are enlarged (nearest) by --scale. Labels in German.

usage: make_sheet.py <modern run> <arcade run or -> <out.png> [--scale=3] [--sets=a,b] [--title=...]
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


def read_log(run):
    rows = {}
    for line in open(os.path.join(run, "log.jsonl")):
        d = json.loads(line)
        if "i" in d:
            rows.setdefault(d["set"], []).append(d)
    return rows


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    modern, arcade, out = args[0], args[1], args[2]
    scale = int(opts.get("scale", 3))
    only = opts.get("sets", "").split(",") if opts.get("sets") else None
    mrows = read_log(modern)
    arows = read_log(arcade) if arcade != "-" else {}
    tiles = []
    for set_id, rows in mrows.items():
        if only and set_id not in only:
            continue
        sd = os.path.join(modern, set_id.replace("/", "_"))
        ad = os.path.join(arcade, set_id.replace("/", "_")) if arcade != "-" else None
        for k in range(1, len(rows)):
            a, b = rows[k - 1], rows[k]
            if a["lod"] and b["lod"] and a["lod"] != b["lod"]:
                ims = []
                for j in (k - 1, k, min(k + 2, len(rows) - 1)):
                    ims.append(Image.open(os.path.join(sd, "f%04d.png" % rows[j]["i"])).convert("RGB"))
                if ad and set_id in arows and k < len(arows[set_id]):
                    ims.append(Image.open(os.path.join(ad, "f%04d.png" % arows[set_id][k]["i"])).convert("RGB"))
                d = np.abs(np.asarray(ims[1], np.int16) - np.asarray(ims[0], np.int16)).max(-1)
                diff = Image.fromarray(np.clip(d * 4, 0, 255).astype(np.uint8)).convert("RGB")
                ims.append(diff)
                lab = "%s  %s→%s  d=%.2f m (Kamera→Wagenmitte)" % (set_id.replace("traffic/", ""), a["lod"], b["lod"], b["d"])
                tiles.append((lab, ims))
    if not tiles:
        print("no switches")
        return
    w, h = tiles[0][1][0].size
    W, H = w * scale, h * scale
    heads = ["Modern davor", "Modern beim Wechsel", "Modern +2 Bilder", "Arcade gleicher Abstand", "Differenz davor/beim (×4)"]
    if arcade == "-":
        heads = ["Modern davor", "Modern beim Wechsel", "Modern +2 Bilder", "Differenz davor/beim (×4)"]
    cols = len(tiles[0][1])
    pad = 28
    sheet = Image.new("RGB", (cols * (W + 6) + 6, 40 + len(tiles) * (H + pad + 6)), (24, 24, 24))
    dr = ImageDraw.Draw(sheet)
    f = font(18)
    dr.text((8, 4), opts.get("title", ""), fill=(255, 255, 255), font=f)
    for ci, hd in enumerate(heads[:cols]):
        dr.text((6 + ci * (W + 6), 22), hd, fill=(200, 200, 200), font=font(14))
    y = 40
    for lab, ims in tiles:
        dr.text((6, y + 2), lab, fill=(255, 230, 120), font=font(15))
        for ci, im in enumerate(ims):
            sheet.paste(im.resize((W, H), Image.NEAREST), (6 + ci * (W + 6), y + pad))
        y += H + pad + 6
    sheet.save(out)
    print("sheet", out, sheet.size, len(tiles), "rows")


if __name__ == "__main__":
    main()
