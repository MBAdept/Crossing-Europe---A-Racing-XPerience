"""KRITIK-2 job lists: p (player cars), t (traffic), s (showroom A/B), x (LOD swaps, silhouettes, fleet, shadows)."""
import json
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

BIG = [960, 600]
SUN_BACK = [0.35, 0.6, -1.0]       # sun ahead of the car: the rear the player looks at is in shade
SUN_W = [0.45, 0.8, 0.35]          # fixed world sun for the shadow comparison


def wheels_hidden(mid):
    return [p["node"] for p in K.wheel_parts(mid)]


# ---------------------------------------------------------------------------------------------------- player
P = []
for car in K.PLAYERS:
    sid = "player/" + car
    mid = "player/" + car
    sup = K.sprite_meta(sid)["supersample"]
    g8 = {"type": "game", "dist": 8.0}
    g9 = {"type": "game", "dist": 9.0}
    g30 = {"type": "game", "dist": 30.0}
    P += [
        {"name": f"{car}_g8_day", "set": sid, "cam": g8},
        {"name": f"{car}_g9_day", "set": sid, "cam": g9},
        {"name": f"{car}_g30_day", "set": sid, "cam": g30},
        {"name": f"{car}_g9_ss", "set": sid, "cam": dict(g9, ss=sup), "msaa": 4},
        {"name": f"{car}_g9_ss_neutral", "set": sid, "cam": dict(g9, ss=sup), "msaa": 4, "look": "neutral"},
        {"name": f"{car}_g8_backlit", "set": sid, "cam": g8, "sun": SUN_BACK},
        {"name": f"{car}_g8_low", "set": sid, "cam": dict(g8, ss=0.75), "msaa": 0},
        {"name": f"{car}_g8_daybrake", "set": sid, "cam": g8, "lamp_a": [0, 1, 0, 0]},
        {"name": f"{car}_g8_nighttail", "set": sid, "cam": g8, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]},
        {"name": f"{car}_g8_nightbrake", "set": sid, "cam": g8, "night": True, "lamp_a": [1, 1, 0, 0], "lamp_b": [1, 0, 0, 0]},
        {"name": f"{car}_g30_nighttail", "set": sid, "cam": g30, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]},
        {"name": f"{car}_g30_nightbrake", "set": sid, "cam": g30, "night": True, "lamp_a": [1, 1, 0, 0], "lamp_b": [1, 0, 0, 0]},
        {"name": f"{car}_g9_yaw+10_ss", "set": sid, "cam": dict(g9, ss=sup), "msaa": 4, "yaw": 10},
        {"name": f"{car}_g9_yaw-10_ss", "set": sid, "cam": dict(g9, ss=sup), "msaa": 4, "yaw": -10},
        {"name": f"{car}_g9_mask_ss", "set": sid, "cam": dict(g9, ss=sup), "msaa": 4, "mode": "mask", "contact": False, "no_ground": True},
    ]
    views = [
        ("rear34", 32, 13, None), ("rear", 0, 9, None), ("side", 90, 4, None), ("front34", 148, 11, None),
        ("rearclose", 18, 10, "rear"), ("frontclose", 162, 8, "front"), ("wheel", 68, 6, "wheel_rr"),
        ("wheelf", 112, 6, "wheel_fr"), ("cabin", 10, 20, "cabin"), ("taillamp", 28, 12, "taillamp"),
        ("headlamp", 152, 10, "headlamp"), ("top", 0, 38, None), ("front", 180, 6, None), ("under", 35, -8, None),
        ("wheelf_low", 100, -4, "wheel_fr"),
    ]
    for (vn, yaw, el, part) in views:
        cam = {"type": "orbit", "yaw": yaw, "el": el}
        if part:
            cam["aabb"] = K.part_aabb(mid, part)
        nog = vn in ("under", "wheelf_low")
        P.append({"name": f"{car}_lod0_{vn}", "set": sid, "lod": "lod0", "cam": cam, "size": BIG, "msaa": 4, "no_ground": nog})
        if vn in ("rear34", "front34", "side", "rearclose", "frontclose", "wheel", "taillamp", "headlamp", "cabin"):
            P.append({"name": f"{car}_show_{vn}", "set": sid, "lod": "show", "cam": cam, "size": BIG, "msaa": 4})
        if vn in ("rear34", "front34", "side", "rearclose", "frontclose", "top", "wheelf"):
            P.append({"name": f"{car}_clay_{vn}", "set": sid, "mode": "clay", "cam": cam, "size": BIG, "msaa": 4})
        if vn in ("rearclose", "frontclose", "rear34"):
            P.append({"name": f"{car}_facets_{vn}", "set": sid, "mode": "facets", "cam": cam, "size": BIG, "msaa": 4})
            P.append({"name": f"{car}_wire_{vn}", "set": sid, "mode": "wire", "cam": cam, "size": BIG, "msaa": 4})
        if vn in ("rear34",):
            P.append({"name": f"{car}_normals_{vn}", "set": sid, "mode": "normals", "cam": cam, "size": BIG, "msaa": 4})
        if vn in ("rear34", "front34", "wheelf", "under", "wheelf_low"):
            P.append({"name": f"{car}_check_{vn}", "set": sid, "mode": "check_noglass", "cam": cam, "size": BIG, "msaa": 4, "no_ground": nog})
            P.append({"name": f"{car}_checkcb_{vn}", "set": sid, "mode": "check_cb", "cam": cam, "size": BIG, "msaa": 4, "no_ground": nog})
        if vn in ("cabin", "rear34", "side"):
            P.append({"name": f"{car}_noglass_{vn}", "set": sid, "mode": "noglass", "cam": cam, "size": BIG, "msaa": 4})
        if vn in ("rearclose", "frontclose", "rear", "side"):
            P.append({"name": f"{car}_lampmap_{vn}", "set": sid, "mode": "lampmap", "cam": cam, "size": BIG, "msaa": 4})
        if vn in ("rearclose", "frontclose", "side", "rear34"):
            P.append({"name": f"{car}_caster_{vn}", "set": sid, "mode": "caster", "cam": cam, "size": BIG, "msaa": 4})
    # sections: driver seat (x = -0.36, seen from the left), rear axle and front axle cross-sections
    wp = K.wheel_parts(mid)
    zr = max(p["pos"][2] for p in wp)
    zf = min(p["pos"][2] for p in wp)
    P += [
        {"name": f"{car}_sec_driver", "set": sid, "mode": "section_col", "section": [-1, 0, 0, 0.36], "cam": {"type": "orbit", "yaw": -90, "el": 4}, "size": BIG, "msaa": 4},
        {"name": f"{car}_sec_mid", "set": sid, "mode": "section_col", "section": [-1, 0, 0, 0.0], "cam": {"type": "orbit", "yaw": -90, "el": 4}, "size": BIG, "msaa": 4},
        {"name": f"{car}_sec_rearaxle", "set": sid, "mode": "section_col", "section": [0, 0, 1, zr], "cam": {"type": "orbit", "yaw": 0, "el": 4, "aabb": [-1.2, 0, zr - 0.2, 1.2, 1.6, zr + 0.2]}, "size": BIG, "msaa": 4},
        {"name": f"{car}_sec_frontaxle", "set": sid, "mode": "section_col", "section": [0, 0, -1, -zf], "cam": {"type": "orbit", "yaw": 180, "el": 4, "aabb": [-1.2, 0, zf - 0.2, 1.2, 1.6, zf + 0.2]}, "size": BIG, "msaa": 4},
        {"name": f"{car}_sec_rearseat", "set": sid, "mode": "section_col", "section": [0, 0, 1, zr - 0.45], "cam": {"type": "orbit", "yaw": 0, "el": 4, "aabb": [-1.2, 0, zr - 0.65, 1.2, 1.6, zr - 0.25]}, "size": BIG, "msaa": 4},
    ]
    # ground shadow: the caster (as in the race) against the body itself casting, same sun from above
    for nm, md in (("shadow_caster", "shaded"), ("shadow_body", "body_caster")):
        P.append({"name": f"{car}_{nm}", "set": sid, "mode": md, "contact": False, "sun_world": SUN_W,
                  "cam": {"type": "orbit", "yaw": 0, "el": 89, "aabb": [-2.6, 0, -3.4, 2.6, 0.2, 3.4]}, "size": [800, 1000], "msaa": 4})
    # night close-ups, every lamp state
    for (ln, la, lb, part, yaw, el) in [
        ("tail", [1, 0, 0, 0], [1, 0, 0, 0], "rear", 18, 10), ("brake", [1, 1, 0, 0], [1, 0, 0, 0], "rear", 18, 10),
        ("indl", [1, 0, 1, 0], [1, 0, 0, 0], "rear", 18, 10), ("indr", [1, 0, 0, 1], [1, 0, 0, 0], "rear", 18, 10),
        ("reverse", [1, 0, 0, 0], [1, 1, 0, 0], "rear", 18, 10), ("head", [1, 0, 0, 0], [1, 0, 0, 0], "front", 162, 8),
        ("headind", [1, 0, 1, 1], [1, 0, 0, 0], "front", 162, 8), ("drl", [0, 0, 0, 0], [0, 0, 0, 0], "front", 162, 8),
        ("taillamp", [1, 0, 0, 0], [1, 0, 0, 0], "taillamp", 28, 12), ("rear_tail", [1, 0, 0, 0], [1, 0, 0, 0], None, 0, 9),
        ("rear_brake", [1, 1, 0, 0], [1, 0, 0, 0], None, 0, 9)]:
        cam = {"type": "orbit", "yaw": yaw, "el": el}
        if part:
            cam["aabb"] = K.part_aabb(mid, part)
        P.append({"name": f"{car}_night_{ln}", "set": sid, "cam": cam, "size": BIG, "msaa": 4, "night": True, "lamp_a": la, "lamp_b": lb})
    # day: unlit lamps and the brake by day (straight from behind and the rear close-up)
    P.append({"name": f"{car}_day_rear_brake", "set": sid, "cam": {"type": "orbit", "yaw": 0, "el": 9}, "size": BIG, "msaa": 4, "lamp_a": [0, 1, 0, 0]})
    # steering and spin
    for st in (25, -25):
        P.append({"name": f"{car}_steer{st:+d}", "set": sid, "steer": st, "cam": {"type": "orbit", "yaw": 140, "el": 14}, "size": BIG, "msaa": 4})
        P.append({"name": f"{car}_steer{st:+d}_top", "set": sid, "steer": st, "mode": "clay", "cam": {"type": "orbit", "yaw": 180, "el": 70}, "size": BIG, "msaa": 4})
    P.append({"name": f"{car}_spin45_wheelf", "set": sid, "spin": 45, "cam": {"type": "orbit", "yaw": 112, "el": 6, "aabb": K.part_aabb(mid, "wheel_fr")}, "size": BIG, "msaa": 4})
