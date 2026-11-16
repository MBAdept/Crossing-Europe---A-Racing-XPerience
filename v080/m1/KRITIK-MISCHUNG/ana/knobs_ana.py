#!/usr/bin/env python3
"""Effect of the mischung.json knobs on the 16-bar sketches (KRITIK-MISCHUNG): loudness, true peak, band shares and
third-octave levels at equal loudness, each against the variant "base". usage: knobs_ana.py <K> -> res/knobs.json"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402
from measure_files import BANDS  # noqa: E402

K = sys.argv[1]
SR = alib.SR


def meas(path):
    x = alib.read_audio(path)
    a = int(1 * 4 * 60 / 132 * SR)            # skip the count-in bar
    seg = x[a:]
    L = alib.Loud(seg)
    lu = L.integrated()
    f, LL, RR, _ = alib.welch_cross(seg)
    tot = LL + RR
    P = float(np.sum(tot))
    th = alib.thirds(f, tot)
    # band levels at equal loudness (-14 LUFS): absolute dB minus the loudness offset
    norm = -14.0 - lu
    return {"lufs": round(lu, 2), "tp": round(alib.true_peak_db(seg), 2), "lra": round(L.lra(), 2),
            "bands_rel": {n: round(alib.pdb(alib.band_sum(f, tot, lo, hi) / P), 2) for n, lo, hi in BANDS},
            "bands_at_m14": {n: round(alib.pdb(alib.band_sum(f, tot, lo, hi)) + norm, 2) for n, lo, hi in BANDS},
            "thirds_at_m14": [round(alib.pdb(v) + norm, 2) for v in th]}


def main():
    root = os.path.join(K, "knobs")
    out = {}
    for v in sorted(os.listdir(root)):
        p = os.path.join(root, v, "linke_spur_skizze_16.wav")
        if os.path.exists(p):
            out[v] = meas(p)
    base = out.get("base")
    for v, r in out.items():
        if base and v != "base":
            r["delta_bands_db"] = {n: round(r["bands_at_m14"][n] - base["bands_at_m14"][n], 2) for n in r["bands_at_m14"]}
            r["delta_thirds_db"] = [round(a - b, 2) for a, b in zip(r["thirds_at_m14"], base["thirds_at_m14"])]
        print(v, r["lufs"], r["tp"], r.get("delta_bands_db", ""))
    json.dump(out, open(os.path.join(K, "res", "knobs.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
