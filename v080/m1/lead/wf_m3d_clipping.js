export const meta = {
  name: 'v080-clipping',
  description: 'v0.8.0: the user saw a white car clip slightly into another car twice on Kassel – Erfurt in the first test build, linked to their steering – reproduce and analyse independently, diagnose with an adversarial counter-check, fix visually in Modern (simulation and Arcade untouched), independent review, fix round and re-check',
  phases: [
    { title: 'Untersuchung', detail: 'CLIP-NACHSTELLEN (reproduce and measure in the test build and on the M2 head) and CLIP-ANALYSE (code and geometry) side by side' },
    { title: 'Diagnose', detail: 'CLIP-DIAGNOSE: root causes ranked with evidence, fix design; two counter-checks try to refute it' },
    { title: 'Umsetzung', detail: 'FIX-CLIP on the M2 head: visual-only fix, tests, gates, before/after pictures' },
    { title: 'Prüfung', detail: 'QA-CLIP: independent review against the reproduction, fairness and Arcade identity' },
    { title: 'Nacharbeit', detail: 'FIX-CLIP2 on blocker/high/medium findings, NACH-CLIP re-check' },
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

// The user's report on the first test build: a white car clips slightly, twice, linked to the user's steering.
// ARGS: { zs1: '<test build commit>', base: '<M2 head to fix on>' }
const A = args || {}
const ZS1 = A.zs1
const BASE = A.base
const D = (p) => `${SP}/deliver/${p}/bericht.md`

const REPORT = `THE USER'S REPORT (German, verbatim, 2026-11-12): "ZS1 Kassel-Erfurt auf meinem Main-PC gespielt. Keine größeren Bugs,
aber leichtes Clipping bei einem weissen PKW. trat 2 mal auf und hing offenbar mit meiner Lenkbewegung zusammen, sah nur
etwas merkwürdig aus und ist kein Game Breaker." – i.e. the first test build ZS1 (commit ${ZS1}, archives in
${SP}/deliver/ZS1/), the stage Kassel – Erfurt (network stage "erfurt_kassel"; find out in which race and direction the
user can drive it), on the user's Windows main PC with a real graphics card – most probably in the graphics mode
"Modern" (the point of the test build), but Arcade is not excluded. No bigger bugs. A white passenger car (PKW) clipped
slightly, twice, apparently connected with the user's steering movement; it looked strange, not game-breaking. It is not
said whether the white car was the user's own car or a traffic car; traffic models in ZS1 come in several colours, white
among them, and the player cars Limousine and Kompakt are models in ZS1 (Kombi, Sportwagen, GT still pictures).`

const LEADS = `LEADS THE LEAD FOUND IN THE CODE (unverified – confirm or refute each with evidence, and look for others):
- The simulation collides axis-aligned boxes: scripts/gameplay/traffic_system.gd find_collision() hits only when
  |dz| < (length_a + length_b)/2 × hitbox_scale and |dx| < (width_a + width_b)/2 × hitbox_scale, with
  collision.hitbox_scale 0.95 (config/game_config.json) – two cars can overlap by about 5 % of their summed half sizes
  without a collision (Arcade hides that: its pictures are drawn one over the other).
- A car BEHIND the player (dz < 0) only collides when at least collision.rear_min_visible_fraction 1/3 of it is visible
  through Arcade's projection (proj.visible_fraction) – the player can steer into a car beside-behind it that Arcade's
  camera does not show; Modern's chase camera may show it.
- After a collision the player is invulnerable (slowdown_s 3 + push_extra_s 0.5 + invulnerable_grace_s 0.75) and
  blinks – it can pass through traffic.
- Modern turns the models visibly: scripts/race3d/layers/vehicles.gd – the player's yaw = steering × player_steer_deg 3
  + understeer × 6 + lateral speed, up to player_yaw_max_deg 20, body roll up to 2.5°, the front wheels steer; traffic
  cars take their own heading from the lateral speed up to vehicle_yaw_max_deg 30 (config render.*). The collision boxes
  do not turn – a corner of a turned model can reach into a neighbour that the simulation does not touch.
- The model sizes are matched to the sprite manifest's object sizes (validator ±2 %); whether they equal the simulation's
  collision sizes (vehicle.width_m/length_m, traffic car width/length) is not checked anywhere.
- Also possible: wheels through the wheel arches when steering, a model through the guardrail or the road, the camera's
  near plane cutting a car beside the camera.`

const RULES = `HARD RULES FOR ANY FIX: the simulation, the collision rules and Arcade stay exactly as they are (the frozen Arcade files,
scripts/gameplay/**, scripts/race/** except the Modern seam, config values Arcade reads) – both modes share physics, results
and leaderboards, so a collision must happen in Modern exactly when it happens in Arcade. The fix is visual and lives in
the Modern renderer. Fairness (contract F1/F6, tests/sim/modern_sight.gd): a car must never be visible later or smaller
than in Arcade; its lights keep their minimum size. Prefer a clean visual rule (for example: turned models keep their
corners out of a neighbour – limit the visual yaw against close neighbours; a residual overlap of a few centimetres from
the 0.95 hitbox resolved by a small symmetric visual side offset; a car the simulation lets the player drive into,
because Arcade would not show it, fades out or ghosts while it overlaps instead of showing the cut) – but decide from
the evidence, not from this list.`

const FILES_NOW = `OWNERSHIP RIGHT NOW: wave 3 runs beside you – R4 owns the renderer core including scripts/race3d/layers/vehicles.gd,
the shaders, race_session.gd/race_renderers.gd and config "graphics"/render keys; R5 tunnels/bridges, R6 structures; AS5a
the city models; QA-M2/FIX-M2 the assembly. A fix therefore goes into NEW files of its own (for example
scripts/race3d/vehicle_clearance.gd, a pure static helper with its own constants, and tests/unit/race3d/
test_vehicle_clearance.gd, a render or sim check of your own) plus the SMALLEST possible hook in layers/vehicles.gd (a few
lines, clearly marked "# FIX-CLIP"), so that the lead can merge it with R4's changes; no edits to config files (constants
in your helper, with an optional ConfigLoader lookup of new keys under render.* that default to your constants).`

const MACHINE = `MACHINE: up to eight agents share 4 cores and 15 GB (wave 3, AS5a, QA-M2). Run every heavy job (Godot renders, test
suites) with nice -n 19, one at a time; before a Godot run check free -g – below 3 GB "available", wait (sleep 60) and
check again. A run that only times out under this load is not a finding by itself: repeat it before you report it.`

const NACH_SCHEMA = {
  type: 'object',
  properties: {
    reproduced: { type: 'string', enum: ['yes', 'partly', 'no'], description: 'did you see the clipping the user describes?' },
    mechanisms: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, what: { type: 'string' }, build: { type: 'string', description: 'ZS1 test build, M2 head or both' },
      situation: { type: 'string', description: 'stage, km, cars, steering, speed' },
      depth_m: { type: 'string', description: 'measured penetration depth (max / typical)' },
      frequency: { type: 'string', description: 'how often it occurs in a normal drive (measured on a stage run)' },
      visible: { type: 'string', description: 'how it looks from the chase camera, picture paths' },
      likely_user_case: { type: 'boolean' } },
      required: ['id', 'what', 'build', 'situation', 'depth_m', 'frequency', 'visible', 'likely_user_case'] } },
    method: { type: 'string', description: 'how you reproduced and measured (scripts in your scratch folder)' },
    arcade_same_moment: { type: 'string', description: 'what Arcade shows in the same simulation states' },
    media: { type: 'array', items: { type: 'string' } },
    notes: { type: 'array', items: { type: 'string' } },
  },
  required: ['reproduced', 'mechanisms', 'method', 'arcade_same_moment', 'media', 'notes'],
}

