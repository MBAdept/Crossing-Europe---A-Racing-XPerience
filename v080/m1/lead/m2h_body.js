
// Acceptance of the Modern sound before it goes into M2: AU-R3 (the last trigger fault + the lead's measuring criteria)
// → two independent read-only checks with different lenses → AU-R4 only on blocker/high → focused re-check of AU-R4.
const AUC1 = '4209268f0bad80beb9abc2609d92a74cd7279db1'   // AU-C1 head: the sound the user heard and called „solide"
const AURH = '3d2e6e128d01e53e30ef5538bd58f42888827cc1'   // AU-R head
const AUR2 = '3600eb76c136d5c2c66537675c87511e3518b0ba'   // AU-R2 head = base of this round
const RF = `${SP}/deliver/KRITIK-FAHRBAHN/bericht.md`
const RR = `${SP}/deliver/KRITIK-R/bericht.md`
const BR = `${SP}/deliver/AU-R/bericht.md`
const BR2 = `${SP}/deliver/AU-R2/bericht.md`

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement, 5-10 sentences; nothing about how it sounds is measured – say inferred' },
    findings: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, severity: { type: 'string', enum: ['blocker', 'high', 'medium', 'low'] },
      area: { type: 'string' }, where: { type: 'string' }, problem: { type: 'string' },
      evidence: { type: 'string', description: 'command + output excerpt or file path; measured vs inferred' },
      repro: { type: 'string' }, fix: { type: 'string', description: 'concrete change: file, parameter, value' } },
      required: ['id', 'severity', 'area', 'where', 'problem', 'evidence', 'repro', 'fix'] } },
    checked_ok: { type: 'array', items: { type: 'string' }, description: 'what was checked and found fine (one line each), with numbers' },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'findings', 'checked_ok', 'media'],
}

const RECHECK = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'is the AU-R4 head fit to be merged? 3-6 sentences' },
    per_finding: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, status: { type: 'string', enum: ['fixed', 'partly', 'not_fixed', 'not_checked'] },
      evidence: { type: 'string' } }, required: ['id', 'status', 'evidence'] } },
    findings: FINDINGS.properties.findings,
    gates: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'per_finding', 'findings', 'gates'],
}

const EARLY = `PRIORITY RULE: other packages run on this machine at the same time (the QA and export of the user's first test
build, which the user expects tomorrow morning, and a model package); the test build is on the critical path. Run EVERY
heavy job (Godot runs, audio captures and renders, test suites, audio_qc --determinism, analyses over many files) with
nice -n 19 and one process; never two heavy jobs at once. tools/run_tests.sh (10–15 min) runs as a background command
with an explicit timeout of at least 3,600,000 ms; tools/golden.sh check (3–5 min) likewise with ≥ 1,200,000 ms.`

const STATE = `WHERE THE SOUND STANDS: the user listened to AU-C1's previews with headphones and wrote „die sounds scheinen solide,
auf kopfhörer getestet. auch die musik ist sehr gut". So the character stays and the music is not touched. Since then:
AU-R (${AURH}) fixed the measured faults of the road/tyre/wind/impact sounds (exact loop repetition, cobble hash,
slab phase, bridge joints per deck, a Modern-only limiter on MMaster, variety of crash layers, snow loop, no rumble at
fuel lanes); an independent re-measurement KRITIK-R (${RR}) found two high and five medium faults; AU-R2 (${AUR2})
fixed them (slab patterns rebuilt from AU-C1's eight joints, flatter slab law above 150 km/h, new seed for the right
cobble loop matched at its pitch, AudioServer lock only when a slab loop starts and every 0.5 s). Reports: AU-R ${BR},
AU-R2 ${BR2}, the first road review ${RF}. New previews of AU-R2 are with the user now (${SP}/deliver/AU-R/).`

