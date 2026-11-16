# STAND R1a – handover file (written by the lead after the container restart of 2026-11-11 02:25 UTC)

A predecessor agent worked on this package for about 35 minutes and was killed by a container restart.
It left NO notes of its own; this file was reconstructed by the lead from its tool log.

- Predecessor worktree (continue THERE): /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1
- Branch: worktree-wf_3b561c53-566-1
- Last commits:
```
7dbd654 v0.8.0 R1a: Renderer-Gerüst mit der Fassade (A-7) auf dem Geometrie-Kern
2b41e16 Bauplan v0.8.0: Abschnitte 1 und 2 als ein Schub in drei Arbeitsgängen (A-8)
71b9b79 Bauplan v0.8.0: Korrekturen und Entscheidungen nach Abschnitt 0, Renderer-Fassade für Abschnitt 1
```
- Uncommitted changes in that worktree at the restart (work in progress – review, then commit as WIP):
```
(none – the tree is clean)```
- Scratch folder of the predecessor: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a
```
total 24
drwxr-xr-x 6 root root 4096 Nov 11 02:09 .
drwxr-xr-x 5 root root 4096 Nov 11 02:01 ..
drwxr-xr-x 2 root root 4096 Nov 11 02:24 bin
drwxr-xr-x 3 root root 4096 Nov 11 02:09 mesa
drwxr-xr-x 2 root root 4096 Nov 11 02:22 tmp
drwxr-xr-x 3 root root 4096 Nov 11 01:50 xdg
```

## What the predecessor did, in order (one line per tool call; the last lines are where it stopped)

1. Fast-forward worktree to wave-0 commit
2. List repo root, disk space, and scratch contents
3. Outline the build contract headings
4. Read contract sections 1 and 2
5. Read contract decisions 3.1 to 3.3
6. Read contract decisions 3.4 to 3.7
7. Read contract interfaces 4.1 to 4.3
8. Read contract 4.4 seam and 4.5 kernel
9. Read contract 4.9 tests, 4.10 quality, 4.11 budgets, section 5
10. Read contract build plan waves 0 to 2
11. Read contract sections 7 to 10
12. Read contract section 11 amendments part 1
13. Read contract amendments A-7 and A-8
14. Read renderer-modern doc part 1
15. Read renderer-modern doc part 2
16. List race3d files and read the stub renderer
17. Read chunk streamer kernel file
18. Read chunk context, builder base and registry
19. Read chase camera, materials and debug road
20. Read road path kernel first part
21. Read road path kernel second part
22. List public API of terrain profile, model factory, model DB, gfx
23. Read renderer factory, self test and gfx levels
24. Find renderer usage in the race session
25. Read the session's renderer start-up code
26. Read the session's per-frame render call and view dictionary
27. List test folders
28. Find run_stage and read seam check start
29. Find tests that rely on the stub renderer
30. Read the seam render check
31. Read the kernel probe renderer
32. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/INTEG/09_ab_arcade_gegen_kern_hinter_der_naht.png
33. Read the integration's probe run scripts
34. Read the golden tool and frame list
35. Read the render check runner and the test runner
36. Copy the import cache into the worktree
37. Run the Godot import in the worktree
38. Outline ARCHITECTURE.md
39. Read ARCHITECTURE.md section 15
40. Read the Screenshotter and run_stage
41. Read the palette
42. Find sun usage in backdrop and road renderer
43. Read backdrop draw_sky and API
44. Find palette usage in the Arcade renderer
45. Read the Arcade renderer's frame setup
46. See which ce globals the shaders use
47. Find the lighting rigs used by the model tools
48. Read the measured colour pipeline notes and the contact sheet rig
49. Look at the spike renderer's light setup
50. Read the spike renderer's setup and environment update
51. Print the graphics, render and daytime configuration
52. Print the graphics, render and daytime configuration
53. Read test base and the streamer unit test start
54. Read the gfx scenarios of check_session
55. Read the seam probe fixture and script checks
56. Read the engine probe's warm-up experiment
57. Find how the session computes the background heading
58. Read the session's perf_stats and model release calls
59. Read Arcade's light pool law
60. Read the seam check's helper and first checks
61. Read where the seam check uses the real renderer
62. List integration protocols
63. Read the kernel-behind-seam protocol
64. Locate insertion points in the kernel and check export filters
65. Add services to ChunkContext
66. Add services to ChunkStreamer
67. Test whether heredoc file writes are accepted
68. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/scripts/race3d/plain_environment.gd
69. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/scripts/race3d/plain_sky.gd
70. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/scripts/race3d/modern_renderer.gd
71. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/assets/shaders/modern/inc/pools.gdshaderinc
72. Edit /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/scripts/race3d/modern_renderer.gd
73. Import new files and compile all scripts
74. Run the import to register new files
75. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a/bin/gd.sh
76. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a/bin/xv.sh
77. Run the import through the helper
78. Show working tree status
79. Check generated uid files
80. Read the debug command line reference
81. Render a first Modern skeleton frame at S1
82. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a/tmp/s1_modern_00.png
83. Render the Arcade frame at S1 for comparison
84. Read streamer unit test patterns and the synthetic track
85. See how the tests free the streamer and wait for threads
86. NOTE: Now the unit test for the services.
87. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/tests/unit/race3d/test_chunk_services.gd
88. Run the new unit test file
89. Fix the type and rerun the unit test
90. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a/bin/light_table.gd
91. Print the light law's deviation table
92. Locate the lines of the light law to adjust
93. Adjust the light law constants and reprint the table
94. Show the header of the plain environment
95. Edit /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/scripts/race3d/plain_environment.gd
96. NOTE: Now fix the unit test expectations to the tuned law.
97. Locate unit test lines to update
98. Show the light tests
99. Edit /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/tests/unit/race3d/test_chunk_services.gd
100. Edit /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/tests/unit/race3d/test_chunk_services.gd
101. Rerun the unit test file
102. Find the split point of the unit test file
103. Cut the skeleton tests out of the services test file
104. Create the separate skeleton unit test file
105. Run all race3d unit tests
106. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/tests/race3d/fixtures/facade_probe_renderer.gd
107. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/tests/race3d/fixtures/facade_layer.gd
108. Simplify the fixture layer's rebased log and fix the pending test
109. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/tests/race3d/fixtures/facade_builder.gd
110. Let the fixture builder write into the shared log
111. Let the fixture builder write into the shared log
112. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1/tests/race3d/check_facade.gd
113. Fix issues in the facade check and fixtures
114. Run the facade check for the first time
115. Fix the facade check and rerun
116. Run the seam check and the session scenarios
117. Show working tree status
118. Stage the skeleton files
119. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a/tmp/commit1.txt
120. Commit the skeleton
121. Push the safety copy
122. List functions of the seam render check
123. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a/bin/patch_seam_render.py

