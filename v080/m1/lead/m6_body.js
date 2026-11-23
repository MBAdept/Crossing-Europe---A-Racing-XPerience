
// M2, third assembly + the open road: RINT-M3 merges FIX-R7a, FIX-R7b, FIX-R7c onto FIX-RINT → R7D on the assembly →
// KRITIK-R7D ∥ QA-R7D → FIX-R7D → NACH-R7D.
// ARGS: { base: '<FIX-RINT head>', r7a: '<FIX-R7a head>', r7b: '<FIX-R7b head>', r7c: '<FIX-R7c head>', notes: '' }
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
    verdict: { type: 'string', description: 'is the fixed head a sound base for QA-mid and test build 2? 3-6 sentences' },
    per_finding: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, status: { type: 'string', enum: ['fixed', 'partly', 'not_fixed', 'not_checked'] },
      evidence: { type: 'string' } }, required: ['id', 'status', 'evidence'] } },
    findings: FINDINGS.properties.findings,
    gates: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'per_finding', 'findings', 'gates'],
}

const MERGES = [
  `R7a = origin/wip/v080-fix-r7a (${A.r7a})  the sight corridor of A-17 from the real geometry (sight_corridor.gd, the
        exact envelope in the chunk snapshot, in_sight_envelope()/bend_intrusion(), border pillars and city fences against
        it) – R7a ${D('R7a')}, review ${D('QA-R7a')}, fixes ${D('FIX-R7a')}, re-check ${D('NACH-R7a')}`,
  `R7b = origin/wip/v080-fix-r7b (${A.r7b})  landmarks, skyline and their light (landmarks.gd, landmark.gdshader, the
        skyline part of backdrop.gd) – R7b ${D('R7b')}, review ${D('QA-R7b')}, fixes ${D('FIX-R7b')}, re-check
        ${D('NACH-R7b')}`,
  `R7c = origin/wip/v080-fix-r7c (${A.r7c})  far LOD of buildings and plants (path band with cross-fade, ce_lod_still,
        far light, shimmer, dusk windows, attachments, AS5a batch 2 and the re-export of all 23 city houses) – R7c
        ${D('R7c')}, review ${D('QA-R7c')}, fixes ${D('FIX-R7c')}, re-check ${D('NACH-R7c')}`,
].join('\n  ')

