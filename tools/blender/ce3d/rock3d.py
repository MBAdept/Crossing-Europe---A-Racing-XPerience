"""Rocks and the cliff of the mode "Modern" (AS3; docs/modelle.md section 15), builder "rock".

The generator's own geometry (cesprites/props_nature.py: boulders = icospheres displaced by clouds and Voronoi
noise - real facets; the cliff = a leaning wall, solidified and displaced, with two boulders and a few shrubs on its
top) with its modifiers applied, decimated to the budget of the catalog entry ("tris": rock 1,500, cliff 6,000 -
Blender's collapse decimation keeps the facets and the outline), the foot of the cliff wall pushed SINK_M into the
ground (on a slope it never floats; the boulders reach below the ground already). Everything is baked into one atlas
with Cycles: the sprite's rock material (noise colours, crack network, strata bands, moss on the tops), the shrubs'
leaf colour, and ambient occlusion (bake.bake_atlas ao=...). One surface of the class baked = one draw call; Godot's
automatic levels of detail (auto_lod) - no lamp channels. All-round texel weights: the props builder turns rocks.
"""
import time

import numpy as np

from . import bake as BK
from . import core, roles
from .export import Lod, Part
from .props3d import _build_source, _finish_model, _objects, weight_allround

SINK_M = 0.9          # the foot of a wall (vertices below FOOT_M) goes this far into the ground
FOOT_M = 0.35


def _tris(objs):
    return sum(s.n for s in core.soups_of(objs))


def _decimate(objs, budget):
    """Collapse decimation of all objects to `budget` triangles in total (each by the same ratio)."""
    import bpy
    total = _tris(objs)
    if total <= budget:
        return total
    ratio = budget / float(total) * 0.985
    for ob in objs:
        m = ob.modifiers.new("ce_decimate", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = ratio
        m.use_collapse_triangulate = True
    core.realize(objs)
    bpy.context.view_layer.update()
    return _tris(objs)


def _sink_feet(objs, foot=FOOT_M, depth=SINK_M):
    """Vertices near the ground go below it (a wall standing on a slope never shows its lower edge)."""
    import bpy
    for ob in objs:
        mw = ob.matrix_world
        inv = mw.inverted()
        me = ob.data
        for v in me.vertices:
            w = mw @ v.co
            if w.z < foot:
                w.z -= depth * (1.0 - max(0.0, w.z) / foot)
                v.co = inv @ w
        me.update()
    bpy.context.view_layer.update()


def build_rock(model_id, spec3d):
    t0 = time.time()
    rig, info, sspec = _build_source(spec3d)
    objs = _objects(rig)
    core.realize(objs)
    tris_src = _tris(objs)
    tris = _decimate(objs, int(spec3d.get("tris", 1450)))
    if spec3d.get("sink", "cliff" in model_id):
        _sink_feet(objs)
    mats = {}
    for ob in objs:
        for s in ob.material_slots:
            if s.material is not None:
                roles.tag(s.material)                 # every material must be tagged
                mats[s.material.name] = s.material
    mat_list = [mats[k] for k in sorted(mats)]
    size = tuple(spec3d.get("atlas", (512, 512)))
    baked = BK.bake_atlas(rig, objs, mat_list, size, weight_fn=weight_allround, ppm_max=spec3d.get("ppm_max", 128.0),
                          ao=spec3d.get("ao"))
    mb = core.MeshBuilder()
    for soup in core.soups_of(objs, uv_layer=BK.UV_NAME):
        uv = soup.uv.copy()
        uv[:, :, 1] = 1.0 - uv[:, :, 1]             # glTF / Godot: v down
        mb.add("baked", soup.pos, soup.nor, uv=uv)
    pts = mb.points()
    model = _finish_model(model_id, spec3d, sspec, info, pts)
    model.auto_lod = True
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(min_height=0.0005), auto_lod=True)])]
    model.roughness = float(spec3d.get("roughness", 0.9))
    model.texture_files["albedo.png"] = BK.encode(baked["albedo"], None, "png")
    model.textures["albedo"] = "albedo.png"
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs), tris_source=tris_src, tris=tris,
                       bake=baked["stats"])
    return model
