# FIX-R6 STAND
- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-3
- Branch: worktree-wf_3b3101bc-877-3 (safety copy origin/wip/v080-fix-r6)
- Base: c8b18d1 (R6 head). Base copy for perf: scratch base/ (git archive c8b18d1 + .godot)
## Done
- ffca594 B-01 masts/stays, B-02 end column LOS, B-04 test literals (mutations M03/M06/M08 now red)
- fc312bf station decision per canopy (cache), LOS both sides to 600 m, fallback; gantry truss+floodlights+white posts
- d5c5b52 + b185bb8: stay order, LOS step 5/margin 0.1, shop forecourt pool, night fascia 0.5, docs. then 2c75af0: LOS cost reduction (same decisions). CODE FROZEN at 2c75af0
- scans (logs/scan_all.log, scan_f1.log): 0 floating roofs (10 masts), station_end 1109->38 pairs, >=6px 195->5 (3 fallback canopies)
## Doing
- shots2.sh (pictures in shots/), then detached gate chain bin/gates.sh (status: gates/status.txt; restartable, skips done steps).
  If the container restarted: rerun `setsid nohup bash bin/gates.sh &` (steps already 'done' are skipped).
## Next
- commit; gates chain: check_scripts, run_tests full, golden check, modern-check(+make), render checks all, sight/path full, perf head/base
- bericht.md in deliver/FIX-R6
## Pitfalls
- Bash refuses compound commands with heredocs/python -c in worktree: use scripts in bin/

## Gate run 2 (on 2c75af0)
- run 1 logs (b185bb8): gates/run1/ – run_tests 761/0 FAIL, golden 20/20 17/17, sight/path OK; modern_check aborted (parse error window)
- run 2: setsid bash bin/gates.sh import scripts tests collect modern_check render perf_head perf_base golden
- this is the 2nd (last allowed) full run_tests
- run 2 results so far: run_tests 761 tests, 1 FAIL = test_music_checks running_game (Arcade audio timing, load) -> rerun alone at the end;
  modern-check 5/6 identical, modern_start_mittel changed ON PURPOSE (gantry truss) -> modern-make after the chain, then commit goldens
- report parts: bericht_teil_{kopf,befunde,bilder,ende}.md -> assemble into deliver/FIX-R6/bericht.md

## FERTIG (00:50)
- Kopf 2b7dcc0 = origin/wip/v080-fix-r6; Bericht deliver/FIX-R6/bericht.md; Scratch aufgeraeumt (base, xdg, mesa, PNG geloescht)
