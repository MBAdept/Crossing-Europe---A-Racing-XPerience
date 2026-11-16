#!/usr/bin/env python3
"""KRITIK-R2-MESS: R1 / V1 table from ana_cap results (plan A, as played): per recording and band the largest value of
the envelope autocorrelation at 0.3-3 s (mono), the local peaks 0.3-3 s and 3-8 s, per channel.
usage: tab_r1.py <c1.json> <obj1.json> <obj2.json>"""
import json
import sys

c1, o1, o2 = (json.load(open(p)) for p in sys.argv[1:4])
ROWS = [("asph130_full", "600-1600", "Asphalt 130, Spielmix", True), ("cobbles50_full", "2500-8000", "Pflaster 50, Spielmix", True),
        ("conc130_noslab_full", "2500-8000", "Beton 130 ohne Plattenschicht, Spielmix", True),
        ("conc130_full", "2500-8000", "Beton 130 mit Platten, Spielmix (zur Kenntnis)", False),
        ("asph130_road", "600-1600", "Asphalt 130, nur Fahrbahn (zur Kenntnis)", False),
        ("cobbles50_road", "2500-8000", "Pflaster 50, nur Fahrbahn (zur Kenntnis)", False),
        ("conc130_noslab_road", "2500-8000", "Beton 130 ohne Platten, nur Fahrbahn (zur Kenntnis)", False)]


def f(v):
    return f"{v[1]:.3f} bei {v[0]:.2f} s".replace(".", ",")


def pk(lst, n=3):
    return "; ".join(f(p[::-1][::-1]) if False else f"{p[1]:.3f} bei {p[0]:.2f} s".replace(".", ",") for p in lst[:n])


print("| Aufnahme (Band) | AU-C1 größte 0,3–3 s | Endstand Seed 7301 | Endstand Seed 7401 | Endstand: Spitzen 3–8 s (7301) | L / R (7301) | V1 < 0,40 |")
print("|---|---|---|---|---|---|---|")
for seg, band, label, crit in ROWS:
    cells = []
    for R in (c1, o1, o2):
        s = R["segments"].get(seg)
        cells.append(f(s["rep"][band]["mono"]["max_0.3_3"]) if s else "–")
    s = o1["segments"][seg]["rep"][band]
    s2 = o2["segments"].get(seg, {}).get("rep", {}).get(band) if o2["segments"].get(seg) else None
    worst = max(s["mono"]["max_0.3_3"][1], s2["mono"]["max_0.3_3"][1] if s2 else 0.0)
    verdict = ("ja" if worst < 0.40 else "**nein**") if crit else "–"
    lr = f"{s['L']['max_0.3_3'][1]:.3f} / {s['R']['max_0.3_3'][1]:.3f}".replace(".", ",")
    print(f"| {label} ({band.replace('-', '–')} Hz) | {cells[0]} | {cells[1]} | {cells[2]} | {pk(s['mono']['peaks_3_8'])} | {lr} | {verdict} |")
