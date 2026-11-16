
// M2, second assembly: RINT-M2 merges FIX-R4, FIX-R5, FIX-R6 and AS5aR1 onto FIX-M2 → QA with two lenses → FIX-RINT →
// NACH-RINT. ARGS: { base: '<FIX-M2 head>', r4: '<FIX-R4 head>', r5: '<FIX-R5 head>', r6: '<FIX-R6 head>',
//   as5a: '<AS5aR1 head>', r5open: '<what FIX-R5/NACH-R5 left open>', r4open: '<what NACH-R4 left open>', notes: '' }
const A = args || {}
const BASE = A.base
const D = (p) => `${SP}/deliver/${p}/bericht.md`

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
    checked_ok: { type: 'array', items: { type: 'string' }, description: 'what was checked and found fine (one line each)' },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'findings', 'checked_ok', 'media'],
}
const RECHECK = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'is the fixed head a sound base for R7 and the whole-race QA? 3-6 sentences' },
    per_finding: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, status: { type: 'string', enum: ['fixed', 'partly', 'not_fixed', 'not_checked'] },
      evidence: { type: 'string' } }, required: ['id', 'status', 'evidence'] } },
    findings: FINDINGS.properties.findings,
    gates: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'per_finding', 'findings', 'gates'],
}

const MERGES = [
  `R4  = origin/wip/v080-fix-r4 (${A.r4})  light, night and weather: rain and snow in the air at every Effekte level,
        spray, the wet road with reflections (road-profile streaks), snow banks, sun disc, tunnel-exit over-exposure,
        police-light glow, the night law of models (R4 ${D('R4')}, review ${D('QA-R4')}, fixes ${D('FIX-R4')},
        re-check ${D('NACH-R4')})`,
  `R5  = origin/wip/v080-fix-r5 (${A.r5})  tunnels, bridges, water and banks: tube panels, walkways, niches, portals,
        pylons, cables, truss portals, bridge lamps, real banks (R5 ${D('R5')}, review ${D('QA-R5')}, fixes
        ${D('FIX-R5')}, re-check ${D('NACH-R5')})`,
  `R6  = origin/wip/v080-fix-r6 (${A.r6})  fuel station, border, city street furniture, start/finish, radar: real
        canopies with line-of-sight column decisions, cable-stayed border roofs where a pillar would block a sight
        line, start/finish gantries with truss and floodlights (R6 ${D('R6')}, review ${D('QA-R6')}, fixes
        ${D('FIX-R6')}, re-check ${D('NACH-R6')})`,
  `AS5a = origin/wip/v080-as5ar1 (${A.as5a})  city buildings part 1, the styles of the race Kiel – Nürnberg: hanse,
        german, german_old – 11 sets with side-wall openings, oriels, railings kept in the mips (AS5a1 ${D('AS5a1')},
        review ${D('KRITIK-5a1')}, rework ${D('AS5aR1')})`,
].join('\n  ')

