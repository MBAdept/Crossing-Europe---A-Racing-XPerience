# RINT-B STAND (handover)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
- Branch: worktree-wf_ae4df3ba-14f-1 ; safety push after every commit: git push origin HEAD:refs/heads/wip/v080-rint-b
- Scratch: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B/
- Deliver: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/RINT-B/
- Helper scripts: scratch tools/ (import.sh, ab.sh [TREE=base for baseline], rows.py, patch.py, paintcmp.py, nightmodel.py,
  bake_vehicles.sh, truck_rebake.sh), probe/ (post, palettes, fog, texmem, brake, pop, census, inst_debug, logger)
- Baseline copy of merged state b473e90: scratch base/ ; ab0/ = baseline A/B; ab1/ = light+horizon; ab2/ = + paint/ground law road
- notes.md = measurements for the report; doc13.md = draft of renderer-modern.md §13 (not yet in the doc)
- Bash tool refuses compound git commands and heredocs with quotes: one plain git cmd per call, python patch files.

## Done (committed + pushed)
- merges dfc99b6 R3E, 94ce4a2 AS1R, b473e90 AU-D1; f198858 WIP (LUT, ground law, horizon, lamp glow, stand-in shadows,
  paint knee, quit, perf_clock)
- 9eac32f: LOD cross-fade (xfade), retro channel 15 + truck re-export, env_night/fill_night, knee 0.45, far-ground rim mean,
  showroom studio_look, docs 11.x / ARCHITECTURE §15 / modelle.md
- a8abb01: INSTANCE_BUDGET 128 (vehicles layer) + check_vehicles instanzen + render check check_instance_budget +
  run_render_checks fails on "Too many instances using shader instance variables"

## Measured since
- brake/tail (black sedan 18 m, 22:00): brake sum / tail sum = 3.93 (>= 2x); noon tail invisible, brake visible
- pop at lod1->lod2 (machine preset lod1 90 m, switch 94.5 m, still scene no traffic): before 5.4 % of car pixels in one
  frame; after 0 % at switch, <= 3.5 % per frame spread (motion baseline 0 %)
- paint tight box: S1 limo noon +6.7 %/-3.4°, dusk +3.3 %/-9.6°; kompakt noon -7.8 %/-1.3°, dusk -16.2 %/+5.9° (sun ahead)
- instance census: Kiel standing, traffic 2x: without budget levels grew 30->159 in 720 frames (total 227), base 15-17
  refusals in 900-frame probes; with budget total <= 198-229, no refusal

- 3d84e0b: loading bar monotonic (+ one frame at 0.65 before start view), contact sheet --showroom with STUDIO_LOOK
- uncommitted: docs/renderer-modern.md §13 appended (assemble_doc13.py)
- measured: ab3 (S1N +31.8 %, N1 kompakt -10.5 %), showroom A/B -> stays false, texmem arcade 221.1 / modern 166.8 MB,
  load Kiel-Hamburg modern 5.2-5.6 s (arcade 0.85 s)
- bericht_body.md = sections 2-4 of the report (draft)

- 8f58b2d: docs §13 committed; run_tests #1 exit 0 (854 s, 692 unit tests 0 failed); validate_models --report OK
- scripts ready: tools/clip.sh, tools/ergebnis.sh, tools/wine_smoke.sh (Linux+Windows bench smoke), bericht_body.md

- render checks all: 16/16 OK; look pass done (look_high, look_machine -> deliver/look); clip deliver (no-watchdog);
  bench leistungstest.json (bench/); previews committed 9b6adbc; ERGEBNIS x3 identical except gfx key;
  autopilot Xvfb run ok (autopilot/run.log); export determinism truck+sedan forced re-export glb identical + rebake clean
- bericht_look.md = section 5 draft

- FINAL: sprite geometry 187/187, golden 20/20, builds ok (zip 156.5 MB), wine + linux bench smoke ok, run_tests #2 exit 0
  (880 s) on 9b6adbc (pushed). bericht.md assembled in deliver/. Large scratch deleted (base, wineprefix, avi, build/).

## Next
- nothing: package delivered (StructuredOutput)
- render checks all; look pass (high+machine, S1K/S1S/S1G) via ab.sh into look/; clip (tools/clip.sh); previews
- golden, sprite geometry, ERGEBNIS x3, full autopilot Xvfb run, texmem probe (probe/texmem_probe.gd), builds + Wine
- run_tests #2, doc §13 (+ instance budget, xfade, retro, night factors), bericht.md, deliver

## Pitfalls
- don't edit runtime files while an A/B job runs from the worktree (later runs load the half-edited files)
- schedstat CPU time is tick-granular (useless per call)
- another session's kritik_render.gd process may load the CPU (not ours)
