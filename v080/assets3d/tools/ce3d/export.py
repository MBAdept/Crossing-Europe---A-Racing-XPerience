"""Spike exporter: one cesprites set -> .glb (+ baked textures) with node/surface conventions.

Nodes (Godot space: X right, Y up, -Z = forward / along the road):
  <root>            scene root, extras: manifest entry
    body            everything that does not turn (vehicles) / the whole prop
    wheel_<axle><l|r>   wheel centre pivot (axle 0 = front), mesh = tyre + rim + disc
Surfaces (material names = roles):
  paint             body colour (clear coat set by the renderer; colour variants share the mesh)
  trim              vertex PBR: COLOR_0 = albedo (sRGB bytes), UV0 = (roughness, metallic)
  glass             glazing
  lens_*            lamp lenses (alpha blend)
  em_<layers>_*     emissive parts; extras.emit = {layer: [r, g, b]} (linear, strength folded in)
  baked             atlas textures (albedo, orm, emission per layer) for procedural materials
"""
import io
import json
import math
import os
import time

import bpy
import numpy as np

from . import bake as BK
from . import core
from .glb import Glb

WHEEL_KEYS = ("tyre", "_rim", "_dish", "wheel", "_brake")


def is_wheel_part(ob):
    n = ob.name.lower()
    if "brake3" in n or "brakefill" in n:
        return False
    return any(k in n for k in WHEEL_KEYS)


def surface_key(mat, info, opts):
    """Role of a material -> (surface name, kind)."""
    name = mat.name if mat else "none"
    cls = info["cls"]
    if cls in ("mask", "proc") or info["emit_proc"]:
        return "baked", "baked"
    if cls == "lens":
        return "lens", "lens"
    if info["emit"]:
        sig = "+".join(sorted(info["emit"].keys()))
        col = "_".join("%02x" % int(max(0, min(1, c)) * 255) for layer in sorted(info["emit"]) for c in info["emit"][layer])
        return "em_%s_%s" % (sig, col[:20]), "emissive"
    base = name.split(".")[0]
    if base.endswith("_paint"):
        return "paint", "paint"
    if "glass" in base and "mirror" not in base:
        return "glass", "glass"
    return "trim", "trim"