json.dump(P, open(K.JOBS + "/p.json", "w"), indent=0)
print(len(P), "player jobs")

# ---------------------------------------------------------------------------------------------------- traffic
T = []
TYPES = dict(K.TRAFFIC_NEW)
for car, sets in TYPES.items():
    mid = "traffic/" + car
    sid = "traffic/" + sets[0]
    lite = "traffic/" + sets[0]   # white / lightest first
    for d, lods in ((10, ["lod0"]), (20, ["lod0"]), (25, ["lod0", "lod1"]), (30, ["lod0"]), (40, ["lod0", "lod1"]), (60, ["lod0", "lod1"]),
                    (80, ["lod1"]), (90, ["lod1", "lod2"]), (120, ["lod1", "lod2"]), (160, ["lod1", "lod2"]), (200, ["lod2"])):
        for lod in lods:
            T.append({"name": f"{car}_g{d}_{lod}_day", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d}})
    for d, lod in ((10, "lod0"), (30, "lod0"), (80, "lod1"), (120, "lod2")):
        T.append({"name": f"{car}_g{d}_{lod}_ss", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d, "ss": 3.0}, "msaa": 4})
    for d, lod in ((10, "lod0"), (30, "lod0"), (80, "lod1"), (150, "lod2")):
        T.append({"name": f"{car}_g{d}_{lod}_daybrake", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d}, "lamp_a": [0, 1, 0, 0]})
        T.append({"name": f"{car}_g{d}_{lod}_dayind", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d}, "lamp_a": [0, 0, 1, 0]})
        T.append({"name": f"{car}_g{d}_{lod}_nighttail", "set": lite, "lod": lod, "cam": {"type": "game", "dist": d}, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
        T.append({"name": f"{car}_g{d}_{lod}_nightbrake", "set": lite, "lod": lod, "cam": {"type": "game", "dist": d}, "night": True, "lamp_a": [1, 1, 1, 0], "lamp_b": [1, 0, 0, 0]})
    for d in (12, 25):
        T.append({"name": f"{car}_g{d}_lane", "set": sid, "lod": "lod0", "cam": {"type": "game", "dist": d, "lane": -3.5}})
    T.append({"name": f"{car}_g15_backlit", "set": sid, "lod": "lod0", "cam": {"type": "game", "dist": 15}, "sun": SUN_BACK})
    T.append({"name": f"{car}_g30_oncoming_night", "set": lite, "lod": "lod0", "yaw": 180, "cam": {"type": "game", "dist": 30, "lane": 3.5}, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
    T.append({"name": f"{car}_g30_oncoming_day", "set": sid, "lod": "lod0", "yaw": 180, "cam": {"type": "game", "dist": 30, "lane": 3.5}})
    m = K.sprite_meta(sid)
    cw, ch = m["cell"]
    for yaw in (0, 12, -12, 24, -24):
        for lod in ("lod0", "lod1", "lod2"):
            if lod != "lod0" and yaw not in (0, 24):
                continue
            T.append({"name": f"{car}_ortho_{lod}_y{yaw:+d}", "set": sid, "lod": lod, "yaw": yaw, "pivot": "rear", "contact": False,
                      "size": [cw * 4, ch * 4], "msaa": 4,
                      "cam": {"type": "ortho", "el": m["elevation_deg"], "width_m": m["image_width_m"], "anchor": m["anchor"],
                              "pivot_z": m["object"]["length_m"] * 0.5}})
    for lod in ("lod0", "lod2"):
        for yaw in (0, 24):
            T.append({"name": f"{car}_sil_{lod}_y{yaw}", "set": sid, "lod": lod, "yaw": yaw, "pivot": "rear", "mode": "mask", "contact": False,
                      "no_ground": True, "size": [cw * 2, ch * 2], "msaa": 4,
                      "cam": {"type": "ortho", "el": m["elevation_deg"], "width_m": m["image_width_m"], "anchor": m["anchor"],
                              "pivot_z": m["object"]["length_m"] * 0.5}})
    for lod in ("lod0", "lod1", "lod2"):
        T.append({"name": f"{car}_ortho_lampmap_{lod}", "set": sid, "lod": lod, "pivot": "rear", "mode": "lampmap", "msaa": 0,
                  "size": [cw * 4, ch * 4], "no_ground": True, "contact": False,
                  "cam": {"type": "ortho", "el": 0.0, "width_m": m["image_width_m"], "anchor": [0.5, 0.95], "pivot_z": m["object"]["length_m"] * 0.5}})
        T.append({"name": f"{car}_ortho_lampmapf_{lod}", "set": sid, "lod": lod, "pivot": "rear", "yaw": 180, "mode": "lampmap", "msaa": 0,
                  "size": [cw * 4, ch * 4], "no_ground": True, "contact": False,
                  "cam": {"type": "ortho", "el": 0.0, "width_m": m["image_width_m"], "anchor": [0.5, 0.95], "pivot_z": m["object"]["length_m"] * 0.5}})
    views = [("rear34", 32, 13, None), ("rear", 0, 9, None), ("side", 90, 4, None), ("front34", 148, 11, None),
             ("rearclose", 18, 10, "rear"), ("frontclose", 162, 8, "front"), ("wheel", 68, 6, "wheel_rr"),
             ("taillamp", 28, 12, "taillamp"), ("headlamp", 152, 10, "headlamp"), ("top", 0, 38, None), ("under", 35, -8, None)]
    for (vn, yaw, el, part) in views:
        cam = {"type": "orbit", "yaw": yaw, "el": el}
        if part:
            cam["aabb"] = K.part_aabb(mid, part)
        T.append({"name": f"{car}_lod0_{vn}", "set": sid, "lod": "lod0", "cam": cam, "size": BIG, "msaa": 4, "no_ground": vn == "under"})
        if vn in ("rear34", "side", "front34", "rearclose"):
            for lod in ("lod1", "lod2"):
                T.append({"name": f"{car}_{lod}_{vn}", "set": sid, "lod": lod, "cam": cam, "size": BIG, "msaa": 4})
                T.append({"name": f"{car}_wire{lod}_{vn}", "set": sid, "lod": lod, "mode": "wire", "cam": cam, "size": BIG, "msaa": 4})
            T.append({"name": f"{car}_clay_{vn}", "set": sid, "lod": "lod0", "mode": "clay", "cam": cam, "size": BIG, "msaa": 4})
            T.append({"name": f"{car}_wirelod0_{vn}", "set": sid, "lod": "lod0", "mode": "wire", "cam": cam, "size": BIG, "msaa": 4})
            T.append({"name": f"{car}_checkcb_{vn}", "set": sid, "lod": "lod0", "mode": "check_cb", "cam": cam, "size": BIG, "msaa": 4})
            T.append({"name": f"{car}_checkng_{vn}", "set": sid, "lod": "lod0", "mode": "check_noglass", "cam": cam, "size": BIG, "msaa": 4})
            T.append({"name": f"{car}_normals_{vn}", "set": sid, "lod": "lod0", "mode": "normals", "cam": cam, "size": BIG, "msaa": 4})
        if vn in ("rearclose", "frontclose"):
            T.append({"name": f"{car}_lampmap_{vn}", "set": sid, "lod": "lod0", "mode": "lampmap", "cam": cam, "size": BIG, "msaa": 4})
        if vn in ("rearclose", "rear34", "side"):
            T.append({"name": f"{car}_caster_{vn}", "set": sid, "lod": "lod0", "mode": "caster", "cam": cam, "size": BIG, "msaa": 4})
    for nm, md in (("shadow_caster", "shaded"), ("shadow_body", "body_caster")):
        T.append({"name": f"{car}_{nm}", "set": sid, "mode": md, "contact": False, "sun_world": SUN_W,
                  "cam": {"type": "orbit", "yaw": 0, "el": 89, "aabb": [-2.6, 0, -3.6, 2.6, 0.2, 3.6]}, "size": [800, 1000], "msaa": 4})
    for (ln, la, lb, part, yaw, el) in [("tail", [1, 0, 0, 0], [1, 0, 0, 0], "rear", 18, 10), ("brake", [1, 1, 0, 0], [1, 0, 0, 0], "rear", 18, 10),
                                        ("indl", [1, 0, 1, 0], [1, 0, 0, 0], "rear", 18, 10), ("reverse", [1, 0, 0, 0], [1, 1, 0, 0], "rear", 18, 10),
                                        ("head", [1, 0, 0, 0], [1, 0, 0, 0], "front", 162, 8), ("headind", [1, 0, 1, 1], [1, 0, 0, 0], "front", 162, 8),
                                        ("off_day", [0, 0, 0, 0], [0, 0, 0, 0], "rear", 18, 10)]:
        cam = {"type": "orbit", "yaw": yaw, "el": el, "aabb": K.part_aabb(mid, part)}
        for lod in ("lod0", "lod1", "lod2"):
            if lod != "lod0" and ln not in ("brake", "indl", "head", "tail"):
                continue
            T.append({"name": f"{car}_{lod}_night_{ln}", "set": lite, "lod": lod, "cam": cam, "size": BIG, "msaa": 4,
                      "night": ln != "off_day", "lamp_a": la, "lamp_b": lb})
    for s in sets:
        T.append({"name": f"{car}_paint_{s}", "set": "traffic/" + s, "lod": "lod0", "cam": {"type": "orbit", "yaw": 32, "el": 13}, "size": [640, 400], "msaa": 4})
        T.append({"name": f"{car}_paint_{s}_g30", "set": "traffic/" + s, "lod": "lod0", "cam": {"type": "game", "dist": 30}})
    T.append({"name": f"{car}_steer25", "set": sid, "lod": "lod0", "steer": 25, "cam": {"type": "orbit", "yaw": 140, "el": 14}, "size": BIG, "msaa": 4})
    T.append({"name": f"{car}_steer25_top", "set": sid, "lod": "lod0", "steer": 25, "mode": "clay", "cam": {"type": "orbit", "yaw": 180, "el": 70}, "size": BIG, "msaa": 4})
# the AS1 types for the fleet comparison
for car, s in K.TRAFFIC_OLD.items():
    sid = "traffic/" + s
    for d, lods in ((10, ["lod0"]), (30, ["lod0"]), (40, ["lod0", "lod1"]), (80, ["lod1"]), (120, ["lod1", "lod2"])):
        for lod in lods:
            T.append({"name": f"{car}_g{d}_{lod}_day", "set": sid, "lod": lod, "cam": {"type": "game", "dist": d}})
    T.append({"name": f"{car}_lod0_rear34", "set": sid, "lod": "lod0", "cam": {"type": "orbit", "yaw": 32, "el": 13}, "size": BIG, "msaa": 4})
    T.append({"name": f"{car}_lod0_side", "set": sid, "lod": "lod0", "cam": {"type": "orbit", "yaw": 90, "el": 4}, "size": BIG, "msaa": 4})
    T.append({"name": f"{car}_lod0_front34", "set": sid, "lod": "lod0", "cam": {"type": "orbit", "yaw": 148, "el": 11}, "size": BIG, "msaa": 4})
    T.append({"name": f"{car}_g30_lod0_nighttail", "set": sid, "lod": "lod0", "cam": {"type": "game", "dist": 30}, "night": True, "lamp_a": [1, 0, 0, 0], "lamp_b": [1, 0, 0, 0]})
# empty frames of the game camera (background for the sprite composites)
T.append({"name": "empty_day", "set": "", "cam": {"type": "game", "dist": 30}})
T.append({"name": "empty_night", "set": "", "night": True, "cam": {"type": "game", "dist": 30}})
T.append({"name": "empty_day_ss3", "set": "", "cam": {"type": "game", "dist": 30, "ss": 3.0}, "msaa": 4})
json.dump(T, open(K.JOBS + "/t.json", "w"), indent=0)
print(len(T), "traffic jobs")

# ---------------------------------------------------------------------------------------------------- showroom
S = []
for car in K.PLAYERS:
    sid = "showroom/" + car
    common = {"set": sid, "lod": "show", "cam": {"type": "showroom"}, "size": [768, 480], "msaa": 4, "lamp_b": [1, 0, 0, 0]}
    S.append(dict(common, name=f"{car}_sr_sheet_agx", tonemap="agx", contact=False))          # AS2a's A/B rig
    S.append(dict(common, name=f"{car}_sr_studio_race", rig="studio"))                        # UI1 studio + race look
    S.append(dict(common, name=f"{car}_sr_studio_neutral", rig="studio", look="neutral"))     # UI1 studio as shipped today
    S.append(dict(common, name=f"{car}_sr_studio_race_norims", rig="studio", no_rims=True))
    S.append(dict(common, name=f"{car}_sr_mask", mode="mask", contact=False, no_ground=True))
    S.append(dict(common, name=f"{car}_sr_clay", mode="clay", rig="studio"))
json.dump(S, open(K.JOBS + "/s.json", "w"), indent=0)
print(len(S), "showroom jobs")
