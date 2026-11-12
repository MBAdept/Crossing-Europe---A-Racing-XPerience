"""Every real-time model of the mode "Modern" (docs/modelle.md): builder, source sprite set, options and
the sprite sets it serves. No bpy at import time (export_models.py --list / --manifest-only).

Entry: model id "<group>/<name>" (group = player | traffic | police | props | landmarks) ->
  builder   player | car | police | heavy | bus | tree | prop_vpbr | prop_baked    (ce3d.export_models.BUILDERS)
  source    sprite set whose generator build is the source (colour variants: any one of them)
  kind      vehicle | heavy | tree | plant | rock | building | landmark | furniture
  sets      sprite set ids served by the model; default = [model id]. Vehicles: {set id: paint dict}
  code      cesprites / ce3d modules whose source goes into the cache key (besides the common ones)
  ...       builder options (documented in the builder modules)
Sets without a model keep their stand-in from assets/models/sets_default.json.

The cache key of a model (cache_key) covers what its builder reads:
  code   the files of COMMON_CODE, BUILDER_CODE[builder] and the entry's "code"
  data   the entry itself; the RESOLVED sprite catalog entries of its source set and of every set it serves
         (parameters, camera with the view angle, tags ... - cesprites.catalog.all_sets()); the colour tables
         the vehicle builders read (TRAFFIC_COLORS / METALLIC, PLAYER_COLORS); for landmarks their own source
         revision instead of the whole module
A model whose paint, tags or view angle changes in the sprite catalog is exported again. (Before, the key held
only the entry and the code lists: a changed catalog left every model "aus dem Cache", and the stale
intermediates were baked.) export_models.py --check-keys tests that.
"""
import hashlib
import json
import os

from . import EXPORTER

HERE = os.path.dirname(os.path.abspath(__file__))
CESPRITES = os.path.abspath(os.path.join(HERE, "..", "cesprites"))
COMMON_CODE = ["ce3d/__init__.py", "ce3d/glb.py", "ce3d/core.py", "ce3d/roles.py", "ce3d/export.py", "ce3d/lod.py",
               "ce3d/manifest.py", "cesprites/rig.py", "cesprites/materials.py", "cesprites/meshutil.py",
               "cesprites/catalog.py"]
# render_all.py: its build() turns a sprite set into the generator model (props, trees); cesprites/props.py: the
# table of the props and their dispatcher
BUILDER_CODE = {
    "player": ["ce3d/vehicles3d.py", "ce3d/decalgeo.py", "cesprites/carinterior.py", "ce3d/extras3d.py", "cesprites/curves.py",
               "cesprites/carbody.py", "cesprites/cardetail.py", "cesprites/player_cars.py", "cesprites/textgeo.py"],
    "car": ["ce3d/traffic3d.py", "ce3d/vehicles3d.py", "ce3d/truck3d.py", "ce3d/decalgeo.py", "cesprites/vehicles.py",
            "cesprites/designs.py", "cesprites/carbody.py", "cesprites/cardetail.py", "cesprites/curves.py"],
    "heavy": ["ce3d/truck3d.py", "ce3d/vehicles3d.py", "ce3d/decalgeo.py", "cesprites/heavy.py", "ce3d/police3d.py",
              "cesprites/textgeo.py"],
    # police: the traffic car of traffic3d (all of its code) with livery, words and light bar
    "police": ["ce3d/police3d.py", "ce3d/traffic3d.py", "ce3d/vehicles3d.py", "ce3d/truck3d.py", "ce3d/decalgeo.py",
               "cesprites/vehicles.py", "cesprites/designs.py", "cesprites/carbody.py", "cesprites/cardetail.py",
               "cesprites/curves.py", "cesprites/police.py", "cesprites/textgeo.py"],
    "bus": ["ce3d/heavy3d.py", "ce3d/truck3d.py", "ce3d/vehicles3d.py", "ce3d/decalgeo.py", "cesprites/heavy.py",
            "cesprites/textgeo.py"],
    "tree": ["ce3d/veg3d.py", "ce3d/leafatlas.py", "ce3d/bake.py", "ce3d/props3d.py", "cesprites/props_nature.py",
             "cesprites/props.py", "render_all.py"],
    "prop_vpbr": ["ce3d/props3d.py", "cesprites/props.py", "render_all.py"],
    "prop_baked": ["ce3d/props3d.py", "ce3d/bake.py", "cesprites/props.py", "render_all.py"],
}

