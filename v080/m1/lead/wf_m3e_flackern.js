export const meta = {
  name: 'v080-lackflackern',
  description: 'v0.8.0: the user saw a white traffic car about 40 m ahead briefly lose its paint, twice, on Kassel – Erfurt in the first test build (a graphics flicker, linked to their steering) – reproduce and analyse independently, diagnose with an adversarial counter-check, fix in the Modern renderer or the models (Arcade untouched), independent review, fix round and re-check',
  phases: [
    { title: 'Untersuchung', detail: 'FLACKER-NACHSTELLEN (reproduce and measure in the test build and on the M2 head) and FLACKER-ANALYSE (code, shader, models) side by side' },
    { title: 'Diagnose', detail: 'FLACKER-DIAGNOSE: root causes ranked with evidence, fix design; two counter-checks try to refute it' },
    { title: 'Umsetzung', detail: 'FIX-FLACKERN on the M2 head: root-cause fix, tests, gates, before/after pictures' },
    { title: 'Prüfung', detail: 'QA-FLACKERN: independent review against the reproduction, fairness and Arcade identity' },
    { title: 'Nacharbeit', detail: 'FIX-FLACKERN2 on blocker/high/medium findings, NACH-FLACKERN re-check' },
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

// The user's report on the first test build: a white car ~40 m ahead briefly loses its paint (flicker), twice.
// ARGS: { zs1: '<test build commit>', base: '<M2 head to fix on>' }
const A = args || {}
const ZS1 = A.zs1
const BASE = A.base
const D = (p) => `${SP}/deliver/${p}/bericht.md`

const REPORT = `THE USER'S REPORT (German, verbatim, 2026-11-12), two messages: (1) "ZS1 Kassel-Erfurt auf meinem Main-PC gespielt.
Keine größeren Bugs, aber leichtes Clipping bei einem weissen PKW. trat 2 mal auf und hing offenbar mit meiner
Lenkbewegung zusammen, sah nur etwas merkwürdig aus und ist kein Game Breaker." (2) asked what was clipping: "ich meinte
mit Clipping das Grafikflackern. Der Wagen war schätzungsweise "reale" 40 Meter vor mir und "verlor" kurz seine
Lackierung :)" – i.e. a GRAPHICS FLICKER, not cars passing through each other: in the first test build ZS1 (commit
${ZS1}, archives in ${SP}/deliver/ZS1/), on the stage Kassel – Erfurt (network stage "erfurt_kassel"; find out in which race
and direction the user can drive it), on the user's Windows main PC with a real graphics card, most probably in the mode
"Modern" with the preset the first start chose for that PC, a white passenger car (traffic) about 40 m ahead of the user
briefly LOST ITS PAINT – twice in the stage, apparently connected with the user's steering. Not game-breaking, but it
looked strange.`

const LEADS = `LEADS THE LEAD FOUND IN THE CODE OF ${ZS1} (unverified – confirm or refute each with evidence, and look for others):
- 40 m is exactly the level-of-detail switch of the vehicle models at Details "Mittel": scripts/race3d/layers/vehicles.gd
  LOD_REF_0 40 m / LOD_REF_1 120 m, scaled by the preset (config graphics.levels.details[]: vehicle_lod0_m 25 / 40 / 60 m
  for Niedrig / Mittel / Hoch – the Steam Deck preset and others use one of them), VehiclePose3D.lod_index() with
  LOD_HYSTERESIS 0.05 (a band of ±5 %, i.e. 38–42 m at "Mittel"). The switch lod0 <-> lod1 is NOT cross-faded
  (XFADE_LODS = ["lod1", "lod2"], XFADE_S 0.5) – it pops. Following a car at about 40 m, small speed changes (steering,
  understeer, a lift of the throttle) can move the distance back and forth across that band – several switches.
- If lod0 and lod1 of a white traffic model do not look the same (paint codes of the atlas, the materials of the level,
  the race LOOK constants applied to the vpbr materials – an art review found earlier that materials created AFTER the look
  was set silently miss it –, merged parts, normals, the paint mask of lod1), every switch shows a different car for a
  moment. Paint is an INSTANCE uniform of vpbr.gdshader (paint / paint2 / paint3, default (0.5, 0.5, 0.52) grey!),
  applied once when a level is built (ModelFactory.apply_paint); the other per-car instance uniforms (fade, sun, lamp_a,
  lamp_b) are pushed by vehicles.gd _set_uniforms() only when they CHANGE against a per-car cache that _set_level() does
  not reset – a level built or shown later can keep stale or default values. Check every path where a level's geometry
  can be drawn without its paint: pooled cars re-used for another set or colour, levels built on demand, the cross-fade
  of lod1/lod2, the box/sprite stand-ins, a model loaded after the car appeared (ModelDB.request).
- Other candidates to rule in or out: mip level / texture compression of the paint codes in the atlas at 40 m and
  certain viewing angles (a real GPU with anisotropic filtering picks other mips than llvmpipe – if it cannot reproduce
  here, analyse the decode in the shader against coarser mips and BC compression), the shadow cascade boundaries of the
  presets (shadow_splits, shadow_distance_m) – the camera turns into bends with the steering and moves the cascades –,
  the clear coat's sun glint and environment reflection (sky_update_s), the light pools, culling of one part.
- Everything here renders with llvmpipe (software); the user's GPU and driver differ. Say clearly what you measured here
  and what you infer for a real GPU.`

const RULES = `HARD RULES FOR ANY FIX: Arcade and the simulation stay exactly as they are (frozen Arcade files, scripts/gameplay/**,
scripts/race/** except the Modern seam, config values Arcade reads). The fix lives in the Modern renderer and/or the
vehicle models. Fairness (contract F1/F6, tests/sim/modern_sight.gd): a car must never be visible later or smaller than
in Arcade; its lights keep their minimum size. A level switch of a car must be invisible at every preset (no change of
paint, brightness or colour a player can notice – measure the changed-pixel share and the colour difference of the car
across the switch); the fix must hold for every vehicle model (traffic, trucks, police, player cars) and every level,
not only the white car. Prefer the root cause over a cover-up (a cross-fade only hides a wrong level).`

const FILES_NOW = `OWNERSHIP RIGHT NOW: wave 3 runs beside you – R4 owns the renderer core including scripts/race3d/layers/vehicles.gd,
model_factory.gd, modern_materials.gd, vehicle_pose3d.gd, the shaders and config "graphics"/render keys; R5 tunnels and
bridges, R6 structures; AS5a the city models (it regenerates assets/models/manifest.json); QA-M2/FIX-M2 the assembly.
Keep the fix as small and self-contained as the root cause allows, every change in those files marked with a comment
"FIX-FLACKERN", and list every changed line range in your report – the lead merges it with R4's changes afterwards. If
the root cause is in the vehicle models (assets/models/vehicles/** and their builder), fix it there, re-export only the
affected models with --jobs 1 and say exactly which files changed (the manifest is regenerated after the merge).`

const MACHINE = `MACHINE: up to eight agents share 4 cores and 15 GB (wave 3, AS5a, QA-M2). Run every heavy job (Godot renders, test
suites) with nice -n 19, one at a time; before a Godot run check free -g – below 3 GB "available", wait (sleep 60) and
check again. A run that only times out under this load is not a finding by itself: repeat it before you report it.`

const NACH_SCHEMA = {
  type: 'object',
  properties: {
    reproduced: { type: 'string', enum: ['yes', 'partly', 'no'], description: 'did you see the car ~40 m ahead lose its paint for a moment?' },
    mechanisms: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, what: { type: 'string' }, build: { type: 'string', description: 'ZS1 test build, M2 head or both' },
      situation: { type: 'string', description: 'stage, km, cars, steering, speed' },
      magnitude: { type: 'string', description: 'measured size of the effect: share of the car\'s pixels that change, colour difference (dE), duration in frames' },
      frequency: { type: 'string', description: 'how often it occurs in a normal drive (measured on a stage run)' },
      visible: { type: 'string', description: 'how it looks from the chase camera, picture paths' },
      likely_user_case: { type: 'boolean' } },
      required: ['id', 'what', 'build', 'situation', 'magnitude', 'frequency', 'visible', 'likely_user_case'] } },
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
      effect: { type: 'string', description: 'what the player would see, how large (colour, share of the car), how long, with the numbers used' },
      likelihood: { type: 'string', enum: ['high', 'medium', 'low', 'refuted'] }, why: { type: 'string' } },
      required: ['id', 'what', 'code', 'effect', 'likelihood', 'why'] } },
    sizes: { type: 'array', items: { type: 'string' }, description: 'per vehicle model and level: material classes, paint codes / paint uniforms, look constants applied, switch distance per preset (both builds)' },
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
  () => agent(`${common('FLACKER-NACHSTELLEN', { mode: 'review', base: ZS1 }, 'render')}
${REPORT}
YOUR ROLE: FLACKER-NACHSTELLEN – REPRODUCE AND MEASURE what the user saw. Your fresh worktree starts at the test build ${ZS1}
(the user's build). Later in your work check the M2 head ${BASE} too (git checkout --detach ${BASE} in the same worktree,
re-import; it has all vehicle models of AS2R) – the fix will be made there.
${LEADS}
${MACHINE}
WHAT TO DO: (1) Find the stage and race the user drove (Kassel – Erfurt) and drive it in Modern with traffic at the
presets Mittel, Hoch and Steam Deck (autopilot or your own scripted input that also follows a car at 35–65 m and steers
a little, as a player does). Instrument the run: every frame, for every traffic car log its set, colour, distance, the
level shown (lod0/lod1/lod2/box/sprite), level switches, cross-fades, and the instance uniforms its visible geometry
really carries (paint, paint2, paint3, fade, sun, lamp_a, lamp_b – read them back from the GeometryInstance3D) against
what they should be. Count per 10 km: level switches near the player, switches back and forth within a second, frames in
which a car shows wrong uniforms. (2) LOOK: render the switch of a white traffic car (and of each other colour and model
in ZS1) at its switch distance from the chase camera – the frame before, at and after the switch – Modern and Arcade
from the same simulation state (tools/ab_shot.sh or your own scene script), --gfx-preset=medium, high and deck, by day
(noon, low sun) and at dusk; measure the colour difference (dE) and the share of the car's pixels that change at the
switch; make a short clip (fixed 60 fps) of the most visible case. Does the car "lose its paint" for a moment? Which
level looks wrong, and why? (3) Repeat the essentials on the M2 head ${BASE}. Scripts into ${SP}/m1/FLACKER-NACHSTELLEN/,
pictures and bericht.md into ${SP}/deliver/FLACKER-NACHSTELLEN/.`,
    { label: 'untersuchung:FLACKER-NACHSTELLEN', phase: 'Untersuchung', schema: NACH_SCHEMA, isolation: 'worktree' }),
  () => agent(`${common('FLACKER-ANALYSE', { mode: 'readonly' }, 'render')}
${REPORT}
YOUR ROLE: FLACKER-ANALYSE – INDEPENDENT CODE, SHADER AND ASSET ANALYSIS (read the code of both builds with git show
${ZS1}:<path> and git show ${BASE}:<path> in ${REPO}; read assets/models/manifest.json, the model files and atlases of the
vehicle models of both builds; run python for numbers; you may run headless Godot scripts from a scratch checkout –
nice -n 19 – if you need numbers only the engine gives, e.g. the materials and instance uniforms of a built level).
${LEADS}
WHAT TO DO: for every mechanism by which a vehicle in Modern can change its paint or look for a moment, give the code path
(file:line), the conditions (preset, distance, steering, time of day, tunnel, pooled car, level built on demand, model
loaded late), and the expected effect. Compare lod0, lod1 and lod2 of every traffic model of ZS1 and of the M2 head –
material classes, paint codes in the atlas and their decode in vpbr.gdshader at the mip levels a 40-m car uses (a
1280×800 and a 1920×1080 frame), the race LOOK constants per material, normals and the coat – and say which levels would
look different when they swap. Rank the mechanisms by how well they fit "a white car about 40 m ahead briefly lost its
paint, twice, linked to my steering". Then list fix options with what each solves, its risks, fairness (F1/F6) and cost.
${RULES}
Write bericht.md into ${SP}/deliver/FLACKER-ANALYSE/.`,
    { label: 'untersuchung:FLACKER-ANALYSE', phase: 'Untersuchung', schema: ANA_SCHEMA }),
])
if (!nach && !ana) { log('Untersuchung ausgefallen'); return { nach, ana } }
log(`FLACKER-NACHSTELLEN: ${nach ? nach.reproduced + ', ' + nach.mechanisms.length + ' Mechanismen' : 'fehlt'}; FLACKER-ANALYSE: ${ana ? ana.mechanisms.filter(m => m.likelihood === 'high').length + ' hoch wahrscheinlich' : 'fehlt'}`)

