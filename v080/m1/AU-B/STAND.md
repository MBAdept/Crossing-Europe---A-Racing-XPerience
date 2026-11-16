# STAND AU-B – handover file (written by the lead after the container restart of 2026-11-11 02:25 UTC)

A predecessor agent worked on this package for about 35 minutes and was killed by a container restart.
It left NO notes of its own; this file was reconstructed by the lead from its tool log.

- Predecessor worktree (continue THERE): /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
- Branch: worktree-wf_bade9e46-06a-2
- Last commits:
```
2b41e16 Bauplan v0.8.0: Abschnitte 1 und 2 als ein Schub in drei Arbeitsgängen (A-8)
71b9b79 Bauplan v0.8.0: Korrekturen und Entscheidungen nach Abschnitt 0, Renderer-Fassade für Abschnitt 1
a5e4e6e v0.8.0 FIX0 (PIPE): Modellprüfer und Kontaktbogen nehmen nur einen absoluten XDG_DATA_HOME
```
- Uncommitted changes in that worktree at the restart (work in progress – review, then commit as WIP):
```
 M scripts/audio/modern/engine_audio3.gd
?? scripts/audio/modern/engine_bank2.gd
?? scripts/audio/modern/engine_mix_thread.gd
?? tools/audio/modern/engine_synth3.py
```
- Scratch folder of the predecessor: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B
```
total 16
drwxr-xr-x 4 root root 4096 Nov 11 02:01 .
drwxr-xr-x 5 root root 4096 Nov 11 02:01 ..
drwxr-xr-x 4 root root 4096 Nov 11 02:24 work
drwxr-xr-x 2 root root 4096 Nov 11 02:01 xdg
```

## What the predecessor did, in order (one line per tool call; the last lines are where it stopped)

1. Fast-forward worktree to the wave-0 commit
2. Copy Godot import cache and run the import
3. Show contract outline
4. Read contract sections 1 and 2
5. Read contract audio decisions and following
6. Read contract interfaces 4.1 to 4.3
7. Read contract 4.7 audio through section 5 ownership
8. Read contract section 6 build plan waves 0-2
9. Read contract sections 8-10
10. Read contract section 11 amendments completely
11. Read the Modern audio documentation
12. Read audio-modern doc part 1
13. Read audio-modern doc part 2
14. Read audio-modern doc part 3
15. List audio scripts, tools and assets
16. Read engine placeholder, layers, module base and context
17. Read ModernAudio main node
18. Read assets loader, frame, loop and voices helpers
19. Read the engine sound documentation
20. List audio study folder
21. Read study prototype bank3.py and bankio.py
22. Read study prototypes engine3.py and render_new.py
23. Inspect the audio study JSON result
24. Show keys of the audio study result
25. Show keys of the audio study entry
26. Show structure of the studies list
27. Print audio study summary, recommendation, decisions
28. Print audio study plan, risks, numbers, evidence
29. Read the frozen Arcade EngineAudio
30. Read the frozen Arcade EngineBank (first part)
31. Read the frozen Arcade EngineBank (rest)
32. Read the frozen Arcade EngineGearbox
33. List audio tools and outline engine_synth.py
34. Read engine_synth.py header and profiles
35. Read engine_synth.py helpers
36. Read engine_synth.py CarModel
37. Find engine-related expectations in the Modern audio unit test
38. Read the start of the Modern audio unit test
39. Find engine-related parts of check_modern_audio.gd
40. Read the head of check_modern_audio.gd
41. Read switch_20 and delegation scenarios
42. Read the mix scenario of check_modern_audio.gd
43. Read race and arcade_after scenarios
44. Show audio configuration
45. Locate the audio section in the config
46. Read the audio section of the config
47. Read modern_lib.py
48. Read audio_qc.py
49. Read placeholder manifests and generator
50. Read AcousticNet and cylinder model in engine_synth.py
51. Read bank building and clip code in engine_synth.py
52. Read capture_mix.gd and measure_mix.py
53. Read ModernMix and start of ModernBuses
54. Read the study thread bench and logs
55. Read the test runner and list test folders
56. Read the process-spawning tests and the test framework
57. Find architecture section 15 and users of the engine API
58. Find AudioManager calls in the race session
59. Read session sound hooks and countdown handling
60. Read AudioManager engine part and profile switching
61. Find existing engine audio tests
62. Read existing Arcade engine audio tests (first half)
63. Find all references to the engine and layers slots
64. Read qc_lib.py measurement helpers
65. Check machine load
66. Create scratch folders and time the Arcade synth for one car
67. Look at the Arcade reference player and checks
68. NOTE: Now I have the full picture. Let me write the synthesis tool first (it is the foundation and the longest-running part).
69. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2/tools/audio/modern/engine_synth3.py
70. Fix clip model reuse, file scale, manifest put semantics
71. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work/patch1.py
72. Apply the patch to the synth tool and check syntax
73. Clean pycache and print bank info
74. First synthesis run for one car
75. Inspect the first generated bank JSON
76. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work/bank2.py
77. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work/an1.py
78. Analyse bank levels versus the Arcade bank
79. NOTE: Now the runtime. First the bank loader.
80. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2/scripts/audio/modern/engine_bank2.gd
81. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2/scripts/audio/modern/engine_mix_thread.gd
82. Check references to the MEngine bus and width reverb
83. Read tests that pin bus levels
84. Read the config-pinning test of the mix
85. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2/scripts/audio/modern/engine_audio3.gd
86. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work/patch2.py
87. Apply mixer and slot fixes
88. Find test references to the layers slot

