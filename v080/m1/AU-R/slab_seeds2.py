"""AU-R: 32-slab patterns – seed search over 400 seeds with a soft knee on the top hits (threshold KNEE x peak):
loudness at the -3 dBFS file peak against AU-C1's 8-slab loops, and the third-octave deviation (length-corrected)."""
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R")
sys.dont_write_bytecode = True
from slab_soft import norm, vl, qc_lib  # noqa: E402

KNEE = float(sys.argv[1]) if len(sys.argv) > 1 else 0.6


def knee(y, k):
    p = float(np.max(np.abs(y)))
    t = k * p
    a = np.abs(y)
    out = np.where(a <= t, a, t + (p - t) * np.tanh((a - t) / (p - t)))
    return np.sign(y) * out


def third(y):
    f = np.fft.rfftfreq(len(y), 1 / 44100)
    p = np.abs(np.fft.rfft(y)) ** 2
    tot = p.sum()
    out = []
    for k in range(-17, 13):
        c = 1000 * 10 ** (k / 10)
        m = (f >= c * 10 ** -0.05) & (f < c * 10 ** 0.05)
        out.append(10 * np.log10(p[m].sum() / tot + 1e-20))
    return np.array(out)


for ref, base, old_seed, old in ((90.0, 2601, 2601, -20.55), (180.0, 2701, 2701, -17.7)):
    o = norm(vl.slab_loop(ref, old_seed, slabs=8))
    To = third(o)
    mask = To > To.max() - 30
    rows = []
    for k in range(0, 400):
        raw = vl.slab_loop(ref, base + k, slabs=32)
        y = norm(knee(raw - float(np.mean(raw)), KNEE))
        lu = float(qc_lib.integrated_lufs(y, 44100))
        d = third(y) - To
        rows.append((lu - old, base + k, float(np.max(np.abs(d[mask])))))
    rows.sort(reverse=True)
    print(ref, "knee", KNEE, "best (dLUFS vs old, seed, max band dev):", [(round(a, 2), b, round(c, 2)) for a, b, c in rows[:10]])
    good = [r for r in rows if r[2] <= 1.0]
    print("   with band dev <= 1 dB:", [(round(a, 2), b, round(c, 2)) for a, b, c in good[:8]])
