"""Octave-band energy (dB relative to the total) of WAV files: octaves.py FILE [FILE ...]"""
import os
import sys

sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1/tools/audio/qc")
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402

BANDS = [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
print("%-16s" % "file" + "".join("%7s" % (str(int(b)) if b >= 100 else str(b)) for b in BANDS) + "   LUFS")
for p in sys.argv[1:]:
    x, sr = qc_lib.read_audio(p)
    m = x.mean(axis=1)
    X = np.abs(np.fft.rfft(m)) ** 2
    f = np.fft.rfftfreq(len(m), 1 / sr)
    tot = X.sum()
    row = []
    for b in BANDS:
        sel = (f >= b / np.sqrt(2)) & (f < b * np.sqrt(2))
        row.append(10 * np.log10(X[sel].sum() / tot + 1e-12))
    print("%-16s" % os.path.basename(p)[:-4][:16] + "".join("%7.1f" % v for v in row) + "  %6.1f" % qc_lib.integrated_lufs(x, sr))
