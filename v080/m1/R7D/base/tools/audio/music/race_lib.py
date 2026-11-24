"""Race pieces of the sound profile "Modern" (contract D30, §4.7.2; docs/audio-modern.md, section "Musik").

The shared machinery of the race-piece generators, in the brand sound of the title theme (synthwave rock on the
instruments of the frozen tools/audio/music_synth.py and the modern layers of music_lib):

  voicing(chord)        bass root, power chord, pad, arpeggio and brass notes of a chord name ("Cm", "Ab", "F#m",
                        "Bbsus2", "Cm9" …) – the voicing rules of linke_spur.py's chord table, for any key
  Timeline / Bar        the bars of a render (phrases, gaps, clips) and the phrase helpers
  render()              the render loop of a race piece: drums (layered), bass (picked, synth, sub), four rhythm-guitar
                        takes through the amp, pad, arpeggio, brass, bells, synth leads with their supersaw double,
                        lead guitar, fx – one track at a time into music_lib.Mixer
  RacePiece             base class of a generator (nachtfahrt.py, rueckenwind.py): composition data + patterns, the
                        main file (count-in + first phrase, then the loop body), the bar-synced ending, the extra clips,
                        Godot import settings and manifest entries – like linke_spur.py, which it grew out of
  Extras                the extra clips of every race piece (linke_spur.py's too), composed once for any key and tempo
                        and mixed with the track gains and the master of the piece's own render (music_lib.Mixer ref,
                        Master.post): so they sound like the piece and sit at its level
                          ziel            stab at the finish line (the director plays it, then the ending at the
                                          next bar line)
                          schluss_rekord  the ending with a fanfare (new record)
                          schluss_finale  the big ending of the last stage of a race (minor pieces end in major)
                          polizei         stinger "busted" (Phrygian hits, chromatic fall)
                          tank            stinger "out of fuel" (the line runs dry and sinks)

Files of a piece <p>: <p>.ogg (main: count-in + first phrase once, then the loop body; loop_offset), <p>_schluss.ogg,
<p>_schluss_rekord.ogg, <p>_schluss_finale.ogg, <p>_ziel.ogg, <p>_polizei.ogg, <p>_tank.ogg (Ogg Vorbis q5, 44.1 kHz,
true peak <= -1 dBTP after the encode). Deterministic: fixed seeds, bit-exact Vorbis – two runs write the same bytes.
"""
from __future__ import annotations

import argparse
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

SR = mlib.SR
NOTE_PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
           "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
# chord qualities: intervals above the root (the third decides minor/major; 7ths and 9ths colour pad and arpeggio)
QUALITIES = {"": (0, 4, 7), "m": (0, 3, 7), "sus2": (0, 2, 7), "sus4": (0, 5, 7), "7": (0, 4, 7, 10),
             "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11), "add9": (0, 4, 7, 14), "madd9": (0, 3, 7, 14),
             "m9": (0, 3, 7, 10, 14), "5": (0, 7)}


# ---------------------------------------------------------------------------------------------------------------------
# chords
# ---------------------------------------------------------------------------------------------------------------------

def parse_chord(name: str) -> tuple:
    """"F#m7" -> (root pitch class, intervals)."""
    root = name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]
    q = name[len(root):]
    if q not in QUALITIES:
        raise ValueError(f"Akkord {name!r}: unbekannte Art {q!r}")
    return NOTE_PC[root], QUALITIES[q]


def _in_range(pc: int, lo: int) -> int:
    """The MIDI note of a pitch class in [lo, lo + 12)."""
    return lo + (pc - lo) % 12


def voicing(name: str) -> dict:
    """Voicings of a chord after the rules of linke_spur.py's table: bass root in G1..F#2, guitar power chord with its
    root in E2..D#3, pad root in G2..F#3 with fifth, octave and the third (and colour tones) an octave up, arpeggio
    over root, third, fifth, octave from the octave above the pad root, upper triad for the brass in D4..C#5."""
    pc, iv = parse_chord(name)
    third = next((i for i in iv if i in (2, 3, 4, 5)), 7)
    colour = [i for i in iv if i in (10, 11, 14)]
    root = _in_range(pc, 31)
    g = _in_range(pc, 40)
    pr = _in_range(pc, 43)
    pad = [pr, pr + 7, pr + 12, pr + 19] if third == 7 else [pr, pr + 7, pr + 12, pr + 12 + third]
    pad += [pr + 12 + c for c in colour]
    arp = [pr + 12, pr + 12 + third, pr + 19, pr + 24]
    if colour:
        arp[3] = pr + 12 + colour[-1]          # the colour tone (7th or 9th) instead of the octave
    pcs = {(pc + i) % 12 for i in iv if i not in (10, 11, 14)}
    tri = [m for m in range(62, 74) if m % 12 in pcs]
    return {"root": root, "pow": (g, g + 7, g + 12), "pad": tuple(pad), "arp": tuple(arp), "tri": tuple(tri),
            "pc": pc, "minor": third == 3}


class Voicings(dict):
    """Chord name -> voicing, computed on first use (a piece may preset some, e.g. linke_spur.py's table)."""

    def __missing__(self, key: str) -> dict:
        v = voicing(key)
        self[key] = v
        return v


def check_tempo(bpm: float, loop_bars: int) -> None:
    """A looping piece must loop exactly – two conditions on its tempo (measured, docs/audio-modern.md "Fallen"):
    a sixteenth is a whole number of frames (else onsets on half frames round differently in the two passes over the
    loop start: -30 dBFS at 112 bpm), and the loop is a whole number of the 63-frame blocks of the frozen
    compressor's level detector (music_synth.compressor_gain: its grid starts at frame 0; else the compressor gains of
    the two passes differ by about 0.1 dB: -34 dBFS at 108 bpm). Tempi that meet both for any bar count: 100, 105, 125,
    140, 150 bpm (a sixteenth is a multiple of 63 frames)."""
    step = SR * 15.0 / bpm
    loop = loop_bars * 16 * step
    if abs(step - round(step)) > 1e-9 or int(round(loop)) % 63 != 0:
        raise SystemExit(f"{bpm:g} bpm, {loop_bars} Takte: eine Sechzehntel ist {step:g} Frames, die Schleife "
                         f"{loop:g} Frames – sie muss eine ganze Zahl von Frames und ein Vielfaches von 63 sein")


def note_name(midi: int) -> str:
    """MIDI -> the note names of music_synth.parse_line ("Eb5", "F#4")."""
    return f"{NAMES[midi % 12]}{midi // 12 - 1}"


# ---------------------------------------------------------------------------------------------------------------------
# timeline
# ---------------------------------------------------------------------------------------------------------------------