const LEAD = `LEAD NOTES FOR RINT-M2 (decisions of the lead; measured facts from the reports and a trial merge):
1. Trial merge by the lead (git merge-tree, chained in the order above onto ${BASE}): the code merges cleanly; conflicts
   only in tests/golden/modern_slice.{md5,env} (every package) and docs/renderer-modern.md (R5). Docs: the union, one
   consistent text (R6 wrote docs/renderer-modern-bauten.md – add one pointer sentence in renderer-modern.md §14.4/§14.5).
   Goldens: take either side while merging and regenerate ONCE at the end with tools/golden.sh modern-make after you
   have LOOKED at all six pictures (A-18); say so in the commit and the report.
2. Contract: right after the four merges, append the lead's text ${SP}/m1/lead/contract_11_3.md VERBATIM to
   docs/dev/v080_contract.md as §11.3 (after the end of §11.2; one commit "Vertrag §11.3 (Leitung): Sichtkorridor,
   Bauten, Instanz-Uniforms, Nachtlicht, Plan, Stadtgebäude"). Read it – A-17 … A-22 bind this assembly. A-17 (the
   corridor) is R7's work, not yours: do not change the corridor here.
3. Low beam specular (NACH-M2 N-03, A-20): FIX-M2 set lights.gd SPOT_SPECULAR = 0.0 against blown-out vehicles; after
   R4 that also kills the low beam's sheen on the wet road. Give the road its specular back and keep vehicles from
   blowing out through their material (e.g. damp the specular response of vpbr/glass to spot lights, or a per-material
   factor) – not by switching the light's specular off for everything. Both must hold on the final head, measured:
   FIX-M2's B-05 numbers (red truck rear at 22:00, 60 m: mean luminance within ±15 % of Arcade's 42, pixels above 200
   ≤ 1 %; silver sedan 60 m) with check_vehicle_lights 'abblendlicht' green, AND check_night_nass (wet cone 0.7–1.15×
   Arcade, edge line ≥ 0.8× Arcade's contrast, no reflection pixels above a car roof) green. Show the wet road at
   night in the low beam (N2 and DEV 21:00 rain) before/after.
4. Brake glow and beacon gain at night (NACH-M2 N-01, A-20): FIX-M2's ×2.2 brake / ×2.4 beacon gains are for
   daylight; scale them by daylight so that at night the glow stays within Arcade +10 % (sports car 60 m, sedan 20 m,
   police 60 m), while the day values stay as FIX-M2 measured them. check_vehicle_lights must still fail with the old
   gains of 1.0.
5. Tint of model instances (A-19): props.gd passes the placement tint ("tint", "fallback_tint") only to stand-ins
   (\`if not is_model\` in _place, about line 643), so models are untinted in Modern: building_shop ×9, building_block_a ×3,
   building_oldtown, bush_low today, and with AS5a city_german_house #e8b8a4 and city_german_mietshaus #e0b09c on the
   Hanseatic outskirts (Kiel, Hamburg), gruenderzeit/mietshaus in Bavaria and Switzerland. Pass the tint to model
   instances through the MultiMesh colour (or another per-instance channel that is NOT an instance uniform) and let
   baked/vpbr(_static) multiply the albedo by it as Arcade multiplies the sprite; a model without a tint gets white
   (byte-identical picture). AS5aR1 delivered a tint study (${SP}/deliver/AS5aR1/, toenungen*). A/B against Arcade at
   Kiel and Hamburg outskirts, a Bavarian town, and a shop/block placement; unit test that a tinted placement reaches
   the model instance.
6. Instance-uniform budget (A-19, NACH-M2 N-02): after these merges (more lamps, flares, city builder, AS5a houses)
   measure the scene census at „Hoch“ with full traffic on Kiel–Hamburg, on a forest stage (Dortmund–Frankfurt km
   40–60) and on a city finish (Nürnberg): scene ≤ 230, the engine never refuses ("Too many instances using shader
   instance variables" never in the log). FIX-M2 shortened the forest check to 20 s so it no longer loads the budget:
   restore a check that really loads it (pre-filled traffic or a longer drive) with its own timeout header (FIX-M2's
   mechanism), and prove it fails when VPBR_STATIC is removed from props.
7. Gameplay boards (NACH-R6 N-04, A-18): at 3 canopies network-wide (prag_leipzig km 148.2, sibiu_timisoara km 149.1,
   prag_nuernberg km 233.3) the fallback end column (Arcade has none) covers a gameplay board, worst an 89 % covered
   'curve' warning at 210 m. Hang those roofs like the border roofs instead; scan_f1 (QA-R6's tool,
   ${SP}/m1/QA-R6/) must show 0 pairs with a gameplay board ≥ 6 px for columns Arcade does not draw.
8. collect() budget (A-18, NACH-R6 N-02): measure collect() per layer and builder on the Deck preset over a whole
   stage with fuel stations and borders (llvmpipe, under the current load – compare with the base in the same run,
   A-11). If the fuel-station/border line-of-sight decision exceeds 2 ms per frame, move it to the worker build or
   prepare() (one decision per roof stays deterministic, independent of where the race started – NACH-R6 N-01).
9. FIX-R6's notes for the light layers (now one owner – you): lights.gd reads per-frame energy from the lamp entries
   (so the radar flash can light the road), flares.gd skips entries with role 'on' and energy 0 and takes optional
   'glow'/'halo' keys. Do them if they are small and tested; else list them.
10. Paint after the merge (FIX-M2 B-06, FIX-R4 B3/B7): where FIX-M2's day desaturation (player_paint) meets FIX-R4's
   night sheen_wash, re-measure the paint saturation of the sedan/limousine at 12:00, 19:30 and 21:00, the sports car
   at 19:30 and the silver Gran Turismo at night in the rain against Arcade (FIX-R4: check_night -- --only=spielerauto
   --fall=Turismo; CAR_SAT_MIN 0.85 is its hint); bring them within ±15 % of Arcade where it is a constant, else list.
11. What the R4/R5 fix rounds and re-checks left open: ${A.r4open || 'see NACH-R4'}; ${A.r5open || 'see FIX-R5 / NACH-R5'}.
   Fix what is small and belongs to the assembly; list the rest with the package it belongs to.
12. The paint flicker of test build 1 is paused at the user's request (A-21): change nothing for it. R4 already
   cross-fades lod0 – keep that as R4 built it.
${A.notes ? `13. ${A.notes}` : ''}`

