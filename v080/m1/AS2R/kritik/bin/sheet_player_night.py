"""Sheet 02: player cars at night from the game camera (8 m and 30 m): Arcade sprite (tail / brake layers, base darkened -
an approximation of Arcade's night modulate) against Modern (tail lights, brake lights); and by day with the brake on.
Measures the red lamp pixels (tail vs brake) and the brightness ratio."""
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

B = "p"


def red_px(img, box):
    a = np.asarray(img.crop(box)).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (r > 120) & (r > 2 * g) & (r > 2 * b)
    return int(m.sum()), float(r[m].mean()) if m.any() else 0.0


def main():
    rows = []
    lines = ["Nacht, Spielkamera 8 m: rote Lampenpixel (R > 120, R > 2G, R > 2B) und ihr mittleres Rot - Rücklicht / Bremse"]
    for car in K.PLAYERS:
        sid = "player/" + car
        tail = K.tile(f"{car}_g8_nighttail", B)
        brake = K.tile(f"{car}_g8_nightbrake", B)
        day_b = K.tile(f"{car}_g8_daybrake", B)
        day = K.tile(f"{car}_g8_day", B)
        bgn = Image.new("RGB", tail.size, tuple(np.asarray(tail)[700, 40].tolist()))
        spr_t, box = K.player_sprite_frame(sid, "c", 1.0, bgn, dist=8.0, layers=("base", "tail"), night=True)
        spr_b, _ = K.player_sprite_frame(sid, "c", 1.0, bgn, dist=8.0, layers=("base", "tail", "brake"), night=True)
        x0, y0, x1, y1 = box
        cb = (x0 - 10, y0 - 10, x1 + 10, min(720, y1 + 10))
        nt, rt = red_px(tail, cb)
        nb, rb = red_px(brake, cb)
        st, srt = red_px(spr_t, cb)
        sb, srb = red_px(spr_b, cb)
        lines.append(f"  {car:13s} Modern Rücklicht {nt:5d} px (R {rt:.0f}), Bremse {nb:5d} px (R {rb:.0f}) | Arcade-Sprite tail {st:5d} px (R {srt:.0f}), brake {sb:5d} px (R {srb:.0f})")
        # day: brake on/off - mean change of the lamp pixels
        a = np.asarray(day.crop(cb)).astype(int)
        bb = np.asarray(day_b.crop(cb)).astype(int)
        d = np.abs(a - bb).max(axis=2)
        ch = d > 24
        lines.append(f"      Tag: Bremse an/aus ändert {int(ch.sum())} px um > 24 Stufen; Mittel der Helligkeit dort {a[ch].mean() if ch.any() else 0:.0f} -> {bb[ch].mean() if ch.any() else 0:.0f}")
        k = 2
        def z(im):
            c = im.crop(cb)
            return c.resize((c.width * k, c.height * k), Image.NEAREST)
        rows += [K.caption(z(spr_t), f"{car}: Arcade nachts + tail (Näherung)", 12), K.caption(z(tail), "Modern nachts: Rücklicht", 12),
                 K.caption(z(spr_b), "Arcade + brake", 12), K.caption(z(brake), "Modern: Rück + Brems", 12),
                 K.caption(z(day), "Modern Tag, Lampen aus", 12), K.caption(z(day_b), "Modern Tag, Bremse an", 12)]
    sheet = K.grid(rows, 6)
    sheet = K.title(sheet, "Spielerautos aus der Spielkamera (8 m): Nacht mit Rück- und Bremslicht, Tag mit Bremse",
                    sub="Arcade-Spalten: Sprite-Schichten base (abgedunkelt wie eine Nacht-Palette, Näherung) + tail / brake. Modern: Nacht-Rig des Kontaktbogens\n(Mond 0,1, Umgebung 0,55, Glow), Renn-Look, Füll-Licht 0,7. Was R4 als Nachtlicht setzt, ist hier nicht enthalten. 2-fach vergrößert.")
    print(K.save_jpg(sheet, K.DELIVER + "/02_spieler_nacht_und_bremse.jpg", q=88))
    open(K.OUT + "/player_night.txt", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
