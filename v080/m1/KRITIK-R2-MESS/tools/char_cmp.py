#!/usr/bin/env python3
"""AU-R2: Klangfarbe before -> after for chosen segments of two ana_cap results (Plan B style): ungated loudness
difference and the largest third-octave difference 25 Hz–12.5 kHz within 30 dB of the loudest band, plus the full
row of differences 25–250 Hz.
usage: char_cmp.py <before.json> <after.json> seg [seg ...]"""
import json
import sys

import numpy as np

b, a = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
c = np.array(a["centres"])
for seg in sys.argv[3:]:
    x, y = b["segments"][seg], a["segments"][seg]
    A, B = np.array(x["third_oct"]), np.array(y["third_oct"])
    m = (c >= 25) & (c <= 12500)
    m &= (A > A[m].max() - 30) | (B > B[m].max() - 30)
    d = B - A
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    low = " ".join(f"{c[k]:.0f}:{d[k]:+.2f}" for k in range(len(c)) if 24 <= c[k] <= 260)
    print(f"{seg}: {x['lufs_plain_1.0']:.2f} -> {y['lufs_plain_1.0']:.2f} LUFS ({y['lufs_plain_1.0'] - x['lufs_plain_1.0']:+.2f} LU) | "
          f"größte Terz {d[i]:+.2f} dB bei {c[i]:.0f} Hz | {low}")
