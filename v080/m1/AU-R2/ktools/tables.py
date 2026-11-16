#!/usr/bin/env python3
"""AU-R2: the tables of the report from the ana_cap results – AU-C1 (vorher, own capture), AU-R (KRITIK-R's
capture of the AU-R head, res/*_after.json there), AU-R2 (nachher, own capture). Markdown on stdout.
usage: tables.py"""
import json
import os

import numpy as np

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2"
K = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R"


def load(p):
    return json.load(open(p)) if os.path.exists(p) else {"segments": {}}


def third_diff(a, b, centres, floor_db=30.0):
    a, b, c = np.array(a), np.array(b), np.array(centres)
    m = (c >= 25) & (c <= 12500)
    m &= (a > a[m].max() - floor_db) | (b > b[m].max() - floor_db)
    d = b - a
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    return float(d[i]), float(c[i])


def de(x, nd=2):
    return f"{x:.{nd}f}".replace(".", ",").replace("-", "−")


def sde(x, nd=2):
    s = f"{x:+.{nd}f}".replace(".", ",").replace("-", "−")
    return s


def main():
    Bb, Ba = load(f"{S}/res/B_before.json"), load(f"{S}/res/B_after.json")
    Ab, Aa = load(f"{S}/res/A_before.json"), load(f"{S}/res/A_after.json")
    KBa, KAa = load(f"{K}/res/B_after.json"), load(f"{K}/res/A_after.json")
    KBb = load(f"{K}/res/B_before.json")
    cen = (Ba.get("centres") or Bb.get("centres"))
    print("## Klangfarbe (Plan B, ohne Zufall; Lautheit ungegatet @1,0; größte Terz-Abweichung 25 Hz–12,5 kHz, 30 dB)\n")
    print("| Aufnahme | AU-C1 → AU-R (KRITIK-R) | AU-C1 → AU-R2 (eigene Aufnahme) | in den Grenzen |")
    print("|---|---|---|---|")
    for seg in Ba["segments"]:
        a, b = Bb["segments"].get(seg), Ba["segments"][seg]
        if not a:
            continue
        d, fc = third_diff(a["third_oct"], b["third_oct"], cen)
        dlu = b["lufs_plain_1.0"] - a["lufs_plain_1.0"]
        k = ""
        ka, kb = KBb["segments"].get(seg), KBa["segments"].get(seg)
        if ka and kb:
            kd, kf = third_diff(ka["third_oct"], kb["third_oct"], cen)
            k = f"{sde(kb['lufs_plain_1.0'] - ka['lufs_plain_1.0'])} LU, {sde(kd)} dB bei {kf:.0f} Hz"
        ok = "ja" if abs(dlu) <= 0.5 and abs(d) <= 1.0 else "**nein**"
        print(f"| {seg} | {k} | {de(a['lufs_plain_1.0'])} → {de(b['lufs_plain_1.0'])} LUFS ({sde(dlu)} LU), {sde(d)} dB bei {fc:.0f} Hz | {ok} |")
    print("\n## R1 Wiederholung (Plan A, wie gespielt; Hüllkurven-Autokorrelation der Monosumme)\n")
    print("| Aufnahme (Band) | AU-C1 (0,3–3 s) | AU-R (KRITIK-R) | AU-R2 (0,3–3 s) | AU-R2 Spitzen 3–8 s | < 0,40 |")
    print("|---|---|---|---|---|---|")
    rows = [("conc130_full", "2500-8000"), ("conc130_full", "600-1600"), ("conc130_noslab_full", "2500-8000"),
            ("conc130_full_slab+0", "2500-8000"), ("conc130_full_slab-3", "2500-8000"),
            ("cobbles50_full", "2500-8000"), ("cobbles50_full", "600-1600"), ("cobbles50_road", "2500-8000"),
            ("asph130_full", "600-1600"), ("conc170_full", "2500-8000"), ("conc200_full", "2500-8000")]
    for seg, band in rows:
        def mx(R):
            s = R["segments"].get(seg)
            if not s or band not in s.get("rep", {}):
                return None
            return s["rep"][band]["mono"]
        b, k, a = mx(Ab), mx(KAa), mx(Aa)
        if a is None:
            continue
        f = lambda m: (f"{de(m['max_0.3_3'][1], 3)} bei {de(m['max_0.3_3'][0])} s" if m else "–")
        p38 = ", ".join(f"{de(v, 3)} bei {de(t)} s" for t, v in a["peaks_3_8"][:3])
        print(f"| {seg} ({band}) | {f(b)} | {f(k)} | {f(a)} | {p38} | {'ja' if a['max_0.3_3'][1] < 0.40 else '**nein**'} |")
    print("\n## Begrenzer und Spitzen (Plan A, Gesamtlautstärke 1,0)\n")
    print("| Aufnahme | True Peak AU-C1 | AU-R (KRITIK-R) | AU-R2 | vor dem Begrenzer AU-R2 | Begrenzung AU-R2 |")
    print("|---|---|---|---|---|---|")
    for R, lab in ((Aa, ""), (load(f"{S}/res/M3_after.json"), "M3"), (load(f"{S}/res/M3B_after.json"), "M3B")):
        for seg, s in R["segments"].items():
            if lab == "" and seg not in ("conc130_full", "conc170_full", "conc200_full", "asph130_full", "cobbles50_full"):
                continue
            b = Ab["segments"].get(seg, {})
            k = KAa["segments"].get(seg, {})
            lim = s.get("limiter", {})
            print(f"| {seg} | {de(b['tp_1.0']) if b else '–'} | {de(k['tp_1.0']) if k else '–'} | {de(s['tp_1.0'])} dBTP | "
                  f"{de(lim.get('pre_peak_db', float('nan')))} dBFS | max {de(lim.get('gr_max_db', float('nan')))} dB, "
                  f"{lim.get('events', '-')} Eingriffe in {de(lim.get('seconds', 0), 0)} s |")


if __name__ == "__main__":
    main()
