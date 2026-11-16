import json, os, sys
from PIL import Image, ImageDraw, ImageFont
Q = sys.argv[1]; D = sys.argv[2]
T = os.path.join(Q, "tree")
man = json.load(open(os.path.join(T, "assets/sprites/manifest.json")))["sets"]
try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
except Exception:
    FONT = ImageFont.load_default()

def cell(sid, angle="c", layer="base"):
    s = man[sid]
    im = Image.open(os.path.join(T, "assets/sprites", s["file"])).convert("RGBA")
    n = len(s["angles"])
    cols = s.get("grid_cols", n)
    i = s["layers"].index(layer) * n + s["angles"].index(angle)
    w, h = s["cell"]
    x, y = (i % cols) * w, (i // cols) * h
    return im.crop((x, y, x + w, y + h))

def over(rgba, bg):
    b = Image.new("RGBA", rgba.size, bg)
    b.alpha_composite(rgba)
    return b.convert("RGB")

def label(im, text):
    im = im.copy()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, im.width, 24), fill=(0, 0, 0))
    d.text((6, 2), text, fill=(255, 255, 255), font=FONT)
    return im

def row(images, pad=6, bg=(24, 24, 24)):
    h = max(i.height for i in images)
    w = sum(i.width for i in images) + pad * (len(images) + 1)
    out = Image.new("RGB", (w, h + 2 * pad), bg)
    x = pad
    for i in images:
        out.paste(i, (x, pad))
        x += i.width + pad
    return out

def col(images, pad=0, bg=(24, 24, 24)):
    w = max(i.width for i in images)
    h = sum(i.height for i in images)
    out = Image.new("RGB", (w, h), bg)
    y = 0
    for i in images:
        out.paste(i, (0, y))
        y += i.height
    return out

def model(name):
    return Image.open(os.path.join(Q, "ab", name + ".png")).convert("RGB")

def up(im, k, res=Image.LANCZOS):
    return im.resize((im.width * k, im.height * k), res)

K = 3
# --- traffic sedan --------------------------------------------------------------------------------------
GREY = (51, 51, 54, 255)
rows = []
for ang, tag in (("c", "c"), ("l24", "p24"), ("r24", "m24")):
    sp = up(over(cell("traffic/sedan_red", ang), GREY), K)
    rows.append(row([label(sp, "Cycles-Sprite traffic/sedan_red  Winkel %s  (284x108 px, 3x)" % ang)] +
                    [label(model("ab_sedan_%s_%s" % (lod, tag)), "Echtzeit %s  (Modell-Drehung %s)" % (lod, tag)) for lod in ("lod0", "lod1", "lod2")]))
col(rows).save(os.path.join(D, "ab_verkehr_limousine_tag.png"))
# like for like: the model reduced to the sprite's resolution, both 3x nearest
rows = []
for ang, tag in (("c", "c"), ("l24", "p24")):
    sp = up(over(cell("traffic/sedan_red", ang), GREY), 4, Image.NEAREST)
    ms = [up(model("ab_sedan_%s_%s" % (lod, tag)).resize((284, 108), Image.LANCZOS), 4, Image.NEAREST) for lod in ("lod0", "lod1", "lod2")]
    rows.append(row([label(sp, "Sprite %s in Spielauflösung (4x Pixel)" % ang)] + [label(m, "Echtzeit %s auf 284x108 verkleinert" % l) for m, l in zip(ms, ("lod0", "lod1", "lod2"))]))
col(rows).save(os.path.join(D, "ab_verkehr_limousine_spielaufloesung.png"))
rows = []
for layer, state in (("tail", "tail"), ("brake", "brake")):
    base = over(cell("traffic/sedan_red", "c"), GREY).point(lambda v: int(v * 0.25))
    lay = cell("traffic/sedan_red", "c", layer)
    comp = base.convert("RGBA"); comp.alpha_composite(lay)
    sp = up(comp.convert("RGB"), K)
    rows.append(row([label(sp, "Sprite: Basis x 0.25 + Lichtebene '%s'" % layer)] +
                    [label(model("ab_sedan_%s_night_%s" % (lod, state)), "Echtzeit %s Nacht, %s" % (lod, state)) for lod in ("lod0", "lod1", "lod2")]))
