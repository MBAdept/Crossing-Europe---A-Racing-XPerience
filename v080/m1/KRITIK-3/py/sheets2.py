from compose import *
from PIL import Image

AS3 = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS3/'
# M1 cliff: turned views + the race picture of AS3 (Lyon - Bern km 148.7)
turn = Image.open(S + 'z_cliff_turn_grid.png').convert('RGB')
ab = Image.open(AS3 + 'ab_alpen_hoch_mittag.jpg').convert('RGB')
a = ab.crop((560, 200, 1000, 440)).resize((880, 480), Image.LANCZOS)
m = ab.crop((1283 + 560, 200, 1283 + 1000, 440)).resize((880, 480), Image.LANCZOS)
r = ab.crop((2330, 250, 2566, 560)).resize((354, 465), Image.LANCZOS)
label(a, 'Arcade: Klippe km 148,8 (Gesicht zur Straße)')
label(m, 'Modern: dieselbe Klippe von der Seite – ein dünnes Horn')
label(r, 'Modern: Klippe km 150 längs')
row = Image.new('RGB', (880 + 880 + 354 + 24, 480), (255, 255, 255))
row.paste(a, (0, 0)); row.paste(m, (888, 0)); row.paste(r, (1776, 8))
top = title(turn, 'M2 Klippe: der Props-Bauer dreht Felsen zufällig – Ansicht 0° ist das Sprite, ab 45° sieht man die dünne, zerrissene Rückseite',
            'props/cliff lod0 in 70 m, Drehung 0/90/180/270 (oben) und 45/135/225/315 (unten); unten: Rennbild von AS3, Lyon–Bern km 148,7, hoch, Mittag')
w = max(top.width, row.width)
out = Image.new('RGB', (w, top.height + row.height + 10), (255, 255, 255))
out.paste(top, (0, 0)); out.paste(row, (0, top.height + 10))
save(out, '05_M2_klippe_drehung_rueckseite.jpg')

# M2 birch trunk: 15 m tile, sprite tile, foot 4x, 12 m frame
d1 = Image.open(S + 'dist_g1_h12.png').convert('RGB')
b15 = d1.crop((0, 1200, 360, 1500)); label(b15, 'Modell 15 m (1:1)')
s15 = d1.crop((0, 1500, 360, 1800)); label(s15, 'Sprite 15 m (1:1)')
sl = Image.open(S + 'slope_30.png').convert('RGB')
foot = sl.crop((360, 300, 720, 600)); label(foot, 'Stammfuß 4x: schwarze Dreiecke')
ur = Image.open(S + 'under_road.png').convert('RGB')
fr = ur.crop((0, 360, 1280, 720)).crop((300, 0, 640, 300)); fr = fr.resize((360, 318), Image.LANCZOS); label(fr, 'Spielbild 12 m (halbe Größe)')
fs = ur.crop((640, 360, 1280, 720)).crop((300, 0, 640, 300)).resize((360, 318), Image.LANCZOS); label(fs, 'Sprite dort')
out = title(grid([b15, s15, foot, fr, fs], 5), 'M1 Birkenstamm: Schachbrett aus schwarzen Dreiecken statt Birkenrinde (88 Birken in den ersten 75 km Kiel–Hamburg)',
            'Eine Farbe je Dreieck, Ringe alle 0,25 m, 6 Segmente (veg3d._bark_colour / _birch_trunk) – das Sprite zeigt weiße Rinde mit feinen grauen Querstrichen')
save(out, '06_M1_birkenstamm_schachbrett.jpg')

# M3 slope
im = Image.open(S + 'slope_30.png').convert('RGB')
out = title(im, 'M7 Hang 30° (Boden steigt von der Straße weg): Bäume stehen sauber, Büsche, Heide und Felsen schweben an der Talseite',
            'Spalten: ganzes Modell in 14 m | Fuß 4x | dasselbe links der Straße. Zeilen: Eiche, Birke, Fichte, Palme, Olive, Busch rund, Busch niedrig, Heide, Fels a, Fels b')
save(out, '07_M7_hang_30grad.jpg', q=84)
