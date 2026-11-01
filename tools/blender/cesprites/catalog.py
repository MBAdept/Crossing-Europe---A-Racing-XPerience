"""Every sprite set rendered by tools/blender/render_all.py.

A set spec:
  id        manifest set id (= output file without .png)
  builder   'player' | 'car' | 'truck' | 'bus' | 'police' | 'prop' | 'icon' | 'landmark'  (see render_all.build)
  render    'box' for trucks/buses (face images of textured boxes, contract v2 section 4)
  params    builder parameters; keys listed in 'paint' only affect the base layer (colour variants share
            geometry, shadow and light-layer renders through the cache)
  camera    mode 'ortho' (elevation deg, ppm, angles [(name, yaw_deg)], margins (side, top, bottom m),
            pivot, view_yaw for props) | 'perspective' (game camera, supersample, angles) | 'showroom' |
            'icon' (fixed cell) | 'box' (ppm, ppm_rear)
  layers    light layers after 'base'; cells are laid out in a grid (index = layer * n_angles + angle)
  glow      per light layer [(sigma_m, strength)] bloom added in post
  light_gain  per light layer brightness gain in post (emission renders stay <= 1)
  samples   base-pass samples (default 40), samples_emit for the light passes
  tags      manifest tags
"""
import json
import os

from . import designs

ANGLES5 = [("l2", -25.0), ("l1", -12.0), ("c", 0.0), ("r1", 12.0), ("r2", 25.0)]


def _angles(step, maxdeg):
    n = int(round(maxdeg / step))
    out = [("l%d" % (step * k), -float(step * k)) for k in range(n, 0, -1)]
    out.append(("c", 0.0))
    out += [("r%d" % (step * k), float(step * k)) for k in range(1, n + 1)]
    return out


# contract v2 (docs/fahrzeug-darstellung.md): traffic/police 17 ortho angles about the rear,
# player cars 21 perspective angles about the centre
ANGLES17 = _angles(3, 24)
ANGLES21 = _angles(2, 20)
CAR_LAYERS = ["base", "tail", "brake"]
SUPERSAMPLE = 2.0


def game_camera():
    """The game camera (config/game_config.json render.*) the player sprites are rendered for."""
    path = os.path.join(os.path.dirname(__file__), "..", "..", "..", "config", "game_config.json")
    r = {}
    try:
        with open(path, encoding="utf-8") as fh:
            r = json.load(fh).get("render", {})
    except (OSError, ValueError):
        pass
    return dict(fov_deg=float(r.get("fov_deg", 84.0)), height_m=float(r.get("camera_height_m", 3.4)),
                distance_m=float(r.get("camera_distance_m", 9.0)), horizon_y_frac=float(r.get("horizon_y_frac", 0.45)),
                screen=[1280, 720])
POLICE_LAYERS = ["base", "tail", "brake", "beacon_a", "beacon_b"]

GLOW_CAR = {"tail": [(0.025, 0.55), (0.08, 0.32)], "brake": [(0.03, 0.7), (0.1, 0.42)],
            "beacon_a": [(0.05, 1.0), (0.2, 0.7), (0.5, 0.25)], "beacon_b": [(0.05, 1.0), (0.2, 0.7), (0.5, 0.25)]}

PLAYER_COLORS = {
    "kompakt": ("#f0b30a", 0.0),
    "kombi": ("#1d6b45", 0.55),
    "limousine": ("#1d4ea8", 0.55),
    "sportwagen": ("#cc1419", 0.15),
    "gran_turismo": ("#b2b7bd", 0.9),
}
GLOW_PLAYER = {"tail": [(0.012, 0.5), (0.05, 0.3)], "brake": [(0.015, 0.6), (0.07, 0.38)]}

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


def player_sets():
    from . import player_cars
    out = []
    gc = game_camera()
    for vid in player_cars.DESIGNS:
        col, metal = PLAYER_COLORS[vid]
        out.append(dict(
            id="player/" + vid, builder="player", params=dict(design=vid, paint=col, metal=metal),
            paint=["paint", "metal"],
            camera=dict(mode="perspective", game=gc, supersample=SUPERSAMPLE, angles=ANGLES21, margin_px=4.0),
            layers=CAR_LAYERS, glow=GLOW_PLAYER, tags=["player"], shadow=0.62, samples=56, samples_emit=24,
            light_gain={"tail": 1.5, "brake": 1.7}, fade_px=4.0))
        out.append(dict(
            id="showroom/" + vid, builder="player", params=dict(design=vid, paint=col, metal=metal, showroom=True),
            paint=["paint", "metal"],
            camera=dict(mode="showroom", cell=(768, 480), yaw=142.0, elevation=11.0, lens=56.0, pivot="center",
                        dist_per_m=1.72, target_h=0.4, shift_y=-0.03),
            layers=["base"], glow={}, tags=["showroom"], shadow=0.7, samples=160))
    return out


def car_sets():
    out = []
    for model, colours in TRAFFIC_COLORS.items():
        if model in ("truck", "bus"):
            continue
        for cname, hexcol in colours:
            out.append(dict(
                id="traffic/%s_%s" % (model, cname), builder="car",
                params=dict(design=model, group="traffic", paint=hexcol, metal=METALLIC.get(cname, 0.35)),
                paint=["paint", "metal"],
                camera=dict(mode="ortho", elevation=9.0, ppm=52.0, angles=ANGLES17, margins=(0.1, 0.1, 0.07),
                            pivot="rear"),
                layers=CAR_LAYERS, glow=GLOW_CAR, tags=["traffic", "car"], shadow=0.75))
    return out


def heavy_sets():
    """Trucks and buses: render "box" (contract section 4) - face-on orthographic images of every visible
    face of the part boxes; rear faces at 100 px/m, sides/top at 80 px/m (all face sizes are multiples
    of 5 cm -> exact pixel rectangles)."""
    out = []
    for model in ("truck", "bus"):
        for cname, hexcol in TRAFFIC_COLORS[model]:
            out.append(dict(
                id="traffic/%s_%s" % (model, cname), builder=model, render="box",
                params=dict(paint=hexcol, variant=cname),
                camera=dict(mode="box", ppm=80.0, ppm_rear=100.0),
                layers=CAR_LAYERS, glow={"tail": [(0.02, 0.5), (0.07, 0.3)], "brake": [(0.025, 0.6), (0.09, 0.4)]},
                tags=["traffic", "heavy"], samples=32))
    return out


def police_sets():
    out = []
    for cc, p in POLICE.items():
        out.append(dict(
            id="police/" + cc, builder="police", params=dict(cc=cc, **p), paint=[],
            camera=dict(mode="ortho", elevation=9.0, ppm=56.0, angles=ANGLES17, margins=(0.1, 0.32, 0.07),
                        pivot="rear"),
            layers=POLICE_LAYERS, glow=GLOW_CAR, tags=["police", cc], shadow=0.75,
            light_gain={"beacon_a": 2.6, "beacon_b": 2.6}))
    return out


def all_sets():
    from . import icons, props
    return player_sets() + car_sets() + heavy_sets() + police_sets() + props.prop_sets() + icons.icon_sets() + landmark_sets()


def landmark_sets():
    """Landmarks landmarks/<name> (docs/staedte.md section 3), defined in props_landmarks."""
    from . import props_landmarks
    return props_landmarks.landmark_sets()
