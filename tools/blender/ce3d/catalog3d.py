"""Every real-time model of the mode "Modern" (docs/modelle.md): builder, source sprite set, options and
the sprite sets it serves. No bpy at import time (export_models.py --list / --manifest-only).

Entry: model id "<group>/<name>" (group = player | traffic | police | props | landmarks) ->
  builder   player | car | heavy | tree | prop_vpbr | prop_baked    (ce3d.export_models.BUILDERS)
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
    "player": ["ce3d/vehicles3d.py", "ce3d/decalgeo.py", "ce3d/interior3d.py", "ce3d/extras3d.py", "cesprites/curves.py",
               "cesprites/carbody.py", "cesprites/cardetail.py", "cesprites/player_cars.py", "cesprites/textgeo.py"],
    "car": ["ce3d/traffic3d.py", "ce3d/vehicles3d.py", "ce3d/truck3d.py", "ce3d/decalgeo.py", "cesprites/vehicles.py",
            "cesprites/designs.py", "cesprites/carbody.py", "cesprites/cardetail.py", "cesprites/curves.py"],
    "heavy": ["ce3d/truck3d.py", "ce3d/vehicles3d.py", "ce3d/decalgeo.py", "cesprites/heavy.py"],
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
    "traffic/sedan": dict(
        builder="car", source="traffic/sedan_red", kind="vehicle", design="sedan",
        sets={"traffic/sedan_red": {}, "traffic/sedan_blue": {}, "traffic/sedan_silver": {}, "traffic/sedan_black": {}}),
    "traffic/hatch": dict(
        builder="car", source="traffic/hatch_green", kind="vehicle", design="hatch",
        far_sill=False,           # lod2: no dark sill on the rear end - the cut costs 68 triangles, lod2 had 20 left
        sets={"traffic/hatch_green": {}, "traffic/hatch_yellow": {}, "traffic/hatch_white": {}, "traffic/hatch_blue": {},
              "traffic/hatch_red": {}}),
    "traffic/wagon": dict(
        builder="car", source="traffic/wagon_silver", kind="vehicle", design="wagon",
        detail={"lod0": {"step": 7.7, "gstep": 8.5}, "lod1": {"step": 16.0, "gstep": 24.0},
                "lod2": {"gstep": 120.0, "ends_n": 1}, "shadow": {"gstep": 120.0}},              # the long greenhouse
        sets={"traffic/wagon_silver": {}, "traffic/wagon_darkblue": {}, "traffic/wagon_green": {},
              "traffic/wagon_white": {}}),
    "traffic/truck": dict(
        builder="heavy", source="traffic/truck_white", kind="heavy", design="truck",
        sets={"traffic/truck_white": {}, "traffic/truck_red": {}, "traffic/truck_blue": {}, "traffic/truck_green": {}}),
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


# --- AS4 --- (wave 5): rural and town buildings, bridge parts, ships (docs/modelle.md section 15). Own block; builder
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
    "props/church": dict(builder="house", source="props/church", kind="building", atlas=(1024, 1024), ppm_max=80.0,
                         roughness=0.85, view="roadside", params={"allround": True}, ao=AO_TOWN, lod1=True,
                         vpbr=("church_gold",), weights=dict(roof=0.75),
                         openings=dict(reveal_m=0.3, door_m=0.3, steps=2, reveal_color="#d8d0bd", sill_color="#cfc6b2",
                                       louvre=(17.0, 19.6), bars={"win": (1, [0.36, 0.66])}),
                         gutters=dict(per_roof=2, walls=("church_nave",))),
    # rural / outskirts: the factory - hall with sawtooth roofs and skylights, steel sash windows, a roller gate with a
    # transom window, the name board "WERK 2" as letters (lit at night), brick chimney with aviation light, silo
    "props/factory": dict(builder="house", source="props/factory", kind="building", atlas=(1024, 1024), ppm_max=80.0,
                          roughness=0.8, view="roadside", params={"allround": True}, ao=AO_TOWN, lod1=True,
                          vpbr=("fac_tank",), baked_lamps=("fac_skylight",), weights=dict(roof=0.55, away=0.25),
                          gutters=False, caps=False,
                          openings=dict(reveal_m=0.2, reveal_color="#9d988e", sill_color="#8f8b84",
                                        bars={"large": (3, 3)}, pane_lit=(0.75, 1.0)),
                          sign=dict(text="WERK 2", face="front", u=(-14.6, -3.4), z=(7.1, 8.4), h=0.95, wall=0.0,
                                    panel="#2f3a44", color="#e9e7df")),
    # town blocks (category city: 10,000 triangles, atlas 2048 x 1024)
    "props/building_block_a": dict(builder="house", source="props/building_block_a", kind="building",
                                   atlas=(2048, 1024), ppm_max=72.0, roughness=0.85, view="roadside",
                                   params={"allround": True}, ao=AO_TOWN, lod1=True, vpbr=("blka_rail",),
                                   overrides={"blka_rail": dict(rough=0.6, metal=0.3)}, weights=dict(roof=0.4),
                                   openings=dict(reveal_color="#cbb98f", sill_color="#d6d1c6"), gutters=False),
    "props/building_block_b": dict(builder="house", source="props/building_block_b", kind="building",
                                   atlas=(2048, 1024), ppm_max=72.0, roughness=0.85, view="roadside",
                                   params={"allround": True}, ao=AO_TOWN, lod1=True, weights=dict(roof=0.4),
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
    # the office tower: glass curtain wall (spandrel bands in the atlas, panes and fins as geometry), lobby lit at night
    "props/building_tall": dict(builder="house", source="props/building_tall", kind="building", atlas=(2048, 1024),
                                ppm_max=48.0, roughness=0.6, view="roadside", ao=AO_TOWN, lod1=True,
                                openings=False, gutters=False, caps=False, baked_lamps=("tower_lobby",),
                                curtain=dict(object="tower", base=3.5, floor=3.5, band=0.9, mull=1.6, lit=0.34,
                                             light="#ffe4b8", glass="#3a5468")),
    # --- bridge parts (generators in props_cities.py: read back, not changed) -----------------------------------
    # the candelabra of stone bridges: flat colours only (vpbr, one draw call); the upper halves of the lantern
    # glasses lie under their caps and are dropped; their sides are flood-lit glass (pale by day, lit at night), the
    # faces looking down are the lamps with the three light anchors (pools on the pavement)
    "props/bridge_lamp": dict(builder="lantern", source="props/bridge_lamp", kind="furniture", auto_lod=False,
                              hidden_tops=("bl_lg",), glass=("bl_lg",), side_flood=0.85,
                              code=["cesprites/props_cities.py"]),
    "props/bridge_pylon": dict(builder="pylon", source="props/bridge_pylon", kind="furniture", atlas=(1024, 1024),
                               ppm_max=40.0, roughness=0.85, view="allround", cable_w=(0.24, 0.4), beacon="bpy_red",
                               split=("bpy_leg", (30.75, 61.5)), code=["cesprites/props_cities.py"]),
    "props/bridge_truss_arch": dict(builder="truss", source="props/bridge_truss_arch", kind="furniture",
                                    atlas=(1024, 512), ppm=28.0, roughness=0.55, code=["cesprites/props_cities.py"]),
    # --- ships -------------------------------------------------------------------------------------------------
    # the ro-pax ferry: the sprite shows its starboard side (view_yaw 90), so the model is turned by -90 degrees
    # (its side faces the approaching player, the bow points to +X); the many cabin windows stay painted (lit in
    # the emission atlas), the deck lights are lamps without anchors, the navigation lights keep theirs
    "props/ferry_ship": dict(builder="house", source="props/ferry_ship", kind="building", atlas=(1024, 1024),
                             ppm_max=24.0, roughness=0.55, view="roadside", params={"lowpoly3d": True}, rotate_deg=-90.0,
                             extent_view=0.0, openings=False, gutters=False, caps=False, baked_lamps=("ferry_bridge",),
                             split=dict(objects=("ferry_hull", "ferry_deck"), axis=0, at=(-36.4, 9.1)),
                             weights=dict(roof=0.3, away=0.3),
                             overrides={"ferry_deckl": dict(lamp="-lights:0.9")},
                             ao=dict(distance=3.0, floor=0.5, gamma=1.0, samples=24),
                             code=["cesprites/props_road.py", "cesprites/props_buildings.py"]),
    # the Amsterdam houseboat: its cabin walls come from props_cities.wallmat (window log taken from outside); the
    # cut-out railing of the roof garden is rebuilt as posts and rails (vpbr), the potted plants decimated
    "props/houseboat": dict(builder="house", source="props/houseboat", kind="building", atlas=(512, 512),
                            ppm_max=110.0, roughness=0.7, view="roadside", city_walls=True,
                            railings=dict(objects=("hb_rail",), post=1.0, color="#1f2321", w=0.05),
                            decimate={"hb_plant": 0.15, "hb_fl": 0.5},
                            ao=dict(distance=1.2, floor=0.45, gamma=0.9, samples=24), gutters=False,
                            openings=dict(reveal_m=0.08, reveal_color="#2b3b31", sill_color="#ece8de", steps=0),
                            code=["cesprites/props_cities.py"]),
    # --- AS1b's windmill, reworked: real openings in the middle of the octagon's faces instead of the painted grid
    # that straddled a corner (hook win3d); the rest as AS1b built it
    "props/windmill": dict(builder="house", source="props/windmill", kind="building", atlas=(1024, 1024),
                           ppm_max=64.0, roughness=0.9, view="allround", gutters=False, ao=AO_RURAL,
                           params={"win3d": True}, openings=False, caps=False,
                           octagon=dict(objects=("mill_base",), faces=(67.5, 112.5, 247.5, 292.5),
                                        rows=(2.3, 4.9), win=(0.8, 1.1), lit=0.5, frame="#e9e6de", reveal_m=0.25),
                           rotor=dict(objects=("mill_sails",), hub_z=19.8), code=["cesprites/props_buildings.py"]),
    # town: the shop with flat, awning, sign (its light stays in the emission atlas: teal by day, cyan at night)
    "props/building_shop": dict(builder="house", source="props/building_shop", kind="building", atlas=(1024, 1024),
                                ppm_max=110.0, roughness=0.85, view="roadside", params={"allround": True}, ao=AO_TOWN,
                                lod1=True, baked_lamps=("shop_sign",),
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
