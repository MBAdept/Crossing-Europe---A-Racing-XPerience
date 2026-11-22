"""AS5aR2: before/after pair: python3 pair.py <before> <after> <out> <label before> <label after> [crop x0,y0,x1,y1] [width]
Both pictures side by side (or cropped to the same box), labels under each."""
import sys

from PIL import Image, ImageDraw, ImageFont

a, b, out, la, lb = sys.argv[1:6]
crop = [int(v) for v in sys.argv[6].split(",")] if len(sys.argv) > 6 and sys.argv[6] != "-" else None
width = int(sys.argv[7]) if len(sys.argv) > 7 else 1920
ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
if crop:
    ia, ib = ia.crop(crop), ib.crop(crop)
h = max(ia.height, ib.height)
canvas = Image.new("RGB", (ia.width + ib.width + 8, h + 40), (27, 31, 39))
canvas.paste(ia, (0, 0))
canvas.paste(ib, (ia.width + 8, 0))
d = ImageDraw.Draw(canvas)
try:
    f = ImageFont.truetype("DejaVuSans.ttf", 24)
except OSError:
    f = ImageFont.load_default()
d.text((10, h + 8), la, fill=(255, 255, 255), font=f)
d.text((ia.width + 18, h + 8), lb, fill=(255, 255, 255), font=f)
if canvas.width > width:
    canvas = canvas.resize((width, int(canvas.height * width / canvas.width)), Image.LANCZOS)
canvas.save(out, quality=88)
print(out, canvas.size)
