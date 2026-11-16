# QA-R5 STAND

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4
Branch: worktree-wf_fd1de4ee-28b-4 (ff to 5558bdc = R5 head), .godot copied + imported (ok)
Base for comparisons: 6e484056ec87e2fa614061000a362feb2b5a6db8 (need a second worktree or git worktree add in scratch)

## Done
- setup (merge ff, import)

## Doing now
- reading contract/brief/R5 report

## Next
- ownership diff, pictures, function scan, fairness, tests, perf

## Pitfalls
- QA_M2_FERTIG exists -> nice -n 10

## Update 1 (19:35)
- base tree exported (git archive) + imported: m1/QA-R5/base (577 MB; delete at end)
- queue1 (tools/queue1.sh, log queue1.log) started in background: pictures new (all places), base subset, deck.
  Output shots/new/*, shots/base/*. If restarted: check which *_ab_*.jpg / *_modern_*.png exist and rerun the rest via
  tools/shots.sh <set> <names>.
- Next: code review bridge.gd/tunnel.gd/far_ground.gd; then queue2 = unit tests filter, full scan, mutation, fairness.

## Update 2
- mut copy: m1/QA-R5/mut (577 MB, worktree copy without .git) holds my own scan tests/qa_r5/qa_scan.gd and is the
  target of tools/mutate.py (results mutations/results.json; restores each file after each mutation).
- queue2 (tools/queue2.sh, log queue2.log) waits for QUEUE1_DONE then: qa_scan, R5 full scan, mutations,
  modern_sight --full, modern_path_check --full (logs in m1/QA-R5/logs/).
- Code review notes so far (bridge.gd/tunnel.gd/far_ground.gd): no per-chunk state in build(); props skip OK;
  boats 0.15 m low (props.gd, R4); golden md5 edited outside ownership (W3 "–").
- Next after queue2: queue3 = run_tests full, render checks modern, golden check, perf (base vs R5).
- NOTE: background tasks die after 2 h. queue2/queue3 were stopped while waiting; start each only after the previous
  finished (bash tools/queue2.sh, then bash tools/queue3.sh; their wait loops pass at once when the DONE line exists).
  queue1 may be killed at ~21:20 (uptime clock) – then rerun missing shots with tools/shots.sh.
- tools/crop.py (PIL crops side by side; use instead of crop2.sh), tests/qa_r5/bench_r5.gd copied into mut and base.

## Update 3 (20:52)
- All 14 R5-head A/B shots done (shots/new/*_ab_*.jpg) and looked at. Notes so far:
  * U1/Somport tube better than base & Arcade-equal+ (panels, walkways, niches); road in tube cold grey (R4);
    exit not overexposed (R4). U1 22h and DEV 21h: headwall/wing walls/hill lit by low beam (R5 = base values,
    not a regression; Arcade dark) – R4 spot cut-off; R5 option: hill/portal on GROUND_LAYERS.
  * KB ramp/end/night, Holtenau, B1, Elbbrücken good; stone bridge solid parapet (R4 roadside).
  * kb_top: beacons visible between HUD bars; Arcade+Modern lit in frame 00, dark 01-03 (same phase).
- Next: after base shots, stop queue1 (deck shots move to queue3b), run queue2, then queue3 (gates), then deck+bench+perf.
- 21:10 queue1 stopped after base shots (deck shots in queue4). queue2 started (bvbld2z2r). Base renders = R5's base
  renders bit-identical (u1_innen, kb_rampe); my R5-head renders = R5's delivered renders bit-identical (12 places).
  Sheets in deliver/QA-R5/bilder (tools/make_sheets.sh).
- 21:20 qa_scan: 122 bridges + 28 tunnels (incl. dev), 0 findings (counts = Arcade events; cables >= 2.15 m; nothing
  in lanes < 4.5 m; hill never above approach corridor). R5 full scan OK (52 s). Mutations: 18/22 caught by named
  tests; B10 (night_albedo) only via SCRIPT ERROR float(null); missed: B12 cables count (self-referential const),
  B14 bridge lamps (no test), T4 set_zone guard (no test with an env lacking set_zone). Results mutations/results.json.
- 21:19 queue2 done: modern_sight --full all OK (F1 0 to 270 m, lanes 0 to 260, F2 0.593/0.596/0.555, F3 0, F7 0),
  path_check OK (267.6 m, loops 2064 m). queue3 (gates) started bxlei5r2w. Then queue4 (deck shots, bench, perf).
  bericht.md draft in deliver/QA-R5 with __PLACEHOLDERS__ to fill.
- 21:36 run_tests full #1: 767 tests, 2 failed (engine3_checks thread, music_checks race) + check_attract (Modern)
  idle 0.90 s – all timing/real-time; retest alone on R5 and base is the first step of queue4.
  Report parts in m1/QA-R5/part_*.md (bilder, befunde, fair, tests); assemble into deliver/QA-R5/bericht.md at the end.
- 21:57 queue3 done: render checks tunnel_bridge/start_km0/terrain_cover(K1 0%)/light_base all OK; golden 20/20 + 17/17.
  queue4 started (ber3jpkco): retest 3 timing failures on R5+base, deck shots, bench, perf (est. ~1.5 h).
- 22:30 retests: attract OK r5+base; engine3 OK r5 / FAIL base; music_checks FAIL r5 / OK base (timing, load).
  deck shots done (+base kb_nacht deck), sheets deck_*.jpg. bench: tunnel build max 5.45 ms (base 0.94), bridge build max
  10.75 ms, commits <= 0.59 ms, far_ground update_rivers <= 1.62 ms (R5's 69.9 ms spike not reproduced as CPU work).
  perf runs (deck preset, KH km76 + U1 km183, r5/base) running in queue4. Next: rerun music_checks r5 alone, assemble bericht.
- 22:50 perf kh_r5 done (timeout at km 94.4, render 2.43 ms avg, commit max 1.98). queue5 queued (beiu1zeka): short
  deck runs with last frame on KB deck / in U1 tube (r5+base) + music_checks again. Then: python3 tools/perftable.py ->
  part_leistung __PERFTABLE__, part_perf_finding.txt, tools/assemble.py, final cleanup (delete base, mut), result.

## FERTIG (23:45)
- bericht.md assembled (tools/assemble.py from part_*.md; template bericht_template.md), 49 pictures/sheets in
  deliver/QA-R5/bilder. base/, mut/, tmp/, mesa/ deleted. Worktree unchanged (5558bdc, clean). Only the final
  StructuredOutput remains.
