
// ZS1 water fix: FIX-WASSER lowers the far ground below the loaded water (Köhlbrandbrücke shows meadow instead of the
// Elbe, ships on the meadow), rebuilds the test build + smoke tests + gates → QA-WASSER checks the delivered archives
// independently → FIX-WASSER-R on blocker/high/medium → NACH-WASSER re-check if the fix round changed the game.
// ARGS: { base: '<head of the corrected first test build>', docs: '<folder with the current user documents>' }
const A = args || {}
const BASE = A.base
const DOCS = A.docs || `${SP}/deliver/FIX-ZS1`
const D = (p) => `${SP}/deliver/${p}/bericht.md`

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement, 5-10 sentences: may this build go to the user?' },
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
    verdict: { type: 'string', description: 'may the delivered build go to the user now? 3-6 sentences' },
    per_finding: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, status: { type: 'string', enum: ['fixed', 'partly', 'not_fixed', 'not_checked'] },
      evidence: { type: 'string' } }, required: ['id', 'status', 'evidence'] } },
    findings: FINDINGS.properties.findings,
    gates: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'per_finding', 'findings', 'gates'],
}

const URGENT = `CRITICAL PATH: the user expects the first test build (Zwischenstand 1, Steam Deck and Windows) this morning
(German time); this fix decides whether it goes out with the Elbe under the Köhlbrandbrücke. Work straight and
measured, no detours, no improvements beyond your brief; look at the clock (date -u) now and then and keep STAND.md
current. Until about 06:45 UTC an independent check of the same test build runs beside you: heavy jobs with nice -n 10,
one Godot/test run at a time; afterwards nice -n 5 (a model-assembly package runs with nice 19 the whole time).
tools/run_tests.sh takes 13–15 min, tools/run_render_checks.sh all about 26 min, tools/golden.sh check about 6 min,
modern-make 12 min and modern-check 14 min – run them as background commands with a timeout of at least 3,600,000 ms and
poll their logs.`

const INFO = (r) => JSON.stringify({ branch: r.branch, commit: r.commit, summary: r.summary,
  open: (r.acceptance || []).filter(a => a.result !== 'pass'), deviations: r.deviations, notes: r.notes_for_next,
  verdict: r.look_verdict || r.quality_verdict })

const BUILD_STEPS = (pkg, outDir) => `THE TEST BUILD from your final, clean, pushed commit (read the usage at the top of
tools/build_testbuild.sh first; it sets version, user folder and the Windows file version only for the export and
restores them): OUT=${SP}/m1/${pkg}/testbuild tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand
Copy both archives, LIZENZEN.txt, SHA256SUMS and BUILDINFO.txt into ${outDir} (sha256sum -c --ignore-missing there
must pass). The builds in ${SP}/deliver/gate1/build/ and ${SP}/deliver/FIX-ZS1/build/ stay untouched – the lead swaps
after the review. Smoke tests with tools/smoke_modern.sh on the Linux export (once plain, once with
DRIVER=opengl3_es) and on the Windows export under Wine (wine64, own WINEPREFIX, TMPDIR unset, paths as Z:<abs path>,
wineserver -w between runs); the first start like a player with ${SP}/m1/FIX-ZS1/chooser_walk.sh (copy it into your
scratch and adapt its paths); and with the EXPORTED Linux build and the EXPORTED Windows build under Wine: the standing
start of Kiel – Hamburg in Modern (countdown and 1.5 s after "LOS!", the car at Arcade's place) and the Köhlbrandbrücke
(km 78.6, flying start) with the Elbe under it – pictures into your report. FIX-ZS1's scripts in ${SP}/m1/FIX-ZS1/
(export_start.sh, smokes.sh, triptych.sh, ab_queue1.sh, gates.sh) show how it did all of this; copy and adapt them.`

