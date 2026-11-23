#!/usr/bin/env python3
"""NACH-R7a: visible pixels of the red test car (qa_occl.gd pictures <pos>_<tag>_d<m>_l<k>.png against
<pos>_<tag>_none.png; a pixel counts when a channel changes by more than 24/255; visible from 12 px on) - the same
rule as FIX-R7a's and QA-R7a's tables. occl_table.py <pos> [--need=270]
Columns: NACH-R7a m3 (HEAD + FIX-RINT + FIX-R7c + patch B), FIX-R7a's pushB12, QA-R7a's R7a | R7a+reach | base."""
import glob, os, re, sys
import numpy as np
from PIL import Image

B = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1"
pos = sys.argv[1]
need = 270
for a in sys.argv[2:]:
    if a.startswith("--need="):
        need = int(a[7:])
cols = [("NACH:m3", B + "/NACH-R7a/occl", "m3"), ("FIX:push12", B + "/FIX-R7a/occl", "pushB12"),
        ("QA:R7a", B + "/QA-R7a/occl", "mine"), ("QA:Reichw", B + "/QA-R7a/occl", "fix"), ("QA:Basis", B + "/QA-R7a/occl", "base")]
vals = {}
used = []
for name, folder, tag in cols:
    none = os.path.join(folder, f"{pos}_{tag}_none.png")
    if not os.path.exists(none):
        continue
    used.append(name)
    b = np.asarray(Image.open(none).convert("RGB")).astype(np.int16)
    for f in glob.glob(os.path.join(folder, f"{pos}_{tag}_d*_l*.png")):
        m = re.search(r"_d(\d+)_l(-?\d+)\.png$", f)
        a = np.asarray(Image.open(f).convert("RGB")).astype(np.int16)
        vals.setdefault((int(m.group(1)), int(m.group(2))), {})[name] = int((np.abs(a - b) > 24).any(axis=2).sum())
print(f"{pos}: d/Spur  " + " | ".join(f"{n:>10}" for n in used) + f"   (sichtbar ab 12 px, verlangt bis {need} m)")
bad = {n: [] for n in used}
for k in sorted(vals):
    v = vals[k]
    print(f"  {k[0]:4d}/{k[1]:+d}  " + " | ".join(f"{v.get(n, '-'):>10}" for n in used))
    for n in used:
        if n in v and k[0] <= need and v[n] < 12:
            bad[n].append(k)
for n, b in bad.items():
    print(f"  {n}: VERDECKT bei {b}")