const LEAD = `LEAD NOTES FOR RINT-M3 (decisions of the lead; measured facts from the reports and a trial merge):
1. Trial merge by the lead (git merge-tree, chained in the order above onto ${BASE}): the code merges cleanly; the only
   conflict is docs/renderer-modern.md at R7b (one consistent text, keep every package's section). FIX-R7c checked its
   merge with FIX-RINT and FIX-R7a pairwise only: after the three merges run test_props, check_lod_band, the landmark
   checks and test_chunk_streamer before anything else.
2. Contract: right after the three merges, append the lead's text ${SP}/m1/lead/contract_11_4.md VERBATIM to
   docs/dev/v080_contract.md as §11.4 (after the end of §11.3; one commit "Vertrag §11.4 (Leitung): R7-Aufteilung,
   Sichtkorridor ganzes Objekt, Wahrzeichen, LOD-Band, Freie Strecke, Streamer-Budgets, Plan"). Read it – A-23 … A-29
   bind this assembly.
3. A-24, the whole object in the envelope (QA-R7a QR7a-01 high, only partly fixed; NACH-R7a NR7a-01/-02): FIX-R7a
   delivered the props.gd change as a patch (${SP}/deliver/FIX-R7a/patch_props.py and props_hinausschieben.diff, written
   for R7c bd1803b – FIX-R7c changed props.gd since, adapt it by hand where it does not apply). Apply it so that the
   reach comes from the MODEL AABB (largest variant, turned as placed; aligned houses: max(extent, AABB side) across the
   road, the AABB along it) and the same model is used in the push-out and in the network check; include attach_list;
   check city_french_sud's extent_m (its geometry reaches 2.08 m beyond extent_m.left). git mv
   tests/race3d/props_footprint.gd (+ .uid) to check_props_footprint.gd so run_tests gates it; --full must give 0, and a
   foot-only mutation must turn it red. Pictures (Arcade | ${BASE} | head) at C1, München, Bern, T4, Belgrad.
4. NACH-RINT N-01 (medium, A-28): a chunk dropped while COMMITTING leaves reflectors registered in lights.gd; after
   _free_trash() every _update_glints() raises SCRIPT ERROR and the glints freeze. Release what a committing chunk
   registered when it is dropped, and let _update_glints() (and every other layer list) skip entries whose node is no
   longer valid. Unit test: reflector on a node that never enters the tree, free it, update the glints → no error,
   count 0. NACH-RINT's probe: ${SP}/m1/NACH-RINT/sh/probe_reflectors.gd. Also N-02 (low): in the last ~2 m before the
   tunnel exit the glare quad shows hard edges – cover the frustum or use Arcade's full-screen law there.
5. NACH-R7c NR7c-01 (medium, A-26): ce_lod_still is binary; above 1.5 m/s the full band returns and a car driving off or
   crawling shows the ordered dither for seconds (and lod0 → half lod1 → lod0 while approaching). Bind the band width to
   the camera speed with one global ce_lod_band_m = speed × 0.4 s and w' = min(w, ce_lod_band_m) toward the far end.
   Look at a stop-and-go clip at „Mittel“ (queue, police) before/after. NR7c-02: the four mutations N1, N3, N4, N5 must
   turn a test red (NACH-R7c's report says how). NR7c-03: the comment at props.gd ~l.75 (far end, not middle).
6. NACH-R7b N-1 (low, A-25): the drawn landmark node can sit up to 11.9 m off Arcade's anchor and nothing checks it.
   Make the network test check the drawn node (≤ 12 m, the contract's bound) or turn about the near corner; state the
   shift and its maximum in docs §18.1.
7. Streamer and main thread (A-28; QA-RINT-SYSTEM B-01, NACH-RINT B-01/F-08, NACH-R7a NR7a-03, FIX-R7c's note on
   collect()): commit per frame reached 6.51 ms on Kiel–Hamburg day at deck (roadside alone 6.32, terrain 4.73, road
   4.16) because a builder is never split; collect() of all builders reached 2.9–3.9 ms on Kiel–Hamburg at deck. Split
   the commit of roadside, terrain and road into parts as A-28 says; book the corridor warming as its own part
   (tu = _part_us("warm", tu) after _warm_corridor()); find which builder's collect() exceeds 2 ms and move the work to
   prepare()/the worker. Judge every maximum as the median of three runs beside ${BASE} in the same session.
8. reflector.gdshader (FIX-R7b's note, inferred from code): line ~21 uses PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y in
   the vertex stage, which is negative in the Compatibility renderer – the same bug R7b found in the landmark glow.
   Measure the reflector glint size against Arcade at night; if it is the cap, fix it as landmark.gdshader does (abs()
   and a viewport_h uniform) and add a render-check case that fails with the signed value.
9. Night windows of city houses (QA-RINT-BILD F-04, FIX-R7c's note): the Hanseatic house in Hamburg at 22:00 shows
   0.46 × Arcade's warm-lit window area (the sprite base had 0.76 ×); Lyon's suburb and the forest stages are weaker too.
   Measure on the merged head (R7c's dusk windows are in now). If the baked night law can light 35–45 % of the residential
   windows per house with a fixed seed from what the bake already carries (emit maps), do it and show A/B at Hamburg and
   Lyon at 22:00 (target: warm share per house 0.85–1.15 × Arcade); if it needs the bake, list it for AS5b (A-29).
10. Docs: renderer-modern-gelaende.md §8 'Kurveninnenseiten' → FIX-R7a's text (${D('FIX-R7a')} §9 item 4); the
   terrain_profile.gd header names in_sight_envelope() (NR7a-04).
11. Rule 8 and the sprites: every helper and probe runs with an absolute XDG_DATA_HOME (QA-RINT-SYSTEM B-07 caught R7
   probes in the real user folder; the lead cleaned it). R7c/AS5aR2 changed tools/blender/cesprites/props_cities.py with
   3D hooks that the sprite path never sets (inner_k, bars_k, side, close3d): show it from the code and, if it costs less
   than 20 minutes, re-render one affected sprite sheet in a scratch copy and cmp it with the committed PNG.
12. Goldens: FIX-R7c regenerated modern_slice.* itself; per A-18/A-29 regenerate ONCE at the end with
   tools/golden.sh modern-make after LOOKING at all six pictures, and say so in the commit and the report.
13. The paint flicker of test build 1 stays paused (A-21): change nothing for it.
${A.notes ? `14. ${A.notes}` : ''}`

const INFO = (r) => JSON.stringify({ branch: r.branch, commit: r.commit, summary: r.summary,
  open: (r.acceptance || []).filter(a => a.result !== 'pass'), deviations: r.deviations, notes: r.notes_for_next,
  look: r.look_verdict })

