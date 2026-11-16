#!/usr/bin/env python3
"""AU-R (R5): gain reduction of the Modern limiter and true peak at Gesamtlautstärke 1.0.
usage: ana_gr.py <post.wav> <pre.f32> [<marks.json>] [--ceiling=-2.0]
post = Master after the limiters, recorded before Master's volume (= Gesamtlautstärke 1.0); pre = MMaster behind the
glue compressor, in front of the Modern limiter. GR(t) = 20 log10(env_pre / env_post) on 5-ms RMS frames after
aligning the two recordings (cross-correlation of their envelopes); reported: the largest GR (5-ms frames), the
share of frames with GR > 0.5 dB, the true peak of post (4x oversampled), the sample peak of pre."""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ana  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith("--")]
ceil = -2.0
for a in sys.argv[1:]:
    if a.startswith("--ceiling="):
        ceil = float(a.split("=", 1)[1])
post = ana.load(args[0])
pre = ana.load(args[1])
marks = json.load(open(args[2]))["marks"] if len(args) > 2 and os.path.exists(args[2]) else []
SR = ana.SR
F = int(0.005 * SR)


def env(x):
    m = np.max(np.abs(x), axis=1)
    n = len(m) // F
    return np.sqrt(np.mean((x[:n * F] ** 2).sum(axis=1).reshape(n, F), axis=1) / 2 + 1e-20)


ep = env(pre)
eo = env(post)
# align: lag of post against pre in frames (post usually starts a little later / earlier: other buses, record start)
a = 20 * np.log10(ep + 1e-9)
b = 20 * np.log10(eo + 1e-9)
best = (0, -9)
for lag in range(-200, 201):
    if lag >= 0:
        x, y = a[:len(a) - lag], b[lag:]
    else:
        x, y = a[-lag:], b[:len(b) + lag]
    k = min(len(x), len(y))
    if k < 200:
        continue
    c = float(np.corrcoef(x[:k], y[:k])[0, 1])
    if c > best[1]:
        best = (lag, c)
lag = best[0]
if lag >= 0:
    A, B = ep[:len(ep) - lag], eo[lag:]
else:
    A, B = ep[-lag:], eo[:len(eo) + lag]
k = min(len(A), len(B))
A, B = A[:k], B[:k]
loud = A > 10 ** (-40 / 20)
gr = np.where(loud, 20 * np.log10((A + 1e-12) / (B + 1e-12)), 0.0)
gr_corr = gr - float(np.median(gr[loud])) if np.any(loud) else gr       # any static level offset between the taps
# The hard limiter reduces the gain only where its input exceeds the ceiling (and holds it for its release): the
# gain reduction at a peak is pre_peak - ceiling. Time under reduction = samples within 0.12 s after any sample above
# the ceiling. (The envelope comparison of the two taps above is kept as a cross-check only: two taps of a noisy
# signal 5 ms apart differ by a few dB frame by frame, so it overstates small reductions.)
apre = np.max(np.abs(pre), axis=1)
over = np.where(apre > 10 ** (ceil / 20))[0]
held = np.zeros(len(apre), bool)
rel = int(0.12 * SR)
for i in over:
    held[i:i + rel] = True
res = {"post_tp_at_1.0": round(ana.tp(post), 2), "post_sp": round(ana.sp(post), 2), "pre_sp": round(ana.sp(pre), 2),
       "pre_tp": round(ana.tp(pre), 2), "gr_peak_db": round(max(0.0, ana.sp(pre) - ceil), 2),
       "samples_over_ceiling": int(len(over)), "time_reduced_s": round(float(held.sum()) / SR, 3),
       "time_reduced_share": round(float(held.mean()), 4), "seconds": round(len(apre) / SR, 2),
       "xcheck_env_gr_max_db": round(float(np.max(gr_corr)), 2), "lag_frames": lag, "align_corr": round(best[1], 3)}
# per crash: pre sample peak in its window (the marks are script time; the audio may run up to ~0.4 s ahead)
per = []
for m in marks:
    t = float(m["t"])
    i0 = max(int((t - 0.5) * SR), 0)
    i1 = min(int((t + 1.6) * SR), len(pre))
    j0 = max(int((t - 0.5) * SR), 0)
    j1 = min(int((t + 1.6) * SR), len(post))
    if i1 > i0 and j1 > j0:
        pk = ana.sp(pre[i0:i1])
        per.append({"t": t, "side": m.get("side"), "pre_sp": round(pk, 2), "gr_est_db": round(max(0.0, pk - ceil), 2),
                    "post_tp": round(ana.tp(post[j0:j1]), 2)})
if per:
    res["crashes"] = per
    res["crash_gr_est_max"] = max(p["gr_est_db"] for p in per)
    res["crash_post_tp_max"] = max(p["post_tp"] for p in per)
print(json.dumps(res, indent=1))
