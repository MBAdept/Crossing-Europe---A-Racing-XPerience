"""Every sprite set rendered by tools/blender/render_all.py.

A set spec:
  id        manifest set id (= output file without .png)
  builder   'car' | 'truck' | 'bus' | 'police' | 'prop' | 'icon'  (see render_all.BUILDERS)
  params    builder parameters; keys listed in 'paint' only affect the base layer (colour variants share
            geometry, shadow and light-layer renders through the cache)
  camera    mode ('ortho' | 'showroom' | 'icon'), elevation (deg), ppm (pixels per metre), angles
            [(name, yaw_deg)], margins (side, top, bottom in m), view_yaw (props), cell (fixed cells)
  layers    sheet rows; 'base' first
  glow      per light layer [(sigma_m, strength)] bloom added in post
  tags      manifest tags
"""
from . import designs

ANGLES5 = [("l2", -25.0), ("l1", -12.0), ("c", 0.0), ("r1", 12.0), ("r2", 25.0)]
CAR_LAYERS = ["base", "tail", "brake"]
POLICE_LAYERS = ["base", "tail", "brake", "beacon_a", "beacon_b"]

GLOW_CAR = {"tail": [(0.025, 0.55), (0.08, 0.32)], "brake": [(0.03, 0.7), (0.1, 0.42)],
            "beacon_a": [(0.05, 1.0), (0.2, 0.7), (0.5, 0.25)], "beacon_b": [(0.05, 1.0), (0.2, 0.7), (0.5, 0.25)]}

PLAYER_COLORS = {
    "kompakt": ("#f0b30a", 0.25),
    "kombi": ("#1d6b45", 0.45),
    "limousine": ("#1d4ea8", 0.5),
    "sportwagen": ("#cc1419", 0.3),
    "gran_turismo": ("#c3c8ce", 0.75),
}

TRAFFIC_COLORS = {
    "hatch": [("green", "#3d8a45"), ("yellow", "#e5bd1c"), ("white", "#e8e8e5"), ("blue", "#2c5fa8"), ("red", "#b5282a")],
    "sedan": [("red", "#b52424"), ("blue", "#24509e"), ("silver", "#a9adb4"), ("black", "#1c1e21")],
    "wagon": [("silver", "#aeb2b8"), ("darkblue", "#1f3157"), ("green", "#2f5d3a"), ("white", "#e6e6e3")],
    "suv": [("black", "#1b1c1f"), ("white", "#ececea"), ("grey", "#5f646a"), ("brown", "#6e4f37")],
    "van": [("white", "#ececea"), ("silver", "#b3b7bc"), ("red", "#a82a25"), ("darkblue", "#203a6b")],
    "sports": [("red", "#d01f1f"), ("yellow", "#f2c30f"), ("orange", "#ec6a12"), ("black", "#18191b"), ("blue", "#2350c8")],
    "truck": [("white", "#ececea"), ("red", "#b02a24"), ("blue", "#21468f"), ("green", "#2e6b3a")],
    "bus": [("white", "#efefeb"), ("red", "#b3242a"), ("blue", "#1f4f9a")],
}
METALLIC = {"silver": 0.75, "grey": 0.55, "black": 0.35, "white": 0.1, "darkblue": 0.5, "blue": 0.45, "brown": 0.5,
            "green": 0.4, "red": 0.3, "yellow": 0.15, "orange": 0.2}

