#!/usr/bin/env python3
"""AU-R "keep the character": third-octave spectrum and loudness of each layer recording, before (old head) against
after (AU-R), same plan, same positions. usage: ana_char.py <before dir> <after dir> <out.json>
Bands: 25 Hz – 12.5 kHz with a level within 30 dB of the loudest band of the 'before' recording (the bands that carry
the layer; below that the engine's leak through muted buses and the noise floor dominate)."""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ana  # noqa: E402

bdir, adir, out = sys.argv[1:4]
names = ["asph130_road", "conc130_road", "cobbles50_road", "asph130_wind", "wet130_road", "gravel100_road", "rumble130_road",
         "grass60_road", "asph130_full", "conc130_full", "cobbles50_full", "asph200_full", "conc200_full", "vmax_full"]
res = {}
c = np.array(ana.TOB_CENTRES)
band_ok = (c >= 25.0) & (c <= 12500.0)
print(f"{'Aufnahme':16s} {'LUFS vorher':>11s} {'nachher':>8s} {'Δ LU':>6s}  {'max |Δ Terz|':>12s} bei   Bänder")
for n in names:
    pb = os.path.join(bdir, n + ".wav")
    pa = os.path.join(adir, n + ".wav")
    if not (os.path.exists(pb) and os.path.exists(pa)):
        continue
    xb = ana.load(pb)
    xa = ana.load(pa)
    lb = ana.lufs(xb)
    la = ana.lufs(xa)
    tb = ana.third_octaves(xb)
    ta = ana.third_octaves(xa)
    m = band_ok & (tb > tb[band_ok].max() - 30.0)
    d = ta - tb
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    res[n] = {"lufs_before": round(lb, 2), "lufs_after": round(la, 2), "d_lu": round(la - lb, 2),
              "max_abs_band_db": round(float(abs(d[i])), 2), "at_hz": round(float(c[i]), 0),
              "bands": {str(round(float(cc))): round(float(dd), 2) for cc, dd, mm in zip(c, d, m) if mm},
              "n_bands": int(m.sum())}
    print(f"{n:16s} {lb:11.2f} {la:8.2f} {la - lb:+6.2f}  {abs(d[i]):12.2f} {c[i]:6.0f} Hz  {int(m.sum())}")
json.dump(res, open(out, "w"), indent=1)