const ANA_SCHEMA = {
  type: 'object',
  properties: {
    mechanisms: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, what: { type: 'string' }, code: { type: 'string', description: 'file:line references' },
      worst_case_m: { type: 'string', description: 'computed penetration depth, with the numbers used' },
      likelihood: { type: 'string', enum: ['high', 'medium', 'low', 'refuted'] }, why: { type: 'string' } },
      required: ['id', 'what', 'code', 'worst_case_m', 'likelihood', 'why'] } },
    sizes: { type: 'array', items: { type: 'string' }, description: 'per vehicle type: collision width/length vs model width/length (both builds)' },
    fix_options: { type: 'array', items: { type: 'object', properties: {
      option: { type: 'string' }, solves: { type: 'array', items: { type: 'string' } }, risks: { type: 'string' },
      fairness: { type: 'string' }, cost: { type: 'string' } }, required: ['option', 'solves', 'risks', 'fairness', 'cost'] } },
    notes: { type: 'array', items: { type: 'string' } },
  },
  required: ['mechanisms', 'sizes', 'fix_options', 'notes'],
}

const DIAG_SCHEMA = {
  type: 'object',
  properties: {
    root_causes: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, what: { type: 'string' }, evidence: { type: 'string' }, user_case: { type: 'string', enum: ['most likely', 'possible', 'unlikely'] } },
      required: ['id', 'what', 'evidence', 'user_case'] } },
    fix_design: { type: 'string', description: 'the visual rule(s), exact behaviour, constants, where the code goes, the hook in vehicles.gd' },
    fairness_argument: { type: 'string' },
    arcade_identity: { type: 'string' },
    tests: { type: 'array', items: { type: 'string' }, description: 'unit tests and measured checks the fix must add' },
    acceptance: { type: 'array', items: { type: 'string' }, description: 'measurable acceptance criteria' },
    risks: { type: 'array', items: { type: 'string' } },
  },
  required: ['root_causes', 'fix_design', 'fairness_argument', 'arcade_identity', 'tests', 'acceptance', 'risks'],
}

