"""Where does the Vorbis seam error of an LF loop sit: start or end of the decoded file?"""
import sys

import numpy as np

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1"
sys.path.insert(0, WT + "/tools/audio/modern")
sys.dont_write_bytecode = True
import vehicle_loops as vl  # noqa: E402
import modern_lib as ml  # noqa: E402
import qc_lib  # noqa: E402

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R"
n = int(round(6.2 * vl.SR))
y = vl.wind_buffet(n, 0)
y = y - y.mean()
y = y * (vl.PEAK / np.max(np.abs(y)))
y = ml.limit_true_peak(y[:, None], -3.0)[:, 0]
for q in (5.0, 6.0):
    p = S + f"/probe_q{int(q)}.ogg"
    ml.write_ogg(p, y, quality=q)
    d = qc_lib.read_audio(p)[0][:, 0]
    err = d - y
    rms_err = np.sqrt(np.mean(err[2000:-2000] ** 2))
    print("q", q, "len", len(d), n, "err rms mid %.2e" % rms_err, "start err max %.2e" % np.max(np.abs(err[:64])),
          "end err max %.2e" % np.max(np.abs(err[-64:])))
    seam = qc_lib.loop_seam(d[:, None], 0, n, 0.1, vl.SR)
    print("   seam", {k: round(v, 2) for k, v in seam.items()})
    # original seam
    seam0 = qc_lib.loop_seam(y[:, None], 0, n, 0.1, vl.SR)
    print("   seam of the float loop", {k: round(v, 2) for k, v in seam0.items()})