const POSITIONS = `S0–S5, T1–T4, C1, N1 (night, snow), N2 (rain), U1, DEV, plus: München, Belgrad, Hannover and Lyon in their
town bends; a border roof (Belgrad–Sofia km 340) by day; Hamburg arrival with the Michel and the Elbphilharmonie at
12:00 and 22:00; the Florianturm Dortmund at 22:00; a tunnel by day and at 22:00 (the exit included); the fuel station
Kiel–Hamburg km 15 (day, 21:00); Hamburg centre and the Kiel outskirts with the city houses (12:00, 19:30, 22:00);
Nürnberg old town`

phase('Zusammenbau')
const r = await agent(`${common('RINT-M3', { mode: 'fresh', base: BASE }, 'render')}
YOUR ROLE: RINT-M3 – THIRD ASSEMBLY OF PUSH M2. Your base is ${BASE} (origin/wip/v080-fix-rint): the second assembly
RINT-M2 (${D('RINT-M2')}) after its independent QA (${D('QA-RINT-BILD')}, ${D('QA-RINT-SYSTEM')}), its fix round
(${D('FIX-RINT')}) and re-check (${D('NACH-RINT')}). The three R7 packages were built on RINT-M2 (9b02f05), each reviewed
independently, fixed and re-checked. Merge with --no-ff in this order (German messages, trailer as above):
  ${MERGES}
${LEAD}
YOU NOW OWN EVERY FILE OF THIS PUSH. Make it one consistent game:
- After each merge: import clean, tests/check_scripts.gd, the unit and render tests of the merged area (filters).
- A/B with tools/ab_shot.sh at ${POSITIONS} – --gfx-preset=high and medium, deck at S1, N2, T2 and the tunnel; two 30-s A/B
  clips side by side with the HUD (Kiel – Hamburg from the start through the fuel stop at km 15; Saragossa–Pau through
  the mountain bends) and the stop-and-go clip of note 5. LOOK at every picture against Arcade AND against the packages'
  own delivered pictures; nothing may be worse than a package showed it alone (interactions: corridor push-out × LOD
  band × attachments × landmarks × skyline × night windows × lamps). Write an honest list: what is now clearly better than
  Arcade, what is equal, what is still worse.
GATES on your final head (commands and output in bericht.md): import clean; tests/check_scripts.gd; tools/run_tests.sh
green, check_props_footprint included (load-only timing failures: rerun alone and against ${BASE} in the same run,
A-11); tools/golden.sh check 20 von 20 and 17 von 17 (once); tools/golden.sh modern-make after looking, then modern-check
6 von 6 and the GLES comparison; tools/run_render_checks.sh all (RENDER_CHECK_TIMEOUT per file as the headers say; a run
stopped by a tool limit continues file by file); tests/sim/modern_sight.gd -- --full and modern_path_check.gd -- --full;
the A-17 occlusion probe at T1–T4, C1, S0, S4; the validator, export determinism and check_sprite_geometry.py;
audio_qc.py; ERGEBNIS identity Arcade vs Modern (tests/race/run_stage.gd) on kiel_hamburg, dev_testetappe (night,
rain) and saragossa_pau (snow); complete Modern autopilot runs with perf_stats of Kiel–Hamburg (medium and deck, three
runs each for the maxima) and of a stage with a city finish and a tunnel, next to ${BASE} in the same session (render()
ms average and max, chunk commit per part, collect() per builder, draw calls, primitives, memory; llvmpipe measured,
real hardware inferred); the instance census of A-19 (≤ 230); texture memory (A-6); tools/build_linux.sh and
tools/build_windows.sh with the pck report inside the size budget; tools/smoke_modern.sh on the Linux export (plain and
DRIVER=opengl3_es) and the Windows export under Wine (wine64, wineserver -w between runs, TMPDIR unset). Push every
commit to origin wip/v080-rint-m3. Deliver the A/B sheets, the clips and bericht.md in ${SP}/deliver/RINT-M3/. Return the
result format with package "RINT-M3": one acceptance entry per merge, per lead note and per gate.`,
  { label: 'zusammenbau:RINT-M3', phase: 'Zusammenbau', schema: BUILD_R, isolation: 'worktree' })
if (!r || !r.commit) { log('RINT-M3 fehlt'); return { r } }
log(`RINT-M3: ${r.commit.slice(0, 7)} (${r.acceptance.filter(a => a.result === 'fail').length} offen)`)
const HEAD = r.commit

