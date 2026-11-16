"""Debug: tuck of the shadow caster of a player car. usage: bpy-python dbg_shadow.py <design>"""
import sys

W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1"
sys.path.insert(0, W + "/tools/blender")
import bpy  # noqa
import numpy as np

from ce3d import catalog3d, core, vehicles3d

spec = catalog3d.MODELS["player/" + sys.argv[1]]
car, info, params, nodes, pivots, tr = vehicles3d._player_level(spec, "lod0")
shell = info["shell"]
for k, v in shell.items():
    g = np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0])
    c = v.mean(axis=1)
    vol = float(np.einsum("ij,ij->i", c, g).sum() / 6.0)
    print("shell", k, v.shape[0], "triangles, signed volume %.3f m3" % vol, "bounds", np.round(v.reshape(-1, 3).min(axis=0), 3), np.round(v.reshape(-1, 3).max(axis=0), 3))
mb, st = vehicles3d._player_shadow(spec, shell)
print("tuck", st)

# --- trace of the tuck of the lower loft
from cesprites import carbody as CB
from cesprites import player_cars
from cesprites import rig as R
from ce3d import lod as LOD
from mathutils.bvhtree import BVHTree
sspec = vehicles3d._sprite_spec(spec["source"])
p = sspec["params"]
d = player_cars.DESIGNS[p["design"]]
rig = R.Rig(quick=True)
car = CB.SmoothCar(rig, d, paint=p["paint"], metal=0.3, name=p["design"], detail=LOD.PLAYER_DETAIL["shadow"])
ys = {car.lb0, car.lb1}
for i in range(1, 12):
    ys.add(car.lb0 + (car.lb1 - car.lb0) * i / 12.0)
for ya in (car.y_ra, car.y_fa):
    ys.update((ya - car.Ra, ya - car.Ra * 0.5, ya, ya + car.Ra * 0.5, ya + car.Ra))
lower = car._loft_object("shadow_lower", sorted(ys), car.lower_half, car.paint)
car.finish()
s = core.soups_of([lower])[0]
sh = shell["body"]
sv = sh.reshape(-1, 3)
tree = BVHTree.FromPolygons(sv.tolist(), [(3 * i, 3 * i + 1, 3 * i + 2) for i in range(sh.shape[0])])
sfn = np.cross(sh[:, 1] - sh[:, 0], sh[:, 2] - sh[:, 0])
sfn /= np.maximum(np.linalg.norm(sfn, axis=1, keepdims=True), 1e-12)
def measure(pos, tag):
    pts = np.einsum("sw,twk->tsk", core._TUCK_W, pos).reshape(-1, 3)
    h = np.full(len(pts), -0.3)
    for k in range(len(pts)):
        loc, _n, idx, _d = tree.find_nearest(pts[k].tolist(), 0.3)
        if loc is not None and sfn[idx, 2] >= -0.25:
            h[k] = float((pts[k] - np.array(loc)) @ sfn[idx])
    order = np.argsort(-h)[:6]
    print(tag, "samples above -12 mm: %d of %d" % (int((h > -0.012).sum()), len(h)))
    for k in order:
        print("    h %6.1f mm at" % (h[k] * 1000), np.round(pts[k], 3))
print("stations", [round(v - car.L / 2, 3) for v in sorted(ys)], "ya", round(car.y_ra - car.L / 2, 3), "Ra", round(car.Ra, 3), "R", car.R, "W2", car.W2)
holes = [(ya - car.L / 2.0, car.R, car.Ra + 0.03) for ya in (car.y_ra, car.y_fa)]
for rounds in (1, 4, 30):
    q = s.pos.copy()
    r = core.tuck_inside(q, sh, 0.012, rounds=rounds, holes=holes)
    print("rounds", rounds, [round(v * 1000, 1) if isinstance(v, float) else v for v in r])
print("max move mm", round(float(np.abs(q - s.pos).max() * 1000), 1))
g0 = np.cross(s.pos[:, 1] - s.pos[:, 0], s.pos[:, 2] - s.pos[:, 0])
g1 = np.cross(q[:, 1] - q[:, 0], q[:, 2] - q[:, 0])
turned = np.nonzero(np.einsum("ij,ij->i", g0, g1) < 0)[0]
a0 = 0.5 * np.linalg.norm(g0, axis=1)
print("turned", len(turned), "areas cm2", np.round(np.sort(a0[turned])[-8:] * 1e4, 2), "total area hull m2", round(float(a0.sum()), 2))
for k in turned[np.argsort(-a0[turned])][:8]:
    print("   turned: %6.2f cm2 at" % (a0[k] * 1e4), np.round(s.pos[k].mean(axis=0), 3), "edge lengths mm", np.round(np.linalg.norm(s.pos[k] - np.roll(s.pos[k], 1, axis=0), axis=1) * 1000, 1), "moves mm", np.round(np.linalg.norm(q[k] - s.pos[k], axis=1) * 1000, 1))
