#!/usr/bin/env python3
"""Rennmusik 3 „Rückenwind“ für das Klangprofil „Modern“ (contract D30, §4.7; docs/audio-modern.md, section "Musik").

The bright one of the three race pieces: A major, 147 bpm (1 bar = 80/49 s; a sixteenth = 4500 frames exactly), uplifting synthwave rock in the brand
sound (the instruments of tools/audio/music_synth.py and the modern layers of music_lib). Against „Linke Spur“
(D minor, 132 bpm) and „Nachtfahrt“ (C minor, 108 bpm): a major key, the fastest tempo, a disco-rock beat (open
hats on the off-beats), octave-jumping eighth basses, guitar strums in the brand's 3-3-2 rhythm, a sparkling
arpeggio, the heroic lift bVI – bVII – I (F – G – A) and a soaring hook up to the high A. Form (8-bar phrases):

  count-in (1 bar, E)  A1 | B1 A2 P1 B2 D S P2 B3 A3 T A1 | …
                       groove + motif, hook, motif and answer on the lead guitar, lift, hook with harmony, breakdown
                       (bells), guitar solo, lift, hook with everything, motif in octaves, turnaround – loop 88 bars
                       = 143.67 s (6,336,000 frames)

Files (race_lib.RacePiece): rueckenwind.ogg (count-in + A1 once, then the loop body; loop_offset),
rueckenwind_schluss.ogg (F – G – A), and the extra clips rueckenwind_{ziel,schluss_rekord,schluss_finale,polizei,
tank}.ogg (the stingers borrow A minor) – one render, one master, the extras with the track gains of this render.

  python3 tools/audio/music/rueckenwind.py              render, write the files, their imports and the manifest
  python3 tools/audio/music/rueckenwind.py --out DIR    the same below DIR (no import files; QC --determinism)
  python3 tools/audio/music/rueckenwind.py --wav DIR    also keep the whole master as float WAV (previews)
  python3 tools/audio/music/rueckenwind.py --sketch N   only the count-in and the first N bars, as WAV to --wav
  python3 tools/audio/music/rueckenwind.py --info       form and clip lengths, no rendering
Deterministic; about 5-9 minutes on one core.
"""
from __future__ import annotations

import copy
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_lib as mlib  # noqa: E402
from music_lib import ms  # noqa: E402
import race_lib  # noqa: E402
from race_lib import Bar  # noqa: E402

