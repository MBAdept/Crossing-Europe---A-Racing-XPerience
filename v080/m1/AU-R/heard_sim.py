#!/usr/bin/env python3
"""AU-R: the new pair as the game plays it (left at pitch p, right at p × side pitch – the rumble strip exactly –,
independent, each at equal loudness) against AU-C1 as it sounded (its loop on two players ±pan, half a loop apart):
energy over both channels, third octaves 25 Hz – 12.5 kHz within 30 dB of the loudest, relative to loudness.
usage: heard_sim.py <old dir> <new dir> [out.json]"""
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
REF = {"tyre_asphalt": 130, "tyre_concrete": 130, "tyre_deck": 120, "tyre_cobbles": 50, "tyre_gravel": 100, "tyre_grass": 60,
       "tyre_wet": 130, "tyre_rumble": 130, "wind_low": 130, "wind_mid": 130, "wind_high": 130, "wind_buffet": 230}
PAN = {"MRoad": 0.55, "MWind": 0.7}
c = np.array(ana.TOB_CENTRES)
ok = (c >= 25.0) & (c <= 12500.0)


def resample(y, pitch, n_out):
    n = len(y)
    pos = (np.arange(n_out) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    return y[i] * (1.0 - fr) + y[(i + 1) % n] * fr


def loop(d, m, sid):
    e = m[sid]
    return ana.load(os.path.join(d, e["file"]))[:, 0][:int(e["loop"][1])]


def bands(y):
    s = np.stack([y, y], 1)
    return ana.third_octaves(s) - ana.lufs(s)


def stereo(left, right, pan):
    """Two players panned to -pan / +pan (equal-power law) mixed into two channels."""
    t1, t2 = (1.0 - pan) * np.pi / 4.0, (1.0 + pan) * np.pi / 4.0
    return np.stack([np.cos(t1) * left + np.cos(t2) * right, np.sin(t1) * left + np.sin(t2) * right], 1)


res = {}
n = int(20 * SR)
for sid, kmh in REF.items():
    e = mo[sid]
    p = (kmh / float(e["ref_kmh"])) ** float(e["pitch_exp"])
    pan = PAN.get(str(e.get("bus", "MRoad")), 0.55)
    xo = loop(old_dir, mo, sid)
    a0 = resample(xo, p, n)
    a = resample(loop(new_dir, mn, sid), p, n)
    a /= np.sqrt(np.mean(a ** 2))
    if sid == "tyre_rumble":                                  # one side at a time: the loop itself, worse side
        b = resample(loop(new_dir, mn, sid + "_b"), p, n)
        b /= np.sqrt(np.mean(b ** 2))
        so = stereo(a0, 0.0 * a0, pan)
        ta = ana.third_octaves(stereo(a, 0.0 * a, pan))
        tb = ana.third_octaves(stereo(b, 0.0 * b, pan))
        sn = stereo(a, 0.0 * a, pan) if np.max(np.abs(ta - tb)) < 0 else None
        to = ana.third_octaves(so) - ana.lufs(so)
        worst = None
        for t, s in ((ta, stereo(a, 0.0 * a, pan)), (tb, stereo(b, 0.0 * b, pan))):
            d = t - ana.lufs(s) - to
            m = ok & (to > to[ok].max() - 30.0)
            i = int(np.argmax(np.where(m, np.abs(d), -1)))
            if worst is None or abs(d[i]) > worst[0]:
                worst = (abs(d[i]), c[i], float(np.sqrt(np.mean(d[m] ** 2))))
        res[sid] = {"pitch": round(p, 3), "max_abs_db": round(float(worst[0]), 2), "at_hz": round(float(worst[1])),
                    "rms_db": round(worst[2], 2)}
        print(f"{sid:14s} p {p:5.3f}: max {worst[0]:4.2f} dB bei {worst[1]:5.0f} Hz (rms {worst[2]:.2f}; je Seite allein)")
        continue
    b0 = resample(np.roll(xo, -(len(xo) // 2)), p, n)       # the second player half a loop further on
    so = stereo(a0, b0, pan)
    b = resample(loop(new_dir, mn, sid + "_b"), p * 1.02, n)
    b /= np.sqrt(np.mean(b ** 2))
    sn = stereo(a, b, pan)
    to = ana.third_octaves(so) - ana.lufs(so)
    tn = ana.third_octaves(sn) - ana.lufs(sn)
    m = ok & (to > to[ok].max() - 30.0)
    d = tn - to
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    res[sid] = {"pitch": round(p, 3), "max_abs_db": round(float(abs(d[i])), 2), "at_hz": round(float(c[i])),
                "rms_db": round(float(np.sqrt(np.mean(d[m] ** 2))), 2)}
    print(f"{sid:14s} p {p:5.3f}: max {abs(d[i]):4.2f} dB bei {c[i]:5.0f} Hz (rms {res[sid]['rms_db']:.2f})")
if out:
    json.dump(res, open(out, "w"), indent=1)
