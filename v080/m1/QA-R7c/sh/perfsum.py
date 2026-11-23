#!/usr/bin/env python3
"""QA-R7c: table of the PERF / RUN / ERGEBNIS lines of the run_stage logs in m1/QA-R7c/perf."""
import json, glob, os, sys

d = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/perf"
rows = []
for f in sorted(glob.glob(d + "/*.log")):
    tag = os.path.basename(f)[:-4]
    perf = run = erg = None
    errs = 0
    for line in open(f, errors="replace"):
        if line.startswith("PERF "):
            perf = json.loads(line[5:])
        elif line.startswith("RUN "):
            run = json.loads(line[4:])
        elif line.startswith("ERGEBNIS "):
            erg = json.loads(line[9:])
        elif "SCRIPT ERROR" in line or "SHADER ERROR" in line:
            errs += 1
    if perf is None:
        print(tag, "no PERF line")
        continue
    hooks = perf.get("hooks_ms_avg", {})
    hmax = perf.get("hooks_ms_max", {})
    print("%-18s wall %5.0f s  frames %4d  frame med/p95 %6.1f/%6.1f ms  render avg/max %5.2f/%5.2f  build avg/max %5.1f/%5.1f  commit max %5.2f  props hook avg/max %.2f/%.2f  draw %d (shadow %s)  prims %s / shadow %s  err %d  time_s %.1f" % (
        tag, float(run.get("wall_s", 0)) if run else -1, perf.get("frames", 0), perf.get("frame_ms_median", 0), perf.get("frame_ms_p95", 0),
        perf.get("render_ms_avg", 0), perf.get("render_ms_max", 0), perf.get("chunk_build_ms_avg", 0), perf.get("chunk_build_ms_max", 0),
        perf.get("chunk_commit_ms_max", 0), float(hooks.get("props", 0)), float(hmax.get("props", 0)) if isinstance(hmax, dict) else -1,
        perf.get("draw_calls", 0), perf.get("draw_calls_shadow", "?"), perf.get("primitives", "?"), perf.get("primitives_shadow", "?"),
        errs, float(erg.get("time_s", 0)) if erg else -1))
