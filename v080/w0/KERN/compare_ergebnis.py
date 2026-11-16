#!/usr/bin/env python3
"""Scratch helper: compares the ERGEBNIS lines of run_stage.gd logs of two graphics modes (all keys but gfx)."""
import json
import sys


def ergebnis(path):
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("ERGEBNIS "):
            return json.loads(line[len("ERGEBNIS "):])
    return None


ok = True
for stage in sys.argv[2:]:
    a = ergebnis("%s/run_%s_arcade.log" % (sys.argv[1], stage))
    m = ergebnis("%s/run_%s_modern.log" % (sys.argv[1], stage))
    if a is None or m is None:
        print("%s: ERGEBNIS fehlt" % stage)
        ok = False
        continue
    diff = sorted(k for k in set(a) | set(m) if a.get(k) != m.get(k))
    same = sorted(k for k in set(a) & set(m) if a.get(k) == m.get(k))
    print("%s: %d Schlüssel, %d gleich, verschieden: %s (arcade gfx=%s, modern gfx=%s), time_s %s / %s, Reihenfolge der Schlüssel gleich: %s" % (
        stage, len(a), len(same), diff, a.get("gfx"), m.get("gfx"), a.get("time_s"), m.get("time_s"), list(a) == list(m)))
    ok = ok and diff == ["gfx"] and "gfx_fallback" not in m
print("ERGEBNIS-VERGLEICH", "OK" if ok else "FEHLER")
sys.exit(0 if ok else 1)
