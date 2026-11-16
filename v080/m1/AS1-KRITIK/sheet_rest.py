import sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image
T = (640, 400)
def t(n, b, lab):
    return K.caption(K.tile(n, b).resize(T, Image.LANCZOS), lab, 14)
ims = []
for car in ("sedan", "hatch", "wagon"):
    ims += [t(f"{car}_lod0_rearclose", "t", f"{car}: Heck nah"), t(f"{car}_lod0_taillamp", "t", "Rückleuchte nah (flach, ohne Streuscheibe)"),
            t(f"{car}_lod0_night_indl", "t", "Nacht: Blinker links + Rücklicht"), t(f"{car}_lod0_wheel", "t", "Rad"),
            t(f"{car}_lod0_frontclose", "t", "Front nah"), t(f"{car}_lod0_side", "t", "Seite")]
sheet = K.grid(ims, 6)
sheet = K.title(sheet, "Verkehrsautos: Nahansichten lod0 (Spiel-Shader, Kontaktbogen-Licht, MSAA 4x)")
print(K.save_jpg(sheet, K.DELIVER + "/10_verkehr_nah.jpg", q=86))
ims = []
for car, sets in (("sedan", ["sedan_red", "sedan_black", "sedan_blue", "sedan_silver"]), ("hatch", ["hatch_red", "hatch_blue", "hatch_green", "hatch_white", "hatch_yellow"]),
                  ("wagon", ["wagon_green", "wagon_darkblue", "wagon_silver", "wagon_white"]), ("truck", ["truck_white", "truck_blue", "truck_green", "truck_red"])):
    b = "k" if car == "truck" else "t"
    for s in sets:
        ims.append(K.caption(K.tile(f"{car}_paint_{s}", b).resize((480, 300), Image.LANCZOS), s, 13))
sheet = K.grid(ims, 5)
sheet = K.title(sheet, "Alle Farbsets (gleiches Netz, Lackwerte aus dem Manifest)")
print(K.save_jpg(sheet, K.DELIVER + "/12_farbsets.jpg", q=86))
ims = [t("truck_lod0_rear34", "k", "Heck schräg"), t("truck_lod0_rearclose", "k", "Heck nah"), t("truck_lod0_night_tail", "k", "Nacht: Rücklicht (Konturmarkierung dunkel)"),
       t("truck_lod0_front34", "k", "Front schräg"), t("truck_lod0_cabclose", "k", "Fahrerhaus nah"), t("truck_lod0_wheels", "k", "Antriebsachse"),
       t("truck_clay_rear34", "k", "Ton"), t("truck_caster_side", "k", "Schattenwerfer rot = ragt aus der Haut"), t("truck_caster_rearclose", "k", "Schattenwerfer am Heck"),
       t("truck_art30_top", "k", "Knicken 30° um den Königszapfen (von oben)"), t("truck_art45_34", "k", "Knicken 45°: Auflieger-Front gegen Fahrerhaus"), t("truck_lod2_rear34", "k", "lod2 (ab 180 m)")]
sheet = K.grid(ims, 3)
sheet = K.title(sheet, "Sattelzug: Nahansichten, Ton, Schattenwerfer, Knickgelenk, ferne Stufe")
print(K.save_jpg(sheet, K.DELIVER + "/13_lkw_nah.jpg", q=86))
