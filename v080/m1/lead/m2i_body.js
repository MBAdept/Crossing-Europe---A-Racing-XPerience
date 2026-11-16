
// M2, first assembly: M2INT merges the finished early content onto the first test build (ZS1) → QA with two lenses →
// FIX-M2. ARGS: { base: '<v0.8.0 head after ZS1 + contract §11.2>', zs1: '<QA1 head>', as4r: '<AS4R head>' | null,
//   sound: '<last sound head>' , soundNote: '<what the sound head is>', notes: '<extra lead notes>' }
const A = args || {}
const BASE = A.base
const AS4R = A.as4r || null
const SOUND = A.sound || '3600eb76c136d5c2c66537675c87511e3518b0ba'
const SOUND_NOTE = A.soundNote || 'AU-R2 head (the acceptance AU-R3/KRITIK-R2 of the sound may still run; its later delta is merged afterwards)'
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

const MERGES = [
  `AS2R  = origin/wip/v080-as2r (c7546c1)  all vehicle models – 37 models for all 180 vehicle sets: the five player cars
          with interiors, transparent glass and rims (AS2a), the trucks in three types, the bus and the police (AS2b),
          reworked after an independent art review (AS2R; reports ${D('AS2R')}, review ${D('KRITIK-2')})`,
  `AS3R  = origin/wip/v080-as3r (638debc)  vegetation and nature – 18 trees (nine species × 2 variants), bushes, heather,
          rocks a/b, cliff (AS3 ${D('AS3')}, review ${D('KRITIK-3')}, rework AS3R ${D('AS3R')})`,
  AS4R ? `AS4R  = origin/wip/v080-as4r (${AS4R})  rural buildings, street furniture, bridge parts, ships – house, church,
          factory, shop, old-town house, blocks A/B, office tower, houseboat, ferry, bridge lamp, pylon, truss portal,
          windmill windows (AS4 ${D('AS4')}, review ${D('KRITIK-4')}, rework AS4R ${D('AS4R')})` : null,
  `SOUND = ${SOUND}  the Modern sound of M2 – ${SOUND_NOTE}: race tracks 2–3, interlude, stingers, UI sounds (AU-D2
          ${D('AU-D2')}); road, tyres, wind, impacts and a Modern-only limiter (AU-C1 ${D('AU-C1')}, reworked after the
          user's headphone verdict „solide", music „sehr gut": AU-R ${D('AU-R')}, AU-R2 ${D('AU-R2')}, AU-R3
          ${D('AU-R3')}, AU-R4 ${D('AU-R4')}; independent acceptance ${D('KRITIK-R2-MESS')}, ${D('KRITIK-R2-CODE')},
          re-check ${D('KRITIK-R3')})`,
].filter(Boolean).join('\n  ')

