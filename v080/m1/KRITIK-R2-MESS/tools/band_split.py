#!/usr/bin/env python3
"""AU-R2: where a third-octave difference of a full game mix comes from – road alone vs the rest (full minus road in
power: engine + wind) before and after, per band 25–200 Hz (Plan B, deterministic).
usage: band_split.py <B_before.json> <B_after.json> <full seg> <road seg> [K_after.json]"""
import json
import sys

import numpy as np

Bb, Ba = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
full, road = sys.argv[3], sys.argv[4]
K = json.load(open(sys.argv[5])) if len(sys.argv) > 5 else None
c = np.array(Ba["centres"])


def parts(R):
    f = np.array(R["segments"][full]["third_oct"])
    r = np.array(R["segments"][road]["third_oct"])
    rest = 10 * np.log10(np.maximum(10 ** (f / 10) - 10 ** (r / 10), 1e-20))
    return f, r, rest


fb, rb, xb = parts(Bb)
fa, ra, xa = parts(Ba)
rows = [("AU-C1", fb, rb, xb), ("AU-R2", fa, ra, xa)]
if K:
    rows.append(("AU-R", *parts(K)))
print("band   | " + " | ".join(f"{lab}: full road rest" for lab, *_ in rows) + " | AU-R2-AU-C1: full road rest")
for i, fc in enumerate(c):
    if fc < 24 or fc > 260:
        continue
    s = " | ".join(f"{f[i]:6.1f} {r[i]:6.1f} {x[i]:6.1f}" for _lab, f, r, x in rows)
    print(f"{fc:6.0f} | {s} | {fa[i] - fb[i]:+.2f} {ra[i] - rb[i]:+.2f} {xa[i] - xb[i]:+.2f}")
