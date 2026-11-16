#!/usr/bin/env python3
"""KRITIK-FAHRBAHN: the collision layers as the runtime stacks them (impact_audio.gd: peak_db at the master per layer,
files at -3 dBFS sample peak, lead_ms inside the files), centred (no pan), master volume 0.8 included via ref_path."""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dsp  # noqa: E402

TREE = os.path.join(HERE, "tree")
SFX = os.path.join(TREE, "assets/audio/modern/sfx")
SR = 44100
cfg = json.load(open(os.path.join(TREE, "config/game_config.json")))["audio"]["modern"]["impact"]
man = json.load(open(os.path.join(SFX, "manifest.json")))["sounds"]
file_peak = cfg["file_peak_db"]
ref_path = cfg["ref_path_db"]


def load_variant(sid, v=0):
    e = man[sid]
    files = e["files"] if "files" in e else [e["file"]]
    x, _ = dsp.load(os.path.join(SFX, files[v % len(files)]))
    return dsp.mono(x)


def layers(closing, heavy):
    t = cfg["collision"]["tiers_kmh"]
    tier = "light" if closing < t[0] else ("medium" if closing < t[1] else "heavy")
    c = cfg["collision"][tier]
    adj = max(-cfg["collision"]["max_db"], min(cfg["collision"]["max_db"], cfg["collision"]["slope_db"] * np.log10(max(closing, 1) / c["ref_kmh"])))
    out = []
    truck = heavy and tier in cfg["collision"]["truck"]
    for sid in sorted(c["layers"]):
        if truck and sid == "hit_heavy":
            continue
        out.append((sid, c["layers"][sid] + adj))
    if truck:
        out.append(("truck_boom", cfg["collision"]["truck"][tier] + adj))
    return tier, out


def stack(rows):
    n = max(len(load_variant(s)) for s, _ in rows) + SR // 2
    y = np.zeros(n)
    parts = {}
    for sid, peak_db in rows:
        # runtime: player volume = peak_db - file_peak - ref_path; the master volume (ref_path) follows: net peak_db - file_peak
        g = 10 ** ((peak_db - file_peak) / 20.0)
        s = load_variant(sid) * g
        parts[sid] = s
        y[:len(s)] += s
    return y, parts


res = {}
print(f"{'Fall':34s} {'Stufe':7s} {'Spitze':>7s} {'TP':>6s} {'LUFSm':>6s} {'HP180':>6s} {'Klein':>6s} {'<100Hz':>7s}  Schichten (Spitze dB am Master, mittig)")
cases = [("Rempler 6 km/h", 6, False), ("Auffahren 30 km/h", 30, False), ("schwer 70 km/h", 70, False),
         ("schwer 130 km/h", 130, False), ("Lkw 40 km/h", 40, True), ("Lkw 110 km/h", 110, True)]
for name, closing, heavy in cases:
    tier, rows = layers(closing, heavy)
    y, parts = stack(rows)
    pad = np.concatenate([y, np.zeros(SR // 2)])
    mm = float(dsp.qc_lib.momentary_max(pad, SR))
    r = {"tier": tier, "layers": rows, "peak": dsp.sp(y), "tp": dsp.tp(y), "lufs_m": mm,
         "hp180": float(dsp.qc_lib.momentary_max(dsp.hp180(pad), SR)) - mm,
         "small": float(dsp.qc_lib.momentary_max(dsp.small_speaker(pad), SR)) - mm,
         "below100": dsp.share_below(pad, 100.0),
         "peak_hp180": dsp.sp(dsp.hp180(y)), "peak_small": dsp.sp(dsp.small_speaker(y))}
    # contribution of the glass layer to the momentary loudness
    if "glass" in parts:
        no_glass = y - np.pad(parts["glass"], (0, len(y) - len(parts["glass"])))
        r["without_glass_lufs_m"] = float(dsp.qc_lib.momentary_max(np.concatenate([no_glass, np.zeros(SR // 2)]), SR))
        c, Lg = dsp.third_octaves(np.concatenate([parts["glass"], np.zeros(SR)]))
        c, Ly = dsp.third_octaves(pad)
        r["glass_share_4k_8k_db"] = [float(Lg[i] - Ly[i]) for i in range(len(c)) if 3000 <= c[i] <= 10000]
    res[name] = r
    print(f"{name:34s} {tier:7s} {r['peak']:7.1f} {r['tp']:6.1f} {r['lufs_m']:6.1f} {r['hp180']:6.1f} {r['small']:6.1f} {100*r['below100']:6.0f}%  "
          + ", ".join(f"{s} {v:.1f}" for s, v in rows))
    if "without_glass_lufs_m" in r:
        print(f"{'':34s} ohne Glas {r['without_glass_lufs_m']:.1f} LUFS momentan; Spitze nach 180-Hz-Hochpass {r['peak_hp180']:.1f}, Kleinlautsprecher {r['peak_small']:.1f} dBFS")
    else:
        print(f"{'':34s} Spitze nach 180-Hz-Hochpass {r['peak_hp180']:.1f}, Kleinlautsprecher {r['peak_small']:.1f} dBFS")
    np.save(os.path.join(HERE, "results", f"impact_{closing}_{int(heavy)}.npy"), y.astype(np.float32))
json.dump(res, open(os.path.join(HERE, "results", "impacts.json"), "w"), indent=1, default=float)
print("Schwenk 0.7: lauterer Kanal +%.1f dB, leiserer %.1f dB (Gesetz gleicher Leistung)" % tuple(20 * np.log10(np.array(dsp.pan_gains(0.7))[::-1])))
