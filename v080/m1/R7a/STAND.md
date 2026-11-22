# R7a STAND (handover)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
- Branch: worktree-wf_ba4424b4-294-1 (push target origin wip/v080-r7a; every commit pushed)
- Base: 9b02f050 (RINT-M2). Base copy for comparisons: scratch m1/R7a/base (git worktree, detached, imported) –
  remove at the end: git worktree remove --force <path>

## Implemented (commits up to 052de62 pushed; docs patch applied, NOT committed yet)
- sight_corridor.gd (exact envelope, every camera row, simple/full mode, clamp at read, warm())
- terrain_profile.gd (corr = strip unless width_near>0 -> max(width, strip+0.55)); chunk_streamer._warm_corridor
- city.gd fence piece mid OR ends; border.gd pillar_in_sight() exact envelope (Belgrad-Sofia km340 back on 4 pillars)
- tests: test_sight_corridor (8), test_terrain_profile, test_chunk_streamer, test_props fixture (chunk 13; R7c file!),
  test_structures (border/fences); fairness.sight_envelope + scan_corridor env checks; modern_sight F7 env lines
- docs/renderer-modern.md 5.3 etc. (patch_docs.py)

## Measurements (logs in m1/R7a)
- props_back_full.log: network 37368 -> 14342 dropped, 23026 back, 0 new; fences 64.3% -> 75.3% of Arcade
- props_back_pos.log: positions 150 m ahead (T4 9->3, T3 4->2, T1 5->1, T2 8->0, C1 6->5, S4 5->3, S0 1->0,
  Lyon 7->3, Bern 5->5, Muenchen 8->6, Nuernberg 7->7, Belgrad 10->6, Hannover 7->1)
- border_roofs.log (base 4 hanging), border_roofs2.log (new 3), roof_detail.log
- startdep.log: L at positions, start dependence (11/13 identical)
- sight_normal.log: modern_sight normal all OK (39 s)

## Gates so far
- run_tests #1: all green except 3 audio timing checks (engine3/modern/music in running game) – rerun alone:
  same failures on base under same load (rerun_audio.log) -> load-only (A-11)
- golden check: 20/20 + 17/17 identical (golden_check.log)
- render check subset: terrain_cover (T1-T4,S1,C1,K1 0.000%), start_km0, light_base, props_render, structures, structures_licht OK
- picture queue sh/queue_pics.sh RUNNING (queue_pics.log); next sh/queue_occl.sh T4 T3 T1 T2 C1 S0 S4, sh/stage.sh perf, clip
- report parts: bericht_teil1.md (sections 1-3)

## Pictures
- ab_boegen (mine, T1-T4 C1 S4 high+medium) done; base = deliver/RINT-M2/ab_boegen; triptychs in deliver/R7a/vergleich (sh/tri.py)
- bilder/: mine high S0 R1(too far, redo) Lyon Bern Muenchen Nuernberg Belgrad Hannover R2-R5 (roofs.txt moved closer)
- PLAN: when queue_pics log shows "mine R5 high" -> TaskStop the queue, start sh/queue2.sh (base subset, R1 redo, occl, perf, clip)
- report parts m1/R7a/bericht_teil1..4.md -> assemble into deliver/R7a/bericht.md

## Next
- run_tests_1.log (full run #1 in progress) -> golden check, modern-check, render checks
- pictures: sh/shots.sh (mine/base), tools/ab_sheet.sh T1 T2 T3 T4 C1 S4 (PRESETS="high medium") -> deliver/R7a
- occlusion: sh/occl.sh mine/base T1 T2 T3 T4 C1 S0 S4; count with FIX-M2 sh/occl_count.py
- clip: tools/ab_clip.sh saragossa_pau mountain bends 20 s
- modern_sight --full, modern_path_check --full, perf autopilot mine vs base
- bericht.md in deliver/R7a

## Pitfalls
- Bash tool refuses compound commands with heredocs+cd: write python patch scripts to scratch and run them.
- Probe helper names must not clash with Object methods (_set!).

## Update 13:40 UTC
- HEAD e81886a pushed (wip/v080-r7a). queue2a (base high R1 S0 Lyon Muenchen Belgrad Hannover) running; then sh/queue2b.sh (occl, perf kh_mine/kh_base, clip) in background.
- triptychs R1 + S0 done in deliver/R7a/vergleich (R1 roof on pillars; S0 oak back).
- after queue2b: occl_eval.py, triptychs cities, gates: render_checks all, golden modern-check (no modern-make), modern_sight --full, modern_path_check --full; assemble bericht.md; cleanup base worktree + mesa/tmp/occl.

## Update 14:55 UTC
- occlusion done (occl_eval.log): F2 held at T1-T4, S0, S4; C1 270 m hidden in base too (house at inside of bend).
- FOUND: props builder tests only the foot -> props whose near edge/crown reach into the envelope: base 1124, R7a 5832
  (probe/intrude.gd, intrude_full.log). Added optional reach/half_len to ChunkContext.in_bend_corridor (43cfd97) + doc (b3f1b67).
  R7c must call it (notes_for_next). Report parts teil1 (Fußabdruck table) and teil2 (Verdeckung) updated.
- RUNNING: queue3 (render checks remaining, golden modern-check, sight --full, path --full) on e81886a code (behaviour same as b3f1b67);
  run_tests #2 (LAST allowed) on b3f1b67 in parallel -> run_tests_2.log.
- NEXT: sh/queue2c.sh (perf kh_mine/kh_base, clip, medium shots) after queue3; assemble bericht.md; cleanup.

## FINAL 18:25 UTC
- HEAD 509bb16 pushed (wip/v080-r7a). Report deliver/R7a/bericht.md assembled (parts m1/R7a/bericht_teil0..6.md).
- 7d8bbb6: warm front to landmark_path_m + catch-up + corridor_sync counters (perf run found 14-24 ms props-hook spikes).
- All gates done (bericht section 6). Base worktree removed, caches/xdg/occl PNGs deleted.
- Only the result remains.
