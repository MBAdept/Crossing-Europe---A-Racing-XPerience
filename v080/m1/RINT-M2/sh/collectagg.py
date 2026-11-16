#!/usr/bin/env python3
"""RINT-M2: collect() time per builder over all PERF lines of stage logs.  usage: collectagg.py log [log ...]"""
import json
import re
import sys

for p in sys.argv[1:]:
    agg = {}
    nlines = 0
    cmax = 0.0
    for line in open(p, errors="replace"):
        i = line.find('"streamer":{')
        i = line.find('"collect_by":', i) if i >= 0 else -1
        if i < 0:
            continue
        nlines += 1
        s = line[i + len('"collect_by":'):]
        depth = 0
        j = 0
        for j, ch in enumerate(s):
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    break
        cb = json.loads(s[:j + 1])
        for k, v in cb.items():
            a = agg.setdefault(k, {"max": 0.0, "n": 0, "sum": 0.0})
            a["max"] = max(a["max"], v["max_ms"])
            a["n"] += v["n"]
            a["sum"] += v["avg_ms"] * v["n"]
        m = re.search(r'"collect_ms_max":([0-9.]+)', line)
        if m:
            cmax = max(cmax, float(m.group(1)))
    print("== %s: %d PERF-Zeilen, collect gesamt max %.3f ms" % (p.split("/")[-1], nlines, cmax))
    for k, a in sorted(agg.items(), key=lambda kv: -kv[1]["max"])[:8]:
        print("   %-10s max %.3f ms  avg %.3f ms  n %d" % (k, a["max"], a["sum"] / max(a["n"], 1), a["n"]))
