
// The user's report on the first test build: a white car clips slightly, twice, linked to the user's steering.
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
