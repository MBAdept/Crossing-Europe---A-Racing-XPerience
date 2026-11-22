# QA-R7b STAND
Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-4 (branch worktree-wf_ba4424b4-294-4, ff to 2c154bc, .godot copied + imported)
Base copy (git archive 9b02f05 + .godot, imported): m1/QA-R7b/base
Mutation copy (git archive 2c154bc + .godot): m1/QA-R7b/mut  (mutate.py restores every file after each mutation)
Scripts: m1/QA-R7b/sh/  Gate logs: m1/QA-R7b/gates/  Pictures: deliver/QA-R7b/raw (batch_pics.sh, abc.sh)
Done:
- contract/report/code read; diff stat (13 files; check_minimal_structures.gd foreign, reported by R7b)
- data scan all 128 directions, 143 landmarks: rep/set/scale/tint = Arcade, 0 deviations; builds headless OK (scan_landmarks.log)
  max anchor offset 37.8 m (Magdeburger Dom, leipzig_magdeburg__leipzig, mirrored church) = 44.7 px at 600 m (< 64) - report says 24.7 max
- run_tests.sh FULL: passed (945 s), check_landmarks 6/6, test_landmarks 8/8 (gates/run_tests.log)  -> do NOT run full again (max 2)
- mutations: 16/16 caught (mutlogs/mutate.log, mutate_render.log); M11 church cases stay inside 64 px (only Burgos trips)
- perf (gates/perf_*_deck_12.log): run_stage deck kiel_hamburg/bremen_dortmund head=base ERGEBNIS identical, render avg same; backdrop max head 3.0/4.3 ms vs base 0.56/1.43 (noisy, load 10)
- lm_cost deck (gates/lm_cost_deck.log): +2..+4 draw calls, +134..+4193 prims per arrival; high probe killed (time)
- flood_bremen_22 (40 m) shows huge church side wall in Modern base+head (model 28x73x92 m), not R7b-specific; flood factor gives only +4/255
- fairness --full: modern_sight F1/F1_lanes/F2/F3/F7/model OK (139 s), path_check OK (61 s) (gates/modern_*_full.log)
- mutations M16/M17 (floodlight removed in shader): NOT caught by any test (mutlogs/mutate_flood.log)
- Bremen 400 m night (flood2_bremen_22): church tower ~63 px right of Arcade (unmirrored), floodlight R7b R+10 over base, near Arcade
- FINDING Elbphilharmonie 22h (hamburg_22): facade mean lum Arcade 112.7 / base 116.2 / R7b 144.5 (+28%); cause likely CE_PICTURE mixes light layer in LINEAR space (Arcade blends sRGB)
- Dortmund/Madrid/Calais day: R7b 3D shapes clearly better than base fallback, close to Arcade
- FINDING Dortmund 22h: aviation light red px Arcade 10 (4x4) vs R7b 232 (17x19), tower +50 px right at 600 m
- arr 12/22 done (10 cities), near 12/22 hannover/leipzig/belgrad done; FINDING Leipzig near: dome hidden behind tree in Modern (dome 25 m behind anchor)
- queue/30_final.sh = render subset (landmarks_render start_km0 terrain_cover light_base props_render occlusion) + golden check -> gates/rc_*.log, golden_check.log
- bericht.md sections 1-4.3 written; still: deck, sky S1/S4/S5/Kassel, findings §5, contract §6, notes §7, sheets (sh/sheets.py; delete dummy 5-byte *_abc.jpg first)
- render subset 6/6 OK (gates/rc_*.log); golden 20/20 + 17/17 (gates/golden_check.log)
DONE: all pictures, sheets (deliver/QA-R7b/boegen), bericht.md complete; base/mut copies deleted. Only StructuredOutput left.
NOTE: never edit batch_pics.sh while a batch runs (bash re-reads it; broke once). Dummy *_abc.jpg = skipped positions (delete before sheets)
Next: pictures batch_pics.sh (arr, near, flood, deck, sky); lm_cost.gd perf (deck/high) + run_stage head vs base; modern_sight --full, path --full; render checks; golden check last; bericht.md
Suspicions to verify in pictures: (a) props/church landmark at night: CE_ATLAS flood multiplies LIT albedo (no emission) -> maybe not floodlit like Arcade; (b) aviation light size; (c) proc_key uses height*scale while mesh is built from height only (latent cache collision, low)
Pitfalls: disk ~5.8 GB free; Bash refuses compound cmds -> scripts in sh/