// ---------------------------------------------------------------- diagnosis + adversarial counter-check
phase('Diagnose')
const diag = await agent(`${common('FLACKER-DIAGNOSE', { mode: 'readonly' }, 'render')}
${REPORT}
YOUR ROLE: FLACKER-DIAGNOSE – decide the root cause(s) and the fix design from two independent investigations.
REPRODUCTION (report ${D('FLACKER-NACHSTELLEN')}): ${nach ? JSON.stringify(nach) : 'NOT AVAILABLE'}
ANALYSIS (report ${D('FLACKER-ANALYSE')}): ${ana ? JSON.stringify(ana) : 'NOT AVAILABLE'}
Read both reports and look at their pictures. Where they disagree, check the code yourself (git show ${BASE}:<path>).
${RULES}
${FILES_NOW}
Design the fix for the M2 head ${BASE}: what exactly changes (code, shader, models), why it removes the cause and not only
the symptom, how a level switch then looks at every preset, what it costs per frame, where the code goes, the tests
(unit tests that fail today: e.g. every level of every vehicle model carries its paint and the per-car uniforms right
after a switch, a pooled car re-used for another set, a level built on demand) and measurable acceptance criteria
(colour difference and changed-pixel share across a switch, uniform mismatches per 10 km = 0 in an instrumented stage
run, F1 unchanged – tests/sim/modern_sight.gd --full, Arcade 20 von 20 identisch). Write bericht.md into
${SP}/deliver/FLACKER-DIAGNOSE/.`,
  { label: 'diagnose:FLACKER-DIAGNOSE', phase: 'Diagnose', schema: DIAG_SCHEMA })
