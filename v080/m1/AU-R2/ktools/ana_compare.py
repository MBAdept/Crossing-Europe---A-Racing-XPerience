#!/usr/bin/env python3
"""KRITIK-R: before / after tables from the ana_cap.py results of plans A and B.
usage: ana_compare.py <A_before.json> <A_after.json> <B_before.json> <B_after.json> <out.json>"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402

K = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R"


def third_diff(a, b, centres, floor_db=30.0):
    a, b, c = np.array(a), np.array(b), np.array(centres)
    m = (c >= 25) & (c <= 12500)
    m &= (a > a[m].max() - floor_db) | (b > b[m].max() - floor_db)
    d = b - a
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    return round(float(d[i]), 2), round(float(c[i])), [round(float(v), 2) for v in d]


def main():
    Ab, Aa, Bb, Ba = (json.load(open(p)) for p in sys.argv[1:5])
    out = {}
    cen = Aa["centres"]
    print("== R1 Wiederholung (Spielmix, Hüllkurven-Autokorrelation, Monosumme) – vorher -> nachher")
    r1 = {}
    for seg, band in (("asph130_full", "600-1600"), ("asph130_full", "2500-8000"), ("conc130_full", "2500-8000"),
                      ("conc130_full", "600-1600"), ("conc130_noslab_full", "2500-8000"), ("cobbles50_full", "2500-8000"),
                      ("cobbles50_full", "600-1600"), ("cobbles50_full", "broad"), ("asph200_full", "600-1600"),
                      ("asph130_road", "600-1600"), ("conc130_road", "2500-8000"), ("cobbles50_road", "2500-8000"),
                      ("asph130_wind", "600-1600"), ("asph130_wind", "2500-8000")):
        row = {}
        for lab, R in (("vorher", Ab), ("nachher", Aa)):
            s = R["segments"].get(seg)
            if not s or band not in s["rep"]:
                continue
            d = s["rep"][band]
            row[lab] = {"max_0.3_3": d["mono"]["max_0.3_3"], "peaks_0.3_3": d["mono"]["peaks_0.3_3"][:3],
                        "peaks_3_8": d["mono"]["peaks_3_8"][:4], "L": d["L"]["max_0.3_3"], "R": d["R"]["max_0.3_3"]}
        r1[f"{seg}|{band}"] = row
        v, n = row.get("vorher", {}), row.get("nachher", {})
        print(f"  {seg:20s} {band:9s} vorher {v.get('max_0.3_3')} {v.get('peaks_0.3_3')} | nachher {n.get('max_0.3_3')} "
              f"{n.get('peaks_0.3_3')} | 3–8 s {n.get('peaks_3_8')} | L/R nachher {n.get('L')} {n.get('R')}")
    out["r1"] = r1
    print("== Pegel und Spitzen (Spielmix, A) – vorher -> nachher; Lautheit @0.8 = Aufnahme - 1.94 dB")
    lv = {}
    for seg in Aa["segments"]:
        a, b = Ab["segments"].get(seg), Aa["segments"][seg]
        if not a:
            continue
        la, lb = a.get("limiter", {}), b.get("limiter", {})
        lv[seg] = {"lufs08": [a["lufs_0.8"], b["lufs_0.8"]], "tp10": [a["tp_1.0"], b["tp_1.0"]],
                   "pre_tp": [a.get("pre_tp"), b.get("pre_tp")], "gr_after": {k: lb.get(k) for k in ("gr_max_db", "events",
                   "gr_share_over_0.1", "gr_share_over_0.5", "seconds", "pre_peak_db", "post_peak_db")},
                   "pre_peak_before": la.get("pre_peak_db")}
        print(f"  {seg:20s} LUFS@0.8 {a['lufs_0.8']:7.2f} -> {b['lufs_0.8']:7.2f} ({b['lufs_0.8'] - a['lufs_0.8']:+.2f}) | TP@1.0 "
              f"{a['tp_1.0']:6.2f} -> {b['tp_1.0']:6.2f} | vor dem Begrenzer: Spitze vorher {la.get('pre_peak_db')} nachher "
              f"{lb.get('pre_peak_db')}, GR max {lb.get('gr_max_db')} dB, {lb.get('events')} Eingriffe in {lb.get('seconds')} s, "
              f"Anteil >0,5 dB {lb.get('gr_share_over_0.5')}")
    out["levels"] = lv
    print("== Klangfarbe (B, ohne Zufall) – Lautheit (ungated, @1.0) und größte Terz-Abweichung 25 Hz–12,5 kHz (30 dB)")
    ch = {}
    for seg in Ba["segments"]:
        a, b = Bb["segments"].get(seg), Ba["segments"][seg]
        if not a:
            continue
        d, fc, dl = third_diff(a["third_oct"], b["third_oct"], cen)
        dlu = round(b["lufs_plain_1.0"] - a["lufs_plain_1.0"], 2)
        ch[seg] = {"lufs": [a["lufs_plain_1.0"], b["lufs_plain_1.0"]], "dlu": dlu, "max_third_db": d, "at_hz": fc, "third_diff": dl,
                   "feed": [a["feed"]["paving"], b["feed"]["paving"], a["feed"]["surface_r"], b["feed"]["surface_r"]]}
        flag = "" if (abs(dlu) <= 0.5 and abs(d) <= 1.0) else "  <-- außerhalb"
        print(f"  {seg:18s} {a['lufs_plain_1.0']:7.2f} -> {b['lufs_plain_1.0']:7.2f} LUFS ({dlu:+.2f} LU) | größte Terz {d:+.2f} dB bei {fc} Hz"
              f" | {a['feed']['paving']}/{a['feed']['surface_r']} -> {b['feed']['paving']}/{b['feed']['surface_r']}{flag}")
    out["character"] = ch
    # the same with drift on (A): road / wind only, 20 s
    print("== dieselben Schichten mit Drift (A, wie gespielt)")
    for seg in ("asph130_road", "conc130_road", "cobbles50_road", "asph130_wind", "asph130_full", "conc130_full", "cobbles50_full"):
        a, b = Ab["segments"].get(seg), Aa["segments"].get(seg)
        if not a or not b:
            continue
        d, fc, _dl = third_diff(a["third_oct"], b["third_oct"], cen)
        print(f"  {seg:18s} {a['lufs_plain_1.0']:7.2f} -> {b['lufs_plain_1.0']:7.2f} LUFS ({b['lufs_plain_1.0'] - a['lufs_plain_1.0']:+.2f}) | "
              f"größte Terz {d:+.2f} dB bei {fc} Hz")
        out.setdefault("character_drift", {})[seg] = {"dlu": round(b["lufs_plain_1.0"] - a["lufs_plain_1.0"], 2), "max_third_db": d, "at_hz": fc}
    json.dump(out, open(sys.argv[5], "w"), indent=1)


if __name__ == "__main__":
    main()
