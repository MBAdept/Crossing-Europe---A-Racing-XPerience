#!/usr/bin/env python3
"""Titelmelodie, Remaster für das Klangprofil „Modern“ (contract D30; docs/audio-modern.md, section "Musik").

The same composition as the title theme of v0.5.0 (tools/audio/music_synth.py, imported and never edited): the same
timeline, sections, chords, notes, drum patterns, seeds and section automation – every event of the original is
rendered by its own instrument. New is the production (the audio study's remaster sketch, now for the whole song at
44.1 kHz): layered drums (a sub kick and a snare with crack and plate under the original ones), a shaker in the
driving sections, a sub bass under the bass line, two more rhythm-guitar takes with a darker amp inside the
hard-panned pair, a wide supersaw double of the synth lead, a deeper sidechain pump, new plate and hall reverbs and
the multiband master with an M/S stage (music_lib.Master).

Writes assets/audio/modern/music/titel_remaster.ogg (Ogg Vorbis q5, 44.1 kHz stereo, -14 LUFS, true peak <= -1 dBTP
after the encode), its Godot import settings (loop from 15.0 s: the 8-bar intro plays once, the 100-bar body loops –
as the original; the body ends with the intro's turnaround, so the seam is part of the music) and its entry in the
manifest (role "title": the Modern profile plays it on the title and in the menus).

  python3 tools/audio/music/title_remaster.py                 render, write the file, the import and the manifest
  python3 tools/audio/music/title_remaster.py --out DIR       the same below DIR (no import file; QC --determinism)
  python3 tools/audio/music/title_remaster.py --wav DIR       also keep the master as float WAV (previews)
  python3 tools/audio/music/title_remaster.py --bars 32:48    only these bars, as WAV to --wav (sketch)
Deterministic (seeds of the original, bit-exact Vorbis); about 6-10 minutes on one core.
"""
from __future__ import annotations

import argparse
import copy
import json
import os
import sys
import time

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_lib as mlib  # noqa: E402
from music_lib import ms, ml  # noqa: E402

GENERATOR = "tools/audio/music/title_remaster.py"
SOUND_ID = "titel_remaster"
FILE_NAME = "titel_remaster.ogg"
TITLE = "Crossing Europe - Titelmelodie (Remaster)"
SHAKER_SECTIONS = ("chorus1", "chorus2", "solo", "final")     # the driving sections get a 16th shaker
AUTO_GROUP = {"kick2": "kick", "snare2": "snare", "shaker": "hats", "sub": "bass_pick", "gtr_L2": "gtr_L",
              "gtr_R2": "gtr_R"}  # the new layers follow the section automation of the track they double


def specs() -> dict:
    """Mix of the remaster: the original's table (ms.MIX) with the changes of the audio study, plus the new layers."""
    sp = copy.deepcopy(ms.MIX)
    sp["kick"]["lufs"] = -19.3
    sp["kick2"] = {"bus": "drums", "lufs": -25.0, "eq": [("hp", 36.0, 0.7), ("peak", 52.0, 0.0, 1.0),
                                                         ("peak", 300.0, -4.0, 1.2), ("peak", 4000.0, 3.0, 1.0)]}
    sp["snare"]["lufs"] = -20.5
    sp["snare2"] = {"bus": "drums", "lufs": -19.8, "eq": [("hp", 110.0, 0.7), ("peak", 200.0, 2.0, 1.2),
                                                          ("peak", 5000.0, 2.0, 0.8)], "sends": {"plate": -14.0}}
    sp["shaker"] = {"bus": "drums", "lufs": -37.0, "eq": [("hp", 4000.0, 0.7)]}
    sp["hats"]["lufs"] = -30.5
    sp["hats"]["eq"] = [("hp", 450.0, 0.7), ("lp", 16500.0, 0.7)]
    sp["crash"]["eq"] = [("hp", 400.0, 0.7), ("hs", 8000.0, -2.0), ("lp", 16000.0, 0.7)]
    sp["sub"] = {"bus": "inst", "lufs": -27.0, "eq": [("lp", 105.0, 0.7), ("hp", 28.0, 0.7)], "duck": 0.8}
    sp["bass_pick"]["eq"] = [("hp", 45.0, 0.8), ("peak", 250.0, -1.5, 1.0), ("peak", 950.0, 3.0, 1.2), ("lp", 4500.0, 0.7)]
    sp["bass_pick"]["duck"] = 0.3
    sp["bass_syn"]["duck"] = 0.6
    for g in ("gtr_L", "gtr_R"):
        sp[g]["duck"] = 0.15
        sp[g]["eq"] = [("hp", 90.0, 0.7), ("peak", 3400.0, 1.0, 1.0), ("lp", 9000.0, 0.7)]
    for g, pan in (("gtr_L2", -0.55), ("gtr_R2", 0.55)):
        sp[g] = {"bus": "inst", "lufs": -27.5, "pan": pan, "eq": [("hp", 95.0, 0.7), ("lp", 7000.0, 0.7)], "duck": 0.2}
    sp["pad"]["duck"] = 0.6
    sp["pad"]["eq"] = [("hp", 160.0, 0.7), ("peak", 400.0, -1.5, 1.0), ("lp", 5200.0, 0.8)]
    sp["arp"]["duck"] = 0.4
    sp["lead_syn"]["lufs"] = -19.0
    sp["lead_wide"] = {"bus": "inst", "lufs": -24.5, "eq": [("hp", 220.0, 0.7), ("hs", 6000.0, 2.0)], "duck": 0.15,
                       "sends": {"hall": -10.0, "delay": -13.0}}
    return mlib.apply_prefs(sp)          # the shared sub and bass levels (tools/audio/music/mischung.json)


