#!/usr/bin/env python3
"""AU-R: an in-game recording of one surface against what its loop files give at that pitch (energy sum of the
sides at equal loudness): bands 25-400 Hz, relative to each signal's loudness.
usage: cap_vs_loop.py <capture.wav> <vehicle dir> <layer> <pitch> [side_pitch] [pair]"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ana  # noqa: E402

cap, vdir, sid, p = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
side = float(sys.argv[5]) if len(sys.argv) > 5 else 1.0
pair = len(sys.argv) > 6 and sys.argv[6] == "pair"
SR = ana.SR
m = json.load(open(os.path.join(vdir, "manifest.json")))["sounds"]
c = np.array(ana.TOB_CENTRES)


def resample(y, pitch, n_out):
    n = len(y)
    pos = (np.arange(n_out) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    return y[i] * (1.0 - fr) + y[(i + 1) % n] * fr


def loop(s):
    e = m[s]
    return ana.load(os.path.join(vdir, e["file"]))[:, 0][:int(e["loop"][1])]


n = int(20 * SR)
a = resample(loop(sid), p, n)
b = resample(loop(sid + "_b") if pair else loop(sid), p * side, n)
la = ana.lufs(np.stack([a, a], 1))
lb = ana.lufs(np.stack([b, b], 1))
a *= 10 ** (-la / 20)
b *= 10 ** (-lb / 20)
sim = 10 * np.log10((10 ** (ana.third_octaves(a) / 10) + 10 ** (ana.third_octaves(b) / 10)) / 2)
x = ana.load(cap)
t = ana.third_octaves(x) - ana.lufs(x)
d = t - sim
sel = (c >= 25) & (c <= 400)
print(os.path.basename(cap), sid, " ".join(f"{cc:.0f}:{dd:+.2f}" for cc, dd in zip(c[sel], d[sel] - np.median(d[sel]))))
