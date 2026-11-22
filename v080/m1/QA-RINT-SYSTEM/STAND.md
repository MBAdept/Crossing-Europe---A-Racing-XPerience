# STAND QA-RINT-SYSTEM (update after every step)
Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3
  (branch worktree-wf_9927a373-337-3, ff to 9b02f05, .godot copied + imported). KEEP PRISTINE (stage runs, tests, golden).
Scratch S = this folder. XDG dirs under S/xdg/<run>. Outputs S/out/. Helper scripts S/sh/.
  S/v070 = git archive of main (v0.7.0) + .godot imported (for Arcade ERGEBNIS comparison)
  S/mut  = copy of the head tree (no .git) for mutation experiments; restore a file by copying from the worktree.
Deliver: ../../deliver/QA-RINT-SYSTEM/ (bericht.md + pictures)

## Done
- setup, import ok
- frozen files vs main: empty diff (S/out/frozen.txt)
- golden lists unchanged since creation (1f637b8 / db5aa6b / 8670656)
- §11.3 verbatim = S/../lead/contract_11_3.md (IDENTICAL)
- Arcade v070 vs head: kiel_hamburg, dev_testetappe(22 rain always), bern_mailand(15 snow auto): CMP OK 27 keys + per-second hashes (S/out/cmp_arcade_v070.txt)
  (bern_mailand with refuel=always gets stuck at km 160.5 in v0.7.0 too – autopilot, use auto)
