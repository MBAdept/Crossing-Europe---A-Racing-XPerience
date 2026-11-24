#!/usr/bin/env python3
"""QA-MID: PERF of every run as a table (llvmpipe: absolute times are no measure for a GPU; spikes and counts are)."""
import json, os, sys, glob
Q = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = []
for f in sorted(glob.glob(Q + "/runs/*.log")):
    tag = os.path.basename(f)[:-4]
    perf = err = None
    for ln in open(f, errors="replace"):
        if ln.startswith("PERF "):
            perf = json.loads(ln[5:])
        elif ln.startswith("ERRORS "):
            err = ln.split(" ", 1)[1].strip()
    if not perf:
        rows.append((tag, "kein PERF")); continue
    hm = perf.get("hooks_ms_max", {})
    top = sorted(hm.items(), key=lambda kv: -kv[1])[:3]
    ld = perf.get("load", {})
    st = perf.get("streamer", {}) if isinstance(perf.get("streamer"), dict) else {}
    co = st.get("corridor", {})
    rows.append((tag, "sync %4d / %4.1f ms  frames %d  med %.0f ms  p95 %.0f  build max %.1f  commit max %.1f  collect max %.1f  draw %s  inst %s  | max: %s | %s" % (
        co.get("sync_calls", 0), co.get("sync_ms_max", 0), perf.get("frames", 0), perf.get("frame_ms_median", 0), perf.get("frame_ms_p95", 0), perf.get("chunk_build_ms_max", 0),
        ld.get("commit_ms_max", 0), ld.get("collect_ms_max", 0), perf.get("draw_calls"), perf.get("instances"),
        ", ".join("%s %.1f" % kv for kv in top), err)))
for r in rows:
    print("%-34s %s" % r)
