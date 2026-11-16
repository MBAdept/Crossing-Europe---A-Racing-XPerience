from compose import *
from PIL import Image
pick = [(1, 0, 'Eiche'), (1, 4, 'Birke'), (2, 0, 'Buche'), (2, 4, 'Pappel'), (3, 0, 'Olive'), (3, 4, 'Kiefer'), (4, 0, 'Fichte'),
        (4, 4, 'Zypresse'), (5, 0, 'Palme'), (5, 4, 'Busch rund'), (6, 0, 'Busch niedrig'), (6, 2, 'Heide'), (6, 4, 'Fels a'),
        (6, 6, 'Fels b'), (6, 8, 'Klippe')]
sheets = {}
pairs = []
for g, r, name in pick:
    if g not in sheets:
        sheets[g] = Image.open(S + 'dist_g%d_h12.png' % g).convert('RGB')
    im = sheets[g]
    col = 1 if name not in ('Klippe',) else 2
    m = im.crop((360 * col, 300 * r, 360 * col + 360, 300 * r + 300))
    s = im.crop((360 * col, 300 * (r + 1), 360 * col + 360, 300 * (r + 1) + 300))
    label(m, '%s – Modern' % name); label(s, 'Arcade-Sprite')
    p = Image.new('RGB', (724, 300), (255, 255, 255)); p.paste(m, (0, 0)); p.paste(s, (364, 0))
    pairs.append(p)
out = title(grid(pairs, 3), 'Alle Arten in 40 m (Klippe 100 m), Mittag, Renn-Licht, Voreinstellung Mittel: links das Modell, rechts das Arcade-Sprite am selben Ort',
            'Ausschnitt des Spielbilds, ganzzahlig vergrößert (Faktor unten in jeder Kachel). Feiner: Eiche, Buche, Pappel, Olive, Kiefer, Fichte; gleich: Zypresse, Büsche, Heide, Felsen; gröber: Palme (Klippe nur von vorn gleich)')
save(out, '00_alle_arten_40m_gegen_sprite.jpg', q=86)
