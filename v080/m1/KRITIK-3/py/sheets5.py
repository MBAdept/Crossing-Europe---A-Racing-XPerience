from compose import *
from PIL import Image
A = K + '/ab/'
def pair(name, idx, box, scale=2, la='Arcade', lm='Modern'):
    a = Image.open(A + '%s_arcade_%02d.png' % (name, idx)).convert('RGB').crop(box)
    m = Image.open(A + '%s_modern_%02d.png' % (name, idx)).convert('RGB').crop(box)
    if scale != 1:
        a = a.resize((a.width * scale, a.height * scale), Image.NEAREST)
        m = m.resize((m.width * scale, m.height * scale), Image.NEAREST)
    label(a, la); label(m, lm)
    return a, m
rows = []
a, m = pair('kh54_hoch', 1, (130, 120, 650, 420))
rows += [a, m]
dk = Image.open(S + 'z_kh54_deck_2x.png').convert('RGB')
label(dk, 'Steam Deck (1280x800, Voreinstellung Deck: keine Baumschatten) – links Arcade, rechts Modern, 2x', (6, 690))
g = grid([a, m], 2)
w = max(g.width, dk.width)
out = Image.new('RGB', (w, g.height + dk.height + 10), (255, 255, 255))
out.paste(g, (0, 0)); out.paste(dk, (0, g.height + 10))
out = title(out, 'Rennen Kiel–Hamburg km 54,9, Mittag: Eiche in etwa 25 m, Busch, Birke – Modern feiner (Blattwerk, Tiefe, Schatten); auf dem Deck fallen die Vieleck-Unterseiten der Kuppeln auf',
            'tools/ab_shot.sh, gleicher Simulationszustand, oben Voreinstellung Hoch (2x vergrößert), unten Steam Deck')
save(out, '01_rennen_kiel_hamburg_eiche_busch.jpg')
