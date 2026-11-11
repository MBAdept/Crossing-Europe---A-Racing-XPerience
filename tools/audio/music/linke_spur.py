#!/usr/bin/env python3
"""Rennmusik 1 „Linke Spur“ für das Klangprofil „Modern“ (contract D30, §4.7; docs/audio-modern.md, section "Musik").

Grown from the audio study's sketch (D minor, 132 bpm, its groove, motif and hook) into a full piece in the brand
sound of the title theme (synthwave rock): instruments of tools/audio/music_synth.py (imported, never edited) and the
modern layers of music_lib. Form, 8-bar phrases (1 bar = 20/11 s):

  count-in (1 bar)  A1  B1  A2  P1  B2  D  S  P2  B3  A3  T   | A1 …
                    groove + motif, hook, motif on the lead guitar, lift, hook with harmony, breakdown (bells),
                    guitar solo, lift, final hook, motif in octaves, turnaround (half-time, riser) – 88 bars = 160 s

Two clips for AudioStreamInteractive (scripts/audio/modern/music_director.gd):
  linke_spur.ogg           count-in + A1 (9 bars, played once) and the loop body B1 … T, A1 (88 bars = 7,056,000
                           frames, exactly 160 s); the import loops it from the body's start (loop_offset), like the
                           title theme. The body's last phrase is A1 again, so the loop seam lies inside the music
                           (A1 -> B1) and is exact: what rings into B1 after the count-in's A1 is what rings into it
                           when the loop comes round. The count-in is one whole bar (the bar grid of the file starts at
                           frame 0): the director starts the file 20/11 s before the countdown's "LOS!".
                           Not three clips with an auto-advance from the intro into the loop: measured on Godot 4.7.2,
                           an auto-advance starts the next clip 640 (or 128) frames before the end of the first one.
  linke_spur_schluss.ogg   the ending (Bb – C – Dm with a drum fill, held final chord, ringing out), started by the
                           director at the next bar line after the finish.
Both come out of ONE render and one master (the loop body sets the level; count-in, A1 and the ending get exactly its
processing), so the join is gapless and the levels match.

  python3 tools/audio/music/linke_spur.py              render, write both files, their imports and the manifest
  python3 tools/audio/music/linke_spur.py --out DIR    the same below DIR (no import files; QC --determinism)
  python3 tools/audio/music/linke_spur.py --wav DIR    also keep the whole master as float WAV (previews)
  python3 tools/audio/music/linke_spur.py --sketch N   only the count-in and the first N bars, as WAV to --wav
  python3 tools/audio/music/linke_spur.py --info       form and clip lengths, no rendering
Deterministic; about 4-8 minutes on one core.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
import os
import sys
import time

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_lib as mlib  # noqa: E402
from music_lib import ms, ml  # noqa: E402

GENERATOR = "tools/audio/music/linke_spur.py"
PIECE = "linke_spur"
BPM = 132.0
mlib.set_tempo(BPM)
SR = mlib.SR
BAR, STEP, BEAT = ms.BAR, ms.STEP, ms.BEAT
FILES = {"main": "linke_spur.ogg", "ending": "linke_spur_schluss.ogg"}
IDS = {"main": "linke_spur", "ending": "linke_spur_schluss"}
TITLE = "Crossing Europe - Linke Spur"
COUNTIN_BARS = 1
ENDING_BARS = 2
GAP_BARS = 3            # silence between the extra bars and the ending in the render (the tails die away)
EXTRA_BARS = 3          # the loop's continuation (B1 bars 1-3) after A1', for the seam check
TAIL_S = 4.2            # the ending rings out

# chords: bass root, power chord (guitars), pad voicing, arpeggio notes, upper triad (brass)
CH = {
    "Dm": {"root": 38, "pow": (50, 57, 62), "pad": (50, 57, 62, 65), "arp": (62, 65, 69, 74), "tri": (62, 65, 69)},
    "Bb": {"root": 34, "pow": (46, 53, 58), "pad": (46, 53, 58, 62), "arp": (58, 62, 65, 70), "tri": (62, 65, 70)},
    "C": {"root": 36, "pow": (48, 55, 60), "pad": (48, 55, 60, 64), "arp": (60, 64, 67, 72), "tri": (64, 67, 72)},
    "F": {"root": 41, "pow": (41, 48, 53), "pad": (53, 57, 60, 65), "arp": (65, 69, 72, 77), "tri": (65, 69, 72)},
    "A": {"root": 33, "pow": (45, 52, 57), "pad": (45, 52, 57, 61), "arp": (57, 61, 64, 69), "tri": (64, 69, 73)},
    "Gm": {"root": 31, "pow": (43, 50, 55), "pad": (43, 50, 55, 58), "arp": (55, 58, 62, 67), "tri": (62, 67, 70)},
}
# phrases of the loop (id, kind, chords) – A groove + motif, B hook, P lift, D breakdown, S solo, T turnaround
PHRASES = [
    ("A1", "A", "Dm Dm Bb C Dm Dm Bb C"),
    ("B1", "B", "Bb C Dm Dm Bb C F A"),
    ("A2", "A", "Dm Dm Bb C Dm Dm Bb C"),
    ("P1", "P", "Gm Gm Bb Bb C C A A"),
    ("B2", "B", "Bb C Dm Dm Bb C F A"),
    ("D", "D", "Bb F C Dm Bb F C A"),
    ("S", "S", "Dm Bb C Dm Dm Bb C A"),
    ("P2", "P", "Gm Gm Bb Bb C C A A"),
    ("B3", "B", "Bb C Dm Dm Bb C F A"),
    ("A3", "A", "Dm Dm Bb C Dm Dm Bb C"),
    ("T", "T", "Dm Dm Bb C Gm Gm A A"),
]
LOOP_BARS = 8 * len(PHRASES)                         # 88
LOOP_FRAMES = int(round(LOOP_BARS * BAR * SR))       # 7,056,000 (11 bars = 20 s exactly)

# --- melodies (16th steps per bar, "step:len:Note[:opts]" as in music_synth.parse_line) ------------------------------
MOTIF = [
    "0:3:D5 3:3:F5 6:2:A5 8:3:G5 11:3:F5 14:2:E5",              # Dm
    "0:6:F5 6:2:D5 8:8:A4",                                     # Dm
    "0:3:D5 3:3:F5 6:2:Bb5 8:3:A5 11:3:G5 14:2:F5",             # Bb
    "0:8:E5 8:2:G5 10:2:C6 12:4:G5",                            # C
]
ANSWER = [
    "0:3:D5 3:3:F5 6:2:A5 8:3:D6 11:3:C6 14:2:A5",              # Dm
    "0:6:C6 6:2:A5 8:8:F5",                                     # Dm
    "0:3:Bb4 3:3:D5 6:2:F5 8:3:Bb5 11:3:A5 14:2:F5",            # Bb
    "0:8:G5 8:2:E5 10:2:G5 12:4:C6",                            # C
]
HOOK = [
    "0:6:D5 6:2:F5 8:8:Bb5",                                    # Bb
    "0:6:E5 6:2:G5 8:6:C6 14:2:Bb5",                            # C
    "0:8:A5 8:3:F5 11:3:G5 14:2:A5",                            # Dm
    "0:12:D6:v 12:2:C6 14:2:A5",                                # Dm
    "0:6:Bb5 6:2:A5 8:4:F5 12:4:D5",                            # Bb
    "0:6:C6 6:2:Bb5 8:4:G5 12:4:E5",                            # C
    "0:3:F5 3:3:A5 6:2:C6 8:8:F6:v",                            # F
    "0:8:E6 8:4:C#6 12:4:A5",                                   # A
    "0:16:D6:v",                                                # (first bar of the next phrase)
]
HARMONY = [
    "0:6:Bb4 6:2:D5 8:8:F5",
    "0:6:C5 6:2:E5 8:6:G5 14:2:G5",
    "0:8:F5 8:3:D5 11:3:E5 14:2:F5",
    "0:12:A5:v 12:2:A5 14:2:F5",
    "0:6:G5 6:2:F5 8:4:D5 12:4:Bb4",
    "0:6:A5 6:2:G5 8:4:E5 12:4:C5",
    "0:3:D5 3:3:F5 6:2:A5 8:8:D6",
    "0:8:C#6 8:4:A5 12:4:E5",
    "0:16:A5",
]
LIFT = [
    "0:8:Bb4 8:4:A4 12:4:G4",                                   # Gm
    "0:16:D5",                                                  # Gm
    "0:8:D5 8:4:C5 12:4:Bb4",                                   # Bb
    "0:16:F5",                                                  # Bb
    "0:8:E5 8:4:D5 12:4:C5",                                    # C
    "0:16:G5",                                                  # C
    "0:8:A5 8:8:G5",                                            # A7
    "0:8:E5 8:8:C#5",                                           # A
]
BELLS = [
    "0:6:F5 6:6:D5 12:4:Bb4", "0:6:C5 6:6:A4 12:4:F4", "0:6:E5 6:6:C5 12:4:G4", "0:6:F5 6:6:D5 12:4:A4",
    "0:6:F5 6:6:D5 12:4:Bb4", "0:6:A5 6:6:F5 12:4:C5", "0:6:G5 6:6:E5 12:4:C5", "0:16:E5",
]
SOFT_D = ["0:16:D5", "0:8:C5 8:8:F5", "0:16:E5", "0:8:C#5 8:8:E5"]
SOLO = [
    "0:4:A4:b-2 4:2:F4 6:2:D4 8:2:F4 10:2:G4 12:4:A4:v",                                          # Dm
    "0:2:Bb4 2:2:A4 4:2:F4 6:2:D4 8:8:F4:v",                                                      # Bb
    "0:1:C4 1:1:D4 2:1:F4 3:1:G4 4:1:A4 5:1:C5 6:1:D5 7:1:E5 8:8:F5:v",                           # C
    "0:6:A5:b-2:v 6:2:F5 8:4:D5 12:4:A4",                                                         # Dm
    "0:8:D5:v 8:2:C5 10:2:A4 12:2:C5 14:2:D5",                                                    # Dm
    "0:4:F5 4:4:D5 8:2:F5 10:2:G5 12:4:A5:b-2:v",                                                 # Bb
    "0:1:C6 1:1:A5 2:1:G5 3:1:E5 4:1:G5 5:1:E5 6:1:D5 7:1:C5 8:1:E5 9:1:D5 10:1:C5 11:1:A4 "
    "12:1:D5 13:1:C5 14:1:A4 15:1:G4",                                                            # C
    "0:6:A4:v 6:2:C#5 8:4:E5 12:4:A5:B+2",                                                        # A
]
SOFT_T = ["0:16:A4", "0:8:F4 8:8:A4", "0:16:F4", "0:16:G4", "0:16:Bb4", "0:8:D5 8:8:Bb4", "0:16:C#5",
          "0:8:E5 8:8:C#5"]
END_LEAD = ["0:8:D6 8:8:E6", "0:28:F6:v"]
END_HARM = ["0:8:Bb5 8:8:C6", "0:28:D6:v"]
# synth phrases: (phrase id, first bar, lines, transposition, patch, velocity, track); "wide" = + supersaw double
LEADS = [
    ("A1", 4, MOTIF, 0, "lead", 0.9, "lead_syn"),
    ("B1", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
    ("P1", 0, LIFT, 0, "lead", 0.82, "lead_syn"),
    ("B2", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
    ("B2", 4, HARMONY[4:], 0, "lead", 0.6, "harm_syn"),
    ("D", 4, SOFT_D, 0, "soft", 0.8, "lead_syn"),
    ("P2", 0, LIFT, 0, "lead", 0.85, "lead_syn"),
    ("B3", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
    ("B3", 0, HARMONY, 0, "lead", 0.6, "harm_syn"),
    ("A3", 0, MOTIF + ANSWER, 0, "lead", 0.9, "lead_syn"),
    ("T", 0, SOFT_T, 0, "soft", 0.75, "lead_syn"),
    ("E", 0, END_LEAD, 0, "lead", 1.0, "lead_syn+wide"),
    ("E", 0, END_HARM, 0, "lead", 0.62, "harm_syn"),
]
# lead guitar phrases: (phrase id, first bar, lines, transposition, velocity)
GUITAR = [
    ("A2", 0, MOTIF + ANSWER, 0, 0.9),
    ("B2", 0, HOOK, -12, 0.8),
    ("S", 0, SOLO, 0, 1.0),
    ("P2", 0, LIFT, -12, 0.75),
    ("B3", 0, HOOK, -12, 0.85),
    ("A3", 0, MOTIF + ANSWER, -12, 0.8),
    ("E", 0, END_LEAD, -12, 0.85),
]
PAD_LEVEL = {"in": 0.6, "A": 0.8, "B": 1.0, "P": 0.95, "D": 1.0, "S": 0.7, "T": 0.9, "E": 1.0}
ARP_STYLE = {"A": (0.85, 4), "B": (0.9, 6), "P": (0.85, 5), "D": (1.0, 6), "S": (0.65, 3), "T": (0.85, 5)}
# section automation (dB per track group): kind -> dB, or (kind, first bar, last bar) -> dB
AUTOMATION = {
    "lead_gtr": {"S": 4.0, "A": 1.5},
    "guitars": {"D": -2.0, "S": -2.5, ("T", 0, 3): -1.5},
    "bass": {("D", 0, 3): -1.5},
}


class Bar:
    __slots__ = ("i", "t", "pid", "kind", "j", "chord", "nxt", "key")


def timeline() -> list:
    """Bars of the render: count-in, the 11 phrases, A1 again (A1'), the extra bars (B1's first ones), a gap, the
    ending. key = seed key: A1' and the extra bars share the keys of A1 and B1 – identical events."""
    rows = [("in", "in", 0, "A")]
    for pid, kind, chords in PHRASES + [PHRASES[0]]:
        for j, c in enumerate(chords.split()):
            rows.append((pid, kind, j, c))
    b1 = PHRASES[1]
    for j in range(EXTRA_BARS):
        rows.append((b1[0], b1[1], j, b1[2].split()[j]))
    for j in range(GAP_BARS):
        rows.append(("gap", "gap", j, "Dm"))
    for j, c in enumerate(["Bb", "Dm"]):
        rows.append(("E", "E", j, c))
    bars = []
    for i, (pid, kind, j, c) in enumerate(rows):
        b = Bar()
        b.i, b.t, b.pid, b.kind, b.j, b.chord = i, i * BAR, pid, kind, j, c
        b.key = (pid, j)
        bars.append(b)
    for a, b in zip(bars, bars[1:]):
        a.nxt = b.chord
    bars[-1].nxt = "Dm"
    return bars


