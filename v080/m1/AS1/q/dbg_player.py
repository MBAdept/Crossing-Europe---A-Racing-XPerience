"""Debug: builds one level of a player car and prints triangles per object and flipped triangles.
usage: bpy-python dbg_player.py <design> <level>"""
import re
import sys

W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1"
sys.path.insert(0, W + "/tools/blender")
import bpy  # noqa
import numpy as np

from ce3d import catalog3d, core, roles, vehicles3d
from cesprites import meshutil as MU
from cesprites import player_cars
from cesprites import rig as R
from ce3d import lod as LOD
from ce3d import interior3d

design = sys.argv[1]
level = sys.argv[2]
spec3d = catalog3d.MODELS["player/" + design]
sspec = vehicles3d._sprite_spec(spec3d["source"])
params = dict(sspec["params"])
params["detail"] = dict(LOD.PLAYER_DETAIL[level], extras=True)
rig = R.Rig(quick=True)
MU.tagging(True)
info = player_cars.build(rig, params)
car = info["car"]
MU.tagging(False)
soups = core.soups_of(core.model_objects(rig))
groups = {}
for s in soups:
    g = np.cross(s.pos[:, 1] - s.pos[:, 0], s.pos[:, 2] - s.pos[:, 0])
    flip = int((np.einsum("ij,ij->i", g, s.nor.sum(axis=1)) < 0).sum())
    key = re.sub(r"\.\d+$", "", s.name)
    e = groups.setdefault(key, [0, 0])
    e[0] += s.n
    e[1] += flip
print("--- %s %s: %d triangles" % (design, level, sum(v[0] for v in groups.values())))
for k, v in sorted(groups.items(), key=lambda kv: -kv[1][0]):
    print("   %6d  %4d flipped  %s" % (v[0], v[1], k))
