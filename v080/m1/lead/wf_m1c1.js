export const meta = {
  name: 'v080-m1-zusammenbau-1',
  description: 'v0.8.0 Modern, M1 assembly part 1: merge the renderer, model, sound and UI packages (RINT-A) and, in parallel, Arcade pictures as stand-ins for vehicles without a 3D model (R3E)',
  phases: [
    { title: 'Zusammenbau 1', detail: 'RINT-A merges R1, R2, R3, AS1b, UI1 and makes them one picture; R3E builds the vehicle stand-ins from the Arcade sheets' },
  ],
}
const REPO = '/home/user/crossing-europe---a-racing-xperience'
const SP = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080'

const startText = (pkg, s) => {
  if (s.mode === 'continue') return `YOUR PACKAGE ID: ${pkg}. You CONTINUE the work of a predecessor that was stopped in the middle
  of its work by an account usage limit (not by a fault of its own). Its handover note is ${SP}/m1/${pkg}/STAND.md; its
  scratch results are in ${SP}/m1/${pkg}/ and ${SP}/deliver/${pkg}/. All of its work is committed: branch ${s.branch},
  head ${s.head}. The last commit ("… Stand beim Abbruch …"), if present, was made by the lead from the predecessor's
  uncommitted files and is UNREVIEWED – review it and compile-check it (tests/check_scripts.gd) before you build on it.
  The predecessor's old worktree ${s.oldWt} stays as it is: never work or commit there.
  START: read STAND.md. If its worktree line names a worktree OTHER than ${s.oldWt}, a successor of this run already
  worked there and was stopped too – continue in THAT worktree (all commands and commits there, on its branch; review
  and commit its uncommitted changes as WIP first; report that branch and worktree in your result). Otherwise, in your
  fresh worktree: git merge --ff-only ${s.head}   (the worktree starts from main; if the fast-forward is impossible,
  stop and report), then  cp -a ${REPO}/.godot . && godot --headless --path . --import , rewrite STAND.md at once with
  YOUR worktree path and branch (keep the predecessor's done/next/pitfalls), and continue with its "next" list until
  the whole brief below is done.`
  if (s.mode === 'fresh') return `YOUR PACKAGE ID: ${pkg}. START: look for a predecessor of this run – the handover file
  ${SP}/m1/${pkg}/STAND.md and the remote branch wip/v080-${pkg.toLowerCase()}. If one exists, do NOT start over: read
  STAND.md, go to the worktree named there (all commands and commits there, on its branch – leave your own fresh
  worktree untouched, and report that branch and worktree in your result), review its uncommitted changes, commit them
  as WIP, and continue where it stopped. Only if there is none, in your fresh worktree: git merge --ff-only ${s.base}
  (the worktree starts from main; if the fast-forward is impossible, stop and report), then
  cp -a ${REPO}/.godot . && godot --headless --path . --import`
  if (s.mode === 'review') return `YOUR PACKAGE ID: ${pkg} – a review role: no commits, no pushes, no branch of your own
  that anybody uses. START: if ${SP}/m1/${pkg}/STAND.md exists, a predecessor of this run was stopped – read it, reuse
  its worktree (named there) and partial results, and continue. Otherwise, in your fresh worktree:
  git merge --ff-only ${s.base}   then  cp -a ${REPO}/.godot . && godot --headless --path . --import . You may change
  files in your worktree for experiments and measurements, but you commit nothing.`
  return `YOUR PACKAGE ID: ${pkg} – a read-only role: no commits, no branch, no safety copy. START: if
  ${SP}/m1/${pkg}/STAND.md exists, a predecessor was stopped by an account usage limit – read it, reuse its working
  copy and partial results, and continue.`
}

