"""AU-R: the written variants of glass, debris, truck_boom against variant a – third-octave balance (bands within
30 dB of the loudest band of a), momentary loudness at the equal file peak, and the old file of AU-C1 against the
new variant a (only the lead differs)."""
import json
import os
import sys

import numpy as np

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1"
sys.path.insert(0, WT + "/tools/audio/qc")
sys.dont_write_bytecode = True
import qc_lib  # noqa: E402

SR = 44100
TOB = [1000.0 * 10.0 ** (k / 10.0) for k in range(-17, 13)]
new = sys.argv[1]      # folder with the new sfx
old = sys.argv[2]      # folder with the old sfx (AU-C1)


def third(y):
    f = np.fft.rfftfreq(len(y), 1.0 / SR)
    p = np.abs(np.fft.rfft(y)) ** 2 / len(y)
    return np.array([10 * np.log10(p[(f >= c * 10 ** -0.05) & (f < c * 10 ** 0.05)].sum() + 1e-30) for c in TOB])


def rd(p):
    x, _ = qc_lib.read_audio(p)
    return x[:, 0]


out = {}
for sid in ("glass", "debris", "truck_boom", "hit_heavy", "hit_light", "crunch"):
    m = json.load(open(os.path.join(new, "manifest.json")))["sounds"][sid]
    files = m.get("files") or [m["file"]]
    a = rd(os.path.join(new, files[0]))
    Ta = third(a)
    mask = Ta > Ta.max() - 30
    lm_a = qc_lib.momentary_max(a, SR)
    rows = []
    for f in files[1:]:
        y = rd(os.path.join(new, f))
        d = third(y) - Ta
        rows.append({"file": f, "max_band_dev_db": round(float(np.max(np.abs(d[mask]))), 2),
                     "d_lufs_m": round(float(qc_lib.momentary_max(y, SR) - lm_a), 2)})
    # old file of AU-C1: same sound, lead changed only
    om = json.load(open(os.path.join(old, "manifest.json")))["sounds"][sid]
    ofiles = om.get("files") or [om["file"]]
    o = rd(os.path.join(old, ofiles[0]))
    lead = int(round(float(m.get("jitter_lead_ms", 0.0)) * SR / 1000.0))
    same = len(a) - lead == len(o) and float(np.max(np.abs(a[lead:] - o))) < 2.0 / 32768
    out[sid] = {"variants": rows, "a_equals_old_after_lead": bool(same), "lead_samples": lead, "lufs_m": m.get("lufs_m")}
    print(sid, json.dumps(out[sid], ensure_ascii=False))
json.dump(out, open(sys.argv[3], "w"), indent=1)
