"""Frequency responses from the impulse responses of probe_ir.gd (dB relative to the capture without an effect)."""
import glob
import os
import sys

import numpy as np

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ir")
RATE = float(sys.argv[1]) if len(sys.argv) > 1 else 44100.0
FREQS = [20, 31, 45, 62, 90, 125, 180, 250, 350, 500, 700, 1000, 1400, 2000, 2800, 4000, 5600, 8000, 11000, 16000, 19000]


def response(path):
    x = np.fromfile(path, dtype="<f4").astype(np.float64)
    if x.size == 0:
        return None
    n = 1 << int(np.ceil(np.log2(max(x.size, 1 << 16))))
    return np.abs(np.fft.rfft(x, n)), n


ref = response(os.path.join(D, "none.f32"))
names = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(D, "*.f32")))
print("%-28s" % "Hz" + "".join("%7d" % f for f in FREQS) + "   Welligkeit 40 Hz..10 kHz")
for name in names:
    r = response(os.path.join(D, name + ".f32"))
    if r is None or ref is None:
        print(name, "leer")
        continue
    mag, n = r
    rmag, rn = ref
    row = []
    for f in FREQS:
        k = int(round(f * n / RATE))
        kr = int(round(f * rn / RATE))
        row.append(20.0 * np.log10(max(mag[k], 1e-12) / max(rmag[kr], 1e-12)))
    lo = int(round(40 * n / RATE))
    hi = int(round(10000 * n / RATE))
    lor = int(round(40 * rn / RATE))
    hir = int(round(10000 * rn / RATE))
    if n == rn:
        d = 20.0 * np.log10(np.maximum(mag[lo:hi], 1e-12) / np.maximum(rmag[lor:hir], 1e-12))
        rip = "%+.2f .. %+.2f dB" % (d.min(), d.max())
    else:
        rip = "-"
    print("%-28s" % name + "".join("%7.2f" % v for v in row) + "   " + rip)
