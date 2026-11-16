"""Scratch (AU-B): where are short high-frequency events in a capture? Prints the times of 5-ms frames whose energy
above 5 kHz stands out against the median of their surroundings, with the phase of the drive and the trace row.
    python3 hf_events.py <capture.wav> [t0 t1] [threshold_db]"""
import json
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work")
import e3an  # noqa: E402
from e3an import qc_lib  # noqa: E402

path = sys.argv[1]
x, sr = qc_lib.read_wav(path)
x = np.asarray(x, np.float64)
meta = json.load(open(path + ".json", encoding="utf-8"))
t0 = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
t1 = float(sys.argv[3]) if len(sys.argv) > 3 else len(x) / sr
thr = float(sys.argv[4]) if len(sys.argv) > 4 else 12.0
# high-pass at 5 kHz in the frequency domain (whole file)
X = np.fft.rfft(x, axis=0)
f = np.fft.rfftfreq(len(x), 1.0 / sr)
X[f < 5000.0] = 0.0
h = np.fft.irfft(X, len(x), axis=0)
n = int(0.005 * sr)
e = np.array([float(np.mean(h[a:a + n] ** 2)) for a in range(0, len(h) - n, n)])
db = 10 * np.log10(np.maximum(e, 1e-14))
half = 40
ev = []
for i in range(len(db)):
    t = i * n / sr
    if t < t0 or t > t1:
        continue
    lo, hi = max(0, i - half), min(len(db), i + half)
    med = float(np.median(db[lo:hi]))
    if db[i] - med > thr and db[i] > -75.0:
        ev.append((t, db[i], db[i] - med))
# merge neighbours
merged = []
for t, d, r in ev:
    if merged and t - merged[-1][0] < 0.03:
        if d > merged[-1][1]:
            merged[-1] = (merged[-1][0], d, r)
    else:
        merged.append((t, d, r))
phases = meta.get("phases", [])
trace = meta.get("trace", [])


def phase_of(t):
    for p in phases:
        if p["t0"] <= t < p["t1"]:
            return p["name"]
    return "-"


def row_of(t):
    if not trace:
        return None
    ts = np.asarray(trace["t"])
    i = int(np.argmin(np.abs(ts - t)))
    return {k: (round(trace[k][i], 2) if isinstance(trace[k][i], float) else trace[k][i]) for k in trace}


print("%d Ereignisse über %.0f dB in %.1f–%.1f s" % (len(merged), thr, t0, t1))
for t, d, r in merged[:80]:
    a = int(t * sr)
    seg = x[max(0, a - 8):a + n + 8]
    d1 = float(np.max(np.abs(np.diff(seg, axis=0)))) if len(seg) > 1 else 0.0
    print("  %7.3f s  HF %6.1f dB (%+5.1f über Umgebung)  Phase %-10s größter Sprung %.4f  Spitze %.3f  %s" % (
        t, d, r, phase_of(t), d1, float(np.max(np.abs(seg))), json.dumps(row_of(t))[:200] if trace else ""))
