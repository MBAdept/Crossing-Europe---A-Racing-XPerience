#!/usr/bin/env python3
"""RINT-M2: luminance of a probe car's rear (vehicle probe pictures), narrow crop around the car's screen position.
usage: vehlum.py <veh dir> <poslog tag> <tag,tag,...> <scene:set_substring> [...]
prints mean luminance and share of pixels > 200 per tag, plus red/blue pixel counts in the vehcrop box."""
import json
import os
import re
import sys

import numpy as np
from PIL import Image

d, postag, tags = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
wants = sys.argv[4:]
pos = {}
for line in open(os.path.join(d, "%s.log" % postag), errors="replace"):
    m = re.match(r"QA-VEH (\w+) (\[.*\])\s*$", line)
    if m:
        pos[m.group(1)] = json.loads(m.group(2))
for w in wants:
    sc, sub = w.split(":")
    for car in pos.get(sc, []):
        if sub not in car["set"] or "screen" not in car:
            continue
        x, y, _ = car["screen"]
        dist = car["z"]
        hw = max(24, int(2600 / max(dist, 8)))
        hh = int(hw * 0.62)
        narrow = (int(x - hw * 0.4), int(y - hh * 1.2), int(x + hw * 0.4), int(y + hh * 0.3))
        wide = (int(x - hw), int(y - hh * 1.15), int(x + hw), int(y + hh * 0.85))
        row = []
        for tag in tags:
            p = os.path.join(d, "%s_%s.png" % (tag, sc))
            if not os.path.exists(p):
                row.append("%s: -" % tag)
                continue
            im = Image.open(p).convert("RGB")
            a = np.asarray(im.crop(narrow)).astype(float)
            lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
            b = np.asarray(im.crop(wide)).astype(int)
            r, g, bl = b[..., 0], b[..., 1], b[..., 2]
            red = int(((r > 170) & (g < 110) & (bl < 110)).sum())
            blue = int(((bl > 160) & (bl - r > 50) & (bl - g > 20)).sum())
            row.append("%s: mean %.1f, >200 %.2f %%, red %d, blue %d" % (tag, lum.mean(), 100.0 * (lum > 200).mean(), red, blue))
        print("%s %s %.0f m | %s" % (sc, car["set"], dist, " | ".join(row)))
