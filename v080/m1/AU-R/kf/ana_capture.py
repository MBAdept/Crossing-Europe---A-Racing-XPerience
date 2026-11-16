#!/usr/bin/env python3
"""KRITIK-FAHRBAHN: analysis of the constant-speed game-mix recordings (cap/*.wav from const_capture.gd)."""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dsp  # noqa: E402

CAP = os.path.join(HERE, "cap")
OUT = os.path.join(HERE, "results")
os.makedirs(OUT, exist_ok=True)
SR = 44100
meta = json.load(open(os.path.join(CAP, "segments.json")))
gain = 10 ** (float(meta["master_db"]) / 20.0)
segs = {s["name"]: s for s in meta["segments"]}


def get(name):
    x, sr = dsp.load(os.path.join(CAP, name + ".wav"))
    return x * gain


res = {"master_db": meta["master_db"], "segments": {}}
print(f"Gesamtlautstärke {meta['master_db']:.2f} dB (Aufnahme vor der Lautstärke, hier angewendet)")
print(f"{'Abschnitt':18s} {'s':>5s} {'LUFS':>6s} {'Kurz.max':>8s} {'TP':>6s} {'Korr':>5s} {'Mono-St':>7s} {'HP180':>6s} {'Klein':>6s}")
X = {}
for name in segs:
    x = get(name)
    X[name] = x
    r = {"seconds": len(x) / SR, "lufs": dsp.lufs(x), "st_max": float(dsp.qc_lib.short_term_max(x, SR)), "tp": dsp.tp(x),
         "corr": float(np.corrcoef(x[:, 0], x[:, 1])[0, 1])}
    m = x.mean(axis=1)
    r["mono_minus_stereo_db"] = dsp.lufs_plain(np.stack([m, m], 1)) - dsp.lufs_plain(x)
    r["hp180_db"] = dsp.lufs_plain(dsp.hp180(x)) - dsp.lufs_plain(x)
    r["small_db"] = dsp.lufs_plain(dsp.small_speaker(x)) - dsp.lufs_plain(x)
    res["segments"][name] = r
    print(f"{name:18s} {r['seconds']:5.1f} {r['lufs']:6.1f} {r['st_max']:8.1f} {r['tp']:6.1f} {r['corr']:5.2f} "
          f"{r['mono_minus_stereo_db']:+7.1f} {r['hp180_db']:6.1f} {r['small_db']:6.1f}")

# ------------------------------------------------------------------ repetition at constant speed
print("\nWiederholung bei konstantem Tempo (Hüllkurve 10 ms, log; Spektralrahmen 20 ms, Bark):")
p_asph = (130 / 120) ** 0.35
p_wl = (130 / 160) ** 0.3
p_wm = (130 / 160) ** 0.5
pred = {"Asphalt L/2": 1.0 / p_asph, "Asphalt L": 2.0 / p_asph, "Wind tief L/2": 1.0 / p_wl, "Wind tief L": 2.0 / p_wl,
        "Wind mittel/hoch L/2": 1.0 / p_wm, "Wind mittel/hoch L": 2.0 / p_wm}
print("  vorhergesagte Perioden:", {k: round(v, 3) for k, v in pred.items()})
rep = {}
for name in ("asph130_road", "asph130_wind", "asph130_full", "asph130_engine", "conc130_road", "conc130_full",
             "asph200_full", "asph200_roadwind", "cobbles50_road", "cobbles50_full"):
    if name not in X:
        continue
    x = X[name]
    lags, ac = dsp.env_autocorr(x, SR, 0.01, 4.0)
    lags2, ss = dsp.spec_selfsim(x, SR, 0.02, 4.0)
    row = {"env_peak_short": dsp.best_peak(lags, ac, 0.3, 1.6), "env_peak_long": dsp.best_peak(lags, ac, 1.6, 3.9),
           "spec_peak_short": dsp.best_peak(lags2, ss, 0.3, 1.6), "spec_peak_long": dsp.best_peak(lags2, ss, 1.6, 3.9),
           "env_median_0.3_3.9": float(np.median(ac[(lags >= 0.3) & (lags <= 3.9)])),
           "spec_median_0.3_3.9": float(np.median(ss[(lags2 >= 0.3) & (lags2 <= 3.9)]))}
    # per band: road band 600-1600 Hz envelope (where the tyre hump sits)
    lb, acb = dsp.env_autocorr(x, SR, 0.01, 4.0, band=(600.0, 1600.0))
    row["band600_1600_peak_short"] = dsp.best_peak(lb, acb, 0.3, 1.6)
    row["band600_1600_peak_long"] = dsp.best_peak(lb, acb, 1.6, 3.9)
    lh, ach = dsp.env_autocorr(x, SR, 0.01, 4.0, band=(2500.0, 8000.0))
    row["band2500_8000_peak_short"] = dsp.best_peak(lh, ach, 0.3, 1.6)
    rep[name] = row
    res.setdefault("curves", {})[name] = {"lags": lags.tolist(), "env": ac.tolist(), "spec": ss.tolist(), "band": acb.tolist()}
    print(f"  {name:17s} Hüllkurve: Spitze {row['env_peak_short'][1]:4.2f} bei {row['env_peak_short'][0]:4.2f} s, "
          f"{row['env_peak_long'][1]:4.2f} bei {row['env_peak_long'][0]:4.2f} s (Median {row['env_median_0.3_3.9']:4.2f}) | "
          f"Spektrum: {row['spec_peak_short'][1]:4.2f} bei {row['spec_peak_short'][0]:4.2f} s, {row['spec_peak_long'][1]:4.2f} bei "
          f"{row['spec_peak_long'][0]:4.2f} s (Median {row['spec_median_0.3_3.9']:4.2f}) | 0,6–1,6 kHz: {row['band600_1600_peak_short'][1]:4.2f} "
          f"bei {row['band600_1600_peak_short'][0]:4.2f} s / {row['band600_1600_peak_long'][1]:4.2f} bei {row['band600_1600_peak_long'][0]:4.2f} s | "
          f"2,5–8 kHz: {row['band2500_8000_peak_short'][1]:4.2f} bei {row['band2500_8000_peak_short'][0]:4.2f} s")
