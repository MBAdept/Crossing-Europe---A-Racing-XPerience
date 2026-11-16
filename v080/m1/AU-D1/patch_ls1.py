import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
('''Three clips for AudioStreamInteractive (scripts/audio/modern/music_director.gd):
  linke_spur_anlauf.ogg    count-in + A1, 9 bars (36 beats), plays once; auto-advance into the loop at its end.
                           The count-in is one bar: the director starts it 20/11 s before the countdown's "LOS!".
  linke_spur_schleife.ogg  B1 … T, A1 – 88 bars, 7,056,000 frames, loops from frame 0. Its last phrase is A1 again,
                           so the loop seam lies inside the music (A1 -> B1) and is exact: the loop start carries the
                           tails of A1 as they ring when the loop comes round.
  linke_spur_schluss.ogg   the ending (Bb – C – Dm with a drum fill, held final chord, ringing out), started by the
                           director at the next bar line after the finish.
All three come out of ONE render and one master (the body sets the level; count-in, A1 and the ending get exactly its
processing), so the joins are gapless and the levels match.

  python3 tools/audio/music/linke_spur.py              render, write the three files, their imports and the manifest''',
'''Two clips for AudioStreamInteractive (scripts/audio/modern/music_director.gd):
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

  python3 tools/audio/music/linke_spur.py              render, write both files, their imports and the manifest'''),
('''FILES = {"intro": "linke_spur_anlauf.ogg", "body": "linke_spur_schleife.ogg", "ending": "linke_spur_schluss.ogg"}
IDS = {"intro": "linke_spur_anlauf", "body": "linke_spur_schleife", "ending": "linke_spur_schluss"}''',
'''FILES = {"main": "linke_spur.ogg", "ending": "linke_spur_schluss.ogg"}
IDS = {"main": "linke_spur", "ending": "linke_spur_schluss"}'''),
('''def lines_until_gap(lines: list, bar0: int, n_bars: int) -> list:
    """The lines of a phrase that start before the next gap bar (the extra bars after A1' end there) and inside the
    rendered bars."""
    k = 0
    while k < len(lines) and bar0 + k < n_bars and BARS[bar0 + k].kind != "gap":
        k += 1
    return lines[:k]''',
'''def lines_until_gap(lines: list, bar0: int, n_bars: int) -> list:
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
    return y'''),
('''            use = lines_until_gap(lines, i0 + j0, len(bars))
            if not use:
                continue
            notes = ms.phrase(use, i0 + j0, tr)
            tt, y = ms.synth_lead(notes, patch, f"ls:{pid}:{j0}:{track}", vel)
            (harm if track == "harm_syn" else lead).place(y, tt, 1.0)
            if track.endswith("+wide"):
                for ch, pt in ((0, "super_l"), (1, "super_r")):
                    tw, yw = ms.synth_lead(notes, pt, f"ls:{pid}:{j0}:wide{ch}", vel)
                    wide.place_channel(yw, tw, ch)''',
'''            if i0 + j0 >= len(bars):
                continue
            notes = ms.phrase(lines, i0 + j0, tr)
            tt, y = ms.synth_lead(notes, patch, f"ls:{pid}:{j0}:{track}", vel)
            (harm if track == "harm_syn" else lead).place(cut_at_gap(y, tt, i0 + j0), tt, 1.0)
            if track.endswith("+wide"):
                for ch, pt in ((0, "super_l"), (1, "super_r")):
                    tw, yw = ms.synth_lead(notes, pt, f"ls:{pid}:{j0}:wide{ch}", vel)
                    wide.place_channel(cut_at_gap(yw, tw, i0 + j0), tw, ch)'''),
('''            use = lines_until_gap(lines, i0 + j0, len(bars))
            if not use:
                continue
            tt, y = ms.lead_guitar_di(ms.phrase(use, i0 + j0, tr), f"ls:{pid}:{j0}")
            di.place(y, tt, vel)''',
'''            if i0 + j0 >= len(bars):
                continue
            tt, y = ms.lead_guitar_di(ms.phrase(lines, i0 + j0, tr), f"ls:{pid}:{j0}")
            di.place(cut_at_gap(y, tt, i0 + j0), tt, vel)'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
i = s.index('    parts = {"intro": (0, F_BODY)')
j = s.index("    man.save()")
new_out = '''    parts = {"main": (0, F_BODY + LOOP_FRAMES), "ending": (F_END, F_END + N_ENDING)}
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
'''
s = s[:i] + new_out + s[j:]
open(p, "w", encoding="utf-8").write(s)
print("ok")
