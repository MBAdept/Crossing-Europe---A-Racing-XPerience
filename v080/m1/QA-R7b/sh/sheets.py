#!/usr/bin/env python3
"""QA-R7b: delivery sheets - per city the triples (Arcade | base 9b02f05 | R7b 2c154bc) of 12:00, 19:30, 22:00 stacked,
each picture at 0.5 scale, labelled. Also near views, flood, deck, skyline groups."""
import os
from PIL import Image, ImageDraw

RAW = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R7b/raw'
OUT = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R7b/boegen'
os.makedirs(OUT, exist_ok=True)


def row(prefix, title, sc=0.5):
    ims = []
    for label, suf in (('Arcade', '_arcade_00.png'), ('Modern Basis 9b02f05', '_basis_00.png'), ('Modern R7b 2c154bc', '_modern_00.png')):
        p = os.path.join(RAW, prefix + suf)
        if os.path.exists(p):
            im = Image.open(p).convert('RGB')
            ims.append((label, im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS)))
    if not ims:
        return None
    w = sum(i.width for _, i in ims) + 6 * (len(ims) - 1)
    h = max(i.height for _, i in ims) + 20
    c = Image.new('RGB', (w, h + 18), (16, 24, 44))
    d = ImageDraw.Draw(c)
    x = 0
    for label, im in ims:
        c.paste(im, (x, 20))
        d.text((x + 6, 4), label, fill=(255, 255, 255))
        x += im.width + 6
    d.text((6, h + 2), title, fill=(200, 210, 230))
    return c


def sheet(name, prefixes):
    rows = [r for r in (row(p, t) for p, t in prefixes) if r is not None]
    if not rows:
        return
    w = max(r.width for r in rows)
    h = sum(r.height for r in rows) + 8 * (len(rows) - 1)
    c = Image.new('RGB', (w, h), (16, 24, 44))
    y = 0
    for r in rows:
        c.paste(r, (0, y))
        y += r.height + 8
    p = os.path.join(OUT, name + '.jpg')
    c.save(p, quality=86)
    print(p, c.size)


CITIES = ['hamburg', 'hannover', 'leipzig', 'dortmund', 'nuernberg', 'paris', 'bruessel', 'belgrad', 'calais', 'madrid']
for city in CITIES:
    sheet(city, [(city + '_12', city + ' 12:00 (ca. 600 m vor dem Wahrzeichen)'), (city + '_195', city + ' 19:30'),
                 (city + '_22', city + ' 22:00')])
    sheet('nah_' + city, [('nah_%s_12' % city, city + ' nah (ca. 250 m) 12:00'), ('nah_%s_22' % city, city + ' nah (ca. 250 m) 22:00')])
sheet('anstrahlung_kirche', [('flood2_bremen_22', 'Bremer Dom (props/church) 400 m, 22:00'), ('flood2_slavonski_22', 'Franziskanerkloster (props/church) 400 m, 22:00'),
                             ('flood2_bremen_12', 'Bremer Dom 12:00'), ('flood2_slavonski_12', 'Franziskanerkloster 12:00'),
                             ('flood_bremen_22', 'Bremer Dom 40 m, 22:00')])
sheet('horizont_S1_S5', [('skyline_km%s' % k, 'Kiel-Hamburg km %s 12:00' % k) for k in ('2', '13.6', '60', '80', '94')])
sheet('skyline_staedte', [('skyline_kassel', 'Kassel (Herkules, Arcade-2D) 12:00'), ('skyline_koeln_12', 'Koeln (Colonius) 12:00'),
                          ('skyline_koeln_22', 'Koeln 22:00'), ('skyline_riga_12', 'Riga (Fernsehturm, St. Petri) 12:00')])
deck = sorted(f[:-len('_arcade_00.png')] for f in os.listdir(RAW) if f.startswith('deck_') and f.endswith('_arcade_00.png'))
sheet('deck_1280x800', [(p, p.replace('deck_', 'Deck-Preset 1280x800: ')) for p in deck])