const VERDICT = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean', description: 'true if the diagnosis or the design is wrong or unsafe in a way that matters' },
    problems: { type: 'array', items: { type: 'object', properties: {
      severity: { type: 'string', enum: ['blocker', 'high', 'medium', 'low'] }, problem: { type: 'string' }, evidence: { type: 'string' },
      correction: { type: 'string' } }, required: ['severity', 'problem', 'evidence', 'correction'] } },
    confirmed: { type: 'array', items: { type: 'string' }, description: 'what you checked and found right' },
  },
  required: ['refuted', 'problems', 'confirmed'],
}

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement, 5-10 sentences' },
    findings: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, severity: { type: 'string', enum: ['blocker', 'high', 'medium', 'low'] },
      area: { type: 'string' }, where: { type: 'string' }, problem: { type: 'string' },
      evidence: { type: 'string', description: 'command + output excerpt or picture path; measured vs inferred' },
      repro: { type: 'string' }, fix: { type: 'string' } },
      required: ['id', 'severity', 'area', 'where', 'problem', 'evidence', 'repro', 'fix'] } },
    checked_ok: { type: 'array', items: { type: 'string' } },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'findings', 'checked_ok', 'media'],
}

const RECHECK = {
  type: 'object',
  properties: {
    verdict: { type: 'string' },
    per_finding: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, status: { type: 'string', enum: ['fixed', 'partly', 'not_fixed', 'not_checked'] },
      evidence: { type: 'string' } }, required: ['id', 'status', 'evidence'] } },
    findings: FINDINGS.properties.findings,
    gates: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'per_finding', 'findings', 'gates'],
}

