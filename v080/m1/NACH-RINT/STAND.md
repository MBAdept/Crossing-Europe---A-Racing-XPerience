# NACH-RINT STAND
Worktree head: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-5 (branch worktree-wf_9927a373-337-5, ff 3248211, no commits)
Base worktree (9b02f05, detached, mine, delete at end with `git worktree remove --force`): m1/NACH-RINT/base
Done: setup, import OK; diff read (environment_rig, tunnel, chunk_streamer, layers, materials, station, benchmark, perf_probe)
Doing: queue m1/NACH-RINT/jobs1.txt via sh/q.sh (log q.log; outputs ab/, clips/); *.done markers make it resumable
Next: tests diff review, B-02 mutation, render checks (tunnel_bridge, structures, night, instance_budget), perf run KH deck ts16 (non-sync), non-sync night shots, golden check, bericht.md
Compare pictures: QA modern (=9b02f05) in m1/QA-RINT-BILD/ab/<ID>_modern_NN.png ; QA clip deliver/QA-RINT-BILD/clips/valik_morgen_schnee.mp4
Pitfalls: disk ~4.9 GB free; other agents load the VM
## 18:40
Queues running (all share heavy.lock): jobs1 (ab/clip), jobs2 (B-02 mutation + unit/race3d), jobs3 (perf day/night KH deck ts16 with shots, render checks tunnel_bridge/structures/night/start_km0/instance_budget/vehicle_lights, golden check).
Restart a queue: nohup sh/q.sh jobsN.txt & (done markers skip finished jobs). Mutation job edits HEAD_W shaders under lock and restores with git checkout: CHECK git status clean after restart!
Results so far: F-05 TS15N zone lum 91.6 vs Arcade 96.4 (0.95x), base 74.7 -> fixed by metric; look still weaker than Arcade's warm volume (deliver F05_*.jpg)
Code review notes: streamer piecewise commit only in threaded mode (all picture tools use --gfx-sync -> flush); props._holders/gantry keep trashed nodes valid 4+ frames (perf() counts them); watchdog B-04 3 frames >1s in countdown -> slow.
## 19:00
- B-02: mutation baked/leaves/billboard -> test_props red each, clean 13/0 green (logs/mut/). fixed.
- unit/race3d 175/0 green.
- F-06 VALN pictures: sports car dark red like Arcade (deliver F06_*.jpg); GT N2N pending.
- perf_kh_day (deck ts16, head): hash = v0.7.0 087ade2e; commit_ms_max 6.51 ms (roadside single builder 6.32) -> B-01 NOT held on this run; trash 69 ms, streamer spike 71.5 ms km 30.27 -> F-08 not improved on VM. shots perf/kh_day_*.png all complete.
- NEW FINDING N-01: lights._reflectors never forgets a part freed without tree_exiting (chunk dropped while COMMITTING, new with B-01) -> SCRIPT ERROR lights.gd:563 every frame with beam on; probe sh/probe_reflectors.gd reproduces (3x SCRIPT ERROR). jobs4: mountain night run to see it in a real drive.
- DO NOT edit sh/*.sh in place while a queue may run them (bash reads incrementally).
## 19:07
- N2N GT head pixel-identical to 9b02f05 (QA) -> GT still silver vs Arcade dark blue-grey -> F-06 partly. deliver F06_gran_turismo_22uhr_regen.jpg
- rc tunnel_bridge 8/8 OK (beacon, B1 water, ausfahrt_schnee white +0.1, snow 0.99x; trocken +1.0)
- N-01 confirmed by probe (3x SCRIPT ERROR lights.gd:563); only reflectors miss the is_instance_valid guard (add_lamps paths handled)
## 19:33
- F-01 clip head: white after exit 2.5-3.1 % (Arcade 0.1-0.3, before 65-68 %), switch in the same frame as Arcade (4.047), no brown frames -> FIXED. deliver F01_*.jpg + clip.
- N-02 (pre-existing, low): glare quad's top/right edge visible 3 frames before exit (3.997-4.030) in head and 9b02f05 (deliver N02_*.jpg)
- mtn night run (saragossa km150-end, ts16, threaded): 0 errors, commit max 1.98, trash 57.5 ms, no N-01 trigger observed
- remaining queue: runner1 VALD, VALD base, S0, KBN, S4; runner3 rc_structures, rc_night, perf_kh_night_arcade, perf_kh_night, rc_start_km0, rc_instance_budget, golden
- bericht.md only skeleton so far
## 20:05
- rc_structures OK (tankstelle zone 0.87x, countdown lamps OK), rc_night OK (sportwagen 1.01x/1.21x, GT 0.92x/0.77x)
- VALD dry exit: base 31 % white at 3.9 s -> head 3.0 % (Arcade 1.5 %); deliver F01_valik_trocken_ausfahrt.jpg
- bericht.md: sections 0 written, rest ABSCHNITTE_FOLGEN placeholder
## 20:22
- S0 head pixel-identical to 9b02f05 (car visible in countdown) -> deliver TB1_start_auto_im_countdown.jpg
- perf_kh_night: hash 67695b6b = arcade night ref, 0 errors, commit max 4.23 (road 4.16), trash 25.5, streamer spike 27.3 ms; shots OK (lamps, bridge, water)
- report: section 1 written; still to write: N-01/N-02 findings, test-build-1 items, gates, contract notes, notes_for_next
## 20:37
- KBN, S4 head pixel-identical to 9b02f05; rc_start_km0 OK (kamera, auto, boden). jobs1 done.
- pending: rc_instance_budget, golden (runner 3); then finish bericht (gates section, contract notes), remove base worktree, StructuredOutput
## 21:01 – FERTIG
- all gates done: rc instance_budget OK (wald 222/230), golden 20/20 + 17/17. Worktree clean at 3248211. Base worktree removed. xdg/mesa/tmp deleted.
- bericht.md complete in deliver/NACH-RINT; remaining step: StructuredOutput.
