#!/usr/bin/env python3
"""AU-R2 (M5): another seed for the right side's cobble loop (the same generator): its two loudest peaks were
coincidences of all four wheels within 1–3 ms (crest of the loop 16.2 dB against 14.3 for what AU-C1 played).
Per candidate seed offset: crest of the matched loop, its 4 loudest peaks (dB re RMS), the in-game model of
cobble_eval.py (crest per channel, third octaves of the layer, loudness) against AU-C1.
usage: cobble_search.py <old_vehicle_dir> <repo_root> <out.json> <offsets e.g. 51:91>"""
import json
import math
import os
import sys

import numpy as np

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
sys.path.insert(0, os.path.join(S, "ktools"))
sys.dont_write_bytecode = True
import cobble_eval as ce  # noqa: E402
import cobble_diag as cd  # noqa: E402

SR = 44100


def main():
    old_dir, repo, out = sys.argv[1], sys.argv[2], sys.argv[3]
    lo, hi = (int(v) for v in sys.argv[4].split(":"))
    sys.path.insert(0, os.path.join(repo, "tools", "audio", "modern"))
    import vehicle_loops as vl  # noqa: E402
    import modern_lib as ml  # noqa: E402
    import qc_lib  # noqa: E402
    import dsp  # noqa: E402
    c = np.array(dsp.TOB_CENTRES)
    band = (c >= 25) & (c <= 12500)

    def finish(y):
        y = y - float(np.mean(y))
        y = y * (vl.PEAK / float(np.max(np.abs(y))))
        return ml.limit_true_peak(y[:, None], -3.0)[:, 0]

    man_old = json.load(open(os.path.join(old_dir, "manifest.json")))["sounds"]
    x, _ = qc_lib.read_audio(os.path.join(old_dir, "tyre_cobbles.wav"))
    lb, le = man_old["tyre_cobbles"]["loop"]
    y_old = np.asarray(x, np.float64)[lb:le, 0]
    cur = man_old["tyre_cobbles"]["lufs_pitch"]
    ref = ce.stats(dsp, ce.game(y_old, y_old, cur, cur, 1.0, True))
    ref_heard = vl.heard(vl.tyre_cobbles(int(round(2.5 * SR)), 50.0, 0), vl.OLD_PAN["MRoad"])
    left = finish(vl.match_loop(vl.tyre_cobbles(int(round(5.7 * SR)), 50.0, 0), ref_heard))
    cl = [[p, vl.lufs_at_pitch(left, p)] for p in vl.PITCHES]
    rows = []
    for s in range(lo, hi):
        y = finish(vl.match_loop(vl.tyre_cobbles(int(round(7.1 * SR)), 50.0, s), ref_heard))
        cr = [[p, vl.lufs_at_pitch(y, p)] for p in vl.PITCHES]
        st = ce.stats(dsp, ce.game(left, y, cl, cr, 1.02, False))
        d = np.array(st["tob"]) - np.array(ref["tob"])
        m = band & (np.array(ref["tob"]) > np.array(ref["tob"])[band].max() - 30)
        i = int(np.argmax(np.where(m, np.abs(d), -1)))
        own = cd.crest(y)
        r = {"s": s, "crest": round(own, 2), "top": [p[1] for p in cd.top_peaks(y, 4)], "tob": round(float(d[i]), 2),
             "at": float(c[i]), "dlu": round(st["lufs"] - ref["lufs"], 2), "L": st["L"]["crest"], "R": st["R"]["crest"],
             "rep": st["rep"][:3]}
        rows.append(r)
        print(f"s {s}: crest {own:.2f} top {r['top']} | game tob {r['tob']:+.2f}@{r['at']:.0f} dLU {r['dlu']:+.2f} "
              f"L {r['L']} R {r['R']} (AU-C1 {ref['L']['crest']}) rep {r['rep']}", flush=True)
    rows.sort(key=lambda r: (max(r["L"], r["R"]), abs(r["tob"])))
    json.dump(rows, open(out, "w"), indent=0)
    print("best:", [(r["s"], r["L"], r["R"], r["tob"], r["dlu"]) for r in rows[:8]])


if __name__ == "__main__":
    main()
