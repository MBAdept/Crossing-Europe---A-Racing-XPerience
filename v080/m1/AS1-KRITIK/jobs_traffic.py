"""Job lists of batches 't' (traffic cars) and 'k' (truck)."""
import json
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K

big = [960, 600]
SETS = {"sedan": ["sedan_red", "sedan_black", "sedan_blue", "sedan_silver"],
        "hatch": ["hatch_red", "hatch_blue", "hatch_green", "hatch_white", "hatch_yellow"],
        "wagon": ["wagon_green", "wagon_darkblue", "wagon_silver", "wagon_white"]}
jobs = []
for car, sets in SETS.items():
    mid = "traffic/" + car
    sid = "traffic/" + sets[0]
    lite = "traffic/" + ("sedan_silver" if car == "sedan" else ("hatch_white" if car == "hatch" else "wagon_silver"))
    # game camera, by distance; the level the renderer would pick at "Details: Mittel" (40 / 120 m) and the
    # neighbour level at the swap distances
    for d, lods in ((10, ["lod0"]), (20, ["lod0"]), (30, ["lod0"]), (40, ["lod0", "lod1"]), (60, ["lod1"]),
                    (80, ["lod1"]), (120, ["lod1", "lod2"]), (200, ["lod2"])):
        for lod in lods:
            jobs.append({"name": f"{car}_g{d}_{lod}_day", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d}})
            jobs.append({"name": f"{car}_g{d}_{lod}_day_ss", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d, "ss": 3.0}, "msaa": 4})
    for d, lod in ((10, "lod0"), (30, "lod0"), (80, "lod1"), (150, "lod2")):
        jobs.append({"name": f"{car}_g{d}_{lod}_daybrake", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d}, "lamp_a": [0, 1, 1, 0]})
        jobs.append({"name": f"{car}_g{d}_{lod}_nighttail", "set": lite, "lod": lod, "cam": {"type": "game", "dist": d}, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
        jobs.append({"name": f"{car}_g{d}_{lod}_nightbrake", "set": lite, "lod": lod, "cam": {"type": "game", "dist": d}, "night": True, "lamp_a": [1, 1, 1, 0], "lamp_b": [1, 0, 0, 0]})
    for d in (12, 25):
        jobs.append({"name": f"{car}_g{d}_lane", "set": sid, "lod": "lod0", "cam": {"type": "game", "dist": d, "lane": -3.5}})
    # backlit and oncoming (front, as on a two-lane road at night)
    jobs.append({"name": f"{car}_g15_backlit", "set": sid, "lod": "lod0", "cam": {"type": "game", "dist": 15}, "sun": [0.35, 0.6, -1.0]})
    jobs.append({"name": f"{car}_g30_oncoming_night", "set": lite, "lod": "lod0", "yaw": 180, "cam": {"type": "game", "dist": 30, "lane": 3.5}, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
    # sprite camera (ortho, 9 deg, pivot at the rear), 4x the sprite's resolution
    m = K.sprite_meta(sid)
    cw, ch = m["cell"]
    for yaw in (0, 12, -12, 24, -24):
        for lod in ("lod0", "lod1", "lod2"):
            if lod != "lod0" and yaw not in (0, 24):
                continue
            jobs.append({"name": f"{car}_ortho_{lod}_y{yaw:+d}", "set": sid, "lod": lod, "yaw": yaw, "pivot": "rear",
                         "size": [cw * 4, ch * 4], "msaa": 4,
                         "cam": {"type": "ortho", "el": m["elevation_deg"], "width_m": m["image_width_m"], "anchor": m["anchor"],
                                 "pivot_z": m["object"]["length_m"] * 0.5}})
    # review close-ups
    views = [("rear34", 32, 13, None), ("rear", 0, 9, None), ("side", 90, 4, None), ("front34", 148, 11, None),
             ("rearclose", 18, 10, "rear"), ("frontclose", 162, 8, "front"), ("wheel", 68, 6, "wheel_rr"),
             ("taillamp", 28, 12, "taillamp"), ("headlamp", 152, 10, "headlamp"), ("top", 0, 38, None), ("cabin", 10, 20, "cabin")]
    for (vn, yaw, el, part) in views:
        cam = {"type": "orbit", "yaw": yaw, "el": el}
        if part:
            cam["aabb"] = K.part_aabb(mid, part)
        jobs.append({"name": f"{car}_lod0_{vn}", "set": sid, "lod": "lod0", "cam": cam, "size": big, "msaa": 4})
        if vn in ("rear34", "side", "front34", "rearclose"):
            for lod in ("lod1", "lod2"):
                jobs.append({"name": f"{car}_{lod}_{vn}", "set": sid, "lod": lod, "cam": cam, "size": big, "msaa": 4})
                jobs.append({"name": f"{car}_wire{lod}_{vn}", "set": sid, "lod": lod, "mode": "wire", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_clay_{vn}", "set": sid, "lod": "lod0", "mode": "clay", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_wirelod0_{vn}", "set": sid, "lod": "lod0", "mode": "wire", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_checkcb_{vn}", "set": sid, "lod": "lod0", "mode": "check_cb", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_checkng_{vn}", "set": sid, "lod": "lod0", "mode": "check_noglass", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_normals_{vn}", "set": sid, "lod": "lod0", "mode": "normals", "cam": cam, "size": big, "msaa": 4})
        if vn in ("rearclose", "frontclose"):
            jobs.append({"name": f"{car}_lampmap_{vn}", "set": sid, "lod": "lod0", "mode": "lampmap", "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"{car}_caster_{vn}", "set": sid, "lod": "lod0", "mode": "caster", "cam": cam, "size": big, "msaa": 4})
    for (ln, la, lb, part, yaw, el) in [("tail", [1, 0, 0, 0], [1, 0, 0, 0], "rear", 18, 10), ("brake", [1, 1, 0, 0], [1, 0, 0, 0], "rear", 18, 10),
                                        ("indl", [1, 0, 1, 0], [1, 0, 0, 0], "rear", 18, 10), ("reverse", [1, 0, 0, 0], [1, 1, 0, 0], "rear", 18, 10),
                                        ("head", [1, 0, 0, 0], [1, 0, 0, 0], "front", 162, 8), ("headind", [1, 0, 1, 1], [1, 0, 0, 0], "front", 162, 8)]:
        cam = {"type": "orbit", "yaw": yaw, "el": el, "aabb": K.part_aabb(mid, part)}
        for lod in ("lod0", "lod1", "lod2"):
            if lod != "lod0" and ln not in ("brake", "indl", "head"):
                continue
            jobs.append({"name": f"{car}_{lod}_night_{ln}", "set": lite, "lod": lod, "cam": cam, "size": big, "msaa": 4,
                         "night": True, "lamp_a": la, "lamp_b": lb})
    for s in sets:
        jobs.append({"name": f"{car}_paint_{s}", "set": "traffic/" + s, "lod": "lod0", "cam": {"type": "orbit", "yaw": 32, "el": 13}, "size": [640, 400], "msaa": 4})
        jobs.append({"name": f"{car}_paint_{s}_g30", "set": "traffic/" + s, "lod": "lod0", "cam": {"type": "game", "dist": 30}})
    jobs.append({"name": f"{car}_steer25", "set": sid, "lod": "lod0", "steer": 25, "cam": {"type": "orbit", "yaw": 140, "el": 14}, "size": big, "msaa": 4})
json.dump(jobs, open(K.S + "/jobs/t.json", "w"), indent=0)
print(len(jobs), "traffic jobs")

# --- truck -----------------------------------------------------------------------------------------------
jobs = []
mid = "traffic/truck"
sid = "traffic/truck_white"
for d, lods in ((15, ["lod0"]), (20, ["lod0"]), (40, ["lod0"]), (60, ["lod0", "lod1"]), (100, ["lod1"]), (150, ["lod1"]),
                (180, ["lod1", "lod2"]), (250, ["lod2"])):
    for lod in lods:
        jobs.append({"name": f"truck_g{d}_{lod}_day", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + 8.25}})
        jobs.append({"name": f"truck_g{d}_{lod}_day_ss", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + 8.25, "ss": 3.0}, "msaa": 4})
for d, lod in ((20, "lod0"), (60, "lod1"), (150, "lod1"), (250, "lod2")):
    jobs.append({"name": f"truck_g{d}_{lod}_daybrake", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + 8.25}, "lamp_a": [0, 1, 1, 0]})
    jobs.append({"name": f"truck_g{d}_{lod}_nighttail", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + 8.25}, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
    jobs.append({"name": f"truck_g{d}_{lod}_nightbrake", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d + 8.25}, "night": True, "lamp_a": [1, 1, 1, 0], "lamp_b": [1, 0, 0, 0]})
for d in (12, 30):
    jobs.append({"name": f"truck_g{d}_lane", "set": sid, "lod": "lod0", "cam": {"type": "game", "dist": d + 8.25, "lane": -3.5}})
jobs.append({"name": "truck_g40_oncoming_night", "set": sid, "lod": "lod0", "yaw": 180, "cam": {"type": "game", "dist": 40, "lane": 3.5}, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
views = [("rear34", 32, 13, None), ("rear", 0, 9, None), ("side", 90, 4, None), ("front34", 148, 11, None), ("top", 0, 38, None),
         ("rearclose", 18, 10, [-1.6, 0.0, 6.6, 1.6, 4.1, 8.3]), ("cabclose", 150, 10, [-1.6, 0.0, -8.3, 1.6, 4.0, -5.0]),
         ("wheels", 70, 6, [0.6, 0.0, -4.0, 1.6, 1.4, -2.2]), ("trailerwheels", 70, 6, [0.6, 0.0, 1.8, 1.6, 1.4, 6.1]),
         ("coupling", 60, 20, [-1.4, 0.0, -5.5, 1.4, 4.0, -1.5]), ("cabside", 90, 4, [-1.6, 0.0, -8.3, 1.6, 4.0, -2.0])]
for (vn, yaw, el, part) in views:
    cam = {"type": "orbit", "yaw": yaw, "el": el}
    if part:
        cam["aabb"] = part
    jobs.append({"name": f"truck_lod0_{vn}", "set": sid, "lod": "lod0", "cam": cam, "size": big, "msaa": 4})
    if vn in ("rear34", "side", "front34", "rearclose", "cabclose"):
        for lod in ("lod1", "lod2"):
            jobs.append({"name": f"truck_{lod}_{vn}", "set": sid, "lod": lod, "cam": cam, "size": big, "msaa": 4})
            jobs.append({"name": f"truck_wire{lod}_{vn}", "set": sid, "lod": lod, "mode": "wire", "cam": cam, "size": big, "msaa": 4})
        jobs.append({"name": f"truck_clay_{vn}", "set": sid, "lod": "lod0", "mode": "clay", "cam": cam, "size": big, "msaa": 4})
        jobs.append({"name": f"truck_wirelod0_{vn}", "set": sid, "lod": "lod0", "mode": "wire", "cam": cam, "size": big, "msaa": 4})
        jobs.append({"name": f"truck_checkcb_{vn}", "set": sid, "lod": "lod0", "mode": "check_cb", "cam": cam, "size": big, "msaa": 4})
        jobs.append({"name": f"truck_check_{vn}", "set": sid, "lod": "lod0", "mode": "check", "cam": cam, "size": big, "msaa": 4})
        jobs.append({"name": f"truck_lampmap_{vn}", "set": sid, "lod": "lod0", "mode": "lampmap", "cam": cam, "size": big, "msaa": 4})
        jobs.append({"name": f"truck_caster_{vn}", "set": sid, "lod": "lod0", "mode": "caster", "cam": cam, "size": big, "msaa": 4})
for (ln, la, lb, part, yaw, el) in [("tail", [1, 0, 0, 0], [1, 0, 0, 0], [-1.6, 0.0, 6.6, 1.6, 4.1, 8.3], 18, 10),
                                    ("brake", [1, 1, 0, 0], [1, 0, 0, 0], [-1.6, 0.0, 6.6, 1.6, 4.1, 8.3], 18, 10),
                                    ("indl", [1, 0, 1, 0], [1, 0, 0, 0], [-1.6, 0.0, 6.6, 1.6, 4.1, 8.3], 18, 10),
                                    ("reverse", [1, 0, 0, 0], [1, 1, 0, 0], [-1.6, 0.0, 6.6, 1.6, 4.1, 8.3], 18, 10),
                                    ("head", [1, 0, 0, 0], [1, 0, 0, 0], [-1.6, 0.0, -8.3, 1.6, 4.0, -5.0], 150, 10),
                                    ("headind", [1, 0, 1, 1], [1, 0, 0, 0], [-1.6, 0.0, -8.3, 1.6, 4.0, -5.0], 150, 10)]:
    for lod in ("lod0", "lod1", "lod2"):
        if lod != "lod0" and ln not in ("brake", "head"):
            continue
        jobs.append({"name": f"truck_{lod}_night_{ln}", "set": sid, "lod": lod, "cam": {"type": "orbit", "yaw": yaw, "el": el, "aabb": part},
                     "size": big, "msaa": 4, "night": True, "lamp_a": la, "lamp_b": lb})
for s in ("truck_white", "truck_blue", "truck_green", "truck_red"):
    jobs.append({"name": f"truck_paint_{s}", "set": "traffic/" + s, "lod": "lod0", "cam": {"type": "orbit", "yaw": 140, "el": 12}, "size": [640, 400], "msaa": 4})
    jobs.append({"name": f"truck_paint_{s}_rear", "set": "traffic/" + s, "lod": "lod0", "cam": {"type": "orbit", "yaw": 30, "el": 10}, "size": [640, 400], "msaa": 4})
for a in (0, 15, 30, 45):
    jobs.append({"name": f"truck_art{a}_top", "set": sid, "lod": "lod0", "articulate": a, "cam": {"type": "orbit", "yaw": 0, "el": 80, "aabb": [-6, 0, -9, 6, 4, 9]}, "size": big, "msaa": 4})
    jobs.append({"name": f"truck_art{a}_34", "set": sid, "lod": "lod0", "articulate": a, "cam": {"type": "orbit", "yaw": 120, "el": 18, "aabb": [-3, 0, -8.5, 3, 4, -1]}, "size": big, "msaa": 4})
jobs.append({"name": "truck_steer25", "set": sid, "lod": "lod0", "steer": 25, "cam": {"type": "orbit", "yaw": 140, "el": 14, "aabb": [-1.6, 0.0, -8.3, 1.6, 4.0, -5.0]}, "size": big, "msaa": 4})
json.dump(jobs, open(K.S + "/jobs/k.json", "w"), indent=0)
print(len(jobs), "truck jobs")