// ---------------------------------------------------------------- investigation (two independent angles)
phase('Untersuchung')
const [nach, ana] = await parallel([
  () => agent(`${common('CLIP-NACHSTELLEN', { mode: 'review', base: ZS1 }, 'render')}
${REPORT}
YOUR ROLE: CLIP-NACHSTELLEN – REPRODUCE AND MEASURE what the user saw. Your fresh worktree starts at the test build ${ZS1}
(the user's build). Later in your work check the M2 head ${BASE} too (git checkout --detach ${BASE} in the same worktree,
re-import; it has all vehicle models of AS2R) – the fix will be made there.
${LEADS}
${MACHINE}
WHAT TO DO: (1) Find the stage and race the user drove (Kassel – Erfurt) and drive it in Modern with traffic (autopilot
or your own scripted input) – instrument the run: every frame, take the visual models of all vehicles (player and
traffic, the nodes of layers/vehicles.gd with their real meshes or their oriented bounding boxes from the model extents)
and log every pair whose geometry intersects, with the penetration depth, the relative position (dz, dx), both yaws, the
player's steering, the speed and the simulation state (collision? invulnerable? rear rule?). Count how often it happens
per 10 km and classify each case by mechanism. (2) Build controlled scenes for the cases you find (a white traffic car
beside, beside-ahead and beside-behind the player at the closest distance that does not collide; the player steering
towards it; lane changes of traffic next to the player; trucks; after a collision while the player blinks) and render
them from the chase camera at --gfx-preset=high and medium (Steam Deck preset too) – Modern and Arcade from the same
simulation state (tools/ab_shot.sh or your own scene script). LOOK at the pictures: which case looks like "slight
clipping linked to steering"? Make a short clip (fixed 60 fps) of the most likely case. (3) Repeat the counts on the M2
head ${BASE}. Put scripts into ${SP}/m1/CLIP-NACHSTELLEN/, pictures and bericht.md into ${SP}/deliver/CLIP-NACHSTELLEN/.
Measured vs inferred: everything here is software rendering; say so.`,
    { label: 'untersuchung:CLIP-NACHSTELLEN', phase: 'Untersuchung', schema: NACH_SCHEMA, isolation: 'worktree' }),
  () => agent(`${common('CLIP-ANALYSE', { mode: 'readonly' }, 'render')}
${REPORT}
YOUR ROLE: CLIP-ANALYSE – INDEPENDENT CODE AND GEOMETRY ANALYSIS (no rendering needed; read the code of both builds with
git show ${ZS1}:<path> and git show ${BASE}:<path> in ${REPO}, read assets/models/manifest.json and the sprite manifest of
both, run python for the numbers; you may run headless Godot scripts from a scratch checkout if you need numbers only the
engine gives – nice -n 19).
${LEADS}
WHAT TO DO: for every mechanism by which two vehicle models (or a model and the road, guardrail, camera) can visibly
intersect in Modern, give the code path (file:line) and the worst-case penetration depth computed from the real numbers:
the collision sizes of every player car and traffic type (vehicle.width_m/length_m, traffic widths/lengths), the model
sizes (manifest extents, all levels), the hitbox scale, the yaw limits and smoothing, body roll, wheel steer and wheel
arch clearance, the rear rule (when exactly a car beside-behind does not collide, how far the player can steer into it),
the invulnerable phase, the camera (near plane, position, curve camera). Rank them by how well they fit "slight, twice,
linked to my steering, a white PKW". Then list fix options with what each solves, its risks, its fairness (F1/F6:
never later or smaller than Arcade) and its cost.
${RULES}
Write bericht.md into ${SP}/deliver/CLIP-ANALYSE/.`,
    { label: 'untersuchung:CLIP-ANALYSE', phase: 'Untersuchung', schema: ANA_SCHEMA }),
])
if (!nach && !ana) { log('Untersuchung ausgefallen'); return { nach, ana } }
log(`CLIP-NACHSTELLEN: ${nach ? nach.reproduced + ', ' + nach.mechanisms.length + ' Mechanismen' : 'fehlt'}; CLIP-ANALYSE: ${ana ? ana.mechanisms.filter(m => m.likelihood === 'high').length + ' hoch wahrscheinlich' : 'fehlt'}`)

// ---------------------------------------------------------------- diagnosis + adversarial counter-check
phase('Diagnose')
const diag = await agent(`${common('CLIP-DIAGNOSE', { mode: 'readonly' }, 'render')}
${REPORT}
YOUR ROLE: CLIP-DIAGNOSE – decide the root cause(s) and the fix design from two independent investigations.
REPRODUCTION (report ${D('CLIP-NACHSTELLEN')}): ${nach ? JSON.stringify(nach) : 'NOT AVAILABLE'}
ANALYSIS (report ${D('CLIP-ANALYSE')}): ${ana ? JSON.stringify(ana) : 'NOT AVAILABLE'}
Read both reports and look at their pictures. Where they disagree, check the code yourself (git show ${BASE}:<path>).
${RULES}
${FILES_NOW}
Design the fix for the M2 head ${BASE}: the exact visual rule(s) with constants, the behaviour over time (no popping,
no jitter: smoothing), which vehicles it touches (player, traffic, trucks, police, the showroom is not concerned),
what happens at the Steam Deck preset, where the code goes and the exact hook, the tests and measurable acceptance
criteria (penetration depth after the fix in the reproduced cases and in an instrumented stage run, F1 unchanged –
tests/sim/modern_sight.gd --full, Arcade 20 von 20 identisch). Write bericht.md into ${SP}/deliver/CLIP-DIAGNOSE/.`,
  { label: 'diagnose:CLIP-DIAGNOSE', phase: 'Diagnose', schema: DIAG_SCHEMA })
if (!diag) { log('CLIP-DIAGNOSE ausgefallen'); return { nach, ana } }

