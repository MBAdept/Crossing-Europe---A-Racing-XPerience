"""Sheet: truck from the game camera - Arcade box (rear face of the box texture, placed in perspective) vs Modern."""
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image, ImageDraw

B = "k"
SID = "traffic/truck_white"
FOCAL = 711.0


def face(sid, rect):
    m = K.sprite_meta(sid)
    sheet = Image.open(K.WT + "/assets/sprites/" + m["file"]).convert("RGBA")
    x, y, w, h = rect
    return sheet.crop((x, y, x + w, y + h))


def arcade_box_frame(bg, d_rear, lights=(), night=False):
    m = K.sprite_meta(SID)
    tr = [p for p in m["parts"] if p["name"] == "trailer"][0]
    rear = face(SID, tr["faces"]["rear"])
    if night:
        r, g, b, a = rear.split()
        rear = Image.merge("RGBA", (r.point(lambda v: int(v * 0.2)), g.point(lambda v: int(v * 0.2)), b.point(lambda v: int(v * 0.24)), a))
    for lay in lights:
        for L in m["lights"][lay]:
            if L["face"] == "rear":
                rear = Image.alpha_composite(rear, face(SID, L["rect"]))
    w_m = tr["x"][1] - tr["x"][0]
    h_m = tr["y"][1] - tr["y"][0]
    s = FOCAL / d_rear
    w, h = max(1, round(w_m * s)), max(1, round(h_m * s))
    img = rear.resize((w, h), Image.LANCZOS)
    f = bg.copy().convert("RGBA")
    y_bottom = 324.0 + 3.4 * s
    f.alpha_composite(img, (round(640 - w / 2), round(y_bottom - h)))
    return f.convert("RGB")


def empty_like(img):
    e = img.copy()
    d = ImageDraw.Draw(e)
    for yy in range(325, img.height):
        d.line([(300, yy), (980, yy)], fill=img.getpixel((40, yy)))
    for yy in range(0, 325):
        d.line([(300, yy), (980, yy)], fill=img.getpixel((40, yy)))
    return e


def crop_center(img, rect, k, tw, th):
    cx, cy = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
    w, h = tw // k, th // k
    x0 = int(round(min(max(cx - w / 2, 0), img.width - w)))
    y0 = int(round(min(max(cy - h / 2, 0), img.height - h)))
    return img.crop((x0, y0, x0 + w, y0 + h)).resize((w * k, h * k), Image.NEAREST)


TW, TH = 330, 260
mt = K.meta(B)
rows = []
for state, lays, night, suffix in (("Tag", (), False, "day"), ("Tag, Brems + Blinker l", ("brake",), False, "daybrake"),
                                   ("Nacht, Rücklicht", ("tail",), True, "nighttail"), ("Nacht, Brems + Blinker l", ("tail", "brake"), True, "nightbrake")):
    ra, rm = [], []
    for d, lod in ((20, "lod0"), (60, "lod1"), (150, "lod1"), (250, "lod2")):
        n = f"truck_g{d}_{lod}_{suffix}"
        if n not in mt:
            n = f"truck_g{d}_{lod}_day" if suffix == "day" else n
        if n not in mt:
            continue
        mod = K.tile(n, B)
        rect = mt[n]["rect"]
        # the rear face only (the model's rect spans the whole 16.5 m truck): rear at d, 2.55 x 4 m
        s = FOCAL / d
        rrect = [640 - 1.6 * s, 324 + (3.4 - 4.1) * s, 640 + 1.6 * s, 324 + 3.4 * s]
        k = max(1, min(10, int(min(TW / ((rrect[2] - rrect[0]) * 1.3), TH / ((rrect[3] - rrect[1]) * 1.3)))))
        arc = arcade_box_frame(empty_like(mod), d, lights=lays, night=night)
        ra.append(K.caption(crop_center(arc, rrect, k, TW, TH), f"Arcade {d} m ({k}x)", 12))
        rm.append(K.caption(crop_center(mod, rrect, k, TW, TH), f"Modern {lod} {d} m · {state}", 12))
    rows.extend(ra + rm)
sheet = K.grid(rows, 8)
sheet = K.title(sheet, "Sattelzug von hinten aus der Spielkamera: Arcade-Quader (Heckfläche der Box-Textur) gegen Modern",
                sub="je Zeile 4x Arcade, 4x Modern; Abstand zum Heck; Nacht-Arcade mit abgedunkelter Grundfläche (Näherung), ohne Schein/Flares beider Renderer")
print(K.save_jpg(sheet, K.DELIVER + "/11_lkw_spielkamera.jpg", q=90))