rows.append(row([label(model("ab_sedan_lod0_night_" + s), "Echtzeit lod0 Nacht: " + s) for s in ("off", "indl", "indr", "rev")]))
col(rows).save(os.path.join(D, "ab_verkehr_limousine_nacht.png"))
# --- props ----------------------------------------------------------------------------------------------
GREEN = (56, 84, 31, 255)
sp = up(over(cell("props/tree_oak"), GREEN), K)
row([label(sp, "Cycles-Sprite props/tree_oak (352x352, 3x)"), label(model("ab_tree_lod0"), "Echtzeit lod0 (420 Karten)"),
     label(model("ab_tree_lod1"), "Echtzeit lod1 (140 Karten)"), label(model("ab_tree_impostor"), "Echtzeit Fernbild (Impostor)")]).resize((2112, 540)).save(os.path.join(D, "ab_eiche.png"))
for name, sid, k in (("farmhouse", "props/farmhouse", K), ("streetlight", "props/streetlight", K), ("michel", "landmarks/michel", 2)):
    sp = up(over(cell(sid), GREEN), k)
    base = over(cell(sid), GREEN).point(lambda v: int(v * 0.22))
    comp = base.convert("RGBA"); comp.alpha_composite(cell(sid, "c", "lights"))
    spn = up(comp.convert("RGB"), k)
    imgs = [label(sp, "Cycles-Sprite %s (%dx)" % (sid, k)), label(model("ab_" + name), "Echtzeit lod0, Tag"),
            label(spn, "Sprite: Basis x 0.22 + Lichtebene"), label(model("ab_" + name + "_night"), "Echtzeit lod0, Nacht (ce_night = 1)")]
    if name != "streetlight":
        imgs.insert(2, label(model("ab_" + name + "_yawneg"), "Echtzeit, andere Drehrichtung (Kontrolle)"))
    r = row(imgs)
    r.save(os.path.join(D, "ab_%s.png" % name))
# --- player car from the game camera ------------------------------------------------------------------------
s = man["player/limousine"]
SS = 1.65
cw, ch = s["cell"]
ax, ay = s["anchor"]
ox, oy = 640.0 * SS, (0.45 * 720.0 + 711.0 * 3.4 / 9.0) * SS      # screen position of the car's origin
x0, y0 = ox - ax * cw, oy - ay * ch
box = (int(round(x0)), int(round(y0)), int(round(x0)) + cw, int(round(y0)) + ch)
ASPH = (51, 51, 54, 255)
sp = over(cell("player/limousine", "c"), ASPH)
imgs = [label(up(sp, 2), "Cycles-Sprite player/limousine 'c' (572x384, 2x)")]
for lod in ("lod0", "show"):
    m = model("ab_limo_game_%s_x2" % lod).crop((box[0] * 2, box[1] * 2, box[2] * 2, box[3] * 2))
    imgs.append(label(m, "Echtzeit %s, Spielkamera 9 m (2x gerendert)" % lod))
row(imgs).save(os.path.join(D, "ab_spielerauto_spielkamera.png"))
m1 = model("ab_limo_game_lod0").crop(box)
row([label(up(sp, 3, Image.NEAREST), "Sprite in Sprite-Auflösung (3x Pixel)"), label(up(m1, 3, Image.NEAREST), "Echtzeit lod0 in derselben Auflösung (3x Pixel)")]).save(os.path.join(D, "ab_spielerauto_spielaufloesung.png"))
# overlay check of the framing: sprite alpha outline over the model render
ov = m1.convert("RGBA"); spc = cell("player/limousine", "c"); a = spc.split()[3].point(lambda v: 110 if v > 128 else 0)
red = Image.new("RGBA", spc.size, (255, 0, 0, 0)); red.putalpha(a); ov.alpha_composite(red)
ov.convert("RGB").save(os.path.join(Q, "ab", "_overlay_limo.png"))
rows = []
for layer, state in (("tail", "tail"), ("brake", "brake")):
    base = over(cell("player/limousine", "c"), ASPH).point(lambda v: int(v * 0.25))
    comp = base.convert("RGBA"); comp.alpha_composite(cell("player/limousine", "c", layer))
    mm = model("ab_limo_game_night_" + state).crop(box)
    rows.append(row([label(up(comp.convert("RGB"), 2), "Sprite: Basis x 0.25 + Lichtebene '%s'" % layer), label(up(mm, 2), "Echtzeit lod0 Nacht, %s" % state)]))
rows.append(row([label(up(model("ab_limo_game_night_" + s).crop(box), 2), "Echtzeit lod0 Nacht: " + s) for s in ("indl", "rev")]))
col(rows).save(os.path.join(D, "ab_spielerauto_nacht.png"))
print("ok")
