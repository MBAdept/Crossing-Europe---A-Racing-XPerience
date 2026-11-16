"""Debug: flipped triangles of a player level after the whole assembly (per MeshBuilder chunk).
usage: bpy-python dbg_flip.py <design> <level>"""
import sys

W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1"
sys.path.insert(0, W + "/tools/blender")
import bpy  # noqa
import numpy as np

from ce3d import catalog3d, core, vehicles3d

design = sys.argv[1]
level = sys.argv[2]
spec3d = catalog3d.MODELS["player/" + design]
car, info, params, nodes, pivots, tr = vehicles3d._player_level(spec3d, level)
mb = nodes["body"]
for cls, chunks in mb.chunks.items():
    for i, (pos, nor, col, uv, uv2) in enumerate(chunks):
        p32 = pos.astype(np.float32).astype(np.float64)
        g = np.cross(p32[:, 1] - p32[:, 0], p32[:, 2] - p32[:, 0])
        area = np.linalg.norm(g, axis=1) * 0.5
        flip = (np.einsum("ij,ij->i", g, nor.sum(axis=1)) < 0) & (area > 1e-12)
        if flip.any():
            c = pos[flip].mean(axis=(0, 1))
            print("%s chunk %d: %d tris, %d flipped, col %s, centre of flipped (%.3f %.3f %.3f), areas mm2 %s" % (
                cls, i, pos.shape[0], int(flip.sum()), col[0, 0].tolist() if col is not None else None, c[0], c[1], c[2],
                np.round(area[flip][:8] * 1e6, 3).tolist()))
