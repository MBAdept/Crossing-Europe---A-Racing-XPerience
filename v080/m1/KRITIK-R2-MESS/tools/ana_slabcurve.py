#!/usr/bin/env python3
"""KRITIK-R2-MESS: slab level against speed while driving the km_slab.gd profile (ramps and jumps 90-160 km/h):
the sum of both captures (slow on MRoad + fast on MWind = what the player hears of the slab layer) as K-weighted
loudness in 0.5-s windows, with the speed of that window (from the rows), against the law slab_lufs(v) of the head.
Reports per 5-km/h bin the mean deviation from the law and the largest step between neighbouring bins.
usage: ana_slabcurve.py <base> <obj|c1|r> <out.json>"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402
from ana_cap import load_f32  # noqa: E402

SR = 44100


def law(v, head):
    t = -17.7 - 4.0 + 3.0 + 20.0 * math.log10(v / 245.0) + 1.94   # at Gesamtlautstärke 1.0 (targets are at 0.8 = -1.94 dB)
    if head == "obj" and v > 150:
        t -= 16.0 * math.log10(v / 150.0)
    return t


def main():
    base, head, out = sys.argv[1], sys.argv[2], sys.argv[3]
    meta = json.load(open(base + ".json"))
    rows = meta["rows"]
    s = load_f32(base + "_slow.f32")
    f = load_f32(base + "_fast.f32")
    n = min(len(s), len(f))
    x = s[:n] + f[:n]
    # capture index -> speed (rows: [t, v, idx_slow, idx_fast, ...])
    idx = np.array([r[2] for r in rows], float)
    vv = np.array([r[1] for r in rows], float)
    w = int(0.5 * SR)
    pts = []
    for a in range(0, n - w, w // 2):
        seg = x[a:a + w]
        if np.max(np.abs(seg)) < 1e-5:
            continue
        mid = a + w // 2
        v = float(np.interp(mid, idx, vv))
        v0, v1 = float(np.interp(a, idx, vv)), float(np.interp(a + w, idx, vv))
        if abs(v1 - v0) > 4.0:           # skip windows with a jump inside
            continue
        L = dsp.lufs_plain(seg)
        pts.append((v, L, L - law(v, head)))
    pts = np.array(pts)
    bins = {}
    for lo in range(90, 165, 5):
        m = (pts[:, 0] >= lo) & (pts[:, 0] < lo + 5)
        if m.sum() >= 2:
            bins[lo] = {"n": int(m.sum()), "lufs": round(float(pts[m, 1].mean()), 2), "dev_law": round(float(pts[m, 2].mean()), 2),
                        "sd": round(float(pts[m, 2].std()), 2)}
    keys = sorted(bins)
    steps = [(keys[i], round(bins[keys[i + 1]]["dev_law"] - bins[keys[i]]["dev_law"], 2)) for i in range(len(keys) - 1)
             if keys[i + 1] - keys[i] == 5]
    res = {"bins": bins, "steps_dev": steps}
    print(f"{head}: Plattenpegel gegen das Gesetz je 5 km/h (Mittel ± SD der 0,5-s-Fenster):")
    for k in keys:
        b = bins[k]
        print(f"   {k:3d}-{k + 5:3d} km/h: {b['lufs']:7.2f} LUFS, gegen Gesetz {b['dev_law']:+.2f} ± {b['sd']:.2f} dB (n {b['n']})")
    print("   Sprünge der Abweichung zwischen Nachbarn:", steps)
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
