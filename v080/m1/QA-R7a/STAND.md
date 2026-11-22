# QA-R7a STAND

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-5
Branch: worktree-wf_ba4424b4-294-5, ff-merged to 509bb168 (R7a head). Import done.
Base copy (git archive 9b02f05 + .godot, imported): m1/QA-R7a/base (delete at end, ~600 MB)
Scripts: m1/QA-R7a/sh/common.sh (pos_args, shot), sh/queue1.sh (log queue1.log, logs/sight_full.log, logs/path_full.log)
Pictures: deliver/QA-R7a/r7a/ and deliver/QA-R7a/basis/

## Done
- setup, contract read (§2, §5, A-1..A-11, §11.3 A-17..A-22), R7a report read, code read (sight_corridor.gd, terrain_profile, chunk_context, streamer, border, city diffs)
- ownership/merge: R7a ∩ FIX-RINT -> CONFLICT in chunk_streamer.gd (merge-tree), saved m1/QA-R7a/merge_streamer_fixrint.gd;
  also overlaps test_props.gd (R7c+FIX-RINT), test_structures.gd, test_chunk_streamer.gd (FIX-RINT) auto-merge; docs/renderer-modern.md (R7b, FIX-RINT) auto-merge
  R7c head 965b8a9 props.gd still calls in_bend_corridor(z, x) WITHOUT reach -> 5,832 intrusions after merge (R7a measured)
  Semantic merge issue: FIX-RINT commit loop partial commits -> R7a's `if done == 0: _warm_corridor` would run in frames with partial commit

## Doing now
- queue1 running (sight/path full, then high-day pictures mine + 4 base)

## Next
- probes: streaming vs full-path corridor determinism; mutation tests; run_tests; render checks; deck + night pictures; perf; golden check at end

## Pitfalls
- no commits. Heavy jobs nice -n 10 one at a time. git compound commands refused -> one git command per call.