## Successor: keep this file up to date from here on (done / doing now / next / pitfalls).

## Successor 2 (started 2026-11-11 02:28 UTC) – running log
- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1 , branch worktree-wf_3b561c53-566-1 (same as predecessor)
- Head at start: 7dbd654 (pushed to wip/v080-r1a), tree clean.
- DOING NOW: re-reading contract (§2, §4.4, §4.5, §11 A-7/A-8) and reviewing the predecessor commit 7dbd654.
- NEXT: seam render check (modern_bild), check_seam.gd adaption, pools render check, tools/ab_shot.sh, docs section,
  ERGEBNIS identity, run_tests.sh, golden.sh check, run_render_checks.sh, A/B picture, bericht.md.
- 02:55 reviewed 7dbd654 completely (renderer, plain env/sky, pools include, facade check + fixtures, unit tests): sound.
  DECISIONS of successor 2 (being implemented now, commit 2):
  * hooks get dt = 0.0 while the stage is prepared (frozen start view);
  * builders ALSO get update(view, dt) and rebased(shift) when they have them (brief lists them for layers AND
    builders; A-7 comments say "layers" -> report under contract_issues);
  * probe renderer gets `bare` (skeleton only: no real layer/builder/rig files) so that check_facade and the render
    checks stay green in the R1/R2/R3 worktrees once they add their files;
  * the "builder file exists but gives no builder" check moves into _create_builders().
  * seam render check: apply bin/patch_seam_render.py (predecessor wrote it, reviewed) + pin modern_bild to bare probe.
- 03:10 DONE commit b64dc14 (pushed): builder update/rebased, dt=0 while preparing, probe `bare`, check_facade green 3x.
- DOING NOW: tests/race3d/render/check_seam_render.gd (modern_bild on the bare probe + generic check of the shipped
  renderer), new tests/race3d/render/check_facade_render.gd (pools include on a plane, warm-up nodes visible >= 2 frames).
