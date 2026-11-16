export const meta = {
  name: 'v080-m2-frueh-modelle',
  description: 'v0.8.0 Modern, early start of M2 vehicle models: remaining player and traffic cars (AS2a), independent art review, trucks/buses/police (AS2b), rework (AS2R); low CPU priority',
  phases: [
    { title: 'Modelle', detail: 'AS2a: Kombi, Sportwagen, Gran Turismo, SUV, Van, Sports; interiors and glass for all player cars' },
    { title: 'Kritik und Lkw/Busse/Polizei', detail: 'independent art review of the cars, in parallel AS2b: trucks, buses, police' },
    { title: 'Nacharbeit', detail: 'AS2R: fix the confirmed defects, self-review of the heavy and police models' },
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

const REVIEW = {
  type: 'object',
  properties: {
    overall: { type: 'string' },
    models: { type: 'array', items: { type: 'object', properties: {
      model: { type: 'string' },
      versus_sprite: { type: 'string', enum: ['finer', 'equal', 'cruder'] },
      showroom_ready: { type: 'boolean' },
      defects: { type: 'array', items: { type: 'object', properties: {
        severity: { type: 'string', enum: ['high', 'medium', 'low'] }, where: { type: 'string' }, problem: { type: 'string' }, evidence: { type: 'string' }, fix: { type: 'string' } },
        required: ['severity', 'where', 'problem', 'evidence', 'fix'] } } },
      required: ['model', 'versus_sprite', 'showroom_ready', 'defects'] } },
    pipeline_issues: { type: 'array', items: { type: 'string' } },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['overall', 'models', 'pipeline_issues', 'media'],
}



// Early start of M2 vehicle models: AS2a -> [KRITIK-2 || AS2b] -> AS2R
// args: { as1r: '<sha of AS1R final head>', as1rBranch: '<branch>', as1rWt: '<worktree>' }
const AS1R = args.as1r
const AS1R_BRANCH = args.as1rBranch
const AS1R_WT = args.as1rWt
const R3_HEAD = '4d02ada71e079ab327511fe657220728396624ef'

const EARLY = `EARLY START – PRIORITY RULE: you are an early start of the next push (M2). The assembly of push M1 runs at the
same time and is on the critical path for the user's first test build. Run EVERY heavy job (Blender exports and bakes,
Godot renders, test suites) with nice -n 19 (not 10) and at most one worker process (export_models.py --jobs 1);
never two heavy jobs at once.`

const QUALITY_BAR = `THE QUALITY BAR. The wave-0 reference cars are not good enough – look at ${SP}/deliver/FIX0/p5_kontaktbogen_tag.jpg and
p6_kontaktbogen_nacht.jpg first: blobby bodies, crumpled coarse levels, lamps as flat patches, opaque glass, no
interior, dull rims. "Feinere Modelle" is the user's explicit wish, and the player car is on screen for the whole
game, seen from behind and slightly above at 6–12 m. What a finished car needs, most-seen first:
- A clean, taut body: crisp character lines and wheel arches, smooth shading with hard edges only where metal is
  folded (split normals / marked sharp edges survive the export), correct proportions against the sprite generator's
  silhouette, panel gaps for doors, bonnet, boot and fuel flap, no dents or waves from decimation at any level.
- The rear: lamp clusters with depth (housing, lens, inner structure) whose lit areas pass the validator's lamp rules
  at every level, a third brake light, number plate with frame and lit plate lamp, bumper with diffuser/reflectors,
  exhaust tips, badge, rear window with a visible parcel shelf and headrests behind real transparent glass.
- Glass and interior for the player cars: transparent tinted glass (you own the look part of glass.gdshader, A-8;
  keep the instance uniforms and the fade untouched) over a simple dark interior – seats, headrests, dashboard,
  steering wheel on the left; traffic cars may keep dark glass with a reflective look but must not look painted.
- Wheels: multi-spoke rims with depth, brake discs behind them, tyres with a rounded shoulder and sidewall, real
  wheel arches with dark liners; nothing floating, nothing intersecting.
- Front: headlights with reflector and lens depth, daytime running lights, grille with depth, mirrors with glass,
  wipers, door handles, roof antenna.
- Coarser levels (LOD1/LOD2) keep the silhouette and the lamp outlines exactly (same outlines at all levels, bounds
  check between levels, decals cut along their contour – no saw teeth at bumper corners); they simplify, they never
  crumple. Indicators of every traffic design ≥ 60 cm² from behind and ≥ 40 cm² from ahead per side.
- The truck: a believable tractor (cab with windows, mirrors, steps, tanks, lights, mud flaps) and a box trailer
  with underrun bar, lamp bars, reflective contour marking, plates; liveries as paint sets. It is the most frequent
  obstacle of the game: its rear at 20–150 m must read at once (lamps, markings).
Stay inside the budgets of §4.6.9 – spend triangles where the camera looks (rear and sides of the player car at
LOD0; the "show" level for the vehicle selection may be generous). Use the generators' own detail levels and
design tables (cesprites, hooks only – additive, no sprite vertex may move) rather than decimating a dense mesh.
Shaders: vpbr.gdshader, model_factory.gd and modern_materials.gd belong to the renderer package R3 in this push –
do not edit them; say under notes_for_next what the cars would need from the paint shader (clear coat, flakes,
chrome …). Work in rounds: build, render the contact sheets (day, night, each lamp channel, the chase-camera view
from behind at 8 m and 30 m, the showroom A/B), LOOK at them, list the worst defects, fix, repeat – at least three
rounds for the two player cars. Set showroom: true only when the real-time show level is at least as good as the
sprite in the same-camera A/B; otherwise leave it false and say exactly what is missing.`

const PIPE_NOTE = `THE PIPELINE AND ITS STANDARD: the vehicle models of the slice went through build (AS1), an independent art review
(${SP}/deliver/AS1-KRITIK/bericht.md – read it completely, its defect list is the checklist of what not to repeat)
and a rework (AS1R, ${SP}/deliver/AS1R/bericht.md and ${SP}/m1/AS1R/STAND.md – its fixes are the standard every
new car must meet from the start: lamp bodies, bumper ends, wheel-arch liners, brake discs, plates, glass, rims, LOD
pop limits, caster rules, validator rules). Its tools are in ${SP}/m1/AS1R/bin (rebuild.sh, sheet.sh, pop.sh,
popmeasure.py, probe.py …) and the reviewer's tools in ${SP}/m1/AS1-KRITIK/tools_kritik – reuse them (copy into
your own scratch folder, do not edit them in place).`

phase('Modelle')
const as2a = await agent(`${common('AS2a', { mode: 'fresh', base: AS1R }, 'content')}
${EARLY}
YOUR ROLE: AS2a – PLAYER CARS AND TRAFFIC CARS, THE REST (contract §6 wave 3 "AS2a"; D17–D24; §4.6 complete; A-4;
docs/modelle.md). Your base is the final head of the rework AS1R ${AS1R} (branch ${AS1R_BRANCH}). Right after the
fast-forward, merge the renderer package R3 (commit ${R3_HEAD}: paint with clear coat and flakes, glass, chrome, the
vehicle layer) with git merge --no-ff ${R3_HEAD} (German message), so you can judge every car through the game's own
shaders; and copy the export cache: cp -a ${AS1R_WT}/tools/blender/_cache3d tools/blender/ (keyed by content, saves
Blender time). Push every commit to origin wip/v080-as2a.
MODELS: player/kombi, player/sportwagen, player/gran_turismo (race mesh from the generator detail levels, show mesh,
shadow mesh – as AS1 did for limousine and kompakt), traffic/suv, traffic/van, traffic/sports (geometry decals,
LOD0–2, every colour set of the sprite manifest as "sets" paint). Then for ALL FIVE player cars: interiors (new
cesprites/carinterior.py: seats, headrests, dashboard, steering wheel on the left, door cards, rear shelf – visible
through the glass from the chase camera) and real transparent glass; the 3D fixes the contract names (wrap-around
lamps, grille mesh, mirror arms) and rim styles per car. Acceptance: as AS1; all 26 traffic car sets and all 5 player
cars resolve to models (no stand-in left among cars – buses, trucks and police are AS2b's); showroom flags decided by
same-camera A/B pictures against the sprites.
FILES YOU OWN: cesprites/{carbody, cardetail, player_cars, vehicles, designs}.py (additive hooks only – no sprite
vertex may move: tools/blender/check_sprite_geometry.py after every cesprites change, "REIHENFOLGE" lines are fine,
"ANDERS" is not), new cesprites/carinterior.py, tools/blender/ce3d/{vehicles3d, traffic3d, interior3d, extras3d}.py,
assets/models/player/**, assets/models/traffic/{suv,van,sports}/** (and the AS1 cars where interiors, glass, rims or
fixes change them), tools/models/contact_sheet.gd, and in this wave the shared pipeline files of §5 (ce3d core, glb,
roles, bake, lod, manifest, catalog3d, export, export_models.py, validate_models.py, tools/models/**, model_db.gd) –
changes there backwards-compatible; regenerate assets/models/manifest.json yourself on your branch. Never touch
assets/models/props/**, the renderer (scripts/race3d/**, assets/shaders/modern/** – report what the cars need from
the shaders), the frozen Arcade files and sprites.
${PIPE_NOTE}
${QUALITY_BAR}
DELIVER to ${SP}/deliver/AS2a/: contact sheets day and night (every lamp channel) of all five player cars and the
three new traffic types, chase-camera views from behind at 8 m and 30 m for each player car next to its Arcade sprite,
showroom A/B per player car, LOD steps at their switch distances, bericht.md. GATES: validator green, budgets of
§4.6.9, check_sprite_geometry, export determinism (--check-keys; a second bake byte-identical), tools/run_tests.sh
(once, at the end), tools/golden.sh check 20 von 20. An independent art reviewer will inspect your branch afterwards and
a rework step follows – leave clear notes on what you consider weakest. Return the result format with package "AS2a".`,
  { label: 'modelle:AS2a', phase: 'Modelle', schema: BUILD_C, isolation: 'worktree' })
if (!as2a) return { as2a: null }
log(`AS2a: ${as2a.commit ? as2a.commit.slice(0, 7) : '?'} (${as2a.acceptance.filter(a => a.result !== 'pass').length} offen)`)
const AS2A_INFO = JSON.stringify({ branch: as2a.branch, commit: as2a.commit, worktree: as2a.worktree, summary: as2a.summary,
  open: as2a.acceptance.filter(a => a.result !== 'pass'), deviations: as2a.deviations, quality: as2a.quality_verdict,
  notes: as2a.notes_for_next, media: as2a.media })

phase('Kritik und Lkw/Busse/Polizei')
const [review, as2b] = await parallel([
  () => agent(`${common('KRITIK-2', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT ART REVIEW OF THE CAR MODELS (no building). AS2a delivered the remaining player and traffic cars
on branch ${as2a.branch} (commit ${as2a.commit}), worktree ${as2a.worktree} – READ-ONLY for you: no edits, no commits
there. Work on a copy in your scratch folder (cp -a the worktree without build/ and without tools/blender/_cache3d;
absolute XDG_DATA_HOME). You make no commits.
Its report: ${AS2A_INFO}
The review of the first cars and its tools: ${SP}/deliver/AS1-KRITIK/bericht.md and ${SP}/m1/AS1-KRITIK/tools_kritik
(the game camera of D12, the sprite comparison as road_renderer.gd draws it, mesh dumps) – reuse them.
Do not trust the report – render and look yourself. You are the art director who answers one question for the user:
are these cars visibly FINER than the Arcade sprites and good enough to be looked at for hours? Review all five player
cars (kombi, sportwagen, gran_turismo, and limousine and kompakt again because interiors, glass and rims changed) and
traffic suv, van, sports (plus a quick look at sedan, hatch, wagon for consistency of the fleet):
1. The chase camera from behind and above at 8 m and 30 m (1280×720, the shipped shaders, a daylight rig with one
   shadowed sun and a night rig), front and rear three-quarter close-ups, side views, every LOD level at its distance
   (40 m, 120 m) and enlarged, every lamp channel at night, interiors through the glass, a flat-shaded or wireframe view.
2. Side by side with the Cycles sprite of the same vehicle in the same camera, and with the generator's silhouette.
3. Defects, each with where, what, a picture as evidence and a fix the builder can carry out: proportions, waves,
   faceting, holes, normals, z-fighting, floating or saw-tooth decals, lamps without depth, lamp outlines that change
   between levels, LOD pops, missing parts, glass that looks painted, interiors that clip through the body, wheels
   that intersect or float, wrong spin or steering pivots, shadow meshes that do not match, paint sets that look
   wrong; validator, budgets, lamp rules, draw calls per car, the showroom flags (deserved or too cautious?).
Rank by what the player sees most (the rear of the player cars first). Comparison sheets and bericht.md into
${SP}/deliver/KRITIK-2/.`,
    { label: 'kritik:AS2a', phase: 'Kritik und Lkw/Busse/Polizei', schema: REVIEW }),
  () => agent(`${common('AS2b', { mode: 'fresh', base: as2a.commit }, 'content')}
${EARLY}
YOUR ROLE: AS2b – TRUCKS, BUSES, POLICE (contract §6 wave 4 "AS2b"; D17–D24; §4.6; A-4; docs/modelle.md). Your base
is AS2a's final head ${as2a.commit} (branch ${as2a.branch}; it contains AS1, AS1R, R3 and AS2a). Copy its export cache
first: cp -a ${as2a.worktree}/tools/blender/_cache3d tools/blender/ . Push every commit to origin wip/v080-as2b.
AS2a's report: ${AS2A_INFO}
MODELS: every heavy set (traffic/truck_* and traffic/bus_*: 7 sets – check whether the AS1 truck already covers the
truck liveries and build what is missing; buses as articulated or rigid bodies like the Arcade box parts) and all 18
police sets (police/<country>: the car bodies come from AS2a's cars with the country liveries, light bars and
beacons). Acceptance: validator green; all 7 heavy and 18 police sets resolve to models; beacon channels A and B
alternate; the part boxes equal the Arcade box parts (collision unchanged); trucks and buses articulate through groups
with pivots like the AS1 semitrailer (R3's vehicle layer builds the articulation from groups).
FILES YOU OWN: cesprites/{heavy, police}.py (additive hooks only – check_sprite_geometry.py after every change),
tools/blender/ce3d/{heavy3d, police3d}.py (new) and truck3d.py, assets/models/traffic/{truck_*, bus_*}/**,
assets/models/police/**, the shared pipeline files of §5 (backwards-compatible), the regenerated manifest. Never
touch the car models of AS2a (an art review of them runs in parallel; its rework follows after you), the renderer,
the frozen Arcade files and sprites.
${PIPE_NOTE}
THE QUALITY BAR for heavy vehicles: the truck is the most frequent obstacle of the game – its rear at 20–150 m must
read at once (lamps, underrun bar, reflective contour marking, plates, mud flaps); cabs with windows, mirrors, steps,
tanks and lights; buses with windows, doors, destination display, wheels in real arches; police cars as finished as the
traffic cars they are built on, with livery decals that follow the body and light bars with depth. Work in rounds:
build, contact sheets day and night (every lamp channel incl. beacons A/B), chase-camera views at 20/60/150 m next to
the Arcade sprite or box, LOOK, fix, repeat. DELIVER to ${SP}/deliver/AS2b/ with bericht.md. GATES: validator,
budgets of §4.6.9, check_sprite_geometry, export determinism, tools/run_tests.sh (once, at the end), tools/golden.sh
check 20 von 20. Return the result format with package "AS2b".`,
    { label: 'modelle:AS2b', phase: 'Kritik und Lkw/Busse/Polizei', schema: BUILD_C, isolation: 'worktree' }),
])
if (review) {
  const high = review.models.flatMap(m => m.defects.filter(d => d.severity !== 'low'))
  log(`Kritik: ${review.models.map(m => `${m.model} ${m.versus_sprite}`).join(', ')}; ${high.length} Mängel hoch/mittel`)
} else log('Kritik ausgefallen – die Nacharbeit prüft selbst')
if (as2b) log(`AS2b: ${as2b.commit ? as2b.commit.slice(0, 7) : '?'} (${as2b.acceptance.filter(a => a.result !== 'pass').length} offen)`)
const base = as2b || as2a
const reviewText = review ? JSON.stringify(review) : 'NOT AVAILABLE – the reviewer failed. Make your own strict review first (chase camera 8/30 m day and night, close-ups, every LOD level at its distance, lamp channels, interiors, comparison with the Cycles sprites) and fix what you find.'

phase('Nacharbeit')
const as2r = await agent(`${common('AS2R', { mode: 'fresh', base: base.commit }, 'content')}
${EARLY}
YOUR ROLE: AS2R – REWORK OF THE CAR MODELS AFTER THE INDEPENDENT ART REVIEW, AND A STRICT SELF-REVIEW OF THE HEAVY AND
POLICE MODELS. Your base is ${base.commit} (branch ${base.branch}; it contains AS2a${as2b ? ' and AS2b' : ' – AS2b failed, so only the car models are there'}).
Copy the export cache first: cp -a ${base.worktree}/tools/blender/_cache3d tools/blender/ . Push every commit to origin
wip/v080-as2r.
AS2a reported: ${AS2A_INFO}
${as2b ? `AS2b reported: ${JSON.stringify({ summary: as2b.summary, open: as2b.acceptance.filter(a => a.result !== 'pass'), deviations: as2b.deviations, quality: as2b.quality_verdict, notes: as2b.notes_for_next, media: as2b.media })}` : ''}
The independent art review of the car models found: ${reviewText}
Check each defect yourself first (reject it with evidence if it is wrong). Fix every confirmed high and medium defect
and the cheap low ones, most-seen first (the rear of the player cars, then the traffic cars at 20–150 m). Then review
the heavy and police models of AS2b yourself with the same strictness (chase camera at 20/60/150 m day and night,
beacons, LOD steps, comparison with the Arcade sprite or box) and fix what you find. Files: everything AS2a and AS2b
owned (see their reports); the same rules (additive cesprites hooks, check_sprite_geometry, no renderer files, no
props, no frozen files).
${PIPE_NOTE}
Re-render the reviewer's comparison views after each round and LOOK at them. Then: validator, check_sprite_geometry,
contact sheets day and night, the showroom A/B with honest flags, export determinism, tools/run_tests.sh,
tools/golden.sh check 20 von 20. Deliver to ${SP}/deliver/AS2R/ with bericht.md. Return the result format with
package "AS2R" (the state after the rework); rejected findings under deviations.`,
  { label: 'nacharbeit:AS2R', phase: 'Nacharbeit', schema: BUILD_C, isolation: 'worktree' })
if (as2r) log(`AS2R: ${as2r.commit ? as2r.commit.slice(0, 7) : '?'} (${as2r.acceptance.filter(a => a.result !== 'pass').length} offen)`)
return { as2a, review, as2b, as2r }
