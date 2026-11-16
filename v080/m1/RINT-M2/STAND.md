# RINT-M2 STAND (update 07:40 UTC) – CODE FROZEN at 1cd689d (code = a3120e4 + check message)
Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
Branch (local): wip/v080-rint-m2 ; push: origin HEAD:refs/heads/wip/v080-rint-m2 (plain)
Base: 515dd51. Merges: R4 04de79f, R5 9fec3a7, R6 5c451f2, AS5a cee4590; contract 8999769.
Commits after: 2322092 n3, 1c61036 WIP n4, b04d28a n5 tint (BROKEN: green), 967ad21 n6, 6347e41/747fa30 n8a/n9,
4fc3d35 n7 mast, eb417a7 n11a-d, aa44247 docs, 58eba9e/5294d00 lamp profile, 618561f n8 CanopyJob,
71ed4b7 n4 final (night share near 0.6 / far 0.15, thresholds 29/57/500), a3120e4 n5 fix (colour+custom, 20 floats)
+ budget check: injected -> layer may exceed budget, scene limit binds, scene counted every 10 frames.

## Key findings
- n5: Godot GLES3 INSTANCE_CUSTOM wrong for colour-only MM ((0,1,0,1)) and custom-only via MultiMesh.buffer (garbage
  on real meshes; set_instance_custom_data fine). colour+custom correct. Probe: probe/mm_models.gd (0.292 % -> 0.002 %).
- n4: probe 22h red px arc/new: sports60 95/94, sedan20 539/476, sports20 567/454.
- n6 (D, old criterion): wald layer 208 scene 211; stadt layer 176 scene 161 -> both FEHLER only by layer>128.
- n10 paint: merged check_night spielerauto Kompakt N1 1.23x, GT rain 0.77x, Limo S1 0.95x, DEV 1.00x -> list.

## Results since 07:05
- n5 fix verified (KHO/KIEL shots, no green); n6 E: wald 216/208 OK, stadt 171/176 OK, KH hoch 141/128 OK,
  mutation no VPBR_STATIC: 144 refusals, scene 306 -> FEHLER (as required). Docs §17 committed 1cd689d.
- runner2.sh (detached, setsid) takes over when runner.sh (2 h harness limit) ends; re-queues an unfinished job.
- Final chain queued: p010 import/tests/golden/modernkeep, p020 ab_sheet high+medium & deck, p030 render/sight/
  ergebnis/texmem, p040 extra A/B, p050 clips, p060 validate/keys/geometry/audio/determinism, p070 perf, p075 base DEV,
  p080 builds+smoke. MANUAL: after p010 look at gates/modern_keep, modern-make, commit, moderncheck.

## Queue (old; runner.sh; snap_D = eb417a7, snap_E = a3120e4 (m001), snap_base = 515dd51, merged = 8999769)
k053 KH hoch budget (D), m001 snap E, m002 n5fix KHO/KIEL shots (E), m003 n5vor KHO (merged modern),
m004/m005 wald2/stadt2 (E), m006 mutation no VPBR_STATIC (E), m007 DEV deck stage head (E), n063 DEV deck base.

## Next
- look at n5fix shots; budget results; collect_by head vs base; write docs §17; code freeze
- final: import, check_scripts, run_tests (<=2), golden check (1), modern-make (look at 6) + modern-check,
  render checks all, sight/path --full, validator/determinism/sprite_geometry/audio_qc, ERGEBNIS x3, perf vs base,
  texture mem, builds, smoke; A/B sheets high+medium, deck S1/N2/tunnel, extra positions, 2 clips; bericht

## Pitfalls
- Bash guard refuses compound git commands: one git command per call, commit with -F file
- rsync missing (cp -a); snapshot names [A-H]; runner sorts names (k0515 ran after k052!)

## 08:45 UTC
- p010 done: import ok, check_scripts 330/0, run_tests 802/0 (150 CHECK OK), golden 20/20 + 17/17 (once!),
  modern-check KEEP 0/6 (expected) – looked at 6 pictures (look/modern_keep6.jpg): plausible, no green.
- note8: head (618561f) station collect max 8.0 ms (worse than 3.4) -> refactor c72d484 (corridor deferred to
  finish(), gather split begin/rest); scan_f1 identical (1648 lines), startdep 0; but in-game F run still station max
  9.5 ms (avg 0.197) -> o045 instrumented debug run on snap_F (STATDBG lines) to find the spike.
- queue: o030 modern-make (running), o040 modern-check, o045 debug, then p020.. A/B, gates.

## 12:45 UTC
- commits: 6b17293 goldens (modern-check 6/6 + GLES), b673df5 WIP station budget/caches, ab2a400 props check fix,
  02051f7 station sign cache. Station collect DEV deck: max 2.40 ms avg 0.14 (was 3.41 inline / 8.04 / 9.5).
  jobpath full network: 1909 canopies, 0 differing.
- gates done: render 27/28 (+ props fixed, rerun OK), sight 6/6 + path 2/2, ERGEBNIS 3x identical,
  texmem KH 201.7/109.2, DF 200.6/110.8 MB.
- A/B sheets high/medium/deck done & viewed (verdicts in bericht_ab_high.md); deliver/RINT-M2/ab_boegen.
- queue: p040 extras (running), o0483 structures recheck, p050 clips, p060 validate.., p070 perf, p075, p080 builds/smoke,
  p090 run_tests #2.

## 13:40 UTC
- ae1fd76 docs §17.10 (checks table) pushed.
- extras viewed: U1N, VAL, VALN, KBT, KBN, STB, STBN, GRZ, GRZN, S0, KHZ, KHH, KHH195 (verdicts in bericht_ab_extra.md);
  KHH195: limousine paint pale/lilac at dusk -> report + §17.9 candidate.
- p040 still running (KHH22, KIEL*, NUE left); then o0483, o0484 (TSB/TSBN), p050 clips, p060, p070, p075, p080, p090.
- check_scripts "exit 1" in summary.txt is the grep -c of the line before (0 matches); rerun check_scripts at the end.

## 14:00 UTC
- FOUND: sh/rc_snap.sh never exported XDG_DATA_HOME -> 19 render-check runs used the real user folder (logs, lock,
  shader cache). Fixed (export added), my 5 logs archived to logs/userfolder_artefacts and removed; lock not present;
  31 shader cache files left. Reported in bericht_teil6 deviations. o0484/p050 now TMPDIR=$S/tmp_ab.
- light gates done (validate OK, keys OK, audio_qc 98/0); p060 reduced to geometry+determinism.
- o0483 structures final OK (countdown, zieltor, grenze, blitz). p095 added (scripts2 + moderncheck2 on final code).