class Bar:
    __slots__ = ("i", "t", "pid", "kind", "j", "chord", "nxt", "key")


class Timeline:
    """Bars of one render: rows (pid, kind, j, chord[, key]) at 16th-step resolution (ms.BAR per bar)."""

    def __init__(self, rows: list, last_next: str):
        self.bars: list[Bar] = []
        for i, row in enumerate(rows):
            pid, kind, j, c = row[:4]
            b = Bar()
            b.i, b.t, b.pid, b.kind, b.j, b.chord = i, i * ms.BAR, pid, kind, j, c
            b.key = row[4] if len(row) > 4 else (pid, j)
            self.bars.append(b)
        for a, b in zip(self.bars, self.bars[1:]):
            a.nxt = b.chord
        if self.bars:
            self.bars[-1].nxt = last_next

    def __len__(self) -> int:
        return len(self.bars)

    def phrase_start(self, pid: str) -> list:
        return [b.i for b in self.bars if b.pid == pid and b.j == 0]

    def first(self, pid: str) -> int:
        return next(b.i for b in self.bars if b.pid == pid)

    def lines_until_gap(self, lines: list, bar0: int, n_bars: int) -> list:
        """The lines of a phrase that start before the next gap bar and inside the rendered bars."""
        k = 0
        while k < len(lines) and bar0 + k < n_bars and self.bars[bar0 + k].kind != "gap":
            k += 1
        return lines[:k]

    def cut_at_gap(self, y: np.ndarray, t0: float, bar0: int) -> np.ndarray:
        """A whole phrase rendered from bar0 on, silenced from the next gap bar on (20 ms fade). Phrases are always
        rendered complete: the frozen oscillator picks its band limit from the highest note of the whole phrase."""
        gap = next((b for b in self.bars[bar0:] if b.kind == "gap"), None)
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


PHRASE_END_FADE_S = 0.06


def phrase_end(y: np.ndarray) -> np.ndarray:
    """The last 60 ms of a synth phrase faded out. music_synth.synth_lead renders 0.6 s past the last note and cuts
    there – with the patch "soft" (release 0.16 s) its tail is still 34 dB under the phrase's peak at the cut (measured):
    a faint click in quiet passages. The fade takes it to zero (the patch "lead" is at -63 dB there anyway)."""
    m = min(len(y), int(PHRASE_END_FADE_S * SR))
    y = np.array(y)
    w = 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, m))
    y[-m:] *= w if y.ndim == 1 else w[:, None]
    return y


def auto_gain(rules: dict | None, tl: Timeline, n: int) -> np.ndarray | None:
    """Section automation (dB) of a track group: kind -> dB or (kind, first bar, last bar) -> dB; 60 ms ramps."""
    if not rules:
        return None
    pts_t, pts_v, prev = [], [], None
    for b in tl.bars:
        v = rules.get(b.kind, 0.0)
        for kk, val in rules.items():
            if isinstance(kk, tuple) and kk[0] == b.kind and kk[1] <= b.j <= kk[2]:
                v = val
        if v != prev:
            pts_t += [b.t - 0.03, b.t + 0.03]
            pts_v += [v if prev is None else prev, v]
            prev = v
    return 10.0 ** (np.interp(np.arange(n) / SR, pts_t, pts_v) / 20.0)


# ---------------------------------------------------------------------------------------------------------------------
# render loop
# ---------------------------------------------------------------------------------------------------------------------

FILLS = {
    "small": [(12, "snare", 0.7), (13, "snare", 0.75), (14, "tom_h", 0.85), (15, "tom_m", 0.9)],
    "toms": [(12, "tom_h", 0.85), (13, "tom_h", 0.8), (14, "tom_m", 0.9), (15, "tom_f", 0.95)],
    "big": [(8, "snare", 0.75), (9, "snare", 0.7), (10, "tom_h", 0.85), (11, "tom_h", 0.8), (12, "tom_m", 0.9),
            (13, "tom_m", 0.85), (14, "tom_f", 0.95), (15, "tom_f", 1.0)],
}


def fill(ev: list, kind: str) -> list:
    """A drum fill at the end of a bar: the bar's events from the fill's first step on are replaced (kicks stay)."""
    f = FILLS[kind]
    start = min(s for s, _, _ in f)
    return [e for e in ev if e[0] < start or e[1] == "kick"] + f


DRUM_GROUPS = (("kick", "kick2"), ("snare", "snare2"), ("clap",), ("toms",), ("hats",), ("shaker",), ("crash",))
TOM_PAN = {"tom_h": -0.35, "tom_m": 0.0, "tom_f": 0.35}