const DECISIONS = `LEAD DECISIONS ON THE MEASURING CRITERIA (binding from now on; the lead writes them into the contract §11.2):
V1 R1 – no exact repetition: no envelope autocorrelation peak ≥ 0.40 at lags 0.3–3 s over 20 s at constant speed
   (asphalt 130 km/h 0.6–1.6 kHz, cobbles 50 km/h 2.5–8 kHz, concrete 130 km/h 2.5–8 kHz). On concrete it is judged
   WITHOUT the slab layer: the 5-m slab rhythm is wanted, it is part of the sound the user heard and liked. The slab
   level stays at audio.modern.road.slabs.db 3; lowering it is a later mix decision after the user has played the test
   build, not a fault.
V2 The concrete share of a country is held within ±0.05 of its configured share only for countries with ≥ 10 autobahn
   sections over all stages; smaller countries are reported, not judged.
V3 Limiter criteria are statistics. Heavy crash at 130 km/h closing speed: the 95th percentile of the limiter's gain
   reduction over 60 crashes ≤ 3 dB (car and truck) and every crash ≤ −1.0 dBTP at master volume 1.0. Cruising at
   130–200 km/h: the largest gain reduction per 60-s run ≤ 0.5 dB in each of at least four runs. The 0.05–0.14 dB that
   Godot's AudioEffectHardLimiter leaves standing after an intervention is not an intervention.
KEEP THE CHARACTER (unchanged): a changed layer keeps its third-octave spectrum within ±1 dB and its loudness within
±0.5 LU of AU-C1 at the reference speeds (130 km/h asphalt and concrete, 50 km/h cobbles). MUSIC: no change at all.`

const R3TASK = `THE TASK (small, precise – no other sound change in this round):
L2 of KRITIK-R (measured with its trigger log): since the hash fix the Venice causeway (a concrete-deck bridge inside the
old-town zone of Venice, stage Mailand – Venedig) is cobbled on 16 of 28 trigger rows and gets concrete joints every 32 m;
in reality it is asphalt. Fix in scripts/audio/modern/audio_feed.gd _paving(): old-town cobbles never on a bridge whose
deck is not "stone" – a concrete deck in a city gets the paving it had before AU-R (asphalt); steel stays "deck", stone
stays "cobbles"; the joints per deck stay as they are. Then:
- enumerate EVERY bridge with a non-stone deck inside an old-town centre over all stages and both driving directions
  (AU-R's hash/trigger scripts in ${SP}/m1/AU-R/ – hash_check4.gd, trigger_log2.gd, run_trig.sh – and KRITIK-R's
  kr_shares.gd / ana_shares.py / ana_trigger.py in ${SP}/m1/KRITIK-R/tools/; copy, do not edit them in place) and list
  each with its paving before → after;
- keep every old town's cobble share within 0.6 ± 0.05 of its streets: if a centre loses cobbled blocks to such a
  bridge, take the bridge blocks out of the allocation base of AudioFeed.cobbled_blocks when that is cheap and robust
  (deterministic, identical in both driving directions); otherwise report the centres that fall below 0.55 with their
  numbers (in Venice the road ends at Piazzale Roma right behind the causeway, so a lower share there is acceptable
  when documented);
- a unit test (tests/unit/audio_modern/test_audio_feed.gd): a city plan with a concrete-deck bridge in its centre gets
  no cobbles on the bridge and its share on the streets; make sure it FAILS on today's code before you fix it;
- the Kiel – Hamburg trigger log must not change; if it does, re-record the two drive previews in ${SP}/deliver/AU-R/
  with AU-R2's scripts (${SP}/m1/AU-R2/, ${SP}/m1/AU-R/drive_ab.gd, build_deliver.py) and update their .txt; otherwise
  leave every preview untouched.
DOCS: docs/audio-modern.md – the acceptance criteria of the Modern sound per V1–V3 where the targets are listed, the
deck rule above, and a short line „Stand nach AU-R3". config _doc entries if a key's meaning changes (none should).
GATES: the feed tests via the filter of tools/run_tests.sh while iterating; at the end tools/run_tests.sh once,
tools/golden.sh check once (20 von 20 identisch), check_arcade_lean OK, git diff v0.7.0..HEAD over the frozen Arcade
paths empty; no sound file changes (so no audio_qc needed – prove with git diff --stat ${AUR2}..HEAD).
DELIVER: ${SP}/deliver/AU-R3/bericht.md (German, short): the bridge table before → after, the shares, the gates.`

const R3 = `${common('AU-R3', { mode: 'fresh', base: AUR2 }, 'content')}
${EARLY}
YOUR ROLE: AU-R3 – the last small fix of the Modern sound before the acceptance checks. Your base is AU-R2's head
${AUR2} (origin/wip/v080-au-r2). You own the files of AU-C1/AU-R (scripts/audio/modern/*.gd, tools/audio/modern/**,
assets/audio/modern/{vehicle,sfx}/**, config/game_config.json → audio.modern, their tests, docs/audio-modern.md) – in
this round you change only audio_feed.gd, its test and the docs. Never the engine v3 sound, the music, the UI sounds or
the frozen Arcade audio.
${STATE}
${DECISIONS}
${R3TASK}
Push every commit to origin wip/v080-au-r3. Return the result format with package "AU-R3".`

