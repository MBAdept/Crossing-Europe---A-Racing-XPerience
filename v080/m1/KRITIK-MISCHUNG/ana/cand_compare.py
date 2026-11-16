#!/usr/bin/env python3
"""The candidate render (render_all.py --out, sub_db -3, high_shelf_db -2 @ 5 kHz, race_music_db +1) against the
repository files: loudness, true peak, band shares at equal loudness. usage: cand_compare.py <K>"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402
from measure_files import BANDS, loudness, spectral  # noqa: E402

K = sys.argv[1]
SR = alib.SR
R = json.load(open(os.path.join(K, "res", "files.json")))
CD = os.path.join(K, "render_cand", "assets", "audio", "modern", "music")
man = json.load(open(os.path.join(CD, "manifest.json")))["sounds"]
out = {}
for n in ("titel_remaster", "linke_spur", "nachtfahrt", "rueckenwind", "zwischenspiel", "linke_spur_schluss", "nachtfahrt_tank"):
    if n not in man:
        continue
    e = man[n]
    x = alib.read_audio(os.path.join(CD, e["file"]))
    lp = e.get("loop")
    a, b = (int(lp[0]), int(lp[1])) if lp and lp[1] > lp[0] + SR else (0, len(x))
    lo = loudness(x, a, b)
    sp = spectral(x[a:b])
    ref = R[n].get("loop") if lp else R[n]["all"]
    ref = ref or R[n]["all"]
    d_bands = {k: round(sp["bands_rel_db"][k] - ref["bands_rel_db"][k], 2) for k, _l, _h in BANDS}
    out[n] = {"lufs": lo["lufs_i"], "tp_file": e.get("true_peak_db"), "gain_db": e.get("gain_db"), "lra": lo["lra"],
              "tilt_1k_10k": sp["tilt_1k_10k"], "ref_tilt_1k_10k": ref["tilt_1k_10k"], "delta_bands_rel_db": d_bands,
              "sha_same": None}
    print(n, out[n]["lufs"], "TP", out[n]["tp_file"], "gain_db", out[n]["gain_db"], "tilt", sp["tilt_1k_10k"], "vs", ref["tilt_1k_10k"])
    print("   delta", d_bands)
json.dump(out, open(os.path.join(K, "res", "cand_compare.json"), "w"), indent=1)