- NEXT: check_seam.gd check "vertrag", tools/ab_shot.sh, docs section, ERGEBNIS identity, full gates, bericht.md.
- 03:35 DONE commit d97e1b7 (pushed): check_seam_render.gd adapted (6/6 green, 75 s), new render/check_facade_render.gd
  (licht, pools, aufwaermen: green, 4 s), pools include got ce_pools_emission()/ce_pools_encode().
  Pictures of the checks: deliver/R1a/facade_{licht,pools,aufwaermen}.png (run the check with -- --save=<abs dir>).
- DOING NOW: tools/ab_shot.sh (item 4).
- NEXT: check_seam.gd check "vertrag", docs section, ERGEBNIS identity, run_tests.sh, golden.sh, run_render_checks.sh,
  A/B picture, bericht.md.
- PITFALL: the harness refuses Bash commands that contain python heredocs with words like commit/rebased in them
  ("too complex to verify") -> use the Edit/Write tools for file changes, keep Bash commands plain.
- (clock note: the times above were guessed; real clock from here on, UTC)
- 02:57 DONE commit fb668f6 (pushed): tools/ab_shot.sh (S1–S5 shortcuts, GFX_ARGS, SCREEN; tested incl. fallback and
  1280x800). Deliverable picture: deliver/R1a/kiel_hamburg_km2_ab_00.jpg (+ _arcade_00.png, _modern_00.png).
- DOING NOW: check_seam.gd check "vertrag" (shipped renderer offers every method/signal/member of §4.4.1 + A-7).
- NEXT: docs section "Aufbau: Fassade, Ebenen, Haken", ERGEBNIS identity (run_stage kiel_hamburg + dev_testetappe),
  tools/run_tests.sh, tools/golden.sh check, tools/run_render_checks.sh, bericht.md, final commit + push.
- 03:02 DONE commit 300a571 (pushed): check_seam.gd "vertrag" (green), docs/renderer-modern.md §9 written.
  ERGEBNIS identity measured: kiel_hamburg + dev_testetappe, 28 keys, only gfx differs (logs: m1/R1a/ergebnis/).
  Perf measured (bin/perf_run.gd): render() avg 0.15 ms headless at real-time pace.
- DOING NOW: full gates in this order: tools/run_tests.sh (log m1/R1a/tmp/run_tests.log), tools/run_render_checks.sh
  (tmp/render_checks.log), tools/golden.sh check (tmp/golden.log). Each started ONCE; if the container dies, check
  the logs first.
- NEXT: fix what fails, verify docs numbers (camera px at 1280x800), bericht.md in deliver/R1a/, final commit + push.
- 03:08 DONE commit faaf3e7 (pushed): timeout counts drawn frames only; plain environment stays inside the path.
  (A first full run_tests.sh was started 03:02 and STOPPED by me after 3.5 min because I changed two source files –
  it does not count as a full run.)
- DOING NOW (03:08): bin/gates.sh = tools/run_tests.sh -> tools/run_render_checks.sh all -> tools/golden.sh check,
  sequential, in the background. Logs: m1/R1a/tmp/run_tests.log, render_checks.log, golden.log. DO NOT edit source
  files while it runs (about 20 min). If the container dies: rerun bin/gates.sh (or single gates: "gates.sh render").
- NEXT: fill docs numbers (camera px at 1280x800 from render_checks.log), write deliver/R1a/bericht.md (draft there),
  final commit + push, StructuredOutput.
- 03:12 bericht.md is written in deliver/R1a/ (complete except two placeholders: ABSCHLUSSLAEUFE = results of the
  three gates, KAMERA_1280x800 = camera px printed by fenster_16_10 in tmp/render_checks.log). After the gates:
  replace both, put the 1280x800 number into docs/renderer-modern.md §6.3 (it says 0,0005 px for both sizes –
  verify), optionally make deliver pictures: S2–S5 sheet with tools/ab_shot.sh and the doc examples under Xvfb
  (bin/doc_examples_run.gd -- --shot=<abs png>), final docs commit + push, then StructuredOutput.
  Result facts so far: deviations/contract issues/notes are listed in bericht.md §4, §7, §8.
