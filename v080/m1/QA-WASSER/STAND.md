# QA-WASSER STAND – FERTIG (09:40 UTC)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-2
Branch: worktree-wf_bdb6e1e1-c64-2 (ff-merged to 0ad9012353855295255c27dd987b90e30ff0f33f), nothing committed, clean.
S = /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
D = /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-WASSER

## Result
- Report: D/bericht.md (composed by S/tools/compose.py from S/bericht_draft.md, bericht_body.md, bericht_befunde.md,
  bericht_ok.md). Pictures: D/bilder (37 files, S/tools/deliver_pics.sh).
- Verdict: build may go to the user. Water fix works in Linux and Windows exports (pixel-identical), golden 20/20 +
  17/17, terrain_cover OK, unit test catches 4 mutations, PCK = 0ad9012 (repro), only far_ground.gdc changed vs ZS1.
- Findings: B1 medium landmarks missing in 6 cities (proc-only landmark_sets); B2 medium pylons glow at night / feet
  washed out; B3 low no quay walls/embankments; B4 low docs (Bergetappen, Windows "-- --graphics=arcade",
  SHA256SUMS, 3 honest sentences); B5 low check_terrain_plan dump old rule + no render check at water.

## Done (all steps)
1 delivered files, 2 Linux export pictures (29 runs), 3 Wine (4 runs), 4 code/mutations/golden/render/baseline/repro,
5 docs, 6 report. Cleanup of large scratch items done (build/, lin/, win/, xdg/, wine/, mesa caches, worktree .godot).

## Pitfalls
- 1 stage km = 100 m path on Kiel-Hamburg: the plane drop happens at km 67.1, not near km 76.5.
- Export frames != project frames (export starts via --stage=, project starts race.tscn; A-2) -> compare like with like.
- cover_measure horizon detection fails when buildings cover the sky -> use fixed horizon row (324 at 1280x720).
- wineboot/wineserver not in PATH here (/usr/lib/wine/), wine64 works without them.
