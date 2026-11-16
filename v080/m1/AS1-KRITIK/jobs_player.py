"""Job list of batch 'p': player cars (game camera at 9 m, yaw sweep, review close-ups, diagnostics)."""
import json
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K

jobs = []
SUN_BACK = [0.35, 0.6, -1.0]       # sun ahead of the car: the rear the player looks at is in shade
for car in ("limousine", "kompakt"):
    sid = "player/" + car
    mid = "player/" + car
    g = {"type": "game", "dist": 9.0}
    # game camera: what the player sees all the time
    jobs.append({"name": f"{car}_g9_day", "set": sid, "cam": g})
    jobs.append({"name": f"{car}_g9_day_backlit", "set": sid, "cam": g, "sun": SUN_BACK})
    jobs.append({"name": f"{car}_g9_day_ss", "set": sid, "cam": dict(g, ss=1.65), "msaa": 4})
    jobs.append({"name": f"{car}_g9_day_brake_ind", "set": sid, "cam": g, "lamp_a": [0, 1, 1, 0]})
    jobs.append({"name": f"{car}_g9_night_tail", "set": sid, "cam": g, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
    jobs.append({"name": f"{car}_g9_night_brake_ind", "set": sid, "cam": g, "night": True, "lamp_a": [1, 1, 1, 0], "lamp_b": [1, 0, 0, 0]})
    jobs.append({"name": f"{car}_g9_night_reverse", "set": sid, "cam": g, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 1, 0, 0]})
    jobs.append({"name": f"{car}_g9_low", "set": sid, "cam": dict(g, ss=0.75), "msaa": 0})
    jobs.append({"name": f"{car}_g9_msaa0", "set": sid, "cam": g, "msaa": 0})
    for yaw in (-20, -10, 10, 20):
        jobs.append({"name": f"{car}_g9_yaw{yaw:+d}", "set": sid, "cam": g, "yaw": yaw})
        jobs.append({"name": f"{car}_g9_yaw{yaw:+d}_ss", "set": sid, "cam": dict(g, ss=1.65), "msaa": 4, "yaw": yaw})
    # yaw sweep for the motion check (small steps; shimmer of fine detail)
    for k in range(0, 21):
        yaw = -2.0 + 0.2 * k
        jobs.append({"name": f"{car}_sweep_{k:02d}", "set": sid, "cam": g, "yaw": yaw})
    # showroom camera (the Cycles showroom sprite: 142 deg, 56 mm lens, 11 deg)
    # review close-ups
    big = [960, 600]
    views = [
        ("rear34", 32, 13, None), ("rear", 0, 9, None), ("side", 90, 4, None), ("front34", 148, 11, None),
        ("rearclose", 18, 10, "rear"), ("frontclose", 162, 8, "front"), ("wheel", 68, 6, "wheel_rr"),
        ("wheelf", 112, 6, "wheel_fr"), ("cabin", 10, 20, "cabin"), ("taillamp", 28, 12, "taillamp"),
        ("headlamp", 152, 10, "headlamp"), ("top", 0, 38, None), ("front", 180, 6, None),
        ("under", 35, -8, None),
    ]
    for (vn, yaw, el, part) in views:
        cam = {"type": "orbit", "yaw": yaw, "el": el}
        if part:
            cam["aabb"] = K.part_aabb(mid, part)
        for lod in ("lod0", "show"):
            if lod == "show" and vn not in ("rear34", "front34", "rearclose", "frontclose", "wheel", "taillamp", "headlamp", "side"):
                continue
            jobs.append({"name": f"{car}_{lod}_{vn}", "set": sid, "lod": lod, "cam": cam, "size": big, "msaa": 4,
                         "no_ground": vn == "under"})
        if vn in ("rear34", "front34", "side", "rearclose", "frontclose", "top", "wheel"):
            jobs.append({"name": f"{car}_clay_{vn}", "set": sid, "mode": "clay", "cam": cam, "size": big, "msaa": 4})
        if vn in ("rear34", "front34", "rearclose", "frontclose"):
            jobs.append({"name": f"{car}_facets_{vn}", "set": sid, "mode": "facets", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_wire_{vn}", "set": sid, "mode": "wire", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_normals_{vn}", "set": sid, "mode": "normals", "cam": cam, "size": big, "msaa": 4})
        if vn in ("rear34", "front34", "wheel", "under", "rearclose", "side"):
            jobs.append({"name": f"{car}_check_{vn}", "set": sid, "mode": "check", "cam": cam, "size": big, "msaa": 4, "no_ground": vn == "under"})
            jobs.append({"name": f"{car}_checkng_{vn}", "set": sid, "mode": "check_noglass", "cam": cam, "size": big, "msaa": 4, "no_ground": vn == "under"})
            jobs.append({"name": f"{car}_checkcb_{vn}", "set": sid, "mode": "check_cb", "cam": cam, "size": big, "msaa": 4, "no_ground": vn == "under"})
        if vn in ("rear34", "front34", "cabin"):
            jobs.append({"name": f"{car}_clayng_{vn}", "set": sid, "mode": "clay_noglass", "cam": cam, "size": big, "msaa": 4})
        if vn in ("rearclose", "frontclose"):
            jobs.append({"name": f"{car}_lampmap_{vn}", "set": sid, "mode": "lampmap", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_caster_{vn}", "set": sid, "mode": "caster", "cam": cam, "size": big, "msaa": 4})
    # night close-ups of each lamp state (rear and front)
    for (ln, la, lb, part, yaw, el) in [
        ("tail", [1, 0, 0, 0], [1, 0, 0, 0], "rear", 18, 10), ("brake", [1, 1, 0, 0], [1, 0, 0, 0], "rear", 18, 10),
        ("indl", [1, 0, 1, 0], [1, 0, 0, 0], "rear", 18, 10), ("indr", [1, 0, 0, 1], [1, 0, 0, 0], "rear", 18, 10),
        ("reverse", [1, 0, 0, 0], [1, 1, 0, 0], "rear", 18, 10), ("head", [1, 0, 0, 0], [1, 0, 0, 0], "front", 162, 8),
        ("headind", [1, 0, 1, 1], [1, 0, 0, 0], "front", 162, 8), ("drl", [0, 0, 0, 0], [0, 0, 0, 0], "front", 162, 8),
        ("taillamp", [1, 0, 0, 0], [1, 0, 0, 0], "taillamp", 28, 12)]:
        cam = {"type": "orbit", "yaw": yaw, "el": el, "aabb": K.part_aabb(mid, part)}
        jobs.append({"name": f"{car}_night_{ln}", "set": sid, "cam": cam, "size": big, "msaa": 4, "night": True,
                     "lamp_a": la, "lamp_b": lb})
    # steering: front wheels at full lock, from the front 3/4 and from above
    for st in (25, -25):
        jobs.append({"name": f"{car}_steer{st:+d}", "set": sid, "steer": st, "cam": {"type": "orbit", "yaw": 140, "el": 14},
                     "size": big, "msaa": 4})
        jobs.append({"name": f"{car}_steer{st:+d}_top", "set": sid, "steer": st, "cam": {"type": "orbit", "yaw": 180, "el": 70},
                     "size": big, "msaa": 4})

json.dump(jobs, open(K.S + "/jobs/p.json", "w"), indent=0)
print(len(jobs), "jobs")
