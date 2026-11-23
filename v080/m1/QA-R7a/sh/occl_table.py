#!/usr/bin/env python3
"""QA-R7a: visible pixels of the red test car (qa_occl.gd pictures: <pos>_<tree>_d<m>_l<k>.png against <pos>_<tree>_none.png,
a pixel counts when a channel changes by more than 24/255; the car counts as shown from 12 px on – as FIX-M2/R7a).
occl_table.py <pos> [required metres] -> table d/lane: R7a | R7a+reach | base."""
import glob, os, re, sys
import numpy as np
from PIL import Image

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/occl"
pos = sys.argv[1]
need = int(sys.argv[2]) if len(sys.argv) > 2 else 270
vals = {}
for w in ["mine", "fix", "base"]:
    none = os.path.join(S, f"{pos}_{w}_none.png")
    if not os.path.exists(none):
        continue
    b = np.asarray(Image.open(none).convert("RGB")).astype(np.int16)
    for f in glob.glob(os.path.join(S, f"{pos}_{w}_d*_l*.png")):
        m = re.search(r"_d(\d+)_l(-?\d+)\.png$", f)
        a = np.asarray(Image.open(f).convert("RGB")).astype(np.int16)
        vals.setdefault((int(m.group(1)), int(m.group(2))), {})[w] = int((np.abs(a - b) > 24).any(axis=2).sum())
print(f"{pos}: d/Spur   R7a | R7a+Reichweite | Basis   (sichtbar ab 12 px, verlangt bis {need} m)")
bad = {"mine": [], "fix": [], "base": []}
for k in sorted(vals):
    v = vals[k]
    print(f"  {k[0]:4d}/{k[1]:+d}  {v.get('mine', '-'):>6} | {v.get('fix', '-'):>6} | {v.get('base', '-'):>6}")
    for w in bad:
        if w in v and k[0] <= need and v[w] < 12:
            bad[w].append(k)
for w, b in bad.items():
    print(f"  {w}: {'gehalten' if not b else 'VERDECKT bei ' + str(b)}")
