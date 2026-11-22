"""sheet.py <out.jpg> <scale> <label1>=<png1> [<label2>=<png2> ...] [--crop=x0,y0,x1,y1] [--cols=n]
Panels side by side (or in rows of --cols), each scaled by <scale>, labelled in a strip above it."""
import sys
from PIL import Image, ImageDraw, ImageFont

out, scale = sys.argv[1], float(sys.argv[2])
crop = None
cols = 0
items = []
for a in sys.argv[3:]:
    if a.startswith('--crop='):
        crop = tuple(int(v) for v in a[7:].split(','))
    elif a.startswith('--cols='):
        cols = int(a[7:])
    else:
        lab, p = a.split('=', 1)
        items.append((lab, p))
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 20)
except Exception:
    font = ImageFont.load_default()
panels = []
for lab, p in items:
    im = Image.open(p).convert('RGB')
    if crop:
        im = im.crop(crop)
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    c = Image.new('RGB', (im.width, im.height + 30), '#10182c')
    c.paste(im, (0, 30))
    ImageDraw.Draw(c).text((8, 4), lab, fill='white', font=font)
    panels.append(c)
cols = cols or len(panels)
rows = (len(panels) + cols - 1) // cols
pw = max(p.width for p in panels)
ph = max(p.height for p in panels)
sheet = Image.new('RGB', (pw * cols + 4 * (cols - 1), ph * rows + 4 * (rows - 1)), '#000000')
for i, p in enumerate(panels):
    sheet.paste(p, ((i % cols) * (pw + 4), (i // cols) * (ph + 4)))
sheet.save(out, quality=88)
print(out, sheet.size)
