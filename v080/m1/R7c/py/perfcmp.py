#!/usr/bin/env python3
"""R7c: PERF of two run_stage logs side by side (flattened keys; numbers only).  perfcmp.py <mine.log> <base.log>"""
import json
import sys


def perf(path):
    run = {}
    p = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("PERF "):
            p = json.loads(line[5:])
        elif line.startswith("RUN "):
            run = json.loads(line[4:])
    p["RUN"] = run
    return p


def flat(d, pre=""):
    out = {}
    for k, v in d.items():
        key = pre + k
        if isinstance(v, dict):
            out.update(flat(v, key + "."))
        elif isinstance(v, (int, float)) and not isinstance(v, bool):
            out[key] = float(v)
    return out


a = flat(perf(sys.argv[1]))
b = flat(perf(sys.argv[2]))
want = sys.argv[3].split(",") if len(sys.argv) > 3 else None
print("%-44s %12s %12s %8s" % ("Wert", "R7c", "Basis", "R7c/B"))
for k in sorted(set(a) | set(b)):
    if want and not any(w in k for w in want):
        continue
    va, vb = a.get(k), b.get(k)
    r = "" if not va or not vb else "%.2f" % (va / vb)
    print("%-44s %12s %12s %8s" % (k, "-" if va is None else "%.3f" % va, "-" if vb is None else "%.3f" % vb, r))
