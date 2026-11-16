#!/usr/bin/env python3
"""KRITIK-R2-MESS: clicks where a slab loop starts or is put back in step (km_slab.gd captures: slow design on MRoad,
fast design on MWind, rows per frame with the counters slab_realigned / slab_locks).
Per event (start of a loop: its share goes from -1 to >= 0; realignment: the counter grows – the quieter loop
restarts) the 93-ms window from 23 ms before the frame's capture index: the largest sample step |x[n]-x[n-1]| and
the largest 8-kHz high-passed peak, each as a percentile rank among all such windows of the same capture while that
loop plays (a click shows as a window above every ordinary one; strikes of the pattern set the ordinary range).
Also the offsets of the two loops (positions and audio) as ana_slab.py.
usage: ana_slabclick.py <base> <out.json>"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402
from ana_cap import load_f32  # noqa: E402

SR = 44100
PRE, POST = 1024, 3072


def window_stats(x, hp):
    m = x.mean(axis=1)
    d = np.abs(np.diff(m, prepend=m[0]))
    h = np.abs(hp)
    n = len(m)
    w = PRE + POST
    starts = np.arange(0, n - w, w // 2)
    dmax = np.array([d[s:s + w].max() for s in starts])
    hmax = np.array([h[s:s + w].max() for s in starts])
    lev = np.array([np.sqrt(np.mean(m[s:s + w] ** 2)) for s in starts])
    return starts, dmax, hmax, lev, d, h


def main():
    base, out = sys.argv[1], sys.argv[2]
    meta = json.load(open(base + ".json"))
    rows = meta["rows"]
    res = {"realigned_total": meta.get("realigned"), "rows": len(rows)}
    for key, col_idx, share_i, lev_i in (("slow", 2, 4, 6), ("fast", 3, 5, 7)):
        x = load_f32(base + "_" + key + ".f32")
        m = x.mean(axis=1)
        hp = dsp.zero_phase(m, SR, dsp.hp_mag(8000.0, 4))
        starts, dmax, hmax, lev, d, h = window_stats(x, hp)
        playing = lev > 1e-4
        events = []
        for i in range(1, len(rows)):
            r0, r1 = rows[i - 1], rows[i]
            kind = None
            if r0[share_i] < 0 <= r1[share_i]:
                kind = "start"
            elif len(r1) > 10 and r1[10] > r0[10]:
                # the quieter loop restarts (lv_s >= lv_f -> fast restarts)
                quiet = "fast" if r1[6] >= r1[7] else "slow"
                if quiet == key:
                    kind = "realign"
            if kind:
                c = int(r1[col_idx])
                a, b = max(0, c - PRE), min(len(m), c + POST)
                if b - a < 1000:
                    continue
                dm, hm = float(d[a:b].max()), float(h[a:b].max())
                ref_d, ref_h = dmax[playing], hmax[playing]
                events.append({"kind": kind, "t": r1[0], "kmh": r1[1], "idx": c,
                               "step_pct": round(float((ref_d < dm).mean() * 100), 1),
                               "hp8k_pct": round(float((ref_h < hm).mean() * 100), 1),
                               "step_rel_p99": round(dm / (np.percentile(ref_d, 99) + 1e-12), 2),
                               "hp8k_rel_p99": round(hm / (np.percentile(ref_h, 99) + 1e-12), 2),
                               "level_db": round(float(20 * np.log10(np.sqrt(np.mean(m[a:b] ** 2)) + 1e-12)), 1)})
        res[key] = {"events": events, "windows_playing": int(playing.sum()),
                    "n_start": sum(1 for e in events if e["kind"] == "start"),
                    "n_realign": sum(1 for e in events if e["kind"] == "realign")}
        for kind in ("start", "realign"):
            ev = [e for e in events if e["kind"] == kind]
            if ev:
                res[key][kind + "_max_step_rel_p99"] = max(e["step_rel_p99"] for e in ev)
                res[key][kind + "_max_hp8k_rel_p99"] = max(e["hp8k_rel_p99"] for e in ev)
                res[key][kind + "_max_step_pct"] = max(e["step_pct"] for e in ev)
                res[key][kind + "_max_hp8k_pct"] = max(e["hp8k_pct"] for e in ev)
        print(f"{key}: {len(events)} Ereignisse ({res[key]['n_start']} Starts, {res[key]['n_realign']} Nachstellungen), "
              f"{int(playing.sum())} Fenster mit Klang")
        for kind in ("start", "realign"):
            if res[key].get(kind + "_max_step_rel_p99") is not None:
                print(f"   {kind}: größter Sprung {res[key][kind + '_max_step_rel_p99']} × p99 (Rang bis {res[key][kind + '_max_step_pct']} %), "
                      f"8-kHz-Spitze {res[key][kind + '_max_hp8k_rel_p99']} × p99 (Rang bis {res[key][kind + '_max_hp8k_pct']} %)")
    # offsets of the two loops while both play (positions)
    offs = []
    for r in rows:
        t, v, sf, ff, sh_s, sh_f, lv_s, lv_f, p_s, p_f = r[:10]
        if sh_s < 0 or sh_f < 0:
            continue
        dd = ((sh_f - sh_s + 0.5) % 1.0) - 0.5
        period = float(meta["len_slow"]) / max(p_s, 0.01)
        offs.append(abs(dd * period * 1000.0))
    if offs:
        o = np.array(offs)
        res["offset_ms"] = {"n": len(o), "median": round(float(np.median(o)), 2), "p95": round(float(np.percentile(o, 95)), 2),
                            "max": round(float(o.max()), 2), "share_over_6": round(float((o > 6).mean()), 4)}
        print("Versatz der Positionen (beide spielen):", res["offset_ms"])
    if len(rows[-1]) > 11:
        dur = rows[-1][0] - rows[0][0]
        res["locks"] = rows[-1][11] - rows[0][11]
        res["locks_per_s"] = round(res["locks"] / max(dur, 1e-6), 2)
        print(f"Sperren {res['locks']} in {dur:.1f} s ({res['locks_per_s']} je s), Nachstellungen {rows[-1][10] - rows[0][10]}")
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