const LEAD = `LEAD NOTES FOR M2INT (decisions of the lead; measured facts from the reports and trial merges):
1. Trial merge by the lead (git merge-tree, chained in this order onto FIX1's head 28e4e8e – QA1 added goldens, test
   hooks and build-only changes on top, re-check on your base): AS2R conflicts in assets/models/manifest.json,
   assets/models/traffic/truck/{lod0_trailer,lod1_body,lod2_body}.res and model.json, docs/modelle.md,
   tools/blender/ce3d/catalog3d.py, tools/blender/export_models.py, tools/models/contact_sheet.gd; AS3R then in
   docs/modelle.md and export_models.py; AS4 (the base of AS4R) in manifest.json, docs/modelle.md, export_models.py; the
   sound only in docs/audio-modern.md (FIX1 rewrote two sentences of §1/§2 about the Klang setting – keep FIX1's text and
   the sound branch's new sections).
2. Trucks: RINT-B (9eac32f) added lamp channel 15 "retro" (contour tape and triangle reflectors light up in the
   player's low beam; roles.py SURFACE_CHANNELS += retro; validator LAMP_CHANNELS 16) and re-exported traffic/truck;
   AS2b/AS2R rebuilt the heavy vehicles as three truck types (truck, truck_transport, truck_tarp) + bus (heavy3d) +
   police (police3d). Resolution: take AS2R's builders, re-apply "retro:%.2f" % TAPE_NIGHT to every retro-reflective
   surface of ALL heavy types (red/yellow contour tape, triangle reflectors; bus and police reflectors if they have
   any; AS2R made the SUV reflectors visible – check their channel), keep RINT-B's roles.py and validator change, then
   tools/blender/export_models.py --check-keys and re-export ONLY what it names (props must stay byte-identical unless a
   merged prop package changed them), regenerate assets/models/manifest.json with --manifest-only (never hand-merge
   the manifest), run the validator, and prove export determinism (a second bake byte-identical). The Blender caches
   of the content packages speed up re-exports – copy them without overwriting (cp -an) into your
   tools/blender/_cache3d: AS2R .claude/worktrees/wf_72970c4d-66e-4/tools/blender/_cache3d (58 MB), AS3R
   .claude/worktrees/wf_aad8d49e-fb4-4/tools/blender/_cache3d (35 MB), AS4R .claude/worktrees/wf_aad8d49e-fb4-6/
   tools/blender/_cache3d (21 MB) – read only, never work in those worktrees.
3. contact_sheet.gd: combine all of AS2a (showroom AgX), AS2b (--arcade for traffic/police/heavy, beacon tile), AS2R
   (race look really applied: create the vpbr/glass materials before _apply_look), RINT-B (--showroom with STUDIO_LOOK)
   and AS3 (in-process set for variants without one). catalog3d.py and export_models.py: the union of all entries.
   docs/modelle.md: the union, one consistent numbering.
4. Tests made outdated by the content (you own them now): tests/race3d/check_vehicles.gd "kasten" expects model-less
   sets – none exist any more: use a test manifest with one model-less set; "leistung" counts the lazy first build of a
   level (34 → 35): build all levels at spawn if that is cheap (measure) or count only cars new in the window – timing
   load-robust (A-11). tests/unit/race3d/test_props.gd assumes props/tree_beech has no model – apply AS3's tested patch
   ${SP}/deliver/AS3/vorschlag_test_props_fuer_R2.diff (7/7 pass).
5. Memory, instances, size: every vehicle set is a model now, so the vehicle stand-in sheets must no longer load in
   prepare() – check it; texture memory against the Arcade race of the same stage (budget + 60 MB, A-6) on Kiel–Hamburg
   and on a city stage; the instance census with RINT-B's probe ${SP}/m1/RINT-B/probe/census_probe.gd
   (INSTANCE_BUDGET 128 of the vehicle layer); the export size with tools/pck_report.py against the download budget
   (the whole download about 280 MB at most; the sound is 19.0 of 23 MB).
6. Look after the content change (measure, fix what is cheap, list the rest): the far-level albedo constants
   TRAFFIC_GLASS_FAR, truck3d.GLASS_FAR, FAR_PLATE (heavy3d FAR_PLATE #c4c4c1 vs traffic #a2a2a0) and CHECK_MEAN_EXP
   against today's LOOK with AS2R's probes (${SP}/m1/AS2R/kritik/probe.sh, bin/winmean.py, platemean.py, bandmean.py,
   buswin.py – copy them, never commit them); LOD pops with RINT-B's cross-fade on (SUV and sports car 28–30 % at
   120 m, sedan 14 % at 40 m, police/be 38 % at 120 m, bus 22 % at 180 m before it); the metallic flakes of the GT at
   race distance (KRITIK-2 A4, 83 sparkle px/frame): couple them to fwidth or set flake_strength 0 in the race look;
   showroom flags with RINT-B's studio look (candidates kombi, limousine, sportwagen, gran_turismo; kompakt only if its
   yellow is right) – set showroom: true only where the same-camera A/B is at least as good as the sprite; the vehicle
   LOOK (exposure, clear coat, fill) in one place (ModernMaterials) read by the vehicle layer, the contact sheet and
   the showroom (A-13).
7. AS3R/AS4R items that belong to this merge (reports ${D('AS3R')}, ${D('AS4R')}): tree_olive/tree_olive_b lod1 is
   +5…+8 % brighter than lod0 at the swap (AS3R regression after its gates) – lift its lod1 and re-export; seed variants
   reference their species' leaves.png through variant_of – prove that the exported game (pck) loads them (a Modern
   stage with olives/cypresses from the Windows and the Linux export); AS4R's hook in cesprites/props_buildings.py
   changes the cache key of the builder "building" (AS1b models): --check-keys names them, re-export them and show
   that the files stay byte-identical; the AS1b buildings (farmhouse, customs hut, fuel station) still have vpbr
   channel-12 window panes that are brown/blue by day – move them into the night-light atlas like AS4R did (A-16) if
   that is cheap (props3d.py shares its cache key with AS3's bushes: re-export both, prove determinism), else list it;
   the ferry is never mirrored (mirror_left would turn its bow); houseboats and ferries only where the ground under
   them is water (A-16; the start fix below may already have done it for the stand-ins – keep one rule for models and
   stand-ins); the pylon is now one level with half fans of ±36 m whose cables end beside the deck – check it on the
   Köhlbrandbrücke in the race (drive over it, ≤ 40 m, by day and night): no cable over a lane; scaling it in height by
   height_m / 88.8 only if that is a one-line change of the props builder, else R5 (A-16). Window light is balanced at
   emit_energy 1.6 (A-16) – keep it. NOT yours (R7/R4 later): the tree LOD cross-fade, the tags ground_align /
   ground_sink / face_road, the impostor time-of-day relief, the bend-corridor rule, the rotor phase of the windmill
   (vpbr uses the origin-relative position and jumps at every 2-km rebase – list it).
8. Sound in the game: the Modern profile plays the new road, tyre, wind and impact layers with engine v3 and the
   Modern limiter; the MusicDirector rotates race tracks 1–3 with stingers and the interlude; UI sounds in the Modern
   menus; the Arcade sound stays byte-identical; tools/audio/qc/audio_qc.py over all folders green; quitting leaves no
   "leaked at exit".
9. QA1 created Modern goldens of the slice (tests/golden/modern_slice.md5): the new models change those pictures –
   regenerate them deliberately after you have LOOKED at the new pictures, and say so in the commit and the report.
${A.notes ? `10. ${A.notes}` : ''}`

