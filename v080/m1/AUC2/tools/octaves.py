"""Octave-band levels (dB re loudest band, A-weighted option) and L/R correlation of WAV files."""
import sys, os
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix/tools/audio/qc")
import numpy as np, qc_lib
C = [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
def aw(f):
    f2 = f * f
    ra = (12194.0**2 * f2**2) / ((f2 + 20.6**2) * np.sqrt((f2 + 107.7**2) * (f2 + 737.9**2)) * (f2 + 12194.0**2))
    return 20 * np.log10(np.maximum(ra, 1e-12)) + 2.0
for p in sys.argv[1:]:
    x, sr = qc_lib.read_audio(p)
    m = x.mean(axis=1)
    F = np.fft.rfft(m * np.hanning(len(m)))
    f = np.fft.rfftfreq(len(m), 1 / sr)
    P = np.abs(F) ** 2
    out = []
    for c in C:
        sel = (f >= c / 2**0.5) & (f < c * 2**0.5)
        out.append(10 * np.log10(P[sel].sum() + 1e-20))
    out = np.array(out); outa = out + aw(np.array(C))
    corr = float(np.corrcoef(x[:, 0], x[:, 1])[0, 1]) if x.shape[1] == 2 else 1.0
    print(f"{os.path.basename(p):22s} " + " ".join(f"{v - out.max():6.1f}" for v in out) + f" | A-max@{C[int(np.argmax(outa))]:g} corr {corr:.2f}")
print("bands  " + " ".join(f"{c:>6g}" for c in C))
