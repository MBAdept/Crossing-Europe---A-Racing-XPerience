#!/usr/bin/env python3
"""FLACKER-NACHSTELLEN: statistics of an instrumented drive (probe_drive.gd output <prefix>_frames.jsonl,
<prefix>_events.jsonl, <prefix>_summary.json).

Per 10 km: level switches of cars within 80 m of the camera, switches back and forth within 1 s, frames in which a
shown car within 160 m / 90 m carries refused geometry (allocator simulation), frames with CPU-side uniform mismatches,
refusals caught vs predicted. Also the followed car: time spent within the hysteresis band of the lod0/lod1 switch.

usage: analyze_drive.py <prefix> [--lod0=40]
"""
import json
import sys
from collections import Counter, defaultdict


def main():
    prefix = sys.argv[1]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    lod0 = float(opts.get("lod0", 40))
    frames = [json.loads(l) for l in open(prefix + "_frames.jsonl")]
    events = [json.loads(l) for l in open(prefix + "_events.jsonl")]
    summ = json.load(open(prefix + "_summary.json"))
    if not frames:
        print("no frames")
        return
    km0, km1 = frames[0]["km"], frames[-1]["km"]
    dist_km = abs(km1 - km0)
    per10 = 10.0 / dist_km if dist_km > 0 else 0.0
    sw = [e for e in events if e.get("ev") == "switch"]
    sw_near = [e for e in sw if e["d"] < 80]
    ff = [e for e in events if e.get("ev") == "flipflop"]
    ref_ev = [e for e in events if e.get("ev") == "refused"]
    mism = [e for e in events if e.get("ev") == "alloc_mismatch"]
    ref_car_frames = 0
    ref_car_frames_near = 0
    ref_car_frames_follow = 0
    mm_frames = 0
    band_frames = 0
    follow_frames = 0
    ref_sets = Counter()
    lod_pairs = Counter()
    gaps = []
    for fr in frames:
        anyr = False
        anyn = False
        anyf = False
        anym = False
        for c in fr.get("cars", []):
            if c.get("sh") and c.get("ref", 0) > 0:
                anyr = True
                ref_sets[(c["s"], c["l"])] += 1
                if c["d"] < 90:
                    anyn = True
                if c["id"] == fr.get("tg"):
                    anyf = True
            if c.get("sh") and c.get("mm"):
                anym = True
            if c["id"] == fr.get("tg"):
                follow_frames += 1
                if lod0 * 0.95 <= c["d"] <= lod0 * 1.05:
                    band_frames += 1
                gaps.append(c["d"])
        ref_car_frames += anyr
        ref_car_frames_near += anyn
        ref_car_frames_follow += anyf
        mm_frames += anym
    for e in sw_near:
        lod_pairs[(e["from"], e["to"])] += 1
    out = {
        "prefix": prefix, "km": [km0, km1], "dist_km": round(dist_km, 2), "frames": len(frames),
        "view_s": frames[-1]["t"],
        "refusals_caught": summ.get("refusals_caught"), "refusals_predicted": summ.get("refusals_predicted"),
        "alloc_mismatch_frames": summ.get("alloc_mismatch_frames"), "alloc_peak": summ.get("alloc_peak"),
        "realloc_errors": summ.get("realloc_errors"),
        "switches_near_80m": len(sw_near), "switches_near_per10km": round(len(sw_near) * per10, 1),
        "switch_pairs_near": {"%s->%s" % k: v for k, v in lod_pairs.items()},
        "flipflops_1s": len(ff), "flipflops_per10km": round(len(ff) * per10, 1),
        "frames_refused_car": ref_car_frames, "frames_refused_car_near90": ref_car_frames_near,
        "frames_refused_followed": ref_car_frames_follow,
        "frames_refused_car_per10km": round(ref_car_frames * per10, 1),
        "frames_uniform_mismatch": mm_frames,
        "refused_set_levels": {"%s|%s" % k: v for k, v in ref_sets.most_common(20)},
        "followed_frames": follow_frames, "followed_in_band_frames": band_frames,
        "refusal_events": len(ref_ev), "refusal_tags": dict(Counter(t for e in ref_ev for t in e.get("tags", {})).most_common(15)),
        "first_mismatches": mism[:5],
    }
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
