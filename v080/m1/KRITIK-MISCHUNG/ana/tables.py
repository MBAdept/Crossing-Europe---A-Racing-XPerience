#!/usr/bin/env python3
"""Markdown tables for bericht.md (German number format) from the result JSONs. usage: tables.py <K>"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

K = sys.argv[1]
R = json.load(open(os.path.join(K, "res", "files.json")))
M = json.load(open(os.path.join(K, "res", "masking.json")))
E = json.load(open(os.path.join(K, "res", "eq_alt.json")))
T = json.load(open(os.path.join(K, "res", "transitions.json")))
KN = json.load(open(os.path.join(K, "res", "knobs.json")))


def de(v, nd=1, sign=False):
    if v is None:
        return "–"
    s = f"{v:+.{nd}f}" if sign else f"{v:.{nd}f}"
    return s.replace("-", "−").replace(".", ",")


NAMES = {"REF_title_v050": "Titelmelodie v0.5.0 (Referenz)", "titel_remaster": "Titel-Remaster", "zwischenspiel": "Zwischenspiel",
         "linke_spur": "Linke Spur", "nachtfahrt": "Nachtfahrt", "rueckenwind": "Rückenwind"}


def seg(n):
    return R[n].get("loop") or R[n]["all"]


print("### T1 Lautheit und Spitzen (Schleife; Referenz ganze Datei)\n")
print("| Stück | integriert LUFS | Kurzzeit max / P10 | LRA LU | True Peak dBTP | PLR dB | PSR Median dB | Einzähler / A1 LUFS |")
print("|---|---|---|---|---|---|---|---|")
for n in NAMES:
    s = seg(n)
    ci = R[n].get("countin", {})
    a1 = R[n].get("a1", {})
    ca = f"{de(ci.get('lufs_i'))} / {de(a1.get('lufs_i'))}" if ci else "–"
    print(f"| {NAMES[n]} | {de(s['lufs_i'],2)} | {de(s['st_max'])} / {de(s['st_p10'])} | {de(s['lra'])} | {de(s['tp'],2)} | "
          f"{de(s['plr'])} | {de(s['psr_median'])} | {ca} |")

print("\n### T2 Klangbalance: Anteil je Band an der Gesamtenergie (dB), Neigung\n")
bands = [("sub_lt40", "< 40"), ("sub_40_60", "40–60"), ("bass_60_120", "60–120"), ("bass_120_250", "120–250"),
         ("lowmid_250_800", "250–800"), ("mid_800_2k", "0,8–2 k"), ("presence_2k_5k", "2–5 k"), ("brill_5k_8k", "5–8 k"),
         ("air_8k_12k", "8–12 k"), ("air_gt12k", "> 12 k")]
print("| Stück | " + " | ".join(b[1] for b in bands) + " | Neigung 0,1–10 k / 1–10 k (dB/Okt) |")
print("|---|" + "---|" * len(bands) + "---|")
for n in NAMES:
    s = seg(n)
    print(f"| {NAMES[n]} | " + " | ".join(de(s['bands_rel_db'][b[0]]) for b in bands) +
          f" | {de(s['tilt_100_10k'],2)} / {de(s['tilt_1k_10k'],2)} |")
ref = seg("REF_title_v050")
print("| **Rennstücke − Referenz** | " + " | ".join(
    de(np.mean([seg(n)['bands_rel_db'][b[0]] for n in ('linke_spur', 'nachtfahrt', 'rueckenwind')]) - ref['bands_rel_db'][b[0]], 1, True)
    for b in bands) + " | |")

print("\n### T3 Stereo je Band: Korrelation / Seite gegen Mitte (dB)\n")
sb = [("lt120", "< 120 Hz"), ("120_500", "120–500"), ("500_2k", "0,5–2 k"), ("2k_5k", "2–5 k"), ("5k_10k", "5–10 k"), ("gt10k", "> 10 k")]
print("| Stück | " + " | ".join(b[1] for b in sb) + " | Monosumme | Bass < 120 Hz: kleinste Korr. (100 ms) |")
print("|---|" + "---|" * len(sb) + "---|---|")
for n in NAMES:
    s = seg(n)
    print(f"| {NAMES[n]} | " + " | ".join(f"{de(s['stereo'][b[0]]['corr'],2)} / {de(s['stereo'][b[0]]['side_mid_db'])}" for b in sb) +
          f" | {de(R[n]['mono_loss_db'],1,True)} dB | {de(R[n]['lowcorr']['corr_min'],2)} |")

print("\n### T4 Zusatzclips\n")
print("| Clip | Länge s | LUFS | Kurzzeit max | Momentan max | True Peak | Neigung 1–10 k |")
print("|---|---|---|---|---|---|---|")
for n, r in R.items():
    if n.startswith("ui:") or n in NAMES:
        continue
    a = r["all"]
    print(f"| {n} | {de(r['dur_s'])} | {de(a['lufs_i'],2)} | {de(a['st_max'])} | {de(a['mom_max'])} | {de(a['tp'],2)} | {de(a['tilt_1k_10k'],1)} |")

print("\n### T5 Spielmix je Fahrzustand (LUFS am Master)\n")
caps = {}
for c in ("gt_car", "sw_car", "gt_engine", "gt_tyres", "gt_wind", "gt_music", "gt_all"):
    caps[c] = json.load(open(os.path.join(K, "cap", c + ".wav.phases.json")))["phases"]
ph = [("idle", "Leerlauf"), ("v80", "80 km/h, Gas 0,3"), ("v130", "130 km/h, Gas 0,3"), ("v130_full", "130 km/h Vollgas"),
      ("v200_full", "200 km/h Vollgas"), ("v250_full", "250 km/h Vollgas")]
print("| Zustand | Auto GT | Motor | Reifen | Wind | Auto Sportwagen | Musik (Linke Spur) | Auto + Musik | Musik − Auto | Ducking | Plan-Schlüssel |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for p, lab in ph:
    g = caps["gt_car"][p]
    w = caps["gt_wind"][p]["lufs"]
    t = caps["gt_tyres"][p]["lufs"]
    print(f"| {lab} | {de(g['lufs'])} | {de(caps['gt_engine'][p]['lufs'])} | {de(t) if t > -100 else '–'} | {de(w) if w > -100 else '–'} | "
          f"{de(caps['sw_car'][p]['lufs'])} | {de(caps['gt_music'][p]['lufs'])} | {de(caps['gt_all'][p]['lufs'])} | "
          f"{de(caps['gt_music'][p]['lufs'] - g['lufs'],1,True)} | {de(g['duck_med'],1)} dB | {de(g['car_plan_med'])} |")

print("\n### T6 Hörbarkeit der Melodie (510 Hz – 3,2 kHz), Modell, Gran Turismo\n")
S = M["sections"]
print("| Zustand | Linke Spur Hook B1 | Linke Spur Groove A1 | Nachtfahrt B1 / A1 | Rückenwind B1 / A1 | alle Abschnitte (Mittel) | Median Abstand zur Schwelle | Motor unter der Musik hörbar |")
print("|---|---|---|---|---|---|---|---|")
for p, lab in ph[1:]:
    allv, sm, car = [], [], []
    for piece in S:
        for sname, v in S[piece].items():
            if sname == "Einzähler":
                continue
            r = v["phases"][p]["gt_car"]["0.0"]
            allv.append(r["mel_hp"])
            sm.append(r["mel_hp_smr"])
            car.append(r["car_aud_hp"])

    def q(pc, sn):
        return int(round(100 * S[pc][sn]["phases"][p]["gt_car"]["0.0"]["mel_hp"]))
    print(f"| {lab} | {q('linke_spur','B1')} % | {q('linke_spur','A1')} % | {q('nachtfahrt','B1')} / {q('nachtfahrt','A1')} % | "
          f"{q('rueckenwind','B1')} / {q('rueckenwind','A1')} % | {int(round(100*np.mean(allv)))} % | {de(float(np.median(sm)),1,True)} dB | "
          f"{int(round(100*np.mean(car)))} % |")

print("\n### T7 Wer verdeckt die Melodie? (alle Abschnitte, Mittel; heute)\n")
print("| Zustand | ganzes Auto GT | nur Motor | nur Reifen | nur Wind | Sportwagen |")
print("|---|---|---|---|---|---|")
for p, lab in ph[1:]:
    row = []
    for c in ("gt_car", "gt_engine", "gt_tyres", "gt_wind", "sw_car"):
        vals = [v["phases"][p][c]["0.0"]["mel_hp"] for piece in S for sn, v in S[piece].items() if sn != "Einzähler"]
        sms = [v["phases"][p][c]["0.0"]["mel_hp_smr"] for piece in S for sn, v in S[piece].items() if sn != "Einzähler"]
        row.append(f"{int(round(100*np.mean(vals)))} % ({de(float(np.median(sms)),1,True)} dB)")
    print(f"| {lab} | " + " | ".join(row) + " |")

print("\n### T8 Pegel-Sweep (alle Abschnitte, Gran Turismo): Melodie hörbar / Motor hörbar\n")
offs = ["-6.0", "-4.0", "-2.0", "0.0", "2.0", "4.0", "6.0"]
print("| Zustand | " + " | ".join(o.replace('.0', '').replace('-', '−') + " dB" for o in offs) + " |")
print("|---|" + "---|" * len(offs))
for p, lab in ph[1:]:
    cells = []
    for o in offs:
        mv = [v["phases"][p]["gt_car"][o]["mel_hp"] for piece in S for sn, v in S[piece].items() if sn != "Einzähler"]
        cv = [v["phases"][p]["gt_car"][o]["car_aud_hp"] for piece in S for sn, v in S[piece].items() if sn != "Einzähler"]
        cells.append(f"{int(round(100*np.mean(mv)))} / {int(round(100*np.mean(cv)))}")
    print(f"| {lab} | " + " | ".join(cells) + " |")

print("\n### T9 Laufzeit-Alternativen (Modell; Abschnitte A1, B1, B2, D, S aller drei Stücke; gleiche Lautheit)\n")
print("| Variante | context_db.race für gleiche Lautheit | duck.depth_db | 130 Teillast Melodie | 130 Vollgas Melodie | 250 Vollgas Melodie (Abstand) | Bass hörbar 250 | Motor hörbar (min) |")
print("|---|---|---|---|---|---|---|---|")
for cname, c in E["configs"].items():
    rows = c["rows"]
    print(f"| {cname} | {de(c['context_race_db_for_equal_loudness'],2,True)} | {de(c['depth'],1)} | {int(round(100*rows['v130']['mel']))} % | "
          f"{int(round(100*rows['v130_full']['mel']))} % | {int(round(100*rows['v250_full']['mel']))} % ({de(rows['v250_full']['smr'],1,True)} dB) | "
          f"{int(round(100*rows['v250_full']['bass']))} % | {int(round(100*min(r['car'] for r in rows.values())))} % |")

print("\n### T10 Knöpfe in mischung.json, gemessen (Skizze Linke Spur, bei gleicher Lautheit, dB)\n")
kb = [("sub_lt40", "< 40"), ("sub_40_60", "40–60"), ("bass_60_120", "60–120"), ("bass_120_250", "120–250"),
      ("lowmid_250_800", "250–800"), ("mid_800_2k", "0,8–2 k"), ("presence_2k_5k", "2–5 k"), ("brill_5k_8k", "5–8 k"),
      ("air_8k_12k", "8–12 k"), ("air_gt12k", "> 12 k")]
print("| Variante | " + " | ".join(b[1] for b in kb) + " | True Peak |")
print("|---|" + "---|" * len(kb) + "---|")
lab = {"sub_m3": "sub_db −3", "sub_m6": "sub_db −6", "sub_p3": "sub_db +3", "bass_m3": "bass_db −3",
       "hs_m2_6k": "high_shelf_db −2 (6 kHz)", "hs_m3_4k": "high_shelf_db −3, high_shelf_hz 4000",
       "ls62_m3": "Experiment: Master-Kuhschwanz 62 Hz um 3 dB tiefer", "ls120_m3": "Experiment: Master-Kuhschwanz 120 Hz −3 dB"}
for v in ("sub_m3", "sub_m6", "sub_p3", "bass_m3", "hs_m2_6k", "hs_m3_4k", "ls62_m3", "ls120_m3"):
    if v in KN:
        d = KN[v]["delta_bands_db"]
        print(f"| {lab[v]} | " + " | ".join(de(d[b[0]], 1, True) for b in kb) + f" | {de(KN[v]['tp'],2)} (Basis {de(KN['base']['tp'],2)}) |")

print("\n### T11 Übergänge (Datei-Ebene, Simulation wie Godot)\n")
print("| Stück | Naht: Sprung / größter Schritt ±50 ms | Schluss: leisestes 5-ms-Fenster | Schluss: Sprung momentan (LU) | Polizei über abgesenkter Musik | Tank | Ziel |")
print("|---|---|---|---|---|---|---|")
for n in ("linke_spur", "nachtfahrt", "rueckenwind"):
    t = T[n]
    ends = t["endings"]
    mn = min(e["min_5ms_rms_rel_db"] for e in ends.values())
    lo = min(e["step_lu_range"][0] for e in ends.values())
    hi = max(e["step_lu_range"][1] for e in ends.values())
    st = t["stingers"]
    print(f"| {NAMES[n]} | {de(t['seam']['jump_at_seam'],3)} / {de(t['seam']['largest_step_within_50ms'],3)} | {de(mn,1)} dB | "
          f"{de(lo,1,True)} … {de(hi,1,True)} | {de(st['busted@B1']['sting_over_ducked_lu'],1,True)} LU (Spitze {de(st['busted@B1']['mix_peak_vs_loop_lu'],1,True)} über der Musik davor) | "
          f"{de(st['out_of_fuel@B1']['sting_over_ducked_lu'],1,True)} LU ({de(st['out_of_fuel@B1']['mix_peak_vs_loop_lu'],1,True)}) | "
          f"{de(st['ziel@B1']['sting_over_ducked_lu'],1,True)} LU ({de(st['ziel@B1']['mix_peak_vs_loop_lu'],1,True)}) |")
