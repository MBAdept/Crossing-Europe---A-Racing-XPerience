"""Debug: decal cut of a traffic car level; reports paint triangles inside the side glass outline."""
import sys

W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1"
sys.path.insert(0, W + "/tools/blender")
import bpy  # noqa
import numpy as np

from ce3d import catalog3d, core, decalgeo, vehicles3d
from ce3d import lod as LOD
from cesprites import meshutil as MU
from cesprites import rig as R
from cesprites import vehicles

design = sys.argv[1]
level = sys.argv[2]
rig = R.Rig(quick=True)
MU.tagging(True)
car = vehicles.Car(rig, vehicles3d.traffic_design(design), paint="#808080", metal=0.3, name=design,
                   detail=LOD.CAR_DETAIL[level]).build()
MU.tagging(False)
soups = {s.name: s for s in core.soups_of(core.model_objects(rig))}
pal, tris, stats = decalgeo.car_surfaces(car, soups, cut=True, level={"lod0": 0, "lod1": 1, "lod2": 2}[level])
w = car.windows()
t = tris[car.cabin.name]
names = {i: (it[0], str(it[1].get("color", it[1].get("slot")))) for i, it in enumerate(pal.items)}
print("palette", names)
fn = t.face_normals()
cen = t.pos.mean(axis=1)
for poly in w["side"]:
    ins = decalgeo.inset([tuple(p) for p in poly], 0.03)
    n = 0
    for i in range(t.pos.shape[0]):
        if fn[i, 0] > 0.3 and decalgeo._inside(cen[i, 1], cen[i, 2], ins):
            role = pal.items[int(t.mat[i])][0]
            if role != "glass":
                n += 1
                if n <= 6:
                    print("  not glass:", names[int(t.mat[i])], "centre", np.round(cen[i], 3), "fn", np.round(fn[i], 2),
                          "corner nx", np.round(t.nor[i][:, 0], 2), "rank", t.rank[i])
    print("pane", [tuple(round(v, 2) for v in p) for p in poly], ": %d triangles inside are not glass" % n)

# --- which triangles of the uncut cabin are candidates, and what the CDT says about a problem triangle
s = soups[car.cabin.name]
t2 = decalgeo.Tris(s.pos, s.nor)
groups = decalgeo._window_items(w, pal, 2, 3, seals=True)
items = groups[("side", 1)]
axis = np.array([1.0, 0.0, 0.0])
before = t2.pos.shape[0]
t2.split_level(axis, 0.45)
print("split_level over the whole cabin: %d -> %d triangles" % (before, t2.pos.shape[0]))
f = t2.nor @ axis
mean = f.mean(axis=1)
fn2 = t2.face_normals()
cen2 = t2.pos.mean(axis=1)
sel = (np.abs(cen2[:, 2] - 1.35) < 0.02) & (cen2[:, 0] > 0.5) & (np.abs(cen2[:, 1] - 2.0) < 0.12)
for i in np.nonzero(sel)[0][:12]:
    print("tri", i, "centre", np.round(cen2[i], 3), "f", np.round(f[i], 3), "fn", np.round(fn2[i], 2),
          "yz", np.round(t2.pos[i][:, 1:], 3).tolist())

# --- replicate apply() for the side projection on the fresh cabin
from mathutils import Vector
from mathutils import geometry as mgeo
t3 = decalgeo.Tris(s.pos, s.nor)
t3.mat[:] = 0
polys = [decalgeo._ccw([(float(p[0]), float(p[1])) for p in it["poly"]]) for it in items]
for k, it in enumerate(items):
    print("item", k, "mat", it["mat"], "rank", it["rank"], "n_min", it["n_min"], "area2", round(decalgeo._area2(polys[k]), 4), len(polys[k]))
n = t3.apply("side", 1, items, cut=True)
cen3 = t3.pos.mean(axis=1)
sel = (np.abs(cen3[:, 2] - 1.35) < 0.02) & (cen3[:, 0] > 0.5) & (np.abs(cen3[:, 1] - 2.0) < 0.12)
for i in np.nonzero(sel)[0][:12]:
    print("after side apply: tri", i, "mat", t3.mat[i], "rank", t3.rank[i], "yz", np.round(t3.pos[i][:, 1:], 3).tolist())

# --- step by step as car_surfaces does it
t4 = decalgeo.Tris(s.pos, s.nor)
t4.mat[:] = 0
def probe(tag):
    c = t4.pos.mean(axis=1)
    sel = (np.abs(c[:, 2] - 1.351) < 0.004) & (c[:, 0] > 0.5) & (np.abs(c[:, 1] - 2.018) < 0.004)
    print(tag, "triangles", t4.pos.shape[0], "probe:", [(int(i), int(t4.mat[i]), int(t4.rank[i])) for i in np.nonzero(sel)[0]])
probe("start")
for key in sorted(groups, key=lambda g: (g[0], -g[1])):
    t4.apply(key[0], key[1], groups[key], cut=True)
    probe(str(key))
dg = decalgeo._decal_items(car.cabin_decals(), pal)
for key in sorted(dg, key=lambda g: (g[0], -g[1])):
    t4.apply(key[0], key[1], dg[key], cut=True)
    probe("decals " + str(key))

# --- duplicates / area after each step
def stat(tt, tag):
    c = np.round(tt.pos.mean(axis=1) * 1e5).astype(np.int64)
    _u, cnt = np.unique(c, axis=0, return_counts=True)
    print("STAT %-18s tris %6d  area %.4f m2  coincident centres %d" % (tag, tt.pos.shape[0], float(core.tri_areas(tt.pos).sum()), int((cnt > 1).sum())))
t5 = decalgeo.Tris(s.pos, s.nor)
t5.mat[:] = 0
stat(t5, "start")
for key in sorted(groups, key=lambda g: (g[0], -g[1])):
    t5.apply(key[0], key[1], groups[key], cut=True)
    stat(t5, str(key))
