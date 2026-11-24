"""Prop catalog and dispatcher. Every prop: one 'c' column, rows base (+ lights).

Camera: orthographic, low elevation (6 deg), optional view_yaw (3/4 view for buildings, rendered for
placement on the RIGHT side of the road; tag 'mirror_left' = the renderer may flip it on the left side).
fit_h = target cell height in px (pixels per metre follow from the object height), max_w caps the width.
"""
from . import props_buildings as B
from . import props_nature as N
from . import props_road as R

E = 6.0
TREE = dict(margins=(0.4, 0.4, 0.25))
SMALL = dict(margins=(0.08, 0.08, 0.06))
BLD = dict(margins=(0.6, 0.6, 0.35))
HUGE = dict(margins=(2.0, 2.0, 1.0))

GLOW_WIN = {"lights": [(0.07, 0.3), (0.3, 0.08)]}
GLOW_LAMP = {"lights": [(0.08, 0.9), (0.35, 0.6), (1.0, 0.25)]}
GLOW_SMALL = {"lights": [(0.02, 0.9), (0.06, 0.5)]}
GLOW_BIG = {"lights": [(0.3, 0.5), (1.5, 0.35), (4.0, 0.2)]}

#  name: (builder, fit_h px, view_yaw, extra camera, lights?, glow, tags, max_w)
PROPS = {
    "tree_oak": (N.tree_oak, 352, 0, TREE, False, None, ["tree"], 512),
    "tree_beech": (N.tree_beech, 384, 0, TREE, False, None, ["tree"], 512),
    "tree_birch": (N.tree_birch, 320, 0, TREE, False, None, ["tree"], 512),
    "tree_pine": (N.tree_pine, 384, 0, TREE, False, None, ["tree"], 512),
    "tree_spruce": (N.tree_spruce, 384, 0, TREE, False, None, ["tree"], 512),
    "tree_poplar": (N.tree_poplar, 384, 0, TREE, False, None, ["tree"], 512),
    "tree_cypress": (N.tree_cypress, 320, 0, TREE, False, None, ["tree"], 512),
    "tree_olive": (N.tree_olive, 256, 0, TREE, False, None, ["tree"], 512),
    "tree_palm": (N.tree_palm, 320, 0, TREE, False, None, ["tree"], 512),
    "bush_round": (N.bush_round, 160, 0, SMALL, False, None, ["plant"], 512),
    "bush_low": (N.bush_low, 128, 0, SMALL, False, None, ["plant"], 512),
    "heather": (N.heather, 96, 0, SMALL, False, None, ["plant"], 512),
    "rock_a": (N.rock_a, 128, 0, SMALL, False, None, ["rock"], 512),
    "rock_b": (N.rock_b, 128, 0, SMALL, False, None, ["rock"], 512),
    "cliff": (N.cliff, 320, 0, BLD, False, None, ["rock"], 640),
    "haybale": (N.haybale, 96, -15, SMALL, False, None, ["farm"], 512),
    "farmhouse": (B.farmhouse, 320, -24, BLD, True, GLOW_WIN, ["building", "mirror_left"], 512),
    "barn": (B.barn, 288, -24, BLD, True, GLOW_WIN, ["building", "mirror_left"], 512),
    "church": (B.church, 512, -24, BLD, True, GLOW_WIN, ["building", "mirror_left"], 512),
    "windmill": (B.windmill, 448, 0, BLD, True, GLOW_WIN, ["building"], 512),
    "wind_turbine": (R.wind_turbine, 512, 0, HUGE, True, GLOW_BIG, ["energy"], 512),
    "power_pylon": (R.power_pylon, 512, 0, BLD, False, None, ["energy"], 512),
    "factory": (B.factory, 448, -22, BLD, True, GLOW_WIN, ["building", "mirror_left"], 640),
    "house_med": (B.house_med, 288, -24, BLD, True, GLOW_WIN, ["building", "mirror_left"], 512),
    "building_block_a": (B.building_block_a, 448, -20, BLD, True, GLOW_WIN, ["building", "city", "mirror_left"], 512),
    "building_block_b": (B.building_block_b, 480, -20, BLD, True, GLOW_WIN, ["building", "city", "mirror_left"], 512),
    "building_tall": (B.building_tall, 512, -20, BLD, True, GLOW_WIN, ["building", "city", "mirror_left"], 512),
    "building_oldtown": (B.building_oldtown, 448, -20, BLD, True, GLOW_WIN, ["building", "city", "mirror_left"], 512),
    "building_shop": (B.building_shop, 288, -20, BLD, True, GLOW_WIN, ["building", "city", "mirror_left"], 512),
    "streetlight": (R.streetlight, 300, 0, dict(margins=(1.1, 1.0, 0.1)), True, GLOW_LAMP, ["road", "mirror_left"], 512),
    "delineator": (R.delineator, 128, 0, dict(margins=(0.1, 0.06, 0.04)), True, GLOW_SMALL, ["road"], 512),
    "fuel_station": (R.fuel_station, 320, -12, BLD, True, GLOW_LAMP, ["fuel", "wide"], 640),
    "fuel_pump": (R.fuel_pump, 192, -30, SMALL, True, GLOW_LAMP, ["fuel"], 512),
    "radar_camera": (R.radar_camera, 192, 0, dict(margins=(0.15, 0.1, 0.06)), False, None, ["road"], 512),
    "customs_booth": (R.customs_booth, 224, 0, dict(margins=(0.2, 0.2, 0.12)), True, GLOW_LAMP, ["border"], 512),
    "ferry_ship": (R.ferry_ship, 400, 90, HUGE, True, GLOW_WIN, ["ship"], 1280),
}
# props keep their natural width -> anchor at the object origin, not necessarily the cell centre
UNCENTERED = {"streetlight", "fuel_station", "farmhouse", "barn", "church", "factory", "house_med",
              "building_block_a", "building_block_b", "building_tall", "building_oldtown", "building_shop",
              "fuel_pump", "ferry_ship", "haybale"}


# shadow catcher size (m) for very tall props: keeps only a contact shadow instead of a long thin streak
CATCHER = {"wind_turbine": 16.0, "power_pylon": 22.0, "building_tall": 60.0, "church": 45.0, "streetlight": 6.0}

# regional city buildings and bridge parts (docs/staedte.md sections 2 and 4)
from . import props_cities as C  # noqa: E402
PROPS.update(C.CITY_PROPS)
UNCENTERED |= C.UNCENTERED
CATCHER.update(C.CATCHER)


def prop_sets():
    out = []
    for name, (fn, fit_h, vy, cam, lights, glow, tags, max_w) in PROPS.items():
        c = dict(mode="ortho", elevation=3.5 if name == "ferry_ship" else E, fit_h=fit_h, view_yaw=float(vy),
                 angles=[("c", 0.0)], max_w=max_w, centered=name not in UNCENTERED)
        c.update(cam)
        out.append(dict(
            id="props/" + name, builder="prop", params=dict(name=name), paint=[],
            camera=c, layers=["base", "lights"] if lights else ["base"], glow=glow or {},
            tags=["prop"] + tags, shadow=0.0 if name == "ferry_ship" else 0.6, catcher=CATCHER.get(name)))
    return out


def build(rig, p):
    fn = PROPS[p["name"]][0]
    return fn(rig, p)
