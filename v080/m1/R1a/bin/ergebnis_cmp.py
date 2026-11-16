#!/usr/bin/env python3
"""Scratch (R1a): compares the ERGEBNIS lines of two run_stage.gd logs (Arcade, Modern); only gfx may differ."""
import json
import sys


def read(path):
    res = perf = None
    errors = []
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("ERGEBNIS "):
            res = json.loads(line[len("ERGEBNIS "):])
        elif line.startswith("PERF "):
            perf = json.loads(line[len("PERF "):])
        elif "SCRIPT ERROR" in line or "Parse Error" in line or line.startswith("FEHLER"):
            errors.append(line.strip())
    return res, perf, errors


a, pa, ea = read(sys.argv[1])
m, pm, em = read(sys.argv[2])
if a is None or m is None:
    print("FEHLER: ERGEBNIS fehlt", sys.argv[1] if a is None else "", sys.argv[2] if m is None else "", ea, em)
    sys.exit(1)
keys = sorted(set(a) | set(m))
diff = [k for k in keys if a.get(k) != m.get(k)]
print("  Schlüssel: %d, verschieden: %s" % (len(keys), diff))
print("  gfx: %r / %r   time: %r / %r   Fehlerzeilen: %d / %d" % (a.get("gfx"), m.get("gfx"), a.get("time"), m.get("time"), len(ea), len(em)))
if pm:
    r = pm.get("renderer", pm)
    print("  Modern PERF: " + json.dumps({k: r.get(k) for k in ("mode", "frames", "render_ms_avg", "render_ms_max", "chunks",
                                                              "chunk_build_ms_avg", "chunk_build_ms_max", "chunk_commit_ms_max", "prepare_ms") if k in r}))
    print("  Modern PERF keys: " + ", ".join(sorted(pm.keys()))[:600])
if pa:
    r = pa.get("renderer", pa)
    print("  Arcade PERF: " + json.dumps({k: r.get(k) for k in ("render_ms_avg", "render_ms_max", "frames") if k in r}))
ok = diff == ["gfx"] and a.get("gfx") == "arcade" and m.get("gfx") == "modern" and not ea and not em
print("  ERGEBNIS-IDENTITAET %s" % ("OK" if ok else "FEHLER"))
sys.exit(0 if ok else 1)
