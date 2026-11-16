"""AS3R scratch: the remaining delivery pictures (contact sheets as JPG with a German header, clip frames)."""
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

M1 = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1"
SH = M1 + "/AS3R/shots"
CL = M1 + "/AS3R/clip"
DL = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS3R"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FR = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
P = os.environ.get("CE_TAG", "f")   # f = renders on 4fb8187, z = renders on the final head


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def with_header(src, out, title, sub, max_w=1800, quality=88):
    img = Image.open(src).convert("RGB")
    if img.width > max_w:
        img = img.resize((max_w, int(round(img.height * max_w / img.width))), Image.LANCZOS)
    head = Image.new("RGB", (img.width, 84), (22, 26, 34))
    d = ImageDraw.Draw(head)
    d.text((12, 10), title, fill=(255, 255, 255), font=font(FB, 24))
    d.text((12, 48), sub, fill=(200, 205, 215), font=font(FR, 17))
    out_img = Image.new("RGB", (img.width, img.height + 90), (255, 255, 255))
    out_img.paste(head, (0, 0))
    out_img.paste(img, (0, 90))
    out_img.save(out, quality=quality)
    print(out, out_img.size)


def clip_sheet(frames, out):
    fr = [Image.open(CL + "/c_%03d.png" % i).convert("RGB") for i in frames]
    w, h = fr[0].size
    sheet = Image.new("RGB", (w * 2 + 6, h * 2 + 6), (255, 255, 255))
    for k, im in enumerate(fr):
        sheet.paste(im, ((k % 2) * (w + 6), (k // 2) * (h + 6)))
    tmp = SH + "/clip_sheet_tmp.png"
    sheet.save(tmp)
    with_header(tmp, out, "Baumreihe bei 120 km/h: vier Folgebilder (je 1/60 s)",
                "Eiche, Fichte, Buche, Kiefer, Pappel, Birke an der Straße, Mittag, Renn-Licht; Bilder %s des 2-s-Clips" % ", ".join(str(i) for i in frames))


def main(which):
    if which in ("all", "kontakt"):
        names = {1: "Eiche, Birke", 2: "Buche, Pappel", 3: "Olive, Kiefer", 4: "Fichte, Zypresse", 5: "Palme, runde Büsche", 6: "flacher Busch, Heide, Felsen a/b, Klippe"}
        for i in range(1, 7):
            with_header(SH + "/%s_dist_h12_%d.png" % (P, i), DL + "/kontakt_mittag_%d.jpg" % i,
                        "Mittag, Renn-Licht: %s" % names[i],
                        "je Zeile Modell und Arcade-Sprite (A/B) in 15 / 40 / 100 / 250 m, Voreinstellung Mittel")
    if which in ("all", "zeit"):
        with_header(SH + "/%s_dist_h19.5.png" % P, DL + "/daemmerung.jpg", "Dämmerung 19:30",
                    "Eiche, Birke, Fichte, Palme, Busch: Modell und Arcade-Sprite in 15 / 40 / 100 / 250 m")
        with_header(SH + "/%s_dist_h23.png" % P, DL + "/nacht.jpg", "Nacht 23 Uhr (ohne Scheinwerfer)",
                    "Eiche, Birke, Fichte, Palme, Busch: Modell und Arcade-Sprite in 15 / 40 / 100 / 250 m")
    if which in ("all", "stufen"):
        with_header(SH + "/%s.png" % (P + "_lods_h12"), DL + "/stufen_mittag.jpg",
                    "Stufen aller Bäume, Mittag",
                    "je Zeile: lod0, lod1 in 60 m | lod1, Fernbild, Arcade-Sprite in 200 m (vergrößert)")
    if which in ("all", "nebel"):
        with_header(SH + "/f_nebel.png", DL + "/fernbild_im_nebel.jpg", "Fernbild und Sprite im fernen Nebel",
                    "300 / 500 / 700 / 850 m, Mittag, Sicht 900 m: das Fernbild verblasst wie das Sprite")
    if which in ("all", "umriss"):
        with_header(SH + "/%s_outline.png" % P, DL + "/umrisse_gegen_sprite.jpg", "Umrisse gegen das Sprite",
                    "je Baum: lod0, lod1, Fernbild über dem Umriss des Arcade-Sprites (orthografisch, 6° von oben)")
    if which in ("all", "clip"):
        clip_sheet((40, 41, 42, 43), DL + "/clip_folgebilder.jpg")
        shutil.copyfile(SH + "/f_clip_120kmh.mp4", DL + "/clip_baumreihe_120kmh.mp4")


main(sys.argv[1] if len(sys.argv) > 1 else "all")
