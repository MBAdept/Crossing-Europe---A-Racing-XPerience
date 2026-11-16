"""AS2a: raw contact sheets (out/raw) -> captioned JPGs in deliver/AS2a; LOD steps with difference images."""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a/out/raw"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS2a"
FB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
FN = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
FS = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
NOTE = ("AS2a · Software-OpenGL (llvmpipe) unter Xvfb · Spiel-Shader mit dem Lack-Look der Fahrzeug-Ebene (R3) · "
        "Licht des Kontaktbogens – Belichtung im Rennen entscheidet der Renderer")


def stack(files):
    ims = [Image.open(os.path.join(S, f)).convert("RGB") for f in files if os.path.exists(os.path.join(S, f))]
    if not ims:
        return None
    w = max(i.width for i in ims)
    h = sum(i.height for i in ims)
    out = Image.new("RGB", (w, h), (20, 20, 22))
    y = 0
    for i in ims:
        out.paste(i, (0, y))
        y += i.height
    return out


def titled(im, title, note=NOTE):
    head = Image.new("RGB", (im.width, 58), (14, 14, 16))
    dr = ImageDraw.Draw(head)
    dr.text((10, 6), title, font=FB, fill=(255, 255, 255))
    dr.text((10, 35), note, font=FN, fill=(190, 190, 190))
    out = Image.new("RGB", (im.width, im.height + 58))
    out.paste(head, (0, 0))
    out.paste(im, (0, 58))
    return out


def save(name, files, title, max_w=2800, note=NOTE):
    im = stack(files)
    if im is None:
        print("fehlt:", name)
        return
    out = titled(im, title, note)
    if out.width > max_w:
        k = max_w / out.width
        out = out.resize((max_w, int(out.height * k)), Image.LANCZOS)
    out.save(os.path.join(D, name), quality=88)
    print(name, out.size)


def pop_sheet(name, title, dist, a, b, models):
    """LOD steps: both levels at the swap distance and the difference (pixels that change by more than 24 levels)."""
    rows = []
    stats = []
    for m in models:
        pa, pb = ["%s/pop_%d_%s_%s.png" % (S, dist, m, l) for l in (a, b)]
        if not (os.path.exists(pa) and os.path.exists(pb)):
            continue
        ia = np.asarray(Image.open(pa).convert("RGB"), dtype=np.int32)
        ib = np.asarray(Image.open(pb).convert("RGB"), dtype=np.int32)
        h, w = ia.shape[:2]
        body = ia[:h - 30]
        bg = np.median(np.concatenate([body[:, :40], body[:, -40:]], axis=1), axis=1)[:, None, :]
        car = (np.abs(ia[:h - 30] - bg).max(axis=2) > 15) | (np.abs(ib[:h - 30] - bg).max(axis=2) > 15)
        changed = (np.abs(ia[:h - 30] - ib[:h - 30]).max(axis=2) > 24) & car
        diff = np.zeros_like(ia)
        diff[:h - 30][car] = (60, 60, 64)
        diff[:h - 30][changed] = (255, 40, 40)
        share = 100.0 * changed.sum() / max(1, car.sum())
        stats.append((m, share))
        di = Image.fromarray(diff.astype(np.uint8))
        dr = ImageDraw.Draw(di)
        dr.text((8, h - 24), "%s: %s -> %s, %.1f %% der Autopixel ändern sich um > 24 Stufen" % (m, a, b, share),
                font=FS, fill=(255, 255, 255))
        row = Image.new("RGB", (w * 3, h))
        row.paste(Image.open(pa).convert("RGB"), (0, 0))
        row.paste(Image.open(pb).convert("RGB"), (w, 0))
        row.paste(di, (2 * w, 0))
        rows.append(row)
    if not rows:
        print("fehlt:", name)
        return stats
    im = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows:
        im.paste(r, (0, y))
        y += r.height
    titled(im, title).save(os.path.join(D, name), quality=90)
    print(name, im.size, stats)
    return stats


if __name__ == "__main__":
    os.makedirs(D, exist_ok=True)
    save("01_spieler_spielkamera_tag_8_9_30m.jpg", ["01_chase_tag.png"],
         "Spielerautos aus der Spielkamera von hinten in 8 / 9 / 30 m, jeweils daneben das Arcade-Sprite (9 m = Rennen)")
    save("02_spieler_spielkamera_nacht.jpg", ["02_chase_nacht.png"],
         "Spielerautos aus der Spielkamera 9 / 30 m: Tag, Nacht mit Rücklicht, Nacht mit Bremslicht + Blinker links")
    save("03_kontaktbogen_tag_spieler.jpg", ["03_tag_spieler.png"],
         "Kontaktbogen Tag: Spielerautos (Rennstufe lod0, Showroom-Stufe show, Schattenwerfer)")
    save("04_kontaktbogen_nacht_spieler.jpg", ["04_nacht_spieler.png"],
         "Kontaktbogen Nacht: Spielerautos, je Lampenzustand (aus, Rück, Brems, Rück+Brems, Blinker l/r, Rückfahr, Scheinwerfer, Blinker vorn)")
    save("05_kontaktbogen_tag_verkehr.jpg", ["05_tag_verkehr.png"],
         "Kontaktbogen Tag: SUV, Transporter, Sportwagen – lod0 / lod1 / lod2, Schattenwerfer, alle Farbsets")
    save("06_kontaktbogen_nacht_verkehr.jpg", ["06_nacht_verkehr.png"],
         "Kontaktbogen Nacht: SUV, Transporter, Sportwagen je Lampenzustand")
    save("07_showroom_ab.jpg", ["07_showroom_ab.png"],
         "Showroom-A/B: Echtzeit-Stufe show (links) gegen das Cycles-Sprite (rechts), dieselbe Kamera, Tonemapper AgX wie im Showroom")
    for m, t in (("kompakt", "Kompakt"), ("kombi", "Kombi"), ("limousine", "Limousine"), ("sportwagen", "Sportwagen"),
                 ("gran_turismo", "Gran Turismo")):
        save("08_nah_%s.jpg" % m, ["08_nah_%s.png" % m],
             "%s nah: Heck schräg, Heck nah, Rückleuchte Tag/Nacht, Heck nachts (Kamerahöhe), Rad, Vorderrad, Radhaus, Innenraum, Scheinwerfer, Front" % t)
    save("09_verkehr_nah.jpg", ["09_nah_verkehr.png"],
         "SUV, Transporter, Sportwagen lod0: Heck schräg, Seite, Heck nah, Rückleuchte nah, Nacht Blinker + Rückfahrlicht, Front schräg")
    save("10_verkehr_spielkamera.jpg", ["10_verkehr_spielkamera.png"],
         "SUV, Transporter, Sportwagen aus der Spielkamera 10 / 30 / 80 m: Tag, Nacht Rücklicht, Nacht Bremse + Blinker")
    save("11_lampenkanaele.jpg", ["11_kanaele.png"], "Prüfstreifen der 15 Lampenkanäle des vpbr-Formats")
    s40 = pop_sheet("12_stufen_40m.jpg", "Stufenwechsel bei 40 m (lod0 -> lod1): beide Stufen aus der Spielkamera und die Differenz",
                    40, "lod0", "lod1", ("suv", "van", "sports"))
    s120 = pop_sheet("13_stufen_120m.jpg", "Stufenwechsel bei 120 m (lod1 -> lod2): beide Stufen aus der Spielkamera und die Differenz",
                     120, "lod1", "lod2", ("suv", "van", "sports"))
    print("pop", s40, s120)
