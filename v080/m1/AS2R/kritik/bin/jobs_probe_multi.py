"""AS2R probe jobs for several sets: both levels at one distance (1x, ss4, clay ss4, mask ss4) + empty frame.
usage: jobs_probe_multi.py <dist> <lodA> <lodB> <out.json> <set> [<set> ...]"""
import json
import sys

dist, a, b, out = float(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
J = []
for sid in sys.argv[5:]:
    tag = sid.split("/")[1]
    for lod in (a, b):
        n = f"{tag}_{int(dist)}_{lod}"
        J.append({"name": n, "set": sid, "lod": lod, "cam": {"type": "game", "dist": dist}})
        J.append({"name": n + "_ss4", "set": sid, "lod": lod, "cam": {"type": "game", "dist": dist, "ss": 4.0}, "msaa": 4})
        J.append({"name": n + "_clay_ss4", "set": sid, "lod": lod, "mode": "clay", "cam": {"type": "game", "dist": dist, "ss": 4.0}, "msaa": 4})
        J.append({"name": n + "_mask_ss4", "set": sid, "lod": lod, "mode": "mask", "contact": False, "no_ground": True,
                  "cam": {"type": "game", "dist": dist, "ss": 4.0}, "msaa": 4})
J.append({"name": "empty_day", "set": "", "cam": {"type": "game", "dist": 30}})
json.dump(J, open(out, "w"), indent=0)
print(len(J), "jobs")
