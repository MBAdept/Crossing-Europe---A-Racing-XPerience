#!/usr/bin/env python3
"""Texel density per atlas size with and without visibility weighting (no baking): road-facing (-x) and
approach-facing (-y) walls weight 1, away-facing walls 0.3, undersides 0.05."""
import json, os, sys
REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import render_all as RA
from ce3d import bake as BK, core
from cesprites import catalog, rig as R
sets = {s["id"]: s for s in catalog.all_sets()}
W = {0: 0.3, 1: 1.0, 2: 0.3, 3: 1.0, 4: 0.7, 5: 0.05}      # +x, -x, +y, -y, +z, -z (generator space)
out = {}
for sid in sys.argv[2].split(","):
    rig = R.Rig(quick=True)
    RA.build(rig, sets[sid])
    objs = core.model_objects(rig)
    BK.realize_in_place(objs)
    names = {s.material.name for o in objs for s in o.material_slots
             if s.material and core.mat_info(s.material)["cls"] in ("mask", "proc")}
    bobjs = [o for o in objs if any(s.material and s.material.name in names for s in o.material_slots)]
    res = {}
    for label, wf in (("uniform", None), ("weighted", lambda ob, c, comp: W[c])):
        charts = BK.box_unwrap(bobjs, lambda m: m is not None and m.name in names, wf)
        area = sum(c["area"] for c in charts)
        for size in ((1024, 1024), (2048, 1024), (2048, 2048)):
            ppm = BK.pack(charts, size, gutter=3, ppm_max=512.0)
            res["%s_%dx%d" % (label, size[0], size[1])] = round(ppm, 1)
        res["charts"] = len(charts)
        res["area_m2"] = round(area, 0)
    out[sid] = res
    print(sid, res, flush=True)
json.dump(out, open(sys.argv[1], "w"), indent=1)
