# STAND QA-R7c
Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-7 (branch worktree-wf_ba4424b4-294-7, ff to bd1803b; .godot copied + imported OK). Nothing committed.
Base copy (git archive 9b02f05 + .godot, imported): m1/QA-R7c/base
Scripts: m1/QA-R7c/sh (common.sh, q1_gates.sh, scan.sh, mergeprobe.sh, mkcopy.sh); probe: m1/QA-R7c/probe/scan_r7c.gd
Gate logs: m1/QA-R7c/gates/ (q1.out summary)
## Done
- contract §2, §11.3 read; R7c report read; props.gd/shader/material diffs reviewed
- diff stat: no frozen file; R7c own files = props.gd, prop_library.gd, model_factory.gd, modern_materials.gd, baked/billboard/leaves + inc/lod_band, config graphics (props.*), docs gelaende, tests, goldens (modern_slice, A-18 vs brief)
- merge-tree: r7a/r7b/fix-r7b clean, fix-rint conflict test_props.gd only; fix-rint also touches modern_materials.gd (auto-merge)
- GATES (R7c head): check_scripts OK; modern_sight --full 6/6 OK (137 s); path --full OK; run_tests.sh FULL 808/0 (983 s) -> DO NOT run full again (1 of max 2 used)
## Done 2
- render_all 29/29 OK (3873 s); Q1 DONE
- scan all 128+dev dirs: R7c == merge(43a1fcc) exactly (195741 props, corridor 35492), base differs only by AS5aR2 extents (x 0.04 m); 602113 instances custom a in [1,2); bands of all 77 models x 3 details sum to 1 (bands_all.log); sink max 0.33 m / 10 %
- unit mutations: caught U1,U2,U6,U11; NOT caught U3 phase const, U4 sink noop, U5 align noop, U7 far_sun not set, U8 leaves phase world, U10 attached never dropped, R5 cutout bias off, R6 relief night off (mutlogs/mutate.out)
- k6 lod0|lod1|sprite 32-50 m (k6/lod01_medium.png): lod1 nearly identical at 1x -> shorter lod0 OK
- Nuernberg clip of R7c analysed (clippeaks/tilepeaks): no LOD pop, spikes below Arcade's
## Doing
- background queues: q1 (gates, render_all running) -> q2 (scan r7c+base, unit mutations; logs/q2.out, scan/) -> q3 (pictures deliver/QA-R7c/raw via sh/tri.sh; logs/q3.out, logs/tri.out). Restart: rerun sh/q2.sh / sh/q3_pics.sh after removing the wait line (tri.sh skips existing pictures)
- copies: m1/QA-R7c/base (9b02f05), m1/QA-R7c/merge (43a1fcc = base + AS5aR2), m1/QA-R7c/mut (bd1803b, mutation copy; sh/mutate.py)
- q1 render_all running (gates/render_all.log)
- probe fixed (missing cam += step); KH test OK: bands 33 models x3 BAD 0
## Next
- scan all dirs base+R7c, diff dumps; pictures (tri runner Arcade|base|R7c), perf deck base vs R7c, mutations (mut copy), golden check last
## Code-review suspicions
- LOD node visibility updated every LOD_STEP_M=2 m without margin -> up to ~23 % dither holes for 2 m (low)
- attach items beyond chunk rows use clamped ground (latent)
## Pitfalls
- disk ~8 GB free only; Bash refuses compound heredoc+git -> use scripts
- FINDING candidate: tag:city lod0 35 m also hits old generic buildings building_block_a/b, oldtown, shop, tall (lod1 ~ 70 % tris) and Kontor lod1 = 749 tris vs 9865 lod0 -> check pictures hh at 35-70 m deck/medium
- 9b02f05 base lacks AS5a2 models -> merge copy 43a1fcc used to isolate R7c
- pictures: hh/nu high 12 looked (R7c ~ base, 0.2-0.5 % px; far facades softer: albedo_bias makes white window frames grey at ~100 m, nu_high_h12 00, tmp/nz.png); tri.sh got skip/merge lists (sh/tri_skip.txt, tri_merge.txt) - never edit tri.sh while a run is inside it (broke hh_high_h12 composition once, recomposed by hand)
- report parts: bericht_teil_gates.md, bericht_teil_mut.md, bericht_teil_code.md; q4 (k6 far light + standing start) waits for Q3 DONE
- looked: pa high 12 (R7c vs 43a1fcc 0.8-1.2 % px, Haussmann at ~60 m in lod1 softer balconies vs lod0 of 43a1fcc; facade luma equal 130.0/130.1), am high 12 (AS5aR2 houses beside the camera, Arcade none - 3D nature, not R7c), be high 12 (Lauben better than Arcade). Paris clip of R7c: tilepeaks no LOD pop.
- FINDING (medium): Deck/Mittel Hamburg hh_deck_h12 00: Speicher at 35-60 m now lod1 -> green loading doors flat slabs (lod0 paneled), windows flatter; base/43a1fcc showed lod0 (tmp/hd.png, k6/speicher.png: lod1 = like sprite). Cause tag:city 35 m for all city houses. 2.5 % px vs base.
- looked ly_out high 12 (worse than Arcade: garden walls+trees missing, pre-existing in base); notes in look_notes.md
- perf KH deck x2 done: R7c props hook avg 0.25-0.27 / max 3.8-4.4 ms vs 43a1fcc 0.10 / 0.47-0.59 (base 0.10/1.20); commit max 2.3-2.8 vs 1.7-1.9; draw 132 vs 129; prims 137k vs 158k; frame times equal within noise
- pictures core done (hh/nu/pa/am/be/ly high 12, hh/nu deck 12, wald high/deck 12, pa/hh/nu 22, hh 19.5); look_notes.md has the table
## FERTIG (08:40 UTC)
- all done: golden 20/20+17/17, render mutations (R1, R2b caught; R2, R3, R4 not), k6 far light (all +-5 %), countdown dither found (QR7c-06)
- deliver/QA-R7c/bericht.md complete (assembled by sh/assemble.py from bericht_teil_*.md + look_notes.md)
- base/merge/mut copies, mesa caches, xdg dirs deleted. Worktree clean at bd1803b, nothing committed.
- Only remaining: StructuredOutput (if a successor finds this: report is complete, return the result)
