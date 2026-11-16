
// ---- args: { v080: '<sha>', reports: [...compact package results...], notes: '<lead notes>' }
const V080 = args.v080
const REPORTS = args.reports
const LEAD_NOTES = args.notes || ''

phase('Zusammenbau 1')

const RINT_A = `${common('RINT-A', { mode: 'fresh', base: V080 }, 'render')}
YOUR ROLE: RINT-A – FIRST HALF OF THE ASSEMBLY OF PUSH M1 (A-8). Your fresh worktree starts from the v0.8.0 head
${V080}. Merge these package branches with --no-ff in this order (German commit messages, trailer as above):
  R1   = worktree-wf_145e8e23-1e4-1 (21bca09)  road, environment, light, overlay, quality, warm-up, kernel
  R2   = worktree-wf_145e8e23-1e4-2 (b947e73)  terrain, far ground, props builder, contact shadows of props
  R3   = worktree-wf_2e14ac26-9d4-1 (4d02ada)  vehicles, flares, paint and glass, signs
  AS1b = worktree-wf_2e14ac26-9d4-2 (adff0b3)  environment models of the slice (trees, bushes, buildings, wind turbine …)
  UI1  = worktree-wf_9693abb2-cee-2 (3b89a33)  options, chooser, Leistungstest, showroom, attract; it already contains
         the vehicle models AS1 (53bcc1b) and the engine sound AU-B (8414002)
(R3 and AS1b were built on d025d1d = R1a + AS1; R1 and R2 on R1a 65c7560; all heads are also pushed as
origin/wip/v080-<package>.)
Two packages run IN PARALLEL with you and are merged in the second half (RINT-B), not by you:
- R3E: Arcade pictures as stand-ins for vehicle sets without a 3D model (instead of R3's painted boxes). Its files:
  scripts/race3d/layers/vehicles.gd, model_factory.gd, vehicle_pose3d.gd, a new stand-in script and shader.
- AS1R: rework of the AS1 vehicle models after an independent art review (cesprites car files, ce3d vehicle builders,
  assets/models/player/** and assets/models/traffic/**, the validator, contact sheets).
Keep your own edits in those files to what the merge strictly needs (for example the shader rename below), so the
second half merges cleanly. Do not touch assets/models/player/** or assets/models/traffic/**.
Resolve conflicts by file ownership (R1 owns modern_renderer.gd, the kernel, race_session.gd and the "graphics"
config section; R3 owns vpbr/glass/sign/flare shaders, model_factory.gd, modern_materials.gd; R2 terrain/props/far
ground and their shaders; AS1b the environment models and prop builders; UI1 the screens, settings, gfx.gd).
Generated files are regenerated, never hand-merged: assets/models/manifest.json (tools/blender/export_models.py
--manifest-only, then the validator), .import/.uid files (godot --headless --import).
The lead's trial merge of exactly these heads (git merge-tree, measured) found conflicts only in
assets/shaders/modern/contact_shadow.gdshader (+ .uid) and docs/renderer-modern.md (R1 and R3 both added a §10).
${LEAD_NOTES}
Package reports (open items, deviations, contract issues, notes for the assembly; full reports at the given paths):
${JSON.stringify(REPORTS)}

THEN MAKE THE PACKAGES ONE PICTURE – you own every merged file now (except the R3E/AS1R files named above):
- Light: the terrain and the far ground get the pool uniforms and the low-beam cone (render layer 2, both includes,
  add_pool_material); lamps of the prop models (street lights with their downward anchor, lit windows on lamp
  channel 12, fuel station and pump, customs booth) reach the light pools and the far-field glow through the
  facade (add_lamps / add_static of A-7); the lights layer sets ce_headlight_pos / ce_headlight_dir / ce_headlight
  so sign retro-reflection and paint use the real low beam instead of R3's camera stand-in.
- Reflections: R1's EnvironmentRig and R3's analytic sky in vpbr/glass must not both reflect – measure (pictures of
  the player car at noon and dusk), keep one source, document the choice in docs/renderer-modern.md.
- Wind turbine rotors turn: implement AS1b's tested rotor rotation in vpbr.gdshader vertex() exactly as its report
  specifies (COLOR.a code 0.875, hub = UV2.y × 128 m, angle = ce_time × 1.35 rad/s + per-instance phase); prove it with
  three frames.
- Props: variants per chunk by a stable hash (≤ 2 draw calls per set and chunk, R2/AS1b reports); the lead decision of
  §11 (ground cover ≤ 0.5 m inside bend corridors) can now be filled with AS1b's props/cover_bush and
  props/cover_grass (graphics.modern.props.bend_cover) – do it and show T2/T4 before/after; find and remove the bright
  diamonds AS1b saw at the horizon of S1 (probably far contact shadows).
- What the combination breaks or leaves ugly: z-fighting between road, shoulders and terrain; seams at chunk
  borders; props in the road or floating on slopes; wrong light on lit stand-ins; shadows cut off; flares through
  terrain; sign posts in the air; LOD pops; cars that do not sit on the road on crests and in bends.
- Kiel–Hamburg drives in Modern from start to finish (autopilot, --gfx-preset=medium) with no per-frame errors or
  warnings in the log; pause freezes the picture; --gfx-debug=fail still gives an Arcade stage; leaving Modern frees
  what it loaded (ModelDB.release_all() + ModernMaterials.drop_shared() in RaceRenderers.leave_modern() – the open A-4
  owner); the engine players are stopped on exit (no "leaked at exit" lines, AU-B note).
- Hook the new checks into the runners: UI1's check_options_tabs (-- --graphics=arcade) and check_attract /
  check_attract_scenes with -- --graphics=modern into tools/run_tests.sh; the new render checks of R1, R2 and R3
  (check_road_parity, check_light_base with 'schatten' changed to lit, unshadowed regions, check_props_render,
  check_vehicle_lights, check_occlusion, …) into tools/run_render_checks.sh.
- Quick look (not yet the final look pass – that is RINT-B's): A/B pictures with tools/ab_shot.sh --gfx-preset=high at
  S1–S5, T1, T4, C1 (19:30) and N1 (night, snow); LOOK at every one and fix integration faults; write down honestly what
  still looks worse than Arcade.
GATES on your final head (commands and output in bericht.md): import clean; tools/run_tests.sh green (once, at the
end); tools/golden.sh check 20 von 20; tools/run_render_checks.sh all; tests/sim/modern_sight.gd -- --full and
tests/sim/modern_path_check.gd -- --full (the kernel changes); python3 tools/blender/validate_models.py --report;
ERGEBNIS identity Arcade vs Modern (tests/race/run_stage.gd) on kiel_hamburg; perf_stats of the Kiel–Hamburg run
(render() ms average and max, chunk commit ms max, draw calls, primitives – llvmpipe, measured). Builds and Wine are
RINT-B's. Push every commit to origin wip/v080-rint-a.
Deliver the pictures and bericht.md to ${SP}/deliver/RINT-A/. Return the result format with package "RINT-A", one
acceptance entry per item of this brief and per gate.`