def render(comp, tl: Timeline, n: int, sp: dict, seed: str, ref: dict | None = None, automation: dict | None = None,
           track_group: dict | None = None, log=print) -> tuple:
    """Renders the bars of `tl` with the patterns of `comp` and mixes them (music_lib.Mixer, ref = the fit of another
    render). comp provides: CH (Voicings), drum_bar(b), bass_bar(b), gtr_bar(b, take), pad_bar(b), arp_bar(b),
    brass_bar(b), fx_bar(b), and the phrase lists LEADS, GUITAR, BELLS. Returns (mix, levels, fit, unmatched)."""
    bars = tl.bars
    STEP, BAR = ms.STEP, ms.BAR
    t_end = len(bars) * BAR
    t_all = time.time()
    track_group = track_group or {}

    def autog(name: str):
        return auto_gain((automation or {}).get(track_group.get(name, name)), tl, n)

    # drums
    ev = []
    for b in bars:
        for s, inst, vel in comp.drum_bar(b):
            r = ms.rng_of(seed + "_drum", b.key, s, inst)
            jit = {"kick": 0.0006, "shaker": 0.002}.get(inst, 0.002)
            ev.append((b.t + s * STEP + jit * r.uniform(-1.0, 1.0), inst, vel * (1.0 + 0.05 * r.uniform(-1, 1)),
                       int(r.integers(0, 4)), s))
    kick_times = [e[0] for e in ev if e[1] == "kick"]
    mx = mlib.Mixer(n, kick_times, 0.17, log, ref)

    def add(name: str, canvas) -> None:
        x = canvas.x if isinstance(canvas, mlib.Canvas) else canvas
        mx.add(name, x, sp[name], autog(name))

    t1 = time.time()
    for names in DRUM_GROUPS:
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
                cv["toms"].place(ms.tom(inst, var), t, vel ** 1.2, TOM_PAN[inst])
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
    # bass: picked + synth + sub (folded from comp.SUB_FOLD Hz up: music_lib.sub_bass)
    t1 = time.time()
    sub_fold = float(getattr(comp, "SUB_FOLD", 36.0))
    pick, syn, sub = mlib.Canvas(n), mlib.Canvas(n), mlib.Canvas(n)
    for b in bars:
        for s, ln, m, vel, layers in comp.bass_bar(b):
            r = ms.rng_of(seed + "_bass", b.key, s)
            t = b.t + s * STEP + 0.0015 * r.uniform(-1.0, 1.0)
            var = int(r.integers(0, 3))
            if "p" in layers:
                pick.place(ms.bass_pick(int(m), ln, var), t, vel)
            if "d" in layers:
                syn.place(ms.bass_syn(int(m), ln, var, 170.0, 300.0, 0.6), t, vel)
            elif "s" in layers:
                syn.place(ms.bass_syn(int(m), ln, var, comp.bass_cut(b)), t, vel)
            if "x" not in layers:
                sub.place(mlib.sub_bass(int(m), round(ln * STEP, 4), sub_fold), t, vel * (0.7 if "d" in layers else 1.0))
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
            for evg in comp.gtr_bar(b, take):
                s, ln, mode, vel, stroke = evg[:5]
                chord = evg[5] if len(evg) > 5 else b.chord
                r = ms.rng_of(seed + "_gtr", take, b.key, s)
                t = b.t + s * STEP + 0.004 * r.uniform(-1.0, 1.0) + 0.003 * take
                notes = comp.CH[chord]["pow"] if mode != "mute" else comp.CH[chord]["pow"][:2]
                di.place(ms.gtr_hit(notes, ln, mode, stroke, take, int(r.integers(0, 4))), t,
                         vel * (1.0 + 0.04 * r.uniform(-1, 1)))
        if not np.any(di.x):
            continue
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
        for s, dur, chord, lvl in comp.pad_bar(b):
            pad.place(ms.pad_chord(comp.CH[chord]["pad"], round(dur, 4), 0), b.t + s * STEP, lvl)
    add("pad", pad)
    del pad
    arp = mlib.Canvas(n)
    for b in bars:
        for s, m, vel, bright in comp.arp_bar(b):
            arp.place(ms.arp_note(int(m), int(bright), s % 2), b.t + s * STEP, vel, 0.28 if s % 2 else -0.28)
    add("arp", arp)
    del arp
    br = mlib.Canvas(n)
    for b in bars:
        for s, ln, vel, chord in comp.brass_bar(b):
            tri = comp.CH[chord]["tri"]
            br.place(ms.brass(tuple(list(tri) + [tri[0] + 12]), ln, 0), b.t + s * STEP, vel)
    add("brass", br)
    del br
    bell = mlib.Canvas(n)
    for pid, j0, lines, vel in comp.BELLS:
        for i0 in tl.phrase_start(pid):
            use = tl.lines_until_gap(lines, i0 + j0, len(bars))
            if use:
                for nt in ms.phrase(use, i0 + j0):
                    if nt["t"] < t_end:
                        bell.place(ms.bell(nt["midi"], round(nt["dur"] / STEP, 3), 0), nt["t"], vel, -0.15)
    add("bell", bell)
    del bell
    log(f"  {'keys':12s} {time.time() - t1:6.1f} s")
    # synth leads (+ the supersaw double) and harmony
    t1 = time.time()
    lead, wide, harm = mlib.Canvas(n), mlib.Canvas(n), mlib.Canvas(n)
    for pid, j0, lines, tr, patch, vel, track in comp.LEADS:
        for i0 in tl.phrase_start(pid):
            if i0 + j0 >= len(bars):
                continue
            notes = ms.phrase(lines, i0 + j0, tr)
            tt, y = ms.synth_lead(notes, patch, f"{seed}:{pid}:{j0}:{track}", vel)
            (harm if track.startswith("harm_syn") else lead).place(tl.cut_at_gap(phrase_end(y), tt, i0 + j0), tt, 1.0)
            if track.endswith("+wide"):
                for ch, pt in ((0, "super_l"), (1, "super_r")):
                    tw, yw = ms.synth_lead(notes, pt, f"{seed}:{pid}:{j0}:wide{ch}", vel)
                    wide.place_channel(tl.cut_at_gap(phrase_end(yw), tw, i0 + j0), tw, ch)
    add("lead_syn", lead)
    add("lead_wide", wide)
    add("harm_syn", harm)
    del lead, wide, harm
    di = mlib.Canvas(n, mono=True)
    for pid, j0, lines, tr, vel in comp.GUITAR:
        for i0 in tl.phrase_start(pid):
            if i0 + j0 >= len(bars):
                continue
            tt, y = ms.lead_guitar_di(ms.phrase(lines, i0 + j0, tr), f"{seed}:{pid}:{j0}")
            di.place(tl.cut_at_gap(y, tt, i0 + j0), tt, vel)
    if np.any(di.x):
        lg = ms.amp_sim(di.x, ms.AMP_LEAD)
        add("lead_gtr", np.stack([lg, lg], axis=1))
    del di
    # clean guitar (optional, comp.clean_bar): single plucked strings of the guitar model without the amp
    if hasattr(comp, "clean_bar"):
        cl = mlib.Canvas(n)
        for b in bars:
            for s, ln, m, vel, pan in comp.clean_bar(b):
                r = ms.rng_of(seed + "_clean", b.key, s, m)
                cl.place(ms.gtr_hit((int(m),), ln, "open", 1, 1, int(r.integers(0, 4))),
                         b.t + s * STEP + 0.003 * r.uniform(-1.0, 1.0), vel * (1.0 + 0.04 * r.uniform(-1, 1)), pan)
        add("gtr_clean", cl)
        del cl
    log(f"  {'leads':12s} {time.time() - t1:6.1f} s")
    # fx: risers and reverse crashes into big downbeats, impacts on them
    t1 = time.time()
    fx = mlib.Canvas(n)
    for b in bars:
        for name, where, vel in comp.fx_bar(b):
            x = {"riser1": lambda: ms.riser(1), "riser2": lambda: ms.riser(2), "rev": lambda: ms.reverse_crash(2.0),
                 "rev1": lambda: ms.reverse_crash(1.0), "impact": ms.impact}[name]()
            t = {"at": b.t, "before": b.t - len(x) / SR, "end": b.t + BAR - len(x) / SR}[where]
            fx.place(x, t, vel)
    add("fx", fx)
    del fx
    log(f"  {'fx':12s} {time.time() - t1:6.1f} s")
    mix = mx.finish()
    log(f"  Mischung fertig nach {time.time() - t_all:.0f} s")
    return mix, mx.levels, mx.fit, mx.unmatched


