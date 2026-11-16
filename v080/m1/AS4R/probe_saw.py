"""AS4R scratch: are the faces of the factory's sawtooth prisms turned outwards? (M4 hypothesis: some front triangles
face inwards - culled in Godot - and the lit skylight glass shows through the hole)."""
import os
import sys

WT = sys.argv[1]
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa: E402,F401
import numpy as np  # noqa: E402

from ce3d import catalog3d, core  # noqa: E402
from ce3d import props3d as P  # noqa: E402

spec = dict(catalog3d.MODELS["props/factory"])
rig, info, sspec = P._build_source(spec)
objs = P._objects(rig)
core.realize(objs)
for ob in objs:
    if not ob.name.startswith(("fac_saw", "fac_glass")):
        continue
    mw = np.array(ob.matrix_world)
    vs = np.array([mw[:3, :3] @ np.array(v.co) + mw[:3, 3] for v in ob.data.vertices])
    cen = vs.mean(axis=0)
    out = []
    for p in ob.data.polygons:
        n = mw[:3, :3] @ np.array(p.normal)
        c = mw[:3, :3] @ np.array(p.center) + mw[:3, 3]
        s = float(n @ (c - cen))
        out.append("%s n=(%.2f,%.2f,%.2f) %s" % (len(p.vertices), n[0], n[1], n[2], "out" if s > 0 else "IN"))
    print(ob.name, "centre", np.round(cen, 2), "|", "; ".join(out))
