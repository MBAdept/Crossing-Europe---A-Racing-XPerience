"""scratch: A/B pictures Cycles sprite vs real-time render.
usage: ab.py out.png --title=TEXT item [item ...]
  item = label|path[|crop=x,y,w,h][|cell=col,row,cw,ch][|h=PIXELS][|bg=r,g,b]
Every item is scaled to the same height (default 420) and set side by side with its label above."""
import sys

from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
title = ""
items = []
for a in sys.argv[2:]:
    if a.startswith("--title="):
        title = a[8:]
    else:
        items.append(a.split("|"))
H = 420
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
    font_b = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except OSError:
    font = font_b = ImageFont.load_default()
tiles = []
for it in items:
    label, path = it[0], it[1]
    opts = dict(o.split("=", 1) for o in it[2:])
    im = Image.open(path).convert("RGBA")
    if "cell" in opts:
        c, r, cw, ch = [int(v) for v in opts["cell"].split(",")]
        im = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
    if "crop" in opts:
        x, y, w, h = [int(v) for v in opts["crop"].split(",")]
        im = im.crop((x, y, x + w, y + h))
    bg = tuple(int(v) for v in opts.get("bg", "96,104,116").split(","))
    base = Image.new("RGBA", im.size, bg + (255,))
    base.alpha_composite(im)
    hh = int(opts.get("h", H))
    base = base.resize((max(1, round(base.width * hh / base.height)), hh), Image.LANCZOS)
    tiles.append((label, base.convert("RGB")))
pad = 12
top = 44 if title else 8
W = sum(t.width for _l, t in tiles) + pad * (len(tiles) + 1)
Hh = top + 30 + max(t.height for _l, t in tiles) + pad
sheet = Image.new("RGB", (W, Hh), (32, 34, 38))
d = ImageDraw.Draw(sheet)
if title:
    d.text((pad, 10), title, fill=(255, 255, 255), font=font_b)
x = pad
for label, t in tiles:
    d.text((x, top + 4), label, fill=(230, 230, 230), font=font)
    sheet.paste(t, (x, top + 30))
    x += t.width + pad
sheet.save(out)
print(out, sheet.size)