const INFO = (r) => JSON.stringify({ branch: r.branch, commit: r.commit, summary: r.summary,
  open: (r.acceptance || []).filter(a => a.result !== 'pass'), deviations: r.deviations, notes: r.notes_for_next,
  look: r.look_verdict })

const POSITIONS = `S1–S5, T1–T4, C1, N1 (night, snow), N2 (rain), U1, DEV, plus: a tunnel by day and at 22:00 (Gotthard
and one short tunnel), the Köhlbrandbrücke and a stone bridge by day and at 22:00, the fuel station Kiel–Hamburg km 15
(day, 21:00), a border by day and at night, the start and the finish of Kiel – Hamburg, Hamburg centre and the Kiel
outskirts with the new city buildings (12:00, 19:30, 22:00), Nürnberg old town`

phase('Zusammenbau')
const r = await agent(`${common('RINT-M2', { mode: 'fresh', base: BASE }, 'render')}
YOUR ROLE: RINT-M2 – SECOND ASSEMBLY OF PUSH M2. Your base is ${BASE} (origin/wip/v080-fix-m2): the first M2 assembly
(M2INT ${D('M2INT')}), the merged fixes of the user's first test build (M2ZS1 ${D('M2ZS1')}) and the fixes after its
independent QA (FIX-M2 ${D('FIX-M2')}, re-check ${D('NACH-M2')}). The wave-3 renderer packages and the first city
buildings were built on 6e48405, each reviewed independently, fixed and re-checked. Merge with --no-ff in this order
(German messages, trailer as above):
  ${MERGES}
${LEAD}
YOU NOW OWN EVERY FILE OF THIS PUSH. Make it one consistent game:
- After each merge: import clean, tests/check_scripts.gd, the unit and render tests of the merged area (filters).
- A/B with tools/ab_shot.sh at ${POSITIONS} – --gfx-preset=high and medium, deck at S1, N2 and the tunnel; two 30-s A/B
  clips side by side with the HUD (Kiel – Hamburg from the start through the fuel stop at km 15; a night stretch in the
  rain with a tunnel). LOOK at every picture against Arcade AND against the packages' own delivered pictures; nothing
  may be worse than the package showed it alone (interactions: wet road × low beam × lamps × flares × tunnels × bridges ×
  city lamps × building windows at night). Write an honest list: what is now clearly better than Arcade, what is equal,
  what is still worse.
GATES on your final head (commands and output in bericht.md): import clean; tests/check_scripts.gd; tools/run_tests.sh
green (load-only timing failures: rerun alone and against ${BASE} in the same run, A-11); tools/golden.sh check 20 von 20
and 17 von 17 (once); tools/golden.sh modern-make after looking, then modern-check 6 von 6 and the GLES comparison;
tools/run_render_checks.sh all (RENDER_CHECK_TIMEOUT per file as the headers say; a run stopped by a tool limit
continues file by file); tests/sim/modern_sight.gd -- --full and modern_path_check.gd -- --full; the validator, export
determinism (export_models.py --check-keys, a second bake byte-identical) and check_sprite_geometry.py; audio_qc.py;
ERGEBNIS identity Arcade vs Modern (tests/race/run_stage.gd) on kiel_hamburg, dev_testetappe (night, rain) and
saragossa_pau (snow); complete Modern autopilot runs with perf_stats of Kiel–Hamburg (medium and deck) and of a stage
with a city finish and a tunnel, next to ${BASE} in the same session (render() ms average and max, chunk commit ms max,
collect() ms, draw calls, primitives, memory; llvmpipe measured, real hardware inferred); texture memory (A-6);
tools/build_linux.sh and tools/build_windows.sh with the pck report inside the size budget (about 280 MB download);
tools/smoke_modern.sh on the Linux export (plain and DRIVER=opengl3_es) and the Windows export under Wine (wine64,
wineserver -w between runs, TMPDIR unset). Push every commit to origin wip/v080-rint-m2. Deliver the A/B sheets, the
clips and bericht.md in ${SP}/deliver/RINT-M2/. Return the result format with package "RINT-M2": one acceptance entry
per merge, per lead note and per gate.`,
  { label: 'zusammenbau:RINT-M2', phase: 'Zusammenbau', schema: BUILD_R, isolation: 'worktree' })