if (!diag) { log('FLACKER-DIAGNOSE ausgefallen'); return { nach, ana } }

const counter = await parallel([
  ['FLACKER-GEGEN-URSACHE', 'the ROOT CAUSE: does the evidence really show that this is what the user saw (a white car about 40 m ahead losing its paint for a moment, twice, linked to steering), and did the investigations miss a mechanism – look at the code, the shader, the models and the pictures yourself; a cheap measurement of your own is welcome?'],
  ['FLACKER-GEGEN-ENTWURF', 'the FIX DESIGN: does it remove the cause for every vehicle model, level and preset, or only hide it; can it break fairness (a car or its lights visible later, smaller or dimmer than in Arcade), Arcade identity, the look of the cars (paint, coat, lamps by day and at night, tunnels), performance (per-frame cost with 40 cars), the merge with R4 (vehicles.gd and friends are R4\'s in wave 3), the vehicle models of the M2 head (AS2R), or miss a case (trucks, police, player cars, box and sprite stand-ins, pooled cars, a model loaded late)?'],
].map(([id, what]) => () => agent(`${common(id, { mode: 'readonly' }, 'render')}
${REPORT}
YOUR ROLE: ${id} – ADVERSARIAL COUNTER-CHECK. Try to REFUTE ${what}
THE DIAGNOSIS (report ${D('FLACKER-DIAGNOSE')}): ${JSON.stringify(diag)}
The investigations behind it: ${D('FLACKER-NACHSTELLEN')} and ${D('FLACKER-ANALYSE')} (pictures in their folders).
${RULES}
Be concrete: every problem with evidence (file:line, numbers, picture) and a correction. If you find nothing that
matters, say refuted=false and list what you checked. Notes into ${SP}/deliver/${id}/bericht.md.`,
  { label: `diagnose:${id}`, phase: 'Diagnose', schema: VERDICT })))
