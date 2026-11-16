import sys

import numpy as np

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1"
sys.path.insert(0, WT + "/tools/audio/modern")
sys.dont_write_bytecode = True
import sfx_modern as sm  # noqa: E402

SR = 44100


def third(y):
    f = np.fft.rfftfreq(len(y), 1.0 / SR)
    p = np.abs(np.fft.rfft(y)) ** 2 / len(y)
    return np.array([10 * np.log10(p[(f >= c * 10 ** -0.05) & (f < c * 10 ** 0.05)].sum() + 1e-30) for c in sm.TOB])


ref = sm.truck_boom(4601)
pk = lambda y: y / np.max(np.abs(y))  # noqa: E731
Ta = third(pk(ref))
mask = Ta > Ta.max() - 30
rows = []
for s in range(46011, 46311):
    y = pk(sm.match_spectrum(sm.truck_boom(s), ref))
    rows.append((round(float(np.max(np.abs((third(y) - Ta)[mask]))), 2), s))
rows.sort()
print(rows[:10])
