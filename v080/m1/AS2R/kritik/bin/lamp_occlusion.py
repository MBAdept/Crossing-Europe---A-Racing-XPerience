"""For a lamp channel: where its triangles lie and what covers them as seen along a view direction (ray cast)."""
import sys
import numpy as np
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import mesh_analysis as M
import klib as K

def body(mid, lod):
    lv = M.lod_entry(mid, lod)
    p = [q for q in lv["parts"] if q["node"] == "body"][0]
    return M.mesh_all(p["mesh"])

def ray_tri(o, d, A, B, C):
    # Moller-Trumbore, many triangles, one ray
    e1 = B - A; e2 = C - A
    p = np.cross(d, e2)
    det = (e1 * p).sum(1)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
    t_ = o - A
    u = (t_ * p).sum(1) * inv
    q = np.cross(t_, e1)
    v = (d * q).sum(1) * inv
    t = (e2 * q).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-4)
    return hit, t

def run(mid, lod, ch, view):
    surfs = body(mid, lod)
    allA, allB, allC, info = [], [], [], []
    for s in surfs:
        v, idx = s["v"], s["i"]
        allA.append(v[idx[:, 0]]); allB.append(v[idx[:, 1]]); allC.append(v[idx[:, 2]])
        if s["uv2"] is not None:
            chs = np.floor(s["uv2"][idx[:, 0], 0])
        else:
            chs = np.full(len(idx), -1.0)
        col = s["c"][idx[:, 0], :3] if s["c"] is not None else np.zeros((len(idx), 3))
        rough = s["uv"][idx[:, 0], 0] if s["uv"] is not None else np.zeros(len(idx))
        code = s["c"][idx[:, 0], 3] if s["c"] is not None else np.ones(len(idx))
        for k in range(len(idx)):
            pass
        info.append((s["name"], chs, col, rough, code))
    A = np.concatenate(allA); B = np.concatenate(allB); C = np.concatenate(allC)
    names = np.concatenate([np.full(len(i[1]), i[0]) for i in info])
    chs = np.concatenate([i[1] for i in info]); col = np.concatenate([i[2] for i in info])
    rough = np.concatenate([i[3] for i in info]); code = np.concatenate([i[4] for i in info])
    sel = np.nonzero(chs == ch)[0]
    if len(sel) == 0:
        print(mid, lod, "channel", ch, ": no triangles"); return
    cen = (A[sel] + B[sel] + C[sel]) / 3
    print(f"{mid} {lod} channel {ch}: {len(sel)} triangles, centroid range x {cen[:,0].min():.3f}..{cen[:,0].max():.3f} y {cen[:,1].min():.3f}..{cen[:,1].max():.3f} z {cen[:,2].min():.3f}..{cen[:,2].max():.3f}")
    d = np.array(view, float); d /= np.linalg.norm(d)
    cover = {}
    visible = 0
    for k in sel[:: max(1, len(sel) // 60)]:
        o = (A[k] + B[k] + C[k]) / 3 + d * 1e-4
        hit, t = ray_tri(o, d, A, B, C)
        hit[k] = False
        if not hit.any():
            visible += 1
            continue
        j = np.nonzero(hit)[0][np.argmin(t[hit])]
        key = (names[j], int(chs[j]), tuple((col[j] * 255).round().astype(int)), round(float(rough[j]), 2), round(float(code[j]), 2), round(float(t[j]) * 1000))
        cover[key] = cover.get(key, 0) + 1
    print("   sampled", len(sel[:: max(1, len(sel) // 60)]), "visible along", view, ":", visible)
    for k, n in sorted(cover.items(), key=lambda x: -x[1])[:6]:
        print("   covered by", k[0], "channel", k[1], "colour", k[2], "rough", k[3], "code", k[4], "at", k[5], "mm:", n)

if __name__ == "__main__":
    for mid, lod, ch, view in [("player/kombi", "lod0", 7, (0, 0.1, 1)), ("player/limousine", "lod0", 7, (0, 0.1, 1)),
                               ("player/kompakt", "lod0", 7, (0, 0.1, 1)), ("traffic/suv", "lod0", 7, (0, 0.1, 1)),
                               ("traffic/van", "lod0", 7, (0, 0.1, 1)), ("traffic/sports", "lod0", 7, (0, 0.1, 1)),
                               ("traffic/sedan", "lod0", 7, (0, 0.1, 1))]:
        run(mid, lod, ch, view)