const INFO = (r) => JSON.stringify({ branch: r.branch, commit: r.commit, summary: r.summary,
  open: (r.acceptance || []).filter(a => a.result !== 'pass'), deviations: r.deviations, notes: r.notes_for_next,
  look: r.look_verdict })

phase('Zusammenbau')
const m2 = await agent(`${common('M2INT', { mode: 'fresh', base: BASE }, 'render')}
YOUR ROLE: M2INT – FIRST ASSEMBLY OF PUSH M2 (contract §6 waves 3–5; §11.2 A-9 … A-16). Your base is ${BASE}
(origin/wip/v080-vertrag): QA1's head ${A.zs1 || '?'} = branch v0.8.0 = the user's first test build (Zwischenstand 1;
reports ${SP}/deliver/QA1/bericht.md and ${SP}/deliver/gate1/bericht.md) plus the lead's contract commit §11.2 – read
§11.2 completely before you start. The early content of M2 was built in parallel
on older heads, each with an independent review and a rework. Merge with --no-ff in this order (German messages,
trailer as above):
  ${MERGES}
${LEAD}
YOU NOW OWN EVERY FILE OF THIS PUSH. Make it one consistent game:
- After each merge: import clean, tests/check_scripts.gd, the unit tests of the merged area (filter of run_tests.sh).
- A/B with tools/ab_shot.sh at S1–S5, T1, T4, C1 (19:30), N1 (night, snow) and N2 (rain), --gfx-preset=high and the
  preset this machine picks, plus the player cars kombi, sportwagen and gran_turismo at S1; two 30-s A/B clips side by
  side with the HUD (the start of Kiel–Hamburg; a stretch with forest and villages, e.g. Dortmund – Frankfurt km 121
  or Hamburg – Hannover). LOOK at every picture against Arcade AND against ZS1 (${SP}/deliver/gate1/,
  ${SP}/deliver/RINT-B/) and improve what is cheap in light, materials and composition; write an honest list: what is
  now better than Arcade, what is still worse or unfinished, what the new models changed.
GATES on your final head (commands and output in bericht.md): import clean; tools/run_tests.sh green;
tools/golden.sh check 20 von 20; tools/run_render_checks.sh all; tests/sim/modern_sight.gd -- --full and
tests/sim/modern_path_check.gd -- --full; python3 tools/blender/validate_models.py --report; export determinism
(export_models.py --check-keys, a second bake byte-identical); check_sprite_geometry.py; audio_qc.py all folders;
ERGEBNIS identity Arcade vs Modern (tests/race/run_stage.gd) on kiel_hamburg, dev_testetappe (night, rain) and
saragossa_pau (snow); a complete Modern autopilot run of Kiel–Hamburg and of one stage with a city finish under Xvfb
without script errors, with perf_stats (render() ms average and max, chunk commit ms max, draw calls, primitives,
memory – llvmpipe, measured; real hardware inferred) next to ZS1's numbers; texture memory (A-6); tools/build_linux.sh
and tools/build_windows.sh succeed with the pck report inside the size budget, and the Windows build starts a Modern
stage under Wine (wine64, wineserver -w between runs, TMPDIR unset). Push every commit to origin wip/v080-m2int.
Deliver the A/B sheets, the two clips and bericht.md in ${SP}/deliver/M2INT/. Return the result format with package
"M2INT", one acceptance entry per merge, per lead note and per gate.`,
  { label: 'zusammenbau:M2INT', phase: 'Zusammenbau', schema: BUILD_R, isolation: 'worktree' })
