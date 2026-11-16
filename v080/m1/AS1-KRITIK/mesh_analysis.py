"""AS1-KRITIK: numpy analysis of the dumped vehicle meshes (out/dump, written by tools/kritik/kritik_dump.gd)."""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K

D = K.OUT + "/dump"
index = json.load(open(D + "/index.json"))


def load(base, kind, cols):
    p = os.path.join(D, base + "." + kind + ".bin")
    if not os.path.exists(p):
        return None
    if kind == "i":
        return np.fromfile(p, dtype=np.int32).reshape(-1, 3)
    return np.fromfile(p, dtype=np.float32).reshape(-1, cols)


def surface(mesh, s):
    b = index[mesh][s]["base"]
    v = load(b, "v", 3)
    n = load(b, "n", 3)
    c = load(b, "c", 4)
    uv = load(b, "uv", 2)
    uv2 = load(b, "uv2", 2)
    i = load(b, "i", 3)
    if i is None:
        i = np.arange(len(v)).reshape(-1, 3)
    return {"name": index[mesh][s]["name"], "v": v, "n": n, "c": c, "uv": uv, "uv2": uv2, "i": i}


def mesh_all(mesh):
    return [surface(mesh, s) for s in range(len(index[mesh]))]


def topo(v, idx, q=1e-4):
    """Weld by position (q m), count open (1 face) and non-manifold (>2) edges."""
    key = np.round(v / q).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    f = inv[idx]
    e = np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]])
    e = np.sort(e, axis=1)
    e = e[e[:, 0] != e[:, 1]]
    _, cnt = np.unique(e, axis=0, return_counts=True)
    return int((cnt == 1).sum()), int((cnt > 2).sum())


def tri_geom(v, idx):
    a, b, c = v[idx[:, 0]], v[idx[:, 1]], v[idx[:, 2]]
    cr = -np.cross(b - a, c - a)   # Godot: clockwise triangles face the viewer
    area = 0.5 * np.linalg.norm(cr, axis=1)
    fn = cr / np.maximum(np.linalg.norm(cr, axis=1, keepdims=True), 1e-12)
    cen = (a + b + c) / 3.0
    return area, fn, cen


def report_mesh(mesh, out):
    rows = []
    for s in mesh_all(mesh):
        v, n, idx = s["v"], s["n"], s["i"]
        area, fn, cen = tri_geom(v, idx)
        vn = (n[idx[:, 0]] + n[idx[:, 1]] + n[idx[:, 2]]) if n is not None else fn
        mism = int(((fn * vn).sum(axis=1) < 0).sum())
        degen = int((area < 1e-9).sum())
        opened, nonman = topo(v, idx)
        # coincident faces (z-fighting candidates): same centroid (0.5 mm) and same facing; back-to-back pairs
        kc = np.round(cen / 5e-4).astype(np.int64)
        kn = np.round(fn * 4).astype(np.int64)
        same = np.concatenate([kc, kn], axis=1)
        _, cs = np.unique(same, axis=0, return_counts=True)
        dup = int((cs > 1).sum())
        opp = np.concatenate([kc, -kn], axis=1)
        sset = {tuple(r) for r in same[area > 1e-7]}
        b2b = int(sum(1 for r in opp[area > 1e-7] if tuple(r) in sset))
        rows.append((s["name"], len(idx), len(v), degen, mism, opened, nonman, dup, b2b, float(area.sum())))
    out.append((mesh, rows))
    return rows


def wheel_report(mesh):
    allv = np.concatenate([s["v"] for s in mesh_all(mesh)])
    lo, hi = allv.min(axis=0), allv.max(axis=0)
    r = np.hypot(allv[:, 1], allv[:, 2])
    ring = allv[r > 0.97 * r.max()]
    # least-squares circle through the outermost vertices (tread): centre = spin wobble, radii = out-of-round
    A = np.c_[2 * ring[:, 1], 2 * ring[:, 2], np.ones(len(ring))]
    bb = (ring[:, 1] ** 2 + ring[:, 2] ** 2)
    sol = np.linalg.lstsq(A, bb, rcond=None)[0]
    cx, cy = sol[0], sol[1]
    rr = np.hypot(ring[:, 1] - cx, ring[:, 2] - cy)
    rmax = np.array([rr.min(), rr.max()])
    return {"bounds": [lo.round(4).tolist(), hi.round(4).tolist()], "half_width": float((hi[0] - lo[0]) / 2),
            "x_centre": float((hi[0] + lo[0]) / 2), "yz_centre_box": [float((hi[1] + lo[1]) / 2), float((hi[2] + lo[2]) / 2)],
            "r_outer_min": float(rmax[0]), "r_outer_max": float(rmax[1]), "ring_centre": [float(cx), float(cy)]}


