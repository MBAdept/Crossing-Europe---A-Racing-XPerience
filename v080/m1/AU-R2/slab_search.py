#!/usr/bin/env python3
"""AU-R2 (H1, M3): search seeds (and an accent cap) for the 32-slab concrete patterns so that the slab layer AS THE
GAME PLAYS IT keeps AU-C1's third-octave balance at every speed – in particular at 130 km/h, where both designs play
at half amplitude IN STEP (AU-R, R3) and their hits add partly coherently (every hit starts its decaying sines at
phase 0: the cross terms of the two designs shape 200–1000 Hz by up to ±2.5 dB, measured in the model) – and so that
the loudest joints are lower at top speeds (M3: the Modern limiter at 200 km/h on concrete).

Model of the runtime (road_audio.gd _update_slabs): slow design at pitch v/90, fast at v/180, crossfade
smoothstep(110, 150, v) on the amplitudes, each player's gain from the loudness of its loop at its pitch (lufs_pitch
as the generator measures it, interpolated on a log scale), both started at the same share. Reference: AU-C1's files
played the same way (KRITIK-R's "before" capture had them in step: both players start in the same frame when
concrete begins; the model reproduces KRITIK-R's in-game differences of AU-R to within 0.05 dB).

usage: slab_search.py <old_vehicle_dir> <repo_root> <out.json> [--slow=a:b] [--fast=a:b] [--keep=10] [--cap=inf,4]
       [--knee=0.6,1.0] [--check=2872,2977,0.6,inf]"""
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
SPEEDS_MIX = [120.0, 130.0, 140.0]
SPEEDS_SLOW = [90.0, 105.0]
SPEEDS_FAST = [160.0, 180.0, 200.0, 230.0]
SECONDS = 20.0


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


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


class Design:
    def __init__(self, y, curve):
        self.y = y
        self.curve = curve


def layer(slow, fast, kmh, seconds=SECONDS, share=0.0, T=-20.0):
    xf = smoothstep(110.0, 150.0, kmh)
    out = np.zeros(int(seconds * SR))
    if 1.0 - xf > 0:
        p = kmh / 90.0
        out += play(slow.y, p, seconds, share) * 10 ** ((T - lufs_interp(slow.curve, p)) / 20) * (1.0 - xf)
    if xf > 0:
        p = kmh / 180.0
        out += play(fast.y, p, seconds, share) * 10 ** ((T - lufs_interp(fast.curve, p)) / 20) * xf
    return out


def measure(dsp, x):
    st = np.stack([x, x], 1)
    _c, L = dsp.third_octaves(st)
    return {"tob": np.array(L), "lufs": dsp.lufs_plain(st), "tp": dsp.tp(st)}


