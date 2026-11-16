"""KRITIK-2: numpy analysis of the dumped vehicle meshes (out/dump, written by tools/kritik/kritik_dump.gd).
Topology, winding, wheels, tyre clearance (spin + steer), interior parts against the outer hull, lamp areas, budgets."""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2/bin")
import klib as K

D = K.OUT + "/dump"
index = json.load(open(D + "/index.json"))

INTERIOR_HEX = ["#17181a", "#101112", "#2b2d31", "#3a3d43", "#141516", "#0f1011", "#8e9297", "#0b0b0c", "#1b1c1f",
                "#26272a", "#05070a", "#0c0c0d"]
INTERIOR_RGB = np.array([[int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)] for h in INTERIOR_HEX]) / 255.0


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
    out = {"name": index[mesh][s]["name"], "v": v, "n": load(b, "n", 3), "c": load(b, "c", 4), "uv": load(b, "uv", 2),
           "uv2": load(b, "uv2", 2), "i": load(b, "i", 3)}
    if out["i"] is None:
        out["i"] = np.arange(len(v)).reshape(-1, 3)
    return out


def mesh_all(mesh):
    return [surface(mesh, s) for s in range(len(index[mesh]))]


def topo(v, idx, q=1e-4):
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


def report_mesh(mesh):
    rows = []
    for s in mesh_all(mesh):
        v, n, idx = s["v"], s["n"], s["i"]
        area, fn, cen = tri_geom(v, idx)
        vn = (n[idx[:, 0]] + n[idx[:, 1]] + n[idx[:, 2]]) if n is not None else fn
        mism = int(((fn * vn).sum(axis=1) < 0).sum())
        degen = int((area < 1e-9).sum())
        opened, nonman = topo(v, idx)
        kc = np.round(cen / 5e-4).astype(np.int64)
        kn = np.round(fn * 4).astype(np.int64)
        same = np.concatenate([kc, kn], axis=1)
        _, cs = np.unique(same, axis=0, return_counts=True)
        dup = int((cs > 1).sum())
        rows.append((s["name"], len(idx), len(v), degen, mism, opened, nonman, dup, float(area.sum())))
    return rows


def wheel_report(mesh):
    allv = np.concatenate([s["v"] for s in mesh_all(mesh)])
    lo, hi = allv.min(axis=0), allv.max(axis=0)
    r = np.hypot(allv[:, 1], allv[:, 2])
    ring = allv[r > 0.97 * r.max()]
    A = np.c_[2 * ring[:, 1], 2 * ring[:, 2], np.ones(len(ring))]
    bb = (ring[:, 1] ** 2 + ring[:, 2] ** 2)
    sol = np.linalg.lstsq(A, bb, rcond=None)[0]
    cx, cy = sol[0], sol[1]
    rr = np.hypot(ring[:, 1] - cx, ring[:, 2] - cy)
    return {"half_width": float((hi[0] - lo[0]) / 2), "x_centre": float((hi[0] + lo[0]) / 2),
            "r_outer_min": float(rr.min()), "r_outer_max": float(rr.max()), "ring_centre": [float(cx), float(cy)],
            "r_max": float(r.max()), "x_lo": float(lo[0]), "x_hi": float(hi[0])}


def lod_entry(mid, lod):
    for l in K.model(mid)["lods"]:
        if l["name"] == lod:
            return l
    return None


def body_points(mid, lod="lod0", with_class=False):
    lv = lod_entry(mid, lod)
    pts, cls = [], []
    for p in lv["parts"]:
        if "wheel" in p:
            continue
        off = np.array(p.get("pos", [0, 0, 0]), dtype=float)
        for s in mesh_all(p["mesh"]):
            pts.append(s["v"] + off)
            cls.append(np.full(len(s["v"]), s["name"]))
    return (np.concatenate(pts), np.concatenate(cls)) if with_class else np.concatenate(pts)


def clearance(mid, lod="lod0", steers=(-25, -15, -7, 0, 7, 15, 25)):
    """Body vertices inside the tyre volume (radial band 0.72..1 R, |x| < half width), per wheel and steer angle.
    Returns per wheel: {steer: (count, depth_mm, example points)}."""
    lv = lod_entry(mid, lod)
    body = body_points(mid, lod)
    res = []
    for p in lv["parts"]:
        if "wheel" not in p:
            continue
        w = wheel_report(p["mesh"])
        R = p["wheel"]["radius"]
        hw = w["half_width"]
        c = np.array(p["pos"], dtype=float)
        out = {}
        for steer in (steers if p["wheel"].get("steer") else (0,)):
            a = math.radians(steer)
            rel = body - c
            xl = rel[:, 0] * math.cos(a) - rel[:, 2] * math.sin(a)
            zl = rel[:, 0] * math.sin(a) + rel[:, 2] * math.cos(a)
            yl = rel[:, 1]
            rr = np.hypot(yl, zl)
            inside = (np.abs(xl) < hw - 0.005) & (rr < R - 0.005) & (rr > 0.72 * R)
            cnt = int(inside.sum())
            depth = float((R - rr[inside]).max()) if cnt else 0.0
            ex = rel[inside]
            # where (angle on the tyre: 0 = top, +90 = front)
            ang = np.degrees(np.arctan2(-zl[inside], yl[inside])) if cnt else np.array([])
            out[steer] = (cnt, round(depth * 1000), (np.percentile(ang, [5, 50, 95]).round().tolist() if cnt else []),
                          ex[:3].round(3).tolist())
        res.append((p["node"], R, round(hw, 3), out, w))
    return res