const objections = counter.filter(Boolean)
const serious = objections.flatMap(v => v.problems.filter(p => ['blocker', 'high', 'medium'].includes(p.severity)))
log(`Gegenprobe: ${objections.filter(v => v.refuted).length} von ${objections.length} widerlegen; ${serious.length} Einwände blocker/hoch/mittel`)

// ---------------------------------------------------------------- fix
phase('Umsetzung')
const fix = await agent(`${common('FIX-FLACKERN', { mode: 'fresh', base: BASE }, 'render')}
${REPORT}
YOUR ROLE: FIX-FLACKERN – FIX IT on the M2 head ${BASE} (origin/wip/v080-m2int). Push every commit to origin
wip/v080-fix-flackern.
THE DIAGNOSIS: ${JSON.stringify(diag)}
THE COUNTER-CHECKS (take every confirmed objection into the design; reject one only with evidence): ${JSON.stringify(objections)}
Evidence and scripts of the investigation: ${SP}/m1/FLACKER-NACHSTELLEN/ (reuse the instrumentation – the before/after
numbers must come from the same measurement), reports ${D('FLACKER-NACHSTELLEN')}, ${D('FLACKER-ANALYSE')},
${D('FLACKER-DIAGNOSE')}.
${RULES}
${FILES_NOW}
${MACHINE}
GATES on your final head (commands and output in bericht.md): import clean; tests/check_scripts.gd; your unit tests (they
fail on ${BASE} and pass after the fix – show both); tools/run_tests.sh green (full run at most twice); tools/golden.sh
check (20 von 20 and 17 von 17 identisch); tools/golden.sh modern-check (modern-make only where a Modern golden changed on
purpose – LOOK first, say so in the commit); tools/run_render_checks.sh with the vehicle checks (check_vehicle_lights,
check_vehicle_standin, check_start_km0, check_occlusion) and all if time allows; tests/sim/modern_sight.gd -- --full;
the instrumented stage run of the reproduction before and after (wrong-uniform frames and visible switches per 10 km);
before/after pictures and a clip of the switch of a white car and of the other reproduced cases (Modern | Arcade,
--gfx-preset=medium, high and deck); perf: the per-frame cost of the change with a full traffic load. Deliver to
${SP}/deliver/FIX-FLACKERN/ with bericht.md (German). Return the result format with package "FIX-FLACKERN".`,
  { label: 'umsetzung:FIX-FLACKERN', phase: 'Umsetzung', schema: BUILD_R, isolation: 'worktree' })