const common = (pkg, start, kind) => `
CONTEXT
- Game: "Crossing Europe – A Racing Xperience" (Godot 4.7.2, GDScript, GL Compatibility renderer), repo ${REPO}.
  German user; docs and player-facing texts in German (tr()), code comments in English. v0.7.0 is released (= main).
  v0.8.0 adds a graphics option: today's pseudo-3D game becomes the mode "Arcade" (frozen, pixel-identical); the new
  mode "Modern" is a second, real-3D renderer in the same build with finer models, dynamic light and a "Modern" sound
  profile. The user's wish, literally: "das gesamte Spiel einer deutlichen grafischen Überarbeitung unterziehen.
  Detailreiche Grafik soweit möglich, feinere Modelle, bessere Lichteffekte, Sound- und Musiküberarbeitung" and "echtes
  3D bitte". Wave 0 (session seam, model pipeline, audio core, geometry kernel with fairness tests) is merged in branch
  v0.8.0. This push (M1) runs as parallel packages: renderer skeleton R1a (done), road/environment R1, terrain/props
  R2, vehicles/signs R3, vehicle models AS1 (done; an art review and a rework AS1R follow), environment models AS1b,
  engine sound AU-B (done), options/chooser/showroom/Leistungstest UI1. Then the lead merges everything, QA checks it,
  and the user gets the first test build (Kiel–Hamburg in Modern, for Steam Deck and Windows).
- THE BUILD CONTRACT IS BINDING: docs/dev/v080_contract.md (1,800 lines). Read §2 (rules), the decisions of §3 that
  concern you, your interfaces in §4, §5, your package in §6, §8 and COMPLETELY §11 (amendments after wave 0 – it wins
  over the older text; A-7 is the renderer facade, A-8 the plan and file ownership of this push). Also read the docs
  of your area: ${kind === 'render' ? 'docs/renderer-modern.md, docs/modelle.md, ARCHITECTURE.md §15' : 'docs/modelle.md, docs/audio-modern.md, ARCHITECTURE.md §15, docs/ui.md'}. Where the contract is wrong
  or blocks you: implement the closest sound solution and report it under contract_issues with evidence – never work
  around it silently. Evidence and prototypes of the design studies (starting points, read before reuse): ${SP}/
  (${kind === 'render' ? 'renderer3d/out/spike_src, engine-probe/evidence/prototypes, synthesis/out' : 'assets3d, audio, product-ux, synthesis'}; index in §10 of the contract).
- ${startText(pkg, start)}
${['readonly', 'review'].includes(start.mode) ? '' : `- SAFETY COPY: after EVERY commit run  git push origin HEAD:refs/heads/wip/v080-${pkg.toLowerCase()}  (plain push, never
  force; never push to v0.8.0 or main, never merge into them, never create tags or pull requests).
