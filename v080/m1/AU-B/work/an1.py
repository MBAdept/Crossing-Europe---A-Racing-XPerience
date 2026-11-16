"""Levels per bank: new format-2 bank vs the Arcade bank of the same car."""
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.getcwd()
sys.path.insert(0, os.path.join(ROOT, "tools/audio/qc"))
import qc_lib
from bank2 import Bank2, Bank1

car = sys.argv[1]
new = Bank2(sys.argv[2] + "/%s.json" % car)
old = Bank1(os.path.join(ROOT, "assets/audio/engines/%s.json" % car))


def lufs(y, sr):
    xk = qc_lib.k_weight(y, sr)
    return -0.691 + 10 * math.log10(max(float(np.mean(np.sum(xk * xk, axis=1))), 1e-20))


def band(y, sr, lo, hi):
    X = np.abs(np.fft.rfft(y[:, 0])) ** 2 + np.abs(np.fft.rfft(y[:, 1])) ** 2
    f = np.fft.rfftfreq(len(y), 1.0 / sr)
    return 10 * math.log10(max(float(np.sum(X[(f >= lo) & (f < hi)])) / max(float(np.sum(X)), 1e-30), 1e-12))


print("NEU  rpm    layer  LUFS   peak   rms    <60Hz  >2k   >5k   corr  xrpm xload")
for i, r in enumerate(new.rpms):
    for layer in ("off", "on", "in"):
        y = new.steady(i, layer)
        c = float(np.corrcoef(y[:, 0], y[:, 1])[0, 1]) if layer != "in" else 1.0
        m = new.src[(i, layer)]["meta"]
        print("     %5.0f  %-4s %6.1f  %5.2f  %5.3f  %5.1f %5.1f %5.1f  %4.2f  %5.2f %5.2f" % (r, layer, lufs(y, new.sr), np.max(np.abs(y)),
              math.sqrt(float(np.mean(y * y))), band(y, new.sr, 0, 60), band(y, new.sr, 2000, 16000), band(y, new.sr, 5000, 16000), c, m["xrpm"], m["xload"]))
print("ALT  rpm    load   LUFS   peak   rms    <60Hz  >2k   >5k")
for i, r in enumerate(old.rpms):
    for layer in ("off", "on"):
        y = old.steady(i, layer) * old.mix["gain"] * (old.mix["off_gain"] if layer == "off" else 1.0)
        print("     %5.0f  %-4s %6.1f  %5.2f  %5.3f  %5.1f %5.1f %5.1f" % (r, layer, lufs(y, old.sr), np.max(np.abs(y)),
              math.sqrt(float(np.mean(y * y))), band(y, old.sr, 0, 60), band(y, old.sr, 2000, 16000), band(y, old.sr, 5000, 16000)))
