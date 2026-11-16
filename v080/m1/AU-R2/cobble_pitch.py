#!/usr/bin/env python3
"""AU-R2: the right cobble loop matched at its playing pitch (match_loop(..., pitch=1.02)) against the committed one –
low third octaves of the layer in the game model against AU-C1, crest per channel.
usage: cobble_pitch.py <old_vehicle_dir> <repo_root>"""
import json
import os
import sys

import numpy as np

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
sys.path.insert(0, os.path.join(S, "ktools"))
sys.dont_write_bytecode = True
import cobble_eval as ce  # noqa: E402
import cobble_diag as cd  # noqa: E402
import dsp  # noqa: E402
import qc_lib  # noqa: E402

old, repo = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(repo, "tools", "audio", "modern"))
import vehicle_loops as vl  # noqa: E402
import modern_lib as ml  # noqa: E402

SR = 44100
mo = json.load(open(os.path.join(old, "manifest.json")))["sounds"]
x, _ = qc_lib.read_audio(os.path.join(old, "tyre_cobbles.wav"))
lb, le = mo["tyre_cobbles"]["loop"]
y_old = np.asarray(x, np.float64)[lb:le, 0]
c = np.array(dsp.TOB_CENTRES)
sel = (c >= 24) & (c <= 260)


def finish(y):
    y = y - float(np.mean(y))
    y = y * (vl.PEAK / float(np.max(np.abs(y))))
    return ml.limit_true_peak(y[:, None], -3.0)[:, 0]


def tob(st):
    return np.array(dsp.third_octaves(st)[1])


ref_heard = vl.heard(vl.tyre_cobbles(int(round(2.5 * SR)), 50.0, 0), vl.OLD_PAN["MRoad"])
left = finish(vl.match_loop(vl.tyre_cobbles(int(round(5.7 * SR)), 50.0, 0), ref_heard))
cl = [[p, vl.lufs_at_pitch(left, p)] for p in vl.PITCHES]
ref = tob(ce.game(y_old, y_old, mo["tyre_cobbles"]["lufs_pitch"], mo["tyre_cobbles"]["lufs_pitch"], 1.0, True))
print("Hz       " + " ".join(f"{v:6.0f}" for v in c[sel]))
for lab, pl, pr in (("p1/p1", 1.0, 1.0), ("p1/p1.02", 1.0, 1.02), ("p1.0/1.02 r4", 1.0, 1.02)):
    raw = vl.tyre_cobbles(int(round(7.1 * SR)), 50.0, vl.COBBLES_SIDE_B)
    right = finish(vl.match_loop(raw, ref_heard, pitch=pr))
    lft = left if pl == 1.0 else finish(vl.match_loop(vl.tyre_cobbles(int(round(5.7 * SR)), 50.0, 0), ref_heard, pitch=pl))
    cr = [[p, vl.lufs_at_pitch(right, p)] for p in vl.PITCHES]
    g = ce.game(lft, right, cl, cr, 1.02, False)
    d = tob(g) - ref
    st = ce.stats(dsp, g)
    print(f"{lab:9s}" + " ".join(f"{v:+6.2f}" for v in d[sel]) + f" | crest L {st['L']['crest']} R {st['R']['crest']} own {cd.crest(right):.2f}")
    if lab == "p1/p1.02":
        break
