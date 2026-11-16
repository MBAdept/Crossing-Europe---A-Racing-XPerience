import sys

import numpy as np

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1"
sys.path.insert(0, WT + "/tools/audio/modern")
sys.dont_write_bytecode = True
import vehicle_loops as vl  # noqa: E402
import modern_lib as ml  # noqa: E402
import qc_lib  # noqa: E402


def norm(y):
    y = y - float(np.mean(y))
    y = y * (vl.PEAK / float(np.max(np.abs(y))))
    return ml.limit_true_peak(y[:, None], -3.0)[:, 0]


def third(y):
    f = np.fft.rfftfreq(len(y), 1 / 44100)
    p = np.abs(np.fft.rfft(y)) ** 2
    out = []
    for k in range(-17, 13):
        c = 1000 * 10 ** (k / 10)
        m = (f >= c * 10 ** -0.05) & (f < c * 10 ** 0.05)
        out.append(10 * np.log10(p[m].sum() / len(y) + 1e-20))
    return np.array(out)


for ref, seed, old_seed, old in ((90.0, 2633, 2601, -20.55), (180.0, 2739, 2701, -17.7)):
    o = norm(vl.slab_loop(ref, old_seed, slabs=8))
    lo = qc_lib.integrated_lufs(o, 44100)
    To = third(o) - 10 * np.log10(np.mean(o ** 2))
    raw = vl.slab_loop(ref, seed, slabs=32)
    print(ref, "old file", old, "old regen", round(lo, 2), "crest old", round(20 * np.log10(np.max(np.abs(o)) / np.sqrt(np.mean(o ** 2))), 2))
    for c in (99.0, 4.0, 3.5, 3.0, 2.8, 2.6, 2.4, 2.2):
        y = raw.copy()
        if c < 50:
            r = vl.rms(y)
            y = c * r * np.tanh(y / (c * r))
        y = norm(y)
        lu = qc_lib.integrated_lufs(y, 44100)
        T = third(y) - 10 * np.log10(np.mean(y ** 2))
        m = To > To.max() - 30
        print("   c %.1f lufs %.2f (old+%.2f) crest %.2f  spectrum diff max %.2f dB" % (c, lu, lu - old,
              20 * np.log10(np.max(np.abs(y)) / np.sqrt(np.mean(y ** 2))), np.max(np.abs((T - To)[m]))))
