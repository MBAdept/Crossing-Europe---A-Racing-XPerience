#!/usr/bin/env python3
"""R5: key numbers of the PERF / RUN / ERGEBNIS lines of tools/perf.sh logs.  perfsum.py <log>…"""
import json, sys

KEYS = ["preset", "frames", "frame_ms_median", "render_ms_avg", "render_ms_max", "chunk_commit_ms_max", "chunk_build_ms_max",
        "draw_calls", "draw_calls_shadow", "primitives", "primitives_shadow", "tex_mem_mb", "quality_lowered"]
for path in sys.argv[1:]:
    perf, run, res = {}, {}, {}
    errors = 0
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("PERF "):
            perf = json.loads(line[5:])
        elif line.startswith("RUN "):
            run = json.loads(line[4:])
        elif line.startswith("ERGEBNIS "):
            res = json.loads(line[9:])
        elif "SCRIPT ERROR" in line or "SHADER ERROR" in line or "Shader compilation failed" in line:
            errors += 1
    print("== %s" % path)
    print("   " + ", ".join("%s=%s" % (k, perf.get(k)) for k in KEYS))
    print("   run: %s" % json.dumps(run))
    print("   ergebnis: aborted=%s km=%s time_s=%s fuel_stops=%s  script/shader errors: %d" % (
        res.get("aborted"), res.get("distance_km", res.get("km")), res.get("time_s"), res.get("fuel_stops"), errors))
