#!/usr/bin/env python3
"""Checks a leistungstest.json against the format of the contract §4.8 (version 1) and prints a summary.
Usage: bench_check.py <file.json> [<second file that must be identical>]"""
import json
import math
import sys

p = sys.argv[1]
d = json.load(open(p))
errs = []
for k in ["version", "date", "adapter", "api", "tier", "preset", "quality", "resolution", "scenes", "suggested_preset"]:
    if k not in d:
        errs.append("fehlt: " + k)
if d.get("version") != 1:
    errs.append("version %r" % d.get("version"))
q = d.get("quality", {})
for k in ["shadows", "details", "scale", "aa", "effects"]:
    if k not in q:
        errs.append("quality fehlt " + k)
res = d.get("resolution", [])
if not (isinstance(res, list) and len(res) == 2 and all(isinstance(v, (int, float)) and v > 0 for v in res)):
    errs.append("resolution %r" % (res,))
if d.get("suggested_preset") not in ("deck", "low", "medium", "high", "custom", ""):
    errs.append("suggested_preset %r" % d.get("suggested_preset"))
scenes = d.get("scenes", [])
if not scenes:
    errs.append("keine Szenen")
for s in scenes:
    for k in ["id", "avg_fps", "low1_fps", "frame_ms_p95", "frame_ms_p99", "script_ms", "draw_calls", "primitives"]:
        if k not in s:
            errs.append("%s: fehlt %s" % (s.get("id"), k))
        elif k != "id" and not (isinstance(s[k], (int, float)) and math.isfinite(s[k]) and s[k] >= 0):
            errs.append("%s: %s = %r" % (s.get("id"), k, s[k]))
    if s.get("avg_fps", 0) <= 0 or s.get("frames", 1) <= 0:
        errs.append("%s: keine Bilder gemessen" % s.get("id"))
    if s.get("low1_fps", 0) > s.get("avg_fps", 0) + 1e-6:
        errs.append("%s: 1%%-low > Mittel" % s.get("id"))
    if s.get("frame_ms_p99", 0) + 1e-6 < s.get("frame_ms_p95", 0):
        errs.append("%s: p99 < p95" % s.get("id"))
    if s.get("draw_calls", 0) <= 0:
        errs.append("%s: draw_calls 0 (Zähler?)" % s.get("id"))
for k in ["fallback", "aborted", "error", "renderer_stub"]:
    if d.get(k):
        errs.append("%s = %r" % (k, d.get(k)))
print("DATEI", p)
print("  adapter=%s api=%s tier=%s preset=%s quality=%s resolution=%s" % (d.get("adapter"), d.get("api"), d.get("tier"),
      d.get("preset"), json.dumps(q), res))
for s in scenes:
    print("  %-20s avg %.1f fps  1%%low %.1f  p95 %.1f ms  p99 %.1f ms  script %.2f ms  draws %s (+%s Schatten)  prims %s  prepare %s s  frames %s" % (
        s.get("id"), s.get("avg_fps", 0), s.get("low1_fps", 0), s.get("frame_ms_p95", 0), s.get("frame_ms_p99", 0),
        s.get("script_ms", 0), s.get("draw_calls"), s.get("draw_calls_shadow"), s.get("primitives"), s.get("prepare_s"), s.get("frames")))
print("  suggested_preset=%s suggested_mode=%s verdict=%s worst=%s target_ms=%s vsync=%s stub=%s" % (
    d.get("suggested_preset"), d.get("suggested_mode"), d.get("verdict"), d.get("worst_scene"), d.get("target_ms"),
    d.get("vsync"), d.get("renderer_stub")))
if len(sys.argv) > 2:
    d2 = json.load(open(sys.argv[2]))
    print("  zweite Datei identisch:", d2 == d)
    if d2 != d:
        errs.append("user://leistungstest.json != --bench-out")
print("FORMAT", "OK" if not errs else "FEHLER: " + "; ".join(errs))
