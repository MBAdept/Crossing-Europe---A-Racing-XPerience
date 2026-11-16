"""AS4 scratch: puts the Arcade sprite (base layer, or the lights layer over a night sky) next to each tile of a
prop_scene "dist" picture, at the size the game camera gives it there: the model's screen height from the SZENE lines
of prop_scene, the tile zoom recomputed the way prop_scene does it.
   python3 sprite_vs.py <worktree> <prop_scene.png> <prop_scene.log> <out.png> --tile=360x300 --zoom=4 [--night]"""
import json
import re
import sys

from PIL import Image, ImageDraw

WT, SRC, LOG, OUT = sys.argv[1:5]
args = dict(a[2:].split("=", 1) for a in sys.argv[5:] if a.startswith("--") and "=" in a)
night = "--night" in sys.argv
tw, th = (int(v) for v in args.get("tile", "360x300").split("x"))
zmax = int(args.get("zoom", "4"))
man = json.load(open(WT + "/assets/sprites/manifest.json"))
rows = []
for line in open(LOG):
    m = re.search(r"SZENE (\S+) (\d+) m (\S+) (\d+)x(\d+) px", line)
    if m:
        rows.append((m.group(1), int(m.group(2)), m.group(3), float(m.group(4)), float(m.group(5))))
models = []
for r in rows:
    if r[0] not in models:
        models.append(r[0])
cols = max(sum(1 for r in rows if r[0] == mid) for mid in models)
src = Image.open(SRC).convert("RGB")
out = Image.new("RGB", (tw * cols * 2, th * len(models)), (40, 40, 40))
for ri, mid in enumerate(models):
    s = man["sets"][mid]
    sheet = Image.open(WT + "/assets/sprites/" + s["file"]).convert("RGBA")
    cw, ch = s["cell"]
    li = 1 if night and "lights" in s.get("layers", []) else 0
    if sheet.size[0] >= cw * 2 and sheet.size[1] < ch * 2:
        cell = sheet.crop((cw * li, 0, cw * (li + 1), ch))
    else:
        cell = sheet.crop((0, ch * li, cw, ch * (li + 1)))
    obj_h_px = float(s["object"]["height_m"]) * cw / float(s["image_width_m"])
    for c, (_m, d, lod, rw, rh) in enumerate([r for r in rows if r[0] == mid]):
        tile = src.crop((c * tw, ri * th, (c + 1) * tw, (ri + 1) * th))
        out.paste(tile, (c * 2 * tw, ri * th))
        zoom = max(1, min(zmax, int(min(tw / max(8.0, rw * 1.15), th / max(8.0, rh * 1.15)))))
        k = rh * zoom / obj_h_px
        w2, h2 = max(1, int(round(cw * k))), max(1, int(round(ch * k)))
        sp = cell.resize((w2, h2), Image.NEAREST if k > 1.0 else Image.BOX)
        bg = Image.new("RGB", (tw, th), (20, 22, 30) if night else (150, 178, 200))
        bg.paste(sp, ((tw - w2) // 2, th - h2 - 24), sp)
        dr = ImageDraw.Draw(bg)
        dr.text((6, th - 18), "Arcade-Sprite %d m %dx" % (d, zoom), fill=(255, 255, 255) if night else (0, 0, 0))
        out.paste(bg, ((c * 2 + 1) * tw, ri * th))
out.save(OUT)
print("->", OUT, out.size)
