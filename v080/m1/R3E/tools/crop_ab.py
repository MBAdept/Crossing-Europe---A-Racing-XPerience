"""Side-by-side crops of the same region of an Arcade and a Modern picture, magnified.
usage: crop_ab.py <arcade.png> <modern.png> <out.png> x y w h [scale]"""
import sys
from PIL import Image

a = Image.open(sys.argv[1]).convert('RGB')
m = Image.open(sys.argv[2]).convert('RGB')
x, y, w, h = [int(v) for v in sys.argv[4:8]]
s = float(sys.argv[8]) if len(sys.argv) > 8 else 2.0
ca = a.crop((x, y, x + w, y + h)).resize((int(w * s), int(h * s)), Image.LANCZOS)
cm = m.crop((x, y, x + w, y + h)).resize((int(w * s), int(h * s)), Image.LANCZOS)
out = Image.new('RGB', (ca.width * 2 + 6, ca.height), (16, 24, 44))
out.paste(ca, (0, 0))
out.paste(cm, (ca.width + 6, 0))
out.save(sys.argv[3])
print(sys.argv[3], out.size)
