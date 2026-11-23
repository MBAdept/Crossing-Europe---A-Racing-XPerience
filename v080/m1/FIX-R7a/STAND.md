# FIX-R7a STAND
- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-8
- Branch: worktree-wf_ba4424b4-294-8 (push to origin wip/v080-fix-r7a after each commit); head 266b142 (code final
  unless gates fail; only docs/report left)
- Helpers: sh/ut.sh, sh/cs.sh, sh/common.sh (shot/occl), sh/patch_props.py <tree> A|B, sh/realbuild_runs.sh,
  sh/dumpdiff.py <dump>, sh/tri.py (sheets), sh/stage.sh (perf), sh/queue1.sh (B6 pics), sh/queue3.sh (B12),
  sh/queue2.sh [a|b] (gates; marks in done/, rerun continues). Background jobs max 2 h each!
- Scratch trees: pfix (HEAD + props patch B; queue3 sets PUSH_MAX 12), base (509bb16 for perf). Delete at end.
- Git: Bash refuses heredoc+git in one call: write msg with Write tool, then plain git commands one by one.

## Done (commits pushed)
- f465c38 exact envelope + fences (QR7a-05); 3195350 streamer/warm (QR7a-02/03); 24e37df ENV_MARGIN;
  a50cc08/8f0e83f props_footprint check + conservative max between rows; 266b142 docs 5.3.
- Measured: realbuild head fences 60,473/79,662 (75.9 %); pushB2 (cap 6): props 217,517, vs base +23,540/-191,
  vs R7a +1,708/-794; footprint --full head 5,728 FEHLER, pushB 0 OK.
- Pictures B6: Muenchen (row kept), T4 (rock group kept), C1 (R7a's brick house gone: depth 8.2/10.6 m > cap 6).
- Deliverables: deliver/FIX-R7a/props_hinausschieben.diff, patch_props.py, vergleich/*.jpg

## Update 06:20
- B12 (cap 12 m) chosen: 218,103 props, vs base +23,943/-8, vs R7a +1,711/-211, footprint 0; C1 occl 6/16/18 (B6 same);
  pictures C1/München/Bern b12 viewed (C1 corner house back, pushed). patch_props.py + diff updated to cap 12.
- pfix deleted. Docs committed 4a43944. Gates: queue2 a running (bg), then `bash sh/queue2.sh b`, then `bash sh/queue2.sh`.
## Doing (old)
- queue1 (B6 pics Belgrad T2 Hannover S0 + occl C1 T4 T3) -> queue3 (B12: realbuild, footprint, C1/Muenchen/Bern pics, occl C1)
- then: bash sh/queue2.sh a (bg) ; bash sh/queue2.sh b ; bash sh/queue2.sh (render checks)

## Next
- decide cap 6 vs 12 from pictures; update diff + docs + bericht accordingly
- bericht.md, StructuredOutput

## Pitfalls
- test_props oracle (_expected) uses corridor_width + floor rule: in_bend_corridor semantics unchanged on purpose.

## Update 07:20
- Gates done: import, check_scripts 333/0, sight --full green (exact envelope 0 short), path --full green, perf runs
  (stage/*.log), golden check 20/20 + 17/17, modern-check 2/6 (same 4 as R7a; vs R7a render only s4_mittel 7 px).
- running: queue2 b (run_tests). Next: `bash sh/queue2.sh` in bg for render checks (marks skip the rest).
- bericht: §1-7, 9 written; §8 gates + acceptance to fill.

## FERTIG 08:45
- All gates green on 4a43944 (run_tests 811/0, render checks 28/28, golden 20/20+17/17, modern 2/6 as R7a, sight/path full).
- bericht.md complete in deliver/FIX-R7a. Scratch trees deleted. Nothing left but the result.
