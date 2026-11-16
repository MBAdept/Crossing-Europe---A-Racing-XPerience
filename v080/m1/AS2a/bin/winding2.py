"""AS2a: the triangles wound against their normals with their size. usage: winding2.py <mesh rel path>"""
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a/bin")
import ana2 as A

for s in A.surfaces(sys.argv[1]):
    v, i, n = s["v"], s["i"], s["n"]
    a, b, c = v[i[:, 0]], v[i[:, 1]], v[i[:, 2]]
    g = np.cross(b - a, c - a)
    ns = n[i[:, 0]] + n[i[:, 1]] + n[i[:, 2]]
    d = np.einsum("ij,ij->i", g, ns)
    bad = np.nonzero(d > 0)[0]
    for t in bad:
        area = 0.5 * np.linalg.norm(g[t])
        el = sorted([np.linalg.norm(b[t] - a[t]), np.linalg.norm(c[t] - b[t]), np.linalg.norm(a[t] - c[t])])
        h = 2 * area / el[2]
        gn = g[t] / max(np.linalg.norm(g[t]), 1e-12)
        nn = ns[t] / max(np.linalg.norm(ns[t]), 1e-12)
        col = A.hexcol(s["c"][i[t, 0]]) if s["c"] is not None else "-"
        print("%s  cen %+.3f %+.3f %+.3f  area %.2f cm2  edges %.1f/%.1f/%.1f mm  height %.2f mm  geo %s  nrm %s  %s" % (
            s["name"], *((a[t] + b[t] + c[t]) / 3), area * 1e4, el[0] * 1e3, el[1] * 1e3, el[2] * 1e3, h * 1e3,
            np.round(-gn, 2), np.round(nn, 2), col))
