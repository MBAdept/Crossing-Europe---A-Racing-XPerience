# R7c STAND (Fern-LOD Bauten und Pflanzen)
- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-3
- Branch: worktree-wf_ba4424b4-294-3 → push origin HEAD:refs/heads/wip/v080-r7c (plain push)
- Base 9b02f05 (ff), merged as5ar2 216ac5c --no-ff (43a1fcc), goldens kept at base (modern_slice conflict → ours)
- Helpers: scratch m1/R7c/run.sh <cmd> (env+nice+waitmem), ab_all.sh <outdir> "name:preset:hour ..." (positions pa am br ly ly_out be hh nu wald)
- Untracked probe: WT/tools/r7c_tmp/shader_probe.gd (NEVER commit; delete before run_tests full)
## Done
- e512616/e216555: per-mesh materials (ModernMaterials.material(...,mesh_path), PER_MESH_CLASSES), inc/lod_band.gdshaderinc
  (lod_band, far light shadow_far/far_sun, shadow pass via vertex varying), baked light() replica + far light, leaves/billboard band,
  vpbr_static injection (STATIC_INJECT: band, far light, rotor phase), props.gd: lod_bands(), _ensure_bands, chunk span culling
  (Euclid. box of instance origins), custom a = 1 + phase, tags ground_align/ground_sink/face_road, attach (model.json "attach"),
  quality_lowered hook; config graphics.modern.props lod_ref_m/lod1_ref_m/lod_fade/lod0_m(fachwerk 35)/far_sun (0.8)
- test_props green (17 tests)
- first A/B Hamburg medium 12h OK (shots/t1)
- 59b4728 far light tuned (far_sun building .78/tree .8/chalet .35/fachwerk .85; within ±5 % 60-250 m, logs/b075_*),
  shimmer (cutout_bias 2, albedo_bias 1.25 ramp 30-120 m, lod0_m tag:city 35, fachwerk/paris 30; logs/spark/*),
  dusk windows (cover + window_ramp 0.6, d823ada; shots/dusk2 looks like Arcade)
- 58ea700 docs renderer-modern-gelaende.md §9, tests/race3d/render/check_lod_band.gd (NOT yet run)
- clips.sh running (paris, nuernberg) -> clips/*.mp4 + AVIs
- aca4123 quality_lowered updates node bands (+test, 18 props tests green)
- after clips: queue.sh lodcheck far078 cutout pics wald perf tests golden mcheck render sight (gates/summary.txt)
- report drafts: bericht_teil_mess.md, spark_table.md; py/clipframes.py for the clip AVIs
- clips done (deliver/R7c/clip_*.mp4; spikes ≤5.7 % excess, no pops seen); 6eaa7e0 shadow pass: finer level casts
  through band (lodcheck 1st run FEHLER 9.3 vs 7.1 → fixed, RERUN lodcheck!); 965b8a9 far_sun per model
- queue1 running since 19:09: lodcheck far078 cutout (done) pics basepics wald → then queue2: lodcheck tests golden mcheck render sight perf
- 21:10 queue1 killed by 2h limit after pics (20 OK) + basepics (4) + wald 2/4. Detached chains now:
  chain3.sh (rest wald incl. BASE run → writes marker) → chain2.sh (queue2: lodcheck tests golden mcheck render sight perf)
  If restarted: check `git status` (base_ab/stage BASE runs check out base files; restore with git checkout HEAD -- <files>)
- deliver/R7c so far: clips, dusk 3-up, basis_* 3-ups, lod_mitte_vorher; report parts: bericht_*.md in m1/R7c
## Next
- measure: far light (kt lodcol --shadow_m), level switch clips, shimmer (sparkle), dusk windows; tune far_sun
- impostor relief night picture; forest stretch; city pictures; clips Paris / Nürnberg Altstadt at Mittel
- docs/renderer-modern.md §19 (German), gates, bericht.md
## Pitfalls
- Bash tool refuses heredocs/compound git: write files with Write, run scripts via run.sh
- MAIN_CAM_INV_VIEW_MATRIX only in vertex()