def is_interior(c, uv):
    rgb = c[:, :3]
    d = np.abs(rgb[:, None, :] - INTERIOR_RGB[None, :, :]).max(axis=2).min(axis=1)
    rough = uv[:, 0]
    return (d < 0.006) & ((np.abs(rough - 0.82) < 0.02) | (np.abs(rough - 0.3) < 0.02)) & (c[:, 3] > 0.9)


def hull_equations(pts):
    """2D convex hull (monotone chain) as half-planes a x + b y + c <= 0 inside (unit normals)."""
    P = np.unique(np.round(pts, 5), axis=0)
    P = P[np.lexsort((P[:, 1], P[:, 0]))]
    if len(P) < 3:
        raise ValueError("degenerate")

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in P:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in P[::-1]:
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    h = np.array(lower[:-1] + upper[:-1])     # counter-clockwise
    eqs = []
    for i in range(len(h)):
        a, b = h[i], h[(i + 1) % len(h)]
        e = b - a
        n = np.array([e[1], -e[0]])               # outward normal of a ccw polygon
        n /= max(np.linalg.norm(n), 1e-12)
        eqs.append([n[0], n[1], -n @ a])
    return np.array(eqs)


def interior_report(mid, lod="lod0"):
    """Interior triangles (colour + roughness of carinterior.py) and how far their vertices stand outside the outer hull
    (convex hull of the outer vertices per 2 cm station, in x-y) - interior poking through the body or glass."""
    lv = lod_entry(mid, lod)
    p = [q for q in lv["parts"] if q["node"] == "body"][0]
    surfs = mesh_all(p["mesh"])
    inn_v, out_v, n_int = [], [], 0
    for s in surfs:
        v, idx = s["v"], s["i"]
        if s["name"] == "vpbr":
            flag = is_interior(s["c"], s["uv"])
            tri_int = flag[idx].all(axis=1)
            n_int += int(tri_int.sum())
            inn_v.append(v[np.unique(idx[tri_int])])
            out_v.append(v[np.unique(idx[~tri_int])])
        else:
            out_v.append(v)
    inn = np.concatenate(inn_v)
    outv = np.concatenate(out_v)
    worst = []
    zs = np.arange(inn[:, 2].min(), inn[:, 2].max() + 0.02, 0.02)
    for z in zs:
        sel_o = outv[np.abs(outv[:, 2] - z) < 0.03][:, :2]
        sel_i = inn[np.abs(inn[:, 2] - z) < 0.01]
        if len(sel_i) == 0 or len(sel_o) < 8:
            continue
        try:
            eq = hull_equations(sel_o)   # a x + b y + c <= 0 inside
        except Exception:
            continue
        dist = (sel_i[:, :2] @ eq[:, :2].T + eq[:, 2]).max(axis=1)
        k = int(dist.argmax())
        if dist[k] > 0.002:
            worst.append((float(dist[k]), float(z), sel_i[k].round(3).tolist()))
    worst.sort(reverse=True)
    return n_int, worst[:6]


def lamp_areas(mid, lod):
    """Projected lamp area per channel from behind (+Z faces) and from ahead (-Z faces), cm2."""
    lv = lod_entry(mid, lod)
    res = {}
    for p in lv["parts"]:
        if "wheel" in p:
            continue
        for s in mesh_all(p["mesh"]):
            if s["uv2"] is None or s["name"] != "vpbr":
                continue
            v, idx = s["v"], s["i"]
            area, fn, cen = tri_geom(v, idx)
            ch = np.floor(s["uv2"][idx[:, 0], 0])
            w = s["uv2"][idx[:, 0], 1]
            for c in np.unique(ch):
                if c < 0:
                    continue
                m = ch == c
                back = float((area[m] * np.clip(fn[m, 2], 0, None)).sum() * 1e4)
                front = float((area[m] * np.clip(-fn[m, 2], 0, None)).sum() * 1e4)
                side = float((area[m] * np.abs(fn[m, 0])).sum() * 1e4)
                res[int(c)] = (round(back), round(front), round(side), round(float(np.median(w[m])), 2))
    return res


