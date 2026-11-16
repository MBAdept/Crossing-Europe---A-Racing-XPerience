# STAND QA-M2-SYSTEM

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
Branch: worktree-wf_438996b0-243-4 (ff to 6e484056ec87e2fa614061000a362feb2b5a6db8, no commits; .godot copied + imported)
Scratch: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM/  (= $S)
Deliver: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-M2-SYSTEM/
Copies: $S/mut = git archive HEAD + .godot (mutations, fallback, export det. ONLY here; revert with bin/mutate.py <mut> <id> revert)
        $S/ref070 = git archive main (v0.7.0) + import
Scripts: $S/bin/*.sh|py, $S/gd/*.gd (qa_race_sound, qa_music_flow, qa_feed_map)

## Done (results)
- frozen diff vs main: 0 files (frozen_diff.out)
- audio_qc.py all folders: 98 sounds 0 errors, sounds 19.0/23 MB, music 18.54/25 MB (audio_qc.log)
- models: manifest-only regen byte-identical, 87 models = 87 folders, 490 files, no orphans; validator OK (models/)
- Arcade audio fingerprint: v0.7.0 regenerated = committed = current (audio_golden/)
- feed map Kiel–Hamburg (sound/feed_map_kh.log): concrete km 25-60, Köhlbrand steel deck 78.0-80.61 (joints 78,79,80,80.61), Elbbrücken 84-86.01, cobbles 87.0-87.81, 88.7-89.61, 90.51-92.31, 94.11-
- finding candidate: check_vehicle_standin skips spieler/verkehr/kasten/nacht/verdeckt (every set has a model) -> A-9 stand-in picture unguarded

- run_tests.sh full #1: PASSED 1133 s, 749/0 unit, 175 CHECK OK, 0 FEHLER (run_tests_1.log) [1 of max 2 full runs used]
- ERGEBNIS v0.7.0 vs cur arcade: kh, bm(km150 snow 22h), df(km170 rain 19:30) identical except gfx; modern kh identical except gfx (ergebnis/)
- Movie-Maker capture works (override.cfg in mut: movie mix rate 44100); real-time headless capture drifts (WAV 10% short under load)

- sound captures done so far: rs_concrete, rs_koehlbrand, rs_cobbles (see notes_results.md)

- race_sound.sh done (rs_concrete/koehlbrand/cobbles/crash/crash2/arcade_koehlbrand), analysis sound/race_sound_analysis.txt
- render checks run 1 (render_checks.log): glow 16/16, flip, facade, instance_budget OK; wald FEHLER Exit 124 (900 s timeout,
  my outer nice + script nice = 19!), then killed the run (EXIT 143) and restarted the rest at nice 10:

## Doing now
- render_rest done: 14/14 files OK; wald killed after >21 min (no verdict) -> finding; vehicle_standin vacuous -> finding
- queue.sh (bg, started 16:47) -> $S/queue.log (START/DONE per step), step logs q_<step>.log:
  wait_render mutations sound2 mix music export_det fallback bench xclose quit soak builds smoke_linux smoke_wine golden
  A restarted queue skips steps with a DONE line; if killed mid-mutation: python3 bin/mutate.py $S/mut <id> revert for all ids
- DO NOT wrap tools/*.sh that nice themselves in another nice (they add up to 19)
- NEVER edit a running bash script in place (bash reads it lazily): race_sound2.sh is the newer copy (nolim cases)
- report parts: bericht_teil_*.md, notes_results.md

## Next (plan, heavy jobs one at a time)
1 ergebnis.sh (ref vs cur arcade on kh/bm/df + modern kh)
2 sound captures: qa_race_sound.gd (concrete 24.5, Köhlbrand 77.6, cobbles 86.5, crash), qa_music_flow.gd, capture_mix race_music/off/menu
3 mutations (mutate.py ids) in $S/mut
4 export_det.sh (Blender) ; fallback.sh ; bench.sh ; quit_screens.sh ; soak.sh ; builds.sh + wine smoke
5 run_render_checks.sh all ; golden.sh check (last)

## Pitfalls
- load 15-18 from other agents (R4, R5, QA-M2-BILD, AS5a)
- Bash tool refuses compound git commands -> scripts
- ref070 gelöscht (ERGEBNIS und Klang-Fingerabdruck fertig)
- mutations step DONE (notes_results.md "Mutationen"); golden_road mutation was INEFFECTIVE (road.gd sets lane_line_w at run time)
  -> followup.sh after the queue: golden_lane, leistung_cache->instanzen, props_gate (run_tests.sh test_props with mutation)
- queue progress 18:15: mutations, sound2, mix, music DONE (results in notes_results.md, bericht_teil_*.md); export_det running
- 18:55 queue.sh killed by the 2-h background limit during check_sprite_geometry (exports, 2 bakes byte-identical, check-keys OK done)
- PART A (bg, 18:57): sprite_geom.sh -> q_sprite_geom.log, then queue.sh STEPS="fallback bench xclose quit"; ends with "PART A DONE" in queue.log
- PART B (start after A): STEPS="soak builds smoke_linux smoke_wine golden" bash bin/queue.sh ; then bin/followup.sh
- 19:24 PART A running (bg biwzdoe6o): quit step started 19:21:29 (14 screens + stage loading/driving/paused + strikes, ~25-30 min)
- PART B queued (bg bxi9vzbur, started ~19:23, 2-h limit ~21:23): waits for "PART A DONE", then
  STEPS="soak builds smoke_linux smoke_wine golden" queue.sh, "PART B DONE", then followup.sh -> q_followup.log
- after: evaluate quit/, soak, builds (pck_report), smoke, golden (20/20 + 17/17), followup; write deliver/QA-M2-SYSTEM/bericht.md; cleanup mut, build/, wine prefix, xdg_*, mesa_*
- 19:42 PART A DONE. quit results: 14 menu screens SIGTERM exit 143, restart title, settings kept, no marker, 0 errors (pictures looked at: OK).
  Stage quit: fixed 45 s waits too short at load 26 (still loading in driving/paused); strike #2 killed before marker armed
  -> bin/quit_stage2.sh (state-based waits; driving/paused/strike2) to run AFTER PART B + followup (one heavy job at a time)
- soak.sh RSS sampler samples the `timeout` process (pgrep bug) -> separate sampler bg bj53nlndw -> soak/rss_godot.tsv (godot pid 22397)
- report parts new: bericht_teil_robust.md (placeholders ⟨QUIT⟩ ⟨SOAK⟩ ⟨BUILDS⟩), bericht_teil_befunde.md (M2S-01..06; ⟨INSTANZEN⟩ ⟨PROPSGATE⟩), bericht_teil_vertrag.md, bericht_teil_naechste.md, bericht_teil_tore.md (⟨GOLDEN⟩)
- 20:03 soak DONE: 1212 s, state racing at my limit, 0 error lines, RSS flat 1.659 GB (rss_godot.tsv), 23 threads, 8 fds -> bericht_teil_soak.md
- builds started 20:02:54
- 2026-11-13 05:26 UTC: CONTAINER RESTART (golden step was running, "Terminated"; builds/smoke_linux/smoke_wine DONE).
  Successor continues: machine quiet (load 1). Plan: (1) golden check alone, (2) wald check alone while quiet
  (RENDER_CHECK_TIMEOUT=3000), (3) followup.sh, (4) quit_stage2.sh, (5) bericht.md, cleanup.
- 05:33 golden running (bin/golden_run.sh -> q_golden.log, DONE line in queue.log). Then in order, one at a time:
  bin/wald_run.sh (-> q_wald.log), bin/tyre_wind.sh (NEW: wind alone / tyres alone via gd/qa_tyre_wind.gd -> tyrewind/),
  bin/followup.sh (-> q_followup.log), bin/quit_stage2.sh (-> quit2/). mut copy verified = worktree (05:33).
  bericht_teil_builds.md: Wine filled (deliver/wine_arcade_modern.png). Version 0.7.0 in builds = by plan (REL bump) -> note only.
- 05:33 GOLDEN arcade 20/20 identisch (365 s); UI list running. Next: bin/rest.sh (bg) STEPS wald tyre_wind followup modern_check quit2
- 2026-11-15 08:03 UTC: SECOND CONTAINER RESTART (uptime 1 min). rest.sh never produced output (no q_wald/tyrewind/followup/quit2).
  Successor #3 continues with: rest.sh steps wald tyre_wind followup modern_check quit2 (one at a time), then bericht.md + cleanup.
- 08:06 rest.sh A started in bg (STEPS="wald tyre_wind followup") -> queue.log START/DONE, q_wald.log, q_tyre_wind.log, q_followup.log.
  Then: STEPS="modern_check quit2" bash bin/rest.sh ; then analyze_tw.py, fill placeholders ⟨GOLDEN⟩ ⟨QUIT⟩ ⟨QUIT2⟩ ⟨SOAK⟩ ⟨BUILDS⟩ ⟨INSTANZEN⟩ ⟨PROPSGATE⟩,
  assemble deliver/QA-M2-SYSTEM/bericht.md from bericht_teil_*.md, cleanup (mut, build/, wineprefix, xdg_*, mesa_*).
- 08:09 (successor #3): bin/assemble.py writes deliver/bericht.md from parts + teil_{golden,quit2,instanzen,propsgate,wald,moderncheck}.md
  (teil_golden.md done). M2S-07 (fallback text names graphics when files missing) added to befunde. Builds version note = no finding
  (build_testbuild.sh sets the version). Still to write: bericht_teil_zusammenfassung.md, bericht_teil_tyrewind.md, the teil_*.md.
- 08:56 wald DONE: OK after 2945 s (texts updated via bin/fix_wald_text.py, teil_wald.md). tyre_wind running.
- 09:00 tyre_wind DONE (bericht_teil_tyrewind.md written). followup running (golden_lane applied in mut; if killed: python3 bin/mutate.py $S/mut golden_lane revert / leistung_cache revert / props_pylon_albedo revert)
- 09:10 followup DONE (golden_lane rot, instanzen rot, props_gate Tor rot; teil_instanzen/propsgate written, mutation table extended). rest.sh B (modern_check quit2) running bg.
- 09:48 modern_check DONE 6/6 + GLES OK (teil_moderncheck.md). quit2 running (bg b3jmzzgeb). After: teil_quit2.md, teil_quitkurz.md, assemble.py, copy pictures quit2 to deliver, cleanup.
- 09:56 quit2 DONE (teil_quit2/quitkurz), report assembled (deliver/bericht.md complete). Next: cleanup + StructuredOutput.
- 10:00 DONE: report complete (deliver/bericht.md), cleanup done (mut, wineprefix, xdg_*, mesa_*, keep dirs, worktree build/ deleted). Only StructuredOutput left.