# --- melodies (16th steps per bar, "step:len:Note[:opts]" as in music_synth.parse_line) ------------------------------
MOTIF = [                                                       # A1, bars 5-8: A E D E
    "0:2:E5 2:2:A5 4:2:C#6 6:2:B5 8:4:A5 12:4:E5",
    "0:2:E5 2:2:G#5 4:2:B5 6:2:A5 8:8:G#5",
    "0:2:D5 2:2:F#5 4:2:A5 6:2:B5 8:4:A5 12:4:F#5",
    "0:6:E5 6:2:F#5 8:4:G#5 12:4:B5",
]
MOTIF2 = [                                                      # bars 1-4: A E F#m D
    "0:2:E5 2:2:A5 4:2:C#6 6:2:B5 8:4:A5 12:4:E5",
    "0:2:E5 2:2:G#5 4:2:B5 6:2:A5 8:8:G#5",
    "0:2:C#5 2:2:F#5 4:2:A5 6:2:B5 8:4:A5 12:4:F#5",
    "0:6:D5 6:2:E5 8:4:F#5 12:4:A5",
]
ANSWER = [                                                      # bars 5-8: A E D E
    "0:2:E5 2:2:A5 4:2:C#6 6:2:E6 8:4:D6 12:4:C#6",
    "0:6:B5 6:2:C#6 8:8:G#5",
    "0:2:F#5 2:2:A5 4:2:D6 6:2:C#6 8:4:B5 12:4:A5",
    "0:8:B5:v 8:4:G#5 12:4:E5",
]
HOOK = [
    "0:3:A5 3:3:D6 6:2:F#6 8:8:E6",                              # D
    "0:3:B5 3:3:E6 6:2:G#6 8:8:F#6",                             # E
    "0:3:G#5 3:3:C#6 6:2:E6 8:6:C#6 14:2:B5",                    # C#m
    "0:12:C#6:v 12:2:B5 14:2:A5",                                # F#m
    "0:3:A5 3:3:D6 6:2:F#6 8:8:E6",                              # D
    "0:3:B5 3:3:E6 6:2:G#6 8:4:F#6 12:4:G#6",                    # E
    "0:16:A6:v",                                                 # A
    "0:8:E6 8:4:C#6 12:4:B5",                                    # E
    "0:12:A5:v",                                                 # (first bar of the next phrase)
]
HARMONY = [
    "0:3:F#5 3:3:B5 6:2:D6 8:8:C#6",
    "0:3:G#5 3:3:C#6 6:2:E6 8:8:D6",
    "0:3:E5 3:3:G#5 6:2:C#6 8:6:G#5 14:2:G#5",
    "0:12:A5:v 12:2:G#5 14:2:F#5",
    "0:3:F#5 3:3:B5 6:2:D6 8:8:C#6",
    "0:3:G#5 3:3:C#6 6:2:E6 8:4:D6 12:4:E6",
    "0:16:E6:v",
    "0:8:B5 8:4:A5 12:4:G#5",
    "0:12:E5",
]
LIFT = [
    "0:8:C6 8:4:A5 12:4:F5",                                     # F
    "0:8:D6 8:4:B5 12:4:G5",                                     # G
    "0:16:C#6",                                                  # A
    "0:8:E6 8:8:C#6",                                            # A
    "0:8:C6 8:4:A5 12:4:F5",                                     # F
    "0:8:D6 8:4:B5 12:4:G5",                                     # G
    "0:8:B5 8:8:G#5",                                            # E
    "0:8:E6 8:4:D6 12:4:B5",                                     # E
]
BELLS_D = [
    "0:6:C#6 6:6:A5 12:4:F#5", "0:6:A5 6:6:F#5 12:4:D5", "0:6:E6 6:6:C#6 12:4:A5", "0:6:B5 6:6:G#5 12:4:E5",
    "0:6:C#6 6:6:A5 12:4:F#5", "0:6:D6 6:6:A5 12:4:F#5", "0:6:B5 6:6:G#5 12:4:E5", "0:16:B5",
]
SOFT_D = ["0:16:F#5", "0:8:E5 8:8:F#5", "0:16:G#5", "0:8:B5 8:8:G#5"]
SOLO = [
    "0:4:E5:b-2 4:2:C#5 6:2:A4 8:2:C#5 10:2:E5 12:4:F#5:v",                                       # A
    "0:2:E5 2:2:B4 4:2:G#4 6:2:B4 8:8:E5:v",                                                      # E
    "0:1:C#5 1:1:E5 2:1:F#5 3:1:A5 4:1:C#6 5:1:B5 6:1:A5 7:1:F#5 8:8:A5:v",                       # F#m
    "0:6:F#5:b-2:v 6:2:E5 8:4:D5 12:4:A4",                                                        # D
    "0:8:A5:v 8:2:B5 10:2:C#6 12:2:B5 14:2:A5",                                                   # A
    "0:4:G#5 4:4:E5 8:2:G#5 10:2:A5 12:4:B5:b-2:v",                                               # E
    "0:1:D6 1:1:C#6 2:1:B5 3:1:A5 4:1:F#5 5:1:A5 6:1:B5 7:1:A5 8:1:F#5 9:1:E5 10:1:D5 11:1:E5 "
    "12:1:F#5 13:1:A5 14:1:B5 15:1:C#6",                                                          # D
    "0:6:E6:v 6:2:B5 8:4:G#5 12:4:B5:B+2",                                                        # E
]
SOFT_T = ["0:16:E5", "0:8:C#5 8:8:E5", "0:16:F#5", "0:16:A5", "0:16:C#5", "0:8:A4 8:8:C#5", "0:16:B4",
          "0:8:G#4 8:8:B4"]
END_LEAD = ["0:8:A5 8:8:B5", "0:28:C#6:v"]
END_HARM = ["0:8:F5 8:8:G5", "0:28:A5:v"]

COLOUR = {"A": "Aadd9", "D": "Dadd9", "E": "E", "F#m": "F#m7", "C#m": "C#m7", "F": "Fadd9", "G": "Gadd9"}
PAD_LEVEL = {"in": 0.6, "A": 0.75, "B": 1.0, "P": 0.95, "D": 1.0, "S": 0.7, "T": 0.9}
ARP_STYLE = {"A": (0.8, 5), "B": (0.85, 6), "P": (0.85, 5), "D": (1.0, 6), "S": (0.6, 4), "T": (0.85, 5)}
ARP_ORDER = (0, 1, 2, 3, 0, 1, 2, 3, 1, 2, 3, 0, 1, 2, 3, 2)      # rising runs – bright, forward


