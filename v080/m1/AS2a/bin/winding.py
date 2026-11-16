"""AS2a: where are the triangles wound against their normals? usage: winding.py <mesh rel path> (after dump2.gd)"""
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a/bin")
import ana2 as A

for s in A.surfaces(sys.argv[1]):
    v, i, n = s["v"], s["i"], s["n"]
    a, b, c = v[i[:, 0]], v[i[:, 1]], v[i[:, 2]]
    g = np.cross(b - a, c - a)
    ns = n[i[:, 0]] + n[i[:, 1]] + n[i[:, 2]]
    # Godot: front faces are clockwise -> the geometric normal of (a, b, c) points INTO the face; compare both ways
    d = np.einsum("ij,ij->i", g, ns)
    for name, bad in (("cross . n < 0", d < 0), ("cross . n > 0", d > 0)):
        k = int(bad.sum())
        print("%s %s: %d of %d" % (s["name"], name, k, len(i)))
        if 0 < k < 60:
            cen = (a + b + c)[bad] / 3.0
            for p in cen[:40]:
                print("    %+.3f %+.3f %+.3f" % tuple(p))
