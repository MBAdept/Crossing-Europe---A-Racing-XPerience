import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
rep = [
('''  linke_spur_schluss.ogg   the ending (Bb – C – Dm with a drum fill, held final chord, ringing out), started by the
                           director at the next bar line after the finish.
Both come out of ONE render and one master (the loop body sets the level; count-in, A1 and the ending get exactly its
processing), so the join is gapless and the levels match.
''', '''  linke_spur_schluss.ogg   the ending (Bb – C – Dm with a drum fill, held final chord, ringing out), started by the
                           director at the next bar line after the finish.
Both come out of ONE render and one master (the loop body sets the level; count-in, A1 and the ending get exactly its
processing), so the join is gapless and the levels match.
The extra clips of race_lib.Extras (stab at the finish line, the endings "rekord" and "finale", the stingers "polizei"
and "tank"; linke_spur_<suffix>.ogg) are rendered afterwards in D minor with the track gains of this render and its
master – they sound like the piece and sit at its level (race_lib.write_extras).
'''),
('''GENERATOR = "tools/audio/music/linke_spur.py"
PIECE = "linke_spur"
BPM = 132.0
''', '''GENERATOR = "tools/audio/music/linke_spur.py"
PIECE = "linke_spur"
BPM = 132.0
ROTATION = 1            # first race piece of a session (MusicDirector: rotation over the "race" entries)
'''),
('''import music_lib as mlib  # noqa: E402
from music_lib import ms, ml  # noqa: E402
''', '''import music_lib as mlib  # noqa: E402
from music_lib import ms, ml  # noqa: E402
import race_lib  # noqa: E402
'''),
('''    "Gm": {"root": 31, "pow": (43, 50, 55), "pad": (43, 50, 55, 58), "arp": (55, 58, 62, 67), "tri": (62, 67, 70)},
}
''', '''    "Gm": {"root": 31, "pow": (43, 50, 55), "pad": (43, 50, 55, 58), "arp": (55, 58, 62, 67), "tri": (62, 67, 70)},
}
# the key for the extra clips (race_lib.Extras): tonic, the ending's cadence, Phrygian bII and iv of the stingers, the
# major tonic of the finale, the root the fanfares are built on (D5)
KEY = {"tonic": "Dm", "minor_tonic": "Dm", "major_tonic": "D", "cadence": ("Bb", "C"), "bII": "Eb", "iv": "Gm",
       "root_hi": 74}
'''),
('''def render(n_bars: int | None = None, log=print) -> tuple:
    """Renders the timeline (or only its first n_bars + 3 s) and mixes it. Returns (mix, levels)."""''',
 '''def render(n_bars: int | None = None, log=print) -> tuple:
    """Renders the timeline (or only its first n_bars + 3 s) and mixes it. Returns (mix, levels, fit) – fit: the level
    decisions of the Mixer (the extra clips are mixed with them)."""'''),
('''    mix = mx.finish()
    log(f"  Mischung fertig nach {time.time() - t_all:.0f} s")
    return mix, mx.levels
''', '''    mix = mx.finish()
    log(f"  Mischung fertig nach {time.time() - t_all:.0f} s")
    return mix, mx.levels, mx.fit
'''),
('''        mix, levels = render(nb)
        m = mlib.Master()''', '''        mix, levels, _fit = render(nb)
        m = mlib.Master()'''),
('''    mix, levels = render()
    body = slice(F_BODY, F_BODY + LOOP_FRAMES)''', '''    mix, levels, fit = render()
    body = slice(F_BODY, F_BODY + LOOP_FRAMES)'''),
('''    rep["master"] = dict(m.info)
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
    man.save()''', '''    rep["master"] = dict(m.info)
    del state, y
    gain = mlib.prefs()["race_music_db"]           # music level against the car (mischung.json)
    host = race_lib.ExtrasHost(PIECE, TITLE, GENERATOR, "ls", KEY, CH, specs)
    rep["extras"] = race_lib.write_extras(host, fit, m, man, gain, BPM)
    ex = race_lib.extra_ids(PIECE)
    if not args.out:
        # loop_offset a quarter frame past the body's first frame: Godot truncates time x rate to a frame
        mlib.write_ogg_import_keep(man.file(FILES["main"]), (F_BODY + 0.25) / SR, BPM, 0, 4)
        mlib.write_ogg_import_keep(man.file(FILES["ending"]), None, BPM, 0, 4)
        for sid in ex.values():
            mlib.write_ogg_import_keep(man.file(f"{sid}.ogg"), None, BPM, 0, 4)
    e = man.add(IDS["main"], FILES["main"], "music", GENERATOR, loop=(F_BODY, F_BODY + LOOP_FRAMES), role="race",
                bus="MMusic", gain_db=gain, bpm=BPM, bar_beats=4,
                note="Linke Spur: Einzähler (1 Takt) und A1 einmal, dann Schleife B1 … T, A1 (88 Takte); "
                     "ohne beat_count: Godot zählt Schläge vom Dateianfang, die Schleife endet am Dateiende")
    e.update({"piece": PIECE, "ending": IDS["ending"], "countin_beats": 4 * COUNTIN_BARS, "intro_bars": I_BODY,
              "loop_bars": LOOP_BARS, "rotation": ROTATION, "key": KEY["tonic"],
              "endings": {"rekord": ex["schluss_rekord"], "finale": ex["schluss_finale"]}, "ziel": ex["ziel"],
              "stingers": {"busted": ex["polizei"], "out_of_fuel": ex["tank"]}})
    e = man.add(IDS["ending"], FILES["ending"], "music", GENERATOR, role="race_ending", bus="MMusic", gain_db=gain,
                bpm=BPM, bar_beats=4, note="Linke Spur: Schluss (B – C – d, Schlussakkord), ab dem nächsten Taktstrich")
    e["piece"] = PIECE
    e["variant"] = "normal"
    e["qc"] = {"lufs": [-20.0, -10.0]}
    man.save()'''),
]
for a, b in rep:
    assert a in s, a[:70]
    s = s.replace(a, b, 1)
open(p, 'w', encoding='utf-8').write(s)
print("ok")
