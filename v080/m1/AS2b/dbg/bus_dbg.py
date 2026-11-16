# Debug: triangles per source of a bus level
import sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender")
import bpy  # noqa
from ce3d import core, heavy3d as HV

level = int(sys.argv[-1])
b, nodes, pivots, tr = HV._level(level, {"paint": "#efefeb", "paint2": "#1f4f9a", "paint3": "#d6262b"})
for s in core.soups_of(core.model_objects(b.rig)):
    print("  obj %-28s %5d" % (s.name, s.n))
for node, lst in b.panels.items():
    for t in lst:
        print("  panel %-10s %5d" % (node, t.pos.shape[0]))
for n, mb in nodes.items():
    print("node", n, mb.triangles())