const COPIES = (head) => `WORK ON COPIES, never in a worktree of another package: for each head you need,
  mkdir -p <dir> && git -C ${REPO} archive <commit> | tar -x -C <dir>   then  cp -a ${REPO}/.godot <dir>/  and import
  once (nice -n 19 godot --headless --path <dir> --import). Heads: the object ${head}, AU-C1 ${AUC1} (the sound the
  user heard), AU-R ${AURH} where a before/after needs it. Absolute XDG_DATA_HOME under your scratch dir for every
  run. Delete the copies when you are done (disk space is limited).`

const MESS = (r3) => `${common('KRITIK-R2-MESS', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT ACCEPTANCE MEASUREMENT of the final Modern sound head – lens MEASUREMENT. A second reviewer looks
at the code, the triggering and regressions at the same time; do not duplicate that. No commits, no pushes.
THE OBJECT: AU-R3's head ${r3.commit} (origin/wip/v080-au-r3) = AU-C1 + AU-R + AU-R2 + AU-R3. AU-R3's report:
${SP}/deliver/AU-R3/bericht.md.
${COPIES(r3.commit)}
${STATE}
${DECISIONS}
TOOLS: the scripts of the last re-measurement, ${SP}/m1/KRITIK-R/tools/, and AU-R2's copies with its additions,
${SP}/m1/AU-R2/ktools/ (kr_capture.gd with plans A = as played and B = without drift, gusts and pass-bys,
kr_crash.gd, kr_perf_conc.gd, kr_seam.gd, kr_slab.gd, kr_worst.gd, ana_cap.py, ana_compare.py, ana_crash.py,
crash_p95.py, ana_peaks.py, ana_seam.py, dsp.py). Copy them and re-run them so the numbers compare 1:1 – but never
take a number from a report: measure it yourself. Where randomness enters (crashes, drift), use NEW seeds (not 777/778).
YOU CANNOT HEAR. Numbers are measured; how it sounds to a person is inferred – say so.
CHECK, ranked by what the player hears most (the motorway at 100–200 km/h first):
1 KEEP THE CHARACTER against AU-C1, deterministic (plan B): spectra and loudness of the road layers and game mixes at
  130 km/h asphalt and concrete and 50 km/h cobbles; the slab layer in the game at 110, 130, 150, 170 and 200 km/h (AU-R2
  rebuilt the patterns from AU-C1's eight joints and flattened the slab law above 150 km/h – is the level continuous at
  150 km/h, about −0.9 dB at 170 and −2 dB at 200 against AU-R, as documented?); the right cobble loop (new seed,
  matched at its pitch): loudest stones per channel against AU-C1, crest factor, true peak of the layer.
2 R1 under V1: asphalt 130, cobbles 50, concrete 130 without the slab layer – no peak ≥ 0.40 at 0.3–3 s; report the peaks
  up to 8 s, and concrete with slabs for the record.
3 V3: 60 car and 60 truck heavy crashes at 130 km/h closing with your own seeds (median, p95, max gain reduction; max
  true peak at master volume 1.0); 200 km/h on concrete in four 60-s runs; top speed with road and wind; AU-C1's
  worst-case stack (true peak only).
4 Seams and artefacts in the game: every Ogg loop and both slab WAVs play sample-exact (no click at a seam or when a slab
  pattern starts or is realigned); no new tonal line; no zipper noise from the per-side drift; no pumping while cruising.
5 CPU: road and impact script time per frame on concrete and asphalt against AU-C1 (interleaved runs under the same
  load), AudioServer locks in the steady state.
6 THE PREVIEWS THE USER IS LISTENING TO NOW (${SP}/deliver/AU-R/*.mp3 with their .txt): do the timestamps in the .txt
  match what is audible in the file (onset of concrete; the four joints on the Köhlbrandbrücke at 0:14.7 / 17.6 / 20.4 /
  22.2 in the bridge A/B; Hamburg in fahrt_kiel_hamburg_vorher_nachher: asphalt 1:23.7, cobbles 1:25.8, asphalt 1:32.0)?
  Is the „nachher" half really the sound of the current head (re-capture a 10-s excerpt on ${r3.commit} and compare)?
SEVERITY: blocker = a gate missed, a true peak above −1.0 dBTP, or a click or regression the player hears; high = a V1/V3
target or a character limit missed, or a preview that misleads the user; medium/low = the rest.
DELIVER ${SP}/deliver/KRITIK-R2-MESS/bericht.md (German): a table per check (AU-C1 → final head, with AU-R where it
helps) and the ranked findings; nothing else.`

