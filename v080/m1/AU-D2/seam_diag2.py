"""Band levels of the difference between two passes (A1 vs A1') per bar, and a best sub-sample alignment test.
usage: seam_diag2.py master.wav first_bar_a first_bar_b bar_frames n_bars"""
import sys
import numpy as np

path, ba, bb, bar, nb = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
raw = np.fromfile(path, dtype="<f4", offset=44)
x = raw.reshape(-1, 2).astype(np.float64)
bands = [(20, 80), (80, 250), (250, 1000), (1000, 4000), (4000, 16000)]
for k in range(nb):
    a = x[(ba + k) * bar:(ba + k + 1) * bar, 0]
    b = x[(bb + k) * bar:(bb + k + 1) * bar, 0]
    d = a - b
    A = np.fft.rfft(a)
    D = np.fft.rfft(d)
    f = np.fft.rfftfreq(len(a), 1 / 44100)
    row = []
    for lo, hi in bands:
        sel = (f >= lo) & (f < hi)
        ea = np.sum(np.abs(A[sel]) ** 2) + 1e-30
        ed = np.sum(np.abs(D[sel]) ** 2) + 1e-30
        row.append(f"{lo}-{hi}:{10*np.log10(ed/ea):6.1f}")
    # does a constant shift explain it? cross-correlation peak offset
    c = np.fft.irfft(np.fft.rfft(a, 2 * len(a)) * np.conj(np.fft.rfft(b, 2 * len(a))))
    lag = int(np.argmax(c))
    lag = lag if lag < len(a) else lag - 2 * len(a)
    print(f"bar {k}: diff/signal per band (dB) " + "  ".join(row) + f"   xcorr lag {lag}")