def diff(dsp, a, b, floor_db=30.0):
    c = np.array(dsp.TOB_CENTRES)
    m = (c >= 25) & (c <= 12500)
    m &= (a["tob"] > a["tob"][m].max() - floor_db) | (b["tob"] > b["tob"][m].max() - floor_db)
    d = b["tob"] - a["tob"]
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    return float(d[i]), float(c[i]), float(b["lufs"] - a["lufs"]), float(b["tp"] - a["tp"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("repo")
    ap.add_argument("out")
    ap.add_argument("--slow", default="2800:2840")
    ap.add_argument("--fast", default="2900:2940")
    ap.add_argument("--keep", type=int, default=8)
    ap.add_argument("--cap", default="inf")
    ap.add_argument("--knee", default="0.6")
    ap.add_argument("--check", default="")
    a = ap.parse_args()
    sys.path.insert(0, os.path.join(a.repo, "tools", "audio", "modern"))
    import vehicle_loops as vl  # noqa: E402
    import modern_lib as ml  # noqa: E402
    import qc_lib  # noqa: E402
    import dsp  # noqa: E402

    def finish(y):
        y = y - float(np.mean(y))
        y = y * (vl.PEAK / float(np.max(np.abs(y))))
        return ml.limit_true_peak(y[:, None], -3.0)[:, 0]

    def curve_of(y):
        return [[p, vl.lufs_at_pitch(y, p)] for p in vl.PITCHES]

    def slab(ref_kmh, seed, cap, knee):
        return vl.slab_loop(ref_kmh, seed, vl.SLABS, knee=knee, **({"accent_cap_db": cap} if cap < 99 else {}))

    # the old designs from their files (what the user heard)
    old = {}
    for nm in ("slab_slow", "slab_fast"):
        x, _sr = qc_lib.read_audio(os.path.join(a.old, nm + ".wav"))
        man = json.load(open(os.path.join(a.old, "manifest.json")))["sounds"][nm]
        lb, le = man["loop"]
        old[nm] = Design(np.asarray(x, np.float64)[lb:le, 0], man["lufs_pitch"])
    ref_raw = {90.0: vl.slab_loop(90.0, 2601), 180.0: vl.slab_loop(180.0, 2701)}
    ref = {}
    for v in SPEEDS_SLOW + SPEEDS_MIX + SPEEDS_FAST:
        ref[v] = measure(dsp, layer(old["slab_slow"], old["slab_fast"], v))

    def design(ref_kmh, seed, cap, knee):
        y = finish(vl.match_loop(slab(ref_kmh, seed, cap, knee), ref_raw[ref_kmh]))
        return Design(y, curve_of(y))

    def eval_single(d, which):
        rows = {}
        for v in (SPEEDS_SLOW if which == "slow" else SPEEDS_FAST):
            m = measure(dsp, layer(d, old["slab_fast"], v) if which == "slow" else layer(old["slab_slow"], d, v))
            rows[v] = diff(dsp, ref[v], m)
        return rows

    def eval_pair(ds, df):
        rows = {}
        for v in SPEEDS_MIX:
            rows[v] = diff(dsp, ref[v], measure(dsp, layer(ds, df, v)))
        return rows

    res = {"ref_tp": {str(v): ref[v]["tp"] for v in ref}, "singles": [], "pairs": []}
    if a.check:
        s1, s2, kn, cp = a.check.split(",")
        cp = float(cp)
        ds = design(90.0, int(s1), cp, float(kn))
        df = design(180.0, int(s2), cp, float(kn))
        for nm, d in (("slab_slow", ds), ("slab_fast", df)):
            f = os.path.join(a.repo, "assets/audio/modern/vehicle", nm + ".wav")
            if os.path.exists(f):
                x, _sr = qc_lib.read_audio(f)
                x = np.asarray(x, np.float64)[:len(d.y), 0]
                print(f"check {nm}: max |file - model| = {float(np.max(np.abs(x - d.y))):.2e} (16-bit step 3.1e-05)")
        print("check slow", {k: [round(t, 2) for t in v] for k, v in eval_single(ds, "slow").items()})
        print("check fast", {k: [round(t, 2) for t in v] for k, v in eval_single(df, "fast").items()})
        print("check pair", {k: [round(t, 2) for t in v] for k, v in eval_pair(ds, df).items()})
        return
    caps = [float(c) for c in a.cap.split(",")]
    knees = [float(k) for k in a.knee.split(",")]
    lo1, hi1 = (int(v) for v in a.slow.split(":"))
    lo2, hi2 = (int(v) for v in a.fast.split(":"))
    for cap in caps:
        for knee in knees:
            singles = {"slow": [], "fast": []}
            for which, rng_, kmh in (("slow", range(lo1, hi1), 90.0), ("fast", range(lo2, hi2), 180.0)):
                for seed in rng_:
                    d = design(kmh, seed, cap, knee)
                    rows = eval_single(d, which)
                    worst = max(abs(r[0]) for r in rows.values())
                    dlu = max(abs(r[2]) for r in rows.values())
                    dtp = max(r[3] for r in rows.values())     # peak at equal loudness, new - old (dB)
                    singles[which].append((worst + 0.5 * max(dlu - 0.25, 0.0), seed, d, rows, dtp))
                    res["singles"].append({"which": which, "seed": seed, "cap": cap, "knee": knee, "worst": round(worst, 2),
                                           "dlu": round(dlu, 2), "dtp": round(dtp, 2),
                                           "rows": {str(k): [round(t, 2) for t in v] for k, v in rows.items()}})
                    print(f"{which} seed {seed} cap {cap} knee {knee}: worst {worst:.2f} dLU {dlu:.2f} dTP {dtp:+.2f} "
                          + " ".join(f"{k:.0f}:{v[0]:+.2f}@{v[1]:.0f}" for k, v in rows.items()), flush=True)
                singles[which].sort(key=lambda t: t[0])
            for (sc1, s1, d1, r1, t1) in singles["slow"][:a.keep]:
                for (sc2, s2, d2, r2, t2) in singles["fast"][:a.keep]:
                    rows = eval_pair(d1, d2)
                    worst = max(abs(r[0]) for r in rows.values())
                    dlu = max(abs(r[2]) for r in rows.values())
                    dtp = max(r[3] for r in rows.values())
                    tot = max(worst, sc1, sc2)
                    res["pairs"].append({"slow": s1, "fast": s2, "cap": cap, "knee": knee, "worst_mix": round(worst, 2),
                                         "worst_all": round(tot, 2), "dlu_mix": round(dlu, 2), "dtp_mix": round(dtp, 2),
                                         "dtp_fast": round(t2, 2), "dtp_slow": round(t1, 2),
                                         "rows": {str(k): [round(t, 2) for t in v] for k, v in rows.items()}})
                    print(f"pair {s1}/{s2} cap {cap} knee {knee}: mix worst {worst:.2f} all {tot:.2f} dLU {dlu:.2f} "
                          f"dTP mix {dtp:+.2f} fast {t2:+.2f} | " + " ".join(f"{k:.0f}:{v[0]:+.2f}@{v[1]:.0f}" for k, v in rows.items()),
                          flush=True)
    res["pairs"].sort(key=lambda r: r["worst_all"])
    json.dump(res, open(a.out, "w"), indent=0)
    print("best:", res["pairs"][:5])


if __name__ == "__main__":
    main()
