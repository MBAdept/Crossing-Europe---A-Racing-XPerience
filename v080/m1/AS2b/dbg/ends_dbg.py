# Debug: lod1 of a check-livery police car - where do the band triangles go? Draws the cut body (side, rear, front)
# after the livery and prints the triangles per soup and per face class in the check band.
import copy
import sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender")
import bpy  # noqa
import numpy as np
from PIL import Image, ImageDraw
from ce3d import police3d as P, catalog3d
from ce3d import traffic3d as T
from cesprites import catalog, designs

OUT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2b/look/"
cc = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "be"
p = catalog.POLICE[cc]
base = p["model"]
traffic = catalog3d.MODELS["traffic/" + base]
spec3d = catalog3d.MODELS["police/" + cc]
detail = copy.deepcopy(traffic.get("detail", {}))
for lv, over in spec3d.get("detail", {}).items():
    detail.setdefault(lv, {}).update(over)
tspec = dict(design=base, detail=detail, far_sill=spec3d.get("far_sill", traffic.get("far_sill", True)))
pol = P._Police(cc, p, designs.TRAFFIC_MODELS[base])
orig_bands = P._Police._bands
LEVEL = 1


def draw(t, pal, name, tag):
    S = 300
    for view in ("side", "rear", "front"):
        fn = t.face_normals()
        if view == "side":
            sel = fn[:, 0] > 0.05
            uv = t.pos[:, :, [1, 2]]
            W, H = int(5.0 * S) + 20, int(1.2 * S) + 20
        elif view == "rear":
            sel = fn[:, 1] < -0.05
            uv = t.pos[:, :, [0, 2]] + np.array([1.15, 0.0])
            W, H = int(2.3 * S), int(1.2 * S) + 20
        else:
            sel = fn[:, 1] > 0.05
            uv = t.pos[:, :, [0, 2]] + np.array([1.15, 0.0])
            W, H = int(2.3 * S), int(1.2 * S) + 20
        im = Image.new("RGB", (W, H), (40, 40, 40))
        dr = ImageDraw.Draw(im)
        for i in np.nonzero(sel)[0]:
            role, data, lamp = pal.items[int(t.mat[i])]
            c = data.get("color", "#808080") if role != "paint" else {"paint": "#c0c0c0", "paint2": "#3050c0",
                                                                         "paint3": "#e0c020"}[data.get("slot", "paint")]
            if not isinstance(c, str):
                c = "#808080"
            pts = [(10 + u * S, H - 10 - v * S) for (u, v) in uv[i]]
            dr.polygon(pts, fill=c, outline=(0, 0, 0))
        im.save(OUT + "ends_%s_%s_%s_%s.png" % (cc, name.split("_")[-1], tag, view))


def bands(self, t, pal, base_data, i_paint, level):
    n0 = t.pos.shape[0]
    zc = t.pos[:, :, 2].mean(axis=1)
    b = [b for b in self.bands_at(level) if "check" in b]
    z0, z1 = (b[0]["z"] if b else (0, 0))
    n = t.nor.mean(axis=1)
    flank = np.abs(n[:, 0]) > np.abs(n[:, 1])
    inb = (zc > z0) & (zc < z1)
    before = (int((inb & flank).sum()), int((inb & ~flank).sum()))
    orig_bands(self, t, pal, base_data, i_paint, level)
    zc = t.pos[:, :, 2].mean(axis=1)
    n = t.nor.mean(axis=1)
    flank = np.abs(n[:, 0]) > np.abs(n[:, 1])
    inb = (zc > z0) & (zc < z1)
    after = (int((inb & flank).sum()), int((inb & ~flank).sum()))
    print("level %d: %d -> %d tris; band flank %d -> %d, ends %d -> %d" % (
        level, n0, t.pos.shape[0], before[0], after[0], before[1], after[1]))


def apply(self, car, pal, tris, level):
    for name in sorted(tris):
        print("soup", name, tris[name].pos.shape[0])
    st = orig_apply(self, car, pal, tris, level)
    for name in sorted(tris):
        print("soup after", name, tris[name].pos.shape[0])
        if level == LEVEL:
            draw(tris[name], pal, name, "l%d" % level)
    return st


orig_apply = P._Police.apply
P._Police.apply = apply
P._Police._bands = bands
with P._hooks(pol):
    fine = None
    for level in ("lod0", "lod1"):
        pol.cur_level = {"lod0": 0, "lod1": 1, "lod2": 2}[level]
        car, sc, nodes, pivots, origin, tr, st, lofts = T._level(tspec, level, p["body"], 0.3, fine)
        print(level, "nodes", {k: v.points().shape[0] for k, v in nodes.items()})
        if level == "lod0":
            fine = lofts
print("ok")