const ROLE_FIX = `YOUR ROLE: FIX-WASSER – THE WATER UNDER THE BRIDGES OF THE FIRST TEST BUILD.
${URGENT}
Your base is ${BASE} (origin/wip/v080-fix-zs1): the corrected first test build (the start of every stage was fixed
there; report ${D('FIX-ZS1')}, pictures ${SP}/deliver/FIX-ZS1/bilder/boote_*.jpg). For this fix YOU OWN:
scripts/race3d/layers/far_ground.gd, the terrain/water code the fix needs (scripts/race3d/terrain_profile.gd,
builders/terrain.gd, ground_look.gd), the tests you add, tests/golden/modern_slice.*, docs/renderer-modern*.md and
docs/qa-v080.md. The frozen Arcade files stay untouched (rule 1).

THE FAULT (FIX-ZS1, measured): under the Köhlbrandbrücke (Kiel – Hamburg km 77.5–80) Modern shows meadow where Arcade
shows the Elbe, and the two ferries (km 78.95 and 79.14, props with "h": −depth from scripts/race/track.gd lines
834–844) stand on that meadow. Cause: the far-ground plane of layers/far_ground.gd lies at "lowest road of the loaded
window − far_ground_drop_m (4 m)"; the water rows of the terrain (terrain_profile.gd: hh = water_h, water_level ≤ 0)
lie 9 m under the road there, so the opaque plane covers them. At the Elbbrücken (km 84.6) the water is right. Every
high bridge over deep water on every stage is affected the same way – find them all from the data (bridges with water
deeper than the drop) and list them.
FIX it at the root: the plane must lie below the lowest water surface of the loaded window as well (for example: the
lowest of road − drop and water surface − a small margin, sampled like lowest_road(); keep FOLLOW_SLOPE/snap behaviour
sane so the plane does not visibly jump when a bridge comes into the window). The plane only moves DOWN, so it still
hides nothing (rule F7); check that the gaps it closes (12 m at a medial axis, the hole of a tight bend, beyond the
outer ring) still look like distant land and not like a pit – especially next to the bridges and at night. If the
far ground beyond the outer ring then shows meadow colour right next to a wide river, say so with a picture (do not
start a far-water feature; list it).
Acceptance: (a) Köhlbrandbrücke km 77.5–80 by day (12 h) and at night (22 h), --gfx-preset=high and the Steam Deck
preset (deck): the Elbe under and beside the bridge like Arcade (colour, extent), the two ferries float on the water at
a sensible height (look at them from the deck and from the bridge ramp) – A/B with tools/ab_shot.sh, LOOK at every
picture; (b) the Elbbrücken km 84.6 unchanged in look; (c) at least three more bridges over deep water on other stages
(pick from your list: e.g. a Rhine, Danube or Elbe crossing and one coastal or lagoon causeway) A/B by day; (d) away
from water nothing changes: tools/golden.sh modern-make may change ONLY the pictures that see deep water (expected
modern_s4_mittel at km 80 at most – show old and new MD5 lists and look at every changed picture), modern-check green;
(e) tools/run_render_checks.sh all green, including the terrain cover check and the new start check; (f) a unit test
for the plane height with water in the window that fails on ${BASE}.

${BUILD_STEPS('FIX-WASSER', `${SP}/deliver/FIX-WASSER/build/`)}
THE USER DOCUMENTS: copy ${DOCS}/was_neu.md and ${DOCS}/steamdeck_checkliste.md to ${SP}/deliver/FIX-WASSER/ and
change only what your fix makes untrue (the sentence about meadow under the Köhlbrandbrücke and the ships on it goes
when the fix is verified in the exported build); plain German, no internal labels or package names.
GATES on the final head (commands and output in bericht.md): import clean; tests/check_scripts.gd; tools/run_tests.sh
green (once at the end; filter argument while iterating) incl. the fairness checks; tools/golden.sh check (20 von 20
and 17 von 17 identisch); tools/golden.sh modern-make + modern-check (incl. OpenGL ES); tools/run_render_checks.sh all.
If time runs short: (1) the water fixed and seen in the exported builds, (2) the gates, (3) the documents. Push every
commit to origin wip/v080-fix-wasser. Report ${D('FIX-WASSER')} with before/after pictures (Arcade | Modern before |
Modern after). Return the result format with package "FIX-WASSER": one acceptance entry per item (a)–(f), the build,
each smoke test and each gate.`