if (!m2 || !m2.commit) { log('M2INT fehlt'); return { m2 } }
log(`M2INT: ${m2.commit.slice(0, 7)} (${m2.acceptance.filter(a => a.result === 'fail').length} offen)`)

const LENSES = [
  { id: 'QA-M2-BILD', prompt: `LENS: PICTURE, FAIRNESS, PERFORMANCE. Judge what the player sees in Modern against Arcade of the same
simulation state (tools/ab_shot.sh) at S1–S5, T1–T4, C1, N1, N2, U1 and DEV, and in motion (10–20 s clips with the
autopilot at 60 fps fixed; look at single frames): the new vehicle models (every player car from behind at 8 and 30 m,
traffic at 20/60/150 m by day and at night: lamps, indicators, brake lights, beacons, the retro-reflective truck contour
in the low beam, LOD swaps, sitting on the road, wheels), the new vegetation (species read like their sprites, LOD swap
at 60 m, impostors, fog, at dusk and night), the new buildings, bridge parts and ships (where Arcade draws them, size,
colour, windows by day and night, LOD), shadows, light at every hour, the curve camera. Compare with ZS1 (the user's
first test build, ${SP}/deliver/gate1/ and ${SP}/deliver/RINT-B/): nothing may look worse than in ZS1. Fairness:
re-run tests/sim/modern_sight.gd -- --full and modern_path_check.gd -- --full and compare F1–F7 with the contract; a car
or a sign must never be visible later or smaller than in Arcade (taller tree models next to bends!). Performance:
perf_stats over a complete Kiel–Hamburg autopilot run per preset (low, medium, high) on llvmpipe next to ZS1's numbers,
spikes during chunk commits, memory over 20 minutes of driving (leaks), warm-up time and texture memory; say what real
hardware would need (inferred).` },
  { id: 'QA-M2-SYSTEM', prompt: `LENS: ARCADE IDENTITY, SOUND, MODELS PIPELINE, ROBUSTNESS. Arcade must be pixel- and sound-identical
to v0.7.0 (tools/golden.sh check; the Arcade ERGEBNIS of run_stage.gd against v0.7.0 = main on three stages); every
frozen file unchanged against main (git diff --stat main -- <frozen list of the contract>). Sound: the Modern profile in
race and menus – engine v3, the new road/tyre/wind/impact layers (Kiel–Hamburg: concrete slabs, the Köhlbrandbrücke
joints, Hamburg's cobbles alternating with asphalt), the Modern limiter (true peak ≤ −1 dBTP at master volume 1.0 in a
heavy crash), race tracks 1–3 rotating with stingers and interlude, ducking, race music on/off, UI sounds, no clicks at
loop seams, clean shutdown without "leaked at exit"; the Arcade sound unchanged; audio_qc.py all folders. Models
pipeline: export_models.py --check-keys clean, a second bake byte-identical, the manifest regenerated and consistent
with every model folder, the validator, check_sprite_geometry.py (sprites unchanged), sizes inside the budget
(tools/pck_report.py; the download about 280 MB at most). Tests: tools/run_tests.sh and run_render_checks.sh all green
on the head, and the tests changed by the merge (check_vehicles kasten/leistung, test_props, the Modern goldens) still
guard their rule – break one line per rule in a scratch copy and see the test fail. Robustness: --gfx-debug=fail and a
missing manifest fall back to Arcade with the right message; the Leistungstest (--bench=all) writes a valid
leistungstest.json; quitting and restarting in every screen; 20 minutes of Modern driving without errors in the log;
the Windows build under Wine starts Modern and Arcade.` },
]
phase('Prüfung')
const reviews = (await parallel(LENSES.map(l => () => agent(`${common(l.id, { mode: 'review', base: m2.commit }, 'render')}
YOUR ROLE: INDEPENDENT QA OF THE FIRST ASSEMBLY OF PUSH M2 (head ${m2.commit}, branch origin/wip/v080-m2int) – no
commits, no pushes. The assembly reports: ${INFO(m2)}; its report ${D('M2INT')}.
Do not trust the reports – run and look yourself. ${l.prompt}
Every finding needs where, what, evidence (command + output or picture path, measured or inferred), how to reproduce
and a concrete fix. Severity: blocker = must not go into the next test build; high = the user will notice at once;
medium = noticeable; low = polish. Also list what you checked and found fine. Pictures and the report (bericht.md)
into ${SP}/deliver/${l.id}/.`,
  { label: `prüfung:${l.id}`, phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })))).filter(Boolean)
