"""Copies the R3E picture series into the delivery folder under numbered names and adds magnified detail crops
(Arcade | Modern) of the near traffic car and of the player."""
import os, shutil, sys
from PIL import Image, ImageDraw, ImageFont
S = sys.argv[1]
D = sys.argv[2]
os.makedirs(D, exist_ok=True)
series = os.path.join(S, 'series')
order = ['sport', 'lieferwagen', 'suv', 'polizei', 'bus', 'lkw']
n = 1
for key in order:
    for t in ['tag', 'nacht']:
        src = os.path.join(series, '%s_%s_ab.jpg' % (key, t))
        if os.path.exists(src):
            shutil.copy(src, os.path.join(D, '%02d_%s_%s.jpg' % (n, key, t)))
        n += 1
for t in ['tag', 'nacht']:
    src = os.path.join(series, 'vorher_nachher_%s_ba.jpg' % t)
    if os.path.exists(src):
        shutil.copy(src, os.path.join(D, '%02d_vorher_nachher_%s.jpg' % (n, t)))
    n += 1
src = os.path.join(series, 'kurve_t1_ab.jpg')
if os.path.exists(src):
    shutil.copy(src, os.path.join(D, '%02d_kurve_t1.jpg' % n))
n += 1
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
except OSError:
    font = ImageFont.load_default()


def crops(prefix, boxes, out, title):
    a = Image.open(os.path.join(series, prefix + '_arcade.png')).convert('RGB')
    m = Image.open(os.path.join(series, prefix + '_modern.png')).convert('RGB')
    rows = []
    for (x, y, w, h, s) in boxes:
        ca = a.crop((x, y, x + w, y + h)).resize((int(w * s), int(h * s)), Image.LANCZOS)
        cm = m.crop((x, y, x + w, y + h)).resize((int(w * s), int(h * s)), Image.LANCZOS)
        row = Image.new('RGB', (ca.width * 2 + 8, ca.height), (16, 24, 44))
        row.paste(ca, (0, 0))
        row.paste(cm, (ca.width + 8, 0))
        rows.append(row)
    W = max(r.width for r in rows)
    H = sum(r.height for r in rows) + 8 * (len(rows) - 1) + 40
    img = Image.new('RGB', (W, H), (16, 24, 44))
    d = ImageDraw.Draw(img)
    d.text((10, 8), title, fill=(220, 228, 240), font=font)
    yy = 40
    for r in rows:
        img.paste(r, (0, yy))
        yy += r.height + 8
    img.save(os.path.join(D, out), quality=92)


# near traffic car (20 m, middle lane) and the player, day and night of the sports-car scene
for t in ['tag', 'nacht']:
    pre = 'sport_%s' % t
    if os.path.exists(os.path.join(series, pre + '_arcade.png')):
        crops(pre, [(455, 370, 140, 75, 4)], '%02d_detail_sportwagen_20m_%s.jpg' % (n, t),
              'Sportwagen bei 20 m (gefaltet), %s – links Arcade, rechts Modern (4-fach)' % ('12 Uhr' if t == 'tag' else '22 Uhr'))
        n += 1
for veh, pre in [('Kombi', 'sport_tag'), ('Sportwagen', 'lieferwagen_tag'), ('Gran Turismo', 'suv_tag')]:
    if os.path.exists(os.path.join(series, pre + '_arcade.png')):
        crops(pre, [(520, 460, 240, 250, 2)], '%02d_detail_spieler_%s.jpg' % (n, veh.lower().replace(' ', '_')),
              'Spielerauto %s, S1 12 Uhr – links Arcade, rechts Modern (2-fach)' % veh)
        n += 1
print(sorted(os.listdir(D)))
