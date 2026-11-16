"""Scratch (AU-B): zoom on the strongest high-frequency transients of a capture window: band levels in 2-ms frames
around each event, the raw samples around the largest step, the trace row.
    python3 hf_zoom.py <capture.wav> t0 t1 [count]"""
import json
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work")
from e3an import qc_lib  # noqa: E402

path, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
count = int(sys.argv[4]) if len(sys.argv) > 4 else 4
x, sr = qc_lib.read_wav(path)
x = np.asarray(x, np.float64)
meta = json.load(open(path + ".json", encoding="utf-8"))
tr = meta["trace"]
ts = np.asarray(tr["t"])
a0, a1 = int(t0 * sr), int(t1 * sr)
seg = x[a0:a1]
X = np.fft.rfft(seg, axis=0)
f = np.fft.rfftfreq(len(seg), 1.0 / sr)
bands = [(300, 2000), (2000, 5000), (5000, 9000), (9000, 16000)]
parts = []
for lo, hi in bands:
    Y = X.copy()
    Y[(f < lo) | (f >= hi)] = 0.0
    parts.append(np.fft.irfft(Y, len(seg), axis=0))
n = int(0.002 * sr)
env = [np.array([float(np.mean(p[a:a + n] ** 2)) for a in range(0, len(seg) - n, n)]) for p in parts]
hf = env[2] + env[3]
order = np.argsort(hf)[::-1]
picked = []
for i in order:
    if all(abs(i - j) > 60 for j in picked):
        picked.append(i)
    if len(picked) >= count:
        break
for i in sorted(picked):
    t = t0 + i * n / sr
    k = int(np.argmin(np.abs(ts - t)))
    row = {key: (round(tr[key][k], 2) if isinstance(tr[key][k], float) else tr[key][k]) for key in tr}
    prev = {key: tr[key][max(k - 12, 0)] for key in ("gear",)}
    print("Ereignis bei %.3f s  %s  (Gang 0,1 s vorher: %s)" % (t, row, prev["gear"]))
    for b, (lo, hi) in enumerate(bands):
        lv = 10 * np.log10(np.maximum(env[b][max(i - 6, 0):i + 14], 1e-14))
        print("   %5d–%5d Hz: %s" % (lo, hi, " ".join("%4.0f" % v for v in lv)))
    a = a0 + i * n
    w = x[a - 6:a + n + 6, 0]
    d = np.abs(np.diff(w))
    j = int(np.argmax(d))
    print("   größter Sprung %.4f bei Abtastwert %d; Umgebung links: %s" % (d[j], j, " ".join("%+.3f" % v for v in w[max(j - 5, 0):j + 7])))
