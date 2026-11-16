# STAND AS1 – handover file (kept by the working agent; the lead's reconstruction of run 1 is STAND_lead_0225.md)

- Worktree (continue THERE): /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1
- Branch: worktree-wf_bade9e46-06a-1   (safety copy: origin wip/v080-as1, push after every commit, never force)
- Scratch: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1
- Deliver: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1
- Helpers in scratch: ex.sh <glob> [--force] (export+bake+manifest; the bake glob has no [..] classes),
  cs.sh <out.png> [contact sheet args] (--review --views=0,1,4 / --chase=9,30 / --night / --showroom)

## Plan (order of work)
1. DONE baseline breadth: catalog entries kompakt / hatch / wagon, first exports (validator red: budgets, lamps).
2. truck builder v1 (new ce3d/truck3d.py: tractor + trailer nodes, paint sets) -> every AS1 model exists.
3. quality rounds player cars (limousine first, then kompakt): lamp pockets with depth (decalgeo pocket +
   patch "sink"), clean decal ends (iso-line split), glass shader look, 3D extras (chmsl, plate frame + lamps,
   antenna, wipers, grille bars), rims material, interior polish. >= 3 rounds: build, render, look, fix.
4. traffic cars: decals cut along contour at all levels, same lamp outlines lod0-2, normals from the fine level
   for lod1/lod2, budgets (hatch lod2, wagon lod0/lod2), wagon front indicators, rims.
5. truck quality round (rear must read at 20-150 m).
6. evidence: validator, sheets day/night + channels, chase 8/30 m, showroom A/B, draw calls, geometry fixture,
   byte report, docs/modelle.md, bericht.md, run_tests.sh, golden.sh check.

## Log (newest last)
- 02:25 run 1 killed by a container restart (no own notes). Its uncommitted work committed as be9c3ca (WIP), pushed.
- run 2 commits: aa81020 catalog entries; 81d8690 truck (ce3d/truck3d.py) + sliver filter; fad88cf decal cut along
  the normal iso-line (decalgeo.split_level), pocket(), core.transfer_normals; c3734c9 player cars with lamp
  recesses (hook lamp_depth), grille recess (player_cars.grille), ce3d/extras3d.py (chmsl, plate frame + lamps,
  antenna, wipers), glass shader look (premultiplied reflection). Sprite geometry check players: 10/10 identical
  (geo_player_2.log, after c3734c9's cesprites changes).

## FINISHED - state 53bcc1b (pushed to origin wip/v080-as1), working tree clean
- validator: CHECK models OK; check_sprite_geometry: 187/187 identical (346 s); cache keys OK
- tools/run_tests.sh (complete, once): 569 tests, 0 failed, 64 CHECK OK (549 s; log tests_full.log)
- tools/golden.sh check: 20 von 20 identisch (golden.log); run_render_checks modern check_models: OK (render_check.log)
- deliverables: deliver/AS1/bericht.md + 18 pictures + pruefer_bericht.txt + lampenflaechen.txt
- showroom flag: false for both player cars (paint/light of the real-time picture are flatter than Cycles)
- nothing left to do except the structured result; what could come next is listed in bericht.md sections 8-11

## Pitfalls
- The harness refuses compound shell commands with `cd` + git: keep git commands plain, run from the worktree.
- Player chase camera: the car centre is 9 m ahead (at 8 m the rear bumper is below the screen edge).
- Godot's String.match has no [..] classes: bake with --only="*" or one model.
- GLES3 scene shader of 4.7 has no PREMUL_ALPHA_FACTOR (compile error) - blend_premul_alpha works without it.
- Blender's delaunay_2d_cdt reports a sliver input face as source of EVERY output face: skip slivers
  (decalgeo.SLIVER_2D) and verify containment.
- tests/race3d/render/check_models.gd checks sedan_silver (indicators amber >= 240 px, brake >= 1.8 x tail,
  third brake light) and limousine indicators from behind: keep green (tools/run_render_checks.sh modern check_models).
