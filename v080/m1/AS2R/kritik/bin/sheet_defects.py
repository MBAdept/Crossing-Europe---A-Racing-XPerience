"""Sheet 16: the defects one by one, each with its evidence crop (player cars first)."""
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

T = (640, 400)


def t(n, batch, lab, crop=None, zoom=None):
    if not K.has_tile(n, batch):
        return K.caption(Image.new("RGB", T, (40, 0, 0)), "fehlt: " + n, 13)
    im = K.tile(n, batch)
    if crop:
        im = im.crop(crop)
    if zoom:
        im = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
    k = min(T[0] / im.width, T[1] / im.height)
    im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS if k < 1 else Image.NEAREST)
    bg = Image.new("RGB", T, (24, 24, 26))
    bg.paste(im, ((T[0] - im.width) // 2, (T[1] - im.height) // 2))
    return K.caption(bg, lab, 13)


def main():
    ims = [
        # A5 sportwagen / GT front wheel arch
        t("sportwagen_sidewf", "x", "A5 Sportwagen seitlich: Radlauf liegt auf dem Reifen, Falte darüber"),
        t("sportwagen_lod0_wheelf_low", "p", "A5 von schräg unten: Reifen verschwindet im Kotflügel"),
        t("sportwagen_secwf_out", "x", "A5 Schnitt 8 cm außen: Karosserie im Reifen (weiß über rotem Ring)"),
        t("gran_turismo_sidewf", "x", "A5 Gran Turismo seitlich: Falte über dem Radlauf"),
        # A4 flakes GT, A1 paint
        t("gran_turismo_sweep_3", "x", "A4 GT 8 m: Glitzerpunkte auf Kofferraumkante (3x)", (540, 600, 740, 710), 3),
        t("gran_turismo_sweepnf_3", "x", "A4 dasselbe ohne Flocken (3x)", (540, 600, 740, 710), 3),
        # A6 reverse light kombi
        t("kombi_night_reverse", "p", "A6 Kombi: Rückfahrlicht an - kein Pixel ändert sich", (430, 200, 960, 470)),
        t("limousine_night_reverse", "p", "zum Vergleich Limousine: Rückfahrlicht sichtbar", (100, 200, 860, 470)),
        # B1 white, B2 van lod2, B3 SUV teeth, A9 diffuser
        t("van_g10_lod0_day", "t", "B1 Transporter weiß in 10 m: Fläche ohne Form", (440, 300, 840, 600)),
        t("van_lod2_side", "t", "B2 Transporter lod2: ganze obere Kastenhälfte als Glas"),
        t("suv_lod0_frontclose", "t", "B3 SUV-Front: Sägezähne an der Stoßfängerkante", (180, 330, 780, 520)),
        t("sportwagen_clay_rear34", "p", "A8 Diffusor-Finnen als Kamm unter dem Heck (Ton)", (200, 300, 760, 560)),
    ]
    sheet = K.grid(ims, 4)
    sheet = K.title(sheet, "Mängel im Einzelnen (Belege): Spielerautos zuerst, dann Verkehr",
                    sub="Kennungen wie in bericht.md Abschnitt 3 (A = Spielerautos, B = Verkehr); Software-OpenGL, Spiel-Shader mit Renn-Look, Kontaktbogen-Rig")
    print(K.save_jpg(sheet, K.DELIVER + "/16_maengel_belege.jpg", q=88))


if __name__ == "__main__":
    main()
