"""Sheet 17: the fleet - every car from the same game camera at 30 m (same crop size, 4x) and in the same 3/4 view;
sheet 18: shadow caster vs body shadow, steering and spin."""
import json
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K


def fleet():
    row1, row2 = [], []
    W, H = 150, 100           # crop at 30 m in game pixels (centred on the camera axis, ground row of the car)
    items = [("player/" + c, f"{c}_g30_day", "p", f"{c}_lod0_rear34", "p") for c in K.PLAYERS]
    items += [("traffic/" + c, f"{c}_g30_lod0_day", "t", f"{c}_lod0_rear34", "t") for c in list(K.TRAFFIC_NEW) + list(K.TRAFFIC_OLD)]
    for sid, g, gb, o, ob in items:
        if not K.has_tile(g, gb):
            continue
        im = K.tile(g, gb)
        cx, cy = 640, int(324 + 3.4 * 711 / 30.0)
        c = im.crop((cx - W // 2, cy - H + 14, cx + W // 2, cy + 14)).resize((W * 4, H * 4), Image.NEAREST)
        row1.append(K.caption(c, sid.split("/")[1] + " 30 m (4x)", 13))
        if K.has_tile(o, ob):
            row2.append(K.caption(K.tile(o, ob).resize((600, 375), Image.LANCZOS), sid.split("/")[1], 13))
    sheet = K.grid(row1 + row2, 11)
    sheet = K.title(sheet, "Die ganze Flotte: Spielkamera 30 m (gleicher Ausschnitt, 4x) und dieselbe Schrägansicht",
                    sub="Spielerautos (Renn-Look mit Füll-Licht) und alle sechs Verkehrstypen in ihrem ersten Farbset; Kontaktbogen-Rig, Tag")
    print(K.save_jpg(sheet, K.DELIVER + "/17_flotte.jpg", q=86))


def shadows():
    ims = []
    lines = ["Schatten am Boden von oben: Werfer (wie im Spiel) gegen die Karosserie selbst als Werfer, gleiche Sonne"]
    for car in K.PLAYERS:
        a = K.tile(f"{car}_shadow_caster", "p")
        b = K.tile(f"{car}_shadow_body", "p")
        A = np.asarray(a).astype(int)
        Bm = np.asarray(b).astype(int)
        d = np.abs(A - Bm).max(axis=2) > 24
        lines.append(f"  {car:13s} {int(d.sum())} px verschieden (von {A.shape[0] * A.shape[1]})")
        diff = Image.fromarray(np.where(d[..., None], np.array([255, 40, 40], np.uint8), (A * 0.6).astype(np.uint8)))
        ims += [K.caption(a.resize((320, 400)), f"{car}: Werfer", 12), K.caption(b.resize((320, 400)), "Karosserie wirft", 12),
                K.caption(diff.resize((320, 400)), "Unterschied rot", 12)]
    for car in K.TRAFFIC_NEW:
        a = K.tile(f"{car}_shadow_caster", "t")
        b = K.tile(f"{car}_shadow_body", "t")
        A = np.asarray(a).astype(int)
        Bm = np.asarray(b).astype(int)
        d = np.abs(A - Bm).max(axis=2) > 24
        lines.append(f"  {car:13s} {int(d.sum())} px verschieden")
        diff = Image.fromarray(np.where(d[..., None], np.array([255, 40, 40], np.uint8), (A * 0.6).astype(np.uint8)))
        ims += [K.caption(a.resize((320, 400)), f"{car}: Werfer", 12), K.caption(b.resize((320, 400)), "Karosserie wirft", 12),
                K.caption(diff.resize((320, 400)), "Unterschied rot", 12)]
    for n, lab in (("kombi_steer+25", "Kombi 25° eingeschlagen"), ("sportwagen_steer-25", "Sportwagen -25°"),
                   ("gran_turismo_spin45_wheelf", "GT Rad um 45° gedreht"), ("kompakt_steer+25_top", "Kompakt 25° von oben (Ton)")):
        ims.append(K.caption(K.tile(n, "p").resize((320, 400), Image.LANCZOS), lab, 12))
    sheet = K.grid(ims, 9)
    sheet = K.title(sheet, "Schattenwerfer gegen die Karosserie (Bodenschatten von oben) und Lenk-/Drehachsen der Räder")
    print(K.save_jpg(sheet, K.DELIVER + "/18_schatten_und_raeder.jpg", q=86))
    open(K.OUT + "/shadow_compare.txt", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    fleet()
    shadows()
