"""crop.py <ab_dir> <ID> <NN> <x0> <y0> <x1> <y1> <out.jpg> [scale] : the same region of Arcade | Modern head | Modern base
(where present) side by side, enlarged by scale (default 2). Coordinates in the 1280x720 (or 1280x800) picture."""
import sys, os
from PIL import Image, ImageDraw, ImageFont

ab, jid, nn = sys.argv[1], sys.argv[2], sys.argv[3]
x0, y0, x1, y1 = map(int, sys.argv[4:8])
out = sys.argv[8]
sc = float(sys.argv[9]) if len(sys.argv) > 9 else 2.0
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 18)
except Exception:
    font = ImageFont.load_default()
tiles = []
for tag, name in (('arcade', 'Arcade'), ('modern', 'Modern Kopf 9b02f05'), ('base_modern', 'Modern Basis 515dd51')):
    p = os.path.join(ab, '%s_%s_%s.png' % (jid, tag, nn))
    if not os.path.exists(p):
        continue
    im = Image.open(p).convert('RGB').crop((x0, y0, x1, y1))
    im = im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS)
    c = Image.new('RGB', (im.width, im.height + 28), '#10182c')
    c.paste(im, (0, 28))
    ImageDraw.Draw(c).text((8, 4), name, fill='white', font=font)
    tiles.append(c)
W = sum(t.width for t in tiles) + 6 * (len(tiles) - 1)
H = max(t.height for t in tiles)
sheet = Image.new('RGB', (W, H), '#10182c')
x = 0
for t in tiles:
    sheet.paste(t, (x, 0))
    x += t.width + 6
sheet.save(out, quality=90)
print(out, sheet.size)
