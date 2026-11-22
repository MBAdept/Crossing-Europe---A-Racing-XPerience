"""compose.py <ab_dir> <out_dir> [ID ...]: per job and shot index a sheet Arcade | Modern head (| Modern base 515dd51).
Writes <out_dir>/<ID>_<NN>.jpg (labels in a strip above each picture) and returns nothing. Missing base -> 2 panels."""
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont

ab, out = sys.argv[1], sys.argv[2]
ids = sys.argv[3:]
os.makedirs(out, exist_ok=True)
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
    small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
except Exception:
    font = small = ImageFont.load_default()


def label(img, text):
    w, h = img.size
    c = Image.new('RGB', (w, h + 34), '#10182c')
    c.paste(img.convert('RGB'), (0, 34))
    ImageDraw.Draw(c).text((10, 5), text, fill='white', font=font)
    return c


if not ids:
    ids = sorted({os.path.basename(p).rsplit('_arcade_', 1)[0] for p in glob.glob(os.path.join(ab, '*_arcade_[0-9][0-9].png'))})
for jid in ids:
    caption = ''
    lg = os.path.join(ab, jid + '_modern.log')
    for a in sorted(glob.glob(os.path.join(ab, jid + '_arcade_[0-9][0-9].png'))):
        nn = a.rsplit('_', 1)[1][:2]
        m = os.path.join(ab, '%s_modern_%s.png' % (jid, nn))
        b = os.path.join(ab, '%s_base_modern_%s.png' % (jid, nn))
        tiles = [label(Image.open(a), 'Arcade')]
        if os.path.exists(m):
            tiles.append(label(Image.open(m), 'Modern 9b02f05 (Kopf)'))
        if os.path.exists(b):
            tiles.append(label(Image.open(b), 'Modern 515dd51 (Basis)'))
        W = sum(t.size[0] for t in tiles) + 6 * (len(tiles) - 1)
        H = max(t.size[1] for t in tiles) + 26
        sheet = Image.new('RGB', (W, H), '#10182c')
        x = 0
        for t in tiles:
            sheet.paste(t, (x, 0))
            x += t.size[0] + 6
        ImageDraw.Draw(sheet).text((10, H - 22), '%s  Bild %s' % (jid, nn), fill='#c8d2e6', font=small)
        sheet.save(os.path.join(out, '%s_%s.jpg' % (jid, nn)), quality=88)
        print(os.path.join(out, '%s_%s.jpg' % (jid, nn)))
