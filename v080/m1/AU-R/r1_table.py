#!/usr/bin/env python3
"""AU-R: the R1 table (envelope autocorrelation peaks) before → after as Markdown.
usage: r1_table.py <res_before.json> <res_after.json> [<res_noslab.json>]"""
import json
import sys

rb = json.load(open(sys.argv[1]))["segments"]
ra = json.load(open(sys.argv[2]))["segments"]
rn = json.load(open(sys.argv[3]))["segments"] if len(sys.argv) > 3 else {}


def fmt(peaks, n=3):
    out = [f"{v:.3f} bei {t:.2f} s".replace(".", ",") for t, v in peaks[:n] if v > 0]
    return ", ".join(out) if out else "–"


def row(name, seg, band, res_b, res_a):
    b = res_b.get(seg, {}).get("rep", {}).get(band, {}).get("mono") if res_b else None
    a = res_a[seg]["rep"][band]["mono"]
    pb = fmt(b["peaks_0.3_3"]) if b else "–"
    pa = fmt(a["peaks_0.3_3"])
    mx = a["peaks_0.3_3"][0][1] if a["peaks_0.3_3"] else 0.0
    verdict = "ja" if mx < 0.40 else "nein"
    label = "breitbandig" if band == "broad" else band.replace("-", "–") + " Hz"
    return f"| {name} | {label} | {pb} | {pa} | {fmt(a['peaks_3_8'], 4)} | {verdict} |"


print("| Aufnahme | Band | vorher: Spitzen 0,3–3 s | nachher: Spitzen 0,3–3 s | nachher: Spitzen 3–8 s | < 0,40 |")
print("|---|---|---|---|---|---|")
print(row("Asphalt 130 km/h", "asph130_full", "600-1600", rb, ra))
print(row("Asphalt 130 km/h", "asph130_full", "2500-8000", rb, ra))
print(row("Beton 130 km/h", "conc130_full", "2500-8000", rb, ra))
print(row("Beton 130 km/h", "conc130_full", "600-1600", rb, ra))
if rn:
    print(row("Beton 130 km/h ohne Plattenschicht", "conc130_noslab_full", "2500-8000", {}, rn))
print(row("Pflaster 50 km/h", "cobbles50_full", "2500-8000", rb, ra))
print(row("Pflaster 50 km/h", "cobbles50_full", "600-1600", rb, ra))
print(row("Pflaster 50 km/h", "cobbles50_full", "broad", rb, ra))
