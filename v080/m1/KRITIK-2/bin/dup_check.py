"""Coincident faces (same centroid within 0.5 mm, same facing) whose material differs = z-fighting candidates."""
import sys
import numpy as np
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2/bin")
import mesh_analysis as M
import klib as K
for mid in ["player/" + c for c in K.PLAYERS] + ["traffic/" + c for c in K.TRAFFIC_NEW]:
    for l in K.model(mid)["lods"]:
        p = [q for q in l["parts"] if q["node"] == "body"][0]
        for s in M.mesh_all(p["mesh"]):
            if s["name"] != "vpbr":
                continue
            v, idx = s["v"], s["i"]
            area, fn, cen = M.tri_geom(v, idx)
            col = np.round(s["c"][idx[:, 0]] * 255).astype(int)
            ch = np.floor(s["uv2"][idx[:, 0], 0]).astype(int) if s["uv2"] is not None else np.zeros(len(idx), int)
            key = np.concatenate([np.round(cen / 5e-4).astype(np.int64), np.round(fn * 4).astype(np.int64)], axis=1)
            _, inv, cnt = np.unique(key, axis=0, return_inverse=True, return_counts=True)
            inv = inv.reshape(-1)
            bad = 0
            bad_area = 0.0
            ex = None
            for g in np.nonzero(cnt > 1)[0]:
                mem = np.nonzero(inv == g)[0]
                sig = {(tuple(col[m]), int(ch[m])) for m in mem}
                if len(sig) > 1:
                    bad += 1
                    bad_area += float(area[mem].max())
                    if ex is None:
                        ex = (cen[mem[0]].round(3).tolist(), sorted(sig))
            print(f"{mid:20s} {l['name']:5s} Doppelflächen {int((cnt > 1).sum()):4d}, davon mit anderer Farbe/Kanal {bad:3d} ({bad_area*1e4:.1f} cm²)" + (f" z.B. {ex}" if ex else ""))
