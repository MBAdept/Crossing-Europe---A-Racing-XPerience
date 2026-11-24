#!/usr/bin/env python3
"""UI-Klänge für das Klangprofil „Modern“ (contract D30, §4.7.3; docs/audio-modern.md, section "Musik", UI-Klänge).

Soft menu sounds in the brand sound of the music: the plucked synth and the FM bell of tools/audio/music_synth.py
(imported, never edited) in E minor pentatonic – the key of the title theme and the interlude that play under the
menus – with a touch of the plate reverb of the music chain. 16-bit WAV, 44.1 kHz stereo, each set to a momentary
loudness of its own (the menu music plays at -20 LUFS: a move is quieter than a confirm), true peak <= -1 dBTP.

  ui_move     focus moves (two variants, played in turn: a scroll does not sound like a machine)
  ui_ok       confirm: a rising fifth (E5 -> B5), pluck and bell
  ui_back     back: a falling fourth (A5 -> E5), darker
  ui_tab      tab switch (LB/RB): a short air sweep and a bell on G5
  ui_toggle   a value changes (option rows): two quick plucks (D6, E6)
  ui_error    not possible: two muted low notes a semitone apart (C4 -> B3), no reverb

ui_move, ui_ok and ui_back replace the Arcade sounds of the same AudioManager names in the profile Modern (SfxBank:
the Modern file of folder "ui" when the manifest has one). ui_tab, ui_toggle and ui_error are new names: the UI plays
them with AudioManager.play("ui/ui_tab") etc. (SfxBank takes "<folder>/<id>"; the Arcade profile ignores the names).

  python3 tools/audio/music/ui_klaenge.py              write the sounds, their imports and the manifest entries
  python3 tools/audio/music/ui_klaenge.py --out DIR    the same below DIR (no import files; QC --determinism)
  python3 tools/audio/music/ui_klaenge.py --wav DIR    also a demo file of all sounds with pauses
Deterministic (fixed seeds); a few seconds.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_lib as mlib  # noqa: E402
from music_lib import ms, ml  # noqa: E402

GENERATOR = "tools/audio/music/ui_klaenge.py"
SR = mlib.SR
mlib.set_tempo(128.0)
# id -> (momentary loudness target of the file in LUFS, description)
TARGETS = {
    "ui_move": (-23.0, "Fokus wandert"),
    "ui_ok": (-18.0, "Bestätigen"),
    "ui_back": (-19.5, "Zurück"),
    "ui_tab": (-20.5, "Reiter wechseln"),
    "ui_toggle": (-21.5, "Wert ändern"),
    "ui_error": (-20.0, "Geht nicht"),
}
PLATE = ("plate2", 1.6, 0.012, 1.0, 0.8, 9000.0, 0.15)


def _n(sec: float) -> int:
    return int(round(sec * SR))


def _place(buf: np.ndarray, x: np.ndarray, t: float, gain: float = 1.0) -> None:
    i = _n(t)
    x = x if x.ndim == 2 else np.stack([x, x], axis=1)
    m = min(len(x), len(buf) - i)
    buf[i:i + m] += x[:m] * gain


def pluck(midi: int, bright: int, var: int, dur: float = 0.18) -> np.ndarray:
    """The arpeggio synth of the music as a short pluck, cut with a soft release."""
    x = np.array(ms.arp_note(int(midi), int(bright), var))
    n = min(len(x), _n(dur))
    x = x[:n]
    x[-_n(0.03):] *= np.linspace(1.0, 0.0, _n(0.03))
    return x


def bell(midi: int, dur: float, var: int = 0) -> np.ndarray:
    x = np.array(ms.bell(int(midi), 2.0, var))[:_n(dur)]
    x[-_n(0.08):] *= np.linspace(1.0, 0.0, _n(0.08))
    return x


def sweep(dur: float, lo: float, hi: float, seed: str) -> np.ndarray:
    """A short band of noise that rises from lo to hi Hz (air)."""
    rng = ms.rng_of("ui_sweep", seed)
    n = _n(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    steps = 12
    for k in range(steps):
        a, b = int(k * n / steps), int((k + 1) * n / steps)
        fc = lo * (hi / lo) ** ((k + 0.5) / steps)
        seg = ms.band_noise(rng, b - a + 256, fc * 0.7, fc * 1.4)[:b - a]
        out[a:b] = seg
    env = np.sin(np.pi * np.clip(t / dur, 0.0, 1.0)) ** 1.5
    return out * env


def with_plate(x: np.ndarray, send_db: float) -> np.ndarray:
    ir = np.asarray(ms.reverb_ir(*PLATE))
    mono = x.mean(axis=1) if x.ndim == 2 else x
    wet = np.stack([ms.convolve(mono, ir[:, c]) for c in range(2)], axis=1)[:len(x) + len(ir) // 2]
    dry = x if x.ndim == 2 else np.stack([x, x], axis=1)
    out = np.zeros((len(wet), 2))
    out[:len(dry)] += dry
    out += ms.apply_eq(wet, [("hp", 400.0, 0.7), ("lp", 8000.0, 0.7)]) * ms.undb(send_db)
    return out


def finish(x: np.ndarray, target: float, tail_s: float) -> np.ndarray:
    """EQ, the momentary loudness target (400 ms), a short fade at the end, true peak checked."""
    x = ms.apply_eq(x, [("hp", 180.0, 0.7), ("hs", 7000.0, -1.5)])
    n = min(len(x), _n(tail_s))
    x = np.array(x[:n])
    f = _n(0.05)
    x[-f:] *= (0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, f)))[:, None]
    _t, mom = ms.loudness_curve(np.pad(x, ((0, _n(0.4)), (0, 0))), 0.4, 0.01)
    x = x * ms.undb(target - float(np.max(mom)))
    tp = ms.true_peak_db(x)
    if tp > -3.0:
        x = x * ms.undb(-3.0 - tp)
    return x


def make() -> dict:
    """id -> list of stereo float signals (variants)."""
    out = {}
    # focus move: one soft pluck on B5, two timbre variants
    mv = []
    for v, br in ((0, 2), (1, 3)):
        buf = np.zeros((_n(0.5), 2))
        _place(buf, pluck(83, br, v, 0.12), 0.0)
        click = ms.band_noise(ms.rng_of("ui_click", v), _n(0.004), 3000.0, 9000.0) * 0.08
        _place(buf, click, 0.0)
        mv.append(finish(with_plate(buf, -16.0), TARGETS["ui_move"][0], 0.42))
    out["ui_move"] = mv
    # confirm: E5 -> B5, pluck + bell
    buf = np.zeros((_n(0.9), 2))
    _place(buf, pluck(76, 4, 0, 0.16), 0.0)
    _place(buf, pluck(83, 5, 1, 0.3), 0.065)
    _place(buf, bell(83, 0.7), 0.065, 0.35)
    out["ui_ok"] = [finish(with_plate(buf, -12.0), TARGETS["ui_ok"][0], 0.85)]
    # back: A5 -> E5, darker
    buf = np.zeros((_n(0.8), 2))
    _place(buf, pluck(81, 3, 2, 0.14), 0.0)
    _place(buf, pluck(76, 2, 3, 0.26), 0.07)
    out["ui_back"] = [finish(with_plate(buf, -14.0), TARGETS["ui_back"][0], 0.7)]
    # tab: an air sweep into a bell on G5
    buf = np.zeros((_n(0.9), 2))
    sw = sweep(0.12, 1500.0, 7000.0, "tab") * 0.25
    _place(buf, np.stack([sw * 0.8, sw], axis=1), 0.0)
    _place(buf, bell(79, 0.6, 0), 0.09, 0.5)
    _place(buf, pluck(79, 3, 4, 0.12), 0.09, 0.6)
    out["ui_tab"] = [finish(with_plate(buf, -13.0), TARGETS["ui_tab"][0], 0.8)]
    # toggle: two quick plucks D6, E6
    buf = np.zeros((_n(0.6), 2))
    _place(buf, pluck(86, 3, 5, 0.07), 0.0)
    _place(buf, pluck(88, 3, 6, 0.1), 0.045)
    out["ui_toggle"] = [finish(with_plate(buf, -17.0), TARGETS["ui_toggle"][0], 0.5)]
    # error: C4 -> B3, muted, dry
    buf = np.zeros((_n(0.5), 2))
    for i, m in enumerate((60, 59)):
        x = pluck(m, 1, 7 + i, 0.11)
        b = np.array(ms.bell(m, 1.0, 0))[:len(x)] * 0.25
        _place(buf, ms.apply_eq(x + b, [("lp", 1800.0, 0.7)]), 0.13 * i)
    out["ui_error"] = [finish(buf, TARGETS["ui_error"][0], 0.45)]
    return out


def write_wav_import_keep(path: str) -> None:
    """Import settings of a one-shot WAV (uncompressed, no loop) that keep an existing uid."""
    imp = path + ".import"
    head = None
    if os.path.exists(imp):
        with open(imp, encoding="utf-8") as fh:
            head = fh.read().split("[params]")[0].rstrip("\n")
    if not head:
        res = "res://" + os.path.relpath(path, mlib.ROOT).replace(os.sep, "/")
        head = f'[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[deps]\n\nsource_file="{res}"'
    params = ["force/8_bit=false", "force/mono=false", "force/max_rate=false", "force/max_rate_hz=44100",
              "edit/trim=false", "edit/normalize=false", "edit/loop_mode=1", "edit/loop_begin=0", "edit/loop_end=-1",
              "compress/mode=0"]
    with open(imp, "w", encoding="utf-8") as fh:
        fh.write(head + "\n\n[params]\n\n" + "\n".join(params) + "\n")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="UI-Klänge des Klangprofils Modern schreiben")
    ap.add_argument("--out", default="", help="statt ins Repository unter diesen Ordner schreiben (ohne .import)")
    ap.add_argument("--wav", default="", help="zusätzlich eine Hörprobe aller Klänge mit Pausen hier ablegen")
    args = ap.parse_args(argv)
    sounds = make()
    man = ml.Manifest("ui", args.out or None)
    man.drop_generator(GENERATOR)
    gain = mlib.prefs()["ui_db"]
    rep = {}
    for sid, variants in sounds.items():
        names = [f"{sid}.wav"] if len(variants) == 1 else [f"{sid}_{i + 1}.wav" for i in range(len(variants))]
        for name, x in zip(names, variants):
            ml.write_wav16(man.file(name), x)
            if not args.out:
                write_wav_import_keep(man.file(name))
        e = man.add(sid, names if len(names) > 1 else names[0], "oneshot", GENERATOR, role="ui", bus="MUI",
                    gain_db=gain, note=f"UI-Klang: {TARGETS[sid][1]} (Momentanlautheit {TARGETS[sid][0]:g} LUFS)")
        rep[sid] = {"files": names, "lufs": e["lufs"], "true_peak_db": e["true_peak_db"]}
    man.save()
    if args.wav:
        os.makedirs(args.wav, exist_ok=True)
        demo = []
        gap = np.zeros((_n(0.8), 2))
        for sid in ("ui_move", "ui_move", "ui_move", "ui_toggle", "ui_tab", "ui_ok", "ui_back", "ui_error"):
            v = sounds[sid][len([d for d in demo if d[0] == sid]) % len(sounds[sid])]
            demo.append((sid, v))
        ms.write_wav(os.path.join(args.wav, "ui_klaenge_demo.wav"),
                     np.concatenate([np.concatenate([v, gap]) for _s, v in demo]))
    print(json.dumps(rep, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
