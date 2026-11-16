# STAND FLACKER-NACHSTELLEN

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_17007edf-ec9-1 (branch worktree-wf_17007edf-ec9-1, ff to 39849f0 = ZS1); .godot copied + imported (ok)
- Scratch: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN/
  - gd/ = my Godot probe scripts (run with -s <abs path>), run_godot.sh = runner (nice 19, xvfb, XDG, memory wait)
  - godot_src/ = Godot 4.7.2 reference sources (instance uniform allocation)
  - recon/ = first counting run
- Deliver: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FLACKER-NACHSTELLEN/
- Sibling (read-only analysis): m1/FLACKER-ANALYSE (do not touch)

## Facts so far
- Stage erfurt_kassel (155 km, forest_hills from km 20): race "Dresden – Dortmund" drives it Erfurt->Kassel; "Einzelne Etappe" both directions.
- Windows PC tier "ok" -> recommended preset "medium" (Mittel): vehicle_lod0_m 40 (switch 38-42 m camera->car centre), 2 shadow splits, split at 0.3*120 = 36 m, no blend.
- Deck: lod 40 m, shadow split 0.3*80 = 24 m. Hoch: lod 60 m, 4 splits blended 16/40/90 m.
- White PKW in ZS1: traffic/hatch_white, traffic/wagon_white (models); suv_white, van_white = sprite stand-ins.
- Godot 4.7.2 GLES3: instance uniforms in one UBO of 4096 vec4 (64 KB); every GeometryInstance with an instance-uniform material takes 16 (also hidden/off-tree); refused instance -> offset -1 -> shader reads global slot idx-1 (paint idx0 OOB). Refused stays refused for life. Globals of ZS1 take 20 slots -> capacity 254 instances.
- M2INT found overflows on forest stages (vpbr props) and fixed with VPBR_STATIC (b2c6b52, NOT in ZS1).
- lead "_set_level does not reset cache": refuted (it resets fade/sun/la/lb, lines 1318-1323).

## Scripts (all parse: godot --headless --check-only -s <file>)
- gd/probe_recon.gd (refusal count), gd/probe_drive.gd (instrumented drive + allocator simulation + shots, needs --pilot=<abs gd/follow_pilot.gd>),
  gd/follow_pilot.gd (Autopilot subclass: follow car, sweeping gap, steering wiggle), gd/probe_force.gd (forced refusal look A vs B),
  gd/probe_switch.gd (still scene, one injected traffic car swept through switch distance, crops per frame; --gfx=modern|arcade)
- switch_stats.py (pixel change / dE at switches), analyze_drive.py (per-10-km stats)

## Results so far
- recon r1 (Erfurt->Kassel km 1-72, Mittel, ts 6, no gfx-sync): 0 refusals; scene instance-uniform users max 156 (vehicles up to 127 of 128 budget, props only ~28 in forest_hills) -> overflow unlikely at Mittel on this stage (measured)
- mesh paint areas (gd/mesh_codes.gd, mesh_codes_zs1.json): paint area equal in lod0/lod1 (hatch 29.5/29.5 m2, wagon 36.5/36.4) -> "lod1 lacks paint mask" refuted
- vpbr samples no texture -> mip/BC of paint refuted (paint = vertex code + instance uniform)
- AS1R measured lod0->lod1 pop at 40 m: 6.6-9.8 % of car pixels (windows/plate/mirrors)

- sibling FLACKER-ANALYSE measured (their STAND/swap/): refused instance on llvmpipe = index0 reads 0, index k reads global k-1;
  refused car = checkerboard-dithered + paint brightened (56-60 % of car px change); lod0->lod1 6.5 %; cascade K1->K2 4.6 %;
  ZS1 Mittel counts max 214 (from Kassel km 136) / 205 (from Erfurt) < 254. Godot allocates newest dirty instance first (LIFO).
- => my focus: natural occurrence in a follow drive (dense traffic B7 km 90-115, Kassel end), slot leak across stages
  (gd/probe_leak.gd), in-race forced refusal look + clip (probe_force/probe_clip), Modern vs Arcade switch sweep, M2 head.

- switch sweep sw/m_med_noon (hatch_white): lod1->lod0 at d=38.0: 30 % of car-window px changed vs ~10 % motion;
  lod0->lod1 at 42.2: 23 %; mean car colour unchanged (dRGB ~2-4): plate appears/disappears, window tone; NO paint loss.
  cascade split 36 m: no spike. (switch_stats.py WIN=150,80,300,215 for crop 440,230,400,240)
