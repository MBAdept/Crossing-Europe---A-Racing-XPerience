#!/usr/bin/env python3
"""AU-R2: table of slab_eval.py results (worst third-octave deviation over all speeds, loudness, peaks)."""
import json
import sys

rows = json.load(open(sys.argv[1]))
rows.sort(key=lambda r: (r["worst"], r["dlu"]))
print("order spread top  worst  dLU | worst@130  dTP: 90  130  140  180  200  230")
for r in rows:
    d = r["dtp"]
    w130 = r["rows"]["130.0"]
    print(f"{r['seed']} {r['spread']:4.1f} {r['top']:4.1f}  {r['worst']:5.2f} {r['dlu']:5.2f} | {w130[0]:+.2f}@{w130[1]:.0f}"
          f"  {d['90.0']:+.2f} {d['130.0']:+.2f} {d['140.0']:+.2f} {d['180.0']:+.2f} {d['200.0']:+.2f} {d['230.0']:+.2f}")
