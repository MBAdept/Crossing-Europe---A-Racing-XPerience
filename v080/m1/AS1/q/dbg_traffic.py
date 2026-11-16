"""Debug: triangles per node / object of a traffic car level. usage: bpy-python dbg_traffic.py <design> <level>"""
import re
import sys

W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1"
sys.path.insert(0, W + "/tools/blender")
import bpy  # noqa
import numpy as np

from ce3d import catalog3d, core, traffic3d

design, level = sys.argv[1], sys.argv[2]
spec = catalog3d.MODELS["traffic/" + design]
fine = None
if level != "lod0":
    fine = traffic3d._level(spec, "lod0", "#808080", 0.3)[7]
car, sc, nodes, pivots, origin, tr, stats, lofts = traffic3d._level(spec, level, "#808080", 0.3, fine)
tot = 0
for node, mb in sorted(nodes.items()):
    n = mb.triangles()
    tot += n if not node.startswith("wheel_") or node == "wheel_0r" else 0
    print("%-10s %6d" % (node, n))
print("stats", stats)
deps = bpy.context.evaluated_depsgraph_get()
groups = {}
for ob in core.model_objects(sc.rig):
    me = ob.evaluated_get(deps).to_mesh()
    me.calc_loop_triangles()
    key = re.sub(r"\.\d+$", "", ob.name)
    groups[key] = groups.get(key, 0) + len(me.loop_triangles)
for k, v in sorted(groups.items(), key=lambda kv: -kv[1])[:14]:
    print("   %6d  %s" % (v, k))
