#!/usr/bin/env python3
"""KRITIK-R3: compare kc_trigger.gd outputs of AU-R3 (KRITIK-R2-CODE res/trigger_all.log) and AU-R4 (own run):
plans with identical output, old-town shares before/after per arrival, Kiel-Hamburg."""
import json, sys
def load(p):
    plans = {}
    for ln in open(p, encoding="utf-8", errors="replace"):
        if ln.startswith("PLAN "):
            d = json.loads(ln[5:])
            plans[(d["stage"], d["from"])] = d
    return plans
a = load(sys.argv[1]); b = load(sys.argv[2])
same = [k for k in a if k in b and a[k] == b[k]]
print("plans", len(a), len(b), "identical", len(same))
def heard(c):
    st = c["street_m"]; s = c["stone_m"]
    return (c["street_cob_m"] + c["stone_cob_m"]) / (st + s) if st + s > 0 else None
diff = []
for k in sorted(a):
    if k not in b or a[k] == b[k]:
        continue
    ca, cb = a[k]["centre"], b[k]["centre"]
    pa = "".join("P" if a[k]["pattern"][x] else "-" for x in sorted(a[k]["pattern"], key=int))
    pb = "".join("P" if b[k]["pattern"][x] else "-" for x in sorted(b[k]["pattern"], key=int))
    keys = [x for x in set(a[k]) | set(b[k]) if a[k].get(x) != b[k].get(x)]
    ha, hb = heard(ca), heard(cb)
    print(f"  {k[0]:28s} from {k[1]:14s} to {a[k]['to']:12s} heard {ha if ha is None else round(ha,3)} -> {hb if hb is None else round(hb,3)}  {pa} -> {pb}  differing keys {sorted(keys)}")
for k in sorted(a):
    if a[k]["to"] == "hamburg" or a[k]["from"] == "hamburg" and a[k]["to"] == "kiel":
        print("  KH", k, "identical" if a[k] == b.get(k) else "DIFFERENT")