# ---------------------------------------------------------------------------------------------------------------------
# extra clips of a race piece (any key and tempo)
# ---------------------------------------------------------------------------------------------------------------------

EXTRA_GAP_BARS = 4        # silence between two clips in the extras render (every reverb tail has died away)
EXTRA_TAIL_S = 4.6        # a clip is cut this long after its last bar (the hall reverb is 4.6 s)
# clip id -> (manifest suffix, bars, role, extra manifest fields)
EXTRA_CLIPS = [
    ("Z", "ziel", 1, "race_ziel", {}),
    ("R", "schluss_rekord", 3, "race_ending", {"variant": "rekord"}),
    ("F", "schluss_finale", 4, "race_ending", {"variant": "finale"}),
    ("P", "polizei", 3, "race_stinger", {"event": "busted"}),
    ("T", "tank", 2, "race_stinger", {"event": "out_of_fuel"}),
]


def _deg(root_hi: int, minor: bool) -> dict:
    """Scale degrees (MIDI) above the high root: r, 2, 3 (minor or major), 4, 5, 6, 7 and the octave."""
    third = 3 if minor else 4
    return {"r": root_hi, "2": root_hi + 2, "3": root_hi + third, "4": root_hi + 5, "5": root_hi + 7,
            "b6": root_hi + 8, "6": root_hi + 9, "b7": root_hi + 10, "8": root_hi + 12}