def clearance(model_id, lod="lod0"):
    """Body vertices inside the swept tyre volume (spinning; front wheels also steered to +-25 deg)."""
    m = K.model(model_id)
    lv = [l for l in m["lods"] if l["name"] == lod][0]
    body_parts = [p for p in lv["parts"] if "wheel" not in p]
    res = []
    bodies = []
    for p in body_parts:
        mesh = p["mesh"]
        vs = np.concatenate([s["v"] for s in mesh_all(mesh)])
        off = np.array(p.get("pos", [0, 0, 0]), dtype=float)
        bodies.append(vs + off)
    body = np.concatenate(bodies)
    for p in lv["parts"]:
        if "wheel" not in p:
            continue
        w = wheel_report(p["mesh"])
        R = p["wheel"]["radius"]
        hw = w["half_width"]
        c = np.array(p["pos"], dtype=float)
        worst = None
        first = None
        for steer in ((-25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25) if p["wheel"].get("steer") else (0,)):
            a = math.radians(steer)
            rel = body - c
            # into the steered wheel frame (yaw about Y)
            xl = rel[:, 0] * math.cos(a) - rel[:, 2] * math.sin(a)
            zl = rel[:, 0] * math.sin(a) + rel[:, 2] * math.cos(a)
            yl = rel[:, 1]
            rr = np.hypot(yl, zl)
            inside = (np.abs(xl) < hw - 0.005) & (rr < R - 0.005) & (rr > 0.72 * R)
            cnt = int(inside.sum())
            depth = float((R - rr[inside]).max()) if cnt else 0.0
            if cnt and (first is None or abs(steer) < abs(first)):
                first = steer
            if worst is None or cnt > worst[1]:
                worst = (steer, cnt, depth, rel[inside][:6].round(3).tolist())
        res.append((p["node"], R, round(hw, 3), worst + (first,)))
    return res


if __name__ == "__main__":
    out = []
    lines = []
    for mesh in sorted(index):
        report_mesh(mesh, out)
    lines.append("Netze: Fläche | Dreiecke | Ecken | entartet | Normale gegen Wicklung | offene Kanten | nicht-mannigfaltig | doppelte Flächen | Rücken-an-Rücken-Paare | Fläche m²")
    for mesh, rows in out:
        for r in rows:
            lines.append(f"{mesh:42s} {r[0]:6s} {r[1]:6d} {r[2]:6d} {r[3]:4d} {r[4]:4d} {r[5]:6d} {r[6]:5d} {r[7]:5d} {r[8]:6d} {r[9]:8.3f}")
    lines.append("")
    lines.append("Räder (Netz im Radraum: Rollachse X):")
    for mesh in sorted(index):
        if "wheel" in mesh.split("/")[-1]:
            w = wheel_report(mesh)
            lines.append(f"{mesh:42s} halbe Breite {w['half_width']:.3f}  x-Mitte {w['x_centre']:+.4f}  yz-Mitte (Box) {w['yz_centre_box'][0]:+.4f} {w['yz_centre_box'][1]:+.4f}  "
                         f"Außenradius {w['r_outer_min']:.4f}..{w['r_outer_max']:.4f}  Ringmitte {w['ring_centre'][0]:+.4f} {w['ring_centre'][1]:+.4f}")
    lines.append("")
    lines.append("Freigang: Karosserie-Ecken im Reifen-Volumen (drehend; Vorderräder auch bei ±25° Lenkung):")
    for mid in ("player/limousine", "player/kompakt", "traffic/sedan", "traffic/hatch", "traffic/wagon", "traffic/truck"):
        for lod in ("lod0",) + (("show",) if mid.startswith("player") else ()):
            for node, R, hw, worst in clearance(mid, lod):
                lines.append(f"{mid:18s} {lod:5s} {node:18s} R {R:.3f} hb {hw:.3f}: schlimmster Lenkwinkel {worst[0]:+3d}°: {worst[1]:5d} Ecken, bis {worst[2]*1000:.0f} mm tief; erster Kontakt bei {worst[4]}°; Beispiele (relativ zur Radmitte) {worst[3][:3]}")
    txt = "\n".join(lines)
    open(K.OUT + "/mesh_analysis.txt", "w").write(txt + "\n")
    print(txt)
