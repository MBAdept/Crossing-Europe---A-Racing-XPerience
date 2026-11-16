from compose import *
from PIL import Image

# 1) species at four distances against the sprite, noon (race light, preset medium)
names = {1: 'eiche_birke', 2: 'buche_pappel', 3: 'olive_kiefer', 4: 'fichte_zypresse', 5: 'palme_busch', 6: 'buschniedrig_heide_felsen_klippe'}
for g, n in names.items():
    im = Image.open(S + 'dist_g%d_h12.png' % g).convert('RGB')
    im = title(im, 'Spielkamera 15 / 40 / 100 / 250 m, Mittag, Renn-Licht, Voreinstellung Mittel – Modell (Stufe des Props-Bauers) und darunter das Arcade-Sprite am selben Ort',
               'Kacheln = Ausschnitt des 1280x720-Spielbilds, ganzzahlig vergrößert (Faktor in der Beschriftung). 15 m: nur ein Ausschnitt der Krone.')
    save(im, '02_arten_mittag_%d_%s.jpg' % (g, n), q=84)
# 2) dusk and night: oak / birch and palm / bush
for h, hn in (('19.5', 'daemmerung'), ('23', 'nacht')):
    for g, n in ((1, 'eiche_birke'), (5, 'palme_busch')):
        im = Image.open(S + 'dist_g%d_h%s.png' % (g, h)).convert('RGB')
        im = title(im, '%s – Modell und Arcade-Sprite, 15 / 40 / 100 / 250 m, Renn-Licht %s Uhr, Mittel (ohne Scheinwerfer)' % (n, h))
        save(im, '03_%s_%s.jpg' % (hn, n), q=84)