def automation(name: str, rd: ms.Render) -> np.ndarray | None:
    return ms.automation(AUTO_GROUP.get(name, name), rd)


def render(bar_a: int = 0, bar_b: int | None = None, log=print) -> tuple:
    """Renders bars [bar_a, bar_b) of the original timeline (+ ms.TAIL_S) and mixes them. Returns (mix, levels, rd)."""
    rd = ms.Render(bar_a, bar_b)
    n = rd.n
    ev = rd.drum_events()
    kick_times = [t - rd.t0 for t in rd.kick_times]
    sp = specs()
    mx = mlib.Mixer(n, kick_times, 0.17, log)
    t_all = time.time()
    # --- the original tracks, group by group (each straight into the mix) ------------------------------------------
    for group in ms.TRACK_ORDER:
        t1 = time.time()
        tracks = getattr(rd, group)()
        for name in list(tracks):
            mx.add(name, tracks.pop(name), sp[name], automation(name, rd))
        log(f"  {group:12s} {time.time() - t1:6.1f} s")
    # --- layered drums -------------------------------------------------------------------------------------------
    t1 = time.time()
    k2 = mlib.Canvas(n, rd.t0)
    s2 = mlib.Canvas(n, rd.t0)
    for t, inst, vel, var in ev:
        if inst == "kick":
            k2.place(mlib.kick2(var), t, vel)
        elif inst == "snare":
            s2.place(mlib.snare2(var), t, vel ** 1.3)
    mx.add("kick2", k2.x, sp["kick2"], automation("kick2", rd))
    mx.add("snare2", s2.x, sp["snare2"], automation("snare2", rd))
    del k2, s2
    shk = mlib.Canvas(n, rd.t0)
    for b in rd.bars:
        if rd.active(b) and b.sec in SHAKER_SECTIONS and b.key[0] != "turn":
            for st in range(16):
                r = ms.rng_of("shaker", b.key, st)
                shk.place(mlib.shaker(int(r.integers(0, 4))), b.t + st * ms.STEP + 0.002 * r.uniform(-1, 1),
                          (1.0 if st % 4 == 2 else 0.55) * (1.0 + 0.1 * r.uniform(-1, 1)), 0.25 if st % 2 else -0.25)
    mx.add("shaker", shk.x, sp["shaker"], automation("shaker", rd))
    del shk
    log(f"  {'drums2':12s} {time.time() - t1:6.1f} s")
    # --- sub bass under the bass line ------------------------------------------------------------------------------
    t1 = time.time()
    sub = mlib.Canvas(n, rd.t0)
    for b in rd.bars:
        if rd.active(b):
            for st, ln, m, vel, _layers in ms.bass_bar(b):
                sub.place(mlib.sub_bass(int(m), round(ln * ms.STEP, 4)), b.t + st * ms.STEP, vel)
    mx.add("sub", sub.x, sp["sub"], automation("sub", rd))
    del sub
    log(f"  {'sub':12s} {time.time() - t1:6.1f} s")
    # --- two more rhythm-guitar takes (darker amp), inside the hard-panned pair --------------------------------------
    t1 = time.time()
    for take, name in ((2, "gtr_L2"), (3, "gtr_R2")):
        di = mlib.Canvas(n, rd.t0, mono=True)
        for b in rd.bars:
            if not rd.active(b):
                continue
            for st, ln, c, mode, vel, stroke in ms.gtr_bar(b):
                r = ms.rng_of("gtr_ev", take, b.key, st)
                t = b.t + st * ms.STEP + 0.004 * r.uniform(-1.0, 1.0) + 0.003 * take
                x = ms.gtr_hit(ms.power_chord(c), ln, mode, stroke, take, int(r.integers(0, 4)))
                di.place(x, t, vel * (1.0 + 0.04 * r.uniform(-1, 1)))
        p = {**ms.AMP_RHYTHM, "mid_f": 640.0, "g1": 6.0,
             "post": ms.AMP_RHYTHM["post"] + [("peak", 1200.0, 2.0, 1.0), ("lp", 5000.0, 0.7)]}
        y = ms.amp_sim(di.x, p)
        del di
        mx.add(name, np.stack([y, y], axis=1), sp[name], automation(name, rd))
    log(f"  {'gtr_2':12s} {time.time() - t1:6.1f} s")
    # --- wide double of the synth lead (two decorrelated supersaws, one per channel) ---------------------------------
    t1 = time.time()
    wide = mlib.Canvas(n, rd.t0)
    for sec, j0, lines, tr, _patch, vel, track in ms.LEAD_PHRASES:
        if track != "lead_syn":
            continue
        for bar0 in rd.section_bars(sec):
            avail = rd.phrase_range(bar0 + j0, len(lines))
            if avail:
                notes = ms.phrase(lines[:avail], bar0 + j0, tr)
                for ch, pt in ((0, "super_l"), (1, "super_r")):
                    tt, y = ms.synth_lead(notes, pt, f"{sec}:{j0}:wide{ch}", vel)
                    wide.place_channel(y, tt, ch)
    mx.add("lead_wide", wide.x, sp["lead_wide"])
    del wide
    log(f"  {'lead_wide':12s} {time.time() - t1:6.1f} s")
    mix = mx.finish()
    log(f"  Mischung fertig nach {time.time() - t_all:.0f} s")
    return mix, mx.levels, rd


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Titelmelodie-Remaster für das Klangprofil Modern rendern")
    ap.add_argument("--out", default="", help="statt ins Repository unter diesen Ordner schreiben (ohne .import)")
    ap.add_argument("--wav", default="", help="zusätzlich den Master als Float-WAV hier ablegen")
    ap.add_argument("--bars", default="", help="nur diese Takte A:B rendern (Skizze nach --wav, keine OGG)")
    args = ap.parse_args(argv)
    t_start = time.time()
    if args.wav:
        os.makedirs(args.wav, exist_ok=True)
    if args.bars:
        a, b = (int(v) for v in args.bars.split(":"))
        mix, levels, rd = render(a, b)
        m = mlib.Master()
        meas = slice(0, int(round((b - a) * ms.BAR * mlib.SR)))
        p = m.pre(mix, meas)
        y = m.fit_gain(p, meas)
        if args.wav:
            ms.write_wav(os.path.join(args.wav, f"titel_remaster_takte_{a}_{b}.wav"), y)
        print(json.dumps({"levels": levels, "master": m.info, "seconds": round(time.time() - t_start, 1)}, indent=1))
        return 0
    mix, levels, rd = render()
    n_file, n_loop = ms.N_FILE, ms.N_LOOP_START
    measure = slice(0, n_file)
    m = mlib.Master()
    p = m.pre(mix, measure)
    del mix
    y = m.fit_gain(p, measure)
    seam = mlib.seam_db(y[n_loop:n_loop + int(2 * ms.BAR * mlib.SR)], y[n_file:n_file + int(2 * ms.BAR * mlib.SR)])
    if args.wav:
        ms.write_wav(os.path.join(args.wav, "titel_remaster_master.wav"), y)

    def reencode(lower: float) -> np.ndarray:
        m.ceiling -= lower
        return m.fit_gain(p, measure)[:n_file]

    man = ml.Manifest("music", args.out or None)
    path = man.file(FILE_NAME)
    enc = mlib.encode_checked(y[:n_file], path, TITLE, reencode)
    register(man, not args.out)
    man.save()
    rep = {"file": path, "lufs": enc["lufs"], "true_peak_dbtp": enc["true_peak_db"], "bytes": enc["bytes"],
           "frames": enc["frames"], "loop": [n_loop, n_file], "seam_diff_dbfs": seam, "levels": levels,
           "master": m.info, "encode_rounds": enc["rounds"], "seconds": round(time.time() - t_start, 1)}
    print(json.dumps(rep, ensure_ascii=False, indent=1))
    return 0


def register(man: ml.Manifest, write_import: bool) -> dict:
    """Import settings (only in the repository) and manifest entry of the written file: tempo and bars of the original
    (128 bpm, 8 intro bars once, then the 100 bars of the loop; without beat_count – Godot counts beats from the start
    of the file, the loop ends at the end of the file)."""
    path = man.file(FILE_NAME)
    if write_import:
        mlib.write_ogg_import_keep(path, ms.LOOP_OFFSET_S, ms.BPM, 0, 4)
    man.drop_generator(GENERATOR)
    e = man.add(SOUND_ID, FILE_NAME, "music", GENERATOR, loop=(ms.N_LOOP_START, ms.N_FILE), role="title",
                bus="MMusic", gain_db=mlib.prefs()["menu_music_db"], bpm=ms.BPM, bar_beats=4,
                note="Titelmelodie v0.5.0, Remaster: gleiche Noten, neue Produktion; Intro 15 s einmal, dann Schleife")
    e["piece"] = "titel"
    e["intro_bars"] = ms.INTRO_BARS
    e["loop_bars"] = ms.BODY_BARS
    return e


if __name__ == "__main__":
    sys.exit(main())