const counter = await parallel([
  ['CLIP-GEGEN-URSACHE', 'the ROOT CAUSE: does the evidence really show that this is what the user saw, and did the investigations miss a mechanism (look at the code and pictures yourself; a cheap measurement of your own is welcome)?'],
  ['CLIP-GEGEN-ENTWURF', 'the FIX DESIGN: can it break fairness (a car visible later or smaller than in Arcade, lights smaller), Arcade identity, the simulation, the look (jitter, popping, cars visibly pushed or turned in odd ways, a ghosted car that should be seen), performance (per-frame cost with 40 cars), the merge with R4 (vehicles.gd), or miss a case (trucks, police, crashes, tunnels, the Steam Deck preset)?'],
].map(([id, what]) => () => agent(`${common(id, { mode: 'readonly' }, 'render')}
${REPORT}
YOUR ROLE: ${id} – ADVERSARIAL COUNTER-CHECK. Try to REFUTE ${what}
THE DIAGNOSIS (report ${D('CLIP-DIAGNOSE')}): ${JSON.stringify(diag)}
The investigations behind it: ${D('CLIP-NACHSTELLEN')} and ${D('CLIP-ANALYSE')} (pictures in their folders).
${RULES}
Be concrete: every problem with evidence (file:line, numbers, picture) and a correction. If you find nothing that
matters, say refuted=false and list what you checked. Notes into ${SP}/deliver/${id}/bericht.md.`,
  { label: `diagnose:${id}`, phase: 'Diagnose', schema: VERDICT })))
const objections = counter.filter(Boolean)
const serious = objections.flatMap(v => v.problems.filter(p => ['blocker', 'high', 'medium'].includes(p.severity)))
log(`Gegenprobe: ${objections.filter(v => v.refuted).length} von ${objections.length} widerlegen; ${serious.length} Einwände blocker/hoch/mittel`)

// ---------------------------------------------------------------- fix
phase('Umsetzung')
const fix = await agent(`${common('FIX-CLIP', { mode: 'fresh', base: BASE }, 'render')}
${REPORT}
YOUR ROLE: FIX-CLIP – FIX IT on the M2 head ${BASE} (origin/wip/v080-m2int). Push every commit to origin wip/v080-fix-clip.
THE DIAGNOSIS: ${JSON.stringify(diag)}
THE COUNTER-CHECKS (take every confirmed objection into the design; reject one only with evidence): ${JSON.stringify(objections)}
Evidence and scripts of the investigation: ${SP}/m1/CLIP-NACHSTELLEN/ (reuse the instrumentation – the before/after
numbers must come from the same measurement), reports ${D('CLIP-NACHSTELLEN')}, ${D('CLIP-ANALYSE')}, ${D('CLIP-DIAGNOSE')}.
${RULES}
${FILES_NOW}
${MACHINE}
GATES on your final head (commands and output in bericht.md): import clean; tests/check_scripts.gd; your unit tests;
tools/run_tests.sh green (full run at most twice); tools/golden.sh check (20 von 20 and 17 von 17 identisch);
tools/golden.sh modern-check (modern-make only where a Modern golden changed on purpose – LOOK first, say so in the
commit); tools/run_render_checks.sh with the vehicle checks (check_vehicle_lights, check_vehicle_standin, check_start_km0,
check_occlusion) and all if time allows; tests/sim/modern_sight.gd -- --full; the instrumented stage run of the
reproduction before and after (penetration count and depth per 10 km); before/after pictures and a clip of each
reproduced case (Modern | Arcade, --gfx-preset=high and the Steam Deck preset); perf: the per-frame cost of the rule with a
full traffic load. Deliver to ${SP}/deliver/FIX-CLIP/ with bericht.md (German). Return the result format with package
"FIX-CLIP".`,
  { label: 'umsetzung:FIX-CLIP', phase: 'Umsetzung', schema: BUILD_R, isolation: 'worktree' })
if (!fix || !fix.commit) { log('FIX-CLIP fehlt'); return { nach, ana, diag, objections } }
log(`FIX-CLIP: ${fix.commit.slice(0, 7)} (${(fix.acceptance || []).filter(a => a.result !== 'pass').length} offen)`)