BARS = timeline()
I_BODY = 1 + 8                                     # first bar of the loop body (B1)
I_END = len(BARS) - ENDING_BARS                    # first bar of the ending
N_RENDER = int(round(len(BARS) * BAR * SR + TAIL_S * SR))
F_BODY = int(math.floor(I_BODY * BAR * SR))        # 721,636: where the body starts in the render (= intro length)
F_END = int(math.floor(I_END * BAR * SR))
N_ENDING = int(round(ENDING_BARS * BAR * SR + TAIL_S * SR))


def phrase_start(pid: str) -> list:
    return [b.i for b in BARS if b.pid == pid and b.j == 0]


def lines_until_gap(lines: list, bar0: int, n_bars: int) -> list:
    """The lines of a phrase that start before the next gap bar (the extra bars after A1' end there) and inside the
    rendered bars (bells: every note is its own sound)."""
    k = 0
    while k < len(lines) and bar0 + k < n_bars and BARS[bar0 + k].kind != "gap":
        k += 1
    return lines[:k]


def cut_at_gap(y: np.ndarray, t0: float, bar0: int) -> np.ndarray:
    """A whole phrase rendered from bar0 on, silenced from the next gap bar on (20 ms fade). The phrase is always
    rendered complete: the frozen oscillator picks its band limit from the highest note of the whole phrase, so a
    phrase cut before rendering would sound brighter or darker than the same phrase in the loop."""
    gap = next((b for b in BARS[bar0:] if b.kind == "gap"), None)
    if gap is None:
        return y
    k = int(round((gap.t - t0) * SR))
    if k >= len(y):
        return y
    y = np.array(y)
    f = int(0.02 * SR)
    a = max(0, k - f)
    ramp = np.linspace(1.0, 0.0, k - a)
    y[a:k] *= ramp if y.ndim == 1 else ramp[:, None]
    y[k:] = 0.0
    return y


