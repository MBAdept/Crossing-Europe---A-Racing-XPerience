from compose import *
from PIL import Image

AS3 = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS3/'
d5 = Image.open(S + 'dist_g5_h12.png').convert('RGB')
d6 = Image.open(S + 'dist_g6_h12.png').convert('RGB')
# M4 bushes: 15 m, 40 m model vs sprite, lod1 100 m hole
t = [d5.crop((0, 1200, 360, 1500)), d5.crop((0, 1500, 360, 1800)), d5.crop((360, 1200, 720, 1500)), d5.crop((360, 1500, 720, 1800)),
     d6.crop((0, 0, 360, 300)), d6.crop((0, 300, 360, 600)), Image.open(S + 'z_bush_lod1.png').convert('RGB').crop((0, 0, 600, 440)).resize((360, 264))]
labels = ['bush_round 15 m', 'Sprite 15 m', 'bush_round 40 m (4x)', 'Sprite 40 m (4x)', 'bush_low 15 m', 'Sprite 15 m', 'lod1 100 m (8x): Loch']
for im, l in zip(t, labels):
    label(im, l, (6, 270 if im.height > 250 else 190))
out = title(grid(t, 4), 'M4 Büsche: aus der Nähe facettierte „grüne Felsbrocken“ mit Tarnmuster, blasser als das Sprite (Sättigung 0,34 gegen 0,42, gemessen)',
            'bush_round steht auf Kiel–Hamburg 76-mal in den ersten 75 km, 2–12 m neben der Fahrbahn (Zensus AS1b); lod1 in 100 m zeigt ein dunkles Loch')
save(out, '08_M4_buesche_facetten.jpg')

# M5 dome rims from below
z = Image.open(S + 'z_oakb_15.png').convert('RGB'); label(z, 'tree_oak_b 15 m (2x): Kuppelränder als gerade Vielecke, Zweige stehen aus der Krone')
d2 = Image.open(S + 'dist_g2_h12.png').convert('RGB')
b = d2.crop((0, 0, 360, 300)).resize((720, 600), Image.NEAREST); label(b, 'tree_beech 15 m (2x)')
bs = d2.crop((0, 300, 360, 600)).resize((720, 600), Image.NEAREST); label(bs, 'Sprite 15 m (2x)')
clip = Image.open(S + 'as3_clip_0.png').convert('RGB').crop((1040, 0, 1290, 500)).resize((360, 720), Image.LANCZOS); label(clip, 'Clip AS3: Buche nah')
row = grid([z, b, bs], 3)
out = title(row, 'M3 Krone aus der Nähe (< 20 m, von unten): ruhig und laubig, aber die unteren Kuppeln enden in geraden Vieleck-Kanten („Lampenschirm“)',
            'Oben feiner als das Sprite (Blattwerk statt glatter Kugeln) – die Unterkante der Krone verrät die Bauweise. Spielkamera, Renn-Licht, Mittag')
save(out, '09_M3_kuppelraender_nah.jpg')

# M6 palm
pal = d5.crop((0, 0, 1440, 1200))
u1 = Image.open(S + 'umriss/u_tree_palm_lod0.png').convert('RGB'); label(u1, 'palm lod0: 20 % außen, 69 % gedeckt')
u2 = Image.open(S + 'umriss/u_tree_palm_b_lod0.png').convert('RGB'); label(u2, 'palm_b: 57 % außen')
uc = Image.open(S + 'under_city6.png').convert('RGB').crop((0, 360, 1280, 720)); label(uc, 'Spanische Innenstadt: Palme 6 m voraus, 3,5 m seitlich (links Modell, rechts Sprite)')
top = grid([u1, u2], 2)
out1 = title(pal, 'M8 Palme: Wedel dünn und nach oben gebogen statt breit und hängend wie im Sprite; Stamm heller, wärmer und stark gestreift',
             'Zeilen: palm, Sprite, palm_b, Sprite – 15 / 40 / 100 / 250 m, Mittag')
w = max(out1.width, top.width, uc.width)
out = Image.new('RGB', (w, out1.height + top.height + uc.height + 20), (255, 255, 255))
out.paste(out1, (0, 0)); out.paste(top, (0, out1.height + 10)); out.paste(uc, (0, out1.height + top.height + 20))
save(out, '10_M8_palme.jpg')

# small defects: cypress antenna, olive 15 m, cliff top shards, oak sky hole
d4 = Image.open(S + 'dist_g4_h12.png').convert('RGB')
cy = d4.crop((360, 1200, 720, 1500)).crop((120, 0, 240, 150)).resize((240, 300), Image.NEAREST); label(cy, 'Zypresse 40 m')
cy2 = d4.crop((720, 1200, 1080, 1500)).crop((120, 20, 240, 170)).resize((240, 300), Image.NEAREST); label(cy2, '100 m lod1')
d3 = Image.open(S + 'dist_g3_h12.png').convert('RGB')
ol = d3.crop((0, 0, 360, 300)); label(ol, 'Olive 15 m: Tarnmuster')
ct = Image.open(S + 'z_cliff_top.png').convert('RGB').resize((720, 300)); label(ct, 'Klippe 40 m (3x): dunkle Zacken am Grat')
oh = Image.open(S + 'z_oak_40.png').convert('RGB').resize((300, 300)); label(oh, 'Eiche 40 m (4x): Himmelsloch')
out = title(grid([ol, ct, oh], 3), 'Kleinere Mängel: Olive aus der Nähe (M10), dunkle Zacken am Klippengrat (M2), Himmelsloch zwischen Kuppeln (M3)')
save(out, '11_kleinere_maengel.jpg')
