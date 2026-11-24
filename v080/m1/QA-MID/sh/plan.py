#!/usr/bin/env python3
"""QA-MID: the run plan – one line per run: tag stage from hour weather graphics preset shot-km-list.
Main route Kiel – Nürnberg in seven conditions (Modern, Hoch), the Frankfurt route's own stages in two, Arcade once
per main stage (simulation digest against Modern 12:00)."""
import json, sys
W = sys.argv[1]
n = json.load(open(W + "/data/network.json"))
st = {s["id"]: s for s in n["stages"]}
MAIN = ["kiel_hamburg", "hamburg_hannover", "hannover_kassel", "kassel_wuerzburg", "wuerzburg_nuernberg"]
ALT = ["hamburg_bremen", "bremen_dortmund", "dortmund_frankfurt", "frankfurt_wuerzburg"]
COND = [("t08", 8, "normal"), ("t12", 12, "normal"), ("t1930", 19.5, "normal"), ("t22", 22, "normal"),
        ("r12", 12, "rain"), ("r22", 22, "rain"), ("s12", 12, "snow")]
def shots(s):
    L = float(s["length_km"])
    ks = set([1.5] + [float(k) for k in range(15, int(L) - 2, 15)] + [round(L - 1.5, 1)])
    for f in s.get("fuel_stations_km", []):
        if f.get("dir") == "fwd" and f["km"] < L - 1:
            ks.add(round(float(f["km"]) - 0.4, 1))
    for t in s.get("tunnels", []):
        k = float(t.get("km", 0)); ln = float(t.get("length_km", 1))
        ks.update([round(k - 0.3, 1), round(k + ln * 0.5, 1), round(k + ln + 0.2, 1)])
    return ",".join("%.1f" % k for k in sorted(ks) if 0 < k < L)
for sid in MAIN:
    s = st[sid]
    for tag, h, w in COND:
        print(f"{sid}_{tag} {sid} {s['from']} {h} {w} modern high {shots(s)}")
    print(f"{sid}_t12_arcade {sid} {s['from']} 12 normal arcade high -")
for sid in ALT:
    s = st[sid]
    for tag, h, w in [("t12", 12, "normal"), ("r22", 22, "rain")]:
        print(f"{sid}_{tag} {sid} {s['from']} {h} {w} modern high {shots(s)}")
