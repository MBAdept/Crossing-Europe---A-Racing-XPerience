# FIX-RINT – Stand

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-4
- Branch: worktree-wf_9927a373-337-4 (push: origin HEAD:refs/heads/wip/v080-fix-rint)
- Base: 9b02f05 (ff ok), .godot copied, import clean.
- Helpers (sh/): ab.sh (ab_shot, TMPDIR/Mesa/XDG in scratch), mshot.sh (Modern only), rc_one.sh (one render check),
  tri.sh (labelled sheets), region.py/warm2.py/lumtrace.py (QA), after_shares.py, snow_metric.py, carbody.py,
  stage_hash.gd (QA driver), q1/q2/q3.sh queues, patch_*.py (applied patches)

## Done (commits)
- c6348fa F-01 rig weather + after-glow law; tunnel_bridge exit_after check; B-02 tint guard
- 05156b8 exit ramp ends at portal (rig + tunnel), cam+1 decisions; streamer commit budget (B-01) + commit_by;
  flares/lights wait for out-of-tree parents; benchmark fields; watchdog B-04; census B-05; B-06 comment
- f2d64f2 station shop glows WIP (F-05), canopy_job_rest resumable (B-03), renderer spikes (F-08)
- 3628eab station glows halo 1; tankstelle zone check; check_night 2 new car cases; docs §18
- F-01 verified: rc_exit3 all OK (schnee white +0.1, snow 0.99x; trocken +1.0); A/B shots f01_base vs f01_fix,
  sheets in deliver/FIX-RINT/F01_*.jpg
- F-03 S0 oak: dropped by "corridor" (A-17 band) -> R7, probe evidence. F-07: no high-rise sprite in track
  km 220.95–221.8 (only 2 trees + 6 objects) -> Arcade draws it elsewhere (city/skyline) -> R7.

- c9b1070/cc92991 F-06 sportwagen night (desat/value/fill per set) -> check 1.01x/1.21x; red-safe mask in check
- F-05 station: zone 0.95x Arcade (ts15n_v3); sheets deliver/FIX-RINT/F05_*.jpg, F06_*.jpg
- 0ef122e streamer: delayed piecewise free (F-08: spikes were in "free" 141.7 ms; trash free 134 ms w/o delay)
- stage runs: logs/stage_kh_deck{,2,3}.log (commit max 3.24/2.53/2.01 ms; Rule 3 digest 087ade2e = v0.7.0)

- 3248211 flares: in-tree flag moved to index 10 (STATIC_SEEN; index 8/9 = _lamp_profile cache) – fixed SCRIPT ERROR
  bool(e[8]) of run_tests1 (check_light_cap, check_benchmark, attract scenes Modern; all three green alone)
- stage runs 3/4: commit max 2.01/2.11 ms; trash 133.8 (run3) -> TRASH_DELAY 4 -> run4 trash 57, path 49.6 (VM noise)

## Gates (final head 3248211) – DONE
- run_tests #2: all hook checks green; 804 unit tests, 2 failed (engine3 thread, music race: load 13) -> both green alone
- golden check 20/20 + 17/17; modern-check 6/6 (+GLES OK) -> no modern-make; render checks all 28/28
- bericht.md complete (deliver/FIX-RINT); large scratch (shots, xdg, mesa, tmp) deleted at the end

## Doing now (old)
- q1: spielerauto check (logs/rc_night_car1.log), q2: TS15N v2 (shots/ts15n_v2), q3: KH deck stage budget
  (logs/stage_kh_deck.log)

## Next
- evaluate F-05 v2 (target zone >= 0.85x Arcade: QA arcade 96.4), F-06 numbers -> tune or list
- gates: run_tests full, golden check, modern-check (+make after looking), render checks all, bericht, result

## Pitfalls
- XDG_DATA_HOME absolute under scratch for EVERY run (export in helper scripts!)
- git: plain separate commands only (no chained git in one Bash call); heredoc python with "git" words refused -> use files