phase('Korrektur')
const fix = await agent(`${common('FIX-WASSER', { mode: 'fresh', base: BASE }, 'render')}
${ROLE_FIX}`, { label: 'korrektur:FIX-WASSER', phase: 'Korrektur', schema: BUILD_R, isolation: 'worktree' })
if (!fix || !fix.commit) { log('FIX-WASSER fehlt'); return { fix } }
log(`FIX-WASSER: ${fix.commit.slice(0, 7)} (${fix.acceptance.filter(a => a.result === 'fail').length} offen)`)

phase('Prüfung')
const qa = await agent(`${common('QA-WASSER', { mode: 'review', base: fix.commit }, 'render')}
YOUR ROLE: QA-WASSER – INDEPENDENT CHECK OF THE REBUILT FIRST TEST BUILD (water under the bridges) before it goes to
the user this morning. No commits, no pushes; nice -n 5, one Godot run at a time. The fix reports: ${INFO(fix)}; its
report ${D('FIX-WASSER')}; the start fix before it ${D('FIX-ZS1')} and its independent check ${D('QA-ZS1')} (if present).
Do not trust the reports – run and look yourself:
1. THE DELIVERED FILES exactly as the user gets them: ${SP}/deliver/FIX-WASSER/build/. Copy them into your scratch,
   sha256sum -c --ignore-missing, unpack, check contents (the program + LIZENZEN.txt), sizes and BUILDINFO (commit
   ${fix.commit}? version 0.8.0-zs1? user folder crossing-europe-zwischenstand?).
2. The Linux export under Xvfb with a fresh XDG_DATA_HOME, Modern next to Arcade at the same moments: the Köhlbrandbrücke
   (Kiel – Hamburg km 77.5–80) by day and at night, with --gfx-preset=high and deck – the Elbe under and beside the
   bridge, the ferries on the water, no pit, no seam, no jumping ground when the bridge comes into view (take a short
   sequence of frames while approaching from km 76.5); the Elbbrücken km 84.6; two more deep-water bridges of other
   stages from FIX-WASSER's list; the standing start of Kiel – Hamburg at km 0 (the car visible in the countdown at
   Arcade's place – the earlier fix must still hold); one mountain stretch with tight bends (the gaps the far ground
   closes must still read as land).
3. The Windows export under Wine (own WINEPREFIX, TMPDIR unset, Z:<abs path>): the Köhlbrandbrücke in Modern and the
   start at km 0.
4. The code: git diff ${BASE}..${fix.commit} – only the intended files, no frozen Arcade file (rule 1); can the lower
   plane hide or show anything the player reacts to (rule F7, fairness)? Is the new unit test a real guard (break the
   fix in a scratch copy: does it fail)? Run tools/golden.sh check once (20 von 20 and 17 von 17) and
   tools/run_render_checks.sh modern terrain_cover (or the file name the terrain cover check has).
5. The two user documents in ${SP}/deliver/FIX-WASSER/ (was_neu.md, steamdeck_checkliste.md): true for this build,
   plain German, no internal labels.
Every finding needs where, what, evidence (command + output or picture path; measured or inferred), how to reproduce
and a concrete fix. Severity: blocker = must not go to the user; high = the user notices at once; medium = noticeable;
low = polish. Also list what you checked and found fine. Pictures and bericht.md into ${SP}/deliver/QA-WASSER/.`,
  { label: 'prüfung:QA-WASSER', phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })
const found = qa ? qa.findings : []
const cnt = (s) => found.filter(f => f.severity === s).length
log(`QA-WASSER: ${cnt('blocker')} Blocker, ${cnt('high')} hoch, ${cnt('medium')} mittel, ${cnt('low')} niedrig`)