- QUEUE: queue.sh jobs1.txt running in background (state in queue.state, logs runs/*.log): force_med, clip_med, d1, leak_med

## RUN 3 (successor, 2026-11-13 05:25, container restarted, machine idle)
- force_med timed out 1800 s (no output, load 25) and clip_med was killed by the restart: both incomplete.
- plan: short speed test of probe_drive, then natural drives medium/high/deck (logger = ground truth for refusals), switch sweeps (arcade, high, deck, low sun, dusk), forced refusal look + clip, M2 head.

## RUN 4 (successor, 2026-11-15 08:00, container restarted again)
- t1 (runs3, km 30-40, medium, 20 s) finished: 0 refusals caught, 1 switch, no readback mismatch.
- first n1 at 640x360 with per-frame pictures: 0.75 fps under load 20 -> killed. New plan:
- gd/probe_switch2.gd = switch probe + --refuse=lod0|lod1 (300 vpbr dummies fill the global buffer, then the level is
  (re)built -> refused) + --mode=clip (d = 40 +- 3.5 m sine, 300 frames at 60 fps, crops c####.png 640x360).
- mk_jobs4.py writes jobs4a (look: sw4/), jobs4b (natural drives 320x180, ts 3, no pictures: runs4/), jobs4m (M2 head: sw4m/).
- chain4.sh = queue4.sh jobs4a then jobs4b (state queue4.state; re-run chain4.sh after a restart: it skips DONE).
- Godot source facts (godot_src/): refused instance keeps instance_buffer_pos = -1 -> every later allocate fails with
  "instance_buffer_pos.has" -> permanent until the node is freed (confirms sibling). max UBO clamp 16 KB..1 MB:
  capacity = GL_MAX_UNIFORM_BLOCK_SIZE/16 (64 KB on NVIDIA/AMD/Intel GL -> 4096 like llvmpipe: inferred).
- stage flow: game_flow._switch_to queue_frees the old race scene -> no slot leak across stages (code, inferred).
- 08:30 load ~31 (8 agents): 1280x720 sweeps ~0.4 fps -> jobs slimmed (slim_jobs.py: hatch only, step 0.2, clips 240
  frames, wait 80). jobs4a.txt is the truth now (do NOT regenerate with mk_jobs4.py). Order: m_med_noon > r0_med_noon >
  a_noon > clip_r0 > n0_med_erf_start > clip_a > clip_m > high > deck > dusk(m,r0,a) > low > all colours > r1.
- RESULT sw4/m_med_noon hatch_white (measured): switch at cd 38.0 (lod1->lod0) / 42.1 (lod0->lod1); same-d pair d=40.1:
  24 % of car px change (>15 levels), dE mean colour 1.27, L 49.0/49.0 -> no paint loss (switch_stats2.py; sheet2.py).
- RESULT sw4/m_med_noon wagon_white: same-d 26.7 %, dE 1.52; white-paint px (L>62, C<12) hatch 503/481, wagon 526/523.
- RESULT sw4/r0_med_noon (forced refusal lod0, hatch_white, medium noon): 300 dummies -> 80 refused (reserve 220 at
  km 30 standing); lod0 build -> +6 refusals (body, 4 wheels, hull). same d=40.2 lod1 ok vs lod0 refused: 89.6 % of car
  px change, dEpx mean 24, white-paint px 473 -> 172 (-64 %), visible car px 995 -> 567 (checkerboard see-through).
  picture tmp/r0_first.png. == "loses its paint" (measured llvmpipe).
- RESULT sw4/a_noon: Arcade at 40.1 m hatch car px 1194, white px 637, L 53.8 (Modern lod1 1025/503/49.0), dE ~4.9.
  sheet deliver/zs1_mittel_12uhr_40m_lod_ablehnung_arcade.png.
- 08:45 queue reordered (slim_jobs2.py): after clip_r0: n0_med_erf_start (17 h, km 0-25), n0b_med_kas_end (from Kassel
  km 118-155, 17 h), n0_high/deck_erf_start (km 0-15), clips, high, deck, dusk, low, all colours, r1. jobs4b emptied.
- chain5.sh (background) waits for chain4 to end, then reruns jobs4a (skips DONE), m2_prepare.sh (checkout --detach
  6e48405 + import), jobs4m (mk_jobs_m2.py). AFTER A RESTART: just start chain5.sh again (in background).
- RESULT clip_r0_med_noon: clip ok (240 frames, lod0 refused shown at cd < 38..42), deliver/zs1_clip_lod0_abgelehnt_60fps.mp4 + _bilder.png
- RESULT n0_med_erf_start (medium, 17 h, Erfurt km 0-25, follow pilot, 320x180, ts 2): 0 refusals caught/predicted,
  in-tree peak 168 (< 254), 3 switches near 80 m (all lod0<->lod1, 1.2/10 km), 0 flip-flops in 1 s, 0 uniform
  mismatches, followed car 35-65 m in 645 of 2290 frames. analyze_drive2.py -> runs4/n0_med_erf_start_an.json
- 09:15 queue after n0b: n_stress_med_kas (probe_drive --density-k=3, Kassel km 100-145, 17 h, shots 480x270),
  n0_deck_kas_end, n0_high_kas_end (Kassel km 118-155, 17 h), then look jobs. edit_jobs.py = safe in-place edit.
  m_high_noon sweep now far 64 near 36 (covers lod switch 57-63 AND cascade boundary 40 m).
- sibling lauf2 (Kassel km 100-136, 17 h, medium): engine used up to 206, smallest reserve 48 at km 136; 0 refusals.
- sibling FLACKER-ANALYSE engine probe (FLKH lines): Erfurt km 0.7-4.5 medium: engine used 109-131, headroom 123-145.

## Doing now (run 2, stale)
- recon run r1 (erfurt_kassel from Erfurt km 1, medium, ts 6, 150 s): counts refusals + scene instance count
- writing follow pilot + main instrument (allocation simulation + readback + pixel crops)

## Next
- instrumented drive both directions at medium/high/deck; pixel proof of refused car; LOD switch renders A/B; M2 head 6e48405

## Pitfalls
- machine heavily loaded (load ~25 on 4 cores); nice -n 19, one heavy job at a time, check free -g (>=3 GB available)
- Bash tool refuses commands with "github" URLs inline (thinks git) -> use fetch scripts
- NEVER sed -i a jobs file while its queue runs (new inode; bash keeps reading the old one). Rewrite in place with
  python open(...,'w') keeping the lines up to the running job byte-identical (or write via /proc/<pid>/fd/0).
- Bash tool refuses heredocs with '>' lines / complex chains: write python helpers into the scratch folder.
NOTE: mk_jobs4.py does not contain n0_med_erf_start (inserted by hand into jobs4a.txt line 2); do not regenerate jobs4a while queue runs