if (!r || !r.commit) { log('RINT-M2 fehlt'); return { r } }
log(`RINT-M2: ${r.commit.slice(0, 7)} (${r.acceptance.filter(a => a.result === 'fail').length} offen)`)
const HEAD = r.commit

const LENSES = [
  { id: 'QA-RINT-BILD', prompt: `LENS: PICTURE IN EVERY CONDITION, FAIRNESS, PERFORMANCE. Judge what the player sees in Modern
against Arcade of the same simulation state (tools/ab_shot.sh) at ${POSITIONS}, at 08:00, 12:00, 19:30, 22:00, dry, rain
and snow, and in motion (10–20 s autopilot clips at 60 fps fixed; look at single frames): light and night (low beam on
dry and wet road, lamps, flares, reflections, building windows, city lamps), weather in the air and on the road,
tunnels (portal by day and at night, inside, the exit), bridges (pylons, cables, lamps, water, banks), fuel station,
border, start/finish, radar, the new city buildings (tint, side walls, LOD switch at 60 m, at night), vehicles (lamps,
brake lights, beacons, paint by day and at night). Nothing may look worse than the package showed alone or than the
base ${BASE}. Fairness: modern_sight --full and modern_path_check --full, compare F1–F7 with the contract (§11.3 included);
a car or a sign must never be visible later or smaller than in Arcade (new canopies, roofs, houses, bridge parts!).
Performance: perf_stats over complete autopilot runs per preset (low, medium, high, deck) of Kiel–Hamburg and of a
night/rain stage with a tunnel, next to ${BASE}; chunk-commit and collect() spikes; memory over 20 minutes (leaks);
the instance census at „Hoch“ (A-19); what real hardware and the Steam Deck would need (inferred).` },
  { id: 'QA-RINT-SYSTEM', prompt: `LENS: ARCADE IDENTITY, BUDGETS, ROBUSTNESS, BUILDS. Arcade must be pixel- and sound-identical to
v0.7.0 (tools/golden.sh check; the Arcade ERGEBNIS of run_stage.gd against v0.7.0 = main on three stages; every frozen
file unchanged against main – git diff --stat main -- <frozen list of the contract>). Rule 3: Modern and Arcade give
the same ERGEBNIS and the same traffic hashes on a whole stage with a fuel stop, a border, a tunnel and a radar.
Budgets: the instance-uniform census (A-19, and that its check really loads the budget – break VPBR_STATIC in a scratch
copy and see it fail), collect() per layer (A-18), chunk commit, texture memory (A-6), the export size (pck_report.py).
Tests: run_tests.sh and run_render_checks.sh all green on the head; the tests the merge changed or added still guard
their rule – break one line per rule in a scratch copy (low-beam specular of A-20 both ways, the night glow gains, the
model tint, the gameplay-board rule of A-18, the goldens) and see the test fail. Robustness: --gfx-debug=fail and a
missing manifest fall back to Arcade with the right message; the Leistungstest (--bench=all) writes a valid
leistungstest.json; the slowness watchdog steps down during the countdown with rain and snow (R4); quitting and
restarting in every screen; 20 minutes of Modern driving without errors in the log; the Linux and Windows builds start
Modern and Arcade (Windows under Wine). The contract §11.3 is in docs/dev/v080_contract.md verbatim.` },
]
phase('Prüfung')
const reviews = (await parallel(LENSES.map(l => () => agent(`${common(l.id, { mode: 'review', base: HEAD }, 'render')}
YOUR ROLE: INDEPENDENT QA OF THE SECOND ASSEMBLY OF PUSH M2 (head ${HEAD}, branch origin/wip/v080-rint-m2) – no commits,
no pushes. The assembly reports: ${INFO(r)}; its report ${D('RINT-M2')}. Its base was ${BASE} (FIX-M2).
Do not trust the reports – run and look yourself. ${l.prompt}
Every finding needs where, what, evidence (command + output or picture path, measured or inferred), how to reproduce
and a concrete fix. Severity: blocker = must not go into the next test build; high = the user will notice at once;
medium = noticeable; low = polish. Also list what you checked and found fine. Pictures and the report (bericht.md)
into ${SP}/deliver/${l.id}/.`,
  { label: `prüfung:${l.id}`, phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })))).filter(Boolean)
