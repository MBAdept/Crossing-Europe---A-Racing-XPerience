# Debug: draw the cut body triangles of a police car after the livery (side and rear projection), per level
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
tspec = dict(design=base, detail=traffic.get("detail", {}), far_sill=traffic.get("far_sill", True))
pol = P._Police(cc, p, designs.TRAFFIC_MODELS[base])
orig_apply = P._Police.apply
COL = {}


def draw(t, pal, name, level):
    S = 260
    W, H = int(5.0 * S) + 20, int(2.0 * S) + 20
    for view in ("side", "rear"):
        im = Image.new("RGB", (W if view == "side" else int(2.3 * S), H), (40, 40, 40))
        dr = ImageDraw.Draw(im)
        fn = t.face_normals()
        if view == "side":
            sel = fn[:, 0] > 0.05
            uv = t.pos[:, :, [1, 2]]
            off = (10, 10)
        else:
            sel = fn[:, 1] < -0.05
            uv = t.pos[:, :, [0, 2]] + np.array([1.15, 0.0])
            off = (10, 10)
        for i in np.nonzero(sel)[0]:
            role, data, lamp = pal.items[int(t.mat[i])]
            c = data.get("color", "#808080") if role != "paint" else {"paint": "#c0c0c0", "paint2": "#3050c0",
                                                                         "paint3": "#e0c020"}[data.get("slot", "paint")]
            if not isinstance(c, str):
                c = "#808080"
            pts = [(off[0] + u * S, H - off[1] - v * S) for (u, v) in uv[i]]
            dr.polygon(pts, fill=c, outline=(0, 0, 0))
        im.save(OUT + "wire_%s_%s_l%d_%s.png" % (cc, name.split("_")[-1], level, view))


def apply(self, car, pal, tris, level):
    st = orig_apply(self, car, pal, tris, level)
    draw(tris[car.body.name], pal, car.body.name, level)
    return st


P._Police.apply = apply
with P._hooks(pol):
    fine = None
    for level in ("lod0", "lod1", "lod2"):
        car, sc, nodes, pivots, origin, tr, st, lofts = T._level(tspec, level, p["body"], 0.3, fine)
        if level == "lod0":
            fine = lofts
print("ok")
