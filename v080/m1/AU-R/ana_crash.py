#!/usr/bin/env python3
"""AU-R (R5): per-crash peaks found in the audio itself (not by script time: the headless recording can lose time
under load). Events = maxima of the pre signal (MMaster in front of the Modern limiter) at least 1.6 s apart and
above -12 dBFS, paired in order with the marks of crash_gr.gd.
usage: ana_crash.py <post.wav> <pre.f32> <marks.json> [--ceiling=-2.0]"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ana  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith("--")]
ceil = -2.0
for a in sys.argv[1:]:
    if a.startswith("--ceiling="):
        ceil = float(a.split("=", 1)[1])
SR = ana.SR
post = ana.load(args[0])
pre = ana.load(args[1])
marks = json.load(open(args[2]))["marks"]
a = np.max(np.abs(pre), axis=1)
# onsets: the 10-ms sample peak rises 6 dB above the median 10-ms peak of the recording (the bed: engine, road and
# wind peak around -11 dBFS, a crash near 0); events >= 1.6 s apart
F = int(0.010 * SR)
n = len(a) // F
pk = a[:n * F].reshape(n, F).max(axis=1)
pk_db = 20 * np.log10(pk + 1e-12)
bed = float(np.median(pk_db))
ev = []
last = -10 ** 9
for i in range(n):
    if pk_db[i] > bed + 6.0 and i - last > int(1.6 / 0.010):
        ev.append(i * F)
        last = i
rows = []
for k, s in enumerate(ev):
    w = pre[max(s - int(0.05 * SR), 0): s + int(1.2 * SR)]
    j0 = max(s - int(0.1 * SR), 0)
    wp = post[j0: s + int(1.3 * SR)]
    p = ana.sp(w)
    r = {"t_audio": round(s / SR, 2), "pre_sp": round(p, 2), "gr_db": round(max(0.0, p - ceil), 2),
         "post_tp": round(ana.tp(wp), 2) if len(wp) else None}
    if k < len(marks):
        lay = {str(l[0]): l for l in marks[k]["layers"]}
        r["t_script"] = marks[k]["t"]
        hh = lay.get("hit_heavy")
        if hh is not None and len(hh) > 4:
            r["hit_heavy_jit"] = round(float(hh[4]), 2)
            r["hit_heavy_var"] = int(hh[1])
        cr = lay.get("crunch")
        if cr is not None and len(cr) > 4:
            r["crunch_jit"] = round(float(cr[4]), 2)
    rows.append(r)
res = {"events": len(ev), "marks": len(marks), "gr_max_db": max(r["gr_db"] for r in rows) if rows else 0.0,
       "post_tp_max": max(r["post_tp"] for r in rows if r["post_tp"] is not None) if rows else None,
       "gr_median_db": float(np.median([r["gr_db"] for r in rows])) if rows else 0.0, "rows": rows}
print(json.dumps(res, indent=1))
