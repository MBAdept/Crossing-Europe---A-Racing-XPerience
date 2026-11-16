import sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-2/tools/blender")
import bpy  # noqa: E402,F401
import numpy as np  # noqa: E402

from ce3d import catalog3d, core, props3d  # noqa: E402
from cesprites import props_buildings as B  # noqa: E402

mid = sys.argv[-1] if sys.argv[-1].startswith("props/") else "props/farmhouse"
spec = catalog3d.MODELS[mid]
B.WINDOW_LOG = []
rig, info, sspec = props3d._build_source(spec)
log = list(B.WINDOW_LOG)
B.WINDOW_LOG = None
objs = props3d._objects(rig)
core.realize(objs)
orig_cdt = props3d._cdt_with_holes


def traced(poly, holes):
    t = orig_cdt(poly, holes)
    print("  CDT poly", [tuple(round(v, 2) for v in p) for p in poly], "holes", len(holes), "-> tris", len(t))
    return t


props3d._cdt_with_holes = traced
geo = props3d._Geo()
for e in log:
    for d in e["decals"]:
        pts = d.get("poly") or []
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        if (max(xs) - min(xs)) * (max(ys) - min(ys)) > 1.5 and min(ys) < 0.05:
            d["door"] = True
            d["face"] = d.get("face", "front")
n = props3d._openings(rig, objs, log, dict(spec.get("openings") or {}), geo)
print("OPENINGS", n)
for name, (m, tris) in sorted(geo.tris.items()):
    print("GEO", name, len(tris))
