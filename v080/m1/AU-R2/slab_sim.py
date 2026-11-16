#!/usr/bin/env python3
"""AU-R2: the slab layer as the game plays it at a road speed, from the files (offline model of road_audio.gd
_update_slabs): slow design at pitch v/90, fast at v/180, crossfade smoothstep(110, 150, v), each player's gain from
its loudness at its pitch (lufs_pitch of the manifest = qc_lib loudness of the resampled loop), both started at the
same share (in step, AU-R) or at independent random shares (AU-C1). Third octaves as KRITIK-R (dsp.third_octaves)
of the mono signal (the slab layer is a centred plain player).
usage: slab_sim.py <old_dir> <new_dir> [kmh ...]"""
import json
import os
import sys

import numpy as np

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(S, "ktools"))
sys.dont_write_bytecode = True
import dsp  # noqa: E402
import qc_lib  # noqa: E402

SR = 44100
GUARD = 16


def load_loop(d, name):
    x, sr = qc_lib.read_audio(os.path.join(d, name))
    y = np.asarray(x, np.float64)[:, 0]
    man = json.load(open(os.path.join(d, "manifest.json")))
    e = man["sounds"][name.rsplit(".", 1)[0]]
    lb, le = e.get("loop", [0, len(y)]) if isinstance(e.get("loop"), list) else (e.get("loop_begin", 0), e.get("loop_end", len(y)))
    return y[lb:le], e


def play(y, pitch, seconds, start_share):
    n = len(y)
    m = int(seconds * SR)
    pos = (start_share * n + np.arange(m) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    return y[i] * (1.0 - fr) + y[(i + 1) % n] * fr


def lufs_curve(e, p):
    c = e.get("lufs_pitch") or []
    if len(c) < 2:
        return float(e["lufs"])
    lp = np.log(max(p, 0.01))
    xs = np.log([float(a) for a, _ in c])
    ys = [float(b) for _, b in c]
    return float(np.interp(lp, xs, ys))


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def layer(d, kmh, seconds=20.0, in_step=True, seed=1):
    ys, es = load_loop(d, "slab_slow.wav")
    yf, ef = load_loop(d, "slab_fast.wav")
    rng = np.random.default_rng(seed)
    xf = smoothstep(110.0, 150.0, kmh)
    ps, pf = kmh / 90.0, kmh / 180.0
    a = rng.random()
    b = a if in_step else rng.random()
    T = -20.0
    out = np.zeros(int(seconds * SR))
    if 1.0 - xf > 0:
        out += play(ys, ps, seconds, a) * 10 ** ((T - lufs_curve(es, ps)) / 20) * (1.0 - xf)
    if xf > 0:
        out += play(yf, pf, seconds, b) * 10 ** ((T - lufs_curve(ef, pf)) / 20) * xf
    return out


def main():
    old, new = sys.argv[1], sys.argv[2]
    speeds = [float(v) for v in sys.argv[3:]] or [90.0, 130.0, 170.0, 200.0]
    c = np.array(dsp.TOB_CENTRES)
    m = (c >= 25) & (c <= 12500)
    for kmh in speeds:
        res = {}
        for lab, d, step in (("old_rand", old, False), ("old_step", old, True), ("new_step", new, True), ("new_rand", new, False)):
            accs = []
            for seed in range(1, 5):
                x = layer(d, kmh, 20.0, step, seed)
                _c, L = dsp.third_octaves(np.stack([x, x], 1))
                accs.append(10 ** (np.array(L) / 10))
                if seed == 1:
                    res[lab + "_lufs"] = dsp.lufs_plain(np.stack([x, x], 1))
                    res[lab + "_tp"] = dsp.tp(np.stack([x, x], 1))
            res[lab] = 10 * np.log10(np.mean(accs, axis=0))
        ref = res["old_rand"]
        floor = ref[m].max() - 30.0
        print(f"== {kmh:.0f} km/h  lufs old_rand {res['old_rand_lufs']:.2f} new_step {res['new_step_lufs']:.2f}  tp old {res['old_rand_tp']:.2f} new {res['new_step_tp']:.2f}")
        for lab in ("old_step", "new_step", "new_rand"):
            d = res[lab] - ref
            # equal loudness as the game (it sets levels by loudness): compare balance after removing the lufs offset
            dl = res[lab + "_lufs"] - res["old_rand_lufs"]
            mm = m & (ref > floor)
            i = int(np.argmax(np.where(mm, np.abs(d), -1)))
            row = " ".join(f"{c[k]:.0f}:{d[k]:+.2f}" for k in range(len(c)) if mm[k])
            print(f"  {lab:9s} dLU {dl:+.2f}  max {d[i]:+.2f} @ {c[i]:.0f} Hz | {row}")


if __name__ == "__main__":
    main()
