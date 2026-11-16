# AU-D1 STAND (handover)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_158edd89-079-1
- Branch: worktree-wf_158edd89-079-1 (pushed as origin wip/v080-au-d1 after every commit)
- Base: 3b89a33 (UI1 head). Last commit: b713e71 (docs, FADE_DISABLED ending, check_music.py)
- XDG for runs: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-D1/xdg
- Float masters (for MP3s): scratch .../AU-D1/wav/titel_remaster_master.wav, linke_spur_master.wav

## Decisions (keep)
- Race track 1 "Linke Spur": D minor, 132 bpm. Count-in = 1 bar (start 3.0-1.818 s after stage_start).
- ONE main Ogg (count-in + A1 = 9 bars intro, loop_offset (721636+0.25)/44100, loop 88 bars to file end,
  bpm 132, beat_count 0) + ending Ogg. NOT 3 clips: auto-advance starts the next clip 640/128 frames early
  (measured with probe_autoadvance.gd -> probe_aa.log; source analysis in godot_src/).
- Interactive: clip lauf -> schluss NEXT_BAR, TO_START, FADE_OUT 0.5 beat (MusicDirector.build_race_stream).
- QC tempo rule (beats = loop length) conflicts with Godot beat_count (counted from file start) for files with
  loop_offset -> no "beats" in manifest for title and main race file (contract issue to report).
- Existing AU-A tests pinned stub music behaviour -> updated: test_modern_audio.gd test_music_contexts,
  test_modern_assets.gd (ids), check_modern_audio.gd race music_ok (deviation to report).

## Done
- music_lib, title_remaster.py, linke_spur.py, renders (QC green), director, test_music_director (7 ok),
  modified AU-A tests pass (filter test_modern_a)

## Done since
- check_music.gd + test_music_checks.gd (10 music tests green). Director clock = physics steps.
- Immediate quit() leaks with either profile (Arcade 3/6, Modern 2/6 runs) -> note for UI2/AU-E:
  GameFlow.quit_game should stop sound and wait ~0.3 s. Director teardown + 0.3 s: 0 of 16 leaks.

## Done since (2)
- levels measured (menu -20.2 whole, race music -23.7 full throttle), MP3s + PNGs in deliver/AU-D1,
  check_music.py (title cos 0.970, race 87.6 %), ending FADE_DISABLED (doubled downbeat measured),
  docs section 14, bericht.md draft (Anhang: gates to fill)

## Done (final, 03eaeff = origin/wip/v080-au-d1)
- 03eaeff: title manifest gets bpm 128/bar_beats/intro_bars 8/loop_bars 100 (+ .import bpm=128), via register()
- audio_qc --determinism: all 3 generators OK (1276 s); plain audio_qc final: 4 sounds OK, 7.483 MB of 25 MB
- run_tests.sh full (once): bestanden, 622 tests 0 failed, 83 CHECK OK 0 FEHLER, 663 s (run_tests_full.log)
- golden.sh check (once): GOLDEN arcade: 20 von 20 identisch (206 s) (golden_check.log)
- bericht.md Anhang filled; big scratch deleted (wav/, cap/*.wav, dump/, qc_tmp/, xdg_tests/)
- remaining: StructuredOutput only

## Next
- capture race mix MP3 (own tool tools/audio/music/capture_race_music.gd?), MP3s, spectrograms, chords check
  (tools/audio/music/check_music.py), bericht.md, docs section, run_tests full + golden at end, QC --determinism

## Pitfalls
- nice -n 19, one worker (OMP_NUM_THREADS=1), never two heavy jobs at once
- mix_audio of a finished Ogg returns short arrays (pad, else infinite loop)
- debug_state must not contain NaN (JSON warning)
