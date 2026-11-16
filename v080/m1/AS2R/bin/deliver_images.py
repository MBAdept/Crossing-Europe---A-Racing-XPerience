"""AS2R: copy / convert the delivery images to deliver/AS2R as JPG (quality 88), long side at most 2600 px."""
import os
import shutil

from PIL import Image

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS2R"
KS = S + "/kritik/sheets"
OD = S + "/out/deliver"
IMAGES = [
    ("01_spieler_spielkamera_sprite_gegen_modern.jpg", KS + "/01_spieler_spielkamera_sprite_gegen_modern.jpg"),
    ("02_spieler_nacht_und_bremse.jpg", KS + "/02_spieler_nacht_und_bremse.jpg"),
    ("03_showroom_ab.jpg", OD + "/k_showroom_ab.png"),
    ("04_kontaktbogen_spieler_tag.jpg", OD + "/k_tag_spieler.png"),
    ("05_kontaktbogen_spieler_nacht.jpg", OD + "/k_nacht_spieler.png"),
    ("06_kontaktbogen_verkehr_tag.jpg", OD + "/k_tag_verkehr.png"),
    ("07_kontaktbogen_verkehr_nacht.jpg", OD + "/k_nacht_verkehr.png"),
    ("08_kontaktbogen_polizei_tag.jpg", OD + "/k_tag_polizei.png"),
    ("09_lampenkanaele.jpg", OD + "/k_lampenkanaele.png"),
    ("10_verkehr_spielkamera_sprite_gegen_modern.jpg", KS + "/10_verkehr_spielkamera_sprite_gegen_modern.jpg"),
    ("13_stufenwechsel.jpg", KS + "/13_stufenwechsel.jpg"),
    ("16_maengel_belege.jpg", KS + "/16_maengel_belege.jpg"),
    ("21_radlauf_sportwagen_gt.jpg", KS + "/a5_check.jpg"),
    ("30_polizei_de_spielkamera.jpg", OD + "/h_police_de_chase.png"),
    ("31_polizei_be_spielkamera.jpg", OD + "/h_police_be_chase.png"),
    ("32_bus_spielkamera.jpg", OD + "/h_traffic_bus_chase.png"),
    ("33_planen_lkw_spielkamera.jpg", OD + "/h_traffic_truck_tarp_chase.png"),
    ("34_polizei_be_120m_karoband.jpg", KS + "/h120g_be.jpg"),
    ("35_bus_60m_heckscheibe.jpg", KS + "/hs60g_bus_white.jpg"),
    ("36_suv_120m_rest.jpg", KS + "/s120_suv_white.jpg"),
]
os.makedirs(D, exist_ok=True)
for name, src in IMAGES:
    if not os.path.exists(src):
        print("FEHLT", src)
        continue
    im = Image.open(src).convert("RGB")
    w, h = im.size
    k = min(1.0, 2600.0 / max(w, h))
    if k < 1.0:
        im = im.resize((int(w * k), int(h * k)), Image.LANCZOS)
    im.save(os.path.join(D, name), "JPEG", quality=88, optimize=True)
    print(name, im.size, os.path.getsize(os.path.join(D, name)) // 1024, "kB")
