#!/usr/bin/env python3
"""Spike 1: old (game recording) vs new (prototype) - tables and pictures."""
import json, math, os, sys
import numpy as np
import alib
from alib import *
from engine3 import Trace

W = alib.WORK
SR = 48000
OUT = W + "/out"
tr = Trace(OUT + "/drive_old.csv")
old = read_audio(OUT + "/drive_old.wav", SR)
new = read_audio(OUT + "/drive_new_full.wav", SR)
eng = read_audio(OUT + "/drive_new_engine_only.wav", SR)
n = min(len(old), len(new))
old, new, eng = old[:n], new[:n], eng[:n]
sig = {"alt (Spiel v0.7.0)": old, "neu nur Antrieb": eng, "neu komplett": new}

phases = [("Leerlauf", tr.phase_time("start_idle")[0] + 1.9, tr.phase_time("start_idle")[1]),
          ("Vollgas durch die Gänge", tr.phase_time("launch")[0] + 1.0, tr.phase_time("launch")[1]),
          ("Vollgas bei 266 km/h", *tr.phase_time("flat_out")),
          ("Gas weg (Schub)", *tr.phase_time("lift")),
          ("130 km/h Teillast", tr.phase_time("cruise130")[0] + 1.0, tr.phase_time("cruise130")[1]),
          ("Kick-down", *tr.phase_time("kickdown"))]


def mean_lufs(x):
    xk = k_weight(x, SR)
    return -0.691 + 10 * np.log10(max(np.mean(np.sum(xk * xk, axis=1)), 1e-12))


def env_mod_db(x, lo=150.0, hi=3000.0):
    """Std of the 50-ms band level (dB) after removing the slow trend (1 s median) - 'liveliness' of a steady sound."""
    e = band_env(x, SR, lo, hi, 0.05)
    k = 21
    pad = np.pad(e, (k // 2, k // 2), mode="edge")
    trend = np.array([np.median(pad[i:i + k]) for i in range(len(e))])
    return float(np.std(e - trend))


def band_share(x, lo, hi):
    fc, v = third_octave(x, SR, 25, 20000)
    p = 10 ** (v / 10)
    return 10 * np.log10(np.sum(p[(fc >= lo) & (fc < hi)]) / np.sum(p))


def occupied_bands(x, floor_db=-30.0):
    """Number of 1/3-octave bands (25 Hz..16 kHz) within floor_db of the loudest band: 'fullness' of the spectrum."""
    fc, v = third_octave(x, SR, 25, 16000)
    return int(np.sum(v > v.max() + floor_db))


rows = []
print("%-26s %-20s %7s %6s %6s %6s %7s %7s %7s %6s %5s" % ("Phase", "Signal", "LUFS", "Crest", "Korr", "S/M", "<60Hz", ">5kHz", "Flux", "Mod", "Bänder"))
table = {}
for name, a, b in phases:
    for sn, x in sig.items():
        s = x[int(a * SR):int(b * SR)]
        r = {"lufs": mean_lufs(s), "crest": crest_db(s), "corr": stereo_corr(s), "sm": side_mid_db(s),
             "lf": band_share(s, 20, 60), "hf": band_share(s, 5000, 21000), "flux": float(np.median(spectral_flux(s, SR))),
             "mod": env_mod_db(s), "bands": occupied_bands(s)}
        table.setdefault(name, {})[sn] = {k: round(float(v), 2) for k, v in r.items()}
        print("%-26s %-20s %7.1f %6.1f %6.2f %6.1f %7.1f %7.1f %7.2f %6.2f %5d" % (name, sn, r["lufs"], r["crest"], r["corr"], r["sm"], r["lf"], r["hf"], r["flux"], r["mod"], r["bands"]))
overall = {}
for sn, x in sig.items():
    xk = k_weight(x, SR)
    overall[sn] = {"lufs_i": round(integrated_lufs(x, SR, xk), 2), "lra": round(loudness_range(x, SR, xk), 1),
                   "true_peak": round(true_peak_db(x), 2), "corr": round(stereo_corr(x), 3)}
    print(sn, overall[sn])
json.dump({"phases": table, "overall": overall}, open(OUT + "/drive_compare.json", "w"), indent=1, ensure_ascii=False)

# --- pictures -------------------------------------------------------------------------------------------
im_o, ref = spectrogram_img(old, SR, w=1700, h=380)
im_e, _ = spectrogram_img(eng, SR, w=1700, h=380, ref_db=ref)
im_n, _ = spectrogram_img(new, SR, w=1700, h=380, ref_db=ref)
stack_images([("ALT – Spiel v0.7.0 (Movie-Maker-Aufnahme: Motorbank 32 kHz mono + Stereohall, Wind)", im_o),
              ("NEU – nur Antrieb (Stereo-Bank 48 kHz, Sättigung, Turbo, Clips, Getriebe, frühe Reflexionen)", im_e),
              ("NEU – komplett (+ Reifen links/rechts, Wind in drei Bändern, Fugen, Vorbeifahr-Wuschen)", im_n)],
             OUT + "/drive_spectrogram_old_vs_new.png",
             "Gran Turismo, gleiche Fahrt: Start, Gasstöße, Vollgas durch die Gänge, 266 km/h, Gas weg, Bremsen, 130 km/h, Kick-down, Stopp")

t_m = np.arange(len(short_term(old, SR, 0.4, 0.1))) * 0.1 + 0.2
ser = [("alt", t_m, short_term(old, SR, 0.4, 0.1), (140, 170, 255)), ("neu nur Antrieb", t_m, short_term(eng, SR, 0.4, 0.1), (255, 190, 90)),
       ("neu komplett", t_m, short_term(new, SR, 0.4, 0.1), (255, 90, 90))]
line_plot(ser, OUT + "/drive_loudness_old_vs_new.png", "Momentane Lautheit (400 ms, K-bewertet) über die Fahrt", "Zeit (s)", "LUFS", ylim=(-45, -5), w=1700)

for pname, key in (("Vollgas bei 266 km/h", "flat"), ("130 km/h Teillast", "cruise")):
    a, b = [(x[1], x[2]) for x in phases if x[0] == pname][0]
    ser = []
    for (sn, x), col in zip(sig.items(), [(140, 170, 255), (255, 190, 90), (255, 90, 90)]):
        fc, v = third_octave(x[int(a * SR):int(b * SR)], SR, 25, 20000)
        ser.append((sn, fc, v, col))
    line_plot(ser, OUT + "/drive_spectrum_%s.png" % key, "Terzspektrum – %s" % pname, "Hz", "dB", logx=True, xlim=(25, 20000), w=1100)


def corr_curve(x, win=0.5):
    w = int(win * SR)
    m = len(x) // w
    return np.array([stereo_corr(x[i * w:(i + 1) * w]) if np.max(np.abs(x[i * w:(i + 1) * w])) > 1e-4 else 1.0 for i in range(m)])


tcx = (np.arange(len(corr_curve(old))) + 0.5) * 0.5
line_plot([("alt", tcx, corr_curve(old), (140, 170, 255)), ("neu komplett", tcx, corr_curve(new), (255, 90, 90))],
          OUT + "/drive_stereo_corr.png", "Stereo-Korrelation links/rechts (0,5-s-Fenster): 1 = mono", "Zeit (s)", "", ylim=(0, 1), w=1700, h=300)
