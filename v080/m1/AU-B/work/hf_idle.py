"""Scratch (AU-B): statistics of the 2.5-ms envelope above 5 kHz in a time window of a capture (idle ticking):
median, 90 %, 99 %, maximum, crest, the autocorrelation peaks of the envelope (period of the ticks).
    python3 hf_idle.py <capture.wav> t0 t1"""
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work")
from e3an import qc_lib  # noqa: E402

path, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
x, sr = qc_lib.read_wav(path)
x = np.asarray(x, np.float64)[int(t0 * sr):int(t1 * sr)]
X = np.fft.rfft(x, axis=0)
f = np.fft.rfftfreq(len(x), 1.0 / sr)
tot = float(np.mean(x ** 2))
for lo in (2000.0, 5000.0):
    Y = X.copy()
    Y[f < lo] = 0.0
    h = np.fft.irfft(Y, len(x), axis=0)
    n = int(0.0025 * sr)
    e = np.array([float(np.mean(h[a:a + n] ** 2)) for a in range(0, len(h) - n, n)])
    db = 10 * np.log10(np.maximum(e, 1e-14))
    env = e - e.mean()
    ac = np.correlate(env, env, "full")[len(env) - 1:]
    ac /= ac[0] + 1e-30
    lags = np.argsort(ac[8:160])[::-1][:4] + 8
    print("%s  %.1f-%.1f s  > %4.0f Hz: Anteil %.1f dB, Hüllkurve Median %.1f  90%% %.1f  99%% %.1f  max %.1f dB  (max-Median %.1f)  Perioden %s" % (
        path.split("/")[-1], t0, t1, lo, 10 * np.log10(max(float(np.mean(h ** 2)), 1e-14) / tot), np.median(db), np.percentile(db, 90),
        np.percentile(db, 99), db.max(), db.max() - np.median(db), ", ".join("%.0f ms (%.2f)" % (l * 2.5, ac[l]) for l in sorted(lags))))
d = np.abs(np.diff(x, axis=0)).max(axis=1)
print("   größter Sprung %.4f, 99,9 %% %.4f, Effektivwert %.4f, Spitze %.3f" % (d.max(), np.percentile(d, 99.9), float(np.sqrt(tot)), float(np.max(np.abs(x)))))