if (!fix || !fix.commit) { log('FIX-FLACKERN fehlt'); return { nach, ana, diag, objections } }
log(`FIX-FLACKERN: ${fix.commit.slice(0, 7)} (${(fix.acceptance || []).filter(a => a.result !== 'pass').length} offen)`)

// ---------------------------------------------------------------- independent review
phase('Prüfung')
const qa = await agent(`${common('QA-FLACKERN', { mode: 'review', base: fix.commit }, 'render')}
${REPORT}
YOUR ROLE: QA-FLACKERN – INDEPENDENT REVIEW of the fix FIX-FLACKERN (head ${fix.commit}, branch origin/wip/v080-fix-flackern,
based on ${BASE}). Its report ${D('FIX-FLACKERN')}: ${JSON.stringify({ summary: fix.summary, files: fix.files_changed, open: (fix.acceptance || []).filter(a => a.result !== 'pass'), deviations: fix.deviations, notes: fix.notes_for_next, look: fix.look_verdict })}
The diagnosis it implements: ${D('FLACKER-DIAGNOSE')}; the reproduction: ${D('FLACKER-NACHSTELLEN')} (scripts in
${SP}/m1/FLACKER-NACHSTELLEN/).
${RULES}
${MACHINE}
Do not trust the report. Check: (1) the reproduced cases before (${BASE}) and after (${fix.commit}) with your own runs and
pictures – does a car still change its paint or look at a level switch, at any preset, by day, at dusk, at night and in a
tunnel? Does anything look worse instead (paint, coat, lamps, a visible cross-fade, a car popping)? (2) an instrumented
drive on Kassel – Erfurt and one more stage with dense traffic: wrong-uniform frames and visible switches per 10 km;
(3) fairness: tests/sim/modern_sight.gd -- --full, cars and their lights never later, smaller or dimmer than in Arcade;
(4) Arcade: tools/golden.sh check identical, git diff ${BASE}..${fix.commit} --stat touches no frozen or simulation file;
(5) the size and marking of the changes in R4's files (mergeable); (6) per-frame cost. Findings with evidence and a fix
each; pictures and bericht.md into ${SP}/deliver/QA-FLACKERN/.`,
  { label: 'prüfung:QA-FLACKERN', phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })
const qaN = qa ? qa.findings.filter(f => ['blocker', 'high', 'medium'].includes(f.severity)) : []
log(`QA-FLACKERN: ${qa ? qaN.length + ' Befunde blocker/hoch/mittel, ' + qa.findings.length + ' insgesamt' : 'ausgefallen'}`)
if (!qa || qaN.length === 0) return { nach, ana, diag, objections, fix, qa }

// ---------------------------------------------------------------- fix round + re-check
phase('Nacharbeit')
const fix2 = await agent(`${common('FIX-FLACKERN2', { mode: 'fresh', base: fix.commit }, 'render')}
${REPORT}
YOUR ROLE: FIX-FLACKERN2 – FIX ROUND after the independent review of FIX-FLACKERN (head ${fix.commit}). Push every commit to
origin wip/v080-fix-flackern2.
THE REVIEW FOUND: ${JSON.stringify(qa)}
Check each blocker/high/medium finding yourself first (reject it with evidence if it is wrong), fix the confirmed ones and
the cheap low ones. Reports: ${D('FIX-FLACKERN')}, ${D('QA-FLACKERN')}, ${D('FLACKER-DIAGNOSE')}.
${RULES}
${FILES_NOW}
${MACHINE}
GATES as FIX-FLACKERN had them (its bericht.md lists them) on your final head; before/after numbers per finding. Deliver to
${SP}/deliver/FIX-FLACKERN2/ with bericht.md. Return the result format with package "FIX-FLACKERN2".`,
  { label: 'nacharbeit:FIX-FLACKERN2', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
if (!fix2 || !fix2.commit) { log('FIX-FLACKERN2 fehlt'); return { nach, ana, diag, objections, fix, qa, fix2 } }
log(`FIX-FLACKERN2: ${fix2.commit.slice(0, 7)}`)
const nachp = await agent(`${common('NACH-FLACKERN', { mode: 'review', base: fix2.commit }, 'render')}
${REPORT}
YOUR ROLE: NACH-FLACKERN – FOCUSED RE-CHECK of the fix round FIX-FLACKERN2 (head ${fix2.commit},
origin/wip/v080-fix-flackern2) against the findings of QA-FLACKERN: ${JSON.stringify(qaN)}
Per finding: fixed / partly / not fixed, with your own evidence (commands, pictures). Then the gates that matter:
tools/golden.sh check identical, tests/sim/modern_sight.gd -- --full, the vehicle render checks, the reproduced switch of a
white car at medium, high and deck, and an instrumented stage run. New findings only if they are real and caused by the fix
round. Report and pictures into ${SP}/deliver/NACH-FLACKERN/.
${MACHINE}`,
  { label: 'nachprüfung:NACH-FLACKERN', phase: 'Nacharbeit', schema: RECHECK, isolation: 'worktree' })
return { nach, ana, diag, objections, fix, qa, fix2, nachp }
