"""Magnified crops of two different regions (Arcade region, Modern region) side by side - for scenes where the
cameras differ (bends).
usage: crop2.py <arcade.png> <modern.png> <out> ax ay mx my w h [scale]"""
import sys
from PIL import Image

a = Image.open(sys.argv[1]).convert('RGB')
m = Image.open(sys.argv[2]).convert('RGB')
ax, ay, mx, my, w, h = [int(v) for v in sys.argv[4:10]]
s = float(sys.argv[10]) if len(sys.argv) > 10 else 3.0
ca = a.crop((ax, ay, ax + w, ay + h)).resize((int(w * s), int(h * s)), Image.LANCZOS)
cm = m.crop((mx, my, mx + w, my + h)).resize((int(w * s), int(h * s)), Image.LANCZOS)
out = Image.new('RGB', (ca.width * 2 + 6, ca.height), (16, 24, 44))
out.paste(ca, (0, 0))
out.paste(cm, (ca.width + 6, 0))
out.save(sys.argv[3])
print(sys.argv[3], out.size)
