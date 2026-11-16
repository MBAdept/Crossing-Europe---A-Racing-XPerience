"""Debug: lamp-coloured triangles of a traffic car lod0 outside their outlines."""
import sys
W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1"
sys.path.insert(0, W + "/tools/blender")
import bpy  # noqa
import numpy as np
from ce3d import catalog3d, core, traffic3d
design = sys.argv[1]
spec = catalog3d.MODELS["traffic/" + design]
car, sc, nodes, pivots, origin, tr, stats, lofts = traffic3d._level(spec, "lod0", "#b52424", 0.3)
for (pos, nor, col, uv, uv2) in nodes["body"].chunks["vpbr"]:
    ch = uv2[0, 0, 0]
    c = pos.mean(axis=1)
    sel = (c[:, 1] < 0.6) & (c[:, 2] > 0.55) & (c[:, 2] < 0.80) & (np.abs(c[:, 0]) > 0.6)
    if sel.any() and (ch >= 0 or tuple(col[0, 0][:3]) not in [(181, 36, 36)]):
        a = core.tri_areas(pos[sel]) * 1e4
        print("channel %.1f colour %s alpha %d: %d triangles in the corner zone, area %.1f cm2, z %.3f..%.3f y %.3f..%.3f x %.3f..%.3f" % (
            ch, col[0, 0][:3].tolist(), col[0, 0][3], int(sel.sum()), a.sum(), pos[sel][:, :, 2].min(), pos[sel][:, :, 2].max(),
            pos[sel][:, :, 1].min(), pos[sel][:, :, 1].max(), np.abs(pos[sel][:, :, 0]).min(), np.abs(pos[sel][:, :, 0]).max()))

print("--- triangles whose corner normals disagree with their face (rear corner zone)")
for (pos, nor, col, uv, uv2) in nodes["body"].chunks["vpbr"]:
    c = pos.mean(axis=1)
    fn = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
    area = np.linalg.norm(fn, axis=1) * 0.5
    fn = fn / np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    dots = np.einsum("tij,tj->ti", nor, fn)
    sel = (c[:, 1] < 0.5) & (c[:, 2] > 0.5) & (c[:, 2] < 0.85) & (c[:, 0] > 0.5) & (dots.min(axis=1) < 0.55) & (area > 2e-5)
    for i in np.nonzero(sel)[0][:8]:
        print("col %s area %.1f cm2 centre %s fn %s corner dots %s\n    corners %s\n    normals %s" % (
            col[0, 0][:3].tolist(), area[i] * 1e4, np.round(c[i], 3).tolist(), np.round(fn[i], 2).tolist(), np.round(dots[i], 2).tolist(),
            np.round(pos[i], 3).tolist(), np.round(nor[i], 2).tolist()))
