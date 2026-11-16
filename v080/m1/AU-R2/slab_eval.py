#!/usr/bin/env python3
"""AU-R2 (H1): the 32-slab patterns built from AU-C1's joints (vehicle_loops.slab_pattern) against AU-C1's designs,
as the game plays them (model of slab_search.py): single designs at 90/105 and 160/180/200/230 km/h, the in-step
pair at 120/130/140 km/h; third octaves (max |diff| in the 30-dB range), ungated loudness and true peak at equal
gated loudness (dTP > 0: the new peaks higher).
usage: slab_eval.py <old_vehicle_dir> <repo_root> <out.json> [--orders=3301:3311] [--spread=0.8,1.2,1.6]"""
import argparse
import json
import os
import sys

import numpy as np

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
sys.path.insert(0, os.path.join(S, "ktools"))
sys.dont_write_bytecode = True
import slab_search as ss  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("repo")
    ap.add_argument("out")
    ap.add_argument("--orders", default="3301:3302")
    ap.add_argument("--spread", default="1.2")
    ap.add_argument("--top", default="0")
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

    old = {}
    for nm in ("slab_slow", "slab_fast"):
        x, _sr = qc_lib.read_audio(os.path.join(a.old, nm + ".wav"))
        man = json.load(open(os.path.join(a.old, "manifest.json")))["sounds"][nm]
        lb, le = man["loop"]
        old[nm] = ss.Design(np.asarray(x, np.float64)[lb:le, 0], man["lufs_pitch"])
    # sanity: AU-C1's file = the refactored slab_loop (bit-identical up to the 16-bit rounding)
    for nm, kmh in (("slab_slow", 90.0), ("slab_fast", 180.0)):
        y = finish(vl.slab_loop(kmh, vl.SLAB_SOURCE[kmh]))
        print(f"{nm}: max |AU-C1 file - slab_loop()| = {float(np.max(np.abs(old[nm].y - y))):.2e}")
    speeds = ss.SPEEDS_SLOW + ss.SPEEDS_MIX + ss.SPEEDS_FAST
    ref = {v: ss.measure(dsp, ss.layer(old["slab_slow"], old["slab_fast"], v)) for v in speeds}
    lo, hi = (int(v) for v in a.orders.split(":"))
    rows = []
    for seed in range(lo, hi):
        order = vl.slab_order(vl.SLABS, vl.SLAB_SOURCE_N, seed)
        for spread, top in [(float(s), float(t)) for s in a.spread.split(",") for t in a.top.split(",")]:
            acc = vl.slab_accents(vl.SLABS, seed, spread)
            d = {}
            for kmh in (90.0, 180.0):
                src = vl.SLAB_SOURCE[kmh]
                y = finish(vl.match_loop(vl.slab_pattern(kmh, src, order, acc, top), vl.slab_loop(kmh, src)))
                d[kmh] = ss.Design(y, [[p, vl.lufs_at_pitch(y, p)] for p in vl.PITCHES])
            res = {}
            for v in speeds:
                res[v] = ss.diff(dsp, ref[v], ss.measure(dsp, ss.layer(d[90.0], d[180.0], v)))
            worst = max(abs(r[0]) for r in res.values())
            dlu = max(abs(r[2]) for r in res.values())
            dtp = {v: round(r[3], 2) for v, r in res.items()}
            rows.append({"seed": seed, "spread": spread, "top": top, "worst": round(worst, 2), "dlu": round(dlu, 2), "dtp": {str(k): v for k, v in dtp.items()}, "dtp_f": dtp,
                         "rows": {str(v): [round(t, 2) for t in r] for v, r in res.items()}, "order": order,
                         "accents": [round(float(x), 2) for x in acc]})
            print(f"order {seed} spread {spread} top {top}: worst {worst:.2f} dLU {dlu:.2f} | "
                  + " ".join(f"{v:.0f}:{r[0]:+.2f}@{r[1]:.0f}/{r[2]:+.2f}LU/tp{r[3]:+.2f}" for v, r in res.items()), flush=True)
    rows.sort(key=lambda r: r["worst"])
    json.dump([{k: v for k, v in r.items() if k != "dtp_f"} for r in rows], open(a.out, "w"), indent=0)
    print("best:", [(r["seed"], r["spread"], r["top"], r["worst"], r["dlu"], r["dtp_f"][200.0], r["dtp_f"][130.0]) for r in rows[:8]])


if __name__ == "__main__":
    main()