MODELS = {
    # --- vehicles ------------------------------------------------------------------------------------
    "player/limousine": dict(
        builder="player", source="player/limousine", kind="vehicle", design="limousine",
        sets={"player/limousine": {}, "showroom/limousine": {"lod": "show", "showroom": False}}),
    "player/kompakt": dict(
        builder="player", source="player/kompakt", kind="vehicle", design="kompakt",
        sets={"player/kompakt": {}, "showroom/kompakt": {"lod": "show", "showroom": False}}),
    "player/kombi": dict(
        builder="player", source="player/kombi", kind="vehicle", design="kombi",
        detail={"lod0": {"step": 3.7}},             # 4.8 m long: the body loft alone had 20,000 triangles at 3.2
        sets={"player/kombi": {}, "showroom/kombi": {"lod": "show", "showroom": False}}),
    "player/sportwagen": dict(
        builder="player", source="player/sportwagen", kind="vehicle", design="sportwagen",
        sets={"player/sportwagen": {}, "showroom/sportwagen": {"lod": "show", "showroom": False}}),
    "player/gran_turismo": dict(
        builder="player", source="player/gran_turismo", kind="vehicle", design="gran_turismo",
        sets={"player/gran_turismo": {}, "showroom/gran_turismo": {"lod": "show", "showroom": False}}),
    "traffic/sedan": dict(
        builder="car", source="traffic/sedan_red", kind="vehicle", design="sedan",
        sets={"traffic/sedan_red": {}, "traffic/sedan_blue": {}, "traffic/sedan_silver": {}, "traffic/sedan_black": {}}),
    "traffic/hatch": dict(
        builder="car", source="traffic/hatch_green", kind="vehicle", design="hatch",
        # lod2 (AS2R): a finer greenhouse takes the rear pane cut along the design's outline for fewer triangles
        # (stations near the pane's edges), the coarser lower body pays for the dark sill on the rear end
        detail={"lod2": {"gstep": 60.0, "step": 80.0}},
        sets={"traffic/hatch_green": {}, "traffic/hatch_yellow": {}, "traffic/hatch_white": {}, "traffic/hatch_blue": {},
              "traffic/hatch_red": {}}),
    "traffic/wagon": dict(
        builder="car", source="traffic/wagon_silver", kind="vehicle", design="wagon",
        detail={"lod0": {"step": 7.7, "gstep": 8.5}, "lod1": {"step": 16.0, "gstep": 24.0},
                "lod2": {"gstep": 60.0, "ends_n": 1, "step": 90.0}, "shadow": {"gstep": 120.0}},  # the long greenhouse
        # (lod2, AS2R: gstep 120 -> 60 - stations along the rear pane make its cut cheaper; step 90 for the body)
        sets={"traffic/wagon_silver": {}, "traffic/wagon_darkblue": {}, "traffic/wagon_green": {},
              "traffic/wagon_white": {}}),
    "traffic/suv": dict(
        builder="car", source="traffic/suv_black", kind="vehicle", design="suv",
        detail={"lod0": {"step": 7.3, "gstep": 7.6}, "lod1": {"step": 17.0, "gstep": 26.0},
                "lod2": {"step": 80.0, "gstep": 60.0}},             # tall body, roof rails, cladding cut
        sets={"traffic/suv_black": {}, "traffic/suv_white": {}, "traffic/suv_grey": {}, "traffic/suv_brown": {}}),
    "traffic/van": dict(
        builder="car", source="traffic/van_white", kind="vehicle", design="van",
        detail={"lod0": {"step": 9.0, "gstep": 10.0}, "lod1": {"step": 17.0, "gstep": 24.0}},     # 5.4 m long, 2.5 m high
        sets={"traffic/van_white": {}, "traffic/van_silver": {}, "traffic/van_red": {}, "traffic/van_darkblue": {}}),
    "traffic/sports": dict(
        builder="car", source="traffic/sports_red", kind="vehicle", design="sports",
        detail={"lod0": {"step": 8.2}, "lod2": {"step": 100.0, "gstep": 60.0}},      # the wing and four tail pipes
        # (lod2 gstep 60, AS2R: the rear pane cut along the design's outline is cheaper on a finer greenhouse)
        sets={"traffic/sports_red": {}, "traffic/sports_yellow": {}, "traffic/sports_orange": {}, "traffic/sports_black": {},
              "traffic/sports_blue": {}}),
    # the semitrailer: one model per kind of trailer of cesprites.heavy.TRUCK_VARIANTS (the word on the box and the
    # curtain are geometry): box with "LOGISTIK", box with "TRANSPORT", curtain sider
    "traffic/truck": dict(
        builder="heavy", source="traffic/truck_white", kind="heavy", design="truck",
        sets={"traffic/truck_white": {}}),
    "traffic/truck_transport": dict(
        builder="heavy", source="traffic/truck_blue", kind="heavy", design="truck",
        sets={"traffic/truck_blue": {}}),
    "traffic/truck_tarp": dict(
        builder="heavy", source="traffic/truck_red", kind="heavy", design="truck",
        sets={"traffic/truck_red": {}, "traffic/truck_green": {}}),
    # the coach: one rigid body as the sprite's box (one part "body"); its three colour sets are paint values
    "traffic/bus": dict(
        builder="bus", source="traffic/bus_white", kind="heavy", design="bus",
        sets={"traffic/bus_white": {}, "traffic/bus_red": {}, "traffic/bus_blue": {}}),
    # --- vegetation ----------------------------------------------------------------------------------
    "props/tree_oak": dict(builder="tree", source="props/tree_oak", kind="tree", species="oak"),
    # --- props ---------------------------------------------------------------------------------------
    # no automatic levels: 312 triangles need none, and the decimation shrinks the lamp head and drops it at the
    # two coarsest levels (lamp area 2,911 -> 2,440 -> 1,484 -> 0 -> 0 cm2) - a lamp without its light at night
    "props/streetlight": dict(
        builder="prop_vpbr", source="props/streetlight", kind="furniture", auto_lod=False,
        code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    "props/farmhouse": dict(
        builder="prop_baked", source="props/farmhouse", kind="building", atlas=(1024, 1024), ppm_max=96.0,
        roughness=0.9, auto_lod=True, view="roadside", params={"allround": True},
        code=["cesprites/props_buildings.py"]),
    # --- landmarks -----------------------------------------------------------------------------------
    "landmarks/michel": dict(
        builder="prop_baked", source="landmarks/michel", kind="landmark", atlas=(2048, 2048), ppm_max=24.0,
        roughness=0.85, auto_lod=True, view="allround", params={"allround": True},
        code=["cesprites/props_buildings.py"]),       # + the landmark's own revision (see cache_key)
}


# --- AS1b (wave 2): the environment of the slice Kiel - Hamburg (docs/modelle.md section 14). Own block: it
# replaces the wave-0 entries of tree_oak, farmhouse and streetlight above (kept there for the merge with the
# vehicle packages) and adds the other props of the slice.
#   variant_of   a second seed of a species: no sets of its own, the species' set lists it in "variants"
#   source None  no sprite set behind the model (ground cover, contract A-3): its set is Modern-only
#                ("modern_only": true in the manifest), the props builder places it inside bend corridors
BUILDER_CODE.update({
    "bush": ["ce3d/veg3d.py", "ce3d/leafatlas.py", "ce3d/props3d.py", "cesprites/props_nature.py",
             "cesprites/props.py", "render_all.py"],
    "grass": ["ce3d/veg3d.py", "ce3d/leafatlas.py"],
    "building": ["ce3d/props3d.py", "ce3d/bake.py", "cesprites/props.py", "cesprites/props_buildings.py",
                 "render_all.py"],
    "lattice": ["ce3d/props3d.py", "ce3d/leafatlas.py", "cesprites/props.py", "render_all.py"],
})
AO_RURAL = dict(distance=1.6, floor=0.42, gamma=0.9, samples=24)
MODELS.update({
    # --- vegetation: two seeds per species (the generator's default seed and one more) ----------------------
    "props/tree_oak": dict(builder="tree", source="props/tree_oak", kind="tree", species="oak",
                           sets={"props/tree_oak": {"variants": ["props/tree_oak", "props/tree_oak_b"]}}),
    "props/tree_oak_b": dict(builder="tree", source="props/tree_oak", kind="tree", species="oak",
                             variant_of="props/tree_oak", params={"seed": 47}),
    "props/tree_birch": dict(builder="tree", source="props/tree_birch", kind="tree", species="birch",
                             sets={"props/tree_birch": {"variants": ["props/tree_birch", "props/tree_birch_b"]}}),
    "props/tree_birch_b": dict(builder="tree", source="props/tree_birch", kind="tree", species="birch",
                               variant_of="props/tree_birch", params={"seed": 37}),
    "props/bush_round": dict(builder="bush", source="props/bush_round", kind="plant", bush="bush_round",
                             sets={"props/bush_round": {"variants": ["props/bush_round", "props/bush_round_b"]}}),
    "props/bush_round_b": dict(builder="bush", source="props/bush_round", kind="plant", bush="bush_round",
                               variant_of="props/bush_round", params={"seed": 83}),
    "props/bush_low": dict(builder="bush", source="props/bush_low", kind="plant", bush="bush_low"),
    # ground cover of at most 0.5 m for the inside of bends (A-3): a low shrub clump and grass tufts
    "props/cover_bush": dict(builder="bush", source=None, kind="plant", bush="cover_bush",
                             cover=dict(centre=(0.0, 0.0, 0.22), a=0.6, b=0.5, c=0.2, n=9, r0=0.2, r1=0.3),
                             object={"width_m": 1.5, "height_m": 0.45, "length_m": 1.2},
                             sets={"props/cover_bush": {"modern_only": True}}),
    "props/cover_grass": dict(builder="grass", source=None, kind="plant", grass=dict(seed=23, tufts=7),
                              object={"width_m": 1.0, "height_m": 0.42, "length_m": 0.9},
                              sets={"props/cover_grass": {"modern_only": True}}),
    # --- buildings with depth: openings, gutters, ambient occlusion; vpbr panes light up at night (channel 12)
    "props/farmhouse": dict(builder="building", source="props/farmhouse", kind="building", atlas=(1024, 1024),
                            ppm_max=96.0, roughness=0.9, view="roadside", params={"allround": True}, ao=AO_RURAL,
                            openings=dict(reveal_color="#d4c8b8", door_color="#5a3a22"),
                            code=["cesprites/props_buildings.py"]),
    # --- field and road furniture -----------------------------------------------------------------------------
    "props/haybale": dict(builder="building", source="props/haybale", kind="furniture", atlas=(512, 512),
                          ppm_max=160.0, roughness=0.95, view="allround", openings=False, gutters=False,
                          ao=dict(distance=0.8, floor=0.5, gamma=1.0, samples=24)),
    # fuel station: shop windows cut in, lamp panels under the canopy (anchors: light pools at night), the haze
    # of the sprite is left out; pump and radar camera: one atlas (furniture: one draw call), lamps in its light
    "props/fuel_station": dict(builder="building", source="props/fuel_station", kind="building", atlas=(1024, 1024),
                               ppm_max=80.0, roughness=0.6, view="roadside", ao=AO_RURAL,
                               params={"lights3d": True, "allround": True},
                               gutters=False, openings=dict(pane_lit_color="#8a8070", pane_lit=(0.85, 1.0),
                                                            reveal_color="#c9cbcc"),
                               code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    "props/fuel_pump": dict(builder="building", source="props/fuel_pump", kind="furniture", atlas=(512, 512),
                            ppm_max=220.0, roughness=0.5, view="allround", openings=False, gutters=False,
                            vpbr_lamps=False, ao=dict(distance=0.6, floor=0.5, gamma=1.0, samples=24),
                            code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    "props/radar_camera": dict(builder="building", source="props/radar_camera", kind="furniture", atlas=(256, 256),
                               ppm_max=260.0, roughness=0.45, view="allround", openings=False, gutters=False,
                               vpbr_lamps=False, ao=dict(distance=0.5, floor=0.55, gamma=1.0, samples=24),
                               code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    "props/barn": dict(builder="building", source="props/barn", kind="building", atlas=(1024, 1024), ppm_max=96.0,
                       roughness=0.85, view="roadside", params={"boards3d": True}, ao=AO_RURAL,
                       code=["cesprites/props_buildings.py"]),
    "props/customs_booth": dict(builder="building", source="props/customs_booth", kind="building", atlas=(512, 512),
                                ppm_max=140.0, roughness=0.6, view="allround", gutters=False,
                                ao=dict(distance=1.0, floor=0.45, gamma=0.9, samples=24),
                                openings=dict(pane_lit_color="#8a8070", pane_lit=(0.85, 1.0), reveal_color="#c9cbcc"),
                                code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    # the sails turn (rotor code, hub at 19.8 m); the octagonal tower keeps its painted windows (its walls do not
    # face along an axis: the cutter leaves them)
    "props/windmill": dict(builder="building", source="props/windmill", kind="building", atlas=(1024, 1024),
                           ppm_max=64.0, roughness=0.9, view="allround", gutters=False, ao=AO_RURAL,
                           rotor=dict(objects=("mill_sails",), hub_z=19.8), code=["cesprites/props_buildings.py"]),
    "props/delineator": dict(builder="building", source="props/delineator", kind="furniture", atlas=(128, 128),
                             ppm_max=480.0, roughness=0.45, view="allround", openings=False, gutters=False,
                             vpbr_lamps=False, ao=dict(distance=0.3, floor=0.6, gamma=1.0, samples=24),
                             code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    # the power pylon: bracing drawn into a cut-out atlas (first model of the class baked_cutout, one draw call)
    "props/power_pylon": dict(builder="lattice", source="props/power_pylon", kind="furniture", atlas=(1024, 1024),
                              ppm=40.0, bold=1.3, colour="#6e757b", roughness=0.55,
                              code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    # the rotor turns (vpbr rotor code; hub at 89.6 m), the aviation light is lamp channel 12
    "props/wind_turbine": dict(builder="prop_vpbr", source="props/wind_turbine", kind="furniture", auto_lod=False,
                               params={"hub_subdiv": 2}, rotor=dict(objects=("wt_hub", "wt_blades"), hub_z=89.6),
                               code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    # the street lamp of wave 0 (no automatic levels, see above); the upper half of its lens lies inside the head
    # and is dropped, so the light anchor looks down (props3d.HIDDEN_TOP_Z)
    "props/streetlight": dict(builder="prop_vpbr", source="props/streetlight", kind="furniture", auto_lod=False,
                              hidden_tops=("sl_lens",), code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
})


# --- police (AS2b): one model per country - base car, livery, word and colours of cesprites.catalog.POLICE -----------
# POLICE_DETAIL: detail overrides per base car on top of the traffic car's own (catalog entry "traffic/<base>"), to
# make room for the livery cuts and the light bar inside the police budgets (contract 4.6.9)
POLICE_DETAIL = {
    "sedan": {"lod1": {"step": 24.0, "gstep": 30.0}, "lod2": {"ring": 0.07, "step": 80.0, "gstep": 80.0, "ends_n": 1}},
    "hatch": {"lod1": {"step": 24.0, "gstep": 30.0}, "lod2": {"ring": 0.07, "step": 80.0, "gstep": 80.0, "ends_n": 1}},
    "wagon": {"lod1": {"step": 32.0, "gstep": 44.0}, "lod2": {"ring": 0.07, "step": 110.0}},
    "suv": {"lod1": {"step": 38.0, "gstep": 50.0}, "lod2": {"ring": 0.07, "step": 100.0, "gstep": 90.0, "ends_n": 1}},
}
# ... and per livery: the checks cost about 4,000 triangles at lod0 (rows and cells), the Hungarian word twice the
# others - a longer station spacing of the lod0 lofts makes the room (the ends and the wheel arches keep their own
# stations); at lod1 the checks on the bumpers (about 360 triangles) take one station per wheel arch and one in
# each rounded end of the body
POLICE_DETAIL_CC = {
    "check": {"lod0": {"step": 12.0, "gstep": 12.0}, "lod1": {"arch_n": 4, "ends_n": 2}},
    "be": {"lod1": {"step": 36.0}},
    "ch": {"lod1": {"step": 36.0}},
    "hu": {"lod0": {"step": 8.8}, "lod1": {"step": 30.0}},
    "ro": {"lod0": {"step": 13.0}, "lod1": {"step": 28.0}},
    "at": {"lod1": {"step": 48.0, "gstep": 64.0}},
}
# ... and options of the build per country (AS2R): Czechia's stripes leave no room in lod2 for the rear pane cut along
# the design's outline (1,204 of 1,200 triangles) - its far greenhouse keeps the normal rule (police3d: far_windows)
POLICE_SPEC_CC = {
    "cz": {"far_windows": False},
}


def _police_models():
    from cesprites import catalog
    out = {}
    for cc in sorted(catalog.POLICE):
        p = catalog.POLICE[cc]
        e = dict(builder="police", source="police/" + cc, kind="vehicle", cc=cc, sets={"police/" + cc: {}})
        detail = {}
        for over in (POLICE_DETAIL.get(p["model"], {}), POLICE_DETAIL_CC.get(p["style"], {}), POLICE_DETAIL_CC.get(cc, {})):
            for lv, vals in over.items():
                detail.setdefault(lv, {}).update(vals)
        if detail:
            e["detail"] = detail
        e.update(POLICE_SPEC_CC.get(cc, {}))
        out["police/" + cc] = e
    return out


MODELS.update(_police_models())


def model_ids():
    return sorted(MODELS)


def _file_hash(rel):
    p = os.path.join(HERE, "..", rel)
    with open(p, "rb") as fh:
        return hashlib.sha1(fh.read()).hexdigest()


def _plain(v):
    """A catalog value as JSON-able data with a stable text: tuples and sets as lists, a function by its
    name (its text form would hold a memory address - a different key in every run)."""
    if isinstance(v, dict):
        return {str(k): _plain(v[k]) for k in sorted(v, key=str)}
    if isinstance(v, (list, tuple)):
        return [_plain(x) for x in v]
    if isinstance(v, (set, frozenset)):
        return sorted(_plain(x) for x in v)
    if callable(v):
        return "fn:%s.%s" % (getattr(v, "__module__", ""), getattr(v, "__qualname__", repr(type(v))))
    if isinstance(v, float):
        return repr(v)
    if v is None or isinstance(v, (bool, int, str)):
        return v
    return "%s:%s" % (type(v).__name__, v)


def served_sets(spec, model_id):
    """Sprite set ids a catalog entry serves."""
    return sorted(spec.get("sets") or [model_id])


def key_data(model_id):
    """What the builder of a model reads from the sprite catalog (needs bpy: the catalog imports the
    generator modules)."""
    from cesprites import catalog
    spec = MODELS[model_id]
    sets = {s["id"]: s for s in catalog.all_sets()}
    data = {"source": _plain(sets[spec["source"]]) if spec.get("source") else None,
            "sets": {sid: _plain(sets.get(sid)) for sid in served_sets(spec, model_id)}}
    if spec["builder"] == "car":
        colours = dict(catalog.TRAFFIC_COLORS[spec["design"]])
        data["colours"] = {name: [colours[name], repr(float(catalog.METALLIC.get(name, 0.35)))] for name in sorted(colours)}
    elif spec["builder"] == "player":
        data["colour"] = _plain(catalog.PLAYER_COLORS[spec["design"]])
    elif spec["builder"] == "heavy":
        from cesprites import heavy
        data["colours"] = _plain(catalog.TRAFFIC_COLORS[spec["design"]])
        data["variants"] = _plain(heavy.TRUCK_VARIANTS)
    elif spec["builder"] == "bus":
        from cesprites import heavy
        data["colours"] = _plain(catalog.TRAFFIC_COLORS["bus"])
        data["variants"] = _plain(heavy.BUS_VARIANTS)
    elif spec["builder"] == "police":
        # the traffic car it is built on: that entry's options (detail per level ...) and the police table row
        base = catalog.POLICE[spec["cc"]]["model"]
        data["police"] = _plain(catalog.POLICE[spec["cc"]])
        data["base"] = _plain(MODELS["traffic/" + base])
    return data


def cache_key(model_id):
    """Hash of builder code + parameters + exporter version (as render_all.py does for the sprites): see
    the module text. Landmarks use the per-landmark source revision of props_landmarks instead of the
    whole module."""
    spec = MODELS[model_id]
    files = list(COMMON_CODE) + BUILDER_CODE.get(spec["builder"], []) + list(spec.get("code", []))
    parts = [EXPORTER, model_id, json.dumps(_plain(spec), sort_keys=True),
             json.dumps(key_data(model_id), sort_keys=True, ensure_ascii=True)]
    for rel in sorted(set(files)):
        parts.append(rel + ":" + _file_hash(rel))
    if model_id.startswith("landmarks/"):
        from cesprites import props_landmarks
        parts.append("rev:" + props_landmarks._revisions()[model_id.split("/", 1)[1]])
    return hashlib.sha1("\n".join(parts).encode("utf-8")).hexdigest()[:20]


def check_keys():
    """Self-test of the cache key (export_models.py --check-keys, needs bpy): one changed value in the sprite
    catalog - a paint, a metallic value, a tag, a view angle - gives the models that read it a new key and
    leaves the others alone; the key is the same in two computations. Returns a list of problems."""
    from cesprites import catalog, props
    problems = []
    before = {mid: cache_key(mid) for mid in model_ids()}
    if before != {mid: cache_key(mid) for mid in model_ids()}:
        problems.append("zwei Berechnungen ergeben verschiedene Schlüssel")

    def expect(what, changed):
        now = {mid: cache_key(mid) for mid in model_ids()}
        got = sorted(mid for mid in now if now[mid] != before[mid])
        if got != sorted(changed):
            problems.append("%s: neue Schlüssel für %s, erwartet %s" % (what, got, sorted(changed)))

    cars = sorted(mid for mid in MODELS if MODELS[mid]["builder"] == "car")
    players = sorted(mid for mid in MODELS if MODELS[mid]["builder"] == "player")
    for mid in cars:
        design = MODELS[mid]["design"]
        table = catalog.TRAFFIC_COLORS[design]
        saved = list(table)
        table[0] = (table[0][0], "#00ff00")
        expect("Lack %s geändert" % design, [m for m in cars if MODELS[m]["design"] == design])
        table[:] = saved
        name = saved[0][0]
        old = catalog.METALLIC.get(name)
        catalog.METALLIC[name] = 0.99
        expect("Metallwert %s geändert" % name, [m for m in cars if name in dict(catalog.TRAFFIC_COLORS[MODELS[m]["design"]])])
        if old is None:
            del catalog.METALLIC[name]
        else:
            catalog.METALLIC[name] = old
    for mid in players:
        design = MODELS[mid]["design"]
        saved = catalog.PLAYER_COLORS[design]
        catalog.PLAYER_COLORS[design] = ("#a81d1d", saved[1])
        expect("Lack des Spielerautos %s geändert" % design, [m for m in players if MODELS[m]["design"] == design])
        catalog.PLAYER_COLORS[design] = saved
    for mid in sorted(MODELS):
        src = MODELS[mid]["source"]
        if not src or not src.startswith("props/") or src.split("/", 1)[1] not in props.PROPS:
            continue
        name = src.split("/", 1)[1]
        row = props.PROPS[name]
        same = sorted(m for m in MODELS if MODELS[m]["source"] == src or src in served_sets(MODELS[m], m))
        props.PROPS[name] = row[:2] + (float(row[2]) + 30.0,) + row[3:]
        expect("Blickwinkel von %s geändert" % src, same)
        props.PROPS[name] = row[:6] + (list(row[6]) + ["ce_check_tag"],) + row[7:]
        expect("Markierung von %s geändert" % src, same)
        props.PROPS[name] = row
    expect("alles zurückgesetzt", [])
    return problems
