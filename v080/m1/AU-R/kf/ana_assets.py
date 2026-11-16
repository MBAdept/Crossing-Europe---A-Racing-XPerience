#!/usr/bin/env python3
"""KRITIK-FAHRBAHN: measurements of the AU-C1 sound files (loops and one-shots) as the runtime plays them.
Writes results/assets.json and prints tables."""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dsp  # noqa: E402

TREE = os.path.join(HERE, "tree")
VEH = os.path.join(TREE, "assets/audio/modern/vehicle")
SFX = os.path.join(TREE, "assets/audio/modern/sfx")
OUT = os.path.join(HERE, "results")
os.makedirs(OUT, exist_ok=True)
SR = 44100

man_v = json.load(open(os.path.join(VEH, "manifest.json")))["sounds"]
man_s = json.load(open(os.path.join(SFX, "manifest.json")))["sounds"]
cfg = json.load(open(os.path.join(TREE, "config/game_config.json")))["audio"]["modern"]
road = cfg["road"]
imp = cfg["impact"]


def loop_samples(sid):
    e = man_v[sid]
    x, sr = dsp.load(os.path.join(VEH, e["file"]))
    a, b = e["loop"]
    return dsp.mono(x)[a:b], e


def pitch_for(e, kmh):
    ref = float(e.get("ref_kmh", 0.0))
    if ref <= 0:
        return 1.0
    return min(max((max(kmh, 1.0) / ref) ** float(e.get("pitch_exp", 0.0)), 0.15), 3.5)


res = {"loops": {}, "oneshots": {}, "pairs": {}}

# ---------------------------------------------------------------------------------------------------- loops
loops = [k for k, v in man_v.items() if v.get("generator", "").endswith("vehicle_loops.py")]
print(f"{'Schleife':14s} {'s':>4s} {'LUFS':>6s} {'Crest':>6s} {'Schwerp.':>8s} {'Neig.':>6s} {'<180Hz':>7s} {'HP180':>6s} {'Klein':>6s} {'cv':>5s} {'innen':>12s}  Töne")
for sid in sorted(loops):
    y, e = loop_samples(sid)
    L = len(y) / SR
    rep = np.tile(y, 3)
    r = {"seconds": L, "lufs": dsp.lufs(y), "crest_db": dsp.crest_db(y), "centroid_hz": dsp.centroid(rep),
         "tilt_db_oct": dsp.spectral_tilt(rep), "share_below_180": dsp.share_below(rep, 180.0),
         "share_below_100": dsp.share_below(rep, 100.0)}
    r["hp180_db"] = dsp.lufs_plain(dsp.hp180(rep)) - dsp.lufs_plain(rep)
    r["small_db"] = dsp.lufs_plain(dsp.small_speaker(rep)) - dsp.lufs_plain(rep)
    r["mod"] = dsp.modulation_depth(rep)
    # repetition inside one loop period: envelope autocorrelation, lags 0.08 s .. 0.9 L
    lags, ac = dsp.env_autocorr(rep, SR, 0.01, min(L * 0.92, 3.0))
    r["inner_rep"] = dsp.best_peak(lags, ac, 0.08, L * 0.9)
    r["tonal"] = dsp.tonal_peaks(rep, SR, 32768, 12.0)
    res["loops"][sid] = r
    tones = ", ".join(f"{f:.0f} Hz +{p:.0f}" for f, p in r["tonal"][:4])
    print(f"{sid:14s} {L:4.2f} {r['lufs']:6.1f} {r['crest_db']:6.1f} {r['centroid_hz']:8.0f} {r['tilt_db_oct']:6.1f} "
          f"{100*r['share_below_180']:6.0f}% {r['hp180_db']:6.1f} {r['small_db']:6.1f} {r['mod']['cv']:5.2f} "
          f"{r['inner_rep'][0]:5.2f}s/{r['inner_rep'][1]:4.2f}  {tones}")

