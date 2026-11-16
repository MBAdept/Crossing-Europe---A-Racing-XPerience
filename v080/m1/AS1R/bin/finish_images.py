"""AS1R: raw contact sheets (out/raw) -> captioned JPGs in deliver/AS1R."""
import os

from PIL import Image, ImageDraw, ImageFont

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R/out/raw"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1R"
FB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
FN = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
NOTE = "AS1R · Software-OpenGL (llvmpipe), Licht des Kontaktbogens – Lack und Licht entscheidet der Renderer (R1/R3)"


def stack(files):
    ims = [Image.open(os.path.join(S, f)).convert("RGB") for f in files if os.path.exists(os.path.join(S, f))]
    w = max(i.width for i in ims)
    h = sum(i.height for i in ims)
    out = Image.new("RGB", (w, h), (20, 20, 22))
    y = 0
    for i in ims:
        out.paste(i, (0, y))
        y += i.height
    return out


def save(name, files, title, max_w=2600):
    im = stack(files)
    head = Image.new("RGB", (im.width, 58), (14, 14, 16))
    dr = ImageDraw.Draw(head)
    dr.text((10, 6), title, font=FB, fill=(255, 255, 255))
    dr.text((10, 35), NOTE, font=FN, fill=(190, 190, 190))
    out = Image.new("RGB", (im.width, im.height + 58))
    out.paste(head, (0, 0))
    out.paste(im, (0, 58))
    if out.width > max_w:
        k = max_w / out.width
        out = out.resize((max_w, int(out.height * k)), Image.LANCZOS)
    out.save(os.path.join(D, name), quality=87)
    print(name, out.size)


save("01_spieler_spielkamera.jpg", ["01.png"], "Spielerautos aus der Spielkamera (9 m und 30 m): Tag, Nacht Rücklicht, Nacht Bremse + Blinker")
save("02_kompakt_nah.jpg", ["02k.png"], "Kompakt nah: Heck, Rückleuchte Tag/Nacht, Rad, Vorderrad, Radhaus, Innenraum, Front")
save("02_limousine_nah.jpg", ["02l.png"], "Limousine nah: Heck, Rückleuchte Tag/Nacht, Rad, Vorderrad, Radhaus, Innenraum, Front")
save("03_spieler_ton.jpg", ["03.png"], "Spielerautos als Ton (Form ohne Lack, Glas ausgeblendet): Schulter über der Rückleuchte, Heck, Radhaus, Rad")
save("04_showroom_ab.jpg", ["04.png"], "Showroom-A/B: Echtzeit-Stufe show (links) gegen das Cycles-Sprite (rechts), dieselbe Kamera")
save("05_verkehr_nah.jpg", ["05_sedan.png", "05_hatch.png", "05_wagon.png"],
     "Verkehrsautos lod0 nah: Heck schräg, Heck nah, Rad, Rückleuchte, Seite, Nacht mit Blinker")
save("06_verkehr_spielkamera.jpg", ["06_sedan.png", "06_hatch.png", "06_wagon.png"],
     "Verkehrsautos aus der Spielkamera 10 / 30 / 80 m: Tag, Nacht Rücklicht, Nacht Bremse + Blinker")
save("08_lkw.jpg", ["08a.png", "08b.png"], "Sattelzug: Spielkamera 20 / 60 / 150 m (weiß) und Nahansichten (rot), Kontur leuchtet nachts")
save("09_schattenwerfer.jpg", ["09.png"], "Schattenwerfer rot: sichtbar nur durchs Glas, hinter Felgen und in Radläufen (Lkw-Kontur und Leuchten: eigene Farbe)")
save("10_kontaktbogen_tag.jpg", ["10p.png", "10t.png"], "Kontaktbogen Tag: jede Stufe von hinten und vorn, Farbsets, Schattenwerfer")
save("11_kontaktbogen_nacht.jpg", ["11p.png", "11t.png"], "Kontaktbogen Nacht: je Fahrzeug ein Bild pro Lampenzustand")
save("12_lampenkanaele.jpg", ["12.png"], "Prüfstreifen der 15 Lampenkanäle")
