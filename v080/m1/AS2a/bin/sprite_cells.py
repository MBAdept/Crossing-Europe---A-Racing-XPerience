#!/usr/bin/env python3
"""Crops sprite cells (base / tail / brake layers) for a quick look. usage: sprite_cells.py <out.png> <set> [<set> ...]
Each set: one row with the base, tail, brake layer of the centre angle (c) on grey."""
import json
import sys

from PIL import Image

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1"
man = json.load(open(WT + "/assets/sprites/manifest.json"))
out = sys.argv[1]
rows = []
for sid in sys.argv[2:]:
    s = man["sets"][sid]
    im = Image.open(WT + "/assets/sprites/" + s["file"]).convert("RGBA")
    cw, ch = s["cell"]
    cols = s.get("grid_cols", len(s["angles"]))
    na = len(s["angles"])
    ia = s["angles"].index("c") if "c" in s["angles"] else 0
    layers = s.get("layers", ["base"])
    nl = max(1, im.height // ch * cols // max(1, na)) if na else 1
    cells = []
    for li in range(3):
        idx = li * na + ia
        r, c = divmod(idx, cols)
        if (r + 1) * ch > im.height:
            break
        cell = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
        bg = Image.new("RGBA", cell.size, (88, 90, 96, 255) if li == 0 else (10, 10, 16, 255))
        bg.alpha_composite(cell)
        cells.append(bg)
    row = Image.new("RGBA", (sum(c.width for c in cells), max(c.height for c in cells)))
    x = 0
    for c in cells:
        row.paste(c, (x, 0))
        x += c.width
    rows.append(row)
W = max(r.width for r in rows)
H = sum(r.height for r in rows)
sheet = Image.new("RGBA", (W, H), (0, 0, 0, 255))
y = 0
for r in rows:
    sheet.paste(r, (0, y))
    y += r.height
sheet.convert("RGB").save(out)
print(out, sheet.size)
