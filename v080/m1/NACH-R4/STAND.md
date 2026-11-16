# NACH-R4 STAND
Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7 (branch worktree-wf_fd1de4ee-28b-7, ff to b156763, NO commits)
Base copy (7f0eae2 files over the worktree, imported cache copied): m1/NACH-R4/base (mkbase.sh)
Scratch: m1/NACH-R4/ ; deliver: deliver/NACH-R4/
Scripts: sh/ab.sh <name> <POS> <preset> [args] (head, Arcade+Modern via tools/ab_shot.sh, TMPDIR=m1/NACH-R4/tmp)
         sh/mshot.sh <base|head> <name> <POS> <preset> [args] (Modern only); positions sh/pos.sh (QA-R4's)
## done
- worktree ff b156763; import OK; base copy built
- code review of diff 7f0eae2..b156763 (18 files; R4 W3 files + flare.gdshader + tests/golden modern_slice + docs)
## doing
- sh/queue1.sh (background, log queue1.log): N2N high 2,4,6.2 (head ab + base), KBN rain, C1RN
## next
- measure cone/marking/column (python), look at pictures, compose to deliver/NACH-R4/bilder
- run check_night_nass on BASE copy with head's test files (should FAIL) -> proves checks guard
- gates: golden.sh check once; run_tests.sh full once; render checks: check_night (both), check_weather (3 files),
  check_start_km0, check_terrain_cover, check_light_base, check_vehicle_lights
- B3 measure: check_night -- --only=spielerauto --fall=Turismo
- side effect: ENV_NIGHT_TINT reaches vpbr|static + glass (all static props at night) – compare base/head at night
## pitfalls
- QA_M2_FERTIG exists -> nice -n 10; one heavy job at a time
## Update 02:00
- N2N head ab done: Arcade frames pixel-identical to QA-R4's (AE 0); head Modern = FIX-R4 pics (AE 0) -> deterministic
- measured head N2N 2 s: cone 54 vs Arcade 61 (R4 108), weber rows 3.87 vs 2.73; 4 s red column px (600-680 x 220-308): head 0, R4 168, Arcade 0
- GT body (x560-720,y490-600, L>30): L 46 vs 46, sat 0.365 vs Arcade 0.518 (0.70x; R4 0.324) -> B3 partly
- crops in m1/NACH-R4/crops (b1_4s.png, b1_62s_ah.png, b2_2s.png)
## Update 02:25
- queue1: N2N head+base, KBNR head+base done; C1RN head+base running. queue2 (sh/queue2.sh, setsid, log gates/queue2.log)
  waits for QUEUE1_DONE then: base_nass night weather start terrain lightbase vlights golden tests
  (restart: sh/queue2.sh <remaining jobs>; queue1 parts: sh/ab.sh / sh/mshot.sh)
- B1 measured: column px above far car 4 s R4 168 / FIX 0; 6.2 s R4 793 / FIX 0 (Arcade 0). KBN rain bridge: lamp streaks on deck,
  road ahead Arcade 62-67, R4 88-103, FIX 65-68. sky/pylon rows 0-269 base==head (ENV_NIGHT_TINT on static invisible there)
- deliver/NACH-R4/bilder 01-03 written
## Update 02:35
- queue1 DONE (N2N, KBNR, C1RN head ab + base). bilder 01-08 in deliver/NACH-R4/bilder
- base_nass: check_night_nass on R4 code FAILS (1.73x/0.42x, 1328 px above roof) -> checks guard the real bugs
- C1RN/KBN: rows 0-269 base==head (static props unchanged); road under lamps FIX ~= Arcade
- queue2 running: night weather start terrain lightbase vlights golden tests
- after queue2: head_nass with pictures (sh/rcd.sh head check_night_nass.gd nass), unit-test mutations U5/U8/R3
  (restore the worktree file afterwards with a plain file restore!), maybe golden modern-check
## Update 02:45
- base copy converted to HEAD copy m1/NACH-R4/mut (sh/tomut.sh) – no base tree any more (rebuild: sh/mkbase.sh)
- mutations (sh/mut.py, mut_run.log): U5, U8, R3 (0.897 m), B1prof, B5 caught; U5t equivalent mutant; unmutated pass
- gate night: check_night 4/4 OK (GT 0.92x / sat 0.77x; DEV limo 0.87x/1.00x), check_night_nass 2/2 OK (0.88x/1.19x, 0 px)
- queue2 now: weather start terrain lightbase vlights golden tests; afterwards: sh/rcd.sh head check_night_nass.gd nass (pictures),
  golden modern-check (sh/queue2.sh can't do it – run tools/golden.sh modern-check with TMPDIR + KEEP)
## Update 03:05
- gates OK: check_night 4/4, check_night_nass 2/2, check_weather 5/5, tabelle + tabelle_schnee OK (rain 22h 0.89x / K 0.84x),
  check_start_km0 3/3, check_terrain_cover 7/7 incl. K1, check_light_base 2/2, check_vehicle_lights 4/4 (logs rc/head_*.log)
- bench road_profile 4.2 us/call (mut/tests/nach_r4_bench.gd) -> 100 streaks 0.42 ms (this machine)
- running: golden, then tests (queue2), then queue3 (head_nass pics + modern-check, log gates/queue3.log)
- bericht.md draft in deliver/NACH-R4 (placeholders @@URTEIL@@ @@DETAILS@@)
## Update 03:32
- golden check: arcade 20/20 (202 s), arcade-ui 17/17 (262 s); run_tests full: 319 scripts 0 broken, 765 unit 0 failed,
  149 CHECK OK, "Tests bestanden (950 s)" (gates/tests.log)
- head_nass with pictures OK (rc/pics_head_nass); bilder 09, 10 written
- running: queue3 modern-check (gates/modern.log, keep gates/modern_keep) – then assemble bericht from m1/NACH-R4/details.md
- cleanup at the end: rm -rf mut xdg tmp mesa_* (keep shots/crops small)
## DONE 03:55
- modern-check 6/6 identisch + gles OK; bericht.md assembled (deliver/NACH-R4/bericht.md, bilder 01-10)
- cleaned mut/xdg/tmp/mesa; worktree clean at b156763; only StructuredOutput left
