"""Police cars: a traffic car design + generic country livery (bands / checks), the local word for
police on both flanks and on the rear, and a roof light bar (beacon_a = left lens, beacon_b = right).
No real emblems or coats of arms."""
import copy

import bmesh

from . import designs
from . import materials as M
from . import meshutil as MU
from . import textgeo
from .vehicles import Car, interp

BEACON = "#2f5bff"
DARK_TEXT = "#18264f"

# rear word position per base model: (z centre, max width, text height)
REAR_WORD = {
    "wagon": (0.835, 0.78, 0.075),
    "sedan": (0.69, 0.82, 0.08),
    "hatch": (0.655, 0.72, 0.07),
    "suv": (0.965, 0.84, 0.08),
}


def _lum(hexcol):
    c = M.srgb(hexcol)
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def _text_on(bg, c1):
    """Text colour readable on background bg: white on dark, c1 (if dark) or navy on light."""
    if _lum(bg) < 0.25:
        return "#ffffff"
    return c1 if _lum(c1) < 0.12 else DARK_TEXT


def livery(style, d, body, c1, c2):
    """Returns (bands, side word z, colour behind the side word). S = sill height, B = belt height."""
    S = d["clearance"] + 0.12
    B = interp(d["lower"], d["L"] * 0.5)
    h = B - S

    def z(a, b):
        return (round(S + a * h, 3), round(S + b * h, 3))

    bands = []
    word_z, word_bg = S + 0.55 * h, c1
    if style == "band":
        bands.append(dict(z=z(0.30, 0.80), color=c1, not_top=True))
    elif style == "band_pin":
        bands.append(dict(z=z(0.36, 0.80), color=c1, not_top=True))
        bands.append(dict(z=z(0.25, 0.32), color=c2, not_top=True))
        word_z = S + 0.58 * h
    elif style == "stripes":
        bands.append(dict(z=z(0.20, 0.32), color=c2, not_top=True))
        bands.append(dict(z=z(0.36, 0.78), color=c1, not_top=True))
        word_z = S + 0.57 * h
    elif style == "check":
        bands.append(dict(z=z(0.02, 0.48), color=c1, check=(0.24, round(h * 0.23, 3), c2), not_top=True))
        bands.append(dict(z=z(0.48, 0.52), color=c1, not_top=True))
        word_z, word_bg = S + 0.73 * h, body
    elif style == "lower":
        bands.append(dict(z=(0.0, round(S + 0.62 * h, 3)), color=c1, not_top=True))
        word_z = S + 0.36 * h
    elif style == "italy":
        bands.append(dict(z=(round(B - 0.24, 3), round(B - 0.03, 3)), color=c1, not_top=True))
        bands.append(dict(z=(round(B - 0.29, 3), round(B - 0.255, 3)), color=c2, not_top=True))
        word_z, word_bg = S + 0.42 * h, body
    return bands, word_z, word_bg


def _bg_at(bands, body, zc):
    col = body
    for b in bands:
        if b["z"][0] <= zc <= b["z"][1]:
            col = b["color"]
    return col


def build(rig, p):
    d = copy.deepcopy(designs.TRAFFIC_MODELS[p["model"]])
    ex = d.setdefault("extras", {})
    ex.pop("roof_rails", None)
    bands, word_z, word_bg = livery(p["style"], d, p["body"], p["c1"], p["c2"])
    car = Car(rig, d, paint=p["body"], livery=dict(bands=bands), metal=p.get("metal", 0.12), name="police").build()
    _lightbar(rig, car)
    _words(rig, car, p, bands, word_z, word_bg)
    size = car.object_size()
    size["height_m"] = round(size["height_m"] + 0.13, 3)
    return dict(object=size)


def _roof(car):
    cab = car.d["cabin"]
    zr = max(q[1] for q in cab)
    flat = [q for q in cab if q[1] > zr - 0.07]
    y = (flat[0][0] + flat[-1][0]) / 2 + 0.15
    wb, zb, zt = car.cabin_frame(y)
    return y, zt + 0.03


def _lightbar(rig, car):
    y, zr = _roof(car)
    base = M.basic("pol_bar", "#1b1c1f", rough=0.4, metal=0.3)
    chrome = M.basic("pol_bar_alu", "#b5b9be", rough=0.3, metal=1.0)
    # strength 1: no channel clips in the render (keeps the blue hue); the glow comes from the post gain
    lens_a = M.basic("pol_lens_a", "#2747c9", rough=0.12, coat=0.8, spec=0.9, emit={"beacon_a": (BEACON, 1.0)})
    lens_b = M.basic("pol_lens_b", "#2747c9", rough=0.12, coat=0.8, spec=0.9, emit={"beacon_b": (BEACON, 1.0)})
    white = M.basic("pol_white", "#d9dde2", rough=0.2, coat=0.5)
    bm = bmesh.new()
    for x in (-0.42, 0.42):
        MU.bm_box(0.06, 0.12, 0.05, (x, y, zr + 0.01), bm=bm)
    MU.make("pol_feet", bm, chrome, parent=rig.root)
    bm = MU.bm_box(1.24, 0.3, 0.035, (0.0, y, zr + 0.045))
    ob = MU.make("pol_bar", bm, base, parent=rig.root)
    MU.bevel(ob, 0.012, 2)
    for side, mat in ((-1, lens_a), (1, lens_b)):
        bm = MU.bm_box(0.5, 0.27, 0.085, (side * 0.33, y, zr + 0.105))
        ob = MU.make("pol_lens", bm, mat, parent=rig.root)
        MU.bevel(ob, 0.03, 3)
    bm = MU.bm_box(0.13, 0.26, 0.07, (0.0, y, zr + 0.1))
    ob = MU.make("pol_mid", bm, white, parent=rig.root)
    MU.bevel(ob, 0.015, 2)


def _words(rig, car, p, bands, word_z, word_bg):
    d = car.d
    word = p["word"]
    mat = M.basic("pol_word", _text_on(word_bg, p["c1"]), rough=0.35, coat=0.4)
    # flanks: on the doors, centred between the axles
    y_mid = (car.y_ra + car.y_fa) / 2 + 0.05
    span = (car.y_fa - car.y_ra) - 2 * car.Ra - 0.25
    th = min(0.16, (interp(d["lower"], y_mid) - d["clearance"]) * 0.2)
    for side in (-1, 1):
        ob = textgeo.text_mesh(rig, word, th, mat, name="pol_word_side", extrude=0.0)
        textgeo.fit(ob, span)
        textgeo.place_side(ob, side, y_mid, word_z, side * (car.W2 + 0.1), wrap=car.body, offset=0.005)
    # rear
    zc, maxw, rh = REAR_WORD[p["model"]]
    rmat = M.basic("pol_word_rear", _text_on(_bg_at(bands, p["body"], zc), p["c1"]), rough=0.35, coat=0.4)
    ob = textgeo.text_mesh(rig, word, rh, rmat, name="pol_word_rear", extrude=0.0)
    textgeo.fit(ob, maxw)
    textgeo.place_rear(ob, 0.0, zc, -0.2, wrap=car.body, offset=0.005)
