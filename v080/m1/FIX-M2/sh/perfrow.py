#!/usr/bin/env python3
"""QA-M2-BILD: one table row per probe drive (frames.csv + samples.jsonl + log), optionally only km in [a, b].
usage: perfrow.py <perf dir> <km_from> <km_to> <name> [<name> ...]"""
import json
import os
import sys

import numpy as np

d = sys.argv[1]
k0 = float(sys.argv[2])
k1 = float(sys.argv[3])
hdr = ("name", "frames", "load_s", "prep/warm/self s", "render avg", "p50", "p95", "p99", "max", "commit-fr p50/p95/max",
       "commit_ms_max", "DC med/max", "tris med/max k", "tex max MB", "RSS max MB", "frame p50 ms", "spikes>3x (on commit)")
print(" | ".join(hdr))
for name in sys.argv[4:]:
    base = os.path.join(d, name)
    try:
        fr = np.genfromtxt(base + "_frames.csv", delimiter=",", names=True, invalid_raise=False)
    except Exception as e:  # noqa
        print(name, "no frames", e)
        continue
    sel = (fr["km"] >= k0) & (fr["km"] <= k1)
    f = fr[sel]
    if f.size == 0:
        print(name, "no frames in range")
        continue
    fms = f["frame_ms"]
    rms = f["render_ms"]
    com = f["commit"] > 0
    sm = []
    if os.path.exists(base + "_samples.jsonl"):
        for line in open(base + "_samples.jsonl"):
            try:
                s = json.loads(line)
            except Exception:  # noqa
                continue
            if k0 <= float(s.get("km", -1)) <= k1:
                sm.append(s)

    def st(key, fn):
        v = [s[key] for s in sm if isinstance(s.get(key), (int, float)) and s.get(key, -1) >= 0]
        return fn(v) if v else -1

    load = prep = warm = selft = commit_max = -1
    log = base + ".log"
    if os.path.exists(log):
        for line in open(log, errors="replace"):
            if line.startswith("QA-LIVE") and load < 0:
                load = float(line.split("=")[1])
            if line.startswith("PERF ") or line.startswith("PERF-STAGE "):
                p = json.loads(line.split(" ", 1)[1])
                prep = p.get("prepare_ms", -1)
                warm = p.get("prewarm_ms", -1)
                selft = p.get("selftest_ms", -1)
                commit_max = p.get("chunk_commit_ms_max", -1)
    med = np.median(fms)
    sp = fms > 3 * med
    row = [name, str(f.size), "%.1f" % load,
           "%.1f/%.1f/%.2f" % (prep / 1000.0, warm / 1000.0, selft / 1000.0) if isinstance(prep, (int, float)) and prep >= 0 else "-",
           "%.2f" % rms.mean() if rms.max() >= 0 else "-", "%.2f" % np.percentile(rms, 50), "%.2f" % np.percentile(rms, 95),
           "%.2f" % np.percentile(rms, 99), "%.1f" % rms.max(),
           ("%.2f/%.1f/%.1f" % (np.percentile(rms[com], 50), np.percentile(rms[com], 95), rms[com].max())) if com.any() else "-",
           "%.1f" % commit_max if isinstance(commit_max, (int, float)) else "-",
           "%s/%s" % (st("draw_calls", lambda v: int(np.median(v))), st("draw_calls", max)),
           "%s/%s" % (st("primitives", lambda v: int(np.median(v) / 1000)), st("primitives", lambda v: int(max(v) / 1000))),
           "%.0f" % st("tex_mb", max), "%.0f" % st("rss_mb", max), "%.0f" % med,
           "%d (%d)" % (sp.sum(), (sp & com).sum())]
    print(" | ".join(row))
