#!/usr/bin/env python3
"""AU-R2: the low third octaves (25–250 Hz) of the cobble layer in the game model (cobble_eval.game) – AU-C1's file
against the committed AU-R2 files (and AU-R's right file from git, if given), several start offsets.
usage: cobble_low.py <old_vehicle_dir> <repo_root> [<aur_right.ogg>]"""
import json
import os
import sys

import numpy as np

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
sys.path.insert(0, os.path.join(S, "ktools"))
sys.dont_write_bytecode = True
import cobble_eval as ce  # noqa: E402
import dsp  # noqa: E402
import qc_lib  # noqa: E402

old, repo = sys.argv[1], sys.argv[2]
mo = json.load(open(os.path.join(old, "manifest.json")))["sounds"]
x, _ = qc_lib.read_audio(os.path.join(old, "tyre_cobbles.wav"))
lb, le = mo["tyre_cobbles"]["loop"]
y_old = np.asarray(x, np.float64)[lb:le, 0]
mn = json.load(open(os.path.join(repo, "assets/audio/modern/vehicle/manifest.json")))["sounds"]
yl = np.asarray(qc_lib.read_audio(os.path.join(repo, "assets/audio/modern/vehicle/tyre_cobbles.ogg"))[0], np.float64)[:, 0]
yr = np.asarray(qc_lib.read_audio(os.path.join(repo, "assets/audio/modern/vehicle/tyre_cobbles_b.ogg"))[0], np.float64)[:, 0]
c = np.array(dsp.TOB_CENTRES)
sel = (c >= 24) & (c <= 260)


def tob(stereo):
    return np.array(dsp.third_octaves(stereo)[1])


ref = tob(ce.game(y_old, y_old, mo["tyre_cobbles"]["lufs_pitch"], mo["tyre_cobbles"]["lufs_pitch"], 1.0, True))
new = tob(ce.game(yl, yr, mn["tyre_cobbles"]["lufs_pitch"], mn["tyre_cobbles_b"]["lufs_pitch"], 1.02, False))
print("Hz    " + " ".join(f"{v:6.0f}" for v in c[sel]))
print("AU-R2 " + " ".join(f"{v:+6.2f}" for v in (new - ref)[sel]))
if len(sys.argv) > 3:
    yb = np.asarray(qc_lib.read_audio(sys.argv[3])[0], np.float64)[:, 0]
    from vehicle_loops import PITCHES, lufs_at_pitch  # noqa: E402
    cb = [[p, lufs_at_pitch(yb, p)] for p in PITCHES]
    aur = tob(ce.game(yl, yb, mn["tyre_cobbles"]["lufs_pitch"], cb, 1.02, False))
    print("AU-R  " + " ".join(f"{v:+6.2f}" for v in (aur - ref)[sel]))
# each side alone against AU-C1's heard reference (one channel of AU-C1's two players)
for lab, y, cur, p in (("links", yl, mn["tyre_cobbles"]["lufs_pitch"], 1.0), ("rechts", yr, mn["tyre_cobbles_b"]["lufs_pitch"], 1.02)):
    a = ce.play(y, p, 20.0, 0.2) * 10 ** ((-25.0 - ce.lufs_interp(cur, p)) / 20)
    b = ce.play(y_old, 1.0, 20.0, 0.13) * 0.938 + ce.play(y_old, 1.0, 20.0, 0.63) * 0.346
    b = b * 10 ** ((-25.0 - ce.lufs_interp(mo["tyre_cobbles"]["lufs_pitch"], 1.0)) / 20)
    ta, tb = tob(np.stack([a, a], 1)), tob(np.stack([b, b], 1))
    ta -= 10 * np.log10(np.sum(10 ** (ta / 10)))
    tb -= 10 * np.log10(np.sum(10 ** (tb / 10)))
    print(f"{lab:6s}" + " ".join(f"{v:+6.2f}" for v in (ta - tb)[sel]))
