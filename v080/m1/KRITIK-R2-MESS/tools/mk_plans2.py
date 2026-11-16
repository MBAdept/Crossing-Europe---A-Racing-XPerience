#!/usr/bin/env python3
"""AU-R2: plans of the second verification round (after the right cobble loop matched at its pitch and the slab law
4 dB/decade above 150 km/h): cobbles B and A, concrete 170 and 200 km/h (four 60-s runs)."""
import json
import os

H = os.path.dirname(os.path.abspath(__file__))
a = {s["name"]: s for s in json.load(open(os.path.join(H, "plan_a.json")))["segments"]}
b = {s["name"]: s for s in json.load(open(os.path.join(H, "plan_b.json")))["segments"]}
json.dump({"segments": [b["c_cobbles50_road"], b["c_cobbles50_full"]]}, open(os.path.join(H, "plan_b3.json"), "w"), indent=1)
segs = [a["cobbles50_full"], a["cobbles50_road"], a["conc170_full"]]
for i in range(4):
    s = dict(a["conc200_full"])
    s["name"] = "conc200_full_r%d" % i
    segs.append(s)
json.dump({"segments": segs}, open(os.path.join(H, "plan_a3.json"), "w"), indent=1)
print("ok")