const R3E = `${common('R3E', { mode: 'fresh', base: '4d02ada71e079ab327511fe657220728396624ef' }, 'render')}
YOUR ROLE: R3E – ARCADE PICTURES AS STAND-INS FOR VEHICLES WITHOUT A 3D MODEL (lead decision for gate 1). Your base
is R3's final head 4d02ada (branch worktree-wf_2e14ac26-9d4-1, also origin/wip/v080-r3; it contains R1a, AS1 and R3).
R3's report: ${SP}/deliver/R3/bericht.md (read it first; R3's own handover: ${SP}/m1/R3/STAND.md).
WHY: R3 draws every vehicle set without a model as a painted box; R3's own verdict: "looks clearly worse than Arcade's
sprites". In the first test build the user would drive the Kombi, the Sportwagen or the Gran Turismo as a box and
meet sports cars, vans, SUVs, buses, most trucks and every police car as boxes. Their models come later (AS2a, AS2b).
Until then – and for good, as the safety net for any set without a model – Modern shows Arcade's own picture of that
vehicle, so nothing is ever worse than Arcade. A set that has a model keeps R3's model path unchanged.
BUILD:
1. Sprite sets (render "sprite": traffic and police use ortho sheets with 17 yaw angles; player cars use perspective
   sheets with 21 angles, a camera block and supersampling): a quad facing the camera at the vehicle's pose, the
   cell chosen exactly like Arcade does – read and reuse the logic of RoadRenderer._vehicle_cell, _draw_car and
   _draw_player (scripts/race/road_renderer.gd is FROZEN: read only, never edit; copy what you need) through the
   SpriteDB API (yaw_list, nearest_angle_index, cell_region, anchor, image_width_m, pixels_per_meter, supersample,
   layers incl. the lamp layer, ANGLE_FALLBACK, is_box). The relative yaw is the vehicle's heading against the
   camera's view ray to it, with Arcade's damping and hysteresis where Arcade has them. Size from image_width_m, so the
   picture has the vehicle's real width; the anchor touches the ground. Player car: the picture sits where Arcade's
   player sprite sits – A/B at S1 with --vehicle=kombi, sportwagen and gran_turismo, position and size compared in px
   (measured; aim ≤ 3 px).
   Light: the sheets carry baked light – modulate them like Arcade does for its light parameter (time of day,
   tunnel, fog); brightness within 10 % of Arcade's frame (measured). At night: the sheet's lamp layer plus R3's
   flares at the lamp positions the box stand-in already derives (F6 minimum sizes stay).
2. Box sets (render "box": trucks and buses with textured faces rear/left/right/top, lamp overlays and parts): a real
   3D box mesh per part with Arcade's face textures – exactly what Arcade draws, in true 3D – articulated like R3's
   groups (tractor / trailer) where the parts say so; lamps through R3's box lights and flares.
3. Shadows: the contact shadow under every stand-in as today; where shadow_casters ≥ 1 a hidden box caster.
4. F5 fade and depth occlusion as for models; the stand-in disappears by itself when the manifest gets a model (no
   set ids in code).
5. Performance: few draw calls (a MultiMesh per sheet or similar); measure µs per car like R3's perf().vehicle_us_avg;
   all sheets are loaded in prepare(), nothing while driving (SpriteDB.loads must not change while driving).
FILES YOU OWN: scripts/race3d/layers/vehicles.gd, scripts/race3d/model_factory.gd, scripts/race3d/vehicle_pose3d.gd,
a new script (e.g. scripts/race3d/vehicle_standin.gd), a new shader assets/shaders/modern/vehicle_sprite.gdshader,
new tests tests/unit/race3d/test_vehicle_standin.gd and tests/race3d/render/check_vehicle_standin.gd, one new
German subsection "Ersatzbilder für Fahrzeuge ohne Modell" in docs/renderer-modern.md (inside R3's section).
DO NOT EDIT: billboard.gdshader and every props/terrain file (R2); contact_shadow.gdshader (the assembly RINT-A
renames R3's vehicle shadow to vehicle_shadow in parallel – leave line 155 of vehicles.gd as it is); vpbr.gdshader and
glass.gdshader; anything of R1; frozen Arcade files; assets/models/** and the model pipeline (AS1R works there in
parallel). Push every commit to origin wip/v080-r3e.
TESTS AND GATES: unit tests (the cell choice equals Arcade's for many yaw cases incl. the player's 21 angles; a set
without a model gets the sprite stand-in; a box set gets the textured box; a set with a model is unchanged); the new
render check compares the stand-in with Arcade's sprite at S1 (position, size, brightness); check_vehicles and
test_vehicles green; tools/run_tests.sh once at the end; tools/golden.sh check 20 von 20; tools/run_render_checks.sh
modern.
PICTURES: A/B Arcade | Modern for each kind (sports car, van, SUV, police car, bus, a truck type without a model and
the three player cars) at 20, 60 and 150 m by day and at night, plus before/after against today's painted box. LOOK at
every one and judge honestly. Deliver pictures and bericht.md to ${SP}/deliver/R3E/. Return the result format with
package "R3E".`

const [rintA, r3e] = await parallel([
  () => agent(RINT_A, { label: 'zusammenbau:RINT-A', phase: 'Zusammenbau 1', schema: BUILD_R, isolation: 'worktree' }),
  () => agent(R3E, { label: 'ersatzbilder:R3E', phase: 'Zusammenbau 1', schema: BUILD_R, isolation: 'worktree' }),
])
const brief = (x) => x ? `${x.package}: ${x.commit ? x.commit.slice(0, 7) : '?'} (${x.acceptance.filter(a => a.result !== 'pass').length} offen)` : 'fehlt'
log(`${brief(rintA)} · ${brief(r3e)}`)
return { rintA, r3e }