# police: base model, colours and word (generic liveries, no emblems)
POLICE = {
    "de": dict(model="wagon", word="POLIZEI", style="band", body="#c9cdd3", c1="#1f4c9c", c2="#1f4c9c", metal=0.6),
    "nl": dict(model="hatch", word="POLITIE", style="stripes", body="#f2f2ef", c1="#1b3f93", c2="#e5531b"),
    "be": dict(model="wagon", word="POLICE", style="check", body="#f2f2ef", c1="#1b3a8f", c2="#e6dc1f"),
    "fr": dict(model="hatch", word="POLICE", style="lower", body="#f2f2ef", c1="#1c2f7a", c2="#d6262b"),
    "es": dict(model="sedan", word="POLICÍA", style="band", body="#f2f2ef", c1="#1b3d8c", c2="#1b3d8c"),
    "ch": dict(model="wagon", word="POLIZEI", style="check", body="#f2f2ef", c1="#e04a16", c2="#f2d21c"),
    "it": dict(model="sedan", word="POLIZIA", style="italy", body="#1f5fa8", c1="#f2f2ef", c2="#c9242b", metal=0.45),
    "si": dict(model="wagon", word="POLICIJA", style="band_pin", body="#f2f2ef", c1="#1c4f96", c2="#2f9a4a"),
    "hr": dict(model="sedan", word="POLICIJA", style="lower", body="#f2f2ef", c1="#1b3a8c", c2="#1b3a8c"),
    "rs": dict(model="sedan", word="ПОЛИЦИЈА", style="band", body="#f2f2ef", c1="#1b4a9a", c2="#1b4a9a"),
    "bg": dict(model="hatch", word="ПОЛИЦИЯ", style="band_pin", body="#f2f2ef", c1="#1b3f8f", c2="#d22a2a"),
    "hu": dict(model="sedan", word="RENDŐRSÉG", style="band_pin", body="#f2f2ef", c1="#1b3a8a", c2="#e3d61c"),
    "at": dict(model="suv", word="POLIZEI", style="band_pin", body="#eef0f2", c1="#1e4597", c2="#d3262c"),
    "cz": dict(model="wagon", word="POLICIE", style="stripes", body="#e9ecef", c1="#1c3f8f", c2="#e9d81f"),
    "pl": dict(model="sedan", word="POLICJA", style="lower", body="#eceff2", c1="#16336e", c2="#16336e", metal=0.5),
    "lt": dict(model="suv", word="POLICIJA", style="check", body="#e9ecef", c1="#1b3c8a", c2="#d8e01c"),
    "lv": dict(model="hatch", word="POLICIJA", style="check", body="#f2f2ef", c1="#1c2f6e", c2="#e3dc1c"),
}


def car_sets():
    out = []
    for vid, design in designs.PLAYER_MODELS.items():
        col, metal = PLAYER_COLORS[vid]
        out.append(dict(
            id="player/" + vid, builder="car", params=dict(design=vid, group="player", paint=col, metal=metal),
            paint=["paint", "metal"],
            camera=dict(mode="ortho", elevation=20.0, ppm=112.0, angles=ANGLES5, margins=(0.12, 0.12, 0.08)),
            layers=CAR_LAYERS, glow=GLOW_CAR, tags=["player"], shadow=0.62))
        out.append(dict(
            id="showroom/" + vid, builder="car", params=dict(design=vid, group="player", paint=col, metal=metal),
            paint=["paint", "metal"],
            camera=dict(mode="showroom", cell=(384, 240), yaw=145.0, elevation=13.0, lens=58.0),
            layers=["base"], glow={}, tags=["showroom"], shadow=0.7))
    for model, colours in TRAFFIC_COLORS.items():
        if model in ("truck", "bus"):
            continue
        for cname, hexcol in colours:
            out.append(dict(
                id="traffic/%s_%s" % (model, cname), builder="car",
                params=dict(design=model, group="traffic", paint=hexcol, metal=METALLIC.get(cname, 0.35)),
                paint=["paint", "metal"],
                camera=dict(mode="ortho", elevation=9.0, ppm=52.0, angles=ANGLES5, margins=(0.1, 0.1, 0.07)),
                layers=CAR_LAYERS, glow=GLOW_CAR, tags=["traffic", "car"], shadow=0.75))
    return out


def heavy_sets():
    out = []
    for model in ("truck", "bus"):
        for cname, hexcol in TRAFFIC_COLORS[model]:
            out.append(dict(
                id="traffic/%s_%s" % (model, cname), builder=model,
                params=dict(paint=hexcol, variant=cname),
                paint=["paint"],
                camera=dict(mode="ortho", elevation=3.5, ppm=34.0, angles=ANGLES5, margins=(0.15, 0.15, 0.1)),
                layers=CAR_LAYERS, glow=GLOW_CAR, tags=["traffic", "heavy"], shadow=0.75))
    return out


def police_sets():
    out = []
    for cc, p in POLICE.items():
        out.append(dict(
            id="police/" + cc, builder="police", params=dict(cc=cc, **p), paint=[],
            camera=dict(mode="ortho", elevation=9.0, ppm=56.0, angles=ANGLES5, margins=(0.1, 0.32, 0.07)),
            layers=POLICE_LAYERS, glow=GLOW_CAR, tags=["police", cc], shadow=0.75,
            light_gain={"beacon_a": 2.6, "beacon_b": 2.6}))
    return out


def all_sets():
    from . import icons, props
    return car_sets() + heavy_sets() + police_sets() + props.prop_sets() + icons.icon_sets()