## Successor: keep this file up to date from here on (done / doing now / next / pitfalls).

---
## Successor #2 (started 2026-11-11 02:28 UTC)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2 (same as predecessor), branch worktree-wf_bade9e46-06a-2
- Safety branch: origin wip/v080-au-b (first push 6d4359f = predecessor WIP, unreviewed)
- DONE: committed + pushed predecessor WIP (6d4359f).
- DOING NOW: reading contract + reviewing predecessor code (engine_synth3.py, engine_bank2.gd, engine_mix_thread.gd, engine_audio3.gd).
- NEXT: get synth tool to produce 5 banks; runtime; tests; measurements; A/B MP3s; docs; gates.

### Stand 03:25 UTC (successor #2)
- DONE: reviewed predecessor code (compiles, 221 scripts ok); synth runs for all 5 cars in ~42 s (scratch out: work/b2);
  fixes: mix.clip_gain as dict; induction layer cut phase-aligned (align_induction); boxer "group" pan only above
  pan_from_hz (mono-compatibility: before corr -0.49 on overrun); noise independence raised; load_curve 0.65;
  exhaust "voice" formants (give_voice); mixer: slow movement processes, level movement on both layers, saturation floor.
  Commit 3f218c4 pushed.
- Scratch tools: work/e3render.gd (offline render Arcade/Modern: drive|steady|sweep|cruise|limiter), work/e3an.py (tables,
  spectrograms; uses study alib.py), work/bank2.py (bank readers). Renders in work/r1.
- DOING: evaluate spectra/levels through the mixer; then VehicleLayers + vehicle assets, config audio.modern.engine,
  write banks into repo, tests (test_engine3*.gd + check_engine3.gd), loudness calibration with capture_mix.gd.
- NEXT: thread bench / shutdown test, sync identity, A/B MP3 per car, spectrogram PNGs, docs/motorsound.md "Modern",
  bericht.md, run_tests.sh, golden.sh check.
- PITFALLS: test_modern_audio.gd (AU-A) expects "car without bank_provider => no bank" -> must adapt 1 test line;
  placeholders in engines/ and vehicle/ belong to make_placeholders.py (keep them; QC determinism compares).

