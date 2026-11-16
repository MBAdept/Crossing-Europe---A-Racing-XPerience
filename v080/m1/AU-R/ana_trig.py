#!/usr/bin/env python3
"""AU-R: joints per bridge and right-side rumble beside fuel lanes from trigger_log2.gd logs.
usage: ana_trig.py <log> [<log> …]"""
import json
import sys

out = {}
for path in sys.argv[1:]:
    evs = []
    summary = {}
    rumble_fuel = []
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("EV "):
            evs.append(json.loads(line[3:]))
        elif line.startswith("SUMMARY "):
            summary = json.loads(line[8:])
        elif line.startswith("RUMBLE_FUEL "):
            rumble_fuel.append(json.loads(line[12:]))
    bridges = []
    for b in summary.get("bridges", []):
        z0, z1 = float(b["z0"]), float(b["z1"])
        js = [e for e in evs if e.get("name") == "joint" and z0 - 0.5 <= float(e["z"]) <= z1 + 0.5]
        bridges.append({"type": b["type"], "km0": b["km0"], "km1": b["km1"], "length_m": round(z1 - z0, 1),
                        "joints": len(js), "decks": sorted({str(e.get("deck")) for e in js}),
                        "z_rel": [round(float(e["z"]) - z0, 1) for e in js]})
    counts = summary.get("counts", {})
    res = {"bridges": bridges, "frames_rumble_r": counts.get("frames_rumble_r", 0),
           "frames_rumble_r_fuel_lane": counts.get("frames_rumble_r_fuel_lane", 0),
           "rumble_fuel_km": sorted({round(float(r["km"]), 2) for r in rumble_fuel})[:12],
           "frames": summary.get("frames"), "km_end": summary.get("km")}
    out[path.rsplit("/", 1)[-1]] = res
    print(path.rsplit("/", 1)[-1], json.dumps(res, ensure_ascii=False))