class Extras:
    """The extra clips of a race piece, composed for its key (KEY of the host) and played by its own instruments.
    host.KEY: {"tonic": "Dm", "minor_tonic": "Dm", "major_tonic": "D", "cadence": ("Bb", "C"), "bII": "Eb",
    "iv": "Gm", "root_hi": 74}."""

    def __init__(self, host):
        k = host.KEY
        self.host = host
        self.CH = host.CH
        self.SUB_FOLD = float(getattr(host, "SUB_FOLD", 36.0))      # the sub of the extras as in the piece
        self.T = k["tonic"]
        self.Tm = k.get("minor_tonic", k["tonic"])
        self.TM = k.get("major_tonic", k["tonic"])
        self.c1, self.c2 = k["cadence"]
        self.bII = k["bII"]
        self.iv = k["iv"]
        r = int(k["root_hi"])
        self.r = r
        self.minor = 3 in parse_chord(self.T)[1]
        self.d = _deg(r, self.minor)          # the scale of the piece's own tonic
        self.dm = _deg(r, True)               # minor (stingers)
        self.dM = _deg(r, False)              # major (finale)
        self.LEADS, self.GUITAR, self.BELLS = self._phrases()

    # --- the timeline: two empty bars, then each clip followed by EXTRA_GAP_BARS empty bars ----------------------
    def timeline(self) -> Timeline:
        rows = [("gap", "gap", j, self.T) for j in range(2)]
        for cid, _suffix, nb, _role, _f in EXTRA_CLIPS:
            for j in range(nb):
                rows.append((cid, cid, j, self._chord(cid, j)))
            rows += [("gap", "gap", j, self.T) for j in range(EXTRA_GAP_BARS)]
        return Timeline(rows, self.T)

    def _chord(self, cid: str, j: int) -> str:
        return {"Z": [self.T], "R": [self.c1, self.T, self.T], "F": [self.c1, self.c1, self.TM, self.TM],
                "P": [self.Tm, self.iv, self.Tm], "T": [self.iv, self.Tm]}[cid][j]

    def clips(self, tl: Timeline) -> list:
        """[(cid, suffix, role, fields, first frame, frames)] – each clip from its first downbeat to EXTRA_TAIL_S after
        its last bar."""
        out = []
        for cid, suffix, nb, role, fields in EXTRA_CLIPS:
            i0 = tl.first(cid)
            a = int(math.floor(i0 * ms.BAR * SR))
            n = int(round(nb * ms.BAR * SR + EXTRA_TAIL_S * SR))
            out.append((cid, suffix, role, fields, a, n))
        return out

    def n_frames(self, tl: Timeline) -> int:
        return int(round(len(tl) * ms.BAR * SR + 1.0 * SR))

    # --- melodic lines (16th steps per bar) --------------------------------------------------------------------------
    def _phrases(self) -> tuple:
        d, dm, dM = self.d, self.dm, self.dM
        N = note_name
        v1 = self.CH[self.c1]["tri"]
        v2 = self.CH[self.c2]["tri"]
        # a tone of each cadence chord near the high root (the top of the upper triad, an octave up when low)
        t1 = max(v1) + (12 if max(v1) < self.r - 2 else 0)
        t2 = max(v2) + (12 if max(v2) < self.r - 2 else 0)
        if t2 <= t1:
            t2 += 12 if t2 + 12 - t1 <= 7 else 0
        lead = []
        harm = []
        gtr = []
        bells = []
        # Z – the stab: a quick fifth-to-octave flick, harmony on the third and fifth
        lead.append(("Z", 0, [f"0:2:{N(d['5'] - 12)} 2:6:{N(d['r'])}:v"], 0, "lead", 1.0, "lead_syn+wide"))
        harm.append(("Z", 0, [f"0:2:{N(d['3'] - 12)} 2:6:{N(d['5'] - 12)}"], 0, "lead", 0.6, "harm_syn"))
        # R – the ending with a fanfare: cadence tones, then the 3-3-2 rise of the brand up the tonic triad
        rise = f"0:3:{N(d['5'] - 12)} 3:3:{N(d['r'])} 6:2:{N(d['3'])} 8:3:{N(d['5'])} 11:3:{N(d['8'])} 14:2:{N(d['3'] + 12)}"
        lead.append(("R", 0, [f"0:8:{N(t1)} 8:8:{N(t2)}", rise, f"0:16:{N(d['8'])}:v"], 0, "lead", 1.0, "lead_syn+wide"))
        harm.append(("R", 0, [f"0:8:{N(t1 - 4)} 8:8:{N(t2 - 3)}", f"0:8:{N(d['3'])} 8:8:{N(d['5'])}",
                              f"0:16:{N(d['5'])}:v"], 0, "lead", 0.6, "harm_syn"))
        gtr.append(("R", 1, [rise, f"0:16:{N(d['8'])}:v"], -12, 0.85))
        bells.append(("R", 2, [f"0:2:{N(d['r'])} 2:2:{N(d['3'])} 4:2:{N(d['5'])} 6:2:{N(d['8'])} "
                               f"8:2:{N(d['3'] + 12)} 10:6:{N(d['5'] + 12)}"], 0.7))
        # F – the finale: the cadence twice (the second time higher), then the major tonic with the fanfare on its third
        lead.append(("F", 0, [f"0:8:{N(t1)} 8:8:{N(t2)}", f"0:8:{N(t1 + 12 if t1 + 12 <= 91 else t1)} "
                                                          f"8:8:{N(t2 + 12 if t2 + 12 <= 93 else t2)}",
                              f"0:3:{N(dM['5'] - 12)} 3:3:{N(dM['r'])} 6:2:{N(dM['3'])} 8:3:{N(dM['5'])} "
                              f"11:3:{N(dM['8'])} 14:2:{N(dM['3'] + 12)}",
                              f"0:16:{N(dM['3'] + 12)}:v"], 0, "lead", 1.0, "lead_syn+wide"))
        harm.append(("F", 0, [f"0:8:{N(t1 - 4)} 8:8:{N(t2 - 3)}", f"0:8:{N(t1 - 4)} 8:8:{N(t2 - 3)}",
                              f"0:8:{N(dM['3'])} 8:8:{N(dM['5'])}", f"0:16:{N(dM['8'])}:v"], 0, "lead", 0.62, "harm_syn"))
        gtr.append(("F", 2, [f"0:3:{N(dM['5'] - 12)} 3:3:{N(dM['r'])} 6:2:{N(dM['3'])} 8:3:{N(dM['5'])} "
                             f"11:3:{N(dM['8'])} 14:2:{N(dM['3'] + 12)}", f"0:16:{N(dM['8'])}:v"], -12, 0.9))
        bells.append(("F", 2, [f"0:2:{N(dM['r'] - 12)} 2:2:{N(dM['3'] - 12)} 4:2:{N(dM['5'] - 12)} 6:2:{N(dM['r'])} "
                               f"8:2:{N(dM['3'])} 10:2:{N(dM['5'])} 12:4:{N(dM['8'])}",
                               f"0:16:{N(dM['5'])}"], 0.65))
        # P – busted: silence over the hits, then the blues fall 5 – b5 – 4 – b3 to the root (bar 1; in the minor key –
        # a major third here would be out of key)
        fall = f"0:4:{N(dm['5'])} 4:4:{N(dm['5'] - 1)} 8:4:{N(dm['4'])} 12:4:{N(dm['3'])}"
        lead.append(("P", 1, [fall, f"0:8:{N(dm['r'])}"], 0, "lead", 0.85, "lead_syn"))
        gtr.append(("P", 1, [fall, f"0:8:{N(dm['r'])}:v"], -12, 0.7))
        # T – out of fuel: the line runs dry – a slow chromatic sigh, then the root sinks by an octave
        sigh = [f"0:4:{N(dm['5'])}:l 4:4:{N(dm['5'] - 1)}:l 8:4:{N(dm['4'])}:l 12:4:{N(dm['3'])}:l",
                f"0:16:{N(dm['r'])}:B-12"]
        lead.append(("T", 0, sigh, 0, "soft", 1.0, "lead_syn"))
        harm.append(("T", 0, sigh, -12, "soft", 0.75, "harm_syn"))
        return lead + harm, gtr, bells

    # --- patterns ----------------------------------------------------------------------------------------------------
    def drum_bar(self, b: Bar) -> list:
        k, j = b.kind, b.j
        if k == "gap":
            return []
        if k == "Z":
            return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 0.9), (0, "clap", 0.8)]
        if k in ("R", "F") and j == 0:
            return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 0.9), (8, "kick", 1.0), (8, "snare", 1.0),
                    (8, "crash", 0.8), (12, "tom_h", 0.85), (13, "tom_h", 0.9), (14, "tom_m", 0.95), (15, "tom_f", 1.0)]
        if k == "F" and j == 1:
            return ([(0, "kick", 1.0), (0, "crash", 0.9), (0, "snare", 0.9), (8, "kick", 1.0), (8, "snare", 0.95)]
                    + [(s, "snare", 0.5 + 0.5 * (s - 9) / 6) for s in range(9, 16)] + [(14, "tom_m", 0.9), (15, "tom_f", 1.0)])
        if (k == "R" and j == 1) or (k == "F" and j == 2):
            return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 1.0), (0, "clap", 0.8)]
        if (k == "R" and j == 2) or (k == "F" and j == 3):
            return [(0, "kick", 0.9), (0, "crash", 0.85)]
        if k == "P":
            if j == 0:
                return [(0, "kick", 1.0), (0, "snare", 0.9), (0, "tom_f", 0.9), (6, "kick", 0.95), (6, "snare", 0.85),
                        (12, "kick", 1.0), (12, "snare", 0.9), (14, "tom_m", 0.8), (15, "tom_f", 0.9)]
            if j == 1:
                return [(0, "tom_f", 0.7), (4, "tom_f", 0.55), (8, "tom_f", 0.7), (12, "tom_m", 0.6), (14, "tom_f", 0.8),
                        (15, "tom_f", 0.9)]
            return [(0, "kick", 1.0), (0, "snare", 0.85), (0, "tom_f", 1.0)]
        if k == "T":
            if j == 0:
                return [(0, "kick", 0.7)]
            return [(8, "kick", 0.6), (8, "tom_f", 0.75)]
        return []

    def bass_cut(self, b: Bar) -> float:
        return 250.0

    def bass_bar(self, b: Bar) -> list:
        k, j = b.kind, b.j
        CH = self.CH
        if k == "gap":
            return []
        if k == "Z":
            return [(0, 6, CH[self.T]["root"], 1.0, "ps")]
        if k in ("R", "F") and j == 0:
            return [(0, 7, CH[self.c1]["root"], 1.0, "ps"), (8, 7, CH[self.c2]["root"], 1.0, "ps")]
        if k == "F" and j == 1:
            return [(0, 7, CH[self.c1]["root"], 1.0, "ps"), (8, 7, CH[self.c2]["root"], 1.0, "ps")]
        if k == "R" and j == 1:
            return [(0, 40, CH[self.T]["root"], 1.0, "ps")]
        if k == "F" and j == 2:
            return [(0, 44, CH[self.TM]["root"], 1.0, "ps")]
        if k == "P":
            if j == 0:
                return [(0, 4, CH[self.Tm]["root"], 1.0, "ps"), (6, 4, CH[self.bII]["root"], 1.0, "ps"),
                        (12, 4, CH[self.Tm]["root"], 1.0, "ps")]
            if j == 1:
                return [(0, 16, CH[self.iv]["root"], 0.6, "d")]
            return [(0, 6, CH[self.Tm]["root"], 1.0, "ps")]
        if k == "T":
            if j == 0:
                return [(0, 16, CH[self.iv]["root"], 0.85, "d")]
            return [(0, 14, CH[self.Tm]["root"], 0.85, "d")]
        return []

    def gtr_bar(self, b: Bar, take: int) -> list:
        k, j = b.kind, b.j
        if k == "gap":
            return []
        if k == "Z":
            return [(0, 8, "open", 1.0, 1, self.T)]
        if k in ("R", "F") and j in (0, 1):
            if k == "R" and j == 1:
                return [(0, 40, "open", 1.0, 1, self.T)]
            return [(0, 8, "open", 1.0, 1, self.c1), (8, 8, "open", 1.0, 1, self.c2)]
        if k == "F" and j == 2:
            return [(0, 44, "open", 1.0, 1, self.TM)]
        if k == "P":
            if j == 0:
                return [(0, 4, "open", 1.0, 1, self.Tm), (6, 4, "open", 0.95, 1, self.bII),
                        (12, 3, "half", 0.9, 1, self.Tm)]
            if j == 1:
                return [(s, 1, "mute", 0.45 + 0.3 * s / 15, 1 if s % 2 == 0 else -1, self.iv) for s in range(0, 16, 2)] \
                    if take < 2 else []
            return [(0, 6, "open", 1.0, 1, self.Tm)]
        if k == "T":
            if j == 0:
                return [(0, 20, "open", 0.95 if take < 2 else 0.8, 1, self.iv)]
            return []
        return []

    def pad_bar(self, b: Bar) -> list:
        k, j = b.kind, b.j
        bar = ms.BAR
        if k == "gap":
            return []
        if k == "Z":
            return [(0, bar * 0.45, self.T, 0.8)]
        if k in ("R", "F") and j in (0, 1) and not (k == "R" and j == 1):
            return [(0, bar * 0.48, self.c1, 1.0), (8, bar * 0.48, self.c2, 1.0)]
        if k == "R" and j == 1:
            return [(0, bar * 1.9, self.T, 1.0)]
        if k == "F" and j == 2:
            return [(0, bar * 1.95, self.TM, 1.0)]
        if k == "P":
            if j == 1:
                return [(0, bar * 0.98, self.iv, 0.8)]
            return []
        if k == "T":
            return [(0, bar * 0.98, b.chord, 1.0)]
        return []

    def arp_bar(self, b: Bar) -> list:
        if b.kind != "T":
            return []
        notes = self.CH[b.chord]["arp"]
        # the arpeggio runs out of breath: ever longer gaps, ever darker
        if b.j == 0:
            steps = [0, 2, 4, 6, 9, 12]
        else:
            steps = [0, 5]
        out = []
        order = (3, 2, 1, 0, 2, 1, 0, 0)
        for i, s in enumerate(steps):
            vel = 0.95 * (1.0 - 0.09 * (i + 6 * b.j))
            bright = max(0, 4 - i // 2 - 3 * b.j)
            out.append((s, notes[order[i % len(order)]], max(vel, 0.25), bright))
        return out

    def brass_bar(self, b: Bar) -> list:
        k, j = b.kind, b.j
        if k == "Z":
            return [(0, 6, 0.85, self.T)]
        if k in ("R", "F") and j == 0:
            return [(0, 6, 0.8, self.c1), (8, 6, 0.8, self.c2)]
        if k == "F" and j == 1:
            return [(0, 6, 0.9, self.c1), (8, 6, 0.9, self.c2)]
        if k == "R" and j == 1:
            return [(0, 24, 0.9, self.T)]
        if k == "F" and j == 2:
            return [(0, 28, 1.0, self.TM)]
        if k == "P" and j == 0:
            return [(0, 4, 0.9, self.Tm), (6, 4, 0.9, self.bII), (12, 3, 0.85, self.Tm)]
        if k == "P" and j == 2:
            return [(0, 5, 0.9, self.Tm)]
        return []

    def fx_bar(self, b: Bar) -> list:
        k, j = b.kind, b.j
        if k == "Z" or (k in ("R", "F") and j == 0):
            return [("impact", "at", 0.9)]
        if (k == "R" and j == 1) or (k == "F" and j == 2):
            return [("impact", "at", 1.0)]
        if k == "P" and j in (0, 2):
            return [("impact", "at", 0.85)]
        return []


class ExtrasHost:
    """What Extras and write_extras need of a piece: PIECE, TITLE, GENERATOR, SEED, KEY, CH (Voicings) and specs()."""

    def __init__(self, piece: str, title: str, generator: str, seed: str, key: dict, ch: dict, specs):
        self.PIECE = piece
        self.TITLE = title
        self.GENERATOR = generator
        self.SEED = seed
        self.KEY = key
        self.CH = Voicings(ch)
        self.specs = specs


def extra_ids(piece: str) -> dict:
    return {suffix: f"{piece}_{suffix}" for _c, suffix, _n, _r, _f in EXTRA_CLIPS}


def write_extras(host, fit: dict, master: mlib.Master, man: ml.Manifest, gain_db: float, bpm: float,
                 log=print) -> dict:
    """Renders the extra clips of a piece with the track gains of its render (`fit`) and its master, writes them (Ogg,
    measured after the encode; a clip whose true peak is too high gets a lower limiter ceiling of its own) and
    registers them in the manifest. Returns the report."""
    t0 = time.time()
    ex = Extras(host)
    tl = ex.timeline()
    n = ex.n_frames(tl)
    mix, levels, _fit, unmatched = render(ex, tl, n, host.specs(), host.SEED + "x", ref=fit, log=log)
    p = master.pre(mix)
    del mix
    rep = {"levels": levels, "unmatched": unmatched, "files": {}}
    ids = extra_ids(host.PIECE)
    for cid, suffix, role, fields, a, nf in ex.clips(tl):
        clip_p = p[a:a + nf]
        name = f"{ids[suffix]}.ogg"
        state = {"ceiling": master.ceiling}

        def reencode(lower: float, clip_p=clip_p, state=state) -> np.ndarray:
            state["ceiling"] -= lower
            return _fade_end(master.post_at(clip_p, state["ceiling"]))

        y = _fade_end(master.post(clip_p))
        info = mlib.encode_checked(y, man.file(name), host.TITLE, reencode, log)
        info["ceiling_dbtp"] = round(state["ceiling"], 2)
        rep["files"][suffix] = info
        e = man.add(ids[suffix], name, "music", host.GENERATOR, role=role, bus="MMusic", gain_db=gain_db, bpm=bpm,
                    bar_beats=4, note=EXTRA_NOTES[suffix])
        e["piece"] = host.PIECE
        e.update(fields)
        e["bars"] = next(nb for c, s, nb, _r, _f in EXTRA_CLIPS if s == suffix)
        e["qc"] = {"lufs": [-30.0, -10.0]}
    rep["seconds"] = round(time.time() - t0, 1)
    return rep


EXTRA_NOTES = {
    "ziel": "Schlag an der Ziellinie, in der Tonart des Stücks (danach der Schluss am nächsten Taktstrich)",
    "schluss_rekord": "Schluss mit Fanfare (neuer Rekord), ab dem nächsten Taktstrich",
    "schluss_finale": "großer Schluss der letzten Etappe eines Rennens (Moll-Stücke enden in Dur)",
    "polizei": "Stinger „Erwischt“ (Polizei), auf dem nächsten Schlag über der abgesenkten Musik",
    "tank": "Stinger „Tank leer“, auf dem nächsten Schlag über der abgesenkten Musik",
}


def _fade_end(y: np.ndarray, sec: float = 0.08) -> np.ndarray:
    """A short fade at the cut end of a clip (the reverb tail is far below -60 dB there)."""
    y = np.array(y)
    m = int(sec * SR)
    w = 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, m))
    y[-m:] *= w[:, None]
    return y


