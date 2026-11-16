#!/usr/bin/env python3
"""KRITIK-R2-MESS: V3 tables – cruising runs (ana_cap results: limiter gain reduction per run, events, pre-limiter
peak, true peak at Gesamtlautstärke 1.0) and the share of 10-ms blocks above 0.1 / 0.5 dB, plus the gain-reduction
time course in 1-s steps (pumping: periodic interventions would show as a regular pattern).
usage: tab_v3.py <ana_cap.json> [seg ...]"""
import json
import sys

import numpy as np

d = json.load(open(sys.argv[1]))
segs = sys.argv[2:] or list(d["segments"])
print("| Lauf | Dauer (s) | größte Begrenzung (dB) | Eingriffe > 0,1 dB | Anteil > 0,1 / > 0,5 dB | Spitze vor dem Begrenzer (dBFS) | True Peak @1,0 (dBTP) | LUFS @0,8 |")
print("|---|---|---|---|---|---|---|---|")
for s in segs:
    r = d["segments"].get(s)
    if not r:
        continue
    L = r.get("limiter", {})
    print(f"| {s} | {L.get('seconds')} | {L.get('gr_max_db')} | {L.get('events')} | {L.get('gr_share_over_0.1')} / {L.get('gr_share_over_0.5')} | "
          f"{L.get('pre_peak_db')} | {r['tp_1.0']} | {r['lufs_0.8']} |")