# --- per-bar patterns ------------------------------------------------------------------------------------------------

def drum_bar(b: Bar) -> list:
    k, j = b.kind, b.j
    if k == "in":
        ev = [(s, "snare", 0.15 + 0.75 * ((s - 2) / 9.0) ** 1.4) for s in range(2, 12)]
        ev += [(12, "tom_h", 0.8), (13, "tom_h", 0.85), (14, "tom_m", 0.9), (15, "tom_f", 1.0)]
        return ev
    if k == "E":
        if j == 0:
            return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 0.9), (8, "kick", 1.0), (8, "snare", 1.0),
                    (8, "crash", 0.8), (12, "tom_h", 0.85), (13, "tom_h", 0.9), (14, "tom_m", 0.95), (15, "tom_f", 1.0)]
        return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 1.0)]
    if k == "gap":
        return []
    if k == "A":
        ev = [(s, "kick", 1.0 if s in (0, 8) else 0.93) for s in (0, 4, 8, 12)]
        ev += [(4, "snare", 1.0), (12, "snare", 1.0)]
        ev += [(s, "hat_c", 0.7 if s % 4 == 2 else 0.48) for s in range(0, 16, 2)]
        if b.pid != "A1" and j >= 4:
            ev = [e for e in ev if not (e[1] == "hat_c" and e[0] % 4 == 2)] + [(s, "hat_o", 0.5) for s in (2, 6, 10, 14)]
        ev += [(s, "shaker", 0.9 if s % 4 == 2 else 0.5) for s in range(16)]
        if j in (3, 5):
            ev.append((14, "kick", 0.8))
        if j == 0:
            ev.append((0, "crash", 0.9))
        if j == 7:
            ev = _fill(ev, "toms" if b.nxt == "Bb" else "small")
        return ev
    if k in ("B", "S"):
        ev = [(s, "kick", 1.0 if s in (0, 8) else 0.93) for s in (0, 4, 8, 12)]
        ev += [(4, "snare", 1.0), (12, "snare", 1.0), (4, "clap", 0.75), (12, "clap", 0.75)]
        ev += [(s, "hat_o", 0.55) for s in (2, 6, 10, 14)]
        ev += [(s, "hat_c", 0.42 if s % 4 == 0 else 0.26) for s in range(16) if s % 4 != 2]
        ev += [(s, "shaker", 0.9 if s % 4 == 2 else 0.5) for s in range(16)]
        if j % 2 == 1:
            ev.append((14, "kick", 0.8))
        crash = (0, 2, 4, 6) if (k == "S" or b.pid == "B3") else (0, 4)
        if j in crash:
            ev.append((0, "crash", 0.95 if j == 0 else 0.8))
        if j == 7:
            ev = _fill(ev, "big" if k == "S" else "toms")
        return ev
    if k == "P":
        if j == 6:
            return [(s, "snare", 0.45 + 0.5 * s / 14) for s in range(0, 16, 2)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
        if j == 7:
            return ([(s, "snare", 0.4 + 0.6 * s / 15) for s in range(16)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
                    + [(12, "tom_m", 0.7), (14, "tom_f", 0.8)])
        ev = [(0, "kick", 1.0), (8, "kick", 0.95), (4, "snare", 1.0), (12, "snare", 1.0)]
        if j % 2:
            ev.append((14, "kick", 0.8))
        ev += [(s, "hat_o", 0.45) for s in (0, 4, 8, 12)] + [(s, "tom_f", 0.3) for s in (2, 6, 10, 14)]
        if j in (0, 4):
            ev.append((0, "crash", 0.8))
        return ev
    if k == "D":
        if j < 2:
            return [(0, "kick", 0.5)]
        if j < 4:
            return [(0, "kick", 0.55)] + [(s, "hat_c", 0.25) for s in range(0, 16, 2)]
        if j < 6:
            return ([(0, "kick", 0.85), (10, "kick", 0.7), (8, "snare", 0.85)] + [(s, "hat_c", 0.35) for s in range(0, 16, 2)]
                    + ([(0, "crash", 0.6)] if j == 4 else []))
        if j == 6:
            return [(s, "snare", 0.45 + 0.5 * s / 14) for s in range(0, 16, 2)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
        return [(s, "snare", 0.4 + 0.6 * s / 15) for s in range(16)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
    if k == "T":
        if j < 4:
            ev = [(0, "kick", 1.0), (10, "kick", 0.8), (8, "snare", 1.0)] + [(s, "hat_c", 0.4) for s in range(0, 16, 2)]
            if j == 0:
                ev.append((0, "crash", 0.9))
            if j == 3:
                ev += [(14, "snare", 0.6), (15, "snare", 0.7)]
            return ev
        if j < 6:
            ev = [(s, "kick", 1.0 if s in (0, 8) else 0.93) for s in (0, 4, 8, 12)] + [(4, "snare", 1.0), (12, "snare", 1.0)]
            ev += [(s, "hat_o", 0.5) for s in (2, 6, 10, 14)]
            return ev + ([(0, "crash", 0.85)] if j == 4 else [])
        if j == 6:
            return [(s, "snare", 0.45 + 0.5 * s / 14) for s in range(0, 16, 2)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
        return ([(s, "snare", 0.4 + 0.6 * s / 15) for s in range(16)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
                + [(12, "tom_h", 0.85), (13, "tom_h", 0.9), (14, "tom_m", 0.95), (15, "tom_f", 1.0)])
    raise ValueError(k)


FILLS = {
    "small": [(12, "snare", 0.7), (13, "snare", 0.75), (14, "tom_h", 0.85), (15, "tom_m", 0.9)],
    "toms": [(12, "tom_h", 0.85), (13, "tom_h", 0.8), (14, "tom_m", 0.9), (15, "tom_f", 0.95)],
    "big": [(8, "snare", 0.75), (9, "snare", 0.7), (10, "tom_h", 0.85), (11, "tom_h", 0.8), (12, "tom_m", 0.9),
            (13, "tom_m", 0.85), (14, "tom_f", 0.95), (15, "tom_f", 1.0)],
}


def _fill(ev: list, kind: str) -> list:
    fill = FILLS[kind]
    start = min(s for s, _, _ in fill)
    return [e for e in ev if e[0] < start or e[1] == "kick"] + fill


def bass_bar(b: Bar) -> list:
    """(step, length in steps, midi, velocity, layers: p picked, s synth, d dark drone)."""
    r = CH[b.chord]["root"]
    k, j = b.kind, b.j
    eighths = range(0, 16, 2)
    if k in ("gap",):
        return []
    if k == "in":
        return [(0, 16, r, 0.55, "d")]
    if k == "E":
        if j == 0:
            return [(0, 7, CH["Bb"]["root"], 1.0, "ps"), (8, 7, CH["C"]["root"], 1.0, "ps")]
        return [(0, 40, r, 1.0, "ps")]
    if k == "A":
        out = []
        for s in eighths:
            m = r + (12 if s in (6, 14) else 0)
            if j == 7 and s == 14 and b.nxt != b.chord:
                m = CH[b.nxt]["root"] - 1 if CH[b.nxt]["root"] - 1 > 28 else CH[b.nxt]["root"] + 11
            out.append((s, 1.8, m, 1.0 if s % 4 == 0 else 0.86, "ps"))
        return out
    if k in ("B", "S"):
        return [(s, 1.8, r + (12 if (s // 2) % 2 else 0), 0.95 if s % 4 == 0 else 0.82, "ps") for s in eighths]
    if k == "P":
        return [(s, 1.8, r, 0.92 if s % 8 == 0 else 0.8, "ps") for s in eighths]
    if k == "D":
        if j < 4:
            return [(0, 16, r, 0.5, "d")]
        if j < 6:
            return [(s, 1.8, r, 0.7, "s") for s in eighths]
        return [(s, 1.8, r, 0.8, "ps") for s in eighths]
    if k == "T":
        if j < 4:
            return [(0, 7.5, r, 1.0, "ps"), (8, 7.5, r, 0.9, "ps")]
        return [(s, 1.8, r, 0.92 if s % 8 == 0 else 0.82, "ps") for s in eighths]
    raise ValueError(k)


def gtr_bar(b: Bar, take: int) -> list:
    """(step, length, mode, velocity, stroke) of a power chord of the bar's chord."""
    k, j = b.kind, b.j
    inner = take >= 2
    if k in ("in", "gap"):
        return []
    if k == "E":
        if j == 0:
            return [(0, 8, "open", 1.0, 1, "Bb"), (8, 8, "open", 1.0, 1, "C")]
        return [(0, 40, "open", 1.0, 1, "Dm")]
    if k == "A":
        if inner and b.pid == "A1":
            return []
        return [(s, 2, "half" if s in (0, 6, 12) else "mute", 1.0 if s in (0, 6, 12) else 0.8, 1) for s in range(0, 16, 2)]
    if k == "B":
        return [(0, 6, "open", 1.0, 1), (6, 6, "open", 0.95, 1), (12, 2, "open", 0.9, 1), (14, 2, "half", 0.85, 1)]
    if k == "S":
        return [(s, 2, "open", 0.86 if s % 4 == 0 else 0.78, 1) for s in range(0, 16, 2)]
    if k == "P":
        if j == 6:
            return [(s, 2, "open", 0.88, 1) for s in range(0, 16, 2)]
        if j == 7:
            return [(s, 1, "mute", 0.55 + 0.45 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
        return [(0, 4, "open", 0.95, 1)] + [(s, 2, "half", 0.8, 1) for s in (4, 6, 8, 10, 12, 14)]
    if k == "D":
        if j < 4 or inner:
            return [] if j < 7 else [(s, 1, "mute", 0.5 + 0.5 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
        if j < 7:
            return [(0, 16, "open", 0.72, 1)]
        return [(s, 1, "mute", 0.5 + 0.5 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
    if k == "T":
        if j < 4:
            return [(0, 16, "open", 0.8, 1)] if not inner else []
        if j < 6:
            return [(s, 2, "half" if s in (0, 6, 12) else "mute", 0.95 if s in (0, 6, 12) else 0.78, 1) for s in range(0, 16, 2)]
        if j == 6:
            return [(s, 2, "open", 0.88, 1) for s in range(0, 16, 2)]
        return [(s, 1, "mute", 0.55 + 0.45 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
    raise ValueError(k)


def arp_bar(b: Bar) -> list:
    """(step, midi, velocity, brightness)."""
    k = b.kind
    if k in ("gap", "E"):
        return []
    order = (0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3)
    notes = CH[b.chord]["arp"]
    out = []
    for s in range(16):
        if k == "in":
            vel, bright = 0.35 + 0.35 * s / 15, min(7, 1 + int(s / 3))
        else:
            vel, bright = ARP_STYLE[k]
            if k == "D" and b.j < 2:
                vel *= 0.8
        m = notes[order[s]] + (12 if (k == "B" and s % 8 >= 4) else 0)
        out.append((s, int(m), vel * (1.0 if s % 4 == 0 else 0.8), bright))
    return out


def brass_bar(b: Bar) -> list:
    """(step, length, velocity, chord)."""
    k, j, c = b.kind, b.j, b.chord
    if k == "P":
        if j in (0, 2, 4):
            return [(0, 6, 0.7, c)]
        if j == 6:
            return [(0, 4, 0.75, c), (6, 4, 0.75, c), (12, 3, 0.75, c)]
        if j == 7:
            return [(0, 6, 0.8, c)]
    if b.pid == "B3" and j in (0, 4):
        return [(0, 8, 0.8, c)]
    if k == "E":
        return [(0, 6, 0.8, "Bb"), (8, 6, 0.8, "C")] if j == 0 else [(0, 24, 0.9, "Dm")]
    return []


def auto_gain(group: str, n: int) -> np.ndarray | None:
    rules = AUTOMATION.get(group)
    if not rules:
        return None
    pts_t, pts_v, prev = [], [], None
    for b in BARS:
        v = rules.get(b.kind, 0.0)
        for kk, val in rules.items():
            if isinstance(kk, tuple) and kk[0] == b.kind and kk[1] <= b.j <= kk[2]:
                v = val
        if v != prev:
            pts_t += [b.t - 0.03, b.t + 0.03]
            pts_v += [v if prev is None else prev, v]
            prev = v
    return 10.0 ** (np.interp(np.arange(n) / SR, pts_t, pts_v) / 20.0)


# --- mix specs (from the sketch, the title remaster and ms.MIX) ------------------------------------------------------

def specs() -> dict:
    sp = {k: copy.deepcopy(ms.MIX[k]) for k in ("kick", "snare", "clap", "toms", "hats", "crash", "bass_pick", "bass_syn",
                                                "gtr_L", "gtr_R", "lead_gtr", "lead_syn", "harm_syn", "pad", "arp",
                                                "brass", "bell", "fx")}
    sp["kick"]["lufs"] = -19.3
    sp["kick2"] = {"bus": "drums", "lufs": -25.0, "eq": [("hp", 36.0, 0.7), ("peak", 300.0, -4.0, 1.2), ("peak", 4000.0, 3.0, 1.0)]}
    sp["snare"]["lufs"] = -20.5
    sp["snare2"] = {"bus": "drums", "lufs": -19.8, "eq": [("hp", 110.0, 0.7), ("peak", 200.0, 2.0, 1.2),
                                                          ("peak", 5000.0, 2.0, 0.8)], "sends": {"plate": -14.0}}
    sp["shaker"] = {"bus": "drums", "lufs": -36.0, "eq": [("hp", 4000.0, 0.7)]}
    sp["hats"]["lufs"] = -30.5
    sp["hats"]["eq"] = [("hp", 450.0, 0.7), ("lp", 16500.0, 0.7)]
    sp["crash"]["eq"] = [("hp", 400.0, 0.7), ("hs", 8000.0, -2.0), ("lp", 16000.0, 0.7)]
    sp["sub"] = {"bus": "inst", "lufs": -27.0, "eq": [("lp", 105.0, 0.7), ("hp", 28.0, 0.7)], "duck": 0.8}
    sp["bass_pick"]["eq"] = [("hp", 45.0, 0.8), ("peak", 250.0, -1.5, 1.0), ("peak", 950.0, 3.0, 1.2), ("lp", 4500.0, 0.7)]
    sp["bass_pick"].update({"duck": 0.3, "lufs": -20.5})
    sp["bass_syn"].update({"duck": 0.65, "lufs": -20.5})
    for g in ("gtr_L", "gtr_R"):
        sp[g]["duck"] = 0.15
        sp[g]["eq"] = [("hp", 90.0, 0.7), ("peak", 3400.0, 1.0, 1.0), ("lp", 9000.0, 0.7)]
    for g, pan in (("gtr_L2", -0.55), ("gtr_R2", 0.55)):
        sp[g] = {"bus": "inst", "lufs": -27.5, "pan": pan, "eq": [("hp", 95.0, 0.7), ("lp", 7000.0, 0.7)], "duck": 0.2}
    sp["pad"]["duck"] = 0.6
    sp["pad"]["eq"] = [("hp", 160.0, 0.7), ("peak", 400.0, -1.5, 1.0), ("lp", 5200.0, 0.8)]
    sp["arp"].update({"duck": 0.4, "lufs": -25.5})
    sp["lead_syn"]["lufs"] = -19.5
    sp["lead_wide"] = {"bus": "inst", "lufs": -24.5, "eq": [("hp", 220.0, 0.7), ("hs", 6000.0, 2.0)], "duck": 0.15,
                       "sends": {"hall": -10.0, "delay": -13.0}}
    sp["lead_gtr"]["lufs"] = -23.0
    sp["bell"]["lufs"] = -24.0
    return sp


TRACK_GROUP = {"kick": "drums", "kick2": "drums", "snare": "drums", "snare2": "drums", "clap": "drums", "toms": "drums",
               "hats": "drums", "shaker": "drums", "crash": "drums", "bass_pick": "bass", "bass_syn": "bass", "sub": "bass",
               "gtr_L": "guitars", "gtr_R": "guitars", "gtr_L2": "guitars", "gtr_R2": "guitars", "lead_gtr": "lead_gtr"}


# --- render ----------------------------------------------------------------------------------------------------------

def render(n_bars: int | None = None, log=print) -> tuple:
    """Renders the timeline (or only its first n_bars + 3 s) and mixes it. Returns (mix, levels)."""
    bars = BARS if n_bars is None else BARS[:n_bars]
    n = N_RENDER if n_bars is None else int(round((n_bars * BAR + 3.0) * SR))
    t_end = len(bars) * BAR
    sp = specs()
    t_all = time.time()
    # drums
    ev = []
    for b in bars:
        for s, inst, vel in drum_bar(b):
            r = ms.rng_of("ls_drum", b.key, s, inst)
            jit = {"kick": 0.0006, "shaker": 0.002}.get(inst, 0.002)
            ev.append((b.t + s * STEP + jit * r.uniform(-1.0, 1.0), inst, vel * (1.0 + 0.05 * r.uniform(-1, 1)),
                       int(r.integers(0, 4)), s))
    kick_times = [e[0] for e in ev if e[1] == "kick"]
    mx = mlib.Mixer(n, kick_times, 0.17, log)

    def add(name: str, canvas: mlib.Canvas | np.ndarray) -> None:
        x = canvas.x if isinstance(canvas, mlib.Canvas) else canvas
        mx.add(name, x, sp[name], auto_gain(TRACK_GROUP.get(name, name), n))

    t1 = time.time()
    for names in (("kick", "kick2"), ("snare", "snare2"), ("clap",), ("toms",), ("hats",), ("shaker",), ("crash",)):
        cv = {nm: mlib.Canvas(n) for nm in names}
        for t, inst, vel, var, s in ev:
            if inst == "kick" and "kick" in cv:
                cv["kick"].place(ms.kick(var), t, vel)
                cv["kick2"].place(mlib.kick2(var), t, vel)
            elif inst == "snare" and "snare" in cv:
                cv["snare"].place(ms.snare(var), t, vel ** 1.3)
                cv["snare2"].place(mlib.snare2(var), t, vel ** 1.3)
            elif inst == "clap" and "clap" in cv:
                cv["clap"].place(ms.clap(var), t, vel)
            elif inst.startswith("tom") and "toms" in cv:
                cv["toms"].place(ms.tom(inst, var), t, vel ** 1.2, {"tom_h": -0.35, "tom_m": 0.0, "tom_f": 0.35}[inst])
            elif inst in ("hat_c", "hat_o") and "hats" in cv:
                cv["hats"].place(ms.hat(inst == "hat_o", var), t, vel, 0.3)
            elif inst == "shaker" and "shaker" in cv:
                cv["shaker"].place(mlib.shaker(var), t, vel, 0.25 if s % 2 else -0.25)
            elif inst == "crash" and "crash" in cv:
                cv["crash"].place(ms.crash(var % 2), t, vel, -0.35 if var % 2 else 0.35)
        for nm in names:
            add(nm, cv[nm])
        del cv
    log(f"  {'drums':12s} {time.time() - t1:6.1f} s")
    # bass: picked + synth + sub
    t1 = time.time()
    pick, syn, sub = mlib.Canvas(n), mlib.Canvas(n), mlib.Canvas(n)
    for b in bars:
        for s, ln, m, vel, layers in bass_bar(b):
            r = ms.rng_of("ls_bass", b.key, s)
            t = b.t + s * STEP + 0.0015 * r.uniform(-1.0, 1.0)
            var = int(r.integers(0, 3))
            if "p" in layers:
                pick.place(ms.bass_pick(int(m), ln, var), t, vel)
            if "d" in layers:
                syn.place(ms.bass_syn(int(m), ln, var, 170.0, 300.0, 0.6), t, vel)
            elif "s" in layers:
                syn.place(ms.bass_syn(int(m), ln, var, 300.0 if b.kind in ("B", "S") else 250.0), t, vel)
            sub.place(mlib.sub_bass(int(m), round(ln * STEP, 4)), t, vel * (0.7 if "d" in layers else 1.0))
    add("bass_pick", pick)
    add("bass_syn", syn)
    add("sub", sub)
    del pick, syn, sub
    log(f"  {'bass':12s} {time.time() - t1:6.1f} s")
    # rhythm guitars: four takes (two hard-panned, two darker inside)
    t1 = time.time()
    for take, name in ((0, "gtr_L"), (1, "gtr_R"), (2, "gtr_L2"), (3, "gtr_R2")):
        di = mlib.Canvas(n, mono=True)
        for b in bars:
            for evg in gtr_bar(b, take):
                s, ln, mode, vel, stroke = evg[:5]
                chord = evg[5] if len(evg) > 5 else b.chord
                r = ms.rng_of("ls_gtr", take, b.key, s)
                t = b.t + s * STEP + 0.004 * r.uniform(-1.0, 1.0) + 0.003 * take
                notes = CH[chord]["pow"] if mode != "mute" else CH[chord]["pow"][:2]
                di.place(ms.gtr_hit(notes, ln, mode, stroke, take, int(r.integers(0, 4))), t,
                         vel * (1.0 + 0.04 * r.uniform(-1, 1)))
        p = dict(ms.AMP_RHYTHM)
        if take == 1:
            p = {**p, "mid_f": 820.0, "g1": 7.5, "post": p["post"] + [("peak", 2600.0, 1.0, 1.5)]}
        elif take >= 2:
            p = {**p, "mid_f": 640.0, "g1": 6.0, "post": p["post"] + [("peak", 1200.0, 2.0, 1.0), ("lp", 5000.0, 0.7)]}
        y = ms.amp_sim(di.x, p)
        del di
        add(name, np.stack([y, y], axis=1))
    log(f"  {'guitars':12s} {time.time() - t1:6.1f} s")
    # pad, arpeggio, brass, bells
    t1 = time.time()
    pad = mlib.Canvas(n)
    for b in bars:
        if b.kind == "gap":
            continue
        if b.kind == "E" and b.j == 1:
            pad.place(ms.pad_chord(CH["Dm"]["pad"], round(BAR * 1.9, 4), 0), b.t, PAD_LEVEL["E"])
            continue
        if b.kind == "E":
            pad.place(ms.pad_chord(CH["Bb"]["pad"], round(BAR * 0.48, 4), 0), b.t, PAD_LEVEL["E"])
            pad.place(ms.pad_chord(CH["C"]["pad"], round(BAR * 0.48, 4), 0), b.t + 8 * STEP, PAD_LEVEL["E"])
            continue
        pad.place(ms.pad_chord(CH[b.chord]["pad"], round(BAR * 0.98, 4), 0), b.t, PAD_LEVEL[b.kind])
    add("pad", pad)
    del pad
    arp = mlib.Canvas(n)
    for b in bars:
        for s, m, vel, bright in arp_bar(b):
            arp.place(ms.arp_note(m, bright, s % 2), b.t + s * STEP, vel, 0.28 if s % 2 else -0.28)
    add("arp", arp)
    del arp
    br = mlib.Canvas(n)
    for b in bars:
        for s, ln, vel, chord in brass_bar(b):
            tri = CH[chord]["tri"]
            br.place(ms.brass(tuple(list(tri) + [tri[0] + 12]), ln, 0), b.t + s * STEP, vel)
    add("brass", br)
    del br
    bell = mlib.Canvas(n)
    for i0 in phrase_start("D"):
        use = lines_until_gap(BELLS, i0, len(bars))
        if use:
            for nt in ms.phrase(use, i0):
                if nt["t"] < t_end:
                    bell.place(ms.bell(nt["midi"], round(nt["dur"] / STEP, 3), 0), nt["t"], 0.75, -0.15)
    add("bell", bell)
    del bell
    log(f"  {'keys':12s} {time.time() - t1:6.1f} s")
    # synth leads (+ the supersaw double) and harmony
    t1 = time.time()
    lead, wide, harm = mlib.Canvas(n), mlib.Canvas(n), mlib.Canvas(n)
    for pid, j0, lines, tr, patch, vel, track in LEADS:
        for i0 in phrase_start(pid):
            if i0 + j0 >= len(bars):
                continue
            notes = ms.phrase(lines, i0 + j0, tr)
            tt, y = ms.synth_lead(notes, patch, f"ls:{pid}:{j0}:{track}", vel)
            (harm if track == "harm_syn" else lead).place(cut_at_gap(y, tt, i0 + j0), tt, 1.0)
            if track.endswith("+wide"):
                for ch, pt in ((0, "super_l"), (1, "super_r")):
                    tw, yw = ms.synth_lead(notes, pt, f"ls:{pid}:{j0}:wide{ch}", vel)
                    wide.place_channel(cut_at_gap(yw, tw, i0 + j0), tw, ch)
    add("lead_syn", lead)
    add("lead_wide", wide)
    add("harm_syn", harm)
    del lead, wide, harm
    # lead guitar
    di = mlib.Canvas(n, mono=True)
    for pid, j0, lines, tr, vel in GUITAR:
        for i0 in phrase_start(pid):
            if i0 + j0 >= len(bars):
                continue
            tt, y = ms.lead_guitar_di(ms.phrase(lines, i0 + j0, tr), f"ls:{pid}:{j0}")
            di.place(cut_at_gap(y, tt, i0 + j0), tt, vel)
    lg = ms.amp_sim(di.x, ms.AMP_LEAD)
    del di
    add("lead_gtr", np.stack([lg, lg], axis=1))
    log(f"  {'leads':12s} {time.time() - t1:6.1f} s")
    # fx: risers and reverse crashes into the big downbeats, impacts on them
    t1 = time.time()
    fx = mlib.Canvas(n)
    ris1, ris2, rev = ms.riser(1), ms.riser(2), ms.reverse_crash(2.0)
    for b in bars:
        if b.j != 0:
            continue
        if b.kind == "in":
            fx.place(ris1, b.t + BAR - len(ris1) / SR, 0.75)
        if (b.kind in ("B", "S") or (b.kind == "A" and b.pid == "A1")) and b.i > 1:
            fx.place(ris2, b.t - len(ris2) / SR, 0.6)
        if b.kind in ("B", "S") or (b.kind == "A" and b.pid == "A1"):
            fx.place(rev, b.t - len(rev) / SR, 0.7)
        if (b.kind == "A" and b.pid == "A1") or b.pid in ("B3", "S") or b.kind == "E":
            fx.place(ms.impact(), b.t, 0.9)
    e1 = [b for b in bars if b.kind == "E" and b.j == 1]
    if e1:
        fx.place(ms.impact(), e1[0].t, 1.0)
    add("fx", fx)
    del fx
    log(f"  {'fx':12s} {time.time() - t1:6.1f} s")
    mix = mx.finish()
    log(f"  Mischung fertig nach {time.time() - t_all:.0f} s")
    return mix, mx.levels


def info() -> dict:
    return {"bpm": BPM, "bar_s": BAR, "loop_bars": LOOP_BARS, "loop_frames": LOOP_FRAMES, "intro_frames": F_BODY,
            "intro_beats": 4 * I_BODY, "ending_frames": N_ENDING, "render_frames": N_RENDER, "render_bars": len(BARS),
            "phrases": [p[0] for p in PHRASES], "countin_s": COUNTIN_BARS * BAR}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Rennmusik 1 „Linke Spur“ rendern")
    ap.add_argument("--out", default="", help="statt ins Repository unter diesen Ordner schreiben (ohne .import)")
    ap.add_argument("--wav", default="", help="zusätzlich den ganzen Master als Float-WAV hier ablegen")
    ap.add_argument("--sketch", type=int, default=0, help="nur den Einzähler und die ersten N Takte (WAV nach --wav)")
    ap.add_argument("--info", action="store_true", help="Form und Clip-Längen zeigen, nichts rendern")
    args = ap.parse_args(argv)
    if args.info:
        print(json.dumps(info(), indent=1))
        return 0
    t_start = time.time()
    if args.wav:
        os.makedirs(args.wav, exist_ok=True)
    if args.sketch:
        nb = min(len(BARS), 1 + args.sketch)
        mix, levels = render(nb)
        m = mlib.Master()
        meas = slice(F_BODY - int(8 * BAR * SR), min(len(mix), int(nb * BAR * SR)))
        p = m.pre(mix, meas)
        y = m.fit_gain(p, meas)
        if args.wav:
            ms.write_wav(os.path.join(args.wav, f"linke_spur_skizze_{args.sketch}.wav"), y)
        print(json.dumps({"levels": levels, "master": m.info, "seconds": round(time.time() - t_start, 1)}, indent=1))
        return 0
    mix, levels = render()
    body = slice(F_BODY, F_BODY + LOOP_FRAMES)
    m = mlib.Master()
    p = m.pre(mix, body)
    del mix
    y = m.fit_gain(p, body)
    n2 = int(2 * BAR * SR)
    seam = mlib.seam_db(y[F_BODY:F_BODY + n2], y[F_BODY + LOOP_FRAMES:F_BODY + LOOP_FRAMES + n2])
    if args.wav:
        ms.write_wav(os.path.join(args.wav, "linke_spur_master.wav"), y)
    parts = {"main": (0, F_BODY + LOOP_FRAMES), "ending": (F_END, F_END + N_ENDING)}
    man = ml.Manifest("music", args.out or None)
    man.drop_generator(GENERATOR)
    rep = {"seam_diff_dbfs": seam, "levels": levels, "master": dict(m.info), "files": {}}
    state = {"y": y}
    for part in ("main", "ending"):
        a, b = parts[part]

        def reencode(lower: float, a=a, b=b) -> np.ndarray:
            m.ceiling -= lower
            state["y"] = m.fit_gain(p, body)
            return state["y"][a:b]

        rep["files"][part] = mlib.encode_checked(state["y"][a:b], man.file(FILES[part]), TITLE, reencode)
    if rep["files"]["ending"]["rounds"] > 1:        # a lowered ceiling applies to the main file as well
        a, b = parts["main"]
        rep["files"]["main"] = mlib.encode_checked(state["y"][a:b], man.file(FILES["main"]), TITLE, None)
    rep["master"] = dict(m.info)
    if not args.out:
        # loop_offset a quarter frame past the body's first frame: Godot truncates time x rate to a frame
        mlib.write_ogg_import_keep(man.file(FILES["main"]), (F_BODY + 0.25) / SR, BPM, 0, 4)
        mlib.write_ogg_import_keep(man.file(FILES["ending"]), None, BPM, 0, 4)
    e = man.add(IDS["main"], FILES["main"], "music", GENERATOR, loop=(F_BODY, F_BODY + LOOP_FRAMES), role="race",
                bus="MMusic", gain_db=0.0, bpm=BPM, bar_beats=4,
                note="Linke Spur: Einzähler (1 Takt) und A1 einmal, dann Schleife B1 … T, A1 (88 Takte); "
                     "ohne beat_count: Godot zählt Schläge vom Dateianfang, die Schleife endet am Dateiende")
    e.update({"piece": PIECE, "ending": IDS["ending"], "countin_beats": 4 * COUNTIN_BARS, "intro_bars": I_BODY,
              "loop_bars": LOOP_BARS})
    e = man.add(IDS["ending"], FILES["ending"], "music", GENERATOR, role="race_ending", bus="MMusic", gain_db=0.0,
                bpm=BPM, bar_beats=4, note="Linke Spur: Schluss (B – C – d, Schlussakkord), ab dem nächsten Taktstrich")
    e["piece"] = PIECE
    e["qc"] = {"lufs": [-20.0, -10.0]}
    man.save()
    rep["seconds"] = round(time.time() - t_start, 1)
    print(json.dumps(rep, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