const all = reviews.flatMap(x => x.findings)
const cnt = (s) => all.filter(f => f.severity === s).length
log(`Prüfung: ${cnt('blocker')} Blocker, ${cnt('high')} hoch, ${cnt('medium')} mittel, ${cnt('low')} niedrig`)

let fix = null
let nach = null
if (cnt('blocker') + cnt('high') + cnt('medium') > 0) {
  phase('Nacharbeit')
  fix = await agent(`${common('FIX-RINT', { mode: 'fresh', base: HEAD }, 'render')}
YOUR ROLE: FIXES AFTER THE QA OF THE SECOND M2 ASSEMBLY. Your base is ${HEAD} (origin/wip/v080-rint-m2). The assembly
reports: ${INFO(r)}; its report ${D('RINT-M2')}. Contract §11.3 (A-17 … A-22) is in docs/dev/v080_contract.md.
Independent QA found (verdicts and findings; reports ${D('QA-RINT-BILD')} and ${D('QA-RINT-SYSTEM')}):
${JSON.stringify(reviews.map(x => ({ verdict: x.verdict, findings: x.findings })))}
Reproduce each blocker, high and medium finding first (reject it with evidence if it is wrong), fix every confirmed
one, most-seen first, and the cheap low ones. A finding about the bend corridor (A-17) belongs to R7: list it, do not
change the corridor. Re-render the pictures the findings point to and LOOK at them. Then the gates once more on your
final head: import clean; tools/run_tests.sh green; tools/golden.sh check 20 von 20 and 17 von 17; modern-check (and
modern-make only after looking); tools/run_render_checks.sh all; modern_sight --full and modern_path_check --full if a
placement or a size changed; the validator and export determinism if a model changed; audio_qc.py if a sound changed.
Push every commit to origin wip/v080-fix-rint. Report in ${SP}/deliver/FIX-RINT/bericht.md. Return the result format
with package "FIX-RINT": one acceptance entry per finding you handled (pass = fixed and re-checked, fail = still open,
not_run = rejected or not yours – say why), then the gates.`,
    { label: 'nacharbeit:FIX-RINT', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
  const game = fix && fix.commit && (fix.files_changed || []).some(f => !/^(\/|docs\/|tests\/|ARCHITECTURE|README|deliver|\(|Bericht|bericht)/.test(f))
  if (fix) log(`FIX-RINT: ${fix.commit ? fix.commit.slice(0, 7) : '?'} (${fix.acceptance.filter(a => a.result === 'fail').length} offen, Spiel geändert: ${game ? 'ja' : 'nein'})`)
  if (game) {
    phase('Nachprüfung')
    nach = await agent(`${common('NACH-RINT', { mode: 'review', base: fix.commit }, 'render')}
YOUR ROLE: NACH-RINT – FOCUSED RE-CHECK of the fix round FIX-RINT only (head ${fix.commit}, origin/wip/v080-fix-rint). No
commits, no pushes. The findings of the independent QA that FIX-RINT had to handle:
${JSON.stringify(all.filter(f => f.severity !== 'low'))}
FIX-RINT reports: ${INFO(fix)}; its report ${D('FIX-RINT')}.
Do not trust the report – reproduce each finding on the new head and judge it (pictures with tools/ab_shot.sh against
Arcade and against ${HEAD}; LOOK at them); git diff ${HEAD}..${fix.commit} for side effects and frozen Arcade files;
tools/golden.sh check once (20 von 20, 17 von 17); the render checks and tests that belong to the changed files; what
the user has in test build 1 must still hold (the car at the start, the water under bridges, the pylons at night).
Return per finding fixed / partly / not_fixed / not_checked with evidence, any new finding, and the gates you ran with
their output. Pictures and bericht.md into ${SP}/deliver/NACH-RINT/.`,
      { label: 'nachprüfung:NACH-RINT', phase: 'Nachprüfung', schema: RECHECK, isolation: 'worktree' })
  }
}
return { r, reviews, fix, nach }
