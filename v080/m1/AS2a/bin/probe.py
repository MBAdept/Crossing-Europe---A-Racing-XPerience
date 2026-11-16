"""AS1R: list the triangles of a body mesh near a point (model space), grouped by colour."""
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R/bin")
import ana as A

mid, lod = sys.argv[1], sys.argv[2]
p = np.array([float(x) for x in sys.argv[3].split(",")])
rad = float(sys.argv[4]) if len(sys.argv) > 4 else 0.03
m = A.model(mid)
lv = [l for l in m["lods"] if l["name"] == lod][0]
for part in lv["parts"]:
    if "wheel" in part:
        continue
    off = np.array(part.get("pos", [0, 0, 0]), dtype=float)
    for s in A.surfaces(part["mesh"]):
        v = s["v"] + off
        i = s["i"]
        area, fn, cen = A.tri_geom(v, i)
        d = np.linalg.norm(cen - p, axis=1)
        sel = np.nonzero(d < rad)[0]
        groups = {}
        for t in sel:
            col = A.hexcol(s["c"][i[t, 0]]) if s["c"] is not None else "-"
            lamp = "" if s["uv2"] is None else " ch%.1f w%.2f" % tuple(s["uv2"][i[t, 0]])
            key = (s["name"], col + lamp)
            groups.setdefault(key, []).append(t)
        for key, ts in sorted(groups.items()):
            vv = v[i[ts]].reshape(-1, 3)
            nn = fn[ts].mean(axis=0)
            print("%-6s %-28s %4d tris  bbox %s .. %s  mean face normal %s  area %.1f cm2" % (
                key[0], key[1], len(ts), vv.min(axis=0).round(3), vv.max(axis=0).round(3), nn.round(2),
                area[ts].sum() * 1e4))
