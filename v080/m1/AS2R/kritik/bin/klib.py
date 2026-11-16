"""KRITIK-2 helpers: manifest access, sprite cells, part boxes, sheet composition (scratch only).
Based on AS1-KRITIK kritik_lib.py."""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4"
OUT = S + "/out"
JOBS = S + "/jobs"
DELIVER = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/sheets"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

_models = json.load(open(WT + "/assets/models/manifest.json"))
_sprites = json.load(open(WT + "/assets/sprites/manifest.json"))["sets"]

PLAYERS = ["kombi", "sportwagen", "gran_turismo", "limousine", "kompakt"]
TRAFFIC_NEW = {"suv": ["suv_white", "suv_black", "suv_brown", "suv_grey"],
               "van": ["van_white", "van_darkblue", "van_red", "van_silver"],
               "sports": ["sports_red", "sports_black", "sports_blue", "sports_orange", "sports_yellow"]}
TRAFFIC_OLD = {"sedan": "sedan_red", "hatch": "hatch_red", "wagon": "wagon_green"}


def model(mid):
    return _models["models"][mid]


def sets_of(mid):
    return sorted(k for k, v in _models["sets"].items() if v.get("model") == mid)


def set_paint(sid):
    return _models["sets"][sid].get("paint", {})


def sprite_meta(set_id):
    return _sprites[set_id]


def sprite_cell(set_id, angle="c", layer="base"):
    """RGBA cell of a sprite set (cell index = layer_row * len(angles) + angle_index)."""
    m = _sprites[set_id]
    angles = m.get("angles", ["c"])
    layers = m.get("layers", ["base"])
    cw, ch = m["cell"]
    cols = m.get("grid_cols", len(angles))
    i = layers.index(layer) * len(angles) + angles.index(angle)
    x, y = (i % cols) * cw, (i // cols) * ch
    im = Image.open(WT + "/assets/sprites/" + m["file"]).convert("RGBA")
    return im.crop((x, y, x + cw, y + ch))


def wheel_parts(mid, lod="lod0"):
    m = model(mid)
    for l in m["lods"]:
        if l["name"] == lod:
            return [p for p in l["parts"] if "wheel" in p]
    return []


def part_aabb(mid, part):
    m = model(mid)
    x0, y0, z0, x1, h, z1 = m["aabb"]
    if part == "rear":
        return [x0, 0.15, z1 - 1.3, x1, h * 0.86, z1]
    if part == "front":
        return [x0, 0.1, z0, x1, h * 0.8, z0 + 1.3]
    if part in ("wheel_rr", "wheel_fr"):
        for p in wheel_parts(mid):
            if p["pos"][0] > 0 and ((p["pos"][2] > 0) == (part == "wheel_rr")):
                px, py, pz = p["pos"]
                r = p["wheel"]["radius"] + 0.12
                return [px - 0.3, 0.0, pz - r, px + 0.15, 2 * r, pz + r]
    if part == "cabin":
        return [x0 * 0.82, h * 0.62, z0 * 0.2, x1 * 0.82, h, z1 * 0.8]
    if part in ("taillamp", "headlamp"):
        role = "tail" if part == "taillamp" else "head"
        best = None
        for li in m.get("lights", []):
            if li["role"] == role and li["pos"][0] > 0.2:
                if best is None or li["pos"][0] > best["pos"][0]:
                    best = li
        if best is None:
            for li in m.get("lights", []):
                if li["role"] in (("tail", "brake") if role == "tail" else ("head",)) and li["pos"][0] > 0.1:
                    best = li
                    break
        if best is not None:
            cx, cy, cz = best["pos"]
            return [cx - 0.34, cy - 0.2, cz - 0.3, cx + 0.26, cy + 0.2, cz + 0.3]
    return m["aabb"]


def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT, size)


def caption(img, text, size=15, pos="bottom"):
    img = img.convert("RGB")
    d = ImageDraw.Draw(img)
    f = font(size)
    y = img.height - size - 9 if pos == "bottom" else 5
    d.text((7, y), text, font=f, fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
    return img


def grid(images, cols, bg=(24, 24, 26), pad=4):
    w = max(i.width for i in images)
    h = max(i.height for i in images)
    rows = int(math.ceil(len(images) / cols))
    sheet = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad), bg)
    for k, im in enumerate(images):
        r, c = divmod(k, cols)
        sheet.paste(im.convert("RGB"), (pad + c * (w + pad), pad + r * (h + pad)))
    return sheet


