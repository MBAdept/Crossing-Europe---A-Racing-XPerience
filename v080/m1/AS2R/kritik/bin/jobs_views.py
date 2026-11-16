"""AS2R: orbit views of sets / levels in some modes.  usage: jobs_views.py <out.json> <lods,..> <modes,..> <views,..> <set> [<set> ...]
views: rear34 rear side front34 front top rearclose frontclose wheel wheelf taillamp headlamp (as the review)."""
import json
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

VIEWS = {"rear34": (32, 13, None), "rear": (0, 9, None), "side": (90, 4, None), "front34": (148, 11, None),
         "front": (180, 6, None), "top": (0, 38, None), "rearclose": (18, 10, "rear"), "frontclose": (162, 8, "front"),
         "wheel": (68, 6, "wheel_rr"), "wheelf": (112, 6, "wheel_fr"), "wheelf_low": (100, -4, "wheel_fr"),
         "taillamp": (28, 12, "taillamp"), "headlamp": (152, 10, "headlamp"), "under": (35, -8, None),
         "sidelow": (90, 0, None)}
out, lods, modes, views = sys.argv[1], sys.argv[2].split(","), sys.argv[3].split(","), sys.argv[4].split(",")
J = []
for sid in sys.argv[5:]:
    mid = K._models["sets"][sid]["model"]
    tag = sid.split("/")[1]
    for lod in lods:
        for mode in modes:
            for v in views:
                yaw, el, part = VIEWS[v]
                cam = {"type": "orbit", "yaw": yaw, "el": el}
                if part:
                    cam["aabb"] = K.part_aabb(mid, part)
                j = {"name": f"{tag}_{lod}_{mode}_{v}", "set": sid, "lod": lod, "cam": cam, "size": [960, 600], "msaa": 4,
                     "no_ground": v in ("under", "wheelf_low")}
                if mode != "shaded":
                    j["mode"] = mode
                J.append(j)
json.dump(J, open(out, "w"), indent=0)
print(len(J), "jobs")