- 03:17 GATE tests: tools/run_tests.sh exit 0, 541 s, 576 unit tests 0 failed, 80 CHECK lines all OK (commit faaf3e7).
  Render checks and golden still running in the same background job.
- PLANNED after the gates (small, decided 03:15): builders/debug_road.gd gets update(view, dt) that tints its unshaded
  material with palette.ambient (tunnel: Palette.TUNNEL_AMBIENT) – without it the stand-in road is day-bright at
  night. Tests to adapt: check_seam_render modern_bild (expected colours x ambient), check_facade "umgebung" (tint at
  noon = white, at 23:00 = night ambient), new render check "nacht" in check_facade_render.gd. Then targeted reruns
  (unit race3d, facade, seam, check_session, run_render_checks modern) – NO third full run_tests start.
- 03:20 GATE render: tools/run_render_checks.sh all -> 5 von 5 Render-Prüfdateien in Ordnung (167 s): glow 16 OK,
  flip OK, check_facade_render 3 OK, check_models 6 OK, check_seam_render 6 OK. Camera px: 0.0005 (1280x720),
  0.0001 (1280x800). Golden still running.
- 03:22 GATE golden: tools/golden.sh check -> GOLDEN arcade: 20 von 20 identisch (143 s). All three gates green on
  commit faaf3e7. Now applying the debug-road tint (uncommitted edits in builders/debug_road.gd, check_facade.gd,
  render/check_facade_render.gd "nacht", render/check_seam_render.gd, docs) and verifying with targeted runs.
- 03:26 DONE commit 72938cd (pushed): debug-road tint + render check "nacht" + docs numbers. Render checks 5/5 green
  on this tree (run 03:22, before the commit, same code). Targeted reruns green: check_scripts, unit race3d,
  check_facade, check_seam, check_session.
- DOING NOW (03:27): bin/gates.sh tests golden on the COMMITTED head 72938cd (second complete run_tests; the first
  complete one was on faaf3e7, plus one start aborted after 3.5 min; the earlier golden ran while debug_road.gd was
  already edited = mixed tree, so it is repeated). Logs: tmp/run_tests.log, tmp/golden.log (overwritten; the earlier
  ones are kept as tmp/run_tests_faaf3e7.log and tmp/golden_mixed_tree.log).
  NO source edits until it ends (~12 min). Then: bericht.md placeholders, deliver pictures, cleanup, StructuredOutput.
- 03:30 OPEN before the result may be sent (in this order, all after the background gates b26llv393 end):
  1. read tmp/run_tests.log + tmp/golden.log of the head run -> replace KOPF_TESTS / KOPF_GOLDEN in deliver/R1a/bericht.md
  2. bin/ergebnis.sh on the head (ERGEBNIS identity was measured on 300a571 only) -> fix the sentence in bericht §4.9
  3. xv.sh -s bin/shadow_on_debug_road.gd : does a caster darken the unshaded debug road? docs §9.1 and bericht §7.6
     currently CLAIM "no shadow on it" – that is inferred, not seen. Make the wording match the measurement.
  4. run render/check_facade_render.gd once more: "nacht" has run only once so far.
  5. deliver pictures (ab_shot S2–S5 sheet, doc examples via bin/doc_examples_run.gd -- --shot=…), cleanup of
     xdg*/mesa/tmpdir, final docs commit + push if docs change, StructuredOutput (draft: m1/R1a/result_draft.md).
- 03:33 Review of my own docs wording found claims that were never observed here – to settle after the gates:
  a) docs §9.6 "Nachbearbeitung drückt unter 12/255 um bis zu zehn Stufen": only the total was measured (road 6/13/27
     vs 16/21/32, plate 17/22/34 vs 21/25/36); the cause is PIPE's finding in docs/modelle.md §4 -> reword.
  b) TUNNEL paths (plain_environment fog/sun, plain_sky flat colour, debug-road tint with TUNNEL_AMBIENT) and
     --gfx-debug=cover have NEVER run in any test or picture of this package (Kiel–Hamburg has no tunnel).
     -> add a headless tunnel assertion to check_facade.gd "umgebung" (bern_mailand km 186 = U1) and take one
        ab_shot there; if it shows a defect in scripts/, REPORT it, do not patch after the last full run.
  c) ce_* globals: set in code, no picture of this package reads them -> say so.
  d) "nachts helle Albedos bis zu einem Viertel heller": predecessor's computed figure -> rerun bin/light_table.gd.
  e) "kein Schatten auf der Debug-Straße": inferred -> bin/shadow_on_debug_road.gd.
  Final commit = docs + tests only; the full suite then stands on 72938cd, the changed test files are rerun alone.