let fixr = null
let nach = null
if (cnt('blocker') + cnt('high') + cnt('medium') > 0) {
  phase('Nacharbeit')
  fixr = await agent(`${common('FIX-WASSER-R', { mode: 'fresh', base: fix.commit }, 'render')}
YOUR ROLE: FIX-WASSER-R – FIXES AFTER THE INDEPENDENT CHECK OF THE REBUILT FIRST TEST BUILD.
${URGENT}
Your base is FIX-WASSER's head ${fix.commit} (origin/wip/v080-fix-wasser). FIX-WASSER reports: ${INFO(fix)}; its report
${D('FIX-WASSER')}. The independent check QA-WASSER found (report ${D('QA-WASSER')}):
${JSON.stringify({ verdict: qa.verdict, findings: qa.findings })}
Reproduce each blocker, high and medium finding first (reject it with evidence if it is wrong), fix every confirmed
one, then the cheap low ones. Documents: fix them in ${SP}/deliver/FIX-WASSER/. If the game changed (anything outside
docs/ and tests/): ${BUILD_STEPS('FIX-WASSER-R', `${SP}/deliver/FIX-WASSER/build/ (REPLACE the files there; keep the replaced ones in ${SP}/m1/FIX-WASSER-R/alt/ until the new ones passed)`)}
Gates again on the final head: tests/check_scripts.gd; tools/run_tests.sh; tools/golden.sh check;
tools/golden.sh modern-check (modern-make only where a Modern picture changed on purpose); tools/run_render_checks.sh
all. Push every commit to origin wip/v080-fix-wasser-r. Report ${D('FIX-WASSER-R')}. Return the result format with
package "FIX-WASSER-R": one acceptance entry per finding (pass = fixed and re-checked, fail = still open, not_run =
rejected – say why), then the build, the smoke tests and the gates.`,
    { label: 'nacharbeit:FIX-WASSER-R', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
  const game = fixr && fixr.commit && (fixr.files_changed || []).some(f => !/^(\/|docs\/|tests\/|ARCHITECTURE|README|deliver|\(|Bericht|bericht)/.test(f))
  if (fixr) log(`FIX-WASSER-R: ${fixr.commit ? fixr.commit.slice(0, 7) : '?'} (${fixr.acceptance.filter(a => a.result === 'fail').length} offen, Spiel geändert: ${game ? 'ja' : 'nein'})`)
  if (game) {
    phase('Nachprüfung')
    nach = await agent(`${common('NACH-WASSER', { mode: 'review', base: fixr.commit }, 'render')}
YOUR ROLE: NACH-WASSER – FOCUSED RE-CHECK of the fix round FIX-WASSER-R only (head ${fixr.commit}), before the build goes
to the user this morning. No commits, no pushes; nice -n 5, one Godot run at a time. The findings of the independent
check: ${JSON.stringify(qa.findings.filter(f => f.severity !== 'low'))}
FIX-WASSER-R reports: ${INFO(fixr)}; its report ${D('FIX-WASSER-R')}.
Check each finding against the DELIVERED build in ${SP}/deliver/FIX-WASSER/build/ (sha256sum -c --ignore-missing;
BUILDINFO names ${fixr.commit}?) – run the exported Linux build under Xvfb and the Windows build under Wine (own
WINEPREFIX, TMPDIR unset): the Köhlbrandbrücke and the start at km 0 in Modern next to Arcade, and whatever the findings
concern; git diff ${fix.commit}..${fixr.commit} for side effects and frozen Arcade files; tools/golden.sh check once;
the documents in ${SP}/deliver/FIX-WASSER/. Return per finding fixed / partly / not_fixed / not_checked with evidence,
any new finding, and the gates you ran with their output. Pictures and bericht.md into ${SP}/deliver/NACH-WASSER/.`,
      { label: 'nachprüfung:NACH-WASSER', phase: 'Nachprüfung', schema: RECHECK, isolation: 'worktree' })
  }
}
return { fix, qa, fixr, nach }
