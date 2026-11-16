"""AS2R probe jobs: one car at one distance, both levels, at 1x and supersampled 4x, day (race look), plus clay
and normal versions - to see what changes at a LOD swap.  usage: jobs_probe.py <set> <dist> <lodA> <lodB> <out.json>"""
import json
import sys

sid, dist, a, b, out = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5]
tag = sid.split("/")[1]
J = []
for lod in (a, b):
    J.append({"name": f"{tag}_{int(dist)}_{lod}", "set": sid, "lod": lod, "cam": {"type": "game", "dist": dist}})
    J.append({"name": f"{tag}_{int(dist)}_{lod}_ss4", "set": sid, "lod": lod, "cam": {"type": "game", "dist": dist, "ss": 4.0}, "msaa": 4})
    J.append({"name": f"{tag}_{int(dist)}_{lod}_clay_ss4", "set": sid, "lod": lod, "mode": "clay", "cam": {"type": "game", "dist": dist, "ss": 4.0}, "msaa": 4})
    J.append({"name": f"{tag}_{int(dist)}_{lod}_mask_ss4", "set": sid, "lod": lod, "mode": "mask", "contact": False, "no_ground": True,
              "cam": {"type": "game", "dist": dist, "ss": 4.0}, "msaa": 4})
J.append({"name": "empty_day", "set": "", "cam": {"type": "game", "dist": 30}})
json.dump(J, open(out, "w"), indent=0)
print(len(J), "jobs")
