# STAND QA-M2-BILD

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3
Branch: worktree-wf_438996b0-243-3 (ff to 6e484056ec87e2fa614061000a362feb2b5a6db8, no own commits; .godot copied + imported)
ZS1 reference tree (git archive 39849f0, .godot copied, imported): $S/zs1tree   ($S = scratch below)
Scratch: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD/
Deliver: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-M2-BILD/
Sibling: QA-M2-SYSTEM (worktree -243-4) runs run_tests, render checks, golden, builds, soak – do not duplicate.
Machine: R4, R5, R6, AS5a, QA-M2-SYSTEM run in parallel – load 12-18; a Modern shot takes ~7 min.

## PITFALL (cost a restart): background commands of the Bash tool are killed after their timeout (default 30 min,
## max 2 h). Work is split into chunk scripts sh/chunkA..F.sh, each < 2 h, each started with run_in_background and
## timeout 7200000; all idempotent (rerun = continue). Start the next chunk when the log says "chunkX end".

## Done
- fairness --full: 6/6 + 2/2 OK (numbers in notes.md); props corridor probe (fair/props_*.txt); S0 (medium, M2/ZS1/
  Arcade), S4 (high, M2/ZS1/Arcade); occlusion T4 (Arcade + M2 high) – notes.md has all numbers so far

## Progress: A done 17:02 (occl T3/T1/W1 + N1 S1 C1 T1 high). D started 17:03 (perf, ~95 min at load 20).
## Order: D -> B -> C -> E -> F (one at a time). Trimmed 17:10: C = player cars night (4) + day (sport, GT) + deck S1 N1
## (arc+m2) + N1 medium; E warm only kh m2/zs1 + n1; F clip3 only with logs/clip3.
## Perf so far: kh_m2_medium done 18:06 (3790 s): render avg 4.04 p50 1.81 p95 7.96 max 1154 ms (streamer stall
## km 87.1; also streamer 215/573 ms at km 54.5/55.5, vehicles 176 ms km 48.5); DC 145/181, tris 132k/179k, tex 120 MB,
## RSS 1066, load 47.5 s (prewarm 38.3). Chunk B now starts with a headless repeat km 70–95; chunk E ZS1 km 40–90.
## 18:30 chunk D done (numbers in notes.md "Perf"); chunk B started 18:31 (bg). Next: C, E, F, then golden + report.
## 19:13 chunk B: KBN/KBT done (sheets in deliver/bilder), U1 done; DEV T3 T2 + traffic probe running.
## C trimmed again (player cars + S1 deck only); veg trimmed (lods 12 + 19.5, bauten 22).
## 19:46 chunk B end, chunk E started (bg bmeo69vih). Day/night traffic analysed (notes.md "Vehicles by day"),
## report parts: bericht_kopf/fair/bild/bruecke/leistung/fahrzeuge.md (scratch). Next after E: C, F, golden, bericht.md.
## Chunks (logs/queue_ab.log for A-C, logs/queue_perf.log for D-F)
- A (started 16:00): occl rest T3 T1 W1 (Arcade+M2 high) + N1 S1 C1 T1 high       -> "chunkA end"
- B: U1 DEV T3 T2 high + vehicles traffic rows                                     -> "chunkB end"
- C: vehicles player cars + deck S1 N1 (arc/m2/zs1) + medium S1 N1                 -> "chunkC end"
- D: perf KH full medium, low, arcade (sh/drive.sh, probe/qa_drive.gd)              -> "chunkD end"
- E: perf zs1 medium km0-35, m2 high km0-35, mem 22 min (qa_drive2 chained), warm.sh -> "chunkE end"
- F: veg.sh (prop_scene lods), extra.sh (S1 6:30, 20:30), clips.sh (3 x 15 s)        -> "chunkF end"
Positions S2 S3 S5 T4 N2 high: use M2INT pictures (deliver/M2INT/ab_boegen, c317625 = same code there).

## Next (analysis)
- sh/compose.py sheets, sh/occl_count.py, sh/perfrow.py (M1 ZS1-era refs: ../QA-BILD/perf), sh/carstats.py
- golden.sh check once at end (7 min); bericht.md + pictures to deliver/

## Pitfalls
- Bash tool refuses compound/heredoc commands: write scripts with Write tool, mkdir separately
- shot.sh/vehicles/occl set absolute XDG per run, MESA cache $S/mesa shared
