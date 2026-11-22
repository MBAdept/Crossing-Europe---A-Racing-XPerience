"""mark.py <in.png> <out.jpg> <x0> <y0> <x1> <y1> <scale> <x,y> [x,y ...] : crop, enlarge, mark the given points."""
import sys
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
x0, y0, x1, y1 = map(int, sys.argv[3:7])
sc = int(sys.argv[7])
im = Image.open(src).convert('RGB').crop((x0, y0, x1, y1))
im = im.resize((im.width * sc, im.height * sc), Image.NEAREST)
dr = ImageDraw.Draw(im)
for p in sys.argv[8:]:
    x, y = map(int, p.split(','))
    cx, cy = (x - x0) * sc + sc // 2, (y - y0) * sc + sc // 2
    dr.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), outline=(255, 0, 255), width=2)
im.save(out, quality=90)
print(out, im.size)