# ---------------------------------------------------------------------------------------------------- pairs
# the runtime: two panned players read the same loop at offsets 0 and L/2 with the same pitch (road_audio.gd Layer)
print("\nPaare (zwei Spieler je Ebene, Versatz L/2, gleiche Tonhöhe):")
for sid, pan in (("tyre_asphalt", road["tyres"]["pan"]), ("tyre_concrete", road["tyres"]["pan"]), ("tyre_wet", road["tyres"]["pan"]),
                 ("wind_low", road["wind"]["pan"]), ("wind_mid", road["wind"]["pan"]), ("wind_high", road["wind"]["pan"]),
                 ("wind_buffet", road["wind"]["pan"])):
    y, e = loop_samples(sid)
    n = len(y)
    a = np.tile(y, 4)
    b = np.roll(a, -n // 2)
    gl0, gr0 = dsp.pan_gains(-pan)
    gl1, gr1 = dsp.pan_gains(pan)
    left = gl0 * a + gl1 * b
    right = gr0 * a + gr1 * b
    st = np.stack([left, right], axis=1)
    corr = float(np.corrcoef(left, right)[0, 1])
    m = left + right
    half = n // 2
    mono_period = float(np.corrcoef(m[:2 * n], m[half:half + 2 * n])[0, 1])
    ch_half = float(np.corrcoef(left[:2 * n], left[half:half + 2 * n])[0, 1])
    # envelope autocorrelation of one channel and of the mono sum at lag L/2 (10-ms log envelope)
    lags, acl = dsp.env_autocorr(left, SR, 0.01, n / SR * 1.1)
    _, acm = dsp.env_autocorr(m, SR, 0.01, n / SR * 1.1)
    k = int(round(n / 2 / SR / 0.01))
    res["pairs"][sid] = {"pan": pan, "stereo_corr": corr, "mono_corr_at_half": mono_period, "left_corr_at_half": ch_half,
                         "env_ac_left_half": float(acl[k]), "env_ac_mono_half": float(acm[k]),
                         "mono_minus_stereo_db": dsp.lufs_plain(np.stack([m / 2, m / 2], 1)) - dsp.lufs_plain(st)}
    p = res["pairs"][sid]
    print(f"  {sid:13s} pan ±{pan:.2f}: Kanalkorrelation {corr:5.2f}; Monosumme gegen sich selbst nach L/2 = {n/2/SR:.2f} s: "
          f"{mono_period:5.2f}; ein Kanal nach L/2: {ch_half:5.2f}; Hüllkurve L/2: Kanal {p['env_ac_left_half']:4.2f}, Mono {p['env_ac_mono_half']:4.2f}; "
          f"Mono − Stereo {p['mono_minus_stereo_db']:+.1f} dB")

# ---------------------------------------------------------------------------------------------------- one-shots
shots = [k for k, v in man_s.items() if v.get("generator", "").endswith("sfx_modern.py")]
print(f"\n{'Einmalklang':16s} {'Var':>3s} {'s':>5s} {'LUFSm':>6s} {'Crest':>6s} {'Schwerp.':>8s} {'<100':>5s} {'<180':>5s} {'HP180':>6s} {'Klein':>6s}  Töne")
for sid in sorted(shots):
    e = man_s[sid]
    files = e["files"] if "files" in e else [e["file"]]
    rows = []
    for fn in files:
        x, sr = dsp.load(os.path.join(SFX, fn))
        y = dsp.mono(x)
        pad = np.concatenate([y, np.zeros(int(0.5 * SR))])
        mm = float(dsp.qc_lib.momentary_max(pad, SR))
        r = {"file": fn, "seconds": len(y) / SR, "lufs_m": mm, "crest_db": dsp.crest_db(y), "centroid_hz": dsp.centroid(pad),
             "share_below_100": dsp.share_below(pad, 100.0), "share_below_180": dsp.share_below(pad, 180.0),
             "hp180_db": float(dsp.qc_lib.momentary_max(dsp.hp180(pad), SR)) - mm,
             "small_db": float(dsp.qc_lib.momentary_max(dsp.small_speaker(pad), SR)) - mm,
             "tonal": dsp.tonal_peaks(pad, SR, 16384, 15.0, 80.0, 12000.0, 5)}
        rows.append(r)
    res["oneshots"][sid] = rows
    r = rows[0]
    tones = ", ".join(f"{f:.0f}+{p:.0f}" for f, p in r["tonal"][:5])
    print(f"{sid:16s} {len(rows):3d} {r['seconds']:5.2f} {r['lufs_m']:6.1f} {r['crest_db']:6.1f} {r['centroid_hz']:8.0f} "
          f"{100*r['share_below_100']:4.0f}% {100*r['share_below_180']:4.0f}% {r['hp180_db']:6.1f} {r['small_db']:6.1f}  {tones}")

json.dump(res, open(os.path.join(OUT, "assets.json"), "w"), indent=1)
print("-> results/assets.json")