res["repetition"] = rep

# ------------------------------------------------------------------ band SNR (critical bands)
print("\nKritische Bänder bei 130 km/h: Pegel der Schicht gegen den Rest (dB, + = Schicht lauter):")
B = {k: dsp.bark(X[k]) for k in ("asph130_engine", "asph130_road", "asph130_wind", "asph130_full") if k in X}
edges = dsp.BARK_EDGES
snr = {}
if len(B) == 4:
    pe, pr, pw = (10 ** (B[k] / 10) for k in ("asph130_engine", "asph130_road", "asph130_wind"))
    snr["road_vs_rest"] = (10 * np.log10(pr / (pe + pw))).tolist()
    snr["wind_vs_rest"] = (10 * np.log10(pw / (pe + pr))).tolist()
    for i in range(len(edges) - 1):
        print(f"  {edges[i]:5d}-{edges[i+1]:5d} Hz  Motor {B['asph130_engine'][i]:6.1f}  Reifen {B['asph130_road'][i]:6.1f}  Wind "
              f"{B['asph130_wind'][i]:6.1f} dB   Reifen/Rest {snr['road_vs_rest'][i]:+5.1f}  Wind/Rest {snr['wind_vs_rest'][i]:+5.1f}")
B2 = {k: dsp.bark(X[k]) for k in ("asph200_engine", "asph200_roadwind") if k in X}
if len(B2) == 2:
    pe, prw = (10 ** (B2[k] / 10) for k in ("asph200_engine", "asph200_roadwind"))
    snr["roadwind200_vs_engine"] = (10 * np.log10(prw / pe)).tolist()
    print("  200 km/h, Reifen+Wind gegen Motor je Band:", [round(v, 1) for v in snr["roadwind200_vs_engine"]])
res["band_snr"] = snr
res["bark"] = {k: v.tolist() for k, v in {**B, **B2}.items()}

# ------------------------------------------------------------------ third octaves for the figures
TO = {}
for k in X:
    c, L = dsp.third_octaves(X[k])
    TO[k] = L.tolist()
res["third_octaves"] = {"centres": [float(v) for v in dsp.TOB_CENTRES], "levels": TO}
for k in ("rumble130_road", "rumble130_full"):
    if k in X:
        c, L = dsp.third_octaves(dsp.small_speaker(X[k]))
        res["third_octaves"]["levels"][k + "_small"] = L.tolist()
        c, L = dsp.third_octaves(dsp.hp180(X[k]))
        res["third_octaves"]["levels"][k + "_hp180"] = L.tolist()
c, L = dsp.third_octaves(dsp.small_speaker(X["asph130_full"]))
res["third_octaves"]["levels"]["asph130_full_small"] = L.tolist()

# rumble: level of the fundamental region (100-140 Hz) and the 2nd/3rd harmonics, before / after
if "rumble130_road" in X:
    f, p = dsp.psd(X["rumble130_road"], SR, 32768)
    f2, p2 = dsp.psd(dsp.small_speaker(X["rumble130_road"]), SR, 32768)
    def lv(pp, lo, hi):
        return 10 * np.log10(float(pp[(f >= lo) & (f < hi)].sum()) + 1e-20)
    fund = 130 / 3.6 / 0.30
    rr = {"fund_hz": fund}
    for nm, (lo, hi) in {"h1": (fund * 0.9, fund * 1.1), "h2": (2 * fund * 0.93, 2 * fund * 1.07), "h3": (3 * fund * 0.95, 3 * fund * 1.05),
                         "h4": (4 * fund * 0.96, 4 * fund * 1.04)}.items():
        rr[nm] = [lv(p, lo, hi), lv(p2, lo, hi)]
    # peaks near harmonics (actual fundamental of the loop at this pitch)
    m = (f > 60) & (f < 600)
    idx = np.argsort(p[m])[-6:]
    rr["top_peaks_hz"] = sorted(float(v) for v in f[m][idx])
    res["rumble"] = rr
    print("\nRüttelstreifen 130 km/h (nur Fahrbahn): Grundton", round(fund, 1), "Hz;",
          {k: [round(a, 1) for a in v] if isinstance(v, list) else v for k, v in rr.items()})

json.dump(res, open(os.path.join(OUT, "capture.json"), "w"), indent=1)
print("-> results/capture.json")
