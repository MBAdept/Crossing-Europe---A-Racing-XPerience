"""Traffic sheets: game camera Arcade vs Modern by distance (day/night), sprite camera at 4x, LOD steps, close-ups."""
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2/bin")
import klib as K

B = "t"
TYPES = list(K.TRAFFIC_NEW)


def car_box(img, bg, thr=10):
    d = np.abs(np.asarray(img).astype(int) - np.asarray(bg).astype(int)).max(axis=2) > thr
    ys, xs = np.nonzero(d)
    if len(xs) == 0:
        return 600, 400, 680, 460
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def crop_both(a, b, bg_a, bg_b, pad):
    ba = car_box(a, bg_a)
    bb = car_box(b, bg_b)
    box = (min(ba[0], bb[0]) - pad, min(ba[1], bb[1]) - pad, max(ba[2], bb[2]) + pad, max(ba[3], bb[3]) + pad)
    return a.crop(box), b.crop(box)


def sheet_game():
    e_day = K.tile("empty_day", B)
    e_ss = K.tile("empty_day_ss3", B)
    rows = []
    for car in TYPES:
        sid = "traffic/" + K.TRAFFIC_NEW[car][0]
        row = []
        for d, lod in ((10, "lod0"), (30, "lod0"), (80, "lod1"), (120, "lod2")):
            mod = K.tile(f"{car}_g{d}_{lod}_ss", B)
            spr, _ = K.traffic_sprite_frame(sid, "c", d, e_ss, ss=3.0)
            a, b = crop_both(spr, mod, e_ss, e_ss, 12)
            h = 220
            k = h / a.height
            row.append(K.caption(a.resize((max(1, int(a.width * k)), h), Image.LANCZOS), f"{car} {d} m Arcade (3x)", 12))
            row.append(K.caption(b.resize((max(1, int(b.width * k)), h), Image.LANCZOS), f"Modern {lod} (3x)", 12))
        rows.append(row)
        # game resolution, nearest neighbour
        row = []
        for d, lod in ((10, "lod0"), (30, "lod0"), (80, "lod1"), (120, "lod2")):
            mod = K.tile(f"{car}_g{d}_{lod}_day", B)
            spr, _ = K.traffic_sprite_frame(sid, "c", d, e_day, ss=1.0)
            a, b = crop_both(spr, mod, e_day, e_day, 3)
            h = 220
            k = max(1, int(h / a.height))
            row.append(K.caption(a.resize((a.width * k, a.height * k), Image.NEAREST), f"{d} m Arcade im Spiel {k}x", 12))
            row.append(K.caption(b.resize((b.width * k, b.height * k), Image.NEAREST), f"Modern {lod} im Spiel {k}x", 12))
        rows.append(row)
    widths = [max(r[i].width for r in rows) for i in range(8)]
    sheet = Image.new("RGB", (sum(widths) + 9 * 4, len(rows) * 224 + 4), (24, 24, 26))
    y = 4
    for r in rows:
        x = 4
        for i, im in enumerate(r):
            sheet.paste(im, (x, y))
            x += widths[i] + 4
        y += 224
    sheet = K.title(sheet, "Neue Verkehrsautos aus der Spielkamera: Arcade-Sprite gegen Modern (gleiche Kamera, Tag)",
                    sub="je Typ oben 3-fach überabgetastet (MSAA 4x), unten im Spielbild (1280x720, MSAA 2x) ganzzahlig vergrößert; Stufe wie bei „Details: Mittel“ (lod0 bis 40 m, lod1 bis 120 m).\nArcade zeigt die 9°-Orthoansicht des Sprites (Spiegel und Dach ohne Perspektive), Modern echte Perspektive; Renn-Look, Kontaktbogen-Rig.")
    print(K.save_jpg(sheet, K.DELIVER + "/10_verkehr_spielkamera_sprite_gegen_modern.jpg", q=88))


if __name__ == "__main__":
    sheet_game()
