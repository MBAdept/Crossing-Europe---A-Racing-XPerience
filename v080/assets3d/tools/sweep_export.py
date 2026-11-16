#!/usr/bin/env python3
"""Robustness sweep: runs the spike exporter over the whole catalog at a small atlas size and records
errors, triangles, chart/packing numbers and times. Usage: bpy-python sweep_export.py OUT_DIR REPORT.json"""
import json
import os
import sys
import time
import traceback

REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import render_all as RA  # noqa: E402
from ce3d import core  # noqa: E402
from ce3d import export as EX  # noqa: E402
from cesprites import catalog  # noqa: E402
from cesprites import rig as R  # noqa: E402


def special_materials(rig):
    """Materials that need special handling: alpha cut-outs (transparent mixed with a BSDF by a mask),
    fake light volumes (transparent + emission only), per-object random colours."""
    out = dict(cutout=[], light_volume=[], obj_random=[])
    seen = set()
    for ob in core.model_objects(rig):
        for s in ob.material_slots:
            m = s.material
            if m is None or m.name in seen:
                continue
            seen.add(m.name)
            ts = {n.bl_idname for n in m.node_tree.nodes}
            if "ShaderNodeObjectInfo" in ts:
                out["obj_random"].append(m.name)
            if "ShaderNodeBsdfTransparent" in ts:
                if "ShaderNodeBsdfPrincipled" in ts:
                    out["cutout"].append(m.name)
                elif "ShaderNodeBsdfGlossy" not in ts:
                    out["light_volume"].append(m.name)
    return out


def main():
    out_dir, rep_path = sys.argv[1], sys.argv[2]
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else []
    os.makedirs(out_dir, exist_ok=True)
    rep = {}
    if os.path.exists(rep_path):
        with open(rep_path) as fh:
            rep = json.load(fh)
    seen_car = set()
    for spec in catalog.all_sets():
        sid = spec["id"]
        b = spec["builder"]
        if b == "icon" or sid.startswith("showroom/") or sid in rep:
            continue
        if only and not any(sid.startswith(p) for p in only):
            continue
        if b == "car":
            if spec["params"]["design"] in seen_car:
                continue
            seen_car.add(spec["params"]["design"])
        t0 = time.time()
        try:
            opts = dict(name=sid.replace("/", "_"), embed_textures=False)
            rig = R.Rig(quick=True)
            if b == "car":
                from ce3d import decalgeo
                from cesprites import designs, vehicles
                p_ = spec["params"]
                car = vehicles.Car(rig, designs.TRAFFIC_MODELS[p_["design"]], paint=p_["paint"], metal=p_.get("metal", 0.35),
                                   name=p_["design"]).build()
                info = dict(object=car.object_size())
                dst = decalgeo.convert(rig, car, res=0.02, body_dissolve_deg=2.0, offset_scale=1.5)
                opts.update(vehicle=True)
                extra = dict(decal=dst)
            else:
                info = RA.build(rig, spec)
                info.pop("car", None)
                extra = {}
                if b == "player":
                    opts.update(vehicle=True)
                elif b in ("truck", "bus", "police"):
                    opts.update(vehicle=True, atlas=(256, 256))
                else:
                    opts.update(atlas=(256, 256), ppm_max=64.0)
            tb = time.time() - t0
            sp = special_materials(rig)
            st = EX.export_set(rig, spec, info, out_dir, opts)
            r = dict(ok=True, builder=b, build_s=round(tb, 2), export_s=st["total_s"], tris=st["tris"], verts=st["verts"],
                     glb_bytes=st["glb_bytes"], surfaces=st["draw_surfaces"], nodes=len(st["nodes"]),
                     bake=st.get("bake"), special=sp, mats=st["materials_src"], mat_classes=st["mat_classes"], **extra)
        except Exception as e:  # noqa
            traceback.print_exc()
            r = dict(ok=False, builder=b, error=repr(e)[:300], build_s=round(time.time() - t0, 2))
        rep[sid] = r
        print("%-40s %s %s" % (sid, "ok " if r["ok"] else "ERR", {k: v for k, v in r.items() if k in ("tris", "export_s", "error", "special")}), flush=True)
        with open(rep_path + ".tmp", "w") as fh:
            json.dump(rep, fh, default=str)
        os.replace(rep_path + ".tmp", rep_path)


if __name__ == "__main__":
    main()
