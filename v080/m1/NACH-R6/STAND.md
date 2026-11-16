# NACH-R6 STAND (re-check of FIX-R6, head 2b7dcc0)
worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4 (branch worktree-wf_3b3101bc-877-4, ff to 2b7dcc0, NO commits)
done:
- ff, import (exit 0), diff read (7 files, all R6-owned + modern_slice golden; no frozen file)
- check_scripts 316/0; run_tests filters: test_structures 12/0, test_props 12/0, test_far_ground_water 4/0, check_minimal_structures OK (logs/unit_*.log)
- head A/B shots (shots/*_ab_*.jpg): grenze_12/21, ziel_12/21, start_21, tank_21, wp_grenze_12 — looked at grenze, ziel, start
done: base shots + triptychs (shots/tri_*.jpg), worktree restored and clean; deliver pictures 01-15 copied (bin/deliver.sh)
done: mutations M03/M06/M08 all red, restored clean; scans: scan_f1 = FIX-R6 (station_end 38 / 5>=6px), scan_all 0 mismatch, 10 masts, startdep 43 differing (40@100m,3@300m,0@500m), collect_time DEV station max 3.22 ms
done: render checks structures/structures_licht/start_km0/terrain_cover/light_base all OK (logs/rc_*.log); bericht drafted (GOLDEN_REST placeholder)
done: golden check 20/20 + 17/17, modern-check start 1/1; bericht complete; caches and worktree .godot deleted
doing: StructuredOutput (final)
next: tools/golden.sh check (once), golden modern-check start (optional), bericht -> deliver/NACH-R6/bericht.md, StructuredOutput
pitfalls: if the worktree shows modified builders (git status) -> run bin/swap.sh head before anything else
findings so far: B-01 masts visible at distance, right side still unsupported from close (fascia hides stays); gates/start clearly better; collect() LOS cost vs contract "cheap snapshot"; decision depends on path window (start position) -> startdep.gd
