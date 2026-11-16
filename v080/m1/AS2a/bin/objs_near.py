"""AS1R: build a player car level in Blender and list the objects with vertices in a box (build space).
usage: python objs_near.py <design> <level> x0,y0,z0,x1,y1,z1"""
import sys

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-3"
sys.path.insert(0, WT + "/tools/blender")
import bpy  # noqa
import numpy as np

from ce3d import lod as LOD
from ce3d import vehicles3d as V
from cesprites import meshutil as MU
from cesprites import player_cars
from cesprites import rig as R

design, level = sys.argv[1], sys.argv[2]
box = [float(x) for x in sys.argv[3].split(",")]
sspec = V._sprite_spec("player/" + design)
params = dict(sspec["params"])
params["detail"] = dict(LOD.PLAYER_DETAIL[level], extras=True)
rig = R.Rig(quick=True)
MU.tagging(True)
info = player_cars.build(rig, params)
car = info["car"]
car.center.location = (0.0, 0.0, 0.0)
bpy.context.view_layer.update()
MU.tagging(False)
print("y_fa", car.y_fa, "Ra", car.Ra, "L", car.L)
for ob in bpy.data.objects:
    if ob.type != "MESH":
        continue
    mw = ob.matrix_world
    pts = np.array([tuple(mw @ v.co) for v in ob.data.vertices])
    if len(pts) == 0:
        continue
    inside = (pts[:, 0] >= box[0]) & (pts[:, 0] <= box[3]) & (pts[:, 1] >= box[1]) & (pts[:, 1] <= box[4]) & \
             (pts[:, 2] >= box[2]) & (pts[:, 2] <= box[5])
    if inside.any():
        print("%-34s %5d verts in box; object bbox %s .. %s" % (ob.name, int(inside.sum()), pts.min(0).round(3),
                                                             pts.max(0).round(3)))
