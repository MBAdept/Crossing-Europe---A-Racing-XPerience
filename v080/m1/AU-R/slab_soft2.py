import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R")
sys.dont_write_bytecode = True
from slab_soft import norm, third, vl, qc_lib  # noqa: E402

for ref, seed, old_seed, old in ((90.0, 2633, 2601, -20.55), (180.0, 2739, 2701, -17.7)):
    o = norm(vl.slab_loop(ref, old_seed, slabs=8))
    To = third(o) - 10 * np.log10(np.mean(o ** 2))
    raw = vl.slab_loop(ref, seed, slabs=32)
    for k in (1.0, 0.85, 0.75, 0.65):
        y = raw.copy()
        if k < 1.0:
            T = k * np.max(np.abs(y))
            y = T * np.tanh(y / T)
        y = norm(y)
        lu = qc_lib.integrated_lufs(y, 44100)
        Tn = third(y) - 10 * np.log10(np.mean(y ** 2))
        d = Tn - To
        cs = [1000 * 10 ** (j / 10) for j in range(-17, 13)]
        print(ref, "k", k, "lufs %.2f (old%+.2f)" % (lu, lu - old),
              " ".join("%d:%+.1f" % (c, v) for c, v, lv in zip(cs, d, To) if lv > To.max() - 30))
