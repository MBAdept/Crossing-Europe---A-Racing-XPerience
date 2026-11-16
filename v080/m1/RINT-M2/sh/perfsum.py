#!/usr/bin/env python3
"""RINT-M2: summary of PERF/ERGEBNIS/RUN lines of run_stage logs.
usage: perfsum.py log [log ...]"""
import json
import sys

KEYS = ["render_ms_avg", "render_ms_max", "chunk_commit_ms_max", "chunk_build_ms_avg", "chunk_build_ms_max", "draw_calls",
        "primitives", "texture_mem_mb", "video_mem_mb", "static_mem_mb", "frame_ms_median"]
for p in sys.argv[1:]:
    perf, erg, run = {}, {}, {}
    for line in open(p, errors="replace"):
        if line.startswith("PERF "):
            perf = json.loads(line[5:])
        elif line.startswith("ERGEBNIS "):
            erg = json.loads(line[9:])
        elif line.startswith("RUN "):
            run = json.loads(line[4:])
    print("==", p.split("/")[-1])
    flat = {}

    def walk(d, pre=""):
        for k, v in d.items():
            if isinstance(v, dict):
                walk(v, pre + k + ".")
            else:
                flat[pre + k] = v
    walk(perf)
    for k in sorted(flat):
        if any(s in k for s in ("render", "commit", "collect", "draw", "primitive", "mem", "build", "frame", "lowered", "fps")):
            print("  %s = %s" % (k, flat[k]))
    st = perf.get("streamer", {})
    if isinstance(st, dict) and "collect_by" in st:
        print("  collect_by:", json.dumps(st["collect_by"]))
    print("  ERGEBNIS:", {k: erg.get(k) for k in ("distance_km", "avg_speed_kmh", "collisions", "stage_time_s", "time_s", "aborted")})
    print("  RUN:", run)