const CODE = (r3) => `${common('KRITIK-R2-CODE', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT ACCEPTANCE REVIEW of the final Modern sound head – lens CODE, TRIGGERING AND REGRESSIONS. A second
reviewer measures levels and spectra at the same time; do not duplicate that. No commits, no pushes.
THE OBJECT: AU-R3's head ${r3.commit} (origin/wip/v080-au-r3). The change to review is ${AUC1}..${r3.commit} over
scripts/audio/**, tools/audio/**, config/game_config.json (audio.*), tests/unit/audio_modern/**, docs/audio-modern.md
(intermediate heads: AU-R ${AURH}, AU-R2 ${AUR2}). AU-R3's report: ${SP}/deliver/AU-R3/bericht.md.
${COPIES(r3.commit)}
${STATE}
${DECISIONS}
CHECK:
1 Code review of the change for correctness bugs: road_audio.gd (per-side loop pairs, random start offsets, OU drift,
  slab alignment with the lock only at start and every 0.5 s, the slab law above 150 km/h, the snow layer, squeal per
  event, pass-bys), audio_feed.gd (fmix32 unit_hash, cobbled_blocks, concrete_threshold_for, section_key, joints per
  deck, fuel lane, AU-R3's deck rule), impact_audio.gd (variants, jitter, glass rule), modern_buses.gd (the MMaster
  limiter only in Modern; Arcade's buses untouched). Look for: state not reset between races, stages or a restart;
  players that leak or keep playing (pause menu, end of race, results screen, switching Arcade ↔ Modern in the options);
  NaN or division by zero at 0 km/h or in reverse; randomness that changes the deterministic race result (ERGEBNIS) or a
  replay; frame-rate dependence (30, 40 – the Steam Deck –, 60, 90 fps); the AudioServer lock while the game is paused;
  the first frame after a teleport (restart, refuel cut); identical decisions in both driving directions.
2 Triggering over ALL stages in both directions (AU-R's and KRITIK-R's trigger and hash scripts in ${SP}/m1/AU-R/ and
  ${SP}/m1/KRITIK-R/tools/): cobbles only in old towns and on stone bridges, never on concrete or steel bridges (AU-R3);
  old-town shares 0.6 ± 0.05; concrete shares per country under V2; joints per deck (steel: ends + about every 100 m;
  concrete: 32 m; stone: none) on every bridge and none off a bridge; no rumble at fuel lanes; the tunnel wind; rain and
  snow switch their layers.
3 Regressions: Arcade identity (git diff v0.7.0..${r3.commit} over the frozen Arcade paths empty; tools/golden.sh check
  20 von 20; Arcade plays nothing of Modern – check_arcade_lean); engine v3 and music files byte-identical to AU-C1;
  mischung.json values unchanged; ERGEBNIS identical between Arcade and Modern on two stages; tools/run_tests.sh once;
  audio_qc.py --determinism for vehicle_loops.py and sfx_modern.py (the generators reproduce the committed files
  bit-identically); the sound budget (≤ 23 MB) and the size of the export.
4 The tests themselves: does each new unit test of AU-R/AU-R2/AU-R3 guard its rule? In a scratch copy, break one line per
  guarded rule and run the test – it must fail.
5 Docs: docs/audio-modern.md and the config _doc entries match the code (keys, defaults, units, V1–V3).
SEVERITY: blocker = a gate missed, or a bug the player hears or one that breaks Arcade or the race result; high = a wrong
trigger in a place the player passes, a leak, a frame-rate dependence, or a test that does not guard its rule;
medium/low = the rest.
DELIVER ${SP}/deliver/KRITIK-R2-CODE/bericht.md (German): the ranked findings with repro, then what was checked.`

