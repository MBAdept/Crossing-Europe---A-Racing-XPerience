"""panel.py <out.jpg> <cols> <title> <spec> [...]
spec = file|x0,y0,x1,y1|caption   (a crop box in pixels; '-' = whole picture). Every cell is scaled to the width of
the first cell, a caption strip under each, a title strip on top."""
import sys
from PIL import Image, ImageDraw, ImageFont
out, cols, title = sys.argv[1], int(sys.argv[2]), sys.argv[3]
cells = []
for spec in sys.argv[4:]:
    f, box, cap = spec.split("|", 2)
    im = Image.open(f).convert("RGB")
    if box != "-":
        im = im.crop(tuple(int(v) for v in box.split(",")))
    cells.append((im, cap))
W = cells[0][0].width
def font(sz):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(p, sz)
        except OSError:
            pass
    return ImageFont.load_default()
f1, f2 = font(18), font(22)
scaled = []
for im, cap in cells:
    h = round(im.height * W / im.width)
    scaled.append((im.resize((W, h), Image.LANCZOS if im.width > W else Image.NEAREST), cap))
rows = [scaled[i:i + cols] for i in range(0, len(scaled), cols)]
CAP, TIT = 30, 40
H = TIT + sum(max(c[0].height for c in r) + CAP for r in rows)
sheet = Image.new("RGB", (W * cols, H), (24, 26, 32))
d = ImageDraw.Draw(sheet)
d.text((10, 8), title, fill=(240, 240, 240), font=f2)
y = TIT
for r in rows:
    rh = max(c[0].height for c in r)
    for i, (im, cap) in enumerate(r):
        sheet.paste(im, (i * W, y))
        d.text((i * W + 8, y + rh + 5), cap, fill=(230, 230, 230), font=f1)
    y += rh + CAP
sheet.save(out, quality=88)
print(out, sheet.size)
