# STAND QA-R4 (review of R4, head 7f0eae2, base 6e48405) – NO commits, NO pushes
- worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3 (branch worktree-wf_fd1de4ee-28b-3, ff to 7f0eae2, imported)
- base copy (git archive 6e48405, imported): $S/base   ($S = this folder)
- mutation copy of head (no .git): $S/mut  (mutate.py restores files after each run)
- scripts: $S/sh/{pos.sh, ab.sh, queue.sh, mutate.py, scan_data.gd}; logs: $S/logs; pictures: $S/shots/{head,base}
- queue.sh <jobs…> skips jobs with a marker in $S/done/ (rerun-safe after a restart; delete the marker to redo)
- deliver: .../v080/deliver/QA-R4/ (bericht.md + pictures)
## done
- 17:03 ff + import; base copy imported; code review of the diff (weather, rig, lights, flares, vehicles, materials, terrain, shaders)
- ownership: diff stat ok except flare.gdshader (no W3 owner) and tests/golden/modern_slice.* (all 4 wave-3 pkgs touch it)
- tunnel data scan: 26 tunnels (both dirs), exit detection 0 failures, 0 gaps < 60 m
- 17:28 run_tests full #1 DONE (1 of 2 used): 762 unit tests, 2 red: test_engine3_checks thread (audio, load) and
  test_chunk_services threaded count (flaky: head 0/6, base 1/6 red when repeated alone) – not R4; all CHECKs OK incl.
  check_light_cap deckel, check_modern_stage kern_zeit, sight, path
- scan: 64 stages snow banks 2517 chunks, 0 errors, max 0.351 m; tunnels ok
- sight --full OK (F1 0 cases/99.4M, F2 0.596, F3 0/5923, F7 0), path --full OK (267.6 m, 2064 m)
- unit mutations: U1 U2 U3 U4 U6 U7 caught; U5 (after-glow cliff) NOT caught; U8 no unit test for bank height; U9 pending
- pictures h_N1, h_N2N looked at (N1 better: snow+banks; car yellow brighter than sprite amber; N2N GT grey-silver
  p75 +10 %, sat 0.78x vs Arcade; HIGH: red column above a far car at N2N 4 s = rear-lamp streak quad horizontal, floats
  in the air when the road ahead climbs – crops/N2N_far.png; confirming with x_streakoff (STREAK_GAIN 0 in mut copy))
- queue1 killed at h_N1deck (never edit queue.sh while it runs!); resume2.sh -> queue2.log continues
- x_streakoff CONFIRMED (red column gone with STREAK_GAIN 0): deliver/QA-R4/bilder/B1_*.png
- h_* all looked at: N1 better; N1deck ok; N2N better (rain) but GT grey-silver, red column (B1); TEXIT equal (no veil;
  after-glow ok by numbers); DEV car vivid blue sat 1.3-1.5x, L 0.86x; C1 equal+; DAWN/DUSK sun disc both, car L +10 %
  sat 0.86-1.05x; OVC clearly better
- merge-tree: R4+FIX-M2 only goldens conflict; R4+R5 docs/renderer-modern.md + golden; R4+R6 goldens
- HIGH B2: wet road in the low beam at night 1.77x Arcade (N2N median 108 vs 61, base 59), marking Weber contrast
  2.93 -> 1.31; N1 dry 1.08x, DEV dry 1.18x -> wet sky mirror (sky/ambient as albedo) is multiplied by the headlight;
  picture deliver/QA-R4/bilder/B2_*.png
- base N1/N2N: head better except new artefacts; GT silver also in base (pre-existing); N1 jagged shadow edge pre-existing
- base pictures all done & looked at (DEV: base car 0.49x Arcade -> head 1.09x, sat 1.38x; TEXIT head over-exposed
  opening like Arcade, after-glow at 3.8 s washes sky white; DAWN/OVC head >= base)
- R4 clip f6.2 s shows the red column too (bilder/B1b_*)
- 19:14 queue3 (after2.sh): rc_check_night OK 4/4, rc_check_weather OK 5/5 (numbers = R4's)
- bericht.md skeleton with @@placeholders@@ in deliver
- rc_check_vehicle_lights OK 4/4 (F6 N1: +0.090 L, +0.239 red), rc_check_start_km0 OK 3/3, rc_check_light_base OK 2/2
- after4.sh started (queue4.log): waits for AFTER2 DONE, then x_b2fix (fix prototype of B2 in mut copy), then golden.sh check
- report pieces: bericht_bilder.md, bericht_befunde.md (B1, B2 written) in $S
- rc terrain_cover 7/7 (K1 0.000 %), occlusion 2/2, tabelle OK (rain 22h 0.97x / contrast 1.17x), tabelle_schnee OK
- report pieces: bericht_rest.md (sections 2-5), bericht_befunde2.md (B3-B9) in $S
- warm cold deck: N1 head OK (443 var, 0 in drive) / base FEHLER (3 var at 4.6 s); N2N head OK / base OK;
  render() 2.149/1.965 ms N1, 1.928/2.027 N2N; commit max 1.27/1.14, 1.01/1.04 ms; draws 72/64, 82/79; tris 99.5k/85.7k, 91.8k/92.0k;
  prep 64/55 s, 72/59 s
- 19:56 render mutations R1-R4 running (queue3.log), then after4: x_b2fix, golden
- render mutations: R1 caught (-2.9 %), R2 caught, R3 NOT caught (bank geometry 0.78 m), R4 caught (0.927 m)
- 20:0x after4: x_b2fix then golden check (queue4.log)
- x_b2fix prototype: cone 54 (Arcade 61, base 59, head 108), marking weber 3.30 (Arcade 2.93, head 1.31) -> fix works
  deliver: bilder/B2b_*.png, b2_behebung_probe_road_gdshader.py
- 20:07 golden check running (logs/golden_check.log)
- 20:18 golden.sh check: arcade 20/20, arcade-ui 17/17 identisch
- 20:20 deliver/QA-R4/bericht.md assembled (assemble.py), pictures in deliver/QA-R4/bilder; base/mut copies and caches deleted
## STATUS: FERTIG – only the StructuredOutput result remains
## doing (old line below is done)
- queue2.log: x_streakoff h_N2Ndeck h_TEXIT h_DEV h_C1 h_DAWN h_DUSK h_OVC b_N1 b_N2N b_TEXIT b_DEV b_C1 b_DAWN b_OVC
## next (queue order)
- queue.sh scan sight path  h_N1 h_N1deck h_N2N h_N2Ndeck h_N2 h_C1 h_DEV h_DAWN h_DUSK h_OVC h_TEXIT h_KBNS  b_N1 b_N2N b_N2 b_C1 b_DEV b_DAWN b_DUSK b_OVC b_TEXIT
- rc_check_night rc_check_weather rc_check_weather_tabelle rc_check_weather_tabelle_schnee rc_check_vehicle_lights rc_check_start_km0 rc_check_terrain_cover rc_check_light_base rc_check_occlusion
- w_N1_head w_N1_base w_N2N_head w_N2N_base (cold cache, deck preset, perf)
- mutate.py U1..U9 then R1..R4
- golden.sh check LAST (once)
## findings so far (candidates)
- after-glow position-based (persists when the car stands within 60 m behind an exit) – low
- spray alpha up to 0.65 vs Arcade 0.28 over tail lights in rain at night – check pictures
## pitfalls
- QA_M2_FERTIG exists -> nice -n 10; disk ~6 GB free
- Bash tool refuses heredocs with git; use Write tool for files
