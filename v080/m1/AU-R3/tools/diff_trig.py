#!/usr/bin/env python3
"""AU-R3: do two trigger logs (trigger_log2.gd) of the same stage show the same feed? The per-second rows are taken
when the stage clock passes a second in a frame, so their positions jitter by a frame between runs (the feed is the
same – stage_compare.gd proves that step by step). Compared here:
  - ERGEBNIS and the SUMMARY counts,
  - every event by what fixes it on the road (name, z, kind, side, set, deck – not the car's distance or the time),
  - the rows counted per feed category (paving, surface left/right, zone, deck),
  - the rows themselves (strict; reported, jitter expected).
usage: diff_trig.py <before.log> <after.log>"""
import collections
import json
import sys


def load(path):
    rows, evs, res, summ = [], [], None, None
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("ROW "):
            rows.append(json.loads(line[4:]))
        elif line.startswith("EV "):
            evs.append(json.loads(line[3:]))
        elif line.startswith("ERGEBNIS "):
            res = json.loads(line[9:])
        elif line.startswith("SUMMARY "):
            summ = json.loads(line[8:])
    return rows, evs, res, summ


def ev_key(e):
    return (e.get("name"), round(float(e.get("z", 0.0)), 2), str(e.get("kind", "")), str(e.get("side", "")),
            str(e.get("set", "")), str(e.get("deck", "")))


def cat(r):
    f = r["f"]
    return (f["paving"], f["surface_l"], f["surface_r"], f["zone"], f["deck"])


def main():
    a = load(sys.argv[1])
    b = load(sys.argv[2])
    ok = True
    print("Zeilen", len(a[0]), len(b[0]), "| Ereignisse", len(a[1]), len(b[1]))
    same_res = a[2] == b[2]
    same_counts = (a[3] or {}).get("counts") == (b[3] or {}).get("counts")
    print("ERGEBNIS gleich:", same_res, "| Zählungen gleich:", same_counts)
    ok = ok and same_res and same_counts
    ea = collections.Counter(ev_key(e) for e in a[1])
    eb = collections.Counter(ev_key(e) for e in b[1])
    print("Ereignisse nach Ort/Art gleich:", ea == eb, "| nur vorher:", sum((ea - eb).values()), "| nur nachher:", sum((eb - ea).values()))
    ok = ok and ea == eb
    ca = collections.Counter(cat(r) for r in a[0])
    cb = collections.Counter(cat(r) for r in b[0])
    print("Zeilen je Kategorie (Belag, links, rechts, Zone, Deck) gleich:", ca == cb)
    for k in sorted(set(ca) | set(cb)):
        if ca[k] != cb[k]:
            print("   ", k, ca[k], "->", cb[k])
    ok = ok and ca == cb
    strict = sum(1 for i in range(min(len(a[0]), len(b[0]))) if cat(a[0][i]) != cat(b[0][i]))
    print("Zeilen mit anderer Kategorie an derselben Stelle der Folge:", strict)
    print("GLEICH" if ok else "VERSCHIEDEN")


if __name__ == "__main__":
    main()
