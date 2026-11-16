#!/usr/bin/env python3
"""Loudness per phase of a mix_speeds.gd recording (central part of each phase) + the logged ducking.
usage: phase_loud.py <wav> [<wav> …]  -> prints a table, writes <wav>.phases.json"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402

SR = alib.SR
SKIP0, SKIP1 = 2.0, 0.8


def phases(path: str) -> dict:
    meta = json.load(open(os.path.splitext(path)[0] + ".json"))
    x = alib.read_audio(path)
    L = alib.Loud(x)
    log = meta["log"]
    out = {"file": os.path.basename(path), "vehicle": meta["vehicle"], "mute": meta.get("mute_buses"), "phases": {}}
    for ph in meta["phases"]:
        t0, t1 = float(ph["t0"]), float(ph["t1"])
        a0, a1 = t0 + SKIP0, t1 - SKIP1
        if ph["name"] in ("lift",):
            a0, a1 = t0 + 0.2, t1 - 0.2
        a, b = int(a0 * SR), min(int(a1 * SR), len(x))
        st = L.short_term(0.1, a, b) if b - a > 3 * SR else L.momentary(0.1, a, b)
        lg = [r for r in log if a0 <= r["t"] <= a1]
        d = {"t0": a0, "t1": a1, "lufs": round(L.ungated(a, b), 2), "st_median": round(float(np.median(st)), 2),
             "st_max": round(float(np.max(st)), 2), "tp": round(alib.true_peak_db(x[a:b]), 2),
             "duck_med": round(float(np.median([r.get("duck", 0.0) for r in lg])), 3) if lg else None,
             "car_plan_med": round(float(np.median([r.get("car", -200.0) for r in lg])), 2) if lg else None,
             "kmh": ph.get("kmh"), "throttle": ph.get("throttle")}
        if lg and "music_t" in lg[0]:
            d["music_t"] = [lg[0]["music_t"], lg[-1]["music_t"]]
            d["pos"] = [lg[0].get("pos"), lg[-1].get("pos")]
        out["phases"][ph["name"]] = d
    out["integrated"] = round(L.integrated(), 2)
    return out


def main() -> int:
    for p in sys.argv[1:]:
        r = phases(p)
        json.dump(r, open(p + ".phases.json", "w"), indent=1)
        print(f"{r['file']} ({r['vehicle']}, stumm: {','.join(r['mute'] or [])}) integriert {r['integrated']} LUFS")
        for n, d in r["phases"].items():
            extra = f" music_t {d['music_t'][0]:.1f}-{d['music_t'][1]:.1f}" if "music_t" in d else ""
            print(f"  {n:10s} {d['t0']:5.1f}-{d['t1']:5.1f}  {d['lufs']:7.2f} LUFS  ST med {d['st_median']:7.2f} max {d['st_max']:7.2f}"
                  f"  TP {d['tp']:6.2f}  duck {d['duck_med']}  car_plan {d['car_plan_med']}{extra}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
