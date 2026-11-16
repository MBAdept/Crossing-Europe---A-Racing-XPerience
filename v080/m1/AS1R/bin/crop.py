"""AS1R: crop + enlarge a region of a raw sheet.  usage: crop.py <in.png> <out.png> x0 y0 x1 y1 [scale]"""
import sys

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
x0, y0, x1, y1 = (int(v) for v in sys.argv[3:7])
k = float(sys.argv[7]) if len(sys.argv) > 7 else 2.0
im = Image.open(src).convert("RGB").crop((x0, y0, x1, y1))
im = im.resize((int(im.width * k), int(im.height * k)), Image.NEAREST)
im.save(dst)
print(dst, im.size)
