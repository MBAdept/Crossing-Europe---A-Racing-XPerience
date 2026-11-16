"""AU-R: seeds of the 32-slab patterns whose loudness at the file peak (-3 dBFS) is at least that of AU-C1's 8-slab
loops + margin: the in-game peaks at a given loudness then do not rise (R5: cruising stays below the limiter)."""
import sys

import numpy as np

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1"
sys.path.insert(0, WT + "/tools/audio/modern")
sys.dont_write_bytecode = True
import vehicle_loops as vl  # noqa: E402
import modern_lib as ml  # noqa: E402
import qc_lib  # noqa: E402

OLD = {90.0: -20.55, 180.0: -17.7}
for ref, base in ((90.0, 2601), (180.0, 2701)):
    rows = []
    for k in range(0, 60):
        y = vl.slab_loop(ref, base + k, slabs=32)
        y = y - float(np.mean(y))
        y = y * (vl.PEAK / float(np.max(np.abs(y))))
        y = ml.limit_true_peak(y[:, None], -3.0)[:, 0]
        lu = float(qc_lib.integrated_lufs(y, vl.SR))
        rows.append((lu, base + k))
    rows.sort(reverse=True)
    print(ref, "old", OLD[ref], "best", [(round(a, 2), b) for a, b in rows[:8]], "median", round(float(np.median([r[0] for r in rows])), 2))
