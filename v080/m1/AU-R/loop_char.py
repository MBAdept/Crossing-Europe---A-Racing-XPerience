#!/usr/bin/env python3
"""AU-R: file-level character check of the loops – AU-C1's file against the new left (a) and right (b) loop, each
played at the pitch of a reference speed and brought to equal loudness (as the runtime does: it sets the loudness
from lufs_pitch). Third-octave bands 25 Hz – 12.5 kHz within 30 dB of the loudest band of the old file.
usage: loop_char.py <old vehicle dir> <new vehicle dir> [out.json]"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ana  # noqa: E402

old_dir, new_dir = sys.argv[1], sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else None
SR = ana.SR
mo = json.load(open(os.path.join(old_dir, "manifest.json")))["sounds"]
mn = json.load(open(os.path.join(new_dir, "manifest.json")))["sounds"]
# layer -> reference speed (km/h) of the check
REF = {"tyre_asphalt": 130, "tyre_concrete": 130, "tyre_deck": 120, "tyre_cobbles": 50, "tyre_gravel": 100, "tyre_grass": 60,
       "tyre_wet": 130, "tyre_rumble": 130, "wind_low": 130, "wind_mid": 130, "wind_high": 130, "wind_buffet": 230,
       "slab_slow": 130, "slab_fast": 130}
c = np.array(ana.TOB_CENTRES)
ok = (c >= 25.0) & (c <= 12500.0)


def played(path, pitch, seconds=12.0):
    x = ana.load(path)[:, 0]
    return ana.resample_pitch(x, pitch, int(seconds * SR)) if hasattr(ana, "resample_pitch") else x


def resample(y, pitch, n_out):
    n = len(y)
    pos = (np.arange(n_out) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    return y[i] * (1.0 - fr) + y[(i + 1) % n] * fr


res = {}
for lid, kmh in REF.items():
    if lid not in mo or lid not in mn:
        continue
    eo = mo[lid]
    ref_kmh = float(eo.get("ref_kmh") or 0.0)
    pexp = float(eo.get("pitch_exp") or 0.0)
    p = (kmh / ref_kmh) ** pexp if ref_kmh > 0 and pexp > 0 else 1.0
    if lid.startswith("slab"):
        p = kmh / ref_kmh
    xo = ana.load(os.path.join(old_dir, eo["file"]))[:, 0][:int(eo["loop"][1])]
    so = resample(xo, p, int(12 * SR))
    lo = ana.lufs(np.stack([so, so], 1))
    to = ana.third_octaves(so) - lo
    m = ok & (to > to[ok].max() - 30.0)
    row = {"pitch": round(p, 3)}
    for side, nid in (("a", lid), ("b", str(mn[lid].get("pair", "")))):
        if not nid or nid not in mn:
            continue
        en = mn[nid]
        xn = ana.load(os.path.join(new_dir, en["file"]))[:, 0][:int(en["loop"][1])]
        sn = resample(xn, p, int(12 * SR))
        ln = ana.lufs(np.stack([sn, sn], 1))
        tn = ana.third_octaves(sn) - ln
        d = tn - to
        i = int(np.argmax(np.where(m, np.abs(d), -1)))
        row[side] = {"max_abs_db": round(float(abs(d[i])), 2), "at_hz": round(float(c[i])), "rms_db": round(float(np.sqrt(np.mean(d[m] ** 2))), 2)}
    res[lid] = row
    print(f"{lid:14s} p {p:5.3f}  " + "  ".join(f"{s}: max {row[s]['max_abs_db']:4.2f} dB bei {row[s]['at_hz']:5d} Hz (rms {row[s]['rms_db']:4.2f})" for s in ("a", "b") if s in row))
if out:
    json.dump(res, open(out, "w"), indent=1)