const FIX = (r3, found) => `${common('AU-R4', { mode: 'fresh', base: r3.commit }, 'content')}
${EARLY}
YOUR ROLE: AU-R4 – fix round after the acceptance checks of the Modern sound. Your base is AU-R3's head ${r3.commit}
(origin/wip/v080-au-r3). Two independent reviews (${SP}/deliver/KRITIK-R2-MESS/bericht.md – measurement;
${SP}/deliver/KRITIK-R2-CODE/bericht.md – code, triggering, regressions; their scripts in ${SP}/m1/KRITIK-R2-MESS/ and
${SP}/m1/KRITIK-R2-CODE/) found the findings below. Fix every blocker and high finding, medium ones where cheap and
safe; re-run each fixed finding's repro with the reviewer's method and report before → after. Your files are those of
AU-R3 (scripts/audio/modern/*.gd, tools/audio/modern/**, assets/audio/modern/{vehicle,sfx}/**, config → audio.modern,
their tests, docs/audio-modern.md); never the engine v3 sound, the music, the UI sounds or the frozen Arcade audio.
${STATE}
${DECISIONS}
Previews: update ${SP}/deliver/AU-R/ (MP3 and .txt) only if what a preview shows changes, and say which in your report.
GATES: tools/run_tests.sh once at the end, tools/golden.sh check once (20 von 20 identisch), check_arcade_lean OK, the
frozen Arcade paths unchanged against v0.7.0, audio_qc.py --determinism if a sound file or generator changed.
DELIVER ${SP}/deliver/AU-R4/bericht.md (German, short). Push every commit to origin wip/v080-au-r4. Return the result
format with package "AU-R4".
FINDINGS (JSON): ${JSON.stringify(found)}`

const NACH = (r3, fix, found) => `${common('KRITIK-R3', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: FOCUSED RE-CHECK of the fix round AU-R4 only – read-only, no commits.
THE OBJECT: AU-R4's head ${fix.commit} (origin/wip/v080-au-r4), base AU-R3 ${r3.commit}; its report
${SP}/deliver/AU-R4/bericht.md. The two acceptance reports: ${SP}/deliver/KRITIK-R2-MESS/bericht.md and
${SP}/deliver/KRITIK-R2-CODE/bericht.md (scripts in ${SP}/m1/KRITIK-R2-MESS/ and ${SP}/m1/KRITIK-R2-CODE/).
${COPIES(fix.commit)}
${DECISIONS}
CHECK: (1) for every finding below re-run the reviewer's repro on ${fix.commit} and say fixed / partly / not fixed with
numbers; (2) review the diff ${r3.commit}..${fix.commit} for new bugs; (3) gates on ${fix.commit}: tools/run_tests.sh once,
tools/golden.sh check once, check_arcade_lean, frozen Arcade paths unchanged against v0.7.0, engine and music files
byte-identical to AU-C1 ${AUC1}. Nothing else.
DELIVER ${SP}/deliver/KRITIK-R3/bericht.md (German, short).
FINDINGS THAT WERE TO BE FIXED (JSON): ${JSON.stringify(found)}`

phase('Nachbesserung')
const r3 = await agent(R3, { label: 'klang:AU-R3', phase: 'Nachbesserung', schema: BUILD_C, isolation: 'worktree' })
if (!r3 || !r3.commit) { log('AU-R3 fehlt'); return { r3 } }
log(`AU-R3: ${r3.commit.slice(0, 7)} (${r3.acceptance.filter(a => a.result !== 'pass').length} offen)`)

phase('Abnahme')
const [mess, code] = await parallel([
  () => agent(MESS(r3), { label: 'abnahme:Messung', phase: 'Abnahme', schema: FINDINGS }),
  () => agent(CODE(r3), { label: 'abnahme:Code', phase: 'Abnahme', schema: FINDINGS }),
])
const tag = (src, r) => (r ? r.findings.map(f => ({ ...f, source: src })) : [])
const all = [...tag('MESS', mess), ...tag('CODE', code)]
const hard = all.filter(f => ['blocker', 'high'].includes(f.severity))
log(`Abnahme: Messung ${mess ? mess.findings.length : 'ausgefallen'}, Code ${code ? code.findings.length : 'ausgefallen'} Befunde (${hard.length} hoch)`)

let fix = null
let nach = null
if (hard.length) {
  const found = all.filter(f => f.severity !== 'low')
  phase('Nacharbeit')
  fix = await agent(FIX(r3, found), { label: 'klang:AU-R4', phase: 'Nacharbeit', schema: BUILD_C, isolation: 'worktree' })
  log(fix ? `AU-R4: ${fix.commit ? fix.commit.slice(0, 7) : '?'} (${fix.acceptance.filter(a => a.result !== 'pass').length} offen)` : 'AU-R4 fehlt')
  if (fix && fix.commit) {
    phase('Nachprüfung')
    nach = await agent(NACH(r3, fix, found), { label: 'kritik:AU-R4', phase: 'Nachprüfung', schema: RECHECK })
  }
}
return { r3, mess, code, fix, nach }
