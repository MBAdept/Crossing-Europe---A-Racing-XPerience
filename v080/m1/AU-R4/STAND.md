# AU-R4 STAND (handover)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-4
- Branch: worktree-wf_15398915-ab3-4 (push target: origin wip/v080-au-r4, plain push after every commit)
- Base: b6339ad (AU-R3 head), fast-forwarded; .godot copied and imported (OK).

## Done
- a28bfa2 tests H1-H4, M2, L3 (M31/M32) in test_road_audio.gd. Mutations before: 12 not caught
  (res/mutations_before.json). Values: tools/verbose_tests.gd.
- 8681128 + f34ca1e M1-CODE: audio_feed.gd cobbled_blocks(skip, paved, late): stone bridges = cobbled street
  ("heard" definition), stage tunnels = late (_closer only if out of band), _closer for every centre; tests in
  test_audio_feed.gd (3 new). Reviewer method kc_trigger.gd: res/trigger_after.log/.json: heard out 14 -> 3
  (Barcelona x2, Ljubljana x1: 0.549 in the 1-m grid, allocated exactly 0.550); street-only out 22 -> 26 (by
  definition); 114/128 plans identical, Kiel-Hamburg identical. Exact metres: tools/cobble_alloc.gd ->
  res/cobble_alloc_after.log (0 of 100 out). Both readings at once impossible for Dresden, Tours, Saragossa,
  Toulouse (tools/both_bands.py) -> contract issue.
- dba0b1c M1-MESS: truck.heavy -11 -> -11.5 (config); runs mess/truck_*.json + mess/boot.py: -11: 2.78/2.72, pooled
  2.78 (boot 14 %); -11.5: 2.13/2.51, pooled 2.34, TP max -1.39 (boot 2 %). Docs 15.12, 15.11, 15.8, 12, 8, L2.
- f253687 docs: final mutations 40/40 (res/mutations_final.json). Preview note appended to
  deliver/AU-R/aufprall_abwechslung_neu.txt (original copy: aufprall_abwechslung_neu.txt.orig here).
- Report body drafted: bericht_body.md (placeholders <<GATES>>, <<GATESDETAIL>>) -> deliver/AU-R4/bericht.md.

- Gates DONE: run_tests 662/0, 92 CHECK OK, 623 s (logs/run_tests_final.log); golden 20/20 (logs/golden.log);
  arcade_lean OK; frozen paths 0 changes. Report: deliver/AU-R4/bericht.md (final), pruefung_*.txt there.

## Doing now
- nothing left but the StructuredOutput (package AU-R4, branch wip/v080-au-r4, HEAD f253687).

## Pitfalls
- Heavy jobs nice -n 19, one at a time. Mutations run IN the worktree: after a restart during tools/mutate.py, run
  `python3 tools/mutate.py --restore` (marker dir mut_inflight/) or check `git diff`.
- The Bash tool refuses heredoc + other commands in one call: write scripts to files.