- Rule3 dev_testetappe modern headless digest == arcade (no radar flash: add +speed run)
- mutation unit: tint shaders off -> test_props still OK (FINDING, no guard); A-18 hides() off -> test_structures 2 FAIL (guarded); brake night share 1.0 -> test_vehicles FAIL (guarded)
- scripts ready: sh/probe_race.gd, sh/quit_probe.gd + quit_restart.sh, sh/render_mut.sh (static eyespec nightglow spotspec tint)
## Running (background; gone after a restart)
- run_tests.sh full run 1 -> S/out/tests1.log (started 17:28)
- stage queue 1 (Arcade v070 vs head on kiel_hamburg, dev_testetappe 22h rain refuel always, bern_mailand 15h snow) -> S/out/stages_queue1.log, S/out/stages/*.log
## Next
- Rule 3: head modern on dev_testetappe + bern_mailand same args (stages.sh head:modern:...)
- mutations in S/mut: VPBR_STATIC (instance budget), eye_lamp_spec / SPOT_SPECULAR, model_glow_gain, tint, A-18 board rule, golden
- robustness: --gfx-debug=fail, missing manifest, --bench=all json, watchdog countdown rain/snow, quit/restart screens, 20 min modern drive
- render checks all, builds + pck_report + smoke (Linux, GLES, Wine), golden.sh check once at end
- §11.3 verbatim: find lead's source text
## Pitfalls
- Bash tool refuses heredocs with git inside: write scripts with Write tool.
- stage_hash.gd samples in _physics_process (deterministic seconds).

## Successor 2 (started Sun Nov 22 08:07 UTC)
- tests1 full run: 803/0 EXIT=0 (1154 s) – done (S/out/tests1.log). rc1 (render checks) never ran (rc1.log empty).
- Rule3 modern==arcade on all 3 stages (queue2) – done.
- 08:10 Rule3+identity with radar: dev_testetappe 14h +speed refuel always: v070==head arcade==head modern (510 hashes, radar 1, police 1, refuels 2) -> S/out/stages_queue3.log
- 08:08 render checks full (all) started in bg -> S/out/rc_full.log (sh/rc_full.sh)
- 08:20 frozen diff re-run empty; §11.3 == lead/contract_11_3.md IDENTICAL, contract diff 515dd51..HEAD append-only (+70)
- FINDING tint guard: unit test_props checks vpbr only ("alb *= v_tint" text); removing the multiply in baked.gdshader
  (+leaves) keeps test_props 13/0 (S/out/mut_tint_baked_unit.log); vpbr removal fails (mut_tint_vpbr_leaves_unit.log).
  (predecessor's comment-out mutation left the substring in the comment -> false "not guarded" for vpbr)
- queue script sh/q.sh (jobs: x_dev x_kh x_dev2 rmut fail manifest wd bench quit drive20 gmut golden gmodern) – logs S/out/q/, .done markers
- render_mut.sh tint now = baked+leaves (vec3(1.0)), runs props_render, models, facade_render
- 08:18 robustness: gfx-debug=fail -> arcade, msg ok, gfx_fallback selftest:debug, aspect KEEP, marker gone (S/out/q/fail.log, S/pics/gfxfail.png)
  missing + truncated manifest -> arcade, gfx_fallback manifest, "Spieldateien fehlen" msg (S/out/q/manifest.log); S/mut manifest restored
- queue q.sh running (bg) jobs: fail manifest wd quit bench x_dev x_kh rmut gmut drive20 ; DO NOT EDIT q.sh while running
- q2.sh ready (build pck smoke golden gmodern) – run AFTER rc_full + q.sh (build patches project.godot in W temporarily)
- 08:25 wd (watchdog) at 1280x720 high/deck rain/snow: NOT judged (watchdog "" median 0) – frames 1.2–2.5 s on loaded VM,
  perf_probe.watch() drops frames > MAX_FRAME_MS 1000 as "pause" -> countdown ends -> disabled. Low finding (machines < 1 fps
  never stepped down). TODO: rerun at 640x360 to show step-down works (job wd_small in q3).
- 08:30 quit/restart 13 screens OK (no errors, no marker left, restart keeps modern) S/out/q/quit.log; race_paused pause was sent during loading (paused=false) -> rerun race_paused_late (q3 quit_late)
- q3.sh ready: wd_small quit_late roadlight
- 08:32 bench=all OK: bench_out.json == user leistungstest.json, all keys, 3 scenes 4.2/1.9/3.6 fps, verdict too_slow->arcade (S/out/q/bench*.json); game_version 0.7.0 in dev tree (bump is REL W8)
- q3 has job texmem (arcade vs modern high, KH km2, 20 s)
- NOTE instanzen_stadt: layer max 176 > scene max 171 (scene sampled every 10 frames) -> low finding
- 08:47 x_dev (Xvfb, modern deck, ts16, dev_testetappe +speed): CMP OK 510/510 hashes vs head arcade (radar 1, police 1, refuels 2) = Rule 3 under real rendering.
  BUDGET (VM load ~15): collect max border 6.72 (avg .069), station 3.61 (avg .148), rest <=0.71; commit max 6.74 avg 1.05 (budget 3); render avg 3.2; hooks max streamer 25, backdrop 20.8; sim_max 142 ms (=preemption). load phase: city collect 9.7, commit 15.0. -> run x_dev2 later (q.sh x_dev2) for variance
- 09:00 x_kh (Xvfb deck ts16): CMP OK 347/347 vs arcade. commit max 8.96 avg 1.27; collect_by max see q/x_kh.log; streamer hook max 70.9 ms
- 08:55 real user folder logs/godot.log written by R7a/probe/bench.gd (not mine; 'BENCH iterations=188000'), copy S/out/real_userfolder_godot_log_0855.txt – report as observation for lead
- 09:07 rmut static (VPBR_STATIC off): instanzen_wald FEHLER 144 engine refusals, scene 306>230 -> A-19 gate real (S/out/rmut/static.log)
- 09:10 rmut eyespec (eye_lamp_spec 1.0): abblendlicht FEHLER 11.8%/36.1% white -> guarded
- 09:13 rmut nightglow (MODEL_BRAKE_NIGHT 1.0): bremsschein FEHLER 68.9>57 -> guarded (render + unit)
- 09:19 rmut spotspec (SPOT_SPECULAR 0): vehicle_lights OK, night_nass OK identical 0.219 -> constant has no measured effect; road low-beam guard tested via q3 roadlight
- 09:20 rmut tint (baked+leaves multiply removed): props_render, models, facade_render all OK -> tint rule NOT guarded (unit nor render) = FINDING medium
- 09:23 gmut arcade: ROAD LSB on 'hamburg' frames = 2/2 identical BUT hamburg km77 uses ROAD_CITY (bad target) -> q3 gmut2 redoes race_s1 (ROAD) + hamburg (ROAD_CITY)
- 09:4x gmut modern (baked tint off): GOLDEN modern 5/6, modern_s4_mittel ANDERS -> only the change detector notices the tint (S/out/q/gmut_modern.log)
- drive20 running (q.sh last job); rc_full 26/28
- 09:50 bericht.md draft written in deliver/QA-RINT-SYSTEM with PLATZHALTER_* to fill
- 10:0x rc_full DONE: 28/28 render check files OK, EXIT=0 (S/out/rc_full.log)
- q3 started (bg): wd_small roadlight gmut2 texmem quit_late -> S/out/q3_main.log ; then q2 (build pck smoke golden) when q.sh(drive20)+q3 done
- 10:01 wd_small (640x360): high->medium in rain AND snow, msg shown, particles 4000->1500, watchdog slow 609/667 ms -> works (S/out/q/wd_small.log)
- 10:04 roadlight mutation: nass_kegel FEHLER 0.35x -> road low-beam guarded
- 10:05 gmut2: ROAD+1LSB race_s1 0/1, ROAD_CITY hamburg 0/2 -> golden sensitive
- 10:06 drive20 (full game GameFlow, KH, modern medium, 21 min, killed by timeout): 0 error lines, but no progress evidence -> drive20p (q4, stage_hash Xvfb bern_mailand km120 18:30 ts4 1200 s) started 10:10
- q.sh DONE. q3 remaining texmem quit_late. Then q2 build pck smoke golden.
- arcade sound identity: test_arcade_identity 6 tests ok in tests1 (byte-identical mixer/sfx vs v070); merge touched no audio files
- 10:11 texmem KH km2 high 20 s: arcade 197.9 MB, modern 144.5 MB (video 204/166) -> A-6 ok
- 10:14 quit_late: pause at 170 s -> paused=true at close, 0 errors, no marker, restart modern -> OK. q3 DONE.
- 10:15 x_dev2 started (q.sh x_dev2, bg) parallel to drive20p; afterwards q2 build pck smoke golden
- 10:27 drive20p: 1200 s wall, Bern-Mailand km 120->161.9 (42 km, 113 s sim, 18:30), Xvfb modern medium, 0 error/warning lines (S/out/q/drive20p.out)
- 10:34 x_dev2: CMP OK 510/510 again; collect max station 4.86 (run1 3.61), border 0.53 (run1 6.72 = noise), signs 1.34, city 1.24; commit max 5.24 avg 1.17; sim_max 173 ms
- 10:35 q2 started (bg): build pck smoke golden -> S/out/q2_main.log ; build OUT=S/build (delete afterwards!)
- test_chunk_services 3x in mut under load: 4/0 each (S/out/flaky_*.log)
- 10:40 build OK: linux tar.gz 191.3 MB, windows zip 200.9 MB measured, parts within budget, worktree clean after; smoke running
- 10:53 smoke OK linux, gles, windows(wine); user dirs inside work dirs; golden check running (q2)
- 11:0x report: Befunde B-01..B-07 written; waiting golden check
- 11:04 golden check: arcade 20/20, arcade-ui 17/17 (S/out/q/golden_check.log). 11:05 gmodern (modern-check on head) started bg -> S/out/q2_gmodern.log. TODO cleanup S/build, S/smoke/windows/wineprefix, golden_keep
- 11:10 report: OK list, Dateien, golden section done; waiting gmodern; then summary + cleanup
- 11:12 CLEANUP: deleted build, wineprefix, v070, mut, golden_keep, xdg/* (except golden, mesa_q in use by gmodern), smoke xdg
- 11:20 report nearly final (only PLATZHALTER_GMODERN left); waiting gmodern
- 11:37 gmodern 6/6 + GLES OK. Report complete; worktree clean at 9b02f05
- 11:39 DONE except StructuredOutput
