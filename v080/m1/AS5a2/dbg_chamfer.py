import os, sys
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-4"
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa
import numpy as np
from ce3d import catalog3d, props3d as P, cities3d as CC, core
spec = dict(catalog3d.MODELS["props/city_paris_corner"])
log = []
restore = CC._log_walls(log, 0.06)
try:
    rig, info, sspec = P._build_source(spec)
finally:
    restore()
objs = P._objects(rig)
core.realize(objs)
for ob in objs:
    if ob.name.startswith("phc_body"):
        for f in ob.data.polygons:
            n = np.array(f.normal)
            if abs(n[2]) < 0.1 and abs(n[0]) < 0.95 and abs(n[1]) < 0.95:
                print("FACE", ob.name, np.round(n, 3), len(f.vertices), [tuple(np.round(ob.data.vertices[i].co, 2)) for i in f.vertices][:4])
for e in log:
    for g in e["grids"]:
        if g.get("face") == "chamfer":
            print("GRID", e["material"], g.get("kind"), g["rects"][:2])
