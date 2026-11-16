#!/usr/bin/env python3
"""FLACKER-NACHSTELLEN: per-10-km statistics of an instrumented drive (probe_drive.gd: <prefix>_frames.jsonl,
_events.jsonl, _summary.json; the summary may be missing when a run was cut short).

Per 10 km of the stage counter: level switches of model cars within 80 m of the camera (and within 38-62 m, the band
the user named), lod0<->lod1 switches, switches back and forth within 1 s of view time, frames in which a shown car
carries refused geometry (allocator simulation) / CPU-side uniform mismatches, refusals caught by the Logger
(per frame: "ref"), time the followed car spends inside the lod0/lod1 hysteresis band.

usage: analyze_drive2.py <prefix> [--lod0=40] [--json=out.json]
"""
import json
import os
import sys
from collections import Counter, defaultdict


def main():
    prefix = sys.argv[1]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    lod0 = float(opts.get("lod0", 40))
    frames = []
    with open(prefix + "_frames.jsonl") as f:
        for line in f:
            try:
                frames.append(json.loads(line))
            except json.JSONDecodeError:
                break           # a half-written last line of a cut run
    events = []
    if os.path.exists(prefix + "_events.jsonl"):
        with open(prefix + "_events.jsonl") as f:
            for line in f:
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    break
    summ = {}
    if os.path.exists(prefix + "_summary.json"):
        summ = json.load(open(prefix + "_summary.json"))
    if not frames:
        print("no frames")
        return
    t2km = [(fr["t"], fr["km"]) for fr in frames]

    def km_at(t):
        lo, hi = 0, len(t2km) - 1
        while lo < hi:
            mid = (lo + hi) // 2
            if t2km[mid][0] < t:
                lo = mid + 1
            else:
                hi = mid
        return t2km[lo][1]

    bins = defaultdict(lambda: Counter())
    for fr in frames:
        b = int(fr["km"] // 10) * 10
        c = bins[b]
        c["frames"] += 1
        c["refusals_caught"] += int(fr.get("ref", 0))
        anyr = anyn = anym = False
        for car in fr.get("cars", []):
            if car.get("sh") and car.get("ref", 0) > 0:
                anyr = True
                if car["d"] < 90:
                    anyn = True
            if car.get("sh") and car.get("mm"):
                anym = True
            if car["id"] == fr.get("tg"):
                c["followed_frames"] += 1
                if lod0 * 0.95 <= car["d"] <= lod0 * 1.05:
                    c["followed_in_band"] += 1
                if 35 <= car["d"] <= 65:
                    c["followed_35_65"] += 1
            if "white" in car["s"] and car.get("sh") and car.get("l", "").startswith("lod") and 30 <= car["d"] <= 50:
                c["white_model_frames_30_50m"] += 1
        c["frames_refused_car"] += anyr
        c["frames_refused_car_near90"] += anyn
        c["frames_uniform_mismatch"] += anym
    for e in events:
        if e.get("ev") == "switch":
            b = int(e["km"] // 10) * 10
            c = bins[b]
            c["switches_all"] += 1
            if e["d"] < 80:
                c["switches_near80"] += 1
                if {e["from"], e["to"]} == {"lod0", "lod1"}:
                    c["sw_lod0_lod1"] += 1
                if "white" in e["set"]:
                    c["switches_white_near80"] += 1
            if e.get("followed"):
                c["switches_followed"] += 1
        elif e.get("ev") == "flipflop":
            b = int(km_at(e["t"]) // 10) * 10
            bins[b]["flipflops_1s"] += 1
            if "white" in e.get("set", ""):
                bins[b]["flipflops_white"] += 1
    tot = Counter()
    for c in bins.values():
        tot.update(c)
    km0, km1 = frames[0]["km"], frames[-1]["km"]
    dist = abs(km1 - km0)
    per10 = {k: round(v * 10.0 / dist, 2) for k, v in tot.items()} if dist > 0 else {}
    out = {"prefix": os.path.basename(prefix), "km": [round(km0, 2), round(km1, 2)], "dist_km": round(dist, 2),
           "view_s": frames[-1]["t"], "complete": bool(summ), "summary": {k: summ.get(k) for k in (
               "refusals_caught", "refusal_frames_caught", "refusals_predicted", "alloc_peak", "alloc_mismatch_frames",
               "realloc_errors", "wall_s", "other_errors")},
           "total": dict(tot), "per_10km": per10, "bins": {k: dict(v) for k, v in sorted(bins.items())},
           "first_flipflops": [e for e in events if e.get("ev") == "flipflop"][:6],
           "refused_events": [e for e in events if e.get("ev") == "refused"][:10]}
    txt = json.dumps(out, indent=1)
    if "json" in opts:
        open(opts["json"], "w").write(txt)
    print(txt[:6000])


if __name__ == "__main__":
    main()