def title(sheet, text, size=22, sub=None):
    th = size + 18 + (int(size * 0.75) * (sub.count("\n") + 1) if sub else 0)
    out = Image.new("RGB", (sheet.width, sheet.height + th), (14, 14, 16))
    out.paste(sheet, (0, th))
    d = ImageDraw.Draw(out)
    d.text((10, 8), text, font=font(size, True), fill=(255, 255, 255))
    if sub:
        d.multiline_text((10, 10 + size + 2), sub, font=font(int(size * 0.62)), fill=(200, 200, 205), spacing=3)
    return out


def tile(name, batch):
    return Image.open(os.path.join(OUT, "tiles", batch, name + ".png")).convert("RGB")


def has_tile(name, batch):
    return os.path.exists(os.path.join(OUT, "tiles", batch, name + ".png"))


def meta(batch, jobfile=None):
    return json.load(open(os.path.join(OUT, "tiles", batch, "_meta_%s.json" % (jobfile or batch))))


def crop_rect(img, rect, margin=0.12, aspect=None, min_w=0):
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


def player_sprite_frame(sid, angle, ss, bg, dist=9.0, layers=("base",), night=False):
    """The player sprite cell as Arcade draws it on a 1280x720 screen (scaled by ss), over bg.
    road_renderer._draw_player: anchor = projected ground point of the car centre, scale = cam_d / depth / supersample."""
    m = sprite_meta(sid)
    cw, ch = m["cell"]
    sup = m["supersample"]
    ax, ay = m["anchor"]
    camd = m["camera"]["distance_m"]
    s = 711.0 / dist
    px, py = 640.0 * ss, (324.0 + 3.4 * s) * ss
    scale = ss * camd / dist / sup
    cell = sprite_cell(sid, angle, "base")
    if night:
        r, g, b, a = cell.split()
        cell = Image.merge("RGBA", (r.point(lambda v: int(v * 0.22)), g.point(lambda v: int(v * 0.22)), b.point(lambda v: int(v * 0.26)), a))
    for lay in layers:
        if lay == "base":
            continue
        cell = Image.alpha_composite(cell, sprite_cell(sid, angle, lay))
    w, h = max(1, round(cw * scale)), max(1, round(ch * scale))
    cell = cell.resize((w, h), Image.LANCZOS)
    x0, y0 = round(px - ax * w), round(py - ay * h)
    frame = bg.copy().convert("RGBA")
    frame.alpha_composite(cell, (x0, y0))
    return frame.convert("RGB"), (x0, y0, x0 + w, y0 + h)


def traffic_sprite_frame(sid, angle, dist, bg, ss=1.0, layers=("base",), lane=0.0):
    """Traffic sprite as Arcade draws it: rear anchor on the road at the car's rear (dist = depth of the car centre
    in the review camera, rear = centre + length/2 nearer), scale = 711 / (rear depth * px per metre)."""
    m = sprite_meta(sid)
    cw, ch = m["cell"]
    ax, ay = m["anchor"]
    ppm = cw / m["image_width_m"]
    L = m["object"]["length_m"]
    dr = dist - L * 0.5
    s = 711.0 / dr
    px, py = (640.0 + lane * s) * ss, (324.0 + 3.4 * s) * ss
    scale = ss * s / ppm
    cell = sprite_cell(sid, angle, "base")
    for lay in layers:
        if lay == "base":
            continue
        cell = Image.alpha_composite(cell, sprite_cell(sid, angle, lay))
    w, h = max(1, round(cw * scale)), max(1, round(ch * scale))
    cell = cell.resize((w, h), Image.LANCZOS)
    x0, y0 = round(px - ax * w), round(py - ay * h)
    frame = bg.copy().convert("RGBA")
    frame.alpha_composite(cell, (x0, y0))
    return frame.convert("RGB"), (x0, y0, x0 + w, y0 + h)
