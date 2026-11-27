#!/usr/bin/env python3
"""W6 scratch: triangles of a .glb whose winding faces against the mean of their vertex normals (like
inspect_models.gd _winding). glb_wind.py <model.glb>: per mesh/primitive the count and centroids + face size."""
import json, struct, sys
d = open(sys.argv[1], "rb").read()
jl = struct.unpack_from("<I", d, 12)[0]
g = json.loads(d[20:20 + jl]); off = 20 + jl
bl = struct.unpack_from("<I", d, off)[0]; binc = d[off + 8: off + 8 + bl]
def acc(i):
    a = g["accessors"][i]; bv = g["bufferViews"][a["bufferView"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[a["componentType"]]
    sz = struct.calcsize(fmt); st = bv.get("byteStride", sz * n)
    return [struct.unpack_from("<%d%s" % (n, fmt), binc, o + k * st) for k in range(a["count"])]
for mi, m in enumerate(g["meshes"]):
    for pi, p in enumerate(m["primitives"]):
        P = acc(p["attributes"]["POSITION"]); N = acc(p["attributes"]["NORMAL"]); I = [x[0] for x in acc(p["indices"])]
        mat = g["materials"][p["material"]]["name"] if "material" in p else "?"
        bad = []
        for t in range(0, len(I) - 2, 3):
            a, b, c = P[I[t]], P[I[t + 1]], P[I[t + 2]]
            u = [b[k] - a[k] for k in range(3)]; v = [c[k] - a[k] for k in range(3)]
            gn = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            if sum(x * x for x in gn) <= 1e-16: continue
            nn = [N[I[t]][k] + N[I[t + 1]][k] + N[I[t + 2]][k] for k in range(3)]
            if sum(gn[k] * nn[k] for k in range(3)) < 0:
                cen = tuple(round((a[k] + b[k] + c[k]) / 3, 2) for k in range(3))
                bad.append((cen, round(0.5 * sum(x * x for x in gn) ** 0.5, 4), tuple(round(x, 2) for x in nn)))
        if bad:
            print("mesh %d %s prim %d mat %s: %d against" % (mi, m.get("name"), pi, mat, len(bad)))
            for b in bad: print("   ", b)
