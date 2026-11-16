"""Sheets: traffic cars from the game camera at the distances they are seen, Arcade sprite placed as Arcade does
(rear-centre anchor, scale 711 / (d_rear * ppm)) against Modern at the level of 'Details: Mittel'."""
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image, ImageDraw

B = "t"
CARS = (("sedan", "traffic/sedan_red"), ("hatch", "traffic/hatch_red"), ("wagon", "traffic/wagon_green"))
FOCAL = 711.0


def arcade_frame(sid, d_center, bg, layers=("base",), night=False, ss=1.0):
    m = K.sprite_meta(sid)
    L = m["object"]["length_m"]
    ppm = m["cell"][0] / m["image_width_m"]
    zr = d_center - L * 0.5
    x, y = 640.0 * ss, (324.0 + 3.4 * FOCAL / zr) * ss
    scale = FOCAL / zr / ppm * ss
    cell = K.sprite_cell(sid, "c", "base")
    if night:
        r, g, b, a = cell.split()
        cell = Image.merge("RGBA", (r.point(lambda v: int(v * 0.2)), g.point(lambda v: int(v * 0.2)), b.point(lambda v: int(v * 0.24)), a))
    for lay in layers:
        if lay != "base":
            cell = Image.alpha_composite(cell, K.sprite_cell(sid, "c", lay))
    w, h = max(1, round(cell.width * scale)), max(1, round(cell.height * scale))
    cell = cell.resize((w, h), Image.LANCZOS)
    ax, ay = m["anchor"]
    f = bg.copy().convert("RGBA")
    f.alpha_composite(cell, (round(x - ax * w), round(y - ay * h)))
    return f.convert("RGB")


def empty_like(img):
    """Ground and sky of a game frame without the car (rows below the horizon take the ground colour of the frame's left edge)."""
    e = img.copy()
    d = ImageDraw.Draw(e)
    for yy in range(325, img.height):
        d.line([(300, yy), (980, yy)], fill=img.getpixel((40, yy)))
    return e


def crop_center(img, rect, k, tw, th):
    """Crop tw/k x th/k around the centre of rect and magnify k times (nearest)."""
    cx, cy = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
    w, h = tw // k, th // k
    x0 = int(round(min(max(cx - w / 2, 0), img.width - w)))
    y0 = int(round(min(max(cy - h / 2, 0), img.height - h)))
    return img.crop((x0, y0, x0 + w, y0 + h)).resize((w * k, h * k), Image.NEAREST)


TW, TH = 300, 200
cols = [(10, "lod0"), (20, "lod0"), (30, "lod0"), (40, "lod0"), (40, "lod1"), (80, "lod1"), (120, "lod1"), (120, "lod2"), (200, "lod2")]
rows = []
for car, sid in CARS:
    mt = K.meta(B)
    ra, rm = [], []
    for d, lod in cols:
        n = f"{car}_g{d}_{lod}_day"
        mod = K.tile(n, B)
        rect = mt[n]["rect"]
        k = max(1, min(8, int(min(TW / ((rect[2] - rect[0]) * 1.25), TH / ((rect[3] - rect[1]) * 1.25)))))
        arc = arcade_frame(sid, d, empty_like(mod))
        ra.append(K.caption(crop_center(arc, rect, k, TW, TH), f"Arcade {d} m ({k}x)", 12))
        rm.append(K.caption(crop_center(mod, rect, k, TW, TH), f"Modern {lod} {d} m ({k}x)", 12))
    rows.extend(ra)
    rows.extend(rm)
sheet = K.grid(rows, len(cols))
sheet = K.title(sheet, "Verkehrsautos aus der Spielkamera bei Tag: Arcade-Sprite (so platziert wie im Spiel) gegen Modern",
                sub="je Auto oben Arcade, unten Modern; Stufe wie „Details: Mittel“ (lod0 bis 40 m, lod1 bis 120 m), an 40 m und 120 m beide Stufen; MSAA 2x; ganzzahlig vergrößert")
print(K.save_jpg(sheet, K.DELIVER + "/07_verkehr_spielkamera_tag.jpg", q=90))

# night: Modern tail / brake + indicator against the sprite's tail / brake layers (base darkened: approximation)
cols = [(10, "lod0"), (30, "lod0"), (80, "lod1"), (150, "lod2")]
rows = []
for car, sid in CARS:
    lite = "traffic/" + ("sedan_silver" if car == "sedan" else ("hatch_white" if car == "hatch" else "wagon_silver"))
    mt = K.meta(B)
    for state, lays in (("nighttail", ("base", "tail")), ("nightbrake", ("base", "tail", "brake"))):
        ra, rm = [], []
        for d, lod in cols:
            n = f"{car}_g{d}_{lod}_{state}"
            mod = K.tile(n, B)
            rect = mt[n]["rect"]
            k = max(1, min(8, int(min(TW / ((rect[2] - rect[0]) * 1.25), TH / ((rect[3] - rect[1]) * 1.25)))))
            arc = arcade_frame(lite, d, empty_like(mod), layers=lays, night=True)
            lab = "Rücklicht" if state == "nighttail" else "Brems+Blinker l"
            ra.append(K.caption(crop_center(arc, rect, k, TW, TH), f"Arcade {lab} {d} m", 12))
            rm.append(K.caption(crop_center(mod, rect, k, TW, TH), f"Modern {lod} {lab} {d} m", 12))
        rows.extend(ra + rm)
sheet = K.grid(rows, 8)
sheet = K.title(sheet, "Verkehrsautos aus der Spielkamera bei Nacht: Rücklicht und Bremslicht + Blinker links",
                sub="je Paar links Arcade (Sprite-Schichten tail/brake; Grundbild abgedunkelt = Näherung), rechts Modern (Kontaktbogen-Nachtlicht, ohne Schein des Renderers)")
print(K.save_jpg(sheet, K.DELIVER + "/08_verkehr_spielkamera_nacht.jpg", q=90))
