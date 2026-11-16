# Debug: are the livery rows in the lower body loft?
import sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender")
import bpy  # noqa
import numpy as np
from ce3d import police3d as P, catalog3d, core
from ce3d import traffic3d as T
from cesprites import catalog, designs
from cesprites import carbody as CB
cc = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "at"
p = catalog.POLICE[cc]
base = p["model"]
traffic = catalog3d.MODELS["traffic/" + base]
tspec = dict(design=base, detail=traffic.get("detail", {}), far_sill=traffic.get("far_sill", True))
pol = P._Police(cc, p, designs.TRAFFIC_MODELS[base])
levels = pol.row_levels()
print("levels", levels)
orig_build_lower = CB.SmoothCar.build_lower


def bl(self, mat=None):
    ob = orig_build_lower(self, mat)
    mid = 0.5 * (self.lb0 + self.lb1)
    pts, k, f = self.lower_half(mid)
    print("  mid profile (%d pts, k_sh %d):" % (len(pts), k), [(round(x, 3), round(z, 3)) for x, z in pts[:20]])
    print("  segs", getattr(self, "_police_rows", None))
    s = core.soups_of([ob])[0]
    zs = s.pos[:, :, 2].ravel()
    for z in levels:
        print("   level %.3f: %d corners within 0.5 mm" % (z, int((np.abs(zs - z) < 5e-4).sum())))
    return ob


CB.SmoothCar.build_lower = bl
with P._hooks(pol):
    for level in ("lod0", "lod1", "lod2"):
        print(level)
        car, sc, nodes, pivots, origin, tr, st, lofts = T._level(tspec, level, p["body"], 0.3, None)