# ---------------------------------------------------------------------------------------------------------------------
# base class of a race-piece generator
# ---------------------------------------------------------------------------------------------------------------------

class RacePiece:
    """A race piece: count-in (COUNTIN_BARS, chord COUNTIN_CHORD), the phrases (PHRASES: id, kind, chords – the first one
    is played after the count-in and again at the end of the loop body), a bar-synced ending (ENDING_BARS) and the
    extra clips. Subclasses set the composition and override the patterns (*_bar)."""

    GENERATOR = ""
    PIECE = ""
    TITLE = ""
    SEED = ""
    BPM = 120.0
    ROTATION = 9
    SUB_FOLD = 45.0               # the sub layer folds into 45..94 Hz (linke_spur.py and the title: 36..75 Hz)
    KEY: dict = {}
    COUNTIN_BARS = 1
    COUNTIN_CHORD = ""
    ENDING = ("", "", "")         # chords of the ending: first half of bar 1, second half, the held final chord
    ENDING_BARS = 2
    GAP_BARS = 3
    EXTRA_BARS = 3
    TAIL_S = 4.2
    PHRASES: list = []
    LEADS: list = []
    GUITAR: list = []
    BELLS: list = []
    AUTOMATION: dict = {}
    TRACK_GROUP = {"kick": "drums", "kick2": "drums", "snare": "drums", "snare2": "drums", "clap": "drums",
                   "toms": "drums", "hats": "drums", "shaker": "drums", "crash": "drums", "bass_pick": "bass",
                   "bass_syn": "bass", "sub": "bass", "gtr_L": "guitars", "gtr_R": "guitars", "gtr_L2": "guitars",
                   "gtr_R2": "guitars", "lead_gtr": "lead_gtr", "pad": "pad", "arp": "arp", "lead_syn": "leads",
                   "lead_wide": "leads", "harm_syn": "leads"}

    def __init__(self):
        mlib.set_tempo(self.BPM)
        self.CH = Voicings()
        self.tl = self.timeline()
        self.I_BODY = self.COUNTIN_BARS + 8
        self.LOOP_BARS = 8 * (len(self.PHRASES) - 1) + 8
        check_tempo(self.BPM, self.LOOP_BARS)
        self.LOOP_FRAMES = int(round(self.LOOP_BARS * ms.BAR * SR))
        self.I_END = len(self.tl) - self.ENDING_BARS
        self.N_RENDER = int(round(len(self.tl) * ms.BAR * SR + self.TAIL_S * SR))
        self.F_BODY = int(math.floor(self.I_BODY * ms.BAR * SR))
        self.F_END = int(math.floor(self.I_END * ms.BAR * SR))
        self.N_ENDING = int(round(self.ENDING_BARS * ms.BAR * SR + self.TAIL_S * SR))

    # --- timeline: count-in, the phrases, the first phrase again, its continuation (seam check), a gap, the ending ---
    def timeline(self) -> Timeline:
        rows = [("in", "in", j, self.COUNTIN_CHORD) for j in range(self.COUNTIN_BARS)]
        for pid, kind, chords in [self.PHRASES[0]] + self.PHRASES[1:] + [self.PHRASES[0]]:
            for j, c in enumerate(chords.split()):
                rows.append((pid, kind, j, c))
        p1 = self.PHRASES[1]
        for j in range(self.EXTRA_BARS):
            rows.append((p1[0], p1[1], j, p1[2].split()[j]))
        rows += [("gap", "gap", j, self.KEY["tonic"]) for j in range(self.GAP_BARS)]
        e1, e2, e3 = self.ENDING
        rows.append(("E", "E", 0, e1))
        rows.append(("E", "E", 1, e3))
        return Timeline(rows, self.KEY["tonic"])

    def fx_names(self) -> dict:
        return {}

    # --- default patterns (linke_spur.py's) – a subclass overrides them -----------------------------------------
    def bass_cut(self, b: Bar) -> float:
        return 300.0 if b.kind in ("B", "S") else 250.0

    def drum_bar(self, b: Bar) -> list:
        raise NotImplementedError

    def bass_bar(self, b: Bar) -> list:
        raise NotImplementedError

    def gtr_bar(self, b: Bar, take: int) -> list:
        raise NotImplementedError

    def pad_bar(self, b: Bar) -> list:
        raise NotImplementedError

    def arp_bar(self, b: Bar) -> list:
        raise NotImplementedError

    def brass_bar(self, b: Bar) -> list:
        raise NotImplementedError

    def fx_bar(self, b: Bar) -> list:
        raise NotImplementedError

    def specs(self) -> dict:
        raise NotImplementedError

    # --- files ---------------------------------------------------------------------------------------------------
    @property
    def files(self) -> dict:
        return {"main": f"{self.PIECE}.ogg", "ending": f"{self.PIECE}_schluss.ogg"}

    @property
    def ids(self) -> dict:
        return {"main": self.PIECE, "ending": f"{self.PIECE}_schluss"}

    def info(self) -> dict:
        return {"piece": self.PIECE, "bpm": self.BPM, "bar_s": ms.BAR, "loop_bars": self.LOOP_BARS,
                "loop_frames": self.LOOP_FRAMES, "loop_s": round(self.LOOP_FRAMES / SR, 2),
                "intro_frames": self.F_BODY, "intro_s": round(self.F_BODY / SR, 2),
                "first_pass_s": round((self.F_BODY + self.LOOP_FRAMES) / SR, 1), "ending_frames": self.N_ENDING,
                "render_frames": self.N_RENDER, "render_bars": len(self.tl), "phrases": [p[0] for p in self.PHRASES],
                "countin_s": self.COUNTIN_BARS * ms.BAR, "key": self.KEY.get("tonic")}

    def render(self, n_bars: int | None = None, log=print) -> tuple:
        tl = self.tl if n_bars is None else Timeline([(b.pid, b.kind, b.j, b.chord, b.key)
                                                      for b in self.tl.bars[:n_bars]], self.KEY["tonic"])
        n = self.N_RENDER if n_bars is None else int(round((n_bars * ms.BAR + 3.0) * SR))
        return render(self, tl, n, self.specs(), self.SEED, None, self.AUTOMATION, self.TRACK_GROUP, log)

    def main(self, argv=None) -> int:
        ap = argparse.ArgumentParser(description=f"Rennmusik „{self.TITLE}“ rendern")
        ap.add_argument("--out", default="", help="statt ins Repository unter diesen Ordner schreiben (ohne .import)")
        ap.add_argument("--wav", default="", help="zusätzlich den ganzen Master als Float-WAV hier ablegen")
        ap.add_argument("--sketch", type=int, default=0, help="nur den Einzähler und die ersten N Takte (WAV nach --wav)")
        ap.add_argument("--info", action="store_true", help="Form und Clip-Längen zeigen, nichts rendern")
        args = ap.parse_args(argv)
        if args.info:
            print(json.dumps(self.info(), indent=1))
            return 0
        t_start = time.time()
        if args.wav:
            os.makedirs(args.wav, exist_ok=True)
        if args.sketch:
            nb = min(len(self.tl), self.COUNTIN_BARS + args.sketch)
            mix, levels, _fit, _u = self.render(nb)
            m = mlib.Master()
            meas = slice(max(0, self.F_BODY - int(8 * ms.BAR * SR)), min(len(mix), int(nb * ms.BAR * SR)))
            p = m.pre(mix, meas)
            y = m.fit_gain(p, meas)
            if args.wav:
                ms.write_wav(os.path.join(args.wav, f"{self.PIECE}_skizze_{args.sketch}.wav"), y)
            print(json.dumps({"levels": levels, "master": m.info, "seconds": round(time.time() - t_start, 1)}, indent=1))
            return 0
        mix, levels, fit, _u = self.render()
        body = slice(self.F_BODY, self.F_BODY + self.LOOP_FRAMES)
        m = mlib.Master()
        p = m.pre(mix, body)
        del mix
        y = m.fit_gain(p, body)
        n2 = int(2 * ms.BAR * SR)
        seam = mlib.seam_db(y[self.F_BODY:self.F_BODY + n2],
                            y[self.F_BODY + self.LOOP_FRAMES:self.F_BODY + self.LOOP_FRAMES + n2])
        if args.wav:
            ms.write_wav(os.path.join(args.wav, f"{self.PIECE}_master.wav"), y)
        parts = {"main": (0, self.F_BODY + self.LOOP_FRAMES), "ending": (self.F_END, self.F_END + self.N_ENDING)}
        man = ml.Manifest("music", args.out or None)
        man.drop_generator(self.GENERATOR)
        rep = {"seam_diff_dbfs": seam, "levels": levels, "master": dict(m.info), "files": {}}
        state = {"y": y}
        for part in ("main", "ending"):
            a, b = parts[part]

            def reencode(lower: float, a=a, b=b) -> np.ndarray:
                m.ceiling -= lower
                state["y"] = m.fit_gain(p, body)
                return state["y"][a:b]

            rep["files"][part] = mlib.encode_checked(state["y"][a:b], man.file(self.files[part]), self.TITLE, reencode)
        if rep["files"]["ending"]["rounds"] > 1:        # a lowered ceiling applies to the main file as well
            a, b = parts["main"]
            rep["files"]["main"] = mlib.encode_checked(state["y"][a:b], man.file(self.files["main"]), self.TITLE, None)
        del state, y
        rep["master"] = dict(m.info)
        pr = mlib.prefs()
        rep["extras"] = write_extras(self, fit, m, man, pr["race_music_db"], self.BPM)
        del p
        if not args.out:
            # loop_offset a quarter frame past the body's first frame: Godot truncates time x rate to a frame
            mlib.write_ogg_import_keep(man.file(self.files["main"]), (self.F_BODY + 0.25) / SR, self.BPM, 0, 4)
            mlib.write_ogg_import_keep(man.file(self.files["ending"]), None, self.BPM, 0, 4)
            for suffix, sid in extra_ids(self.PIECE).items():
                mlib.write_ogg_import_keep(man.file(f"{sid}.ogg"), None, self.BPM, 0, 4)
        register_main(man, self, pr["race_music_db"])
        man.save()
        rep["seconds"] = round(time.time() - t_start, 1)
        print(json.dumps(rep, ensure_ascii=False, indent=1))
        return 0