if __name__ == "__main__":
    L = []
    mids = ["player/" + c for c in K.PLAYERS] + ["traffic/" + c for c in list(K.TRAFFIC_NEW) + list(K.TRAFFIC_OLD)]
    L.append("== Netze: Fläche | Dreiecke | Ecken | entartet | Normale gegen Wicklung | offene Kanten | nicht-mannigfaltig | doppelte Flächen | Fläche m²")
    for mid in mids:
        m = K.model(mid)
        files = set()
        for l in m["lods"]:
            for p in l["parts"]:
                files.add(p["mesh"])
        if "shadow" in m:
            files.add(m["shadow"]["mesh"])
        for f in sorted(files):
            if f not in index:
                continue
            for r in report_mesh(f):
                L.append(f"{f:40s} {r[0]:6s} {r[1]:6d} {r[2]:6d} {r[3]:4d} {r[4]:4d} {r[5]:6d} {r[6]:5d} {r[7]:5d} {r[8]:8.3f}")
    L.append("")
    L.append("== Räder (Netz im Radraum: Rollachse X)")
    for mid in mids:
        for p in K.wheel_parts(mid):
            if p["node"].endswith("0r"):
                w = wheel_report(p["mesh"])
                L.append(f"{mid:22s} {p['mesh']:34s} R(manifest) {p['wheel']['radius']:.3f} r_max {w['r_max']:.4f} halbe Breite {w['half_width']:.3f} "
                         f"x-Mitte {w['x_centre']:+.4f} Ring-Mitte {w['ring_centre'][0]*1000:+.1f}/{w['ring_centre'][1]*1000:+.1f} mm "
                         f"unrund {1000*(w['r_outer_max']-w['r_outer_min']):.1f} mm; Unterkante pos.y - R = {1000*(p['pos'][1]-p['wheel']['radius']):+.1f} mm")
    L.append("")
    L.append("== Freigang: Karosserie-Ecken (inkl. Innenraum) im Reifenvolumen; Lenkwinkel: Ecken / Tiefe mm / Lage auf dem Reifen (0° oben, +90° vorn) 5/50/95 %")
    for mid in mids:
        lods = ["lod0"] + (["show"] if mid.startswith("player/") else [])
        for lod in lods:
            for node, R, hw, out, w in clearance(mid, lod):
                parts = []
                for st in sorted(out):
                    cnt, dep, ang, ex = out[st]
                    parts.append(f"{st:+d}°: {cnt} / {dep} mm" + (f" / {ang}" if cnt else ""))
                L.append(f"{mid:22s} {lod:5s} {node:9s} R {R:.3f}: " + "; ".join(parts))
    L.append("")
    L.append("== Innenraum (Farben/Rauheit von carinterior.py): Dreiecke; Ecken außerhalb der äußeren Hülle (konvexe Hülle je 2-cm-Station in x-y): Abstand mm, z, Punkt")
    for mid in ["player/" + c for c in K.PLAYERS]:
        for lod in ("lod0", "show"):
            try:
                n_int, worst = interior_report(mid, lod)
                L.append(f"{mid:22s} {lod:5s} Innenraum {n_int} Dreiecke; " + ("; ".join(f"{d*1000:.0f} mm bei z {z:+.2f} {pt}" for d, z, pt in worst) if worst else "nichts außerhalb"))
            except Exception as e:
                L.append(f"{mid} {lod}: Fehler {e}")
    L.append("")
    L.append("== Lampenflächen je Kanal (cm², von hinten / von vorn / seitlich, Gewicht)")
    for mid in mids:
        for l in K.model(mid)["lods"]:
            la = lamp_areas(mid, l["name"])
            L.append(f"{mid:22s} {l['name']:5s} " + " ".join(f"k{c}:{v[0]}/{v[1]}/{v[2]}@{v[3]}" for c, v in sorted(la.items())))
    L.append("")
    L.append("== Budgets (Manifest) und Zeichenaufrufe (Flächen je Teil)")
    BUD = {"player": (55000, None, None, 120000, 3000), "traffic": (18000, 6000, 1200, None, None)}
    for mid in mids:
        m = K.model(mid)
        grp = mid.split("/")[0]
        b = BUD[grp]
        row = []
        for l in m["lods"]:
            calls = sum(len(p.get("classes", ["x"])) for p in l["parts"])
            lim = {"lod0": b[0], "lod1": b[1], "lod2": b[2], "show": b[3]}.get(l["name"])
            row.append(f"{l['name']} {l['tris']}/{lim} ({100*l['tris']/lim:.1f} %) Aufrufe {calls}")
        sh = m.get("shadow", {})
        row.append(f"Werfer {sh.get('tris')}" + (f"/{b[4]}" if b[4] else ""))
        L.append(f"{mid:22s} " + " · ".join(row) + f" · Bytes {m.get('bytes')}")
    txt = "\n".join(L)
    open(K.OUT + "/mesh_analysis.txt", "w").write(txt + "\n")
    print(txt)
