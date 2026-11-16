#!/usr/bin/env python3
"""AU-R2 (M5): the cobble layer as the game plays it at 50 km/h (offline model of road_audio.gd: two players panned
±0.55 with the equal-power law, each at the loudness target − 3 dB from its own loudness curve; AU-C1: ONE loop on
both players half a loop apart, AU-R: the left loop on the left player, the right side's own loop on the right
player at pitch × 1.02), per channel: crest (sample peak / RMS), the loudest single peaks against AU-C1's loudest,
the 99.9 % quantile of |x| over RMS, third octaves of the stereo sum, loudness (ungated) – and the envelope
autocorrelation of the road alone (KRITIK-R dsp.env_autocorr, 2.5–8 kHz, mono) up to 8 s.
usage: cobble_eval.py <old_vehicle_dir> <repo_root> [--cap=none,auto,...] [--files]"""
import argparse
import json
import math
import os
import sys

import numpy as np

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(S, "ktools"))
sys.dont_write_bytecode = True
SR = 44100
PAN = 0.55
SECONDS = 20.0


def play(y, pitch, seconds, start_share=0.0):
    n = len(y)
    m = int(seconds * SR)
    pos = (start_share * n + np.arange(m) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    return y[i] * (1.0 - fr) + y[(i + 1) % n] * fr


def lufs_interp(curve, p):
    xs = np.log([float(a) for a, _ in curve])
    ys = [float(b) for _, b in curve]
    return float(np.interp(math.log(max(p, 0.01)), xs, ys))


def pan_gains(p):
    ang = (p + 1.0) * math.pi / 4.0
    return math.cos(ang), math.sin(ang)


def game(left, right, curve_l, curve_r, pitch_r, same, T=-25.0):
    """Stereo signal of the layer: left player at -PAN, right player at +PAN."""
    gl = 10 ** ((T - 3.0103 - lufs_interp(curve_l, 1.0)) / 20)
    gr = 10 ** ((T - 3.0103 - lufs_interp(curve_r, pitch_r)) / 20)
    a = play(left, 1.0, SECONDS, 0.13) * gl
    b = play(right, pitch_r, SECONDS, 0.63 if same else 0.41) * gr
    lL, lR = pan_gains(-PAN)
    rL, rR = pan_gains(PAN)
    return np.stack([lL * a + rL * b, lR * a + rR * b], 1)


def peaks_of(x, k=8, gap_s=0.02):
    """The k largest local peaks of |x| at least gap_s apart: [(t, dB re RMS)]."""
    r = float(np.sqrt(np.mean(x * x)))
    a = np.abs(x)
    g = int(gap_s * SR)
    out = []
    idx = np.argsort(a)[::-1]
    taken = []
    for i in idx:
        if len(out) >= k:
            break
        if any(abs(int(i) - j) < g for j in taken):
            continue
        taken.append(int(i))
        out.append((round(i / SR, 3), round(20 * math.log10(a[i] / r), 2)))
    return out


def stats(dsp, x):
    res = {"lufs": round(dsp.lufs_plain(x), 2), "tp": round(dsp.tp(x), 2)}
    for ch, nm in ((0, "L"), (1, "R")):
        c = x[:, ch]
        r = float(np.sqrt(np.mean(c * c)))
        res[nm] = {"crest": round(20 * math.log10(np.max(np.abs(c)) / r), 2),
                   "q999": round(20 * math.log10(np.quantile(np.abs(c), 0.999) / r), 2),
                   "q99": round(20 * math.log10(np.quantile(np.abs(c), 0.99) / r), 2),
                   "top": peaks_of(c, 6), "peak_dbfs": round(20 * math.log10(np.max(np.abs(c))), 2)}
    _c, L = dsp.third_octaves(x)
    res["tob"] = [round(float(v), 2) for v in L]
    lags, ac = dsp.env_autocorr(x, SR, 0.01, 8.0, band=(2500.0, 8000.0))
    pk = []
    for i in range(1, len(ac) - 1):
        if lags[i] >= 0.3 and ac[i] >= ac[i - 1] and ac[i] > ac[i + 1]:
            pk.append((round(float(lags[i]), 2), round(float(ac[i]), 3)))
    pk.sort(key=lambda t: -t[1])
    res["rep"] = pk[:5]
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("repo")
    ap.add_argument("--cap", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    sys.path.insert(0, os.path.join(a.repo, "tools", "audio", "modern"))
    import vehicle_loops as vl  # noqa: E402
    import modern_lib as ml  # noqa: E402
    import qc_lib  # noqa: E402
    import dsp  # noqa: E402
    c = np.array(dsp.TOB_CENTRES)
    band = (c >= 25) & (c <= 12500)

    man_old = json.load(open(os.path.join(a.old, "manifest.json")))["sounds"]
    x, _ = qc_lib.read_audio(os.path.join(a.old, "tyre_cobbles.wav"))
    lb, le = man_old["tyre_cobbles"]["loop"]
    y_old = np.asarray(x, np.float64)[lb:le, 0]
    ref = stats(dsp, game(y_old, y_old, man_old["tyre_cobbles"]["lufs_pitch"], man_old["tyre_cobbles"]["lufs_pitch"], 1.0, True))
    out = {"old": ref}
    print(f"AU-C1: lufs {ref['lufs']} tp {ref['tp']} | L crest {ref['L']['crest']} q999 {ref['L']['q999']} top {ref['L']['top'][:3]}"
          f" | R crest {ref['R']['crest']} q999 {ref['R']['q999']} top {ref['R']['top'][:3]} | rep {ref['rep'][:3]}")

    def report(label, yl, yr, cl, cr):
        st = stats(dsp, game(yl, yr, cl, cr, 1.02, False))
        d = np.array(st["tob"]) - np.array(ref["tob"])
        m = band & ((np.array(ref["tob"]) > np.array(ref["tob"])[band].max() - 30))
        i = int(np.argmax(np.where(m, np.abs(d), -1)))
        topd = (st["L"]["top"][0][1] - ref["L"]["top"][0][1], st["R"]["top"][0][1] - ref["R"]["top"][0][1])
        print(f"{label}: lufs {st['lufs'] - ref['lufs']:+.2f} LU, tob max {d[i]:+.2f} @ {c[i]:.0f} | L crest {st['L']['crest']} "
              f"({st['L']['crest'] - ref['L']['crest']:+.2f}) q999 {st['L']['q999']} | R crest {st['R']['crest']} "
              f"({st['R']['crest'] - ref['R']['crest']:+.2f}) q999 {st['R']['q999']} | loudest vs AU-C1 L {topd[0]:+.2f} R {topd[1]:+.2f} dB"
              f" | rep {st['rep'][:3]}", flush=True)
        out[label] = st

    # AU-R's files as they are
    man = json.load(open(os.path.join(a.repo, "assets/audio/modern/vehicle/manifest.json")))["sounds"]
    fl = [np.asarray(qc_lib.read_audio(os.path.join(a.repo, "assets/audio/modern/vehicle", f))[0], np.float64)[:, 0]
          for f in ("tyre_cobbles.ogg", "tyre_cobbles_b.ogg")]
    report("AU-R files", fl[0], fl[1], man["tyre_cobbles"]["lufs_pitch"], man["tyre_cobbles_b"]["lufs_pitch"])

    def finish(y):
        y = y - float(np.mean(y))
        y = y * (vl.PEAK / float(np.max(np.abs(y))))
        return ml.limit_true_peak(y[:, None], -3.0)[:, 0]

    old_n = int(round(2.5 * SR))
    draws = []
    vl.tyre_cobbles(old_n, 50.0, 0, None, draws)
    dmax = max(draws)
    print(f"AU-C1 draws: {len(draws)}, max {dmax:.3f} (x{math.exp(dmax):.2f} = +{20 * dmax / math.log(10):.1f} dB), "
          f"p99.9 {np.quantile(draws, 0.999):.3f}")
    ref_heard = vl.heard(vl.tyre_cobbles(old_n, 50.0, 0), vl.OLD_PAN["MRoad"])
    for capspec in [s for s in a.cap.split(",") if s]:
        cap = None if capspec == "none" else (dmax if capspec == "auto" else dmax + float(capspec))
        ys = []
        for sec, s in ((5.7, 0), (7.1, vl.SIDE_B)):
            n = int(round(sec * SR))
            dd = []
            y = finish(vl.match_loop(vl.tyre_cobbles(n, 50.0, s, cap, dd), ref_heard))
            ys.append(y)
            print(f"   cap {capspec}: side s={s} draws {len(dd)} max {max(dd):.3f} capped {sum(1 for v in dd if cap is not None and v > cap)}")
        cl = [[p, vl.lufs_at_pitch(ys[0], p)] for p in vl.PITCHES]
        cr = [[p, vl.lufs_at_pitch(ys[1], p)] for p in vl.PITCHES]
        report(f"cap {capspec}", ys[0], ys[1], cl, cr)
    if a.out:
        json.dump(out, open(a.out, "w"), indent=0)


if __name__ == "__main__":
    main()
