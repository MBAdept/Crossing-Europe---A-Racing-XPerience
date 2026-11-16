"""AU-R: extra variants of glass, debris and truck_boom from the same generators with other seeds – the seeds whose
third-octave balance stays closest to today's file (variant a, the seed of AU-C1). Spectra normalised to the file
peak (-3 dBFS) as the runtime plays one-shots by peak; bands within 30 dB of the loudest band of today's file."""
import json
import sys

import numpy as np

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1"
sys.path.insert(0, WT + "/tools/audio/modern")
sys.dont_write_bytecode = True
import sfx_modern as sm  # noqa: E402
import vehicle_loops as vl  # noqa: E402
import modern_lib as ml  # noqa: E402
import qc_lib  # noqa: E402

SR = 44100


def prep(y, lead_ms):
    lead = int(round(lead_ms * SR / 1000.0))
    if lead > 0:
        y = np.concatenate([np.zeros(lead), y])
    y = vl.fade_tail(y, 0.01)
    y = y * (sm.PEAK / float(np.max(np.abs(y))))
    return ml.limit_true_peak(y[:, None], -3.0)[:, 0]


def third(y):
    f = np.fft.rfftfreq(len(y), 1 / SR)
    p = np.abs(np.fft.rfft(y)) ** 2 / len(y)
    out = []
    for k in range(-17, 13):
        c = 1000 * 10 ** (k / 10)
        m = (f >= c * 10 ** -0.05) & (f < c * 10 ** 0.05)
        out.append(10 * np.log10(p[m].sum() + 1e-20))
    return np.array(out)


res = {}
N = int(sys.argv[1]) if len(sys.argv) > 1 else 300
for name, fn, base, lead in (("glass", sm.glass, 4401, 9.0), ("debris", sm.debris, 4501, 40.0), ("truck_boom", sm.truck_boom, 4601, 0.0)):
    ref = prep(fn(base), lead)
    T0 = third(ref)
    mask = T0 > T0.max() - 30
    lm0 = float(qc_lib.momentary_max(ref, SR))
    rows = []
    for j in range(1, N + 1):
        seed = base * 10 + j          # 44011, 44012, … (no overlap with any other seed of the generator)
        y = prep(fn(seed), lead)
        d = third(y) - T0
        rows.append((float(np.max(np.abs(d[mask]))), seed, round(float(qc_lib.momentary_max(y, SR)) - lm0, 2)))
    rows.sort()
    res[name] = rows[:10]
    print(name, "best (max band dev dB, seed, dLUFS_m):", [(round(a, 2), b, c) for a, b, c in rows[:8]])
json.dump(res, open("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R/sfx_seeds.json", "w"), indent=1)
