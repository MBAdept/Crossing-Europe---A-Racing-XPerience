"""Preview of some tiles of a contact sheet: tiles.py <sheet.png> <out.png> <tile w> <tile h> <cols in sheet>
<first tile> <count> <preview cols> <preview tile w>"""
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
tw, th, cols, first, count, pcols, pw = [int(v) for v in sys.argv[3:10]]
im = Image.open(src)
ph = pw * th // tw
rows = (count + pcols - 1) // pcols
sheet = Image.new("RGB", (pcols * pw, rows * ph))
for i in range(count):
    t = first + i
    c, r = t % cols, t // cols
    tile = im.crop((c * tw, r * th, c * tw + tw, r * th + th)).resize((pw, ph), Image.LANCZOS)
    sheet.paste(tile, ((i % pcols) * pw, (i // pcols) * ph))
sheet.save(out)
print(out, sheet.size)
