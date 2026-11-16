#!/usr/bin/env python3
"""KRITIK-R2-MESS: capture plans (same segment definitions as KRITIK-R / AU-R2 plans A and B)."""
import json
import os

D = os.path.dirname(os.path.abspath(__file__))
ROAD = ["MEngine", "MEngineFx", "MWind"]


def seg(name, km, kmh, paving, mute=(), seconds=20.0, throttle=0.35, **kw):
    s = {"name": name, "km": km, "kmh": kmh, "throttle": throttle, "x": 1.875, "mute": list(mute), "seconds": seconds,
         "paving": paving}
    s.update(kw)
    return s


B = [seg("c_asph130_road", 15.0, 130.0, "asphalt", ROAD, nd=True),
     seg("c_asph130_full", 15.0, 130.0, "asphalt", nd=True),
     seg("c_conc130_road", 42.0, 130.0, "concrete", ROAD, nd=True),
     seg("c_conc130_tyre", 42.0, 130.0, "concrete", ROAD, nd=True, noslab=True),
     seg("c_conc130_slab", 42.0, 130.0, "concrete", ROAD, nd=True, slabonly=True),
     seg("c_conc130_full", 42.0, 130.0, "concrete", nd=True),
     seg("c_cobbles50_road", 87.3, 50.0, "cobbles", ROAD, throttle=0.25, nd=True),
     seg("c_cobbles50_full", 87.3, 50.0, "cobbles", throttle=0.25, nd=True)]
S = [seg(f"s_slab{v}", 42.0, float(v), "concrete", ROAD, seconds=15.0, nd=True, slabonly=True,
         throttle=0.35 if v <= 130 else 0.5) for v in (110, 130, 140, 150, 160, 170, 200)]
A = [seg("asph130_full", 15.0, 130.0, "asphalt"),
     seg("cobbles50_full", 87.3, 50.0, "cobbles", throttle=0.25),
     seg("conc130_noslab_full", 42.0, 130.0, "concrete", noslab=True),
     seg("conc130_full", 42.0, 130.0, "concrete"),
     seg("asph130_road", 15.0, 130.0, "asphalt", ROAD),
     seg("cobbles50_road", 87.3, 50.0, "cobbles", ROAD, throttle=0.25),
     seg("conc130_noslab_road", 42.0, 130.0, "concrete", ROAD, noslab=True)]
V = [seg(f"conc200_r{i}", 42.0, 200.0, "concrete", seconds=60.0, throttle=0.6) for i in range(4)] + \
    [seg("conc170_60", 42.0, 170.0, "concrete", seconds=60.0, throttle=0.5),
     seg("asph200_60", 20.0, 200.0, "asphalt", seconds=60.0, throttle=0.6),
     seg("vmax_full", 15.0, -1.0, "asphalt", seconds=15.0, throttle=1.0)]
for nm, segs in (("B", B), ("S", S), ("A", A), ("V", V)):
    json.dump({"segments": segs}, open(os.path.join(D, f"plan_m{nm}.json"), "w"), indent=1)
    print(nm, len(segs), sum(s["seconds"] + 2.5 for s in segs), "s")
