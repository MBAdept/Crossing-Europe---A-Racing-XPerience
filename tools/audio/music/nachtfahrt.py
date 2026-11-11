#!/usr/bin/env python3
"""Rennmusik 2 „Nachtfahrt“ für das Klangprofil „Modern“ (contract D30, §4.7; docs/audio-modern.md, section "Musik").

The dark one of the three race pieces: C minor, 108 bpm (1 bar = 20/9 s; a sixteenth = 6125 frames exactly), a night drive in the brand sound (synthwave
rock on the instruments of tools/audio/music_synth.py and the modern layers of music_lib). Where „Linke Spur“
(D minor, 132 bpm) rolls on four-on-the-floor and eighth-note basses, this one pulses: half-time drums in the verses,
a sequenced sixteenth-note synth bass with octave jumps, a hypnotic arpeggio over lush pads (minor ninths, major
sevenths), sparse dark guitars, a melancholic motif on the soft lead and a soaring hook (bVI – bIII – bVII – i).
Form (8-bar phrases):

  count-in (1 bar, G)  A1 | B1 A2 C1 B2 D S C2 B3 T A1 | …
                       groove + motif, hook, motif on the lead guitar, lift (iv – bVI – bVII – V), hook with harmony,
                       breakdown (bells over the arpeggio), guitar solo, lift, hook with everything, turnaround
                       (half-time) – loop 80 bars = 177.78 s (7,840,000 frames)

Files (race_lib.RacePiece): nachtfahrt.ogg (count-in + A1 once, then the loop body; loop_offset), nachtfahrt_schluss.ogg
(Ab – Bb – Cm), and the extra clips nachtfahrt_{ziel,schluss_rekord,schluss_finale,polizei,tank}.ogg – one render, one
master, the extras with the track gains of this render.

  python3 tools/audio/music/nachtfahrt.py              render, write the files, their imports and the manifest
  python3 tools/audio/music/nachtfahrt.py --out DIR    the same below DIR (no import files; QC --determinism)
  python3 tools/audio/music/nachtfahrt.py --wav DIR    also keep the whole master as float WAV (previews)
  python3 tools/audio/music/nachtfahrt.py --sketch N   only the count-in and the first N bars, as WAV to --wav
  python3 tools/audio/music/nachtfahrt.py --info       form and clip lengths, no rendering
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
MOTIF = [
    "0:4:G4 4:2:C5 6:2:Eb5 8:6:D5 14:2:C5",                      # Cm
    "0:6:Eb5 6:2:C5 8:8:Ab4",                                   # Ab
    "0:4:F4 4:2:Ab4 6:2:C5 8:6:Bb4 14:2:Ab4",                   # Fm
    "0:8:G4:v 8:4:B4 12:4:D5",                                  # G
]
ANSWER = [
    "0:4:G4 4:2:C5 6:2:Eb5 8:4:G5 12:4:F5",                     # Cm
    "0:6:Eb5 6:2:F5 8:8:C5",                                    # Ab
    "0:4:Ab4 4:2:C5 6:2:F5 8:4:Eb5 12:4:D5",                    # Fm
    "0:8:D5:v 8:4:B4 12:4:G4",                                  # G
]
HOOK = [
    "0:6:C6 6:2:Bb5 8:8:Ab5",                                   # Ab
    "0:6:G5 6:2:Ab5 8:6:Bb5 14:2:C6",                           # Eb
    "0:6:D6 6:2:C6 8:4:Bb5 12:4:F5",                            # Bb
    "0:12:Eb5:v 12:2:D5 14:2:Eb5",                              # Cm
    "0:6:C6 6:2:Bb5 8:8:Ab5",                                   # Ab
    "0:6:G5 6:2:Ab5 8:6:Bb5 14:2:C6",                           # Eb
    "0:6:D6 6:2:C6 8:4:Bb5 12:4:F5",                            # Bb
    "0:8:B5:v 8:4:D6 12:4:F6",                                  # G
    "0:12:G5:v",                                                # (first bar of the next phrase)
]
HARMONY = [
    "0:6:Ab5 6:2:G5 8:8:Eb5",
    "0:6:Eb5 6:2:F5 8:6:G5 14:2:Ab5",
    "0:6:Bb5 6:2:Ab5 8:4:F5 12:4:D5",
    "0:12:C5:v 12:2:B4 14:2:C5",
    "0:6:Ab5 6:2:G5 8:8:Eb5",
    "0:6:Eb5 6:2:F5 8:6:G5 14:2:Ab5",
    "0:6:Bb5 6:2:Ab5 8:4:F5 12:4:D5",
    "0:8:G5:v 8:4:B5 12:4:D6",
    "0:12:Eb5",
]
LIFT = [
    "0:8:C5 8:4:Ab4 12:4:F4",                                   # Fm
    "0:16:Ab4",                                                 # Fm
    "0:8:Eb5 8:4:C5 12:4:Ab4",                                  # Ab
    "0:16:C5",                                                  # Ab
    "0:8:F5 8:4:D5 12:4:Bb4",                                   # Bb
    "0:16:D5",                                                  # Bb
    "0:8:B4 8:8:D5",                                            # G
    "0:8:F5 8:8:G5",                                            # G7
]
BELLS_D = [
    "0:6:C6 6:6:Ab5 12:4:Eb5", "0:6:Bb5 6:6:G5 12:4:Eb5", "0:6:Ab5 6:6:F5 12:4:C5", "0:6:G5 6:6:Eb5 12:4:C5",
    "0:6:C6 6:6:Ab5 12:4:Eb5", "0:6:Bb5 6:6:G5 12:4:Eb5", "0:6:Ab5 6:6:F5 12:4:C5", "0:16:B5",
]
SOFT_D = ["0:16:Eb5", "0:8:D5 8:8:Bb4", "0:16:C5", "0:8:B4 8:8:D5"]
SOLO = [
    "0:4:G4:b-2 4:2:Eb4 6:2:C4 8:2:Eb4 10:2:F4 12:4:G4:v",                                        # Cm
    "0:2:Ab4 2:2:G4 4:2:Eb4 6:2:C4 8:8:Eb4:v",                                                    # Ab
    "0:1:Bb3 1:1:C4 2:1:Eb4 3:1:F4 4:1:G4 5:1:Bb4 6:1:C5 7:1:D5 8:8:Eb5:v",                       # Eb
    "0:6:F5:b-2:v 6:2:D5 8:4:Bb4 12:4:F4",                                                        # Bb
    "0:8:C5:v 8:2:Bb4 10:2:G4 12:2:Bb4 14:2:C5",                                                  # Cm
    "0:4:Eb5 4:4:C5 8:2:Eb5 10:2:F5 12:4:Ab5:b-2:v",                                              # Ab
    "0:1:C6 1:1:Ab5 2:1:G5 3:1:F5 4:1:Ab5 5:1:F5 6:1:Eb5 7:1:C5 8:1:F5 9:1:Eb5 10:1:C5 11:1:Ab4 "
    "12:1:C5 13:1:Ab4 14:1:G4 15:1:F4",                                                           # Fm
    "0:6:G4:v 6:2:B4 8:4:D5 12:4:F5:v",                                                           # G
]
SOFT_T = ["0:16:G4", "0:8:Eb4 8:8:G4", "0:16:Ab4", "0:16:C5", "0:16:F4", "0:8:Ab4 8:8:C5", "0:16:B4", "0:8:D5 8:8:B4"]
END_LEAD = ["0:8:C6 8:8:D6", "0:28:Eb6:v"]
END_HARM = ["0:8:Ab5 8:8:Bb5", "0:28:C6:v"]

# pads and arpeggios colour the triads of the form (lush minor ninths, major sevenths)
COLOUR = {"Cm": "Cm9", "Ab": "Abmaj7", "Eb": "Ebadd9", "Fm": "Fm7", "Bb": "Bbadd9", "G": "G"}
PAD_LEVEL = {"in": 0.6, "A": 0.9, "B": 1.0, "C": 0.95, "D": 1.0, "S": 0.75, "T": 0.95}
ARP_STYLE = {"A": (0.8, 3), "B": (0.85, 5), "C": (0.85, 4), "D": (1.0, 5), "S": (0.6, 2), "T": (0.8, 4)}
ARP_CELL = (0, 2, 3, 1)          # root, fifth, top, third – four sixteenths, over and over (hypnotic)


class Nachtfahrt(race_lib.RacePiece):
    GENERATOR = "tools/audio/music/nachtfahrt.py"
    PIECE = "nachtfahrt"
    TITLE = "Crossing Europe - Nachtfahrt"
    SEED = "nf"
    BPM = 108.0          # a sixteenth is a whole number of frames: the two passes over the loop start are
    # identical (at 112 bpm a sixteenth was 5906.25 frames, onsets on half frames rounded differently)
    ROTATION = 2
    KEY = {"tonic": "Cm", "minor_tonic": "Cm", "major_tonic": "C", "cadence": ("Ab", "Bb"), "bII": "Db", "iv": "Fm",
           "root_hi": 72}
    COUNTIN_CHORD = "G"
    ENDING = ("Ab", "Bb", "Cm")
    PHRASES = [
        ("A1", "A", "Cm Ab Fm G Cm Ab Fm G"),
        ("B1", "B", "Ab Eb Bb Cm Ab Eb Bb G"),
        ("A2", "A", "Cm Ab Fm G Cm Ab Fm G"),
        ("C1", "C", "Fm Fm Ab Ab Bb Bb G G"),
        ("B2", "B", "Ab Eb Bb Cm Ab Eb Bb G"),
        ("D", "D", "Ab Eb Fm Cm Ab Eb Fm G"),
        ("S", "S", "Cm Ab Eb Bb Cm Ab Fm G"),
        ("C2", "C", "Fm Fm Ab Ab Bb Bb G G"),
        ("B3", "B", "Ab Eb Bb Cm Ab Eb Bb G"),
        ("T", "T", "Cm Cm Ab Ab Fm Fm G G"),
    ]
    LEADS = [
        ("A1", 4, MOTIF, 0, "soft", 0.95, "lead_syn"),
        ("B1", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
        ("C1", 0, LIFT, 0, "lead", 0.82, "lead_syn"),
        ("B2", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
        ("B2", 4, HARMONY[4:], 0, "lead", 0.6, "harm_syn"),
        ("D", 4, SOFT_D, 0, "soft", 0.8, "lead_syn"),
        ("C2", 0, LIFT, 0, "lead", 0.85, "lead_syn"),
        ("B3", 0, HOOK, 0, "lead", 1.0, "lead_syn+wide"),
        ("B3", 0, HARMONY, 0, "lead", 0.6, "harm_syn"),
        ("T", 0, SOFT_T, 0, "soft", 0.75, "lead_syn"),
        ("E", 0, END_LEAD, 0, "lead", 1.0, "lead_syn+wide"),
        ("E", 0, END_HARM, 0, "lead", 0.62, "harm_syn"),
    ]
    GUITAR = [
        ("A2", 0, MOTIF + ANSWER, 0, 0.9),
        ("B2", 0, HOOK, -12, 0.8),
        ("S", 0, SOLO, 0, 1.0),
        ("C2", 0, LIFT, -12, 0.75),
        ("B3", 0, HOOK, -12, 0.85),
        ("E", 0, END_LEAD, -12, 0.85),
    ]
    BELLS = [("D", 0, BELLS_D, 0.75)]
    AUTOMATION = {
        "lead_gtr": {"S": 4.0, "A": 1.5},
        "guitars": {"A": -1.5, "D": -2.0, "S": -2.5, ("T", 0, 3): -1.5},
        "bass": {("D", 0, 3): -1.5},
        "arp": {"D": 1.5, "S": -1.0},
    }

    # --- drums: half-time in the verses, four-on-the-floor in hook and solo ---------------------------------------
    def drum_bar(self, b: Bar) -> list:
        k, j = b.kind, b.j
        if k == "in":
            ev = [(s, "hat_c", 0.15 + 0.45 * s / 11) for s in range(12)] + [(8, "snare", 0.4)]
            return ev + [(12, "tom_h", 0.7), (13, "tom_h", 0.75), (14, "tom_m", 0.85), (15, "tom_f", 0.95)]
        if k == "gap":
            return []
        if k == "E":
            if j == 0:
                return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 0.9), (8, "kick", 1.0), (8, "snare", 1.0),
                        (8, "crash", 0.8), (12, "tom_h", 0.85), (13, "tom_h", 0.9), (14, "tom_m", 0.95), (15, "tom_f", 1.0)]
            return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 1.0)]
        if k == "A":
            ev = [(0, "kick", 1.0), (10, "kick", 0.85), (8, "snare", 1.0), (8, "clap", 0.6)]
            ev += [(s, "hat_c", 0.5 if s % 2 == 0 else 0.28) for s in range(16) if s != 14] + [(14, "hat_o", 0.45)]
            if j in (3, 7):
                ev.append((6, "kick", 0.7))
            if b.pid != "A1" and j >= 4:
                ev += [(s, "shaker", 0.85 if s % 4 == 2 else 0.45) for s in range(16)]
            if j == 0:
                ev.append((0, "crash", 0.9))
            if j == 7:
                ev = _fill(ev, "toms")
            return ev
        if k in ("B", "S"):
            ev = [(s, "kick", 1.0 if s in (0, 8) else 0.93) for s in (0, 4, 8, 12)]
            ev += [(4, "snare", 1.0), (12, "snare", 1.0), (4, "clap", 0.7), (12, "clap", 0.7)]
            ev += [(s, "hat_o", 0.5) for s in (2, 6, 10, 14)]
            ev += [(s, "hat_c", 0.26) for s in range(1, 16, 2)]
            ev += [(s, "shaker", 0.9 if s % 4 == 2 else 0.5) for s in range(16)]
            crash = (0, 2, 4, 6) if (k == "S" or b.pid == "B3") else (0, 4)
            if j in crash:
                ev.append((0, "crash", 0.95 if j == 0 else 0.8))
            if j == 7:
                ev = _fill(ev, "big" if k == "S" else "toms")
            return ev
        if k == "C":
            if j == 6:
                return [(s, "snare", 0.45 + 0.5 * s / 14) for s in range(0, 16, 2)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
            if j == 7:
                return ([(s, "snare", 0.4 + 0.6 * s / 15) for s in range(16)] + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]
                        + [(12, "tom_m", 0.7), (14, "tom_f", 0.8)])
            ev = [(0, "kick", 1.0), (8, "kick", 0.95), (4, "snare", 1.0), (12, "snare", 1.0)]
            if j % 2:
                ev.append((14, "kick", 0.8))
            ev += [(s, "hat_c", 0.35) for s in range(0, 16, 2)] + [(s, "tom_f", 0.3) for s in (2, 6, 10, 14)]
            if j in (0, 4):
                ev.append((0, "crash", 0.8))
            return ev
        if k == "D":
            if j < 2:
                return [(0, "kick", 0.5)] if j == 0 else []
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
                ev = [(0, "kick", 1.0), (8, "snare", 0.9)] + [(s, "hat_c", 0.4) for s in range(0, 16, 2)]
                if j == 0:
                    ev.append((0, "crash", 0.9))
                return ev
            if j < 6:
                return ([(0, "kick", 1.0), (10, "kick", 0.85), (8, "snare", 1.0)] + [(s, "hat_c", 0.4) for s in range(0, 16, 2)
                                                                                     if s != 14] + [(14, "hat_o", 0.45)])
            if j == 6:
                return [(0, "kick", 1.0), (8, "kick", 0.9), (4, "snare", 1.0), (12, "snare", 1.0)] + [
                    (s, "hat_o", 0.45) for s in (2, 6, 10, 14)]
            return ([(0, "kick", 1.0), (4, "snare", 0.9), (8, "kick", 0.9), (12, "snare", 0.8)]
                    + [(13, "tom_h", 0.85), (14, "tom_m", 0.9), (15, "tom_f", 1.0)])
        raise ValueError(k)

    # --- bass: a sixteenth-note synth sequence in the verses, driving eighths in hook, lift and solo ----------------
    def bass_cut(self, b: Bar) -> float:
        return {"A": 230.0, "T": 230.0, "D": 210.0}.get(b.kind, 300.0)

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
                return [(0, 7, self.CH["Ab"]["root"], 1.0, "ps"), (8, 7, self.CH["Bb"]["root"], 1.0, "ps")]
            return [(0, 40, r, 1.0, "ps")]
        if k == "A" or (k == "T" and j >= 4) or (k == "D" and j in (4, 5)):
            soft = 0.75 if k == "D" else 1.0
            seq = [(s, 0.9, r + (12 if s % 4 == 2 else 0), soft * (1.0 if s % 4 == 0 else 0.72), "sx") for s in range(16)]
            if k == "A" and j == 7 and b.nxt != b.chord:
                seq[14] = (14, 0.9, r + 2, 0.8, "sx")           # a passing note into the next phrase
            return seq + [(s, 3.6, r, soft, "") for s in (0, 4, 8, 12)]     # the sub follows the quarter notes
        if k in ("B", "S"):
            return [(s, 1.8, r + (12 if (s // 2) % 2 else 0), 0.95 if s % 4 == 0 else 0.82, "ps") for s in eighths]
        if k == "C":
            return [(s, 1.8, r, 0.92 if s % 8 == 0 else 0.8, "ps") for s in eighths]
        if k == "D":
            if j < 4:
                return [(0, 16, r, 0.5, "d")]
            return [(s, 1.8, r, 0.8, "ps") for s in eighths]
        if k == "T":
            return [(0, 7.5, r, 1.0, "ps"), (8, 7.5, r, 0.9, "ps")]
        raise ValueError(k)

    # --- guitars: sparse and dark in the verses, a wall in the hook -------------------------------------------------
    def gtr_bar(self, b: Bar, take: int) -> list:
        k, j = b.kind, b.j
        inner = take >= 2
        if k in ("in", "gap"):
            return []
        if k == "E":
            if j == 0:
                return [(0, 8, "open", 1.0, 1, "Ab"), (8, 8, "open", 1.0, 1, "Bb")]
            return [(0, 40, "open", 1.0, 1, "Cm")]
        if k == "A":
            if inner:
                return []
            ev = [(0, 14, "open", 0.72, 1)] if j % 2 == 0 else []
            if b.pid != "A1" and j >= 4:
                ev = [(s, 2, "mute", 0.62 if s % 4 == 0 else 0.5, 1) for s in range(0, 16, 2)]
            return ev
        if k == "B":
            return [(0, 14, "open", 1.0, 1), (14, 2, "half", 0.8, 1)]
        if k == "C":
            if j >= 6:
                return [(s, 2, "open", 0.85, 1) for s in range(0, 16, 2)]
            return [(s, 1, "mute", 0.5 + 0.35 * (j * 16 + s) / 95, 1 if s % 2 == 0 else -1) for s in range(16)]
        if k == "S":
            return [(s, 2, "half", 0.82 if s % 4 == 0 else 0.74, 1) for s in range(0, 16, 2)]
        if k == "D":
            if j == 7 and not inner:
                return [(s, 1, "mute", 0.5 + 0.5 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
            return []
        if k == "T":
            if j < 4:
                return [(0, 16, "open", 0.75, 1)] if not inner else []
            if j < 7:
                return [(s, 2, "mute", 0.7, 1) for s in range(0, 16, 2)]
            return [(s, 1, "mute", 0.55 + 0.45 * s / 15, 1 if s % 2 == 0 else -1) for s in range(16)]
        raise ValueError(k)

    def pad_bar(self, b: Bar) -> list:
        bar = ms.BAR
        if b.kind == "gap":
            return []
        if b.kind == "E":
            if b.j == 0:
                return [(0, bar * 0.48, "Abmaj7", 1.0), (8, bar * 0.48, "Bbadd9", 1.0)]
            return [(0, bar * 1.9, "Cm9", 1.0)]
        return [(0, bar * 0.98, COLOUR.get(b.chord, b.chord), PAD_LEVEL[b.kind])]

    def arp_bar(self, b: Bar) -> list:
        k = b.kind
        if k in ("gap", "E"):
            return []
        notes = self.CH[COLOUR.get(b.chord, b.chord)]["arp"]
        out = []
        for s in range(16):
            if k == "in":
                vel, bright = 0.35 + 0.35 * s / 15, min(7, 1 + int(s / 3))
            else:
                vel, bright = ARP_STYLE[k]
                if k == "D" and b.j < 2:
                    vel *= 0.8
            m = notes[ARP_CELL[s % 4]] + (12 if (k == "B" and s % 8 >= 4) else 0)
            out.append((s, int(m), vel * (1.0 if s % 4 == 0 else 0.8), bright))
        return out

    def brass_bar(self, b: Bar) -> list:
        k, j, c = b.kind, b.j, b.chord
        if k == "C":
            if j in (0, 2, 4):
                return [(0, 6, 0.7, c)]
            if j == 6:
                return [(0, 4, 0.75, c), (6, 4, 0.75, c), (12, 3, 0.75, c)]
            if j == 7:
                return [(0, 6, 0.8, c)]
        if b.pid == "B3" and j in (0, 4):
            return [(0, 8, 0.8, c)]
        if k == "E":
            return [(0, 6, 0.8, "Ab"), (8, 6, 0.8, "Bb")] if j == 0 else [(0, 24, 0.9, "Cm")]
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
        if (b.kind == "A" and b.pid == "A1") or b.pid in ("B3", "S") or b.kind == "E":
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
        sp["snare2"] = {"bus": "drums", "lufs": -19.6, "eq": [("hp", 110.0, 0.7), ("peak", 200.0, 2.0, 1.2),
                                                              ("peak", 5000.0, 2.0, 0.8)], "sends": {"plate": -12.0}}
        sp["shaker"] = {"bus": "drums", "lufs": -36.5, "eq": [("hp", 4000.0, 0.7)]}
        sp["hats"]["lufs"] = -30.0
        sp["hats"]["eq"] = [("hp", 450.0, 0.7), ("lp", 16000.0, 0.7)]
        sp["crash"]["eq"] = [("hp", 400.0, 0.7), ("hs", 8000.0, -2.0), ("lp", 16000.0, 0.7)]
        sp["sub"] = {"bus": "inst", "lufs": -27.0, "eq": [("lp", 105.0, 0.7), ("hp", 28.0, 0.7)], "duck": 0.8}
        sp["bass_pick"]["eq"] = [("hp", 45.0, 0.8), ("peak", 250.0, -1.5, 1.0), ("peak", 950.0, 3.0, 1.2),
                                 ("lp", 4500.0, 0.7)]
        sp["bass_pick"].update({"duck": 0.3, "lufs": -21.5})
        sp["bass_syn"].update({"duck": 0.55, "lufs": -20.0})
        for g in ("gtr_L", "gtr_R"):
            sp[g]["duck"] = 0.15
            sp[g]["lufs"] = -24.0
            sp[g]["eq"] = [("hp", 90.0, 0.7), ("peak", 3400.0, 0.5, 1.0), ("lp", 8500.0, 0.7)]
        for g, pan in (("gtr_L2", -0.55), ("gtr_R2", 0.55)):
            sp[g] = {"bus": "inst", "lufs": -28.5, "pan": pan, "eq": [("hp", 95.0, 0.7), ("lp", 6500.0, 0.7)], "duck": 0.2}
        sp["pad"]["duck"] = 0.6
        sp["pad"]["lufs"] = -24.0
        sp["pad"]["eq"] = [("hp", 150.0, 0.7), ("peak", 400.0, -1.5, 1.0), ("lp", 5200.0, 0.8)]
        sp["pad"]["sends"] = {"hall": -8.0}
        sp["arp"].update({"duck": 0.45, "lufs": -24.5, "sends": {"delay": -5.0, "hall": -12.0}})
        sp["lead_syn"]["lufs"] = -19.5
        sp["lead_syn"]["sends"] = {"hall": -11.0, "delay": -10.0}
        sp["lead_wide"] = {"bus": "inst", "lufs": -24.0, "eq": [("hp", 220.0, 0.7), ("hs", 6000.0, 2.0)], "duck": 0.15,
                           "sends": {"hall": -9.0, "delay": -12.0}}
        sp["lead_gtr"]["lufs"] = -22.5
        sp["bell"]["lufs"] = -23.0
        return mlib.apply_prefs(sp)          # the shared sub and bass levels (tools/audio/music/mischung.json)


_fill = race_lib.fill


if __name__ == "__main__":
    sys.exit(Nachtfahrt().main())