def export_set(rig, spec, info_build, out_dir, opts):
    """opts: atlas=(W,H) | None, ppm_max, vehicle=bool, lod_ratio, min_obj_tris_keep, name"""
    t_start = time.time()
    name = opts.get("name") or spec["id"].replace("/", "_")
    objs = core.model_objects(rig)
    stats = dict(id=spec["id"], name=name, objects=len(objs))
    # --- materials
    minfo = {}
    for ob in objs:
        for s in ob.material_slots:
            if s.material and s.material.name not in minfo:
                minfo[s.material.name] = core.mat_info(s.material)
    stats["materials_src"] = len(minfo)
    stats["mat_classes"] = {}
    for k, v in minfo.items():
        stats["mat_classes"][v["cls"]] = stats["mat_classes"].get(v["cls"], 0) + 1
    t0 = time.time()
    BK.realize_in_place(objs)
    stats["realize_s"] = round(time.time() - t0, 2)
    # optional LOD: collapse decimation per object (after realising), tiny objects dropped
    if opts.get("planar_deg"):
        # error-bounded clean-up: merge (nearly) coplanar triangles of the dense lofts / CDT patches
        for ob in objs:
            if is_wheel_part(ob) and not opts.get("planar_wheels"):
                continue
            m = ob.modifiers.new("planar", "DECIMATE")
            m.decimate_type = "DISSOLVE"
            m.angle_limit = math.radians(opts["planar_deg"])
            m.delimit = {"MATERIAL", "SHARP"}
        BK.realize_in_place(objs)
    lod = opts.get("lod_ratio")
    if lod:
        keep = []
        for ob in objs:
            nt = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            if nt < opts.get("lod_drop_below", 0) and not is_wheel_part(ob):
                dims = ob.dimensions
                if max(dims) < opts.get("lod_drop_size", 0.0):
                    continue
            if nt > opts.get("lod_min_tris", 200):
                core.decimate_copy(ob, lod)
            keep.append(ob)
        objs = keep
        BK.realize_in_place(objs)
    # --- baking
    bake_names = {k for k, v in minfo.items() if surface_key(bpy.data.materials[k], v, opts)[1] == "baked"}
    textures = {}
    atlas = opts.get("atlas")
    layers = [l for l in spec["layers"] if l != "base"]
    if bake_names and atlas:
        t0 = time.time()
        bobjs = [o for o in objs if any(s.material and s.material.name in bake_names for s in o.material_slots)]
        charts = BK.box_unwrap(bobjs, lambda m: m is not None and m.name in bake_names, opts.get("weight_fn"))
        ppm = BK.pack(charts, atlas, gutter=opts.get("gutter", 3), ppm_max=opts.get("ppm_max", 512.0))
        BK.write_uvs(charts, atlas)
        stats["bake"] = dict(atlas=list(atlas), charts=len(charts), ppm=round(ppm, 1),
                             area_m2=round(sum(c["area"] for c in charts), 1), unwrap_s=round(time.time() - t0, 2))
        t0 = time.time()
        bk = BK.Baker(rig, bobjs, [bpy.data.materials[k] for k in sorted(bake_names)], atlas)
        alb = bk.bake_input("Base Color")
        cov = bk.coverage()
        rough = bk.bake_input("Roughness")
        metal = bk.bake_input("Metallic")
        textures["albedo"] = alb
        orm = np.zeros_like(alb)
        orm[:, :, 0] = 1.0
        orm[:, :, 1] = rough[:, :, 0]
        orm[:, :, 2] = metal[:, :, 0]
        textures["orm"] = orm
        if opts.get("cutout"):
            op = bk.bake_opacity()
            if op is not None:
                textures["opacity"] = op[:, :, 0]
        if opts.get("paint_mask"):
            # alpha = 1 where the base colour equals the paint colour (colour variants in the shader)
            pc = np.array(opts["paint_mask"][:3], dtype=np.float32)
            d = np.abs(alb[:, :, :3] - pc).max(axis=2)
            textures["paintmask"] = np.clip(1.0 - d / 0.02, 0.0, 1.0)
        for layer in layers:
            if any(layer in minfo[k]["emit_proc"] or layer in minfo[k]["emit"] for k in bake_names):
                textures["emit_" + layer] = bk.bake_layer(layer)
        from cesprites import materials as M
        M.set_pass("base")
        stats["bake"]["bake_s"] = round(time.time() - t0, 2)
        stats["bake"]["coverage"] = round(float((cov > 0.5).mean()), 3)
    # --- soups, node assignment
    t0 = time.time()
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    soups = [core.Soup(ob, deps, uv_layer=BK.UV_NAME) for ob in objs]
    soups = [s for s in soups if s.n > 0]
    nodes = {"body": []}
    wheel_centres = []
    if opts.get("vehicle"):
        tyres = [s for s in soups if "tyre" in s.name.lower()]
        for s in tyres:
            p = s.pos.reshape(-1, 3)
            # dual tyres (trucks) form one object: one centre per tyre object
            c = (p.min(axis=0) + p.max(axis=0)) / 2
            wheel_centres.append(c)
        # merge centres closer than 0.45 m in x and 0.1 m in y (dual wheels stay one node)
        merged = []
        for c in wheel_centres:
            for mc in merged:
                if abs(mc[1] - c[1]) < 0.1 and (mc[0] > 0) == (c[0] > 0):
                    break
            else:
                merged.append(c)
        wheel_centres = merged
        ys = sorted({round(float(c[1]), 2) for c in wheel_centres}, reverse=True)      # front axle first
        wnames = []
        for c in wheel_centres:
            axle = ys.index(round(float(c[1]), 2))
            wnames.append("wheel_%d%s" % (axle, "r" if c[0] > 0 else "l"))
        for wn in wnames:
            nodes[wn] = []
        for s in soups:
            if is_wheel_part(s.ob):
                p = s.pos.reshape(-1, 3)
                c = (p.min(axis=0) + p.max(axis=0)) / 2
                d = [abs(c[1] - w[1]) + (0.0 if (c[0] > 0) == (w[0] > 0) else 10.0) for w in wheel_centres]
                nodes[wnames[int(np.argmin(d))]].append(s)
            else:
                nodes["body"].append(s)
    else:
        nodes["body"] = soups
    # --- GLB
    g = Glb()
    tex_idx = {}
    tex_files = {}
    for key, arr in textures.items():
        if key in ("paintmask", "opacity"):
            continue
        if key == "albedo" and "opacity" in textures:
            a = arr.copy()
            a[:, :, 3] = textures["opacity"]
            data, im = BK.to_png_bytes(a, linear_to_srgb=True, mode="RGBA")
        elif key == "albedo" and "paintmask" in textures:
            a = arr.copy()
            a[:, :, 3] = textures["paintmask"]
            data, im = BK.to_png_bytes(a, linear_to_srgb=True, mode="RGBA")
        elif key == "orm":
            data, im = BK.to_png_bytes(arr, linear_to_srgb=False)
        else:
            data, im = BK.to_png_bytes(arr, linear_to_srgb=True)
        fn = "%s_%s.png" % (name, key)
        with open(os.path.join(out_dir, fn), "wb") as fh:
            fh.write(data)
        tex_files[key] = dict(file=fn, bytes=len(data), size=[im.size[0], im.size[1]])
        if opts.get("embed_textures", True):
            tex_idx[key] = g.image(fn, data)
    stats["textures"] = tex_files
    surf_stats = {}
    node_ids = []
    root_children = []
    manifest_nodes = {}
    for nname, ss in nodes.items():
        if not ss:
            continue
        origin = np.zeros(3)
        if nname.startswith("wheel_"):
            p = np.concatenate([s.pos.reshape(-1, 3) for s in ss if "tyre" in s.name.lower()] or
                               [s.pos.reshape(-1, 3) for s in ss])
            origin = (p.min(axis=0) + p.max(axis=0)) / 2
        groups = {}
        for s in ss:
            for mi in np.unique(s.mi):
                mat = s.mats[mi] if mi < len(s.mats) else None
                inf = minfo.get(mat.name) if mat else core.mat_info(None)
                skey, kind = surface_key(mat, inf, opts)
                if kind == "baked" and not atlas:
                    skey, kind = "trim", "trim"
                sel = s.mi == mi
                pos = s.pos[sel] - origin
                nor = s.nor[sel]
                n = pos.shape[0]
                uv = None
                col = None
                if kind == "baked":
                    uv = s.uv[sel].copy()
                    uv[:, :, 1] = 1.0 - uv[:, :, 1]
                elif kind in ("trim", "emissive", "glass", "paint"):
                    c8 = np.clip(core.lin_to_srgb(np.array(inf["color"][:3])) * 255 + 0.5, 0, 255).astype(np.uint8)
                    col = np.empty((n, 3, 4), dtype=np.uint8)
                    col[:, :, :3] = c8
                    col[:, :, 3] = 255
                    uv = np.empty((n, 3, 2), dtype=np.float32)
                    uv[:, :, 0] = inf["rough"]
                    uv[:, :, 1] = inf["metal"]
                elif kind == "lens":
                    c8 = np.clip(core.lin_to_srgb(np.array(inf["color"][:3])) * 255 + 0.5, 0, 255).astype(np.uint8)
                    col = np.empty((n, 3, 4), dtype=np.uint8)
                    col[:, :, :3] = c8
                    col[:, :, 3] = 150 if inf.get("frost") else 90
                e = groups.setdefault(skey, dict(kind=kind, pos=[], nor=[], uv=[], col=[], info=inf, srcs=set()))
                e["pos"].append(pos)
                e["nor"].append(nor)
                if uv is not None:
                    e["uv"].append(uv)
                if col is not None:
                    e["col"].append(col)
                e["srcs"].add(mat.name if mat else "none")
        prims = []
        for skey in sorted(groups):
            e = groups[skey]
            pos = core.to_gltf_axes(np.concatenate(e["pos"]).reshape(-1, 3)).reshape(-1, 3, 3)
            nor = core.to_gltf_axes(np.concatenate(e["nor"]).reshape(-1, 3)).reshape(-1, 3, 3)
            uv = np.concatenate(e["uv"]) if e["uv"] else None
            col = np.concatenate(e["col"]) if e["col"] else None
            w = core.weld(pos, nor, uv, col)
            kind = e["kind"]
            inf = e["info"]
            extras = {"role": kind, "src": sorted(e["srcs"])[:8], "src_count": len(e["srcs"])}
            if kind == "baked":
                mi = g.material("baked", rough=1.0, metal=1.0, base_tex=tex_idx.get("albedo"), mr_tex=tex_idx.get("orm"),
                                emissive_tex=tex_idx.get("emit_lights") if "emit_lights" in tex_idx else None,
                                emissive=(0, 0, 0) if "emit_lights" in tex_idx else None, extras=extras,
                                alpha_mode="MASK" if "opacity" in textures else None,
                                alpha_cutoff=0.5 if "opacity" in textures else None,
                                double_sided="opacity" in textures)
            elif kind == "paint":
                mi = g.material("paint", color=inf["color"], rough=inf["rough"], metal=inf["metal"],
                                extras=dict(extras, coat=inf["coat"], coat_rough=inf.get("coat_rough", 0.03)))
            elif kind == "glass":
                mi = g.material("glass", color=inf["color"], rough=inf["rough"], metal=0.0, extras=extras)
            elif kind == "lens":
                mi = g.material("lens", color=(1, 1, 1, 1), rough=0.05, metal=0.0, alpha_mode="BLEND", extras=extras)
            elif kind == "emissive":
                extras["emit"] = inf["emit"]
                mi = g.material(skey, color=(1, 1, 1, 1), rough=inf["rough"], metal=inf["metal"], emissive=(0, 0, 0),
                                extras=extras)
            else:
                mi = g.material("trim", color=(1, 1, 1, 1), rough=0.5, metal=0.0, extras=extras)
            prims.append(dict(pos=w["pos"], nor=w["nor"], idx=w["idx"], uv=w["uv"], col=w["col"], material=mi))
            st = surf_stats.setdefault(skey, dict(tris=0, verts=0, kind=kind))
            st["tris"] += int(len(w["idx"]) // 3)
            st["verts"] += int(w["pos"].shape[0])
        mesh = g.mesh(name + "_" + nname, prims)
        tr = core.to_gltf_axes(origin.reshape(1, 3))[0]
        nid = g.node(nname, mesh=mesh, translation=tr)
        root_children.append(nid)
        manifest_nodes[nname] = dict(origin=[round(float(x), 4) for x in tr],
                                     tris=int(sum(len(p["idx"]) // 3 for p in prims)), surfaces=len(prims))
    entry = dict(id=spec["id"], object=info_build.get("object"), nodes=manifest_nodes, layers=spec["layers"],
                 tags=spec.get("tags", []))
    g.node(name, children=root_children, root=True, extras=entry)
    path = os.path.join(out_dir, name + ".glb")
    total = g.write(path)
    stats.update(glb=os.path.basename(path), glb_bytes=total, nodes=manifest_nodes, surfaces=surf_stats,
                 tris=int(sum(v["tris"] for v in surf_stats.values())), verts=int(sum(v["verts"] for v in surf_stats.values())),
                 write_s=round(time.time() - t0, 2), total_s=round(time.time() - t_start, 2),
                 draw_surfaces=sum(v["surfaces"] for v in manifest_nodes.values()))
    return stats
