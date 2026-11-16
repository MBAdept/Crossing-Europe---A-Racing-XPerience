"""AS1-KRITIK helpers: manifest access, sprite cells, part boxes, sheet composition (scratch only)."""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK"
WT = S + "/wt"
OUT = S + "/out"
DELIVER = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1-KRITIK"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

_models = json.load(open(WT + "/assets/models/manifest.json"))
_sprites = json.load(open(WT + "/assets/sprites/manifest.json"))["sets"]


def model(mid):
    return _models["models"][mid]


def sprite_meta(set_id):
    return _sprites[set_id]


def sprite_cell(set_id, angle="c", layer="base"):
    """RGBA cell of a sprite set (cell index = layer_row * len(angles) + angle_index)."""
    m = _sprites[set_id]
    angles = m["angles"]
    layers = m["layers"]
    cw, ch = m["cell"]
    cols = m.get("grid_cols", len(angles))
    i = layers.index(layer) * len(angles) + angles.index(angle)
    x, y = (i % cols) * cw, (i // cols) * ch
    im = Image.open(WT + "/assets/sprites/" + m["file"]).convert("RGBA")
    return im.crop((x, y, x + cw, y + ch))


def part_aabb(mid, part):
    m = model(mid)
    x0, y0, z0, x1, h, z1 = m["aabb"]
    if part == "rear":
        return [x0, 0.15, z1 - 1.3, x1, h * 0.86, z1]
    if part == "front":
        return [x0, 0.1, z0, x1, h * 0.8, z0 + 1.3]
    if part == "wheel_rr":
        for l in m["lods"]:
            for p in l["parts"]:
                if "wheel" in p and p["pos"][0] > 0 and p["pos"][2] > 0:
                    px, py, pz = p["pos"]
                    r = p["wheel"]["radius"] + 0.12
                    return [px - 0.3, 0.0, pz - r, px + 0.15, 2 * r, pz + r]
    if part == "wheel_fr":
        for l in m["lods"]:
            for p in l["parts"]:
                if "wheel" in p and p["pos"][0] > 0 and p["pos"][2] < 0:
                    px, py, pz = p["pos"]
                    r = p["wheel"]["radius"] + 0.12
                    return [px - 0.3, 0.0, pz - r, px + 0.15, 2 * r, pz + r]
    if part == "cabin":
        return [x0 * 0.82, h * 0.62, z0 * 0.2, x1 * 0.82, h, z1 * 0.8]
    if part in ("taillamp", "headlamp"):
        role = "tail" if part == "taillamp" else "head"
        for li in m.get("lights", []):
            if li["role"] == role and li["pos"][0] > 0.2:
                cx, cy, cz = li["pos"]
                return [cx - 0.34, cy - 0.2, cz - 0.3, cx + 0.26, cy + 0.2, cz + 0.3]
    return m["aabb"]


def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT, size)


def caption(img, text, size=15, pos="bottom"):
    """Caption with an outline at the bottom (or top) of the image."""
    img = img.convert("RGB")
    d = ImageDraw.Draw(img)
    f = font(size)
    y = img.height - size - 9 if pos == "bottom" else 5
    d.text((7, y), text, font=f, fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
    return img


def grid(images, cols, bg=(24, 24, 26), pad=4):
    """Images of possibly different sizes in a grid (cell size = largest image)."""
    w = max(i.width for i in images)
    h = max(i.height for i in images)
    rows = int(math.ceil(len(images) / cols))
    sheet = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad), bg)
    for k, im in enumerate(images):
        r, c = divmod(k, cols)
        sheet.paste(im.convert("RGB"), (pad + c * (w + pad), pad + r * (h + pad)))
    return sheet


def title(sheet, text, size=22, sub=None):
    """Title bar above a sheet."""
    th = size + 18 + (size if sub else 0)
    out = Image.new("RGB", (sheet.width, sheet.height + th), (14, 14, 16))
    out.paste(sheet, (0, th))
    d = ImageDraw.Draw(out)
    d.text((10, 8), text, font=font(size, True), fill=(255, 255, 255))
    if sub:
        d.text((10, 10 + size + 2), sub, font=font(int(size * 0.68)), fill=(200, 200, 205))
    return out


def tile(name, batch):
    return Image.open(os.path.join(OUT, "tiles", batch, name + ".png")).convert("RGB")


def meta(batch):
    return json.load(open(os.path.join(OUT, "tiles", batch, "_meta_%s.json" % batch)))


def crop_rect(img, rect, margin=0.12, aspect=None, min_w=0):
    """Crop around a screen rectangle [x0, y0, x1, y1] with a margin (fraction of its size)."""
    x0, y0, x1, y1 = rect
    w, h = x1 - x0, y1 - y0
    mx, my = w * margin, h * margin
    x0, x1, y0, y1 = x0 - mx, x1 + mx, y0 - my, y1 + my
    if aspect:
        cw, ch = x1 - x0, y1 - y0
        if cw / ch < aspect:
            d = (ch * aspect - cw) / 2
            x0, x1 = x0 - d, x1 + d
        else:
            d = (cw / aspect - ch) / 2
            y0, y1 = y0 - d, y1 + d
    if x1 - x0 < min_w:
        d = (min_w - (x1 - x0)) / 2
        x0, x1 = x0 - d, x1 + d
    box = (int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1)))
    return img.crop(box), box


def save_jpg(img, path, q=90):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.convert("RGB").save(path, quality=q, subsampling=0)
    return path
