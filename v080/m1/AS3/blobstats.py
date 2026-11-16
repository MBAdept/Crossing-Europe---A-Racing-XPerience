"""AS3 scratch: statistics of the crown blobs of a species (exposure, occlusion) - run with the Blender python:
   /home/user/tools/bpyenv/bin/python blobstats.py props/tree_oak [seed]"""
import os
import sys

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-1"
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa: F401,E402
import numpy as np  # noqa: E402

from ce3d import veg3d as V  # noqa: E402

src = sys.argv[1]
spec = {"source": src}
if len(sys.argv) > 2:
    spec["params"] = {"seed": int(sys.argv[2])}
sspec, info, wood, crown_pts, blobs = V._source(spec)
bc, br, bz = V._blob_arrays(blobs)
centre = bc.mean(axis=0)
exp = V._exposed(bc, br, bz, 48)
print("blobs", len(blobs), "with exposure", len(exp), "r", br.min().round(2), br.max().round(2))
rows = []
for (b, pts, nrm) in exp:
    ao = V._occlusion(pts, nrm, bc, br, bz)
    rows.append((b, pts.shape[0], float(ao.mean()), float(ao.max()), float(br[b])))
rows.sort(key=lambda r: -r[1] * r[4] ** 2)
for r in rows:
    print("blob %2d exposed %2d ao mean %.2f max %.2f r %.2f" % r)
vis = [r for r in rows if r[3] > 0.35]
print("visible (ao max > 0.35):", len(vis))
