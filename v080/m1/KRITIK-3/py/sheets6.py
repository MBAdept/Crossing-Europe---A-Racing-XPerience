from compose import *
from PIL import Image
A = K + '/ab/'
def full_pair(name, idx, scale=0.5):
    a = Image.open(A + '%s_arcade_%02d.png' % (name, idx)).convert('RGB')
    m = Image.open(A + '%s_modern_%02d.png' % (name, idx)).convert('RGB')
    a = a.resize((int(a.width * scale), int(a.height * scale)), Image.LANCZOS)
    m = m.resize((int(m.width * scale), int(m.height * scale)), Image.LANCZOS)
    label(a, 'Arcade'); label(m, 'Modern')
    return grid([a, m], 2)
# city beeches Hamburg + poplar avenue + forest spruces
st = Image.open(S + 'z_stadt_2x.png').convert('RGB'); label(st, 'Hamburg km 92,8 (City Limits): Buchen – oben Arcade, unten Modern (2x)', (6, 470))
mv = Image.open(S + 'z_mv60_right.png').convert('RGB'); label(mv, 'Mailand–Venedig km 60,9: Pappel in etwa 25 m – links Arcade, rechts Modern', (6, 390))
df = Image.open(S + 'z_df121_right.png').convert('RGB'); label(df, 'Dortmund–Frankfurt km 122: Fichten – links Arcade, rechts Modern (1,5x)', (6, 610))
w = max(st.width, mv.width + df.width + 10)
out = Image.new('RGB', (w, st.height + max(mv.height, df.height) + 10), (255, 255, 255))
out.paste(st, (0, 0)); out.paste(mv, (0, st.height + 10)); out.paste(df, (mv.width + 10, st.height + 10))
out = title(out, 'Rennen: Stadtbuchen, Pappelallee, Fichtenwald – Modern ist feiner (Blattwerk, Nadelzweige, Schlagschatten); kleine helle Himmelspunkte in den Buchenkronen',
            'tools/ab_shot.sh, Voreinstellung Hoch, Mittag, gleicher Simulationszustand')
save(out, '15_rennen_stadt_pappel_fichte.jpg')
# bend corridor: forest and cliffs dropped in Modern
p1 = full_pair('df121_hoch', 1)
p2 = full_pair('lb_klippe_hoch', 0)
p3 = full_pair('lb_klippe_hoch', 2)
out = Image.new('RGB', (p1.width, p1.height * 3 + 20), (255, 255, 255))
out.paste(p1, (0, 0)); out.paste(p2, (0, p1.height + 10)); out.paste(p3, (0, 2 * p1.height + 20))
out = title(out, 'Hinweis an R2/R7 (nicht AS3): in Kurven lässt Modern Bäume, Felsen und Klippen im Sichtkorridor weg (F7, A-3) – Bergstrecken wirken leerer als Arcade',
            'Oben Dortmund–Frankfurt km 122 (Waldrand innen fehlt); Mitte/unten Lyon–Bern km 143,7 / 144,3 (Klippen km 144,0 und 145,2 fehlen); links Arcade, rechts Modern')
save(out, '16_rennen_kurvenkorridor_leer.jpg')
# clip frames
tiles = []
for f in (60, 61, 62, 63):
    im = Image.open(K + '/clip/c_%03d.png' % f).convert('RGB').crop((470, 170, 810, 350)).resize((680, 360), Image.NEAREST)
    label(im, 'Bild %d' % f)
    tiles.append(im)
out = title(grid(tiles, 2), 'Vier Folgebilder der Fahrt mit 120 km/h (Ausschnitt 60–300 m, 2x): kein Glitzern, ruhige Kronen',
            'prop_scene --mode=clip, Mittel, Mittag; Film 14_clip_baumreihe_120kmh.mp4')
save(out, '14_clip_folgebilder.jpg')