class Rueckenwind(race_lib.RacePiece):
    GENERATOR = "tools/audio/music/rueckenwind.py"
    PIECE = "rueckenwind"
    TITLE = "Crossing Europe - Rueckenwind"
    SEED = "rw"
    BPM = 147.0          # a sixteenth is a whole number of frames (see nachtfahrt.py)
    ROTATION = 3
    KEY = {"tonic": "A", "minor_tonic": "Am", "major_tonic": "A", "cadence": ("F", "G"), "bII": "Bb", "iv": "Dm",
           "root_hi": 69}
    COUNTIN_CHORD = "E"
    ENDING = ("F", "G", "A")
    PHRASES = [
        ("A1", "A", "A E F#m D A E D E"),
        ("B1", "B", "D E C#m F#m D E A E"),
        ("A2", "A", "A E F#m D A E D E"),
        ("P1", "P", "F G A A F G E E"),
        ("B2", "B", "D E C#m F#m D E A E"),
        ("D", "D", "F#m D A E F#m D E E"),
        ("S", "S", "A E F#m D A E D E"),
        ("P2", "P", "F G A A F G E E"),
        ("B3", "B", "D E C#m F#m D E A E"),
        ("A3", "A", "A E F#m D A E D E"),
        ("T", "T", "A A D D F#m F#m E E"),
    ]
    LEADS = [
        ("A1", 4, MOTIF, 0, "lead", 0.9, "lead_syn"),
        ("B1", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
        ("P1", 0, LIFT, 0, "lead", 0.85, "lead_syn"),
        ("B2", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
        ("B2", 4, HARMONY[4:], 0, "lead", 0.6, "harm_syn"),
        ("D", 4, SOFT_D, 0, "soft", 0.8, "lead_syn"),
        ("P2", 0, LIFT, 0, "lead", 0.88, "lead_syn"),
        ("B3", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
        ("B3", 0, HARMONY, 0, "lead", 0.6, "harm_syn"),
        ("A3", 0, MOTIF2 + ANSWER, 0, "lead", 0.9, "lead_syn"),
        ("T", 0, SOFT_T, 0, "soft", 0.75, "lead_syn"),
        ("E", 0, END_LEAD, 0, "lead", 1.0, "lead_syn+wide"),
        ("E", 0, END_HARM, 0, "lead", 0.62, "harm_syn"),
    ]
    GUITAR = [
        ("A2", 0, MOTIF2 + ANSWER, 0, 0.9),
        ("B2", 0, HOOK, -12, 0.8),
        ("S", 0, SOLO, 0, 1.0),
        ("P2", 0, LIFT, -12, 0.75),
        ("B3", 0, HOOK, -12, 0.85),
        ("A3", 0, MOTIF2 + ANSWER, -12, 0.8),
        ("E", 0, END_LEAD, -12, 0.85),
    ]
    BELLS = [("D", 0, BELLS_D, 0.75)]
    AUTOMATION = {
        "lead_gtr": {"S": 4.0, "A": 1.5},
        "guitars": {"D": -2.5, "S": -2.5, ("T", 0, 3): -1.5},
        "bass": {("D", 0, 3): -1.5},
    }

    # --- drums: disco-rock – four-on-the-floor, open hats on the off-beats ----------------------------------------
    def drum_bar(self, b: Bar) -> list:
        k, j = b.kind, b.j
        if k == "in":
            ev = [(s, "clap", 0.25 + 0.55 * s / 10) for s in range(0, 12, 2)]
            return ev + [(s, "snare", 0.5 + 0.5 * (s - 12) / 3) for s in range(12, 16)]
        if k == "gap":
            return []
        if k == "E":
            if j == 0:
                return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 0.9), (8, "kick", 1.0), (8, "snare", 1.0),
                        (8, "crash", 0.8), (12, "tom_h", 0.85), (13, "tom_h", 0.9), (14, "tom_m", 0.95), (15, "tom_f", 1.0)]
            return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 1.0)]
        if k in ("A", "B", "S"):
            ev = [(s, "kick", 1.0 if s in (0, 8) else 0.93) for s in (0, 4, 8, 12)]
            ev += [(4, "snare", 1.0), (12, "snare", 1.0)]
            ev += [(s, "hat_o", 0.55) for s in (2, 6, 10, 14)]
            ev += [(s, "hat_c", 0.3 if s % 4 == 1 else 0.22) for s in range(1, 16, 2)]
            if k != "A" or b.pid != "A1":
                ev += [(s, "shaker", 0.85 if s % 4 == 2 else 0.45) for s in range(16)]
            if k in ("B", "S"):
                ev += [(4, "clap", 0.75), (12, "clap", 0.75)]
            if j % 2 == 1:
                ev.append((15, "kick", 0.7))
            crash = (0, 2, 4, 6) if k in ("B", "S") else (0,)
            if j in crash:
                ev.append((0, "crash", 0.95 if j == 0 else 0.78))
            if j == 7:
                ev = _fill(ev, "big" if k == "S" else ("toms" if k == "B" else "small"))
            return ev
        if k == "P":
            if j == 6:
                return [(s, "snare", 0.45 + 0.5 * s / 14) for s in range(0, 16, 2)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
            if j == 7:
                return ([(s, "snare", 0.4 + 0.6 * s / 15) for s in range(16)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
                        + [(12, "tom_m", 0.7), (14, "tom_f", 0.8)])
            ev = [(0, "kick", 1.0), (8, "kick", 0.95), (4, "snare", 1.0), (12, "snare", 1.0), (4, "clap", 0.6),
                  (12, "clap", 0.6)]
            if j % 2:
                ev.append((14, "kick", 0.8))
            ev += [(s, "hat_c", 0.3) for s in range(0, 16, 2)] + [(s, "tom_f", 0.32) for s in (2, 6, 10, 14)]
            if j in (0, 2, 4):
                ev.append((0, "crash", 0.8))
            return ev
        if k == "D":
            if j < 2:
                return []
            if j < 4:
                return [(0, "kick", 0.6), (8, "kick", 0.55)] + [(s, "hat_c", 0.25) for s in range(0, 16, 2)]
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
            if j < 7:
                ev = [(s, "kick", 1.0 if s in (0, 8) else 0.93) for s in (0, 4, 8, 12)] + [(4, "snare", 1.0), (12, "snare", 1.0)]
                ev += [(s, "hat_o", 0.5) for s in (2, 6, 10, 14)]
                return ev + ([(0, "crash", 0.85)] if j == 4 else [])
            return ([(s, "snare", 0.4 + 0.6 * s / 15) for s in range(16)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
                    + [(12, "tom_h", 0.85), (13, "tom_h", 0.9), (14, "tom_m", 0.95), (15, "tom_f", 1.0)])
        raise ValueError(k)

    # --- bass: octave-jumping eighths ("disco octaves"), straight drive in the hook ---------------------------------
    def bass_cut(self, b: Bar) -> float:
        return 340.0 if b.kind in ("B", "S") else 280.0

    def bass_bar(self, b: Bar) -> list:
        r = self.CH[b.chord]["root"]
        k, j = b.kind, b.j
        eighths = range(0, 16, 2)
        if k == "gap":
            return []
        if k == "in":
            return [(0, 16, r, 0.55, "d")]
        if k == "E":
            if j == 0:
                return [(0, 7, self.CH["F"]["root"], 1.0, "ps"), (8, 7, self.CH["G"]["root"], 1.0, "ps")]
            return [(0, 40, r, 1.0, "ps")]
        if k in ("A", "S") or (k == "T" and 4 <= j < 7):
            out = [(s, 1.8, r + (12 if (s // 2) % 2 else 0), 1.0 if s % 4 == 0 else 0.85, "ps") for s in eighths]
            if j == 7 and b.nxt != b.chord:
                nr = self.CH[b.nxt]["root"]
                out[-1] = (14, 1.8, nr - 1 if nr - 1 >= 28 else nr + 11, 0.85, "ps")     # leading tone below
            return out
        if k == "B":
            out = [(s, 1.8, r, 0.95 if s % 4 == 0 else 0.84, "ps") for s in eighths]
            if j == 7:
                out[-1] = (14, 1.8, r + 12, 0.9, "ps")
            return out
        if k == "P":
            return [(s, 1.8, r, 0.92 if s % 8 == 0 else 0.8, "ps") for s in eighths]
        if k == "D":
            if j < 4:
                return [(0, 16, r, 0.5, "d")]
            return [(s, 1.8, r, 0.75, "s") for s in eighths]
        if k == "T":
            if j < 4:
                return [(0, 7.5, r, 1.0, "ps"), (8, 7.5, r, 0.9, "ps")]
            return [(s, 1.8, r, 0.9 - 0.3 * s / 15, "ps") for s in eighths]
        raise ValueError(k)

    # --- guitars: strums in the brand's 3-3-2 rhythm, a wide open wall in the hook ----------------------------------
    def gtr_bar(self, b: Bar, take: int) -> list:
        k, j = b.kind, b.j
        inner = take >= 2
        if k in ("in", "gap"):
            return []
        if k == "E":
            if j == 0:
                return [(0, 8, "open", 1.0, 1, "F"), (8, 8, "open", 1.0, 1, "G")]
            return [(0, 40, "open", 1.0, 1, "A")]
        if k == "A":
            if inner:
                return [] if b.pid == "A1" else [(s, 2, "mute", 0.6, 1) for s in range(0, 16, 2)]
            return [(0, 3, "half", 1.0, 1), (3, 3, "half", 0.9, -1), (6, 2, "half", 0.85, 1), (8, 3, "half", 0.95, 1),
                    (11, 3, "half", 0.88, -1), (14, 2, "half", 0.82, 1)]
        if k == "B":
            return [(0, 6, "open", 1.0, 1), (6, 2, "half", 0.85, -1), (8, 6, "open", 0.95, 1), (14, 2, "half", 0.85, -1)]
        if k == "P":
            if j == 6:
                return [(s, 2, "open", 0.88, 1) for s in range(0, 16, 2)]
            if j == 7:
                return [(s, 1, "mute", 0.55 + 0.45 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
            if j % 2 == 0:
                return [(0, 16, "open", 0.95, 1)]
            return [(s, 2, "half", 0.82, 1) for s in range(0, 16, 2)]
        if k == "S":
            return [(s, 2, "half", 0.84 if s % 4 == 0 else 0.76, 1) for s in range(0, 16, 2)]
        if k == "D":
            if j < 4 or inner:
                return [] if j < 7 else [(s, 1, "mute", 0.5 + 0.5 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
            if j < 7:
                return [(0, 16, "open", 0.72, 1)]
            return [(s, 1, "mute", 0.5 + 0.5 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
        if k == "T":
            if j < 4:
                return [(0, 16, "open", 0.8, 1)] if not inner else []
            if j < 7:
                return [(0, 3, "half", 0.95, 1), (3, 3, "half", 0.88, -1), (6, 2, "half", 0.82, 1),
                        (8, 3, "half", 0.92, 1), (11, 3, "half", 0.86, -1), (14, 2, "half", 0.8, 1)]
            return [(s, 1, "mute", 0.55 + 0.45 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
        raise ValueError(k)

    def pad_bar(self, b: Bar) -> list:
        bar = ms.BAR
        if b.kind == "gap":
            return []
        if b.kind == "E":
            if b.j == 0:
                return [(0, bar * 0.48, "Fadd9", 1.0), (8, bar * 0.48, "Gadd9", 1.0)]
            return [(0, bar * 1.9, "Aadd9", 1.0)]
        return [(0, bar * 0.98, COLOUR.get(b.chord, b.chord), PAD_LEVEL[b.kind])]

    def arp_bar(self, b: Bar) -> list:
        k = b.kind
        if k in ("gap", "E"):
            return []
        notes = self.CH[COLOUR.get(b.chord, b.chord)]["arp"]
        out = []
        for s in range(16):
            if k == "in":
                vel, bright = 0.35 + 0.35 * s / 15, min(7, 2 + int(s / 3))
            else:
                vel, bright = ARP_STYLE[k]
                if k == "D" and b.j < 2:
                    vel *= 0.85
            m = notes[ARP_ORDER[s]] + (12 if (k in ("B", "P") and s >= 8) else 0)
            out.append((s, int(m), vel * (1.0 if s % 4 == 0 else 0.8), bright))
        return out

    def brass_bar(self, b: Bar) -> list:
        k, j, c = b.kind, b.j, b.chord
        if k == "P":
            if j in (0, 1, 4, 5):
                return [(0, 6, 0.75, c)] if j % 2 == 0 else [(0, 3, 0.7, c), (6, 3, 0.7, c), (12, 3, 0.75, c)]
            if j == 6:
                return [(0, 4, 0.78, c), (6, 4, 0.78, c), (12, 3, 0.78, c)]
            if j == 7:
                return [(0, 6, 0.82, c)]
        if b.pid == "B3" and j in (0, 4, 6):
            return [(0, 8, 0.8, c)]
        if k == "E":
            return [(0, 6, 0.8, "F"), (8, 6, 0.8, "G")] if j == 0 else [(0, 24, 0.9, "A")]
        return []

    def fx_bar(self, b: Bar) -> list:
        if b.kind == "E" and b.j == 1:
            return [("impact", "at", 1.0)]            # the held final chord
        if b.j != 0:
            return []
        out = []
        if b.kind == "in":
            out.append(("riser1", "end", 0.75))
        big = b.kind in ("B", "S") or (b.kind == "A" and b.pid == "A1")
        if big and b.i > 1:
            out.append(("riser2", "before", 0.6))
        if big:
            out.append(("rev", "before", 0.7))
        if (b.kind == "A" and b.pid == "A1") or b.pid in ("B1", "B3", "S") or b.kind == "E":
            out.append(("impact", "at", 0.9))
        return out

    def specs(self) -> dict:
        sp = {k: copy.deepcopy(ms.MIX[k]) for k in ("kick", "snare", "clap", "toms", "hats", "crash", "bass_pick",
                                                    "bass_syn", "gtr_L", "gtr_R", "lead_gtr", "lead_syn", "harm_syn",
                                                    "pad", "arp", "brass", "bell", "fx")}
        sp["kick"]["lufs"] = -19.3
        sp["kick2"] = {"bus": "drums", "lufs": -25.0, "eq": [("hp", 36.0, 0.7), ("peak", 300.0, -4.0, 1.2),
                                                             ("peak", 4000.0, 3.0, 1.0)]}
        sp["snare"]["lufs"] = -20.5
        sp["snare2"] = {"bus": "drums", "lufs": -19.8, "eq": [("hp", 110.0, 0.7), ("peak", 200.0, 2.0, 1.2),
                                                              ("peak", 5000.0, 2.5, 0.8)], "sends": {"plate": -14.0}}
        sp["clap"]["lufs"] = -26.0
        sp["shaker"] = {"bus": "drums", "lufs": -35.0, "eq": [("hp", 4000.0, 0.7)]}
        sp["hats"]["lufs"] = -29.5
        sp["hats"]["eq"] = [("hp", 450.0, 0.7), ("lp", 17000.0, 0.7)]
        sp["crash"]["eq"] = [("hp", 400.0, 0.7), ("hs", 8000.0, -1.5), ("lp", 16500.0, 0.7)]
        sp["sub"] = {"bus": "inst", "lufs": -27.5, "eq": [("lp", 105.0, 0.7), ("hp", 28.0, 0.7)], "duck": 0.8}
        sp["bass_pick"]["eq"] = [("hp", 45.0, 0.8), ("peak", 250.0, -1.5, 1.0), ("peak", 950.0, 3.0, 1.2),
                                 ("lp", 4800.0, 0.7)]
        sp["bass_pick"].update({"duck": 0.3, "lufs": -20.5})
        sp["bass_syn"].update({"duck": 0.65, "lufs": -21.0})
        for g in ("gtr_L", "gtr_R"):
            sp[g]["duck"] = 0.12
            sp[g]["lufs"] = -21.8
            sp[g]["eq"] = [("hp", 95.0, 0.7), ("peak", 3400.0, 1.5, 1.0), ("lp", 9500.0, 0.7)]
        for g, pan in (("gtr_L2", -0.55), ("gtr_R2", 0.55)):
            sp[g] = {"bus": "inst", "lufs": -27.0, "pan": pan, "eq": [("hp", 95.0, 0.7), ("lp", 7000.0, 0.7)], "duck": 0.2}
        sp["pad"]["duck"] = 0.6
        sp["pad"]["lufs"] = -26.0
        sp["pad"]["eq"] = [("hp", 170.0, 0.7), ("peak", 400.0, -1.5, 1.0), ("lp", 5600.0, 0.8)]
        sp["arp"].update({"duck": 0.35, "lufs": -25.5})
        sp["lead_syn"]["lufs"] = -19.3
        sp["lead_wide"] = {"bus": "inst", "lufs": -23.5, "eq": [("hp", 220.0, 0.7), ("hs", 6000.0, 2.0)], "duck": 0.15,
                           "sends": {"hall": -10.0, "delay": -13.0}}
        sp["lead_gtr"]["lufs"] = -22.5
        sp["bell"]["lufs"] = -23.5
        return mlib.apply_prefs(sp)          # the shared sub and bass levels (tools/audio/music/mischung.json)


_fill = race_lib.fill


if __name__ == "__main__":
    sys.exit(Rueckenwind().main())
