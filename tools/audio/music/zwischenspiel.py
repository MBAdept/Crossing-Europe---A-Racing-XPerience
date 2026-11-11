#!/usr/bin/env python3
"""Zwischenspiel für das Klangprofil „Modern“ (contract D30; docs/audio-modern.md, section "Musik").

The calm loop of the screens between the stages (music context "race_menu", and "result" while there is no piece of
its own): E minor like the title theme, 98 bpm (1 bar = 120/49 s, a sixteenth 6750 frames), in the brand sound but quiet – pads, bells, a soft
arpeggio, a clean guitar picking chords, a round synth bass and a soft half-time beat. The title theme's hook comes
back on the soft lead (recognition), the bells play a melody of their own. Form:

  T (2 bars, Am – B: the turnaround, once) | A (8) B (8) A' (8) B' (6) T (2) | …
     A  C G D Em C G Am B   bells melody over pads, half-time beat
     B  Em C G D Em C G D   the title hook on the soft lead, arpeggio, shaker
     A' as A                the bells' melody on the soft lead an octave down, clean guitar picking
     B' as B (6 bars)       the hook with a harmony, clean guitar
  loop 32 bars = 78.37 s (3,456,000 frames); the intro is the loop's own last two bars, so the seam lies inside the music

  python3 tools/audio/music/zwischenspiel.py              render, write the file, its import and the manifest entry
  python3 tools/audio/music/zwischenspiel.py --out DIR    the same below DIR (no import file; QC --determinism)
  python3 tools/audio/music/zwischenspiel.py --wav DIR    also keep the whole master as float WAV (previews)
Deterministic; about 2-4 minutes on one core.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
import os
import sys
import time

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_lib as mlib  # noqa: E402
from music_lib import ms, ml  # noqa: E402
import race_lib  # noqa: E402
from race_lib import Bar, Timeline  # noqa: E402

GENERATOR = "tools/audio/music/zwischenspiel.py"
PIECE = "zwischenspiel"
TITLE = "Crossing Europe - Zwischenspiel"
SEED = "zw"
BPM = 98.0               # a sixteenth is a whole number of frames: the loop seam is exact
FILE = "zwischenspiel.ogg"
TAIL_S = 4.6
EXTRA_BARS = 3

PHRASES = [
    ("A", "A", "C G D Em C G Am B"),
    ("B", "B", "Em C G D Em C G D"),
    ("A2", "A", "C G D Em C G Am B"),
    ("B2", "B", "Em C G D Em C"),
    ("T", "T", "Am B"),
]
BELLS_A = [
    "0:6:E5 6:6:G5 12:4:C6", "0:12:B5 12:4:G5", "0:6:F#5 6:6:A5 12:4:D6", "0:16:B5",
    "0:6:E5 6:6:G5 12:4:C6", "0:12:D6 12:4:B5", "0:6:A5 6:6:C6 12:4:E6", "0:8:D#6 8:8:F#5",
]
SOFT_T = ["0:12:C5 12:4:E5", "0:8:D#5 8:8:F#5"]
COLOUR = {"Em": "Em9", "C": "Cmaj7", "G": "Gadd9", "D": "D", "Am": "Am7", "B": "B7"}
CLEAN_CELL = (0, 2, 3, 1, 2, 3, 1, 2)       # eighths over root, third, fifth, top


class Zwischenspiel:
    """The patterns of the interlude (the API of race_lib.render)."""

    SUB_FOLD = 45.0               # the sub layer folds into 45..94 Hz (no E at 41 Hz)

    def __init__(self):
        mlib.set_tempo(BPM)
        self.CH = race_lib.Voicings()
        hook = list(ms.HOOK)                                     # the title theme's hook (Em C G D Em C G D)
        harm = [ms.harmony_line(ln) for ln in hook]
        self.LEADS = [
            ("B", 0, hook, 0, "soft", 0.78, "lead_syn"),
            ("A2", 0, BELLS_A, -12, "soft", 0.72, "lead_syn"),
            ("B2", 0, hook[:6], 0, "soft", 0.8, "lead_syn"),
            ("B2", 0, harm[:6], 0, "soft", 0.5, "harm_syn"),
            ("T", 0, SOFT_T, 0, "soft", 0.62, "lead_syn"),
        ]
        self.GUITAR = []
        self.BELLS = [("A", 0, BELLS_A, 0.8), ("A2", 0, BELLS_A, 0.45)]
        rows = []
        for j, c in enumerate(PHRASES[-1][2].split()):              # the intro: the turnaround, key-identical to T
            rows.append(("T", "T", j, c))
        for pid, kind, chords in PHRASES:
            for j, c in enumerate(chords.split()):
                rows.append((pid, kind, j, c))
        for j, c in enumerate(PHRASES[0][2].split()[:EXTRA_BARS]):  # the loop's continuation (seam check)
            rows.append(("A", "A", j, c))
        self.tl = Timeline(rows, "C")
        self.I_BODY = 2
        self.LOOP_BARS = sum(len(p[2].split()) for p in PHRASES)
        self.LOOP_FRAMES = int(round(self.LOOP_BARS * ms.BAR * mlib.SR))
        self.F_BODY = int(math.floor(self.I_BODY * ms.BAR * mlib.SR))
        self.N_RENDER = int(round(len(self.tl) * ms.BAR * mlib.SR + TAIL_S * mlib.SR))

    # --- patterns ------------------------------------------------------------------------------------------------
    def drum_bar(self, b: Bar) -> list:
        k, j = b.kind, b.j
        hats = [(s, "hat_c", 0.3 if s % 4 == 0 else 0.2) for s in range(0, 16, 2)]
        if k == "A":
            ev = [(0, "kick", 0.75), (8, "snare", 0.4)] + hats
            if b.pid == "A2":
                ev += [(s, "shaker", 0.3 if s % 4 == 2 else 0.18) for s in range(0, 16, 2)]
            return ev
        if k == "B":
            ev = [(0, "kick", 0.8), (10, "kick", 0.6), (8, "snare", 0.5)] + hats
            ev += [(s, "shaker", 0.32 if s % 4 == 2 else 0.18) for s in range(16)]
            if j == 0:
                ev.append((0, "crash", 0.42))
            return ev
        if k == "T":
            if j == 0:
                return [(0, "kick", 0.7), (8, "snare", 0.4)] + hats
            return [(0, "kick", 0.7), (8, "snare", 0.35), (12, "tom_m", 0.45), (14, "tom_f", 0.5)] + hats[:6]
        return []

    def bass_cut(self, b: Bar) -> float:
        return 200.0

    def bass_bar(self, b: Bar) -> list:
        r = self.CH[b.chord]["root"]
        if b.kind == "A":
            return [(0, 7.5, r, 0.7, "d"), (8, 7.5, r, 0.6, "d")]
        if b.kind == "B":
            return [(0, 5.5, r, 0.8, "s"), (6, 1.8, r + 12, 0.55, "s"), (8, 7.5, r, 0.7, "s")]
        if b.kind == "T":
            return [(0, 15.0, r, 0.7, "d")]
        return []

    def gtr_bar(self, b: Bar, take: int) -> list:
        return []

    def clean_bar(self, b: Bar) -> list:
        if b.pid not in ("A2", "B2", "T"):
            return []
        notes = self.CH[COLOUR.get(b.chord, b.chord)]["arp"]
        out = []
        for i, s in enumerate(range(0, 16, 2)):
            if b.kind == "T" and s >= 12:
                break
            m = notes[CLEAN_CELL[i]]
            out.append((s, 3.5, m, 0.85 if s % 8 == 0 else 0.7, -0.3 if i % 2 else 0.3))
        return out

    def pad_bar(self, b: Bar) -> list:
        lvl = {"A": 0.85, "B": 1.0, "T": 0.9}[b.kind]
        return [(0, ms.BAR * 0.98, COLOUR.get(b.chord, b.chord), lvl)]

    def arp_bar(self, b: Bar) -> list:
        if b.kind != "B":
            return []
        notes = self.CH[COLOUR.get(b.chord, b.chord)]["arp"]
        return [(s, notes[(0, 1, 2, 3, 2, 1, 2, 3)[s // 2]], 0.5 if s % 8 == 0 else 0.4, 1) for s in range(0, 16, 2)]

    def brass_bar(self, b: Bar) -> list:
        return []

    def fx_bar(self, b: Bar) -> list:
        if b.kind == "B" and b.j == 0:
            return [("rev1", "before", 0.35)]
        return []

    def specs(self) -> dict:
        sp = {k: copy.deepcopy(ms.MIX[k]) for k in ("kick", "snare", "clap", "toms", "hats", "crash", "bass_pick",
                                                    "bass_syn", "lead_syn", "harm_syn", "pad", "arp", "bell", "fx")}
        sp["kick"]["lufs"] = -24.0
        sp["kick2"] = {"bus": "drums", "lufs": -30.5, "eq": [("hp", 36.0, 0.7), ("peak", 300.0, -4.0, 1.2),
                                                             ("lp", 3000.0, 0.7)]}
        sp["snare"]["lufs"] = -27.0
        sp["snare"]["sends"] = {"plate": -9.0}
        sp["snare2"] = {"bus": "drums", "lufs": -31.0, "eq": [("hp", 140.0, 0.7), ("lp", 7000.0, 0.7)],
                        "sends": {"plate": -10.0}}
        sp["toms"]["lufs"] = -28.0
        sp["hats"]["lufs"] = -34.0
        sp["hats"]["eq"] = [("hp", 500.0, 0.7), ("hs", 9000.0, -3.0), ("lp", 14000.0, 0.7)]
        sp["shaker"] = {"bus": "drums", "lufs": -38.0, "eq": [("hp", 4000.0, 0.7), ("lp", 12000.0, 0.7)]}
        sp["crash"]["lufs"] = -33.0
        sp["sub"] = {"bus": "inst", "lufs": -28.0, "eq": [("lp", 100.0, 0.7), ("hp", 28.0, 0.7)], "duck": 0.5}
        sp["bass_syn"].update({"duck": 0.3, "lufs": -22.5})
        sp["pad"].update({"lufs": -21.0, "duck": 0.25, "sends": {"hall": -7.0}})
        sp["pad"]["eq"] = [("hp", 140.0, 0.7), ("peak", 400.0, -1.0, 1.0), ("lp", 4200.0, 0.8)]
        sp["arp"].update({"lufs": -27.0, "duck": 0.2, "sends": {"delay": -6.0, "hall": -10.0}})
        sp["bell"].update({"lufs": -21.5, "sends": {"hall": -6.0, "delay": -9.0}})
        sp["lead_syn"].update({"lufs": -21.5, "sends": {"hall": -8.0, "delay": -10.0}})
        sp["harm_syn"].update({"lufs": -27.0, "sends": {"hall": -8.0, "delay": -12.0}})
        sp["gtr_clean"] = {"bus": "inst", "lufs": -24.0, "pan": 0.0, "chorus": 0.5,
                           "eq": [("hp", 120.0, 0.7), ("peak", 2500.0, 1.5, 1.0), ("lp", 7500.0, 0.7)],
                           "sends": {"plate": -10.0, "delay": -14.0}}
        sp["fx"]["lufs"] = -31.0
        sp["lead_wide"] = {"bus": "inst", "lufs": -40.0}
        for k in ("gtr_L", "gtr_R", "gtr_L2", "gtr_R2", "lead_gtr", "brass"):
            sp[k] = {"bus": "inst", "lufs": -40.0}
        return mlib.apply_prefs(sp)          # the shared sub and bass levels (tools/audio/music/mischung.json)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Zwischenspiel für das Klangprofil Modern rendern")
    ap.add_argument("--out", default="", help="statt ins Repository unter diesen Ordner schreiben (ohne .import)")
    ap.add_argument("--wav", default="", help="zusätzlich den ganzen Master als Float-WAV hier ablegen")
    ap.add_argument("--info", action="store_true", help="Form und Länge zeigen, nichts rendern")
    args = ap.parse_args(argv)
    z = Zwischenspiel()
    if args.info:
        print(json.dumps({"bpm": BPM, "bar_s": ms.BAR, "loop_bars": z.LOOP_BARS, "loop_frames": z.LOOP_FRAMES,
                          "intro_frames": z.F_BODY, "file_s": round((z.F_BODY + z.LOOP_FRAMES) / mlib.SR, 2),
                          "render_bars": len(z.tl)}, indent=1))
        return 0
    t_start = time.time()
    mix, levels, _fit, _u = race_lib.render(z, z.tl, z.N_RENDER, z.specs(), SEED)
    body = slice(z.F_BODY, z.F_BODY + z.LOOP_FRAMES)
    m = mlib.Master()
    p = m.pre(mix, body)
    del mix
    y = m.fit_gain(p, body)
    n2 = int(2 * ms.BAR * mlib.SR)
    seam = mlib.seam_db(y[z.F_BODY:z.F_BODY + n2], y[z.F_BODY + z.LOOP_FRAMES:z.F_BODY + z.LOOP_FRAMES + n2])
    if args.wav:
        os.makedirs(args.wav, exist_ok=True)
        ms.write_wav(os.path.join(args.wav, "zwischenspiel_master.wav"), y)
    man = ml.Manifest("music", args.out or None)
    man.drop_generator(GENERATOR)
    n_file = z.F_BODY + z.LOOP_FRAMES

    def reencode(lower: float) -> object:
        m.ceiling -= lower
        return m.fit_gain(p, body)[:n_file]

    enc = mlib.encode_checked(y[:n_file], man.file(FILE), TITLE, reencode)
    if not args.out:
        mlib.write_ogg_import_keep(man.file(FILE), (z.F_BODY + 0.25) / mlib.SR, BPM, 0, 4)
    e = man.add(PIECE, FILE, "music", GENERATOR, loop=(z.F_BODY, n_file), role="interlude", bus="MMusic",
                gain_db=mlib.prefs()["menu_music_db"], bpm=BPM, bar_beats=4,
                note="Zwischenspiel: Kehre (2 Takte) einmal, dann Schleife A B A' B' T (32 Takte = 78,4 s); Bildschirme "
                     "zwischen den Etappen")
    e.update({"piece": PIECE, "intro_bars": z.I_BODY, "loop_bars": z.LOOP_BARS, "key": "Em"})
    man.save()
    print(json.dumps({"seam_diff_dbfs": seam, "levels": levels, "master": m.info, "file": enc,
                      "seconds": round(time.time() - t_start, 1)}, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
