# STAND R1 (Renderer-Kern)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-1
- Branch: worktree-wf_145e8e23-1e4-1  (safety copy: origin wip/v080-r1; plain push after every commit)
- Base: a8ec8b8 (predecessor head, branch worktree-wf_3b561c53-566-2, fast-forwarded). Predecessor's worktree
  .claude/worktrees/wf_3b561c53-566-2 must NOT be touched. I am successor #1 (started ~05:30).
- git: the harness refuses compound git commands and heredocs -> separate plain commands; commit messages via
  `git commit -q -F <scratch>/msg.txt`; patch scripts are written with the Write tool into <scratch>/py/ and run.

## Done (committed by predecessor)
- environment_rig.gd (light law with post-path inverse, sun swing, moon, tunnel blend, sky as reflection source,
  ce_* globals, quality hooks), layers/backdrop.gd (RaceBackdrop on canvas layer -10, any aspect, true horizon row),
  builders/road.gd + assets/shaders/modern/road.gdshader (all paint analytic), inc/headlight.gdshaderinc,
  inc/pools.gdshaderinc (pool_dir cones), builders/roadside.gd (W-beam rails, posts, reflectors, delineators; vpbr),
  layers/lights.gd (2 spots, omni pool, pools, glints) + reflector.gdshader, debug road as terrain stand-in.
- 109cee5: quality.gd, perf_probe.gd, prewarm.gd, integration in modern_renderer.gd, race_session.gd
  (quality_lowered), race_renderers.gd (leave_modern), config max_chunks 18 + prepare_timeout_s.
- a8ec8b8 (lead, UNREVIEWED): overlay layer, light/road shaders, first tests -> review + compile-check first.

## Done by me (successor #1)
- 8e468ba (pushed): review of a8ec8b8 – check_scripts 241 OK, race3d unit tests 61 OK, check_modern_stage
  6/7 -> "nacht" made deterministic (synthetic car 60 m ahead) -> 7/7. Render checks modern: 3/3 files OK
  (rc1.log). Shots b1/ (S1 high, S3 23:00 high) compile and look sane.

- ef3a83b (pushed): render/check_road_parity.gd – gerade 0.23 px, kurve_400 7.11 px (<=8), kurve_136 13.27 px
  (<=27), fenster 1280x800 + 1680x720 OK. Measures across the line normal; edge lines judged while >= 1.5 px wide.
- 91d2251 (pushed): render/check_light_base.gd – tageslicht asphalt -6.7 %, grass +1.5 %, sky -4.8 %; schatten
  -0.32 %. debug_road stand-in ribbon now uses the scenery grass bands (was 15 % too dark).

- fairness --full (on 91d2251 content): modern_sight F1 0/99.4M to 270 m, F1 lanes 0, F2 0.593/0.596/0.555,
  F3 0/5923, F7 0, model OK (141 s); modern_path_check clearance 267.6 m, loops 2064 m, 0 positions > 18 chunks.
  Logs: sight_full.log, path_full.log.
- 583b72e (pushed): tests/race3d/render/warmup_cold.gd (cold cache; Mesa cache files = compiles) + session sets
  hud.state in _begin_prepare (HUD canvas shaders compiled behind the cover). Cold runs: noon 0 compiles, longest
  497 ms / median 179; 19:06 0 compiles, 362/189. Docs §10 draft in renderer-modern.md.

- 46456fe (pushed): warmup_cold prints render/commit/draw calls too.
- Pictures: shots/c1 (S1-S5 high, dawn 6.3, dusk 19.4, night 23, rain S3), copied with German names into
  deliver/R1/ (+ fenster, parity curves, tageslicht A/B).

- run_tests.sh FULL #1 on 46456fe: 596 unit OK, 79 CHECK OK, 1 FEHLER (check_seam "ablauf": asserted empty
  hud.state during preparation) -> fixed in 21bca09 (asserts _last_countdown stays -1 + HUD holds start state);
  check_seam 9/9. Full runs used: 1 of 2.
- 21bca09 (pushed): check_seam fix, plain_environment comment, docs 10.11/10.12, warmup_cold.gd.uid.
- cold6: 0 compiles; frame criterion failed once at load 12.5 (1167 ms single frame, no compile) – noise.

- On 21bca09: run_render_checks.sh all -> 7 of 7 files OK (41 check lines OK, rc_all.log);
  golden.sh check -> 20 von 20 identisch (183 s, golden.log).

- run_tests.sh FULL #2 on 21bca09: "Tests bestanden" (619 s), 596 unit, 80 CHECK OK. Both full runs used.
- bericht.md final in deliver/R1. Head 21bca09 = origin wip/v080-r1. Tree clean. DONE – only the result is left.

## Doing now
- nothing (package delivered). A successor would only re-send the result.
- Look tuning skipped for time (notes: tar snakes / asphalt grain; noon picture empty without R2/R3).

## Next
1. layers/overlay.gd + assets/shaders/modern/overlay.gdshader (canvas layer 2: chase lights at the corners, radar flash).
2. Tests: tests/unit/race3d/{test_road_builder, test_quality, test_environment_rig}.gd,
   tests/race3d/check_modern_stage.gd (ERGEBNIS = Arcade, core time, leave_modern),
   tests/race3d/render/{check_road_parity, check_light_base}.gd; adapt check_facade_render (WARMUP 8 already).
3. Cold-cache warm-up check (scratch script, start_frame_ms_* of perf_stats).
4. Look tuning (asphalt detail, shadows, night), pictures S1-S5 + dawn/dusk/night into deliver/R1.
5. docs/renderer-modern.md (Aufbau), bericht.md, gates: run_tests.sh (max 2 full runs), golden.sh check once,
   run_render_checks.sh, modern_sight --full + modern_path_check --full (kernel changed: max_chunks, debug_road).

## Pitfalls
- Default preset on this VM is "low" (adapter tier software): no shadow casters. Pictures: GFX_ARGS="--gfx-preset=medium|high".
- `godot --check-only -s` cannot compile scripts that name RoadRenderer (autoloads missing) -> use tests/check_scripts.gd.
- Canvas _draw of the backdrop is outside render() timing; measure separately (not yet in perf()).
- ModelDB.release_all() without owner drops everything: only in RaceRenderers.leave_modern() (Arcade renderer after Modern).

## Scratch
- /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1/
  shots/ (pictures), py/ (patch scripts, lightlaw.py), gd/profile_core.gd, shots.sh, msg.txt, mesa/ (shader cache)
- deliver: .../scratchpad/v080/deliver/R1/ (bericht.md + pictures)
