#!/usr/bin/env python3
"""Placeholder sounds of the profile "Modern" (wave 0, package AU-A): one small generated file per asset folder with
its manifest entry, so that the whole path – generator, manifest, Godot import, loader, export filter, QC – can be
checked before the real sounds exist.

    python3 tools/audio/modern/make_placeholders.py            writes assets/audio/modern/*/platzhalter_* and
                                                                the manifests (other entries stay), then run
                                                                "godot --headless --path . --import" once
    python3 tools/audio/modern/make_placeholders.py --out DIR   the same files below DIR (for the determinism check)

Every entry carries "placeholder": true: the game never plays one (ModernAudioAssets hides them unless
audio.modern.placeholders is set, which only tests do). They are deliberately plain: periodic noise and tones.

  engines/platzhalter.i16 (+ .json)   raw int16, 32 kHz stereo, 0.5 s – the raw format of the engine banks
  vehicle/platzhalter_loop.wav        stereo loop, 1 s
  traffic/platzhalter_loop.wav        mono loop, 1 s
  sfx/platzhalter_hit.wav             stereo one-shot, 0.4 s
  ui/platzhalter_blip.wav             mono one-shot, 0.12 s
  ambience/platzhalter_bed.ogg        stereo loop, 4 s, Vorbis q4
  music/platzhalter_takt.ogg          two bars at 120 bpm, 4 s, Vorbis q5, -14 LUFS, role "race"
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

GENERATOR = "tools/audio/modern/make_placeholders.py"
SR = ml.SR
NOTE = "Platzhalter (Welle 0): wird im Spiel nie abgespielt"


def _t(n: int, sr: int = SR) -> np.ndarray:
    return np.arange(n) / float(sr)


def engine_raw() -> np.ndarray:
    """0.5 s at 32 kHz stereo: 40 periods of an 80-Hz harmonic tone, the partials spread between the channels."""
    n = ml.BANK_SR // 2
    t = _t(n, ml.BANK_SR)
    left = np.zeros(n)
    right = np.zeros(n)
    for k in range(1, 13):
        part = np.sin(2 * np.pi * 80.0 * k * t + 0.7 * k) / k
        pan = 0.5 + 0.35 * np.sin(1.3 * k)
        left += part * np.cos(pan * np.pi / 2)
        right += part * np.sin(pan * np.pi / 2)
    x = np.stack([left, right], axis=1)
    return 0.35 * x / np.max(np.abs(x))


def vehicle_loop() -> np.ndarray:
    def shape(f):
        return np.where((f > 200.0) & (f < 4000.0), 1.0 / np.sqrt(f), 0.0)
    return 0.25 * np.stack([ml.periodic_noise(SR, SR, 11, shape), ml.periodic_noise(SR, SR, 12, shape)], axis=1)


def traffic_loop() -> np.ndarray:
    t = _t(SR)
    tone = sum(np.sin(2 * np.pi * 110.0 * k * t + k) / k for k in range(1, 9))
    noise = ml.periodic_noise(SR, SR, 21, lambda f: np.where((f > 500.0) & (f < 3000.0), 1.0 / f, 0.0))
    x = tone / np.max(np.abs(tone)) + 0.5 * noise
    return 0.3 * x / np.max(np.abs(x))


def sfx_hit() -> np.ndarray:
    n = int(0.4 * SR)
    t = _t(n)
    rng = np.random.default_rng(31)
    env = np.exp(-t / 0.06) * np.minimum(1.0, (0.4 - t) / 0.05)
    thump = np.sin(2 * np.pi * 60.0 * t) * np.exp(-t / 0.12) * np.minimum(1.0, (0.4 - t) / 0.05)
    x = np.stack([rng.uniform(-1, 1, n) * env + thump, rng.uniform(-1, 1, n) * env + thump], axis=1)
    x[: int(0.002 * SR)] *= np.linspace(0.0, 1.0, int(0.002 * SR))[:, None]
    return 0.5 * x / np.max(np.abs(x))


def ui_blip() -> np.ndarray:
    n = int(0.12 * SR)
    t = _t(n)
    env = np.minimum(1.0, t / 0.004) * np.exp(-t / 0.035) * np.minimum(1.0, (0.12 - t) / 0.01)
    return 0.4 * np.sin(2 * np.pi * 880.0 * t) * env


def ambience_bed() -> np.ndarray:
    n = 4 * SR

    def shape(f):
        return np.where((f > 100.0) & (f < 6000.0), 1.0 / f, 0.0)
    return 0.12 * np.stack([ml.periodic_noise(n, SR, 41, shape), ml.periodic_noise(n, SR, 42, shape)], axis=1)


def music_bars() -> np.ndarray:
    """Two bars at 120 bpm (4 s, every part periodic over the file): kick on the beats, noise on the off-beats, a pad."""
    n = 4 * SR
    t = _t(n)
    beat = 0.5
    x = np.zeros(n)
    for b in range(-1, 8):                               # -1: the tail of the last beat of the bar before
        tb = t - b * beat
        on = tb >= 0.0
        ph = 2 * np.pi * (50.0 * tb + (70.0 * 0.05) * (1.0 - np.exp(-np.maximum(tb, 0.0) / 0.05)))
        x += np.where(on, np.sin(ph) * np.exp(-np.maximum(tb, 0.0) / 0.12), 0.0) * 0.9
    rng = np.random.default_rng(51)
    hat = rng.uniform(-1, 1, n)
    hat = hat - np.concatenate([[0.0], hat[:-1]])        # crude high-pass
    for b in range(8):
        tb = t - (b + 0.5) * beat
        x += np.where(tb >= 0.0, hat * np.exp(-np.maximum(tb, 0.0) / 0.02), 0.0) * 0.12
    pad_l = sum(np.sin(2 * np.pi * f * t) for f in (220.0, 261.75, 329.75)) / 3.0
    pad_r = sum(np.sin(2 * np.pi * f * t + 0.9) for f in (220.0, 261.75, 329.75)) / 3.0
    x = np.stack([x + 0.35 * pad_l, x + 0.35 * pad_r], axis=1)
    x = ml.normalize_lufs(x, SR, -14.0)
    return ml.limit_true_peak(x, -2.0)


def generate(out: str | None) -> list[str]:
    """Writes every placeholder and its manifest entry. Returns the written files (relative to the asset folder)."""
    written: list[str] = []
    repo = out is None

    def manifest(folder: str) -> ml.Manifest:
        m = ml.Manifest(folder, out)
        m.drop_generator(GENERATOR)
        return m

    # engines: raw int16 next to a description
    m = manifest("engines")
    ml.write_i16(m.file("platzhalter.i16"), engine_raw())
    with open(m.file("platzhalter.json"), "w", encoding="utf-8") as fh:
        json.dump({"format": "ce-engine-bank-2-platzhalter", "sample_rate": ml.BANK_SR, "channels": 2,
                   "frames": ml.BANK_SR // 2, "data": "platzhalter.i16", "note": NOTE}, fh, ensure_ascii=False, indent="\t")
        fh.write("\n")
    m.add("platzhalter", "platzhalter.i16", "bank", GENERATOR, loop=(0, ml.BANK_SR // 2), bus="MEngine",
          placeholder=True, note=NOTE)
    m.save()
    written += ["engines/platzhalter.i16", "engines/platzhalter.json", "engines/manifest.json"]

    wavs = [("vehicle", "platzhalter_loop", vehicle_loop(), "loop", "MRoad"),
            ("traffic", "platzhalter_loop", traffic_loop(), "loop", "MTrafficV0"),
            ("sfx", "platzhalter_hit", sfx_hit(), "oneshot", "MSfx"),
            ("ui", "platzhalter_blip", ui_blip(), "oneshot", "MUI")]
    for folder, sid, x, kind, bus in wavs:
        m = manifest(folder)
        name = sid + ".wav"
        ml.write_wav16(m.file(name), x)
        loop = (0, len(x)) if kind == "loop" else None
        if repo:
            ml.write_wav_import(m.file(name), loop)
        m.add(sid, name, kind, GENERATOR, loop=loop, bus=bus, gain_db=0.0, placeholder=True, note=NOTE)
        m.save()
        written += [f"{folder}/{name}", f"{folder}/manifest.json"]

    m = manifest("ambience")
    bed = ambience_bed()
    ml.write_ogg(m.file("platzhalter_bed.ogg"), bed, quality=4.0, title="Crossing Europe - Platzhalter")
    if repo:
        ml.write_ogg_import(m.file("platzhalter_bed.ogg"), 0.0)
    m.add("platzhalter_bed", "platzhalter_bed.ogg", "loop", GENERATOR, loop=(0, len(bed)), bus="MAmb", gain_db=0.0,
          placeholder=True, note=NOTE)
    m.save()
    written += ["ambience/platzhalter_bed.ogg", "ambience/manifest.json"]

    m = manifest("music")
    bars = music_bars()
    ml.write_ogg(m.file("platzhalter_takt.ogg"), bars, quality=5.0, title="Crossing Europe - Platzhalter")
    if repo:
        ml.write_ogg_import(m.file("platzhalter_takt.ogg"), 0.0, bpm=120.0, beats=8, bar_beats=4)
    m.add("platzhalter_takt", "platzhalter_takt.ogg", "music", GENERATOR, loop=(0, len(bars)), role="race",
          bus="MMusic", gain_db=0.0, bpm=120.0, beats=8, bar_beats=4, placeholder=True, note=NOTE)
    m.save()
    written += ["music/platzhalter_takt.ogg", "music/manifest.json"]
    return written


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=None, help="in diesen Ordner statt ins Repository schreiben (ohne .import-Dateien)")
    args = ap.parse_args()
    files = generate(args.out)
    base = ml.assets_dir(args.out)
    total = sum(os.path.getsize(os.path.join(base, f)) for f in files)
    print(f"{len(files)} Dateien unter {base} geschrieben ({total / 1024:.0f} kB)")
    if args.out is None:
        print("Danach einmal: godot --headless --path . --import (Godot ergänzt die .import-Dateien)")


if __name__ == "__main__":
    main()
