#!/usr/bin/env python3
"""Baseline: export the raw generator output with Blender's stock glTF exporter (no preparation) and report
what survives (materials, modifiers, text objects)."""
import json
import os
import struct
import sys
import time

REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import bpy  # noqa: E402

import render_all as RA  # noqa: E402
from cesprites import catalog  # noqa: E402
from cesprites import rig as R  # noqa: E402


def glb_json(path):
    with open(path, "rb") as fh:
        magic, ver, total = struct.unpack("<4sII", fh.read(12))
        ln, kind = struct.unpack("<I4s", fh.read(8))
        return json.loads(fh.read(ln))


def main():
    out_dir = sys.argv[1]
    ids = sys.argv[2].split(",")
    os.makedirs(out_dir, exist_ok=True)
    sets = {s["id"]: s for s in catalog.all_sets()}
    rep = {}
    for sid in ids:
        s = sets[sid]
        rig = R.Rig(quick=True)
        t0 = time.time()
        RA.build(rig, s)
        tb = time.time() - t0
        path = os.path.join(out_dir, sid.replace("/", "_") + "_naive.glb")
        t0 = time.time()
        err = None
        try:
            bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                                      export_materials="EXPORT", export_cameras=False, export_lights=False,
                                      export_animations=False, export_extras=False)
        except Exception as e:  # noqa
            err = repr(e)
        te = time.time() - t0
        r = dict(build_s=round(tb, 1), export_s=round(te, 1), error=err)
        if os.path.exists(path):
            j = glb_json(path)
            r["bytes"] = os.path.getsize(path)
            r["nodes"] = len(j.get("nodes", []))
            r["meshes"] = len(j.get("meshes", []))
            r["materials"] = len(j.get("materials", []))
            r["images"] = len(j.get("images", []))
            tris = 0
            for m in j.get("meshes", []):
                for p in m["primitives"]:
                    acc = j["accessors"][p["indices"]]
                    tris += acc["count"] // 3
            r["tris"] = tris
            mats = []
            for m in j.get("materials", []):
                pbr = m.get("pbrMetallicRoughness", {})
                mats.append(dict(name=m.get("name"), base=pbr.get("baseColorFactor"), metal=pbr.get("metallicFactor"),
                                 rough=pbr.get("roughnessFactor"), emissive=m.get("emissiveFactor"),
                                 ext=list(m.get("extensions", {}).keys()), alpha=m.get("alphaMode")))
            r["mats"] = mats
            r["default_mats"] = sum(1 for m in mats if m["base"] is None and not m["ext"])
        rep[sid] = r
        print(sid, {k: v for k, v in r.items() if k != "mats"}, flush=True)
        for m in r.get("mats", [])[:14]:
            print("    ", m)
    with open(os.path.join(out_dir, "naive_report.json"), "w") as fh:
        json.dump(rep, fh, indent=1)


if __name__ == "__main__":
    main()
