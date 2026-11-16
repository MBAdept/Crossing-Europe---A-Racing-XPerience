#!/usr/bin/env python3
"""Summarise QA-BILD probe drives: frames.csv + samples.jsonl + log (QA-SUMMARY, PERF).
usage: perfsum.py <perf dir> <name> [<name> ...]"""
import json
import os
import sys

import numpy as np

d = sys.argv[1]
for name in sys.argv[2:]:
    base = os.path.join(d, name)
    print("=" * 100)
    print(name)
    try:
        fr = np.genfromtxt(base + "_frames.csv", delimiter=",", names=True)
    except Exception as e:  # noqa
        print("  no frames", e)
        continue
    if fr.size == 0:
        print("  empty")
        continue
    fms = fr["frame_ms"]
    rms = fr["render_ms"]
    com = fr["commit"]
    print("  frames %d  wall %.0f s  km %.1f  sim %.0f s" % (fr.size, fr["t_wall_s"][-1], fr["km"][-1], fr["sim_s"][-1]))
    for lab, a in (("frame_ms", fms), ("render_ms", rms)):
        print("  %-10s p50 %.2f  p90 %.2f  p95 %.2f  p99 %.2f  max %.2f  mean %.2f" % (lab, *np.percentile(a, [50, 90, 95, 99, 100]), a.mean()))
    c = com > 0
    if c.any():
        print("  render_ms on commit frames (%d): p50 %.2f p95 %.2f max %.2f | other frames: p50 %.2f p95 %.2f max %.2f" % (
            c.sum(), *np.percentile(rms[c], [50, 95, 100]), *np.percentile(rms[~c], [50, 95, 100])))
        print("  frame_ms on commit frames: p50 %.1f p95 %.1f | other: p50 %.1f p95 %.1f" % (
            *np.percentile(fms[c], [50, 95]), *np.percentile(fms[~c], [50, 95])))
    med = np.median(fms)
    sp = fms > 3 * med
    print("  frames > 3x median (%.1f ms): %d (%.2f %%), of which on commit frames %d" % (med, sp.sum(), 100 * sp.mean(), (sp & c).sum()))
    big = np.argsort(rms)[-5:][::-1]
    print("  top render_ms frames:", ", ".join("#%d %.1f ms (km %.2f, commit %d)" % (i, rms[i], fr["km"][i], com[i]) for i in big))
    sm = []
    if os.path.exists(base + "_samples.jsonl"):
        for line in open(base + "_samples.jsonl"):
            try:
                sm.append(json.loads(line))
            except Exception:  # noqa
                pass
    if sm:
        keys = ["rss_mb", "static_mb", "objects", "resources", "nodes", "orphans", "tex_mb", "buf_mb", "vid_mb", "draw_calls",
                "primitives", "chunks", "instances", "vehicles", "vehicle_instances", "load1"]
        def stat(k):
            v = [s.get(k, -1) for s in sm if isinstance(s.get(k, -1), (int, float)) and s.get(k, -1) >= 0]
            if not v:
                return "-"
            return "first %s  min %s  max %s  last %s" % (v[0], min(v), max(v), v[-1])
        for k in keys:
            print("  %-18s %s" % (k, stat(k)))
    log = base + ".log"
    if os.path.exists(log):
        for line in open(log, errors="replace"):
            if line.startswith("QA-LIVE") or line.startswith("QA-SPIKE") and "render_ms=" in line:
                print("  " + line.strip()[:300])
            if line.startswith("PERF "):
                p = json.loads(line[5:])
                print("  PERF preset=%s render_ms_avg=%.3f max=%.2f prepare_ms=%s prewarm_ms=%s selftest_ms=%s commit_ms_max=%s tex_mem_mb=%.1f draw_calls=%s prims=%s warmup_nodes=%s vehicle_us_avg=%s flare_us_avg=%s" % (
                    p.get("preset"), p.get("render_ms_avg", 0), p.get("render_ms_max", 0), p.get("prepare_ms"), p.get("prewarm_ms"),
                    p.get("selftest_ms"), p.get("chunk_commit_ms_max"), p.get("tex_mem_mb", 0), p.get("draw_calls"), p.get("primitives"),
                    p.get("warmup_nodes"), p.get("vehicle_us_avg"), p.get("flare_us_avg")))
                print("  PERF load=", json.dumps(p.get("load", {}))[:300])
            if line.startswith("ERGEBNIS"):
                print("  ERGEBNIS present")