### Stand 03:36 UTC (successor #2)
- Commits pushed up to a5d9fb6 (code, tests, config, synth tool). NOT yet committed: the generated assets
  assets/audio/modern/{engines,vehicle}/** (deterministic: `python3 tools/audio/modern/engine_synth3.py` then
  `godot --headless --path . --import` recreates them, 45 s) - commit them once the final loudness check passed.
- DONE: VehicleLayers; config audio.modern.engine/layers, levels.MSfx 0; tests test_engine3_{bank,mix,slot,checks}.gd +
  check_engine3.gd (thread bench 0 underruns at six 400 ms hitches; sync 405; 20/20 clean shutdowns via
  work/shutdown20.sh); audio_qc --determinism green; audio_modern test group 83/83 green.
  Loudness plan round 3 (work/cap_c3.log): all cars full throttle -15.3..-17.0, idle -24.0..-24.8, cruise -20.8..-21.7.
- RUNNING in background: work/final_chain.sh f1 (plan captures modern -> A/B captures -> plan captures arcade);
  logs work/plan_f1_modern.log, work/ab_f1.log, work/plan_f1_arcade.log. DO NOT regenerate assets while it runs.
- NEXT: steady tables with final banks (work/e3steady.py res://assets/audio/modern/engines work/s4), A/B MP3 per car +
  spectrogram PNGs into deliver/AU-B, docs/motorsound.md section "Modern", small updates docs/audio-modern.md,
  bericht.md, full tools/run_tests.sh, tools/golden.sh check, final commit incl. assets.
- PITFALLS found: modern_lib.write_wav_import truncates the .import before reading its head (worked around in
  engine_synth3.write_wav_import_keep); Godot prints "ObjectDB instances leaked at exit" whenever a process quits while
  any AudioStreamPlayer plays (probe work/leak_probe.gd) - test_engine3_checks ignores exactly these two notices.

### Stand 03:58 UTC (successor #2, after context compaction)
- Commits pushed up to 5dfe67b: code, tests, config AND the final generated assets (engines + vehicle). Loop guard
  (16 frames behind loop_end) and queue reserve are in.
- Final loudness plan with the committed assets: work/plan_f2_modern.log (all five cars inside the plan).
- RUNNING in background: work/final_chain2.sh -> Modern A/B captures into work/ab/ab_f2 (Arcade half copied from ab_f1).
- NEXT (in this order): ab_make.py ab_f2 -> deliver/AU-B (MP3, PNG, numbers); rerun e3steady (work/s5) + e3cruise
  (work/cr2) with final banks; docs/motorsound.md section 6 (draft work/doc_modern.md has 6-6.5; 6.6-6.9 missing);
  small updates docs/audio-modern.md; rerun evidence (audio_qc --determinism, shutdown20, check_engine3, movie probe);
  commit + push; full tools/run_tests.sh (1st of at most 2), tools/golden.sh check (once); bericht.md; cleanup;
  StructuredOutput.

### Stand 04:12 UTC (successor #2)
- Committed + pushed 5dfe67b (assets). AFTER that, uncommitted in the worktree: softened clonk of shift thump / tip-in
  (tools/audio/modern/engine_synth3.py thump(): 2nd-order band 300-2000 Hz + 0.8 ms attack; regenerated
  vehicle/{shift_thump_a,b,tipin_a,b}.wav + manifest), docs/audio-modern.md updates, pointer line in docs/motorsound.md.
- Deliver folder has final A/B MP3 + txt + spectrogram PNG + ab_zahlen.json (from work/ab/ab_f3, shipped files).
- Final offline tables: work/steady_s5.log (+ s5/*.json), work/cruise_cr2.log (+ cr2/cruise.json), work/tables_f3.md.
- RUNNING in background: work/final_chain4.sh (plan_f3 -> qc_final.log -> shutdown20_final.log ->
  check_engine3_final.log -> movie_final.log). Do not edit code/assets until "KETTE4 FERTIG" in work/final_chain4.log.
- docs draft complete: work/doc_modern.md (sections 6-6.9) -> append to docs/motorsound.md (pointer line already in);
  update table 6.6 with plan_f3 numbers first.
- NEXT: append doc, commit + push; full tools/run_tests.sh (run #1); tools/golden.sh check; bericht.md; cleanup;
  StructuredOutput.
- OPEN FINDING (reported, not fixed): Modern engine is dry; centre cars (kompakt, kombi, limousine) have in-game L/R
  correlation 0.97-1.00, Arcade (width reverb) 0.80-0.99.

### Stand 04:40 UTC (successor #2)
- Commits pushed up to c33809c (final content): docs/motorsound.md section 6, docs/audio-modern.md, softened clonk,
  Kombi -0.4 dB / Sportwagen -0.3 dB, shift thump law by torque step (vehicle_layers.gd). Working tree clean.
- Gates so far: full tools/run_tests.sh run #1 on e500f09: 595 tests, 0 failed, all checks OK (572 s).
  audio_qc --determinism green on the final sound files (work/qc_final2.log). Loudness plan final: work/plan_f3 (kompakt,
  limousine, GT) + work/plan_f4 (kombi, sportwagen) -> deliver/AU-B/belege/pegelplan_modern.txt.
- RUNNING in background (work/final_chain6.sh, log work/final_chain6.log): Modern A/B captures ab_f5 -> movie probe ->
  full run_tests #2 (LAST allowed, log work/tests_full_2.log) -> tools/golden.sh check (ONCE, log work/golden_final.log).
  Do not edit repo files until "KETTE6 FERTIG".
- NEXT: python3 work/ab_make.py work/ab/ab_f5 <deliver/AU-B>; bash work/collect.sh; write deliver/AU-B/bericht.md;
  delete large scratch (work/ab, work/cap, work/b1, work/b2, work/r1, work/movie, work/deliver_test, work/cr*, work/s*
  wav); StructuredOutput (commit c33809c unless something changes).

### Stand 04:58 UTC (successor #2) - FINISHED
- Final commit 8414002 on worktree-wf_bade9e46-06a-2, pushed to origin wip/v080-au-b. Working tree clean.
- Gates: full run #1 green (595 tests, all checks OK) on e500f09; full run #2 on c33809c failed in ONE test of mine
  (probabilistic crackle assertion in test_engine3_slot.gd, random seed) and stopped after the unit phase; fixed with a
  fixed seed (8414002); `tools/run_tests.sh unit` on 8414002: 595 tests, 0 failed. No third full run (rule: at most
  two). tools/golden.sh check (once, on c33809c): 20 von 20 identisch.
- Deliverables: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-B/
  (bericht.md, motor_ab_<car>.mp3/.txt, spektrogramm_<car>.png, ab_zahlen.json, belege/).
- Large scratch items deleted (captures, intermediate banks, renders). Remaining: scripts, logs, JSON results (14 MB).
- Nothing left to do for this package; the result goes back through StructuredOutput.
