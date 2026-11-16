"""Scratch (AU-B): short-term loudness (3 s window, 0.5 s step) over the full-throttle phase of plan captures.
    python3 st_curve.py <capture.wav> [...]"""
import json
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work")
from e3an import qc_lib  # noqa: E402

for path in sys.argv[1:]:
    x, sr = qc_lib.read_wav(path)
    x = np.asarray(x, np.float64)
    meta = json.load(open(path.replace(".wav", ".json") if not path.endswith(".wav.json") else path, encoding="utf-8")) if False else None
    try:
        meta = json.load(open(path[:-4] + ".json", encoding="utf-8"))
    except OSError:
        meta = json.load(open(path + ".json", encoding="utf-8"))
    ph = {p["name"]: p for p in meta["phases"]}
    xk = qc_lib.k_weight(x, sr)
    p = np.sum(xk ** 2, axis=1)
    c = np.concatenate([[0.0], np.cumsum(p)])
    w = int(3.0 * sr)
    out = []
    t = ph["full_throttle"]["t0"] + 3.0
    while t <= ph["flat_out"]["t1"]:
        b = int(t * sr)
        a = b - w
        if a >= 0 and b <= len(p):
            out.append((t, -0.691 + 10 * np.log10(max((c[b] - c[a]) / w, 1e-12))))
        t += 0.5
    name = path.split("/")[-1]
    vals = np.array([v for _, v in out])
    print("%s: Kurzzeit über Vollgas+Höchsttempo  min %.2f  max %.2f  (Vollgas %s–%s s, Höchsttempo bis %s s)" % (
        name, vals.min(), vals.max(), round(ph["full_throttle"]["t0"], 1), round(ph["full_throttle"]["t1"], 1), round(ph["flat_out"]["t1"], 1)))
    print("   " + "  ".join("%.0f:%.1f" % (t, v) for t, v in out[::2]))
