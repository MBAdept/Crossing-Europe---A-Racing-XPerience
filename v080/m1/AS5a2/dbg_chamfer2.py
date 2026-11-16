import os, sys
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-4"
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa
import numpy as np
from ce3d import catalog3d, props3d as P, cities3d as CC, core
from ce3d import buildings3d as H
spec = dict(catalog3d.MODELS["props/city_paris_corner"])
log = []
restore = CC._log_walls(log, 0.06)
try:
    rig, info, sspec = P._build_source(spec)
finally:
    restore()
objs = P._objects(rig)
core.realize(objs)
opt = dict(spec.get("openings") or {})
opt.setdefault("far_ring", False)
print("OPT", opt)
geo, mats, stats = H.Geo(), H.Mats(), {}
recs = CC.cut_openings(rig, objs, log, opt, geo, mats, stats)
print("STATS", stats)
for r in recs:
    if r["cls"] == "chamfer":
        print("REC", r["ob"], r["mat"], len(r["holes"]), r["poly"][:4])
print("CLASSES", sorted({r["cls"] for r in recs}))
