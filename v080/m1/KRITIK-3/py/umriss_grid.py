# Grid of the lod0 outline overlays (KRITIK-3): sprite outline vs model silhouette, labelled with the shares.
import sys, os, re
from PIL import Image, ImageDraw
d = sys.argv[1]; log = sys.argv[2]; out = sys.argv[3]; lod = sys.argv[4] if len(sys.argv) > 4 else 'lod0'
shares = {}
for line in open(log):
    m = re.match(r'UMRISS props/(\S+) .*?' + lod + r' ([\d.]+) % außerhalb, Sprite zu ([\d.]+) % gedeckt', line)
    if m:
        shares[m.group(1)] = (m.group(2), m.group(3))
names = ['tree_oak','tree_oak_b','tree_birch','tree_birch_b','tree_beech','tree_beech_b','tree_poplar','tree_poplar_b','tree_olive','tree_olive_b',
         'tree_pine','tree_pine_b','tree_spruce','tree_spruce_b','tree_cypress','tree_cypress_b','tree_palm','tree_palm_b']
ims = []
for n in names:
    f = os.path.join(d, 'u_%s_%s.png' % (n, lod))
    if os.path.exists(f):
        ims.append((n, Image.open(f).convert('RGB')))
cols = 6
rows = []
for i in range(0, len(ims), cols):
    rows.append(ims[i:i + cols])
cw = max(im.width for _, im in ims) + 10
rh = [max(im.height for _, im in r) + 34 for r in rows]
sheet = Image.new('RGB', (cw * cols, sum(rh) + 30), (255, 255, 255))
dr = ImageDraw.Draw(sheet)
dr.text((6, 6), 'Umriss %s gegen Arcade-Sprite (Blick der Sprite-Kamera, 6 Grad): gruen = beide, orange = Modell ausserhalb, blau = Sprite nicht gedeckt' % lod, fill=(0, 0, 0))
y = 30
for r, h in zip(rows, rh):
    x = 0
    for n, im in r:
        sheet.paste(im, (x + 5, y + h - 34 - im.height))
        s = shares.get(n, ('?', '?'))
        dr.text((x + 5, y + h - 30), '%s: %s %% aussen, %s %% gedeckt' % (n, s[0], s[1]), fill=(0, 0, 0))
        x += cw
    y += h
sheet.save(out)
print(sheet.size)
