"""Contact sheet of Arcade sprites (base layer over a sky colour, lights layer over black) for sets (scratch).
   python3 sprite_sheet.py <worktree> <out.png> name1,name2,... [height]"""
import json
import sys

from PIL import Image, ImageDraw

WT = sys.argv[1]
OUT = sys.argv[2]
names = sys.argv[3].split(",")
H = int(sys.argv[4]) if len(sys.argv) > 4 else 360
man = json.load(open(WT + "/assets/sprites/manifest.json"))
row = []
for n in names:
    sid = n if "/" in n else "props/" + n
    s = man["sets"][sid]
    img = Image.open(WT + "/assets/sprites/" + s["file"]).convert("RGBA")
    cw, ch = s["cell"]
    cells = []
    for li, layer in enumerate(s.get("layers", ["base"])):
        if img.size[0] >= cw * (li + 1) and img.size[1] < ch * 2:
            box = (cw * li, 0, cw * (li + 1), ch)
        else:
            box = (0, ch * li, cw, ch * (li + 1))
        cells.append((layer, img.crop(box)))
    print(n, img.size, s["cell"], s.get("layers"), s.get("object"), s.get("extent_m"), s.get("image_width_m"), s.get("anchor"))
    for layer, c in cells:
        sc = H / c.size[1]
        w = max(1, int(c.size[0] * sc))
        t = c.resize((w, H), Image.LANCZOS)
        bg = Image.new("RGBA", (w, H + 20), (150, 178, 200, 255) if layer == "base" else (10, 10, 14, 255))
        bg.alpha_composite(t, (0, 20))
        d = ImageDraw.Draw(bg)
        d.text((4, 4), "%s %s" % (n, layer), fill=(0, 0, 0, 255) if layer == "base" else (255, 255, 255, 255))
        row.append(bg)
W = sum(r.size[0] for r in row) + 4 * len(row)
sheet = Image.new("RGBA", (W, H + 20), (60, 60, 60, 255))
x = 0
for r in row:
    sheet.alpha_composite(r, (x, 0))
    x += r.size[0] + 4
sheet.convert("RGB").save(OUT)
print("->", OUT, sheet.size)
