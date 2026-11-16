
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

