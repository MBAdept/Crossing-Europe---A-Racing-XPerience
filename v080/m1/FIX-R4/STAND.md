# FIX-R4 STAND
- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-5
- Branch: worktree-wf_fd1de4ee-28b-5 (push to origin wip/v080-fix-r4), head 3f00551 (pushed)
- Base: 7f0eae2 (R4 head); base tree copy for comparisons: m1/FIX-R4/base (imported)
## Done (all committed + pushed)
- B1 streak on road profile; B2 lamps light diffuse only; B5 weather quality_lowered; B6 after-glow ≤ 2 s; B8 glare first;
  B4: check_night_nass.gd (nass_kegel 0.88×/1.19×, spiegelung 0 px; mutated: 1.73×/0.42×, 1207 px → both FEHLER),
  schneewall mesh height, exit ramp continuity, unit tests (race3d 136/136)
- B3 partial (ENV_NIGHT_TINT 0.8: GT sat 0.73→0.77×, 1.0 → 0.78×, so not the sky; open), B7 sheen_wash 0.35 (DEV limo
  sat 1.00× in check), check_night spielerauto DEV case + CAR_SAT_MAX 1.25 + --fall filter
- docs 15.2/15.4/15.6/15.7/15.9
## Doing
- sh/pics.sh (Modern pictures into m1/FIX-R4/pics, log pics/pics.log); Arcade pictures = m1/QA-R4/shots/head/*_arcade_*.png
## Next (gates, one at a time, nice 10)
- golden.sh check; golden.sh modern-check (s1_nacht expected to change → look, modern-make, commit);
  run_tests.sh full; modern_sight --full, modern_path_check --full; sh/stage.sh head <wt> and base m1/FIX-R4/base;
  run_render_checks.sh all; clips N2N + TEXIT (tools/ab_clip.sh, see m1/R4/sh/clips.sh); bericht.md in deliver/FIX-R4
## Pitfalls
- don't edit shader files during the first ~5 min of a run
## Update 22:05
- pics done (m1/FIX-R4/pics), composed into deliver/FIX-R4/bilder 01–13; report draft deliver/FIX-R4/bericht.md +
  m1/FIX-R4/details.md (merge into bericht at the end)
- gates queue running (sh/gates.sh, log gates/gates.log): golden 20/20 + 17/17 identisch DONE; modern-check running;
  then sight, path, stage_head, stage_base, tests, render
- after gates: modern-make if only s1_nacht changed (look first), clip N2N (tools/ab_clip.sh), finish bericht
## Update 22:35
- head b156763 pushed (modern_s1_nacht hash updated after looking; 5/6 identical)
- gates so far: golden 20/20 + 17/17; modern 5/6 (s1_nacht intended) + gles OK; sight/path OK; stage head/base exit 0,
  same ERGEBNIS (render avg 4.21 vs 3.67 ms – one 226 ms load spike in unchanged lights hook; head2 rerun queued)
- running: tests (then render all); post.sh (nohup) waits for GATES_DONE then stage head2 + clip N2N (clips/N2N.mp4)
- if container restarts: rerun the missing gates with sh/gates.sh <job…>, sh/post.sh
## Update 23:00
- tests full: 765 unit tests 0 failed, all CHECK OK (1057 s) – gates/tests.log
- render all running since 22:46 (gates/render.log); report assembled at deliver/FIX-R4/bericht.md with placeholders
  GATES_TABLE / STAGE_TABLE / CLIP_STATUS – fill when render + post.sh (stage head2, clip) are done
## Update 23:20
- the first render run (gates.sh) was killed by the tool's 2-h background limit after check_instance_budget.gd (3 Arcade+
  2 Modern files OK in gates/render.log). Remaining 20 files: sh/render_rest.sh started DETACHED (setsid nohup) →
  gates/render2.log, per-file exit in gates/gates.log, ends with GATES_DONE → post.sh (nohup, alive) then runs
  stage head2 + clip N2N. If the container restarts: rerun sh/render_rest.sh (edit the file list) and sh/post.sh.
## Update 00:55
- ALL GATES DONE: render 24/24 files OK (gates/render.log + render2.log), stage head2 done (render avg 4.24, spikes in
  other layers than head1). Running: clip N2N (post.sh) → then post2.sh (nohup): stage base2 + head3.
- Remaining: fill GATES_TABLE / STAGE_TABLE / CLIP_STATUS in deliver/FIX-R4/bericht.md, copy clip to deliver, final
  STAND, StructuredOutput. Code is final (head b156763, pushed).
## FERTIG 01:45
- head b156763 = origin/wip/v080-fix-r4; all gates green; report deliver/FIX-R4/bericht.md complete, pictures 01–14,
  clip deliver/FIX-R4/clip_nacht_regen_verkehr_N2N.mp4; large scratch (base copy, xdg, mesa) deleted.
- Only the StructuredOutput result remains.
