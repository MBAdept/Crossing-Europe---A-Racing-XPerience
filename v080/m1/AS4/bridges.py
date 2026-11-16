"""List the bridges of data/cities.json with type, boats, ships (AS4 scratch)."""
import json
import sys

WT = sys.argv[1]
d = json.load(open(WT + "/data/cities.json"))
TYPES = ("cable_stayed", "truss_arch", "stone_arch", "causeway", "girder", "suspension", "arch", "beam")


def walk(o, path=""):
    if isinstance(o, dict):
        if o.get("type") in TYPES or "boats" in o or "ships" in o:
            print(path, {k: o[k] for k in o if k in ("type", "name", "boats", "ships", "pylon_m", "depth_m", "start_km",
                                                     "end_km", "water", "bank")})
        for k, v in o.items():
            walk(v, path + "/" + str(k))
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(v, path + "[%d]" % i)


walk(d)
