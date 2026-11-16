"""AS4R scratch: copy the delivery pictures with German names into deliver/AS4R (PNG composites as JPG 90)."""
import os
import shutil

from PIL import Image

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS4R"

PAIRS = [
    ("vn/pylon_rennen_01.jpg", "pylon_rennen_vorher_nachher_01.jpg"),
    ("vn/pylon_rennen_02.jpg", "pylon_rennen_vorher_nachher_02.jpg"),
    ("vn/pylon_rennen_03.jpg", "pylon_rennen_vorher_nachher_03.jpg"),
    ("vn/pylon_abstaende.jpg", "pylon_abstaende_vorher_nachher.jpg"),
    ("vn/dorf_nacht_fenster.jpg", "fenster_nacht_dorf_vorher_nachher.jpg"),
    ("vn/kirche_tag.jpg", "kirche_tag_vorher_nachher.jpg"),
    ("vn/fabrik_dreh_nacht.jpg", "fabrik_shed_nacht_vorher_nachher.jpg"),
    ("vn/fabrik_nacht_rennen.jpg", "fabrik_nacht_rennen_vorher_nachher.jpg"),
    ("vn/nah_stadt_tag_scheiben.jpg", "scheiben_tag_stadt_vorher_nachher.jpg"),
    ("vn/nah_stadt_nacht.jpg", "fenster_nacht_stadt_vorher_nachher.jpg"),
    ("vn/nah_land_nacht.jpg", "fenster_nacht_land_vorher_nachher.jpg"),
    ("vn/portal_vorher_nachher.jpg", "portal_vorher_nachher.jpg"),
]
for i in range(4):
    PAIRS.append(("ab/f_pylon_mittag_ab_%02d.jpg" % i, "ab_kiel_hamburg_km77_4_pylon_mittag_%02d.jpg" % i))
for i in range(3):
    PAIRS.append(("ab/f_dorf_nacht_ab_%02d.jpg" % i, "ab_paris_tours_km129_dorf_nacht_%02d.jpg" % i))
    PAIRS.append(("ab/f_dorf_mittag_ab_%02d.jpg" % i, "ab_paris_tours_km129_dorf_mittag_%02d.jpg" % i))
for i in range(2):
    PAIRS.append(("ab/f_fabrik_nacht_ab_%02d.jpg" % i, "ab_bremen_dortmund_km1_9_fabrik_nacht_%02d.jpg" % i))
    PAIRS.append(("ab/f_turm_nachmittag_ab_%02d.jpg" % i, "ab_dresden_leipzig_km111_turm_nachmittag_%02d.jpg" % i))
    PAIRS.append(("ab/f_elbe_deck_ab_%02d.jpg" % i, "ab_kiel_hamburg_km82_9_fachwerkportale_deck_%02d.jpg" % i))
JPG = [
    ("shots/v2_d_land_12.png", "abstaende_land_tag.jpg"),
    ("shots/v2_d_land_19_5.png", "abstaende_land_daemmerung.jpg"),
    ("shots/v2_d_land_23.png", "abstaende_land_nacht.jpg"),
    ("shots/v2_d_stadt_12.png", "abstaende_stadt_tag.jpg"),
    ("shots/v2_d_stadt_23.png", "abstaende_stadt_nacht.jpg"),
    ("shots/v2_d_gross_12.png", "abstaende_turm_kirche_gross_tag.jpg"),
    ("shots/v2_d_gross_23.png", "abstaende_turm_kirche_gross_nacht.jpg"),
    ("shots/v3_d_bruecke_12.png", "abstaende_bruecke_tag.jpg"),
    ("shots/v2_d_schiffe_12.png", "abstaende_schiffe_tag.jpg"),
    ("shots/v2_nah_land_12.png", "nahansichten_land_tag.jpg"),
    ("shots/v2_nah_land_23.png", "nahansichten_land_nacht.jpg"),
    ("shots/v2_nah_stadt_12.png", "nahansichten_stadt_tag.jpg"),
    ("shots/v2_nah_stadt_23.png", "nahansichten_stadt_nacht.jpg"),
]
os.makedirs(D, exist_ok=True)
missing = []
for src, dst in PAIRS:
    p = os.path.join(S, src)
    if os.path.exists(p):
        shutil.copyfile(p, os.path.join(D, dst))
    else:
        missing.append(src)
for src, dst in JPG:
    p = os.path.join(S, src)
    if os.path.exists(p):
        Image.open(p).convert("RGB").save(os.path.join(D, dst), quality=90)
    else:
        missing.append(src)
total = sum(os.path.getsize(os.path.join(D, f)) for f in os.listdir(D))
print("Dateien:", len(os.listdir(D)), "Größe: %.1f MB" % (total / 1e6), "fehlend:", missing)
