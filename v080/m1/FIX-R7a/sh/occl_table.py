#!/usr/bin/env python3
"""FIX-R7a: visible pixels of the red test car (qa_occl.gd pictures <pos>_<tag>_d<m>_l<k>.png against <pos>_<tag>_none.png;
a pixel counts when a channel changes by more than 24/255; shown from 12 px on). occl_table.py <pos> <tag>... [--need=270]
Columns: the tags of this package (m1/FIX-R7a/occl), then QA-R7a's R7a | R7a+reach | base where present."""
import glob, os, re, sys
import numpy as np
from PIL import Image

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a/occl"
Q = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/occl"
pos = sys.argv[1]
need = 270
tags = []
for a in sys.argv[2:]:
    if a.startswith("--need="):
        need = int(a[7:])
    else:
        tags.append(a)
cols = [(t, S, t) for t in tags] + [("QA:R7a", Q, "mine"), ("QA:Reichw", Q, "fix"), ("QA:Basis", Q, "base")]
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
print(f"{pos}: d/Spur  " + " | ".join(f"{n:>9}" for n in used) + f"   (sichtbar ab 12 px, verlangt bis {need} m)")
bad = {n: [] for n in used}
for k in sorted(vals):
    v = vals[k]
    print(f"  {k[0]:4d}/{k[1]:+d}  " + " | ".join(f"{v.get(n, '-'):>9}" for n in used))
    for n in used:
        if n in v and k[0] <= need and v[n] < 12:
            bad[n].append(k)
for n, b in bad.items():
    print(f"  {n}: verdeckt bei {b}" if b else f"  {n}: überall sichtbar")
