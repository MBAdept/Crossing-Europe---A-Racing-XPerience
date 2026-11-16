# FIX-R5 STAND

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6
Branch: worktree-wf_fd1de4ee-28b-6 (safety copy origin/wip/v080-fix-r5)
Base: 5558bdc (R5 head), ff-merged, .godot copied, import clean. Base copy (git archive + import): FIX-R5/base

## Done (all pushed)
- repro QR5-01: shots/repro u1_nacht + dev bit-identical to QA-R5 renders (md5)
- 7e575e6: portal on render layer 2 (tunnel.gd PORTAL_LAYERS), tests, exact full scan
- 7610875: scan without river-pier rule; scan OK 122 bridges 28 tunnels 0 defects 180 s (scan_full.log); docs
- ea5d8f7: tunnel_state["light"] for R4's road (QR5-02 support) + test + docs
- mutations B10/B12/B14/T4/P1 all caught (mutations/results.json)
- fix1 pictures: U1 22h headwall 79->56 lum (Arcade 46), wing 70->50 (Arcade 44); sheets in deliver/FIX-R5/bilder
- perf u1 deck (600 s, km 183): base commit max 17.8 ms, new 4.1 ms (load); bench headless min-of-3 commit <= 0.25 ms
  tunnels (perf/bench_new.log) -> QR5-09 not reproducible as code problem

## FERTIG (04:30): all gates green, bericht.md assembled, scratch cleaned; only StructuredOutput left

## Doing now (old)
- 80b8141 pushed: tunnel_state.exit_z (R4 glare quad sits at raw end_km-0.6, tube ends at snapped segment)
- r4mix tree (head + fix-r4 patch): exit over-exposed (QR5-03 solved by R4) but frame ring glows; r4mix env rig patched
  line 433 z_quad = snapped exit - 0.05 -> step r4mix2 renders it
- queue.sh pictures fix2 (day/night identical to R5 renders except night portal), then detached chain.sh ->
  queue2.sh r4mix2 scripts sight path tests golden render modern perf_kh_new perf_kh_base (queue.log, gates/)
- if the container restarted: check queue.log, rerun missing steps with queue2.sh <steps> (setsid nohup)

## Gates so far (head 80b8141)
- check_scripts 314/0; sight full OK; path full OK; run_tests 769/0 "Tests bestanden" (935 s, 1st full run);
  golden check 20/20 + 17/17; r4mix2: quad at exit_z-0.05 -> frame L134 (not 244), outside L150
- render checks all: 19/20 files OK (tunnel_bridge 6/6, terrain_cover K1 0.000 %, start_km0, light_base OK);
  check_instance_budget_wald timeout 900 s (M2S-01 load) -> chain2.sh reruns it alone after the chain (gates/render_wald.log)
- modern-check 6/6 identisch + GLES OK
- running: perf_kh_new, perf_kh_base (perf/new_kh.log, base_kh.log), then chain2 forest check
- report: edit parts bericht_*.md, then python3 mkrepl.py && python3 assemble.py (needs perf_kh_table.md,
  perf_kh_lesart.md, perf_kurz.txt, wald.txt, gates_kurz.txt)
- bericht parts: bericht_body.md, bericht_mid.md, bericht_notes.md (assemble into deliver/FIX-R5/bericht.md)

## Next
- queue.sh scripts tests golden render sight path modern perf_kh_new perf_kh_base   (logs FIX-R5/gates, queue.log)
- bericht.md in deliver/FIX-R5, StructuredOutput
- notes: QR5-02 road shader (R4) reads tunnel_state.light; QR5-03 R4 has exit glare (fix-r4 _update_exit);
  QR5-04 roadside.gd balusters (R4) + contract gap; QR5-07 golden regen at RINT-M2; QR5-08 props.gd:599 +0.15

## Pitfalls
- Bash refuses compound git commands and some heredocs: write python edit scripts with Write, run them
- measure.py <x0,y0,x1,y1> pngs ; shots.sh <set> names (modern only; WT= MODE=arcade PRESET SCREEN SUFFIX)
- QA arcade/R5 shots in m1/QA-R5/shots/new (R5 head pictures bit-identical)
