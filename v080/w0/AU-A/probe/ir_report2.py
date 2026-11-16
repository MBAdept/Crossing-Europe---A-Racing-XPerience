"""Frequency responses from impulse responses (dir with *.f32, none.f32 = reference). Usage: ir_report2.py <dir> [rate]"""
import glob
import os
import sys

import numpy as np

D = sys.argv[1]
RATE = float(sys.argv[2]) if len(sys.argv) > 2 else 44100.0
FREQS = [20, 31, 45, 62, 90, 125, 180, 250, 350, 420, 500, 600, 700, 1000, 1400, 2000, 2800, 4000, 8000, 16000]
N = 1 << 17


def response(path):
    x = np.fromfile(path, dtype="<f4").astype(np.float64)
    return np.abs(np.fft.rfft(x, N))


ref = response(os.path.join(D, "none.f32"))
names = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(D, "*.f32")))
print("%-22s" % "Hz" + "".join("%7d" % f for f in FREQS) + "   Minimum")
for name in names:
    mag = response(os.path.join(D, name + ".f32"))
    d = 20.0 * np.log10(np.maximum(mag, 1e-12) / np.maximum(ref, 1e-12))
    row = [d[int(round(f * N / RATE))] for f in FREQS]
    lo = int(round(30 * N / RATE))
    hi = int(round(16000 * N / RATE))
    k = lo + int(np.argmin(d[lo:hi]))
    print("%-22s" % name + "".join("%7.2f" % v for v in row) + "   %.2f dB bei %.0f Hz" % (d[k], k * RATE / N))
