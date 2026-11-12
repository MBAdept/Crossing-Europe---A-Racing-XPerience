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


# --- AS3 ---------------------------------------------------------------------------------------------------------------
# AS3 (wave 4): vegetation and nature (docs/modelle.md section 18). Own block: the species tables of the card-tree
# builder are in ce3d/veg3d.py (oak, birch and the bushes above get the reworked builder through them); the entries
# here add the other species with a second seed each, heather, the two rocks and the cliff.
#   params   generator parameters of the 3D build: "seed" - and for species whose generator draws no random shape, a
#            3D-only shape parameter of the generator (spruce: tiers, taper; cypress: bulge, width; palm: bend) so
#            that the two variants differ in silhouette. The sprite catalog never passes them: the sprites stay.
#   code     spruce, cypress and palm build their crowns in ce3d/veg3d_shapes.py (part of their cache key)
BUILDER_CODE.update({
    "rock": ["ce3d/rock3d.py", "ce3d/veg3d.py", "ce3d/bake.py", "ce3d/props3d.py", "cesprites/props_nature.py",
             "cesprites/props.py", "render_all.py"],
})
AS3_SHAPES = ["ce3d/veg3d_shapes.py"]


def _as3_tree(name, species, seed_b, code=None, params_b=None):
    """A species and its second seed variant (props/tree_<name>, props/tree_<name>_b)."""
    a = dict(builder="tree", source="props/tree_" + name, kind="tree", species=species,
             sets={"props/tree_" + name: {"variants": ["props/tree_" + name, "props/tree_%s_b" % name]}})
    b = dict(builder="tree", source="props/tree_" + name, kind="tree", species=species,
             variant_of="props/tree_" + name, params=dict({"seed": seed_b}, **(params_b or {})))
    if code:
        a["code"] = list(code)
        b["code"] = list(code)
    return {"props/tree_" + name: a, "props/tree_%s_b" % name: b}


MODELS.update(_as3_tree("beech", "beech", 61))
MODELS.update(_as3_tree("poplar", "poplar", 29))
# M2INT (AS3R report 11.): olive_b's fuller lod1 rim was +5.0 / +6.5 / +8.3 % brighter than its lod0 at the swap
# (noon / dusk / night) with the species' lift 1.12 - its own lod1 lift (veg3d.build_tree, params "lift")
MODELS.update(_as3_tree("olive", "olive", 53, params_b={"lift": [1.0, 1.057]}))
MODELS.update(_as3_tree("pine", "pine", 71))
MODELS.update(_as3_tree("spruce", "spruce", 19, AS3_SHAPES, {"tiers": 12, "taper": 1.25}))
MODELS.update(_as3_tree("cypress", "cypress", 41, AS3_SHAPES, {"bulge": 1.45, "width": 1.12}))
# AS3R (art review M8): palm_b bends like the sprite (0.4 was a straight pole, 57 % outside the sprite) - another seed
# only: its own frond directions, lengths and lifts
MODELS.update(_as3_tree("palm", "palm", 43, AS3_SHAPES, {"bend": 0.9}))
MODELS.update({
    # heather: the generator's tufts (props_nature.SHAPE_LOG "heather") as leaf domes, flowers and foliage
    "props/heather": dict(builder="bush", source="props/heather", kind="plant", bush="heather"),
    # rocks and the cliff: the generator's boulders (and wall) decimated to their budget, the rock material
    # (cracks, strata, moss) baked into an atlas with ambient occlusion; the cliff's shrubs baked in (one draw call)
    "props/rock_a": dict(builder="rock", source="props/rock_a", kind="rock", atlas=(512, 512), ppm_max=160.0,
                         roughness=0.9, tris=1450, ao=dict(distance=0.9, floor=0.45, gamma=1.0, samples=24)),
    "props/rock_b": dict(builder="rock", source="props/rock_b", kind="rock", atlas=(512, 512), ppm_max=160.0,
                         roughness=0.9, tris=1450, ao=dict(distance=0.9, floor=0.45, gamma=1.0, samples=24)),
    # AS3R (art review M2): the cliff as a closed rock body (props_nature "solid3d": crest, back flank, closed ends,
    # shrubs set onto the crest) - the props builder turns rocks; tag face_road asks it to keep the face to the road
    "props/cliff": dict(builder="rock", source="props/cliff", kind="rock", atlas=(1024, 1024), ppm_max=40.0,
                        roughness=0.92, tris=5900, ao=dict(distance=2.5, floor=0.4, gamma=1.0, samples=24),
                        params={"solid3d": True}, tags_add=["face_road"]),
})
# ground cover grass (AS1b): twice the tufts, so that it reads as grass and not as one spot at 15 m
MODELS["props/cover_grass"] = dict(MODELS["props/cover_grass"], grass=dict(seed=23, tufts=14))
# --- end AS3 -----------------------------------------------------------------------------------------------------------


