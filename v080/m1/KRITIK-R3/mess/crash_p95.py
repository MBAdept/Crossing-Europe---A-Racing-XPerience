#!/usr/bin/env python3
"""AU-R2 (M2/M4): the limiter's gain reduction per crash as a distribution – median, p90, p95, max, count > 3 dB –
and the true peak of the Master (Gesamtlautstärke 1.0) per crash, from ana_crash.py results.
usage: crash_p95.py <res.json> [...]"""
import json
import sys

import numpy as np

for p in sys.argv[1:]:
    r = json.load(open(p))
    gr = np.array([row["gr_max"] for row in r["rows"]])
    tp = np.array([row["tp_master_1.0"] for row in r["rows"]])
    print(f"{p.rsplit('/', 1)[-1]}: n {len(gr)} | Begrenzung Median {np.median(gr):.2f} p90 {np.percentile(gr, 90):.2f} "
          f"p95 {np.percentile(gr, 95):.2f} max {gr.max():.2f} dB, > 3 dB: {int((gr > 3.0).sum())} | True Peak max {tp.max():.2f} "
          f"p95 {np.percentile(tp, 95):.2f} Median {np.median(tp):.2f} dBTP | Glas {r.get('glass_share', 0):.2f} | Schichten "
          f"{json.dumps(r.get('heavy_layers'))} Lkw {json.dumps(r.get('truck_db'))}")
