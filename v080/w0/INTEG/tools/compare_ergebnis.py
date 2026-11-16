#!/usr/bin/env python3
"""Integration helper (not part of the repository): compares the ERGEBNIS lines of run_stage.gd logs.

Usage: compare_ergebnis.py <log dir> <stage>...
For every stage the four logs run_<stage>_g-<gfx>_s-<sound>.log are read. Expected: every key equal to the
reference run (Arcade picture, Arcade sound) except "gfx", which must name the graphics mode of the run; no
"gfx_fallback" anywhere.
"""
import json
import sys

COMBOS = [("arcade", "arcade"), ("modern", "arcade"), ("arcade", "modern"), ("modern", "modern")]


def ergebnis(path):
    try:
        for line in open(path, encoding="utf-8", errors="replace"):
            if line.startswith("ERGEBNIS "):
                return json.loads(line[len("ERGEBNIS "):])
    except OSError:
        pass
    return None


def main():
    ok = True
    for stage in sys.argv[2:]:
        ref = ergebnis("%s/run_%s_g-arcade_s-arcade.log" % (sys.argv[1], stage))
        if ref is None:
            print("%s: ERGEBNIS des Referenzlaufs fehlt" % stage)
            ok = False
            continue
        print("%s: Referenz (Arcade-Bild, Arcade-Klang) %d Schlüssel, time_s %s, gfx %s" % (
            stage, len(ref), ref.get("time_s"), ref.get("gfx")))
        ok = ok and ref.get("gfx") == "arcade"
        for gfx, snd in COMBOS[1:]:
            res = ergebnis("%s/run_%s_g-%s_s-%s.log" % (sys.argv[1], stage, gfx, snd))
            if res is None:
                print("  Bild %-6s Klang %-6s: ERGEBNIS fehlt" % (gfx, snd))
                ok = False
                continue
            diff = sorted(k for k in set(ref) | set(res) if ref.get(k) != res.get(k))
            want = ["gfx"] if gfx != "arcade" else []
            good = diff == want and res.get("gfx") == gfx and "gfx_fallback" not in res and list(ref) == list(res)
            print("  Bild %-6s Klang %-6s: %d Schlüssel, verschieden %s, gfx %s, time_s %s, Reihenfolge gleich %s -> %s" % (
                gfx, snd, len(res), diff, res.get("gfx"), res.get("time_s"), list(ref) == list(res),
                "OK" if good else "FEHLER"))
            ok = ok and good
    print("ERGEBNIS-VERGLEICH", "OK" if ok else "FEHLER")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
