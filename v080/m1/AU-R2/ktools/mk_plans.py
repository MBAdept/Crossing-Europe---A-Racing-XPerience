#!/usr/bin/env python3
"""AU-R2: the verification plans (subsets of KRITIK-R's plans A and B, unchanged segment definitions)."""
import json
import os

H = os.path.dirname(os.path.abspath(__file__))
a = json.load(open(os.path.join(H, "plan_a.json")))["segments"]
segA = {s["name"]: s for s in a}
plan = [segA[n] for n in ("conc130_full", "conc130_noslab_full", "cobbles50_full", "cobbles50_road", "conc170_full",
                          "conc200_full", "asph130_full")]
# H2 evidence for the lead: the slab level at 0 and -3 dB (config 3), concrete 130 as played
for db in (0.0, -3.0):
    s = dict(segA["conc130_full"])
    s["name"] = "conc130_full_slab%+d" % int(db)
    s["slab_db"] = db
    plan.append(s)
json.dump({"segments": plan}, open(os.path.join(H, "plan_a2.json"), "w"), indent=1)
b = json.load(open(os.path.join(H, "plan_b.json")))["segments"]
segB = {s["name"]: s for s in b}
planb = [segB[n] for n in ("c_conc130_slab", "c_conc130_road", "c_conc130_tyre", "c_cobbles50_road", "c_conc130_full",
                           "c_cobbles50_full", "c_asph130_road")]
json.dump({"segments": planb}, open(os.path.join(H, "plan_b2.json"), "w"), indent=1)
p3 = []
for i in range(3):
    s = dict(segA["conc200_full"])
    s["name"] = "conc200_full_r%d" % i
    p3.append(s)
json.dump({"segments": p3}, open(os.path.join(H, "plan_m3.json"), "w"), indent=1)
print(len(plan), len(planb), len(p3))
