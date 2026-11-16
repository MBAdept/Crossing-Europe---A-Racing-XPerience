# NACH-M2 STAND
Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-6 (branch worktree-wf_438996b0-243-6, ff to 515dd51, .godot copied + imported clean)
Base tree 6e48405: m1/NACH-M2/base (git archive + .godot, imported clean) -- delete at end (~600 MB)
## done
- ff merge 515dd51, import; diff 6e48405..515dd51 read (20 files, no frozen file); FIX-M2 bericht read
## doing now
- sh/q1.sh (setsid) vehicle probe head/base h12/h22 + player paint -> shots/veh, log logs/q1.log (Q1-DONE at end)
## next
- lightcount (FIX-M2 sh/lc.py, TAGS) vs arc/zs1 shots in m1/FIX-M2/shots/veh; paintbox
- ab_shot S0 start / S4 Köhlbrand day / pylons night: head vs base vs Arcade
- gates: render checks vehicle_lights, vehicle_standin, instance_budget(_wald); headless check_seam, check_vehicles; unit filters; run_tests.sh once; golden.sh check once (end)
- bericht.md in deliver/NACH-M2
## pitfalls
- load ~16-17; one heavy job at a time
## 15:30 update
- q1 (veh probe), q2 (ab shots, waits Q1-DONE), q3 (gates: rc vehicle_/light_base/start_km0/showroom_render/instance_budget, run_tests full, golden check; waits Q2-DONE) all started with setsid. On restart: just restart q1/q2/q3 (idempotent: veh skips by QA-VEH-END, shots skip by png, gates skip by STEP-END).
- h12 traffic probe: head pictures bit-identical with FIX-M2 fx1 (d20a..d60b); lc.py numbers in bericht (police 60 m day 153, brake sports 60 m day 11 vs Arcade 34).
- cmp/ dir: symlinks to FIX-M2 shots arc/zs1/m2 + mine nm2 -> TAGS="arc_h%s,zs1_h%s,m2_h%s,nm2_h%s" python3 m1/FIX-M2/sh/lc.py cmp 12
- later: mutation test check_vehicle_lights (SPOT_SPECULAR 0.6 + gains 1.0, --only=blaulicht,abblendlicht) then git checkout files + git status clean
## 15:22
- q4 started (after Q3-DONE: golden modern-check, then MUTATION of lights.gd/vehicle_pose3d.gd + check_vehicle_lights --only=blaulicht,abblendlicht).
  PITFALL: if interrupted during mutation -> git checkout -- scripts/race3d/layers/lights.gd scripts/race3d/vehicle_pose3d.gd ; git status must be clean.
- measured so far: B-03 fixed (day 60 m blue 153 vs ZS1 114/Arcade 182; night 103 vs ZS1 76/Arcade 184), B-05 fixed (truck rear 60 m lum 45 vs Arcade 42; 20 m 57 vs 51), B-04 day sports 60 m 11 vs Arcade 32 (partly), night brake 60 m ~2x Arcade (new low finding).
- base 6e48405 probe = QA M2 pictures bit-identical; head = FIX-M2 fx1 bit-identical.
- ZEITLIMIT test: RENDER_CHECK_TIMEOUT=15 start_km0 -> "ZEITLIMIT (Exit 124)", script exit 1 (logs/zeitlimit_test.log)
- pictures so far: deliver/NACH-M2/bilder/fahrzeuge_{nacht,tag}_20m_60m_arcade_zs1_vorher_fixm2.jpg
## 15:45
- q1 done. B-06 measured (paintbox QA tool, box 520..760 x 450/480..690/700, player_nobrake): limousine 12h Arcade .583 / vorher .731 / head .634 / +R4 .631; sport 19:30 .493/.617/.585/.561; kompakt 22 snow .721/.950/.950/.755 -> partly (day ok, dusk +19 %, night unchanged on head).
- M2S-04 throwaway test: FAIL with "Skriptfehler im Test" (logs/m2s04_test.log), file deleted. M2S-05 mutation (no water term): test red (logs/m2s05_mut.log), restored, git status clean.
- S0 start: car present in countdown and at LOS+4.5 (bilder/S0_start_km0_...jpg); start oak missing (B-01).
- merge-tree 515dd51 with r4/r5/r6: only tests/golden/modern_slice.{md5,env} conflict.
## 16:25
- q2 done: S0/S1/C1/N1/KBT/KBN head pictures; diffs vs base only in the player car (S0,S1,KBT), plus C1 facade (max 10/255) and KBN deck/pylon legs/car ahead (all darker, SPOT_SPECULAR). Water under bridge OK, pylons at night unchanged mean lum, car at start OK. B-06: S1 .732->.635 (Arcade .583), C1 .617->.584 (Arcade .509), N1 .944 unchanged (Arcade .719).
- props probe head T4 9/12 dropped, S0 oak dropped – identical to base (fair/).
- bilder: S0_..., S1_C1_N1_..., KBT_..., KBN_... in deliver/NACH-M2/bilder
- q3 gates running now.
## 16:35
- rc_vehicle: 2/2 OK (vehicle_lights 6 checks incl blaulicht 310/1061, abblendlicht 0.5 %/0.25, 0.1 %/0.17; standin 6 checks all compare). Log logs/gate_rc_vehicle.log
- bericht draft: deliver/NACH-M2/bericht.md (placeholders), m1/NACH-M2/befunde_teil.md (table)
## 17:00
- render gates all OK: vehicle_lights, vehicle_standin, light_base, start_km0 (auto 193x192 vs 192x192), showroom_render, instance_budget (100 s, veh <=128, scene <=142, 322 s), instance_budget_wald (20 s, veh <=38, scene <=51 (!), 456 s = load 53 + drive 400).
- NEW finding: wald check now only reaches scene 51 / vehicles 38 (before 142/127) -> no longer loads the budget at high.
- run_tests running, then golden check, then q4.
## 17:20
- run_tests.sh full (1 of max 2 used): 751 tests, 2 red (test_engine3_checks thread, test_music_checks race) + check_attract Arcade "idle Demo 0.94 s (idle_s 1)"; everything else green incl. check_seam (rueckfall_dateien), check_vehicles leistung, modern_sight F1/F2/F3/F7, modern_path, kern_zeit. Log logs/gate_run_tests.log
- q5 started (after Q4-DONE): reruns of the 3 red cases alone on head and base -> logs/q5.log
- golden check running now (q3), then q4.
## 17:35
- golden check: GOLDEN arcade 20 von 20 identisch (311 s), arcade-ui 17 von 17 identisch (464 s). Q3 done. golden_keep dir can be deleted at end.
- q4 (modern-check, then mutation) running; q5 reruns after.
## 18:05
- golden modern-check: GOLDEN modern 6 von 6 identisch (1472 s); modern-gles OK max 2/255 PSNR 73.2 dB.
- mutation running (q4); if interrupted restore lights.gd and vehicle_pose3d.gd from HEAD (checkout), status must be clean
- bericht.md mostly written; placeholders RERUN MODERNCHECK MUTATION left
## 18:15 FERTIG
- all gates done; reruns: engine3 red on head and base, music green head/red base, attract green both.
- bericht.md complete (no placeholders); bilder 13 files in deliver/NACH-M2/bilder.
- base tree, keep folders, mesa, xdg deleted. Worktree clean at 515dd51. Only remaining: return StructuredOutput.
