#!/usr/bin/env python3
"""AU-R: analysis of a cap_const.gd run: loudness, peaks, repetition (envelope autocorrelation) per segment.
usage: ana_cap.py <capdir> <out.json>"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ana  # noqa: E402

cap = sys.argv[1]
out = sys.argv[2]
meta = json.load(open(os.path.join(cap, "segments.json")))
res = {"master_db": meta["master_db"], "mmaster_fx": meta.get("mmaster_fx"), "segments": {}}
for s in meta["segments"]:
    name = s["name"]
    x = ana.load(os.path.join(cap, name + ".wav"))
    r = {"seconds": round(len(x) / ana.SR, 2), "lufs": round(ana.lufs(x), 2), "tp_at_1.0": round(ana.tp(x), 2),
         "sp_at_1.0": round(ana.sp(x), 2), "feed": {k: s["feed"].get(k) for k in ("surface_l", "surface_r", "paving", "zone")}}
    pre = os.path.join(cap, name + "_pre.f32")
    if os.path.exists(pre):
        y = ana.load(pre)
        if len(y):
            r["pre_sp"] = round(ana.sp(y), 2)
            r["pre_tp"] = round(ana.tp(y), 2)
    r["third_oct"] = [round(float(v), 2) for v in ana.third_octaves(x)]
    if any(k in name for k in ("asph130", "conc130", "cobbles50", "asph200", "conc200")):
        r["rep"] = ana.repetition(x)
    res["segments"][name] = r
    rep = r.get("rep", {})
    line = f"{name:16s} {r['seconds']:5.1f}s {r['lufs']:7.2f} LUFS  TP@1.0 {r['tp_at_1.0']:6.2f}  SP {r['sp_at_1.0']:6.2f}"
    if "pre_sp" in r:
        line += f"  pre SP {r['pre_sp']:6.2f}"
    print(line)
    for b, d in rep.items():
        print("    %-10s mono %s L %s R %s | >3s mono %s" % (b, d["mono"]["max_0.3_3"], d["L"]["max_0.3_3"], d["R"]["max_0.3_3"],
                                                        d["mono"]["peaks_3_8"][:2]))
json.dump(res, open(out, "w"), indent=1)
print("->", out)
