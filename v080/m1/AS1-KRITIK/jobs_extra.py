import json, sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
jobs = []
for car in ("limousine", "kompakt"):
    for k in range(0, 21):
        yaw = -2.0 + 0.2 * k
        jobs.append({"name": f"{car}_sweepref_{k:02d}", "set": "player/" + car, "cam": {"type": "game", "dist": 9.0, "ss": 3.0}, "msaa": 4, "yaw": yaw})
for car, sid in (("sedan", "traffic/sedan_silver"), ("hatch", "traffic/hatch_white"), ("wagon", "traffic/wagon_silver"), ("truck", "traffic/truck_white")):
    off = 8.25 if car == "truck" else 0.0
    for d, lod in ((30, "lod0"), (80, "lod1")):
        jobs.append({"name": f"{car}_g{d}_{lod}_dayind", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + off}, "lamp_a": [0, 0, 1, 0]})
        jobs.append({"name": f"{car}_g{d}_{lod}_dayoff", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + off}})
        jobs.append({"name": f"{car}_g{d}_{lod}_nightind", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + off}, "night": True, "lamp_a": [1, 0, 1, 0], "lamp_b": [1, 0, 0, 0]})
        jobs.append({"name": f"{car}_g{d}_{lod}_nighttailonly", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + off}, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
for car, sid in (("sedan", "traffic/sedan_red"), ("hatch", "traffic/hatch_red"), ("wagon", "traffic/wagon_green")):
    m = K.sprite_meta(sid)
    cw, ch = m["cell"]
    for lod in ("lod0", "lod1", "lod2"):
        jobs.append({"name": f"{car}_ortho_lampmap_{lod}", "set": sid, "lod": lod, "pivot": "rear", "mode": "lampmap", "msaa": 0,
                     "size": [cw * 4, ch * 4], "no_ground": True,
                     "cam": {"type": "ortho", "el": 0.0, "width_m": m["image_width_m"], "anchor": [0.5, 0.95], "pivot_z": m["object"]["length_m"] * 0.5}})
json.dump(jobs, open(K.S + "/jobs/x.json", "w"), indent=0)
print(len(jobs))