const all = reviews.flatMap(r => r.findings)
const cnt = (s) => all.filter(f => f.severity === s).length
log(`Prüfung: ${cnt('blocker')} Blocker, ${cnt('high')} hoch, ${cnt('medium')} mittel, ${cnt('low')} niedrig`)

let fix = null
if (cnt('blocker') + cnt('high') + cnt('medium') > 0) {
  phase('Nacharbeit')
  fix = await agent(`${common('FIX-M2', { mode: 'fresh', base: m2.commit }, 'render')}
YOUR ROLE: FIXES AFTER THE QA OF THE FIRST M2 ASSEMBLY. Your base is M2INT's head ${m2.commit} (origin/wip/v080-m2int).
The assembly reports: ${INFO(m2)}; its report ${D('M2INT')}.
Independent QA found (verdicts and findings; reports ${D('QA-M2-BILD')} and ${D('QA-M2-SYSTEM')}):
${JSON.stringify(reviews.map(r => ({ verdict: r.verdict, findings: r.findings })))}
Reproduce each blocker, high and medium finding first (reject it with evidence if it is wrong), fix every confirmed
one, most-seen first, and the cheap low ones. Re-render the pictures the findings point to and LOOK at them. Then the
gates once more on your final head: import clean; tools/run_tests.sh green; tools/golden.sh check 20 von 20;
tools/run_render_checks.sh all; modern_sight --full and modern_path_check --full if a vehicle/prop placement or a model
size changed; the validator and export determinism if a model changed; audio_qc.py if a sound changed. Push every
commit to origin wip/v080-fix-m2. Report in ${SP}/deliver/FIX-M2/bericht.md. Return the result format with package
"FIX-M2": one acceptance entry per finding you handled (pass = fixed and re-checked, fail = still open, not_run =
rejected – say why), then the gates.`,
    { label: 'nacharbeit:FIX-M2', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
  if (fix) log(`FIX-M2: ${fix.commit ? fix.commit.slice(0, 7) : '?'} (${fix.acceptance.filter(a => a.result === 'fail').length} offen)`)
}
return { m2, reviews, fix }
