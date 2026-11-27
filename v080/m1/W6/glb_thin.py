#!/usr/bin/env python3
"""W6 scratch: sliver triangles of a .glb (smallest altitude below a threshold) and the AABB."""
import json, struct, sys
exec(open(sys.argv[0].replace("glb_thin.py", "glb_wind.py")).read().split("for mi, m in enumerate")[0])
lim = float(sys.argv[2]) if len(sys.argv) > 2 else 0.01
lo = [1e9] * 3; hi = [-1e9] * 3; tot = 0
for mi, m in enumerate(g["meshes"]):
    for pi, p in enumerate(m["primitives"]):
        P = acc(p["attributes"]["POSITION"]); I = [x[0] for x in acc(p["indices"])]
        for q in P:
            for k in range(3): lo[k] = min(lo[k], q[k]); hi[k] = max(hi[k], q[k])
        mat = g["materials"][p["material"]]["name"] if "material" in p else "?"
        thin = []
        for t in range(0, len(I) - 2, 3):
            a, b, c = P[I[t]], P[I[t + 1]], P[I[t + 2]]
            u = [b[k] - a[k] for k in range(3)]; v = [c[k] - a[k] for k in range(3)]; w = [c[k] - b[k] for k in range(3)]
            area2 = sum(x * x for x in (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])) ** 0.5
            longest = max(sum(x * x for x in e) ** 0.5 for e in (u, v, w))
            if longest > 0 and area2 / longest < lim:
                thin.append((tuple(round((a[k] + b[k] + c[k]) / 3, 1) for k in range(3)), round(area2 / longest, 5), round(longest, 2)))
        tot += len(thin)
        if thin: print("mesh %d prim %d mat %s: %d slivers" % (mi, pi, mat, len(thin)), thin[:12])
print("AABB", [round(x, 1) for x in lo], [round(x, 1) for x in hi], "slivers", tot)
