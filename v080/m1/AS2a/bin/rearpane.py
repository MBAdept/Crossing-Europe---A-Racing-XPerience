"""AS2a: faces of the rear greenhouse of a dumped traffic car at one level - normal, centre, colour.
usage: rearpane.py <model> <lod> <ymin> (Godot y = height; rear = +z)"""
import sys

import numpy as np

sys.argv, args = sys.argv[:1], sys.argv[1:]
import ana2 as A  # noqa: E402

mid, lod, ymin = args[0], args[1], float(args[2])
m = A.model(mid)
lv = [l for l in m["lods"] if l["name"] == lod][0]
for p in lv["parts"]:
    if "wheel" in p:
        continue
    for s in A.surfaces(p["mesh"]):
        v, i = s["v"], s["i"]
        a, b, c = v[i[:, 0]], v[i[:, 1]], v[i[:, 2]]
        cen = (a + b + c) / 3.0
        n = np.cross(b - a, c - a)
        ln = np.linalg.norm(n, axis=1) + 1e-12
        n = -n / ln[:, None]
        sel = (cen[:, 1] > ymin) & (cen[:, 2] > 0.3) & (n[:, 2] > 0.05)
        col = s["c"][i[:, 0]]
        for k in np.nonzero(sel)[0]:
            print("%s c(%+.2f %.2f %+.2f) n(%+.2f %+.2f %+.2f) %s area %.0f cm2" % (
                s["name"], cen[k, 0], cen[k, 1], cen[k, 2], n[k, 0], n[k, 1], n[k, 2], A.hexcol(col[k]), 0.5 * ln[k] * 1e4))
