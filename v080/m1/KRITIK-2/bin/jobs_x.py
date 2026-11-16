"""Batch x: flake shimmer at race distance, night LOD swaps, extra checks."""
import json, sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2/bin")
import klib as K
X = []
for car in K.PLAYERS:
    sid = "player/" + car
    for k in range(7):
        yaw = -0.6 + 0.2 * k
        X.append({"name": f"{car}_sweep_{k}", "set": sid, "cam": {"type": "game", "dist": 8.0}, "yaw": yaw})
        X.append({"name": f"{car}_sweepnf_{k}", "set": sid, "cam": {"type": "game", "dist": 8.0}, "yaw": yaw,
                  "params": [["vpbr", "flake_strength", 0.0]]})
    X.append({"name": f"{car}_ref_ss3", "set": sid, "cam": {"type": "game", "dist": 8.0, "ss": 3.0}, "msaa": 4})
for car, sets in K.TRAFFIC_NEW.items():
    sid = "traffic/" + sets[0]
    for d, lods in ((40, ("lod0", "lod1")), (120, ("lod1", "lod2"))):
        for lod in lods:
            X.append({"name": f"{car}_g{d}_{lod}_nightlod", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d},
                      "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
    # lane-side view at the swap distance (the car beside the camera axis, as in traffic)
    for lod in ("lod0", "lod1"):
        X.append({"name": f"{car}_g40_{lod}_lane", "set": sid, "lod": lod, "cam": {"type": "game", "dist": 40, "lane": -3.5}})
json.dump(X, open(K.JOBS + "/x.json", "w"), indent=0)
print(len(X), "x jobs")
# sections through the front and rear wheel centre (y-z plane), seen from outside: the arch against the tyre
for car in K.PLAYERS + ["traffic_sports"]:
    if car == "traffic_sports":
        sid, mid = "traffic/sports_red", "traffic/sports"
    else:
        sid, mid = "player/" + car, "player/" + car
    for p in K.wheel_parts(mid):
        if p["node"] not in ("wheel_0r", "wheel_1r"):
            continue
        x, y, z = p["pos"]
        R = p["wheel"]["radius"]
        tag = "f" if p["node"] == "wheel_0r" else "r"
        box = [x - 0.3, 0.0, z - R - 0.35, x + 0.3, 2 * R + 0.35, z + R + 0.35]
        X.append({"name": f"{car}_secw{tag}_mid", "set": sid, "mode": "section_col", "section": [1, 0, 0, x],
                  "cam": {"type": "orbit", "yaw": 90, "el": 0, "aabb": box}, "size": [960, 600], "msaa": 4})
        X.append({"name": f"{car}_secw{tag}_out", "set": sid, "mode": "section_col", "section": [1, 0, 0, x + 0.08],
                  "cam": {"type": "orbit", "yaw": 90, "el": 0, "aabb": box}, "size": [960, 600], "msaa": 4})
        X.append({"name": f"{car}_sidew{tag}", "set": sid, "cam": {"type": "orbit", "yaw": 90, "el": 0, "aabb": box}, "size": [960, 600], "msaa": 4})
        X.append({"name": f"{car}_sidew{tag}_clay", "set": sid, "mode": "clay", "cam": {"type": "orbit", "yaw": 90, "el": 0, "aabb": box}, "size": [960, 600], "msaa": 4})
json.dump(X, open(K.JOBS + "/x.json", "w"), indent=0)
print(len(X), "x jobs (with wheel sections)")
# see-through check: wheels and arches against a bright green ground (holes show green)
for car in K.PLAYERS:
    sid, mid = "player/" + car, "player/" + car
    for vn, yaw, el, part in (("wheelf", 112, 6, "wheel_fr"), ("wheel", 68, 6, "wheel_rr"), ("wheelf_low", 100, -4, "wheel_fr")):
        X.append({"name": f"{car}_green_{vn}", "set": sid, "cam": {"type": "orbit", "yaw": yaw, "el": el, "aabb": K.part_aabb(mid, part)},
                  "size": [960, 600], "msaa": 4, "ground": [0.0, 0.9, 0.0], "contact": False})
for car, sets in K.TRAFFIC_NEW.items():
    sid, mid = "traffic/" + sets[0], "traffic/" + car
    X.append({"name": f"{car}_green_wheel", "set": sid, "cam": {"type": "orbit", "yaw": 68, "el": 6, "aabb": K.part_aabb(mid, "wheel_rr")},
              "size": [960, 600], "msaa": 4, "ground": [0.0, 0.9, 0.0], "contact": False})
json.dump(X, open(K.JOBS + "/x.json", "w"), indent=0)
print(len(X), "x jobs (with green ground)")
# C-pillar base / rear quarter from the chase direction (black wedges, folds)
for car in K.PLAYERS:
    sid = "player/" + car
    m = K.model(sid)
    x0, y0, z0, x1, h, z1 = m["aabb"]
    box = [0.25, h * 0.45, z1 * 0.25, 1.0, h * 1.0, z1 * 0.85]
    for md in ("shaded", "clay", "wire", "check_cb"):
        X.append({"name": f"{car}_cpillar_{md}", "set": sid, "mode": md, "cam": {"type": "orbit", "yaw": 25, "el": 24, "aabb": box}, "size": [960, 600], "msaa": 4})
json.dump(X, open(K.JOBS + "/x.json", "w"), indent=0)
print(len(X), "x jobs (with C-pillar)")
