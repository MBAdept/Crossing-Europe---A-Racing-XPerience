"""AS2b: raw contact sheets -> numbered JPGs with a German title bar in the delivery folder.

usage: finish_images.py [name ...]   (no name = all)"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080"
RAW = S + "/m1/AS2b/out/raw"
OUT = S + "/deliver/AS2b"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

POP = [[("p_%s_%d_lod%d" % (m, d, l)) for l in range(3)]
       for (m, d) in (("pol_de", 40), ("pol_de", 120), ("pol_be", 40), ("pol_be", 120),
                      ("bus", 60), ("bus", 180), ("tarp", 60), ("tarp", 180))]

ITEMS = [
    ("01_lkw_koffer_heck_20_60_150m", "Sattelzug Koffer (weiß, LOGISTIK) in der Spielkamera, Heck in 20 / 60 / 150 m – "
     "Modell neben Arcade-Quader; Nacht: Rücklicht, Bremslicht + Blinker", [["c_truck_white"]]),
    ("02_lkw_plane_transport_heck", "Planen-Sattelzug (grün) und Transport-Koffer (blau), Heck in 20 / 60 / 150 m, "
     "Modell neben Arcade-Quader (Tag)", [["c_truck_kinds"]]),
    ("03_bus_heck_20_60_150m", "Reisebus (weiß), Heck in 20 / 60 / 150 m neben dem Arcade-Quader; Nacht: Rücklicht, "
     "Bremslicht + Blinker", [["c_bus"]]),
    ("04_polizei_de_heck", "Polizei Deutschland, Heck in 20 / 60 / 150 m neben dem Arcade-Sprite; Nacht mit "
     "Blaulicht A", [["c_pol_de"]]),
    ("05_polizei_be_heck", "Polizei Belgien (Karos), Heck in 20 / 60 / 150 m neben dem Arcade-Sprite; Nacht mit "
     "Blaulicht A", [["c_pol_be"]]),
    ("06_polizei_it_heck", "Polizei Italien, Heck in 20 / 60 / 150 m neben dem Arcade-Sprite; Nacht mit Blaulicht A",
     [["c_pol_it"]]),
    ("07_polizei_alle_18_tag", "Alle 18 Polizeiautos, lod0, Tag (Heck schräg / Front schräg)", [["k_pol_day"]]),
    ("08_polizei_stufen", "Polizei Österreich, Belgien, Deutschland: lod0 / lod1 / lod2 / Schattenwerfer",
     [["k_pol_lods"]]),
    ("09_polizei_de_nacht_alle_kanaele", "Polizei Deutschland bei Nacht: jeder Lampenkanal einzeln, "
     "Blaulicht A (links) und B (rechts)", [["k_pol_night_de"]]),
    ("10_polizei_be_nacht_alle_kanaele", "Polizei Belgien bei Nacht: jeder Lampenkanal einzeln, Blaulicht A / B",
     [["k_pol_night_be"]]),
    ("11_lkw_bus_stufen_tag", "Bus und die drei Sattelzüge: lod0 / lod1 / lod2 / Schattenwerfer und die "
     "Farbsets (Tag)", [["k_heavy_day"]]),
    ("12_lkw_bus_nacht_alle_kanaele", "Sattelzug und Bus bei Nacht: jeder Lampenkanal einzeln "
     "(Umrissleuchten, Rück-, Brems-, Rückfahrlicht, Blinker, Scheinwerfer)", [["k_heavy_night"]]),
    ("13_polizei_de_nah", "Polizei Deutschland aus der Nähe: Lichtbalken mit Glas und LED-Modulen, Schriftzug, "
     "Streifen folgen der Karosserie", [["n_pol_de"]]),
    ("14_polizei_be_nah", "Polizei Belgien aus der Nähe: Karos in die Karosserie geschnitten", [["n_pol_be"]]),
    ("15_polizei_it_nah", "Polizei Italien aus der Nähe", [["n_pol_it"]]),
    ("16_bus_nah", "Reisebus aus der Nähe: Fenster, Doppeltür, Zielanzeige, Räder in Radläufen, Heck bei Nacht",
     [["n_bus"]]),
    ("17_planen_lkw_nah", "Planen-Sattelzug (rot) aus der Nähe: Plane mit Gurten, Räder, Heck bei Nacht",
     [["n_truck_tarp"]]),
    ("18_lkw_fahrerhaus_nah", "Fahrerhaus: Scheiben, Spiegel, Dachleuchten, Tritte, Tank, Radhaus",
     [["n_truck_cab"]]),
    ("19_ton_ansicht", "Ton-Ansicht (alles grau, Glas unsichtbar): Formen ohne Farbe", [["n_clay"]]),
    ("20_schattenwerfer", "Schattenwerfer (rot über dem Modell)", [["n_caster"]]),
    ("21_stufenwechsel", "Stufenwechsel in der Spielkamera (Tag): je Zeile dieselbe Entfernung, Spalten "
     "lod0 / lod1 / lod2 – Polizei bei 40 und 120 m, Lkw/Bus bei 60 und 180 m", POP),
]


def font(size, bold=False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


def compose(rows):
    imgs = [[Image.open("%s/%s.png" % (RAW, n)).convert("RGB") for n in row] for row in rows]
    w = max(sum(i.width for i in row) for row in imgs)
    h = sum(max(i.height for i in row) for row in imgs)
    out = Image.new("RGB", (w, h), (24, 24, 28))
    y = 0
    for row in imgs:
        x = 0
        for i in row:
            out.paste(i, (x, y))
            x += i.width
        y += max(i.height for i in row)
    return out


def titled(img, title):
    f = font(26, True)
    bar = 52
    out = Image.new("RGB", (img.width, img.height + bar), (18, 20, 26))
    out.paste(img, (0, bar))
    d = ImageDraw.Draw(out)
    # shrink the font until the title fits
    size = 26
    while size > 12 and d.textlength(title, font=f) > img.width - 24:
        size -= 1
        f = font(size, True)
    d.text((12, (bar - size) // 2 - 2), title, font=f, fill=(240, 240, 240))
    return out


def main():
    want = set(sys.argv[1:])
    os.makedirs(OUT, exist_ok=True)
    for name, title, rows in ITEMS:
        if want and name not in want and not any(name.startswith(w) for w in want):
            continue
        missing = [n for row in rows for n in row if not os.path.exists("%s/%s.png" % (RAW, n))]
        if missing:
            print("FEHLT", name, missing)
            continue
        img = titled(compose(rows), title)
        path = "%s/%s.jpg" % (OUT, name)
        img.save(path, quality=90, optimize=True)
        print(path, img.size, os.path.getsize(path))


main()
