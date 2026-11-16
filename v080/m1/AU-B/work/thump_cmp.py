"""Scratch (AU-B): the clonk of the shift thump / tip-in before and after softening - share of the energy above
2, 5 and 10 kHz, largest sample step, peak, energy."""
import sys

import numpy as np

W = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work"
R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2/assets/audio/modern/vehicle"
sys.path.insert(0, W)
from e3an import qc_lib  # noqa: E402

for name in ("shift_thump_a", "tipin_a"):
    for label, path in (("vorher ", f"{W}/oldveh/{name}.wav"), ("nachher", f"{R}/{name}.wav")):
        x, sr = qc_lib.read_wav(path)
        x = np.asarray(x, np.float64)
        if x.ndim == 2:
            x = x[:, 0]
        X = np.abs(np.fft.rfft(x)) ** 2
        f = np.fft.rfftfreq(len(x), 1.0 / sr)
        tot = X.sum()
        sh = [10 * np.log10(max(X[f >= c].sum() / tot, 1e-12)) for c in (300.0, 2000.0, 5000.0, 10000.0)]
        print("%-14s %s: %5d Frames, Spitze %.3f, Energie %.2f dB, größter Sprung %.4f, Anteil > 300 Hz %.1f  > 2 kHz %.1f  > 5 kHz %.1f  > 10 kHz %.1f dB" % (
            name, label, len(x), float(np.max(np.abs(x))), 10 * np.log10(float(np.sum(x * x))), float(np.max(np.abs(np.diff(x)))), *sh))
