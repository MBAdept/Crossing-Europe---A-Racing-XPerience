"""AS2a: what lies in the front intake window of a dumped car (front-facing triangles, depth layers).
usage: intake.py <model> <x0> <x1> <y0> <y1> [lod]"""
import sys

import numpy as np

sys.argv, args = sys.argv[:1], sys.argv[1:]
import ana2 as A  # noqa: E402

mid = args[0]
x0, x1, y0, y1 = (float(v) for v in args[1:5])
lod = args[5] if len(args) > 5 else "lod0"
m = A.model(mid)
lv = [l for l in m["lods"] if l["name"] == lod][0]
rows = []
for p in lv["parts"]:
    if "wheel" in p:
        continue
    for s in A.surfaces(p["mesh"]):
        v, i = s["v"], s["i"]
        a, b, c = v[i[:, 0]], v[i[:, 1]], v[i[:, 2]]
        cen = (a + b + c) / 3.0
        n = np.cross(b - a, c - a)
        ln = np.linalg.norm(n, axis=1) + 1e-12
        n = -n / ln[:, None]            # Godot: clockwise = front
        area = 0.5 * ln
        sel = (cen[:, 0] > x0) & (cen[:, 0] < x1) & (cen[:, 1] > y0) & (cen[:, 1] < y1) & (n[:, 2] < -0.3)
        col = s["c"][i[:, 0]] if s["c"] is not None else np.zeros((len(i), 4))
        for k in np.nonzero(sel)[0]:
            rows.append((cen[k, 2], area[k], s["name"], A.hexcol(col[k]), round(float(col[k, 3]), 3)))
rows.sort()
zs = np.array([r[0] for r in rows])
print("%d front-facing triangles in the window, z from %.3f to %.3f" % (len(rows), zs.min(), zs.max()))
# depth layers: histogram of z (1 cm bins) with area, surface class and the colours found there
bins = {}
for z, ar, sn, hx, pa in rows:
    k = round(z, 2)
    e = bins.setdefault(k, [0.0, set()])
    e[0] += ar
    e[1].add("%s %s a%.2f" % (sn, hx, pa))
for k in sorted(bins):
    print("z %+.2f  %7.1f cm2  %s" % (k, bins[k][0] * 1e4, ", ".join(sorted(bins[k][1]))[:150]))