phase('Freie Strecke')
const b = await agent(`${common('R7D', { mode: 'fresh', base: HEAD }, 'render')}
YOUR ROLE: R7d – "FREIE STRECKE", THE OPEN ROAD OF MODERN. Your base is ${HEAD} (origin/wip/v080-rint-m3), the third
assembly of push M2; its report ${D('RINT-M3')} – read its honest list of what is better, equal and worse. Contract
§11.4 is in docs/dev/v080_contract.md; A-27 is your package, A-24 … A-29 bind you.
${R7D_WHY}
${R7D_SCOPE}
${R7D_RULES}
${R7D_GATES}
Push every commit to origin wip/v080-r7d. Deliver the A/B sheets (one per position, Arcade | base | head), the clips and
bericht.md in ${SP}/deliver/R7D/ – bericht.md starts with the per-picture verdict "recognisable at first glance: yes /
partly / no" for S1 and S3 in all seven conditions and for Deck S1. Return the result format with package "R7D": one
acceptance entry per item of the scope (1–7), per rule and per gate.`,
  { label: 'bau:R7D', phase: 'Freie Strecke', schema: BUILD_R, isolation: 'worktree' })
if (!b || !b.commit) { log('R7D fehlt'); return { r, b } }
log(`R7D: ${b.commit.slice(0, 7)} (${b.acceptance.filter(a => a.result === 'fail').length} offen)`)
const RH = b.commit

