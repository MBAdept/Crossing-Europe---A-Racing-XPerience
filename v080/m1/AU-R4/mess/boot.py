#!/usr/bin/env python3
"""AU-R4: V3 heavy-crash statistic of one or more ana_crash.py results, pooled: p95 of the limiter's gain reduction
(np.percentile as crash_p95.py), crashes > 3 dB, true peak max, and a bootstrap of the p95 at the pooled n and at
n = 60 (standard error, share of resamples with p95 > 3 dB). usage: boot.py <res.json> [...]"""
import json
import sys

import numpy as np

gr = []
tp = []
for p in sys.argv[1:]:
    r = json.load(open(p))
    gr += [row["gr_max"] for row in r["rows"]]
    tp += [row["tp_master_1.0"] for row in r["rows"]]
gr = np.array(gr)
tp = np.array(tp)
rng = np.random.default_rng(4711)
out = {"n": len(gr), "p95": round(float(np.percentile(gr, 95)), 2), "median": round(float(np.median(gr)), 2),
       "max": round(float(gr.max()), 2), "over_3db": int((gr > 3.0).sum()), "tp_max": round(float(tp.max()), 2),
       "tp_over_m1": int((tp > -1.0).sum())}
for n in sorted({len(gr), 60}):
    b = np.array([np.percentile(rng.choice(gr, size=n, replace=True), 95) for _ in range(10000)])
    out[f"boot_n{n}_se"] = round(float(b.std()), 2)
    out[f"boot_n{n}_share_over_3db"] = round(float((b > 3.0).mean()), 3)
print(" + ".join(s.rsplit("/", 1)[-1] for s in sys.argv[1:]), json.dumps(out))