- 03:36 (clock) HEAD GATE tests on 72938cd: tools/run_tests.sh exit 0, 534 s, 576 unit tests 0 failed,
  73 "CHECK <name> OK" lines, 0 FEHLER. CORRECTION: the "80 CHECK lines" written earlier (STAND, bericht.md and the
  commit message of 72938cd) counted the 7 "CHECKS OK (…)" summary lines as checks – the real number is 73, in the
  faaf3e7 run as well. Fix in bericht.md and in the result; the pushed commit message stays as it is.
  Golden on the head still running.
- 03:39 (clock) HEAD GATE golden on 72938cd (working tree clean, verified): GOLDEN arcade: 20 von 20 identisch.
  So on the pushed head: run_tests green (576 unit tests, 73 checks), golden 20/20; render checks 5/5 ran on the
  same code content just before it was recorded (not afterwards).
  NOW working through the open list (ERGEBNIS on head, perf on head, shadow measurement, light table, tunnel,
  "nacht" repeat). From here on the repo gets docs + tests only.
- 03:41 (clock) MEASURED on head 72938cd:
  * ERGEBNIS identity again: both stages 28 keys, only gfx differs (logs m1/R1a/ergebnis_head/).
  * perf again: render() avg 0.173 / 0.150 ms (km 2 / km 60), max 2.36 / 2.24; sync 0.192 avg, 5.79 max;
    prepare headless 79-89 ms -> docs 9.10 ranges must be widened (0.15-0.17 ms; 74-89 ms).
  * shadow on the unshaded debug road: NONE (pixel 55565e with and without the box, 0 of 1296 px differ; control =
    the lit plate of "licht"). Pictures m1/R1a/shadow/. The docs sentence is right, may now say "gemessen".
  * light table (deliver/R1a/lichtgesetz_tabelle.txt, raw output of bin/light_table.gd): docs 9.6 is WRONG in two
    places: "bei Tag hoechstens 7,5 %" holds only 8:30-17:30 (dawn/dusk up to -17 % / +26 %), "nachts bis zu einem
    Viertel heller" is up to +35 % (rain), and albedo 0.2 at night is -45 to -59 %. Same wrong wording in the header
    comment of scripts/race3d/plain_environment.gd (NOT to be edited any more: report it).
  STILL OPEN: tunnel (never run), "nacht" repeat, docs corrections, new render check for the road without shadow.
- 03:46 (clock) DONE head d4c0da9 (pushed to wip/v080-r1a): docs + two test files only (name-only diff against
  72938cd checked). Fully gated commit = 72938cd (run_tests 576 unit + 73 checks, golden 20/20; render checks 5/5 on
  its content). On d4c0da9 itself only: check_scripts, check_facade.gd (8 OK), render/check_facade_render.gd (5 OK).
  New: tunnel part in "umgebung" (camera in tunnel: true), render check "strasse" (no shadow on the debug road).
  Docs 9.6 now carry the computed light table; "--gfx-debug=cover" is documented as NOT run.
  Known wrong, not changed: header comment of scripts/race3d/plain_environment.gd (too favourable numbers).
- NEXT: deliver pictures (u1 copy, S2-S5 sheet, doc examples under Xvfb), bericht.md update, cleanup, result.
- 03:56 (clock) FINISHED. Head 65c7560 = origin wip/v080-r1a (same hash, checked), tree clean.
  Last step after d4c0da9: tools/ab_shot.sh label font race fixed (convert -list font piped into grep -q failed
  3 of 8 times under pipefail) - found by looking at the S2-S5 sheet; 4 runs of the fixed tool give the same label
  and byte-identical pictures. All delivered pictures were regenerated with the fixed tool.
  Report: deliver/R1a/bericht.md (final, no placeholders). Scratch caches deleted (xdg*, mesa, tmpdir).
  NOT done on the head 65c7560: full run_tests.sh, golden.sh, the other render check files (they ran on 72938cd).
  A successor has nothing left to do except send the result (m1/R1a/result_draft.md is OUTDATED - use bericht.md).