def register_main(man: ml.Manifest, pc, gain_db: float) -> None:
    """Manifest entries of the main file and the ending of a RacePiece (the extras register themselves)."""
    e = man.add(pc.ids["main"], pc.files["main"], "music", pc.GENERATOR, loop=(pc.F_BODY, pc.F_BODY + pc.LOOP_FRAMES),
                role="race", bus="MMusic", gain_db=gain_db, bpm=pc.BPM, bar_beats=4,
                note=f"{pc.TITLE}: Einzähler ({pc.COUNTIN_BARS} Takt) und {pc.PHRASES[0][0]} einmal, dann Schleife "
                     f"{pc.PHRASES[1][0]} … {pc.PHRASES[-1][0]}, {pc.PHRASES[0][0]} ({pc.LOOP_BARS} Takte); ohne "
                     f"beat_count: Godot zählt Schläge vom Dateianfang, die Schleife endet am Dateiende")
    ex = extra_ids(pc.PIECE)
    e.update({"piece": pc.PIECE, "ending": pc.ids["ending"], "countin_beats": 4 * pc.COUNTIN_BARS,
              "intro_bars": pc.I_BODY, "loop_bars": pc.LOOP_BARS, "rotation": pc.ROTATION, "key": pc.KEY["tonic"],
              "endings": {"rekord": ex["schluss_rekord"], "finale": ex["schluss_finale"]}, "ziel": ex["ziel"],
              "stingers": {"busted": ex["polizei"], "out_of_fuel": ex["tank"]}})
    e = man.add(pc.ids["ending"], pc.files["ending"], "music", pc.GENERATOR, role="race_ending", bus="MMusic",
                gain_db=gain_db, bpm=pc.BPM, bar_beats=4,
                note=f"{pc.TITLE}: Schluss ({' – '.join(c for c in pc.ENDING if c)}), ab dem nächsten Taktstrich")
    e["piece"] = pc.PIECE
    e["variant"] = "normal"
    e["qc"] = {"lufs": [-20.0, -10.0]}
