#!/usr/bin/env python3
"""Markdown table of the Leistungstest result files (QA1): one row per preset and scene.
usage: bench_table.py <file.json> [...]"""
import json
import os
import sys

BUDGET = {"deck": (650, 450000, 1.5), "low": (400, 250000, 1.2), "medium": (900, 700000, 1.5), "high": (1500, 1500000, 2.0)}
print("| Datei | Voreinstellung (Stufe) | Szene | Ø fps | 1 %-low fps | p95 / p99 ms | `render()` ms (max) | Draw Calls (+Schatten) | Dreiecke (+Schatten) | Vorbereitung s | Urteil / Vorschlag |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for path in sys.argv[1:]:
    r = json.load(open(path, encoding="utf-8"))
    preset = r.get("preset", "?")
    b = BUDGET.get(preset)
    for s in r.get("scenes", []):
        dc = s.get("draw_calls", 0)
        dcs = s.get("draw_calls_shadow", 0)
        pr = s.get("primitives", 0)
        prs = s.get("primitives_shadow", 0)
        flag = ""
        if b:
            over = []
            if dc > b[0]:
                over.append("DC")
            if pr > b[1]:
                over.append("Dreiecke")
            if s.get("script_ms", 0) > b[2]:
                over.append("Skript")
            flag = " **über Budget: %s**" % ", ".join(over) if over else " (im Budget)"
        print("| %s | %s (%s) | %s | %.1f | %.1f | %.0f / %.0f | %.2f (%.1f) | %d (%d) | %d (%d) | %.1f | %s / %s%s |" % (
            os.path.basename(path), preset, r.get("tier", "?"), s.get("id"), float(s.get("avg_fps", 0)),
            float(s.get("low1_fps", 0)), float(s.get("frame_ms_p95", 0)), float(s.get("frame_ms_p99", 0)),
            float(s.get("script_ms", 0)), float(s.get("script_ms_max", 0)), dc, dcs, pr, prs, float(s.get("prepare_s", 0)),
            r.get("verdict", "?"), r.get("suggested_preset", "?"), flag))
    print("| %s | Gerät: %s, %s, Auflösung %s, Version %s, Vorschlag Modus %s |  |  |  |  |  |  |  |  |  |" % (
        os.path.basename(path), r.get("adapter", "?"), r.get("api", "?"), r.get("resolution"), r.get("game_version"),
        r.get("suggested_mode")))
