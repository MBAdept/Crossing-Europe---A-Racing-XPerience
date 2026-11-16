# Debug: triangles per object of a traffic car level (police base)
import sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender")
import bpy  # noqa
from ce3d import catalog3d, core, decalgeo
from ce3d import traffic3d as T

base = sys.argv[-2]
level = sys.argv[-1]
traffic = catalog3d.MODELS["traffic/" + base]
detail = dict(traffic.get("detail", {}))
tspec = dict(design=base, detail=detail, far_sill=traffic.get("far_sill", True))
orig = decalgeo.car_surfaces


def wrap(car, soups, *a, **kw):
    for n, s in sorted(soups.items()):
        print("  soup %-24s %5d" % (n, s.n))
    pal, tris, st = orig(car, soups, *a, **kw)
    for n, t in sorted(tris.items()):
        print("  cut  %-24s %5d" % (n, t.pos.shape[0]))
    return pal, tris, st


decalgeo.car_surfaces = wrap
car, sc, nodes, pivots, origin, tr, st, lofts = T._level(tspec, level, "#808080", 0.3, None)
for s in core.soups_of(core.model_objects(car.rig)):
    print("  obj  %-24s %5d" % (s.name, s.n))
for n, mb in nodes.items():
    print("node", n, mb.triangles())