// ---------------------------------------------------------------- independent review
phase('Prüfung')
const qa = await agent(`${common('QA-CLIP', { mode: 'review', base: fix.commit }, 'render')}
${REPORT}
YOUR ROLE: QA-CLIP – INDEPENDENT REVIEW of the fix FIX-CLIP (head ${fix.commit}, branch origin/wip/v080-fix-clip, based on
${BASE}). Its report ${D('FIX-CLIP')}: ${JSON.stringify({ summary: fix.summary, files: fix.files_changed, open: (fix.acceptance || []).filter(a => a.result !== 'pass'), deviations: fix.deviations, notes: fix.notes_for_next, look: fix.look_verdict })}
The diagnosis it implements: ${D('CLIP-DIAGNOSE')}; the reproduction: ${D('CLIP-NACHSTELLEN')} (scripts in
${SP}/m1/CLIP-NACHSTELLEN/).
${RULES}
${MACHINE}
Do not trust the report. Check: (1) the reproduced cases before (${BASE}) and after (${fix.commit}) with your own runs and
pictures – is the clipping gone, and does nothing look odd instead (cars visibly shoved, turned or ghosted where the
player should see them, jitter, popping)? (2) an instrumented drive on Kassel – Erfurt and one more stage with dense
traffic: penetration count and depth per 10 km; (3) fairness: tests/sim/modern_sight.gd -- --full, and that no car or
light appears later or smaller than in Arcade; (4) Arcade: tools/golden.sh check identical, git diff ${BASE}..${fix.commit}
--stat touches no frozen or simulation file; (5) the size of the hook in vehicles.gd (mergeable with R4); (6) per-frame
cost. Findings with evidence and a fix each; pictures and bericht.md into ${SP}/deliver/QA-CLIP/.`,
  { label: 'prüfung:QA-CLIP', phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })
const qaN = qa ? qa.findings.filter(f => ['blocker', 'high', 'medium'].includes(f.severity)) : []
log(`QA-CLIP: ${qa ? qaN.length + ' Befunde blocker/hoch/mittel, ' + qa.findings.length + ' insgesamt' : 'ausgefallen'}`)
if (!qa || qaN.length === 0) return { nach, ana, diag, objections, fix, qa }

// ---------------------------------------------------------------- fix round + re-check
phase('Nacharbeit')
const fix2 = await agent(`${common('FIX-CLIP2', { mode: 'fresh', base: fix.commit }, 'render')}
${REPORT}
YOUR ROLE: FIX-CLIP2 – FIX ROUND after the independent review of FIX-CLIP (head ${fix.commit}). Push every commit to origin
wip/v080-fix-clip2.
THE REVIEW FOUND: ${JSON.stringify(qa)}
Check each blocker/high/medium finding yourself first (reject it with evidence if it is wrong), fix the confirmed ones and
the cheap low ones. Reports: ${D('FIX-CLIP')}, ${D('QA-CLIP')}, ${D('CLIP-DIAGNOSE')}.
${RULES}
${FILES_NOW}
${MACHINE}
GATES as FIX-CLIP had them (its bericht.md lists them) on your final head; before/after numbers per finding. Deliver to
${SP}/deliver/FIX-CLIP2/ with bericht.md. Return the result format with package "FIX-CLIP2".`,
  { label: 'nacharbeit:FIX-CLIP2', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
if (!fix2 || !fix2.commit) { log('FIX-CLIP2 fehlt'); return { nach, ana, diag, objections, fix, qa, fix2 } }
log(`FIX-CLIP2: ${fix2.commit.slice(0, 7)}`)
const nachp = await agent(`${common('NACH-CLIP', { mode: 'review', base: fix2.commit }, 'render')}
${REPORT}
YOUR ROLE: NACH-CLIP – FOCUSED RE-CHECK of the fix round FIX-CLIP2 (head ${fix2.commit}, origin/wip/v080-fix-clip2) against
the findings of QA-CLIP: ${JSON.stringify(qaN)}
Per finding: fixed / partly / not fixed, with your own evidence (commands, pictures). Then the gates that matter:
tools/golden.sh check identical, tests/sim/modern_sight.gd -- --full, the vehicle render checks, the reproduced cases and an
instrumented stage run. New findings only if they are real and caused by the fix round. Report and pictures into
${SP}/deliver/NACH-CLIP/.
${MACHINE}`,
  { label: 'nachprüfung:NACH-CLIP', phase: 'Nacharbeit', schema: RECHECK, isolation: 'worktree' })
return { nach, ana, diag, objections, fix, qa, fix2, nachp }
