import sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image
T = (640, 400)
def crop(n, b, box, lab, k=None):
    im = K.tile(n, b).crop(box)
    im = im.resize(T, Image.NEAREST if k else Image.LANCZOS)
    return K.caption(im, lab, 14)
ims = [
    crop("kompakt_g9_day", "p", (676, 540, 756, 590), "A3 Kompakt 9 m (Spielbild, 8x): schwarzer Keil über der Rückleuchte", k=1),
    crop("kompakt_lod0_taillamp", "p", (300, 150, 780, 450), "A3 Nahansicht: Keil = Blendenende steht über der Schulter"),
    crop("kompakt_clay_rearclose", "p", (560, 180, 880, 380), "A3 Ton: das Blatt steht ab"),
    crop("kompakt_lod0_wheelf", "p", (300, 160, 940, 560), "A4 Kompakt: Stoßfänger ragt 52 mm in den Vorderreifen"),
    crop("limousine_lod0_wheel", "p", (0, 160, 720, 610), "A5/A6 Stoßfänger-Kasten mit flacher Kappe; Bremsscheibe als Kugel"),
    crop("kompakt_lod0_rearclose", "p", (640, 160, 960, 360), "A7 Fugen gestrichelt bei streifendem Blick"),
    crop("sedan_lod0_rearclose", "t", (150, 80, 790, 480), "B1/B2 Verkehr: unbeleuchtete Lampen wirken an, flache Felder"),
    K.caption(Image.open(K.OUT + "/v_lodpop.png").convert("RGB").crop((736, 0, 1468, 222)).resize(T, Image.NEAREST), "B3 Stufenwechsel 120 m: lod1 | lod2 | Differenz x4", 14),
    crop("truck_caster_side", "k", (500, 300, 960, 460), "C3 Lkw: Schattenwerfer (rot) ragt aus der Hülle"),
]
sheet = K.grid(ims, 3)
sheet = K.title(sheet, "Mängel im Einzelnen (IDs wie im Bericht, Abschnitt 3)")
print(K.save_jpg(sheet, K.DELIVER + "/17_maengel_nah.jpg", q=88))
