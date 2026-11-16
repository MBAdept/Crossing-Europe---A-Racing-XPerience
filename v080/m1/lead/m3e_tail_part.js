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
