"""Visible share of each lamp channel along the view from behind / ahead / the side (ray cast through the body mesh;
glass counts as see-through but is reported)."""
import sys
import numpy as np
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2/bin")
import mesh_analysis as M
import klib as K
from lamp_occlusion import body, ray_tri

REAR = {0, 1, 2, 3, 4, 7, 8, 9}
FRONT = {3, 4, 5, 6}

def run(mid, lod):
    surfs = body(mid, lod)
    A, B, C, nm, ch, op, ar, fz = [], [], [], [], [], [], [], []
    for s in surfs:
        v, idx = s["v"], s["i"]
        a, b, c = v[idx[:, 0]], v[idx[:, 1]], v[idx[:, 2]]
        A.append(a); B.append(b); C.append(c)
        nm.append(np.full(len(idx), s["name"]))
        ch.append(np.floor(s["uv2"][idx[:, 0], 0]) if (s["uv2"] is not None and s["name"] == "vpbr") else np.full(len(idx), -1.0))
        area, fn, cen = M.tri_geom(v, idx)
        ar.append(area); fz.append(fn)
    A = np.concatenate(A); B = np.concatenate(B); C = np.concatenate(C)
    nm = np.concatenate(nm); ch = np.concatenate(ch); ar = np.concatenate(ar); fz = np.concatenate(fz)
    opaque = nm != "glass"
    out = []
    for c in sorted(set(ch[ch >= 0].astype(int))):
        for vname, d in (("hinten", (0, 0.12, 1)), ("vorn", (0, 0.12, -1))):
            if (vname == "hinten" and c not in REAR) or (vname == "vorn" and c not in FRONT):
                continue
            dv = np.array(d, float); dv /= np.linalg.norm(dv)
            sel = np.nonzero((ch == c) & ((fz @ dv) > 0.05))[0]
            if len(sel) == 0:
                continue
            step = max(1, len(sel) // 150)
            tot, vis, thru_glass = 0.0, 0.0, 0.0
            for k in sel[::step]:
                w = ar[k] * float(fz[k] @ dv)
                o = (A[k] + B[k] + C[k]) / 3 + dv * 2e-4
                hit, t = ray_tri(o, dv, A, B, C)
                hit[k] = False
                hit_op = hit & opaque
                tot += w
                if not hit_op.any():
                    vis += w
                    if hit.any():
                        thru_glass += w
            out.append(f"k{c} {vname}: sichtbar {100*vis/tot:.0f} % (davon hinter Glas {100*thru_glass/max(tot,1e-9):.0f} %)")
    print(f"{mid:20s} {lod}: " + "; ".join(out))

if __name__ == "__main__":
    for c in K.PLAYERS:
        run("player/" + c, "lod0")
    for c in list(K.TRAFFIC_NEW) + list(K.TRAFFIC_OLD):
        for lod in ("lod0", "lod1", "lod2"):
            run("traffic/" + c, lod)
