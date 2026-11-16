#!/usr/bin/env python3
"""AU-R: what the game plays at a reference speed – left loop at pitch p, right loop at p × side pitch – against
AU-C1 (one loop read twice at p), third octaves at equal loudness. usage: side_sim.py <old dir> <new dir> [side_pitch]"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ana  # noqa: E402

old_dir, new_dir = sys.argv[1], sys.argv[2]
SIDE = float(sys.argv[3]) if len(sys.argv) > 3 else 1.02
SR = ana.SR
mo = json.load(open(os.path.join(old_dir, "manifest.json")))["sounds"]
mn = json.load(open(os.path.join(new_dir, "manifest.json")))["sounds"]
REF = {"tyre_asphalt": 130, "tyre_concrete": 130, "tyre_cobbles": 50, "wind_low": 130, "wind_mid": 130, "wind_high": 130}
c = np.array(ana.TOB_CENTRES)
ok = (c >= 25.0) & (c <= 12500.0)


def resample(y, pitch, n_out):
    n = len(y)
    pos = (np.arange(n_out) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    return y[i] * (1.0 - fr) + y[(i + 1) % n] * fr


def loop(d, m, sid):
    e = m[sid]
    return ana.load(os.path.join(d, e["file"]))[:, 0][:int(e["loop"][1])]


for sid, kmh in REF.items():
    e = mo[sid]
    p = (kmh / float(e["ref_kmh"])) ** float(e["pitch_exp"])
    n = int(20 * SR)
    xo = loop(old_dir, mo, sid)
    so = resample(xo, p, n)
    to = ana.third_octaves(so) - ana.lufs(np.stack([so, so], 1))
    a = resample(loop(new_dir, mn, sid), p, n)
    b = resample(loop(new_dir, mn, sid + "_b"), p * SIDE, n)
    # loudness of each side brought to the old (as the runtime does it from lufs_pitch), then the energy sum
    la = ana.lufs(np.stack([a, a], 1))
    lb = ana.lufs(np.stack([b, b], 1))
    lo = ana.lufs(np.stack([so, so], 1))
    a *= 10 ** ((lo - la) / 20)
    b *= 10 ** ((lo - lb) / 20)
    pa = 10 ** (ana.third_octaves(a) / 10)
    pb = 10 ** (ana.third_octaves(b) / 10)
    tn = 10 * np.log10((pa + pb) / 2) - lo
    m = ok & (to > to[ok].max() - 30.0)
    d = tn - to
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    print(f"{sid:14s} Seiten-Tonhöhe {SIDE:.2f}: max {abs(d[i]):.2f} dB bei {c[i]:.0f} Hz | " +
          " ".join(f"{cc:.0f}:{dd:+.2f}" for cc, dd, mm in zip(c, d, m) if mm and cc <= 400))
