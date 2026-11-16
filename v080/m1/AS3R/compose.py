"""AS3R scratch: delivery sheets (before | after) from the review pictures and the new renders."""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

M1 = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1"
SH = M1 + "/AS3R/shots"
KR = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-3"
DL = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS3R"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FR = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
W = 1800
P = os.environ.get("CE_TAG", "f")   # f = renders on 4fb8187, z = renders on the final head


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def header(title, sub, width):
    img = Image.new("RGB", (width, 84 if sub else 48), (22, 26, 34))
    d = ImageDraw.Draw(img)
    d.text((12, 10), title, fill=(255, 255, 255), font=font(FB, 24))
    if sub:
        d.text((12, 48), sub, fill=(200, 205, 215), font=font(FR, 17))
    return img


def label(img, text):
    img = img.convert("RGB")
    d = ImageDraw.Draw(img)
    f = font(FB, 20)
    box = d.textbbox((0, 0), text, font=f)
    d.rectangle([4, 4, box[2] + 14, box[3] + 12], fill=(0, 0, 0))
    d.text((9, 6), text, fill=(255, 230, 80), font=f)
    return img


def fit(img, width):
    if img.width == width:
        return img
    h = int(round(img.height * width / img.width))
    return img.resize((width, h), Image.LANCZOS if width < img.width else Image.NEAREST)


def crop(path, box=None):
    img = Image.open(path).convert("RGB")
    if box:
        x0, y0, x1, y1 = box
        w, h = img.size
        img = img.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    return img


def sheet(out, title, sub, rows, width=W, quality=88):
    """rows: [[(img, label), ...], ...] - every row is scaled to `width` (its pictures side by side)."""
    parts = [header(title, sub, width)]
    for row in rows:
        imgs = [label(im, lab) if lab else im for (im, lab) in row]
        h = max(im.height for im in imgs)
        imgs = [im.resize((int(im.width * h / im.height), h), Image.LANCZOS) for im in imgs]
        strip = Image.new("RGB", (sum(im.width for im in imgs) + 6 * (len(imgs) - 1), h), (255, 255, 255))
        x = 0
        for im in imgs:
            strip.paste(im, (x, 0))
            x += im.width + 6
        parts.append(fit(strip, width))
    total = sum(p.height for p in parts) + 6 * (len(parts) - 1)
    out_img = Image.new("RGB", (width, total), (255, 255, 255))
    y = 0
    for p in parts:
        out_img.paste(p, (0, y))
        y += p.height + 6
    out_img.save(out, quality=quality)
    print(out, out_img.size)


