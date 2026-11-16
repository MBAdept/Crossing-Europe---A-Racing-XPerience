"""KRITIK-4: compose the review sheets for deliver/KRITIK-4 from K/shots and K/ab (scratch; never committed).
   python3 compose.py            (writes numbered JPGs into DL)"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

K = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4"
DL = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-4"
S = K + "/shots"
os.makedirs(DL, exist_ok=True)


def font(size):
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def titled(img, title, size=26):
    """A header band with a title above the picture."""
    f = font(size)
    band = size + 18
    out = Image.new("RGB", (img.width, img.height + band), (24, 26, 32))
    out.paste(img, (0, band))
    d = ImageDraw.Draw(out)
    d.text((12, 8), title, fill=(240, 240, 240), font=f)
    return out


def hstack(imgs, gap=8, bg=(24, 26, 32)):
    h = max(i.height for i in imgs)
    w = sum(i.width for i in imgs) + gap * (len(imgs) - 1)
    out = Image.new("RGB", (w, h), bg)
    x = 0
    for i in imgs:
        out.paste(i, (x, 0))
        x += i.width + gap
    return out


def vstack(imgs, gap=8, bg=(24, 26, 32)):
    w = max(i.width for i in imgs)
    h = sum(i.height for i in imgs) + gap * (len(imgs) - 1)
    out = Image.new("RGB", (w, h), bg)
    y = 0
    for i in imgs:
        out.paste(i, (0, y))
        y += i.height + gap
    return out


def load(name):
    p = name if name.startswith("/") else S + "/" + name
    return Image.open(p).convert("RGB")


def fit(img, max_w=None, max_h=None):
    s = 1.0
    if max_w and img.width > max_w:
        s = min(s, max_w / img.width)
    if max_h and img.height > max_h:
        s = min(s, max_h / img.height)
    if s < 1.0:
        img = img.resize((int(img.width * s), int(img.height * s)), Image.LANCZOS)
    return img


def save(img, name, q=88):
    p = DL + "/" + name
    img.save(p, quality=q, optimize=True)
    print(p, img.size, os.path.getsize(p) // 1024, "kB")


if __name__ == "__main__":
    what = sys.argv[1:] or ["all"]
    print("compose", what)


def part1():
    """Distance sheets (model row above the Arcade sprite row), day / dusk / night."""
    for grp, title in [("land", "Land: Haus 34 m, Kirche 40 m, Fabrik 49 m, Mühle 90 m seitlich"),
                       ("stadt", "Stadt: Ladenhaus 17,6 m, Altstadt 15,5 m, Block A 21,5 m, Block B 22 m seitlich"),
                       ("bruecke", "Brücke: Pylon 7,5 m, Brückenlaterne 6 m, Fachwerkportal über der Fahrbahn"),
                       ("schiffe", "Schiffe auf Wasser (Prüf-Wasserfläche): Hausboot 25 m, Fähre 100 m (Maßstab 0,4)"),
                       ("gross", "Wahrzeichen-Ersatz: Büroturm Maßstab 2,15 bei 68 m, Kirche Maßstab 2,2 bei 69 m")]:
        cols = []
        for hour, lab in [("12", "12 Uhr"), ("19_5", "19:30"), ("23", "23 Uhr")]:
            im = load("d_%s_%s.png" % (grp, hour))
            cols.append(titled(fit(im, max_w=1080), lab, 24))
        sheet = titled(hstack(cols), "Spielkamera (Renn-Licht, Voreinstellung Mittel) – je Modell oben Modern, darunter das "
                       "Arcade-Sprite am selben Ort. " + title, 26)
        save(sheet, "%s_abstaende_tag_daemmerung_nacht.jpg" % grp)


def sheets_dist():
    """10-14: distance sheets at full size, day | dusk | night."""
    spec = [("10", "land", "Land – Haus 34 m, Kirche 40 m, Fabrik 49 m, Mühle 90 m seitlich"),
            ("11", "stadt", "Stadt – Ladenhaus 17,6 m, Altstadt 15,5 m, Block A 21,5 m, Block B 22 m seitlich"),
            ("12", "bruecke", "Brücke – Pylon 7,5 m, Brückenlaterne 6 m, Fachwerkportal über der Fahrbahn"),
            ("13", "schiffe", "Schiffe auf einer Prüf-Wasserfläche – Hausboot 25 m, Fähre 100 m (Maßstab 0,4)"),
            ("14", "gross", "Wahrzeichen-Ersatz – Büroturm Maßstab 2,15 bei 68 m, Kirche Maßstab 2,2 bei 69 m")]
    for num, grp, title in spec:
        cols = [titled(load("d_%s_%s.png" % (grp, h)), lab, 24)
                for h, lab in [("12", "12 Uhr"), ("19_5", "19:30"), ("23", "23 Uhr")]]
        sheet = titled(hstack(cols), "%s: Spielkamera mit Renn-Licht (Mittel) – je Modell oben Modern, darunter das "
                       "Arcade-Sprite am selben Ort, Ausschnitte ganzzahlig vergrößert" % title, 28)
        save(sheet, "%s_%s_abstaende_tag_daemmerung_nacht.jpg" % (num, grp))


def sheets_close():
    """20 outlines, 21/22 close-ups day/night, 25 level swaps, 26 shimmer, 27 pylon swap."""
    ua = load("umriss_a.png")
    ua = fit(ua, max_w=3000)
    save(titled(ua, "Umriss in der Sprite-Kamera (view_yaw des Sets, 6°): je Modell Sprite | Überlagerung lod0 | Modell lod0 "
                "| Überlagerung lod1 | Modell lod1 – grün = beide, orange = nur Modell, blau = nur Sprite", 28),
         "20_umrisse_sprite_gegen_modell.jpg")
    for h, lab in [("12", "Tag, 12 Uhr"), ("23", "Nacht, 23 Uhr")]:
        rows = [load("nah_%s_%s.png" % (g, h)) for g in ("land", "stadt", "rest")]
        sheet = titled(vstack(rows), "Nahansichten lod0, %s, Renn-Licht (Hoch): Anfahrt | schräg an der Fassade | "
                       "Straßenseite | von oben | Rückseite" % lab, 30)
        save(sheet, "%s_nahansichten_%s.jpg" % ("21" if h == "12" else "22", "tag" if h == "12" else "nacht"))
    rows = [titled(load("lods_%s.png" % n), t, 22) for n, t in [
        ("land_mittel", "Mittel: Umschalten bei 60 m (lod0 | lod1) und 200 m (lod1 | lod1 | Sprite)"),
        ("stadt_mittel", "Mittel, Stadthäuser 18 m seitlich"),
        ("land_hoch", "Hoch: Umschalten bei 120 m und 350 m"),
        ("stadt_hoch", "Hoch, Stadthäuser"),
        ("nacht_mittel", "Nacht 23 Uhr, Mittel")]]
    save(titled(vstack(rows), "Stufenwechsel im selben Ausschnitt (prop_scene --mode=lods, Renn-Licht 12 Uhr)", 28),
         "25_stufenwechsel.jpg")
    rows = [titled(load("flimmer_%s.png" % n), t, 22) for n, t in [
        ("bauten", "Block B, Büroturm, Windmühle, Fabrik – je oben Modell, darunter Sprite; Prozent = kippende Pixel je Viertelpixel-Schritt"),
        ("bruecke", "Pylon, Brückenlaterne"), ("portal", "Fachwerkportal")]]
    save(titled(vstack(rows), "Flimmern: Viertelpixel-Schritte seitlich bei 50/60–400 m, Modell gegen Arcade-Sprite", 28),
         "26_flimmern.jpg")
    save(titled(load("lods_pylon.png"), "Pylon (x 7,5 m) und Büroturm: lod0 | lod1 bei 60 m, lod1 bei 200 m, Sprite – "
                "der Pylon ändert beim Wechsel 58,5 % seiner Pixel (Seile 0,28 → 0,34 m)", 26),
         "27_pylon_stufenwechsel.jpg")


def sheets_evidence():
    """23 day panes brown/blue, 28 night windows Arcade vs Modern, 29 church brightness in the race."""
    a = load("nah_stadt_12_building_block_b_road.png")
    big = load("d_gross_12.png").crop((0, 0, 360, 300)).resize((720, 600), Image.NEAREST)
    house = load("d_land_12.png").crop((300, 0, 600, 250)).resize((720, 600), Image.NEAREST)
    left = titled(a, "Block B aus 7 m (lod0, 12 Uhr): Lampen-Scheiben (53,45,39)…(69,62,50) braun, Glas (39,52,63) blau", 22)
    right = vstack([titled(big, "Büroturm (Maßstab 2,15) bei 100 m: jede 3. Scheibe braun", 22),
                    titled(house, "Haus bei 100 m (lod1, 3×): braune und blaue Scheiben nebeneinander", 22)])
    save(titled(hstack([left, right]), "M3 – bei Tag verrät jede Fassade, welche Fenster nachts leuchten "
                "(Kanal-12-Lampe unbeleuchtet = Leuchtfarbe × 0,5)", 28), "23_fenster_tag_braun_blau.jpg")
    n1 = load("zz_dorf_nacht_haus.png")
    n2 = load("zz_altstadt_ab.png")
    save(titled(vstack([titled(n1, "Paris–Tours km 131,3, 23 Uhr, Haus 70 m voraus: links Arcade (Fenster bis 225), "
                               "rechts Modern (bis 165)", 22),
                        titled(n2, "Kassel–Würzburg km 203, 21 Uhr, Altstadthaus 20 m voraus: links Arcade, rechts Modern "
                               "(41 % weniger helle Fensterpixel)", 22)]),
               "M6 – nachts leuchten die Fenster matter als in Arcade (Rennbilder, gemessen)", 28),
         "28_nachtfenster_arcade_gegen_modern.jpg")
    d = load("zz_dorf_tag_ab.png")
    save(titled(d, "Paris–Tours km 130,5, 12 Uhr: oben Arcade, unten Modern – Kirche in Modern heller (Wand p95 229 gegen 203), "
                "Haus gleich hell (202 gegen 203)", 24), "29_kirche_hell_im_rennen.jpg")


AB = K + "/ab"
AB_SHEETS = [
    ("01", "rennen_pylon_seile_in_der_fahrbahn", "pylon_mittag", [1, 2, 3],
     "M1: Pylon-Seile enden in den Fahrspuren und vor der Brücke; M2: Fähren auf der Wiese – Kiel–Hamburg km 77,9 / 78,3 / 79,0, 12 Uhr, Hoch"),
    ("02", "rennen_dorf_tag", "dorf_mittag", [0, 1, 2],
     "Paris–Tours km 129,3 / 130,5 / 131,2, 12 Uhr, Hoch: Haus und Kirche wie im Arcade-Bild, gleich groß, feiner"),
    ("03", "rennen_dorf_nacht", "dorf_nacht", [0, 1],
     "Paris–Tours km 129,3 / 131,3, 23 Uhr, Hoch: Fenster warm und vereinzelt, aber matter als Arcade (M6)"),
    ("04", "rennen_altstadt_abend", "altstadt_abend", [0, 1, 2],
     "Kassel–Würzburg km 201,6 / 203,0 / 204,8, 21 Uhr, Mittel: Altstadthaus (Modell) zwischen Stadthaus-Platzhaltern"),
    ("05", "rennen_stadt_steamdeck", "stadt_deck", [0, 1],
     "Hamburg–Hannover km 142,4 / 143,3, 12 Uhr, Steam Deck 1280×800: fast nur Stadthaus-Platzhalter (AS5), Ladenhaus in der Ferne"),
    ("06", "rennen_bueroturm", "turm_nachmittag", [0, 1],
     "Dresden–Leipzig km 111,6 / 112,8, 15 Uhr, Hoch: Büroturm (Maßstab 2,15) an der Stelle des Sprites; nah bleibt das Modell im Bild"),
    ("07", "rennen_fabrik_nacht", "fabrik_nacht", [0, 1],
     "Bremen–Dortmund km 2,2 / 2,9, 23 Uhr, Hoch: Fabrik (gespiegelt) und Block B – Fenster matter als Arcade (M6)"),
]


def sheets_ab(only=None):
    for num, name, run, frames, title in AB_SHEETS:
        if only and run not in only:
            continue
        files = [AB + "/%s_ab_%02d.jpg" % (run, f) for f in frames]
        if not all(os.path.exists(f) for f in files):
            print("fehlt:", run)
            continue
        rows = [fit(load(f), max_w=2566) for f in files]
        save(titled(vstack(rows), num + " – " + title, 26), "%s_%s.jpg" % (num, name), q=86)


def sheet_factory():
    """24: factory night triangles (turn views) and the day comparison."""
    n = load("fabrik_dreh_nacht.png")
    d = load("fabrik_dreh_tag.png")
    c = load("zz_factory_night_front.png")
    save(titled(vstack([titled(n, "23 Uhr, lod0, 70 m, Drehung 0/30/60/90/180/270/315/330°", 22),
                        titled(d, "12 Uhr, Drehung 0/30/330°: dieselben Flächen grau", 22),
                        titled(c, "Nahansicht von vorn, 23 Uhr", 22)]),
               "M4 – Fabrik: die Glasbänder der Sheds leuchten nachts als reinweiße Flächen (von der Straßenseite 30°/60° unsichtbar)", 26),
         "24_fabrik_dreiecke_nacht.jpg")
