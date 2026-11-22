"""Summarise gates/perf_<tree>_<stage>_<preset>.log: frame median/p95, draw calls, primitives, chunk build max, collect
max, wall time.  usage: perfsum.py <gates dir>"""
import glob
import json
import os
import sys

G = sys.argv[1]
rows = []
for p in sorted(glob.glob(G + "/perf_*_*.log")):
    name = os.path.basename(p)[5:-4]
    perf = None
    run = None
    for line in open(p, errors="replace"):
        if line.startswith("PERF "):
            try:
                perf = json.loads(line[5:])
            except ValueError:
                pass
        elif line.startswith("RUN "):
            try:
                run = json.loads(line[4:])
            except ValueError:
                pass
    if perf is None:
        print("%-36s kein PERF" % name)
        continue
    st = perf.get("streamer", {})
    cb = st.get("collect_by", {}) if isinstance(st, dict) else {}
    cmax = max([v.get("max_ms", 0.0) for v in cb.values()] or [0.0])
    cworst = max(cb.items(), key=lambda kv: kv[1].get("max_ms", 0.0))[0] if cb else "-"
    print("%-36s frames %5d  median %7.1f ms  p95 %7.1f ms  draw %4s  prim %7s  build max %6.1f  collect max %5.2f (%s)  wall %s s  ok %s" % (
        name, perf.get("frames", 0), perf.get("frame_ms_median", 0), perf.get("frame_ms_p95", 0),
        perf.get("draw_calls", "-"), perf.get("primitives", "-"), perf.get("chunk_build_ms_max", 0), cmax, cworst,
        round(run.get("wall_s", 0)) if run else "-", run.get("ok") if run else "-"))
