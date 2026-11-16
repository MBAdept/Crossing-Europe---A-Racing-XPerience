#!/usr/bin/env python3
"""QA-M2-BILD: signal-light pixel counts around each injected test car (vehicle probe), Arcade | ZS1 | M2.
usage: lightcount.py <veh dir> <hour> [scenes…]
red = brake/tail (r>170, g<110, b<110), amber = indicator (r>200, g>120, b<90, r-b>120), blue = beacon
(b>160, b-r>50, b-g>20). Window = the vehcrop box (scales with 1/distance)."""
import json
import os
import re
import sys

import numpy as np
from PIL import Image

d, hour = sys.argv[1], sys.argv[2]
scenes = sys.argv[3:] or ["d20a", "d20b", "d20c", "d60a", "d60b", "d60c", "d150a", "d150b", "d150c"]
cols = [(t.split("_")[0], t % hour) for t in os.environ.get("TAGS", "arc_h%s,zs1_h%s,m2_h%s").split(",")]
pos = {}
for line in open(os.path.join(d, "m2_h%s.log" % hour), errors="replace"):
    m = re.match(r"QA-VEH (\w+) (\[.*\])\s*$", line)
    if m:
        pos[m.group(1)] = json.loads(m.group(2))
print("scene car dist | red arc/zs1/m2 | amber arc/zs1/m2 | blue arc/zs1/m2 | lum arc/zs1/m2")
for sc in scenes:
    for car in pos.get(sc, []):
        if "screen" not in car:
            continue
        x, y, _ = car["screen"]
        dist = car["z"]
        hw = max(24, int(2600 / max(dist, 8)))
        hh = int(hw * 0.62)
        box = (int(x - hw), int(y - hh * 1.15), int(x + hw), int(y + hh * 0.85))
        res = {"red": [], "amber": [], "blue": [], "lum": []}
        for lab, tag in cols:
            p = os.path.join(d, "%s_%s.png" % (tag, sc))
            if not os.path.exists(p):
                for k in res:
                    res[k].append("-")
                continue
            a = np.asarray(Image.open(p).convert("RGB").crop(box)).astype(int)
            r, g, b = a[..., 0], a[..., 1], a[..., 2]
            res["red"].append(int(((r > 170) & (g < 110) & (b < 110)).sum()))
            res["amber"].append(int(((r > 200) & (g > 120) & (b < 90) & (r - b > 120)).sum()))
            res["blue"].append(int(((b > 160) & (b - r > 50) & (b - g > 20)).sum()))
            res["lum"].append(int((0.2126 * r + 0.7152 * g + 0.0722 * b).mean()))
        print("%s %s %.0f | %s | %s | %s | %s" % (sc, car["set"].split("/")[-1], dist,
              "/".join(map(str, res["red"])), "/".join(map(str, res["amber"])),
              "/".join(map(str, res["blue"])), "/".join(map(str, res["lum"]))))
