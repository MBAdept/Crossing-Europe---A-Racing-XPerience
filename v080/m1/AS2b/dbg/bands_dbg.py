# Debug: where do the band lines cross the bodies of a police car (per level)?
import sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender")
import bpy  # noqa
import numpy as np
from ce3d import police3d as P, catalog3d
from ce3d import traffic3d as T
from cesprites import catalog, designs
cc = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "de"
p = catalog.POLICE[cc]
base = p["model"]
traffic = catalog3d.MODELS["traffic/" + base]
tspec = dict(design=base, detail=traffic.get("detail", {}), far_sill=traffic.get("far_sill", True))
pol = P._Police(cc, p, designs.TRAFFIC_MODELS[base])
orig = P._Police._bands
print("levels", pol.row_levels())


def dbg(self, t, pal, base_data, i_paint, level):
    lines = sorted({z for b in self.bands for z in b["z"]})
    paint = t.mat == i_paint
    fn = t.face_normals()
    sn = t.nor.mean(axis=1)
    for z in lines:
        d = t.pos[:, :, 2] - z
        cross = (d.min(axis=1) < -1e-6) & (d.max(axis=1) > 1e-6) & paint
        if not cross.any():
            continue
        cap = cross & (np.abs(fn[:, 1]) > 0.9)
        side = cross & (np.abs(fn[:, 0]) > 0.7)
        other = cross & ~cap & ~side
        zext = t.pos[:, :, 2].max(axis=1) - t.pos[:, :, 2].min(axis=1)
        print("  level %d z %.3f: %4d crossed: cap %4d side %4d other %4d | zext<1cm %d <4cm %d | ys other %s" % (
            level, z, cross.sum(), cap.sum(), side.sum(), other.sum(), (cross & (zext < 0.01)).sum(),
            (cross & (zext < 0.04)).sum(), np.round(np.sort(t.pos[other][:, :, 1].mean(axis=1))[:40], 2).tolist()))
    return orig(self, t, pal, base_data, i_paint, level)


P._Police._bands = dbg
with P._hooks(pol):
    fine = None
    for level in ("lod0", "lod1", "lod2"):
        print(level)
        car, sc, nodes, pivots, origin, tr, st, lofts = T._level(tspec, level, p["body"], 0.3, fine)
        if level == "lod0":
            fine = lofts