const LENSES = [
  { id: 'KRITIK-R7D', prompt: `LENS: ART DIRECTION – THE FIRST GLANCE. You are the user's eye: an art director who has to say whether the
graphics option "Modern" now delivers "eine deutliche grafische Überarbeitung … Detailreiche Grafik … bessere
Lichteffekte" where the player spends most of the race. Render yourself (tools/ab_shot.sh, same simulation state, HUD
on, --gfx-preset=high, medium and deck) S1, S3, S0, S4, T2 and two further open-motorway places of your choice on other
stages (another country, another scenery: e.g. France, the Balkans, the Alps), each at 08:00, 12:00, 19:30, 22:00, clear,
rain and snow, and 20-s clips by day and at dusk side by side with Arcade (look at single frames AND judge the motion:
cloud drift, cloud shadows passing, shimmer). For every picture: is Modern recognisable at first glance, is it clearly
more beautiful, and what still reads as Arcade's picture? Judge the sky (clouds, light, horizon), the road surface
(does it read as a real motorway at the chase camera; is anything noisy, repetitive, tiled or "dirty" in a bad way),
the land (meadows, fields, relief, cloud shadows, tree shadows), the coherence of light (sun, clouds, shadows and
reflections agree), and whether any of it makes the picture busier where the player must read the road. Also check
that nothing elsewhere got worse than the assembly RINT-M3 (${HEAD}): a city arrival, a tunnel portal, a night in the
rain. Be concrete: what exactly to change, where, how much.` },
  { id: 'QA-R7D', prompt: `LENS: FAIRNESS, RULES, BUDGETS, IDENTITY. Fairness: modern_sight --full and modern_path_check --full; F4 – static
scenery never fogged more than Arcade at the same road point (measure the contrast of far scenery against Arcade at
several distances and weathers; the sky's horizon band and hue shifts must not lower it); F5/F6 untouched (vehicles,
signs, their lights); cloud shadows never on vehicles, signs or lights, on the road at most the soft dimming of A-27
(measure it); marking contrast ≥ 0.9 × Arcade at 20/60/120 m day/night/dry/wet on the new road surface (Rule 9);
relief only outside the A-17 envelope (F7, the occlusion probe at T1–T4, C1, S0, S4 unchanged against ${HEAD});
check_props_footprint 0. Determinism: the sky uses no TIME – two renders of the same state are byte-identical, goldens
stable. Budgets: perf_stats of complete autopilot runs per preset (deck, low, medium, high) of Kiel–Hamburg next to
${HEAD} in the same session (render() ms mean/max, the sky's own cost, draw calls, primitives, memory; three runs for
maxima), §4.10; the Steam Deck keeps sky and cloud shadows (A-27) – infer its cost. Identity: tools/golden.sh check
20/20 and 17/17, every frozen Arcade file unchanged against main, ERGEBNIS identity Arcade vs Modern (Rule 3) on two
stages. Tests: run_tests.sh and run_render_checks.sh all green; R7d's new guards really guard – break one line per rule
in a scratch copy (marking contrast, cloud shadow on the road/vehicles, the F4 fog law, relief inside the envelope) and
see the test fail. Robustness: --gfx-debug=fail fallback, the Leistungstest writes a valid leistungstest.json, the
slowness watchdog, 20 minutes of Modern driving without errors in the log.` },
]
phase('Prüfung')
const reviews = (await parallel(LENSES.map(l => () => agent(`${common(l.id, { mode: 'review', base: RH }, 'render')}
YOUR ROLE: INDEPENDENT REVIEW OF R7d "FREIE STRECKE" (head ${RH}, branch origin/wip/v080-r7d) – no commits, no pushes.
Its base is the third M2 assembly ${HEAD} (${D('RINT-M3')}). R7d's brief, in short: on the open motorway Modern must be
recognisable at first glance and clearly more beautiful than Arcade (contract §11.4 A-27; QA-RINT-BILD F-02 in
${D('QA-RINT-BILD')} is why it exists). R7d reports: ${INFO(b)}; its report ${D('R7D')}.
Do not trust the report – run and look yourself. ${l.prompt}
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
  fix = await agent(`${common('FIX-R7D', { mode: 'fresh', base: RH }, 'render')}
YOUR ROLE: FIXES AFTER THE REVIEW OF R7d "FREIE STRECKE". Your base is ${RH} (origin/wip/v080-r7d) on the assembly
${HEAD}. R7d reports: ${INFO(b)}; its report ${D('R7D')}. Contract §11.4 (A-23 … A-29) is in docs/dev/v080_contract.md;
A-27 is the package's law.
The independent review found (verdicts and findings; reports ${D('KRITIK-R7D')} and ${D('QA-R7D')}):
${JSON.stringify(reviews.map(x => ({ verdict: x.verdict, findings: x.findings })))}
Reproduce each blocker, high and medium finding first (reject it with evidence if it is wrong), fix every confirmed
one, most-seen first, and the cheap low ones. Re-render the pictures the findings point to and LOOK at them against
Arcade and against ${RH}. Then the gates once more on your final head: import clean; tools/run_tests.sh green;
tools/golden.sh check 20 von 20 and 17 von 17; tools/run_render_checks.sh all; modern_sight --full and
modern_path_check --full; perf_stats of Kiel–Hamburg at deck and high beside ${RH} if a shader or a budget changed. Do
not regenerate tests/golden/modern_slice.* (A-18); list which pictures changed. Push every commit to origin
wip/v080-fix-r7d. Report in ${SP}/deliver/FIX-R7D/bericht.md. Return the result format with package "FIX-R7D": one
acceptance entry per finding you handled (pass = fixed and re-checked, fail = still open, not_run = rejected or not
yours – say why), then the gates.`,
    { label: 'nacharbeit:FIX-R7D', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
  const game = fix && fix.commit && (fix.files_changed || []).some(f => !/^(\/|docs\/|tests\/|ARCHITECTURE|README|deliver|\(|Bericht|bericht)/.test(f))
  if (fix) log(`FIX-R7D: ${fix.commit ? fix.commit.slice(0, 7) : '?'} (${fix.acceptance.filter(a => a.result === 'fail').length} offen, Spiel geändert: ${game ? 'ja' : 'nein'})`)
  if (game) {
    phase('Nachprüfung')
    nach = await agent(`${common('NACH-R7D', { mode: 'review', base: fix.commit }, 'render')}
YOUR ROLE: NACH-R7D – FOCUSED RE-CHECK of the fix round FIX-R7D only (head ${fix.commit}, origin/wip/v080-fix-r7d). No
commits, no pushes. The findings of the independent review that FIX-R7D had to handle:
${JSON.stringify(all.filter(f => f.severity !== 'low'))}
FIX-R7D reports: ${INFO(fix)}; its report ${D('FIX-R7D')}.
Do not trust the report – reproduce each finding on the new head and judge it (pictures with tools/ab_shot.sh against
Arcade and against ${RH}; LOOK at them); git diff ${RH}..${fix.commit} for side effects and frozen Arcade files;
tools/golden.sh check once (20 von 20, 17 von 17); the render checks and tests that belong to the changed files;
modern_sight --full if anything near the road changed. Above all: is the open motorway (S1, S3, Deck S1) now
recognisable at first glance, and did nothing the player reacts to get harder to see? Return per finding fixed / partly
/ not_fixed / not_checked with evidence, any new finding, and the gates you ran with their output. Pictures and
bericht.md into ${SP}/deliver/NACH-R7D/.`,
      { label: 'nachprüfung:NACH-R7D', phase: 'Nachprüfung', schema: RECHECK, isolation: 'worktree' })
  }
}
return { r, b, reviews, fix, nach }