def main(which):
    os.makedirs(DL, exist_ok=True)
    if which in ("all", "birke"):
        sheet(DL + "/01_birkenstamm_vorher_nachher.jpg", "M1 Birkenstamm: vorher Schachbrett aus Dreiecken, nachher weiße Rinde mit Querbändern",
              "oben: Kunstkritik (be866d2); darunter: AS3R in 8 / 12 / 25 m neben dem Arcade-Sprite, Mittag, Renn-Licht; unten: Fuß am 30°-Hang, 4×",
              [[(crop(KR + "/06_M1_birkenstamm_schachbrett.jpg", (0, 0.17, 1, 1)), "vorher")],
               [(crop(SH + "/f_birch_near.png"), "nachher")],
               [(crop(SH + "/f_slope_30.png", (0, 0, 1, 1 / 8.0)), "nachher: Hang 30°")]])
    if which in ("all", "klippe"):
        sheet(DL + "/02_klippe_vorher_nachher.jpg", "M2 Klippe: vorher Fetzen und Horn, nachher geschlossener Felskörper aus jeder Richtung",
              "8 Drehungen in 70 m wie der Props-Bauer sie würfelt (0° = Sprite-Ansicht); oben vorher (Kunstkritik), unten nachher",
              [[(crop(KR + "/05_M2_klippe_drehung_rueckseite.jpg", (0, 0.06, 0.9, 0.58)), "vorher")],
               [(crop(SH + "/f_turn_cliff_grid.png"), "nachher")]])
    if which in ("all", "kuppeln"):
        sheet(DL + "/03_kronen_nah_vorher_nachher.jpg", "M3 Kronen aus der Nähe: ausgefranste, hängende Kuppelränder",
              "oben vorher (Kunstkritik, 15 m, 2×), unten nachher: Eiche_b, Buche, Eiche in 15 m (2×). Offen: zwei dünne dunkle Striche oben in der Krone von tree_oak_b",
              [[(crop(KR + "/09_M3_kuppelraender_nah.jpg", (0, 0.1, 1, 1)), "vorher")],
               [(crop(SH + "/r6_near15.png", (0, 0, 1, 1 / 6.0)), "nachher Eiche_b"),
                (crop(SH + "/r6_near15.png", (0, 2 / 6.0, 1, 3 / 6.0)), "nachher Buche"),
                (crop(SH + "/r6_near15.png", (0, 4 / 6.0, 1, 5 / 6.0)), "nachher Eiche")]])
    if which in ("all", "busch"):
        d5 = SH + "/%s_dist_h12_5.png" % P
        sheet(DL + "/04_buesche_vorher_nachher.jpg", "M4 Büsche: weniger, rundere Kuppeln (12-Eck-Rand), satter, lod1 ohne Loch",
              "oben vorher (Kunstkritik); darunter nachher: bush_round, Sprite, bush_round_b, Sprite in 15 / 40 / 100 / 250 m",
              [[(crop(KR + "/08_M4_buesche_facetten.jpg", (0, 0.12, 1, 1)), "vorher")],
               [(crop(d5, (0, 0.5, 1, 1)), "nachher")]])
    if which in ("all", "fernbild"):
        sheet(DL + "/05_fernbild_vorher_nachher.jpg", "M5 Fernbild: Relief im Licht des Sprite-Rigs statt flacher Fläche",
              "Spalten: lod0, lod1 in 60 m | lod1, Fernbild, Arcade-Sprite in 200 m (vergrößert). Oben vorher (Kunstkritik), unten nachher",
              [[(crop(KR + "/12_M5_stufen_fernbild_flach.jpg", (0, 0.05, 1, 1)), "vorher")],
               [(crop(SH + "/%s_lods_h12.png" % P, (0, 0, 1, 1 / 18.0)), "nachher Eiche")],
               [(crop(SH + "/%s_lods_h12.png" % P, (0, 2 / 18.0, 1, 3 / 18.0)), "nachher Birke")],
               [(crop(SH + "/%s_lods_h12.png" % P, (0, 4 / 18.0, 1, 5 / 18.0)), "nachher Buche")],
               [(crop(SH + "/%s_lods_h12.png" % P, (0, 6 / 18.0, 1, 7 / 18.0)), "nachher Pappel")],
               [(crop(SH + "/%s_lods_h12.png" % P, (0, 12 / 18.0, 1, 13 / 18.0)), "nachher Fichte")],
               [(crop(SH + "/%s_lods_h12.png" % P, (0, 16 / 18.0, 1, 17 / 18.0)), "nachher Palme")]])
    if which in ("all", "palme"):
        d5 = SH + "/%s_dist_h12_5.png" % P
        sheet(DL + "/06_palme_vorher_nachher.jpg", "M8 Palme: breitere, hängende Wedel, dunkler Stamm mit feinen Ringen",
              "oben vorher (Kunstkritik: Palme, Sprite, palm_b, Sprite in 15 / 40 / 100 / 250 m), unten nachher (palm_b gebogen wie das Sprite, nur eine andere Saat)",
              [[(crop(KR + "/10_M8_palme.jpg", (0, 0.05, 1, 0.664)), "vorher")],
               [(crop(d5, (0, 0, 1, 0.5)), "nachher")]])
    if which in ("all", "hang"):
        sheet(DL + "/07_hang_30grad_nachher.jpg", "M7 Hang 30°: Birke, Palme, Büsche, Heide, Gras, Felsen nachher",
              "Spalten: Modell in 14 m | Fuß 4× | Fuß links 4×. Büsche und Heide mit Kernschürze, Gras ab -0,1 m, Felsfüße im Boden; die Heide braucht das Kippen an die Bodennormale (Kennzeichen ground_align)",
              [[(crop(SH + "/f_slope_30.png"), "nachher")]], width=1080)


main(sys.argv[1] if len(sys.argv) > 1 else "all")
