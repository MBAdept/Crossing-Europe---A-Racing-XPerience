"""AS1R: numpy analysis of dumped vehicle meshes (bin/dump.gd -> out/dump). Scratch only."""
import json
import math
import os
import sys

import numpy as np

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1"
D = os.environ.get("DUMP", S + "/out/dump")
MAN = json.load(open(WT + "/assets/models/manifest.json"))
index = json.load(open(D + "/index.json"))


def model(mid):
    return MAN["models"][mid]


def _load(base, kind, cols):
    p = os.path.join(D, base + "." + kind + ".bin")
    if not os.path.exists(p):
        return None
    if kind == "i":
        return np.fromfile(p, dtype=np.int32).reshape(-1, 3)
    return np.fromfile(p, dtype=np.float32).reshape(-1, cols)


def surfaces(mesh):
    out = []
    for s in index[mesh]:
        b = s["base"]
        v = _load(b, "v", 3)
        i = _load(b, "i", 3)
        if i is None:
            i = np.arange(len(v)).reshape(-1, 3)
        out.append(dict(name=s["name"], v=v, n=_load(b, "n", 3), c=_load(b, "c", 4), uv=_load(b, "uv", 2),
                        uv2=_load(b, "uv2", 2), i=i))
    return out


def tri_geom(v, idx):
    a, b, c = v[idx[:, 0]], v[idx[:, 1]], v[idx[:, 2]]
    cr = -np.cross(b - a, c - a)   # Godot: clockwise = front
    area = 0.5 * np.linalg.norm(cr, axis=1)
    fn = cr / np.maximum(np.linalg.norm(cr, axis=1, keepdims=True), 1e-12)
    return area, fn, (a + b + c) / 3.0


def hexcol(c):
    return "#%02x%02x%02x/%d" % (int(round(c[0] * 255)), int(round(c[1] * 255)), int(round(c[2] * 255)), int(round(c[3] * 255)))


def wheel_dims(mesh):
    allv = np.concatenate([s["v"] for s in surfaces(mesh)])
    lo, hi = allv.min(axis=0), allv.max(axis=0)
    return (hi[0] - lo[0]) / 2.0


def clearance(mid, lod="lod0", steers=(-25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25), margin=0.0):
    """Body vertices inside (tyre radius + margin) of each wheel; per steering angle; reports colours."""
    m = model(mid)
    lv = [l for l in m["lods"] if l["name"] == lod][0]
    body = []
    for p in lv["parts"]:
        if "wheel" in p:
            continue
        off = np.array(p.get("pos", [0, 0, 0]), dtype=float)
        for s in surfaces(p["mesh"]):
            col = s["c"] if s["c"] is not None else np.zeros((len(s["v"]), 4))
            body.append((s["v"] + off, col, s["name"], s["uv2"]))
    res = []
    for p in lv["parts"]:
        if "wheel" not in p:
            continue
        R = p["wheel"]["radius"]
        hw = wheel_dims(p["mesh"])
        c = np.array(p["pos"], dtype=float)
        worst = (0, 0, 0.0, [])
        for steer in (steers if p["wheel"].get("steer") else (0,)):
            a = math.radians(steer)
            hits = []
            for (v, col, sname, uv2) in body:
                rel = v - c
                xl = rel[:, 0] * math.cos(a) - rel[:, 2] * math.sin(a)
                zl = rel[:, 0] * math.sin(a) + rel[:, 2] * math.cos(a)
                rr = np.hypot(rel[:, 1], zl)
                inside = (np.abs(xl) < hw + margin) & (rr < R + margin) & (rr > 0.72 * R)
                for k in np.nonzero(inside)[0]:
                    hits.append((R + margin - rr[k], sname, hexcol(col[k]), rel[k].round(3).tolist()))
            depth = max((h[0] for h in hits), default=0.0)
            if len(hits) > worst[1] or (len(hits) == worst[1] and depth > worst[2]):
                worst = (steer, len(hits), depth, sorted(hits, reverse=True)[:5])
        res.append((p["node"], R, hw, worst))
    return res


def lamp_table(mid, lod="lod0"):
    """Per lamp channel: area, mean weight, colour of the vpbr surfaces of a level."""
    m = model(mid)
    lv = [l for l in m["lods"] if l["name"] == lod][0]
    rows = {}
    for p in lv["parts"]:
        if "wheel" in p:
            continue
        for s in surfaces(p["mesh"]):
            if s["uv2"] is None:
                continue
            area, fn, cen = tri_geom(s["v"], s["i"])
            ch = np.floor(s["uv2"][s["i"][:, 0], 0])
            w = s["uv2"][s["i"][:, 0], 1]
            col = s["c"][s["i"][:, 0]]
            for k in np.unique(ch):
                if k < 0:
                    continue
                sel = ch == k
                ws = np.round(w[sel], 2)
                for wv in np.unique(ws):
                    ss = np.nonzero(sel)[0][ws == wv]
                    key = (int(k), float(wv), hexcol(col[ss[0]]))
                    back = float((area[ss] * np.clip(fn[ss, 2], 0, None)).sum())
                    e = rows.setdefault(key, [0, 0.0, 0.0])
                    e[0] += len(ss)
                    e[1] += float(area[ss].sum())
                    e[2] += back
    return rows


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "clear":
        for mid in sys.argv[2:]:
            for lod in ("lod0", "show") if mid.startswith("player") else ("lod0",):
                for node, R, hw, w in clearance(mid, lod):
                    print("%-16s %-4s %-18s R %.3f hw %.3f steer %+3d: %4d verts, %4.0f mm" % (mid, lod, node, R, hw, w[0], w[1], w[2] * 1000))
                    for h in w[3][:4]:
                        print("      %5.1f mm  %-6s %s  rel %s" % (h[0] * 1000, h[1], h[2], h[3]))
    elif what == "lamps":
        for mid in sys.argv[2:]:
            for l in model(mid)["lods"]:
                print("== %s %s" % (mid, l["name"]))
                for key, e in sorted(lamp_table(mid, l["name"]).items()):
                    print("   ch %2d w %.2f %s: %5d tris, area %7.1f cm2, from behind %7.1f cm2" % (key[0], key[1], key[2], e[0], e[1] * 1e4, e[2] * 1e4))
