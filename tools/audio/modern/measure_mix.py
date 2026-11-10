#!/usr/bin/env python3
"""Loudness of a recording made by tools/audio/modern/capture_mix.gd, per phase of its scenario – against the
loudness plan of the profile "Modern" (config audio.modern.loudness, contract D29).

    python3 tools/audio/modern/measure_mix.py <capture.wav> [<other.wav> …] [--json out.json]

Reads <capture>.json next to the WAV (phases {name, t0, t1}). Per phase: loudness of the whole phase (BS.1770
K-weighted, ungated), the loudest and the median short-term value (3-s window), true peak. Whole file: integrated
loudness, loudness range, true peak. Plan targets are printed next to the phases they belong to:
full_throttle / flat_out -> full_throttle_lufs (short-term), cruise_130 -> cruise_lufs, idle -> idle_lufs,
menu -> menu_music_lufs.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import modern_lib as ml  # noqa: E402
import qc_lib  # noqa: E402

TARGET_OF = {"full_throttle": "full_throttle_lufs", "flat_out": "full_throttle_lufs", "cruise_130": "cruise_lufs",
             "idle": "idle_lufs", "menu": "menu_music_lufs"}


def plan() -> dict:
    with open(os.path.join(ml.ROOT, "config", "game_config.json"), encoding="utf-8") as fh:
        return json.load(fh)["audio"]["modern"]["loudness"]


def phase_loudness(x: np.ndarray, sr: int) -> float:
    xk = qc_lib.k_weight(qc_lib.as_played(x), sr)
    return float(-0.691 + 10.0 * np.log10(max(float(np.mean(np.sum(xk * xk, axis=1))), 1e-14)))


def measure(path: str) -> dict:
    x, sr = qc_lib.read_audio(path)
    meta_path = os.path.splitext(path)[0] + ".json"
    meta = json.load(open(meta_path, encoding="utf-8")) if os.path.exists(meta_path) else {"phases": []}
    targets = plan()
    out = {"file": path, "profile": meta.get("profile", "?"), "scenario": meta.get("scenario", "?"),
           "vehicle": meta.get("vehicle", ""), "seconds": round(len(x) / sr, 2),
           "integrated_lufs": round(qc_lib.integrated_lufs(x, sr), 2), "lra": round(qc_lib.loudness_range(x, sr), 2),
           "true_peak_db": round(qc_lib.true_peak_db(x), 2), "phases": []}
    for ph in meta.get("phases", []):
        a = int(float(ph["t0"]) * sr)
        b = min(int(float(ph["t1"]) * sr), len(x))
        if b - a < sr // 2:
            continue
        seg = x[a:b]
        st = qc_lib.short_term(seg, sr, min(3.0, (b - a) / sr), 0.1)
        key = TARGET_OF.get(ph["name"])
        out["phases"].append({"name": ph["name"], "t0": ph["t0"], "t1": ph["t1"], "lufs": round(phase_loudness(seg, sr), 2),
                              "short_term_max": round(float(np.max(st)), 2), "short_term_median": round(float(np.median(st)), 2),
                              "true_peak_db": round(qc_lib.true_peak_db(seg), 2),
                              "target": targets.get(key) if key else None})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Lautheit einer Aufnahme von capture_mix.gd je Phase")
    ap.add_argument("files", nargs="+")
    ap.add_argument("--json", default="")
    args = ap.parse_args()
    results = [measure(f) for f in args.files]
    for r in results:
        print(f"{os.path.basename(r['file'])}: Profil {r['profile']}, {r['scenario']} {r['vehicle']}, {r['seconds']} s – "
              f"integriert {r['integrated_lufs']} LUFS, Lautheitsbereich {r['lra']} LU, True Peak {r['true_peak_db']} dBTP")
        for p in r["phases"]:
            target = "" if p["target"] is None else f"   Plan {p['target']:.0f}"
            print(f"  {p['name']:14s} {p['t0']:6.1f}–{p['t1']:6.1f} s  {p['lufs']:7.2f} LUFS  Kurzzeit max {p['short_term_max']:7.2f}"
                  f" / Median {p['short_term_median']:7.2f}  True Peak {p['true_peak_db']:6.2f}{target}")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(results, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