# --- AS4 --- (wave 5): rural and town buildings, bridge parts, ships (docs/modelle.md section 19). Own block; builder
# "house" lives in ce3d/buildings3d.py (props3d.py stays as it is, so the keys of the models above do not change).
BUILDER_CODE.update({
    "house": ["ce3d/buildings3d.py", "ce3d/props3d.py", "ce3d/bake.py", "ce3d/leafatlas.py", "cesprites/props.py",
              "cesprites/props_buildings.py", "render_all.py"],
    "pylon": ["ce3d/bridges3d.py", "ce3d/buildings3d.py", "ce3d/props3d.py", "ce3d/bake.py", "cesprites/props.py",
              "cesprites/props_cities.py", "render_all.py"],
    "truss": ["ce3d/bridges3d.py", "ce3d/buildings3d.py", "ce3d/props3d.py", "ce3d/leafatlas.py", "cesprites/props.py",
              "cesprites/props_cities.py", "render_all.py"],
    "lantern": ["ce3d/bridges3d.py", "ce3d/buildings3d.py", "ce3d/props3d.py", "cesprites/props.py", "render_all.py"],
})
AO_TOWN = dict(distance=2.0, floor=0.4, gamma=0.9, samples=24)
MODELS.update({
    # rural: the medium house (village of the plains), ochre plaster, hip roof, green shutters, balcony
    "props/house_med": dict(builder="house", source="props/house_med", kind="building", atlas=(1024, 1024),
                            ppm_max=96.0, roughness=0.9, view="roadside", params={"allround": True}, ao=AO_RURAL,
                            lod1=True, vpbr=("med_rail",), overrides={"med_rail": dict(rough=0.75, metal=0.2)},
                            openings=dict(reveal_color="#d6bd8c", sill_color="#d9d3c6"),
                            gutters=dict(per_roof=2)),
    # rural: the village church - nave with arched windows, tower with a belfry (louvres) and clocks on three faces,
    # slate spire with a gilded cross; walls 30 cm deep in the openings, two steps at the door
    # AS4R: the plaster 12 % darker than the sprite's (#e8e1d0 came out 13 % brighter than the sprite in the race)
    "props/church": dict(builder="house", source="props/church", kind="building", atlas=(1024, 1024), ppm_max=80.0,
                         roughness=0.85, view="roadside", params={"allround": True, "plaster": "#ccc6b7"}, ao=AO_TOWN,
                         lod1=True,
                         vpbr=("church_gold",), weights=dict(roof=0.5, away=0.25),
                         openings=dict(reveal_m=0.3, door_m=0.3, steps=2, reveal_color="#d8d0bd", sill_color="#cfc6b2",
                                       louvre=(17.0, 19.6), bars={"win": (1, [0.36, 0.66])}),
                         flood=dict(objects=("church_tower",), strength=0.12, z=(0.0, 21.0), tint="#ffe2b0", top=0.3),
                         gutters=dict(per_roof=2, walls=("church_nave",))),
    # rural / outskirts: the factory - hall with sawtooth roofs and skylights, steel sash windows, a roller gate with a
    # transom window, the works sign (a gear between bars, lit at night - mirror-symmetric: the set is tagged
    # mirror_left, lettering would read backwards on the left roadside), brick chimney with aviation light, silo
    "props/factory": dict(builder="house", source="props/factory", kind="building", atlas=(1024, 1024), ppm_max=80.0,
                          roughness=0.8, view="roadside", params={"allround": True}, ao=AO_TOWN, lod1=True,
                          vpbr=("fac_tank",), baked_lamps=("fac_skylight",), weights=dict(roof=0.4, away=0.25),
                          overrides={"fac_tank": dict(rough=0.5, metal=0.45)}, gutters=False, caps=False,
                          openings=dict(reveal_m=0.2, reveal_color="#9d988e", sill_color="#8f8b84",
                                        bars={"large": (3, 3)}, pane_lit=(0.75, 1.0)),
                          sign=dict(logo="gear", face="front", u=(-14.6, -3.4), z=(7.1, 8.4), wall=0.0,
                                    panel="#2f3a44", color="#e9e7df"),
                          # AS4R (M4): the sawtooth glazing with mullions and a transom, its light at 30 % and fading
                          # towards the top (it lit as five pure white fields)
                          skylight=dict(objects=("fac_glass",), glass="#5d7486", frame="#4a4f55", light="#cfe0ff",
                                        strength=0.9, k=0.3, pitch=1.4, bar=0.1, fade=0.5, z=(9.1, 11.9))),
    # town blocks (category city: 10,000 triangles, atlas 2048 x 1024)
    "props/building_block_a": dict(builder="house", source="props/building_block_a", kind="building",
                                   atlas=(2048, 1024), ppm_max=72.0, roughness=0.85, view="roadside",
                                   params={"allround": True}, ao=AO_TOWN, lod1=True, vpbr=("blka_rail",),
                                   overrides={"blka_rail": dict(rough=0.6, metal=0.3)}, weights=dict(roof=0.4, away=0.5),
                                   openings=dict(reveal_color="#cbb98f", sill_color="#d6d1c6"), gutters=False),
    "props/building_block_b": dict(builder="house", source="props/building_block_b", kind="building",
                                   atlas=(2048, 1024), ppm_max=72.0, roughness=0.85, view="roadside",
                                   params={"allround": True}, ao=AO_TOWN, lod1=True, weights=dict(roof=0.4, away=0.5),
                                   openings=dict(reveal_color="#cfc4b2", sill_color="#d3cabb",
                                                 bars={"large": (1, [0.78])}), gutters=False),
    # old town: the stepped-gable house (the gable one prism so that its windows can be cut; a back gable closes the roof)
    "props/building_oldtown": dict(builder="house", source="props/building_oldtown", kind="building",
                                   atlas=(1024, 1024), ppm_max=96.0, roughness=0.85, view="roadside",
                                   params={"allround": True, "gable3d": True}, ao=AO_TOWN, lod1=True,
                                   weights=dict(roof=0.6),
                                   openings=dict(reveal_color="#ece5d8", sill_color="#e6dfd2",
                                                 bars={"large": (1, [0.62])}),
                                   gutters=dict(per_roof=2)),
    # the office tower: glass curtain wall (spandrel bands in the atlas, panes and fins as geometry), lobby lit at night.
    # AS4R (M3/M8): the panes are atlas patches - the sprite's glass gradient in six steps, the same by day for lit and
    # unlit panes, the light (34 %, spread per face, floor and bay) in the emission atlas; the lobby at 20 % of its
    # light with mullions in front of it
    "props/building_tall": dict(builder="house", source="props/building_tall", kind="building", atlas=(2048, 1024),
                                ppm_max=48.0, roughness=0.6, view="roadside", ao=AO_TOWN, lod1=True,
                                openings=False, gutters=False, caps=False, baked_lamps=("tower_lobby",),
                                light_scale={"tower_lobby": 0.2},
                                curtain=dict(object="tower", base=3.5, floor=3.5, band=0.9, mull=1.6, lit=0.34,
                                             light="#ffe4b8", glass="#2c4256", glass_top="#6f8ea8", bands=6,
                                             strength=0.75, lobby=dict(object="tower_lobby", posts=1.6, w=0.12))),
    # --- bridge parts (generators in props_cities.py: read back, not changed) -----------------------------------
    # the candelabra of stone bridges: flat colours only (vpbr, one draw call); the upper halves of the lantern
    # glasses lie under their caps and are dropped; their sides are flood-lit glass (pale by day, lit at night), the
    # faces looking down are the lamps with the three light anchors (pools on the pavement)
    "props/bridge_lamp": dict(builder="lantern", source="props/bridge_lamp", kind="furniture", auto_lod=False,
                              hidden_tops=("bl_lg",), glass=("bl_lg",), side_flood=0.85,
                              code=["cesprites/props_cities.py"]),
    # AS4R (art review AS4, M1/M5): the leg upright and 0.9 m farther out (its foot and plinth end at the deck edge,
    # model x -1.3 m), seven cables a side from the head down to the deck edge (axis at x -1.15 m, 1.1 m high - Arcade
    # draws them to x -1.4 m; with their 0.32 m the cables then end outside the railing line) within 36 m of the pylon
    # - every cable-stayed bridge of the network has at least 40.5 m (Elisabeth- and Vansu-Bruecke); one level;
    # extent_m stays the sprite's (the pylon is not placed by it)
    "props/bridge_pylon": dict(builder="pylon", source="props/bridge_pylon", kind="furniture", atlas=(1024, 1024),
                               ppm_max=40.0, roughness=0.85, view="allround", cable_w=(0.32,), beacon="bpy_red",
                               split=("bpy_leg", (30.75, 61.5)), band_w=(1.0, 0.6, 0.45), drop=("bpy_anch",),
                               upright=dict(lean_deg=3.5, top=82.0, shift_x=0.9, clip_x=-2.2, clip_z=1.0),
                               fan=dict(n=7, span=36.0, near=8.0, heads=(55.0, 79.0), deck=(-1.15, 1.1), head_y=0.6,
                                        shift_x=0.9, leg_hw=(2.2, 1.35, 82.0)),
                               extent_source=True, code=["cesprites/props_cities.py"]),
    # the same pylon without cables, for a renderer that draws the cables of each bridge from its data (height_m,
    # cables, deck edge - RoadRenderer._pylon): a set of the mode Modern only, placed by no stage
    "props/bridge_pylon_bare": dict(builder="pylon", source="props/bridge_pylon", kind="furniture", atlas=(1024, 1024),
                                    ppm_max=40.0, roughness=0.85, view="allround", cable_w=(0.32,), beacon="bpy_red",
                                    split=("bpy_leg", (30.75, 61.5)), band_w=(1.0, 0.6, 0.45), drop=("bpy_anch",),
                                    upright=dict(lean_deg=3.5, top=82.0, shift_x=0.9, clip_x=-2.2, clip_z=1.0),
                                    bare=True, object={"width_m": 5.25, "height_m": 88.8, "length_m": 8.0},
                                    sets={"props/bridge_pylon_bare": {"modern_only": True}},
                                    code=["cesprites/props_cities.py"]),
    # AS4R (M10): the web of the cut-out picture 1.2 x wider and 15 % darker (paler than the sprite at 400 m); the
    # steel 15 % darker than the sprite's STEEL_GREEN #56676a (sun and sky light make the model lighter and bluer
    # than the pre-lit sprite: at 100 m contrast to the sky 98 against 109)
    "props/bridge_truss_arch": dict(builder="truss", source="props/bridge_truss_arch", kind="furniture",
                                    atlas=(1024, 512), ppm=28.0, roughness=0.55, web_k=1.2, web_dark=0.85,
                                    steel="#49585a", code=["cesprites/props_cities.py"]),
    # --- ships -------------------------------------------------------------------------------------------------
    # the ro-pax ferry: the sprite shows its starboard side (view_yaw 90), so the model is turned by -90 degrees
    # (its side faces the approaching player, the bow points to +X); the many cabin windows stay painted (lit in
    # the emission atlas), the deck lights are lamps without anchors, the navigation lights keep theirs
    "props/ferry_ship": dict(builder="house", source="props/ferry_ship", kind="building", atlas=(1024, 1024),
                             ppm_max=24.0, roughness=0.55, view="roadside", params={"lowpoly3d": True}, rotate_deg=-90.0,
                             extent_view=0.0, openings=False, gutters=False, caps=False, baked_lamps=("ferry_bridge",),
                             split=dict(objects=("ferry_hull", "ferry_deck"), axis=0, at=(-36.4, 9.1)),
                             weights=dict(roof=0.3, away=0.3),
                             # navigation lights glow without anchors: a signal light lights no deck (and the anchors
                             # of one role share the colour of its first lamp - the white lights came out green)
                             overrides={"ferry_deckl": dict(lamp="-lights:0.9"),
                                        "ferry_nav_g": dict(lamp="-lights:1:#18ff50"),
                                        "ferry_nav_w": dict(lamp="-lights:1:#ffffff"),
                                        "ferry_nav_w2": dict(lamp="-lights:1:#ffffff")},
                             ao=dict(distance=3.0, floor=0.5, gamma=1.0, samples=24),
                             code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    # the Amsterdam houseboat: its cabin walls come from props_cities.wallmat (window log taken from outside); the
    # cut-out railing of the roof garden is rebuilt as posts and rails (vpbr), the potted plants decimated
    "props/houseboat": dict(builder="house", source="props/houseboat", kind="building", atlas=(1024, 512),
                            ppm_max=110.0, roughness=0.7, view="roadside", city_walls=True,
                            railings=dict(objects=("hb_rail",), post=1.0, color="#1f2321", w=0.05),
                            decimate={"hb_plant": 0.15, "hb_fl": 0.5},
                            ao=dict(distance=1.2, floor=0.45, gamma=0.9, samples=24), gutters=False,
                            openings=dict(reveal_m=0.08, reveal_color="#2b3b31", sill_color="#ece8de", steps=0),
                            code=["cesprites/props_cities.py"]),
    # --- AS1b's windmill, reworked: real openings in the middle of the octagon's faces instead of the painted grid
    # that straddled a corner (hook win3d); the rest as AS1b built it. AS4R: the panes are atlas patches (M3); the
    # sails stay the sprite's lattice - the art review's flicker of the mill (M7) was the rotor turning while its
    # measurement moved the model (the rotor phase follows the world position); with the camera moving instead, mill
    # and sprite flicker alike (measured, docs/modelle.md section 19)
    "props/windmill": dict(builder="house", source="props/windmill", kind="building", atlas=(1024, 1024),
                           ppm_max=64.0, roughness=0.9, view="allround", gutters=False, ao=AO_RURAL,
                           params={"win3d": True}, openings=False, caps=False,
                           octagon=dict(objects=("mill_base",), faces=(67.5, 112.5, 247.5, 292.5),
                                        rows=(2.3, 4.9), win=(0.8, 1.1), lit=0.5, frame="#e9e6de", reveal_m=0.25),
                           rotor=dict(objects=("mill_sails",), hub_z=19.8), code=["cesprites/props_buildings.py"]),
    # town: the shop with flat, awning, sign (its light stays in the emission atlas: teal by day, cyan at night).
    # AS4R (M9): an emblem on the sign board - a shopping bag between two bars, mirror-symmetric (mirror_left), lit at
    # night (channel 14); the board's own light at 25 % (it was a white box at night)
    "props/building_shop": dict(builder="house", source="props/building_shop", kind="building", atlas=(1024, 1024),
                                ppm_max=110.0, roughness=0.85, view="roadside", params={"allround": True}, ao=AO_TOWN,
                                lod1=True, baked_lamps=("shop_sign",), light_scale={"shop_sign": 0.25},
                                sign=dict(logo="bag", face="front", u=(-4.4, 4.4), z=(3.75, 4.55), wall=-0.245,
                                          panel=None, color="#f4f1ea", flood=1.0),
                                openings=dict(reveal_color="#d9d4c8", sill_color="#c9c4b8",
                                              bars={"large": (0, [0.8])}),
                                gutters=False),
})


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
