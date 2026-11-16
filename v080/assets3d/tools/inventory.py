#!/usr/bin/env python3
"""Inventory of all cesprites generators: builds every distinct model with the real builders and counts
evaluated triangles (after modifiers), objects, modifiers and material classes. Read-only w.r.t. the repo.

Usage: bpy-python inventory.py OUT.json [--only PREFIX,...]
"""
import json
import os
import sys
import time

REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import bpy  # noqa: E402
import numpy as np  # noqa: E402

import render_all as RA  # noqa: E402
from cesprites import catalog  # noqa: E402
from cesprites import rig as R  # noqa: E402

PROC = {"ShaderNodeTexNoise", "ShaderNodeTexVoronoi", "ShaderNodeTexBrick", "ShaderNodeTexWhiteNoise",
        "ShaderNodeTexWave", "ShaderNodeTexMagic", "ShaderNodeTexChecker", "ShaderNodeTexGradient"}


def classify(mat):
    nt = mat.node_tree
    if nt is None:
        return dict(cls="none", emit=[])
    types = [n.bl_idname for n in nt.nodes]
    ts = set(types)
    emit = []
    for n in nt.nodes:
        if n.bl_idname == "ShaderNodeGroup" and n.node_tree and n.node_tree.name.startswith("CE_PASS"):
            for o in n.outputs:
                if o.name != "base" and o.is_linked:
                    emit.append(o.name)
    emit = sorted(set(emit))
    bsdf = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"]
    linked = []
    for b in bsdf:
        for key in ("Base Color", "Roughness", "Metallic", "Normal", "Coat Weight", "Specular IOR Level"):
            if b.inputs[key].is_linked:
                linked.append(key)
    if "ShaderNodeBsdfTransparent" in ts and not bsdf:
        cls = "lens"
    elif ts & PROC:
        cls = "proc"            # noise/voronoi/brick ... -> needs baking or a tiling texture
    elif linked:
        cls = "mask"            # object-space math masks (decals, windows) -> geometry or baking
    else:
        cls = "flat"
    info = dict(cls=cls, emit=emit, bump="Normal" in linked, nodes=len(types))
    if bsdf:
        b = bsdf[0]
        info["coat"] = round(float(b.inputs["Coat Weight"].default_value), 3) if not b.inputs["Coat Weight"].is_linked else "linked"
        info["metal"] = round(float(b.inputs["Metallic"].default_value), 3) if not b.inputs["Metallic"].is_linked else "linked"
        info["rough"] = round(float(b.inputs["Roughness"].default_value), 3) if not b.inputs["Roughness"].is_linked else "linked"
        info["transmission"] = round(float(b.inputs["Transmission Weight"].default_value), 3)
    return info


def measure(rig):
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    objs = [o for o in rig.root.children_recursive]
    out = dict(objects=0, tris=0, verts=0, types={}, modifiers={}, mats={}, tris_by_cls={}, empties=0,
               neg_scale=0, shared_mesh=0, per_object=[])
    seen_mesh = {}
    pts = []
    for ob in objs:
        out["types"][ob.type] = out["types"].get(ob.type, 0) + 1
        if ob.type == "EMPTY":
            out["empties"] += 1
            continue
        if ob.type not in ("MESH", "CURVE", "FONT"):
            continue
        if ob.hide_render:
            continue
        for m in ob.modifiers:
            out["modifiers"][m.type] = out["modifiers"].get(m.type, 0) + 1
        if ob.scale.x * ob.scale.y * ob.scale.z < 0:
            out["neg_scale"] += 1
        if ob.data.name in seen_mesh:
            out["shared_mesh"] += 1
        seen_mesh[ob.data.name] = 1
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        nt = len(me.loop_triangles)
        nv = len(me.vertices)
        base_tris = sum(len(p.vertices) - 2 for p in ob.data.polygons) if ob.type == "MESH" else 0
        out["objects"] += 1
        out["tris"] += nt
        out["verts"] += nv
        if nv:
            co = np.empty(nv * 3, dtype=np.float64)
            me.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3)
            mw = np.array(ob.matrix_world)
            w = co @ mw[:3, :3].T + mw[:3, 3]
            pts.append(np.array([w.min(axis=0), w.max(axis=0)]))
        # triangles per material
        mats = [s.material for s in ob.material_slots]
        if nt:
            mi = np.empty(nt, dtype=np.int32)
            me.loop_triangles.foreach_get("material_index", mi)
            for idx in np.unique(mi):
                n = int((mi == idx).sum())
                mat = mats[idx] if idx < len(mats) and mats[idx] is not None else None
                name = mat.name if mat else "<none>"
                e = out["mats"].setdefault(name, dict(tris=0, **(classify(mat) if mat else dict(cls="none", emit=[]))))
                e["tris"] += n
                out["tris_by_cls"][e["cls"]] = out["tris_by_cls"].get(e["cls"], 0) + n
        out["per_object"].append([ob.name, nt, base_tris, [m.type for m in ob.modifiers]])
        ev.to_mesh_clear()
    if pts:
        a = np.concatenate(pts)
        out["bbox"] = [[round(float(v), 3) for v in a.min(axis=0)], [round(float(v), 3) for v in a.max(axis=0)]]
    out["per_object"].sort(key=lambda t: -t[1])
    out["per_object"] = out["per_object"][:12]
    return out


def main():
    out_path = sys.argv[1]
    only = []
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1].split(",")
    sets = catalog.all_sets()
    res = {}
    if os.path.exists(out_path):
        with open(out_path) as fh:
            res = json.load(fh)
    seen_geo = {}
    for s in sets:
        sid = s["id"]
        if only and not any(sid.startswith(p) for p in only):
            continue
        if s["builder"] == "icon":
            continue
        if sid in res:
            continue
        # colour variants share geometry: one per model for cars
        if s["builder"] == "car":
            key = ("car", s["params"]["design"])
            if key in seen_geo:
                res[sid] = dict(same_as=seen_geo[key])
                continue
            seen_geo[key] = sid
        t0 = time.time()
        try:
            rig = R.Rig(quick=True)
            info = RA.build(rig, s)
            m = measure(rig)
            m["build_s"] = round(time.time() - t0, 2)
            m["builder"] = s["builder"]
            m["layers"] = s["layers"]
            m["object"] = info.get("object")
            res[sid] = m
            print("%-40s %-9s obj %4d tris %8d  mats %3d  %5.1fs  %s" % (
                sid, s["builder"], m["objects"], m["tris"], len(m["mats"]), m["build_s"], m["tris_by_cls"]), flush=True)
        except Exception as e:  # noqa
            import traceback
            traceback.print_exc()
            res[sid] = dict(error=str(e))
        with open(out_path + ".tmp", "w") as fh:
            json.dump(res, fh)
        os.replace(out_path + ".tmp", out_path)


if __name__ == "__main__":
    main()
