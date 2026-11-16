"""AS5a1 scratch: what does the generator build for a sprite set? Objects, triangles, materials (role), node.
   /home/user/tools/bpyenv/bin/python inspect_src.py <worktree> <set id>[,<set id>...]"""
import os
import sys

WT = sys.argv[1]
IDS = sys.argv[2].split(",")
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa: E402,F401

from ce3d import core, roles  # noqa: E402
from ce3d import props3d as P  # noqa: E402

for sid in IDS:
    rig, info, sspec = P._build_source({"source": sid})
    objs = core.model_objects(rig)
    core.realize(objs)
    tot = 0
    rows = []
    for ob in objs:
        me = ob.data
        me.calc_loop_triangles()
        n = len(me.loop_triangles)
        tot += n
        mats = []
        for s in ob.material_slots:
            m = s.material
            if m is None:
                continue
            try:
                role, d = roles.tag(m)
            except Exception as e:  # noqa: BLE001
                role, d = "?" + str(e)[:20], {}
            mats.append("%s(%s)" % (m.name, role))
        rows.append((n, ob.name, roles.node_of(ob), ",".join(mats)))
    print("==== %s  objects %d  tris %d  info %s" % (sid, len(objs), tot, info))
    for n, name, node, mats in sorted(rows, key=lambda r: -r[0]):
        print("  %6d  %-22s %-6s %s" % (n, name, node, mats))
