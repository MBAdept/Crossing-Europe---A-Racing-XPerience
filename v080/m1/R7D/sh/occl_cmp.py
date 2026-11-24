#!/usr/bin/env python3
"""R7D: A-17 occlusion probe, head against base – visible pixels of the red test car per place, distance and lane.
A pixel counts when it differs from the picture without the car (none) by more than 40 in any channel and is red
(r > g + 40 and r > b + 40). Usage: occl_cmp.py <occl dir>"""
import sys, os, re
import numpy as np
from PIL import Image
d = sys.argv[1]
def px(path, none):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    diff = np.abs(a - none).max(axis=2) > 40
    red = (a[..., 0] > a[..., 1] + 40) & (a[..., 0] > a[..., 2] + 40)
    return int((diff & red).sum())
rows = []
same = 0; total = 0; worse = []
for pos in ["T1", "T2", "T3", "T4", "C1", "S0", "S4"]:
    res = {}
    for which in ["head", "base"]:
        nf = os.path.join(d, f"{pos}_{which}_none.png")
        if not os.path.exists(nf):
            continue
        none = np.asarray(Image.open(nf).convert("RGB")).astype(int)
        for f in sorted(os.listdir(d)):
            m = re.match(rf"{pos}_{which}_d(\d+)_l(-?\d)\.png$", f)
            if m:
                res.setdefault((int(m.group(1)), int(m.group(2))), {})[which] = px(os.path.join(d, f), none)
    for k in sorted(res):
        h = res[k].get("head"); b = res[k].get("base")
        if h is None or b is None:
            continue
        total += 1
        tag = ""
        if abs(h - b) <= max(3, 0.05 * b):
            same += 1
        else:
            tag = "  <-- anders"
            if h < b:
                worse.append((pos, k, h, b))
        rows.append(f"{pos} {k[0]:3d} m Spur {k[1]:+d}: Kopf {h:5d}  Basis {b:5d}{tag}")
print("\n".join(rows))
print(f"OCCL {total} Stellen, {same} gleich (±5 % / ±3 px), Kopf weniger sichtbar an {len(worse)}: {worse}")