`}- RESTART PROTOCOL: the container can restart, or an account usage limit can stop you, at any moment; a successor with
  this same brief is then started (both have already happened in this push). (1) Your START instruction above says how
  to find and continue a predecessor; its background processes are gone and half-written output files may be
  incomplete. (2) Keep ${SP}/m1/${pkg}/STAND.md up to date after every step you finish: worktree path and branch,
  done / doing now / next / pitfalls, where your scratch results are.${['readonly', 'review'].includes(start.mode) ? '' : ` (3) Commit and push work in progress at
  least every 30 minutes ("WIP" commits are fine) – unpushed work can be lost for good.`}
- Runs: for EVERY game run set XDG_DATA_HOME to an ABSOLUTE folder under your scratch dir; pass --graphics=arcade|modern
  explicitly. Rendering needs  xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3
  --audio-driver Dummy …  (software OpenGL, llvmpipe – no real GPU, no loudspeakers here: everything about a Steam
  Deck, a real GPU or how something sounds to a person is "inferred", never "measured"). The default graphics preset
  on this machine is "low" (adapter tier software: no shadow casters) – for pictures pass --gfx-preset=medium or high.
  Up to six agents share the 4 cores and 16 GB: heavy jobs (Godot renders, Blender, audio renders, test suites) one at
  a time with nice -n 10 and at most 2 worker processes; run the complete tools/run_tests.sh (9–15 min) at most twice
  (use its filter argument while iterating) and tools/golden.sh check (Arcade identity, must print 20 von 20
  identisch) once at the end. Tools: godot, python3 (numpy, PIL), ffmpeg, ImageMagick, Blender 5.2 as Python module
  /home/user/tools/bpyenv/bin/python, tools/run_tests.sh, tools/run_render_checks.sh, tools/golden.sh, tools/ab_shot.sh
  (in branches that contain R1a), tools/models_contact_sheet.sh, tools/blender/validate_models.py,
  tools/audio/qc/audio_qc.py.
- Shell: the Bash tool may refuse compound commands with heredocs or several chained git commands ("too complex"):
  write helper scripts into your scratch folder and run them one by one; write commit messages to a file and use
  git commit -F <file>. "-s" scripts must not name autoload-dependent classes statically; compile-check with
  tests/check_scripts.gd.
- Rule 1: the frozen Arcade files are never edited${kind === 'render' ? '' : ' (sprites are never re-rendered)'}. Stay inside your file ownership (§5 with A-8)${kind === 'render' ? '; packages of this push talk to each other only through the facade of A-7 with duck typing' : ''}.
- ${kind === 'render' ? `LOOK AT YOUR OWN PICTURES: you can open PNG/JPG files with the Read tool. Judge every picture you deliver honestly
  against the Arcade frame of the same simulation state. "Modern" has to look clearly better than Arcade, not merely
  different; say plainly where it does not yet.` : `LOOK AT / MEASURE YOUR OWN RESULTS: you can open PNG/JPG files with the Read tool. Judge every picture you deliver
  honestly; say plainly where something is not yet good enough.`}
- Scratch for working files: ${SP}/m1/${pkg}/ ; pictures, previews and reports for review: ${SP}/deliver/${pkg}/ (write
  your full report there as bericht.md). Never commit intermediates or previews. Disk space is limited: delete large
  scratch items (exports, copies of the tree, caches you no longer need) when you are done.
- ${['readonly', 'review'].includes(start.mode) ? 'You make no commits and change no branch.' : `Commits: sensible steps on your branch; every commit message (German subject line) ends with
  "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" and
  "Claude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq". No model names anywhere else.`}
- Priorities when time gets tight: ${kind === 'render' ? '(1) nothing broken – gates green, Arcade identical, fairness tests green; (2) the interfaces others depend on; (3) the look' : '(1) nothing broken – gates green, Arcade identical; (2) the interfaces others depend on; (3) quality of what the player sees or hears most; breadth last'}.
  Deliver the core solid and list what is left under notes_for_next rather than leaving everything half-done.
- RESULT: keep it compact – summary at most 250 words; deviations, contract_issues and notes_for_next at most 10
  entries each, one or two sentences per entry; the details belong into bericht.md. Mark numbers measured/inferred.
`

const buildSchema = (verdictKey, verdictDesc) => ({
  type: 'object',
  properties: {
    package: { type: 'string' }, branch: { type: 'string' }, commit: { type: 'string' }, worktree: { type: 'string' },
    summary: { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
    acceptance: { type: 'array', items: { type: 'object', properties: { check: { type: 'string' }, result: { type: 'string', enum: ['pass', 'fail', 'partial', 'not_run'] }, evidence: { type: 'string' } }, required: ['check', 'result', 'evidence'] } },
    tests_total: { type: 'integer' }, tests_failed: { type: 'integer' },
    deviations: { type: 'array', items: { type: 'string' } },
    contract_issues: { type: 'array', items: { type: 'string' } },
    notes_for_next: { type: 'array', items: { type: 'string' } },
    [verdictKey]: { type: 'string', description: verdictDesc },
    media: { type: 'array', items: { type: 'string' }, description: 'absolute paths with a German caption after " – "' },
  },
  required: ['package', 'branch', 'commit', 'worktree', 'summary', 'files_changed', 'acceptance', 'tests_total', 'tests_failed', 'deviations', 'contract_issues', 'notes_for_next', verdictKey, 'media'],
})
const BUILD_R = buildSchema('look_verdict', 'honest judgement of the pictures against Arcade: what is better, what is worse, what is missing')
const BUILD_C = buildSchema('quality_verdict', 'honest judgement of what the player will see/hear: what is good, what is not yet, what is missing')

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
