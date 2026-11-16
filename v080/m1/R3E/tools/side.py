"""Two pictures side by side (optionally scaled).  usage: side.py <left.png> <right.png> <out> [scale]"""
import sys
from PIL import Image

a = Image.open(sys.argv[1]).convert('RGB')
b = Image.open(sys.argv[2]).convert('RGB')
s = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
a = a.resize((int(a.width * s), int(a.height * s)), Image.LANCZOS)
b = b.resize((int(b.width * s), int(b.height * s)), Image.LANCZOS)
out = Image.new('RGB', (a.width + b.width + 6, max(a.height, b.height)), (16, 24, 44))
out.paste(a, (0, 0))
out.paste(b, (a.width + 6, 0))
out.save(sys.argv[3])
print(sys.argv[3], out.size)
