
// ZS1 start fix: FIX-ZS1 fixes QA1-B1 (start at km 0) and QA1-B3 (start-gate lamp rims) on QA1's head, checks boats on
// dry ground, rebuilds the test build + smoke tests → QA-ZS1 checks the delivered archives independently → FIX-ZS1R on
// blocker/high/medium → NACH-ZS1 re-check if the fix round changed the game.
// ARGS: { base: '<QA1 final head>', build: '<commit the current test build was exported from>' }
const A = args || {}
const BASE = A.base
const BUILD = A.build || BASE
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

const URGENT = `CRITICAL PATH: the user expects this first test build (Zwischenstand 1, Steam Deck and Windows) this morning
(German time). Work straight and measured, no detours, no improvements beyond your brief. Look at the clock (date -u)
now and then and say in STAND.md where you are. You are the priority job on this machine: heavy jobs with nice -n 5,
one Godot/test run at a time (a sound-measurement package may run beside you with nice 19). tools/run_tests.sh takes
13–15 min, tools/run_render_checks.sh all about 30 min, tools/golden.sh check about 7 min, modern-make 12 min and
modern-check 14 min – run them as background commands with a timeout of at least 3,600,000 ms and poll their logs.`

const INFO = (r) => JSON.stringify({ branch: r.branch, commit: r.commit, summary: r.summary,
  open: (r.acceptance || []).filter(a => a.result !== 'pass'), deviations: r.deviations, notes: r.notes_for_next,
  verdict: r.look_verdict || r.quality_verdict })

const BUILD_STEPS = (pkg, outDir) => `THE TEST BUILD from your final, clean, pushed commit (read the usage at the top of
tools/build_testbuild.sh first; it sets version, user folder and the Windows file version only for the export and
restores them): OUT=${SP}/m1/${pkg}/testbuild tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand
Copy both archives, LIZENZEN.txt, SHA256SUMS and BUILDINFO.txt into ${outDir} (sha256sum -c there must pass). The old
build in ${SP}/deliver/gate1/build/ stays untouched – the lead swaps after the review. Smoke tests with
tools/smoke_modern.sh on the Linux export (once plain, once with DRIVER=opengl3_es) and on the Windows export under
Wine (wine64, own WINEPREFIX, TMPDIR unset, paths as Z:<abs path>, wineserver -w between runs); the first start like a
player with QA1's ${SP}/m1/QA1/chooser_walk.sh (copy it into your scratch and adapt its paths); and, with the EXPORTED
Linux build and the EXPORTED Windows build under Wine, pictures of the standing start of Kiel – Hamburg in Modern in
the countdown and 1.5 s after "LOS!" that show the car at Arcade's place (put them into your report).`

const ROLE_FIX = `YOUR ROLE: FIX-ZS1 – FIX THE FIRST TEST BUILD BEFORE IT GOES TO THE USER.
${URGENT}
Your base is QA1's final head ${BASE} (origin/wip/v080-qa1); the current test build was exported from ${BUILD}. Read
QA1's report ${D('QA1')} (= ${SP}/deliver/gate1/bericht.md) §1, §4 and §6 and docs/qa-v080.md first.
For this fix YOU OWN: scripts/race3d/road_path.gd, scripts/race3d/layers/vehicles.gd, scripts/race3d/builders/*.gd,
the terrain/chunk code the fix needs, the tests you add, the lists of tools/golden.sh, tools/run_render_checks.sh,
docs/qa-v080.md and docs/renderer-modern.md. The frozen Arcade files stay untouched (rule 1).

FIX 1 – QA1-B1 (high): at the start of EVERY stage (km 0, standing start with countdown) the Modern camera stands 9 m
too far ahead. The car stands at pos_z = 0, the camera at pos_z − render.camera_distance_m = −9 m, but RoadPath3D
only knows z ≥ 0 (first ≥ 0; _locate() clamps _lt to 0…1; world()/frame_at() return the point at z = 0), and
layers/vehicles.gd::_update_car hides a car with z < z_lo (rear before the first path point: z = pos_z − length/2 =
−2.4 m). So the player car is missing in the countdown and appears too big and too low after "LOS!" until it has
driven 9 m; the start gate looks nearer than in Arcade and the sign "Tankstelle 15 km" on the right is out of the
picture. Evidence: ${SP}/deliver/QA1/befund_start_km0_*.jpg, ${SP}/m1/QA1/diag/,
${SP}/deliver/gate1/rauchtest/linux_modern_start_km0_ohne_auto.png, ${SP}/deliver/gate1/ab_boegen/S0_*.
Fix it at the root so that the start looks like Arcade's. QA1's proposal: continue the path before point 0 straight
along the tangent at z = 0 (only while the kept window starts at the track start, first == 0), build road, markings,
verges, guard rails and ground of the first chunk from about z = −15 m (or as far back as the camera sees – no void and
no seam at the bottom or the sides of the picture), and show cars whose body begins before z_lo. Prefer the smallest
change that is right. Nothing may change for z ≥ 0 (fairness proofs, every picture at km > 0). Check everything that
reads the path before z = 0 (traffic behind the player at the start, police, the sight checks, the start gate,
rebasing, chunk building) and keep it consistent.
Acceptance: (a) at km 0 the player car stands where Arcade draws it – same screen position and size within a few per
cent – compared with tools/ab_shot.sh at the same simulation state 1 s and 3 s into the countdown and 0.7 s, 1.5 s and
4 s after the start; the camera glides on without a jump; start gate and the sign "Tankstelle 15 km" where Arcade has
them; (b) the same at three more stage starts of different kinds – one that begins in a bend or on a slope, one that
starts in a city, one at night – pick them from the data and say which; (c) Modern pictures at km > 0 unchanged:
tools/golden.sh modern-make may change ONLY modern_start_mittel (show the old and new MD5 lists); (d) a new render check
"Start bei km 0" in tests/race3d/render/ that FAILS on ${BASE} (run it there once to prove it) and passes now, wired
into tools/run_render_checks.sh, plus unit tests for the path before z = 0 and for a car whose rear is before z_lo.
LOOK at every picture against Arcade.

FIX 2 – QA1-B3 (medium): builders/gantry.gd creates the three rims of the countdown lamps (from about line 187)
without cast_shadow, so they cast shadows with "Schatten: Aus" and check_light_base "schatten" fails. Set them like the
other parts of the gate, and look for other MeshInstance3D in scripts/race3d/builders/ that ignore shadow_casters.
tools/run_render_checks.sh modern light_base must pass.

CHECK 3 – boats on dry ground: an art package measured on a LATER branch (with ship models) that ferries stand on the
meadow on Kiel – Hamburg at km 78.9, 79.1 and 84.6. They come from scripts/race/track.gd (lines 834–844: houseboats and
ferry_ship next to bridges with "h": −depth, 5–110 m beside the road). Check with pictures whether this build shows
them on dry ground in Modern (here they are Arcade pictures). If yes and the fix is small and safe (e.g. skip such a
prop where the ground under it is not water, or set it on the water level), fix it with a unit test; otherwise report.

${BUILD_STEPS('FIX-ZS1', `${SP}/deliver/FIX-ZS1/build/`)}
THE USER DOCUMENTS: copy ${SP}/deliver/gate1/was_neu.md and ${SP}/deliver/gate1/steamdeck_checkliste.md to
${SP}/deliver/FIX-ZS1/ and remove the passages about the known start fault ONLY if the fix is verified in the exported
build; adjust what else became untrue (sizes, the boats if you fixed them); plain German, no internal labels or package
names; keep everything else as it is.
GATES on the final head (commands and output in bericht.md): import clean; tests/check_scripts.gd; tools/run_tests.sh
green (once at the end; filter argument while iterating); tools/golden.sh check (20 von 20 and 17 von 17 identisch);
tools/golden.sh modern-make + modern-check (incl. OpenGL ES); tools/run_render_checks.sh all (every file OK, incl. the
new check). If time runs short: (1) the start fixed and seen in the exported builds, (2) golden check, run_tests and
the render checks, (3) the documents. Push every commit to origin wip/v080-fix-zs1. Report ${D('FIX-ZS1')} with
before/after pictures (Arcade | Modern before | Modern after, same moments). Return the result format with package
"FIX-ZS1": one acceptance entry per item (a)–(d), FIX 2, CHECK 3, the build, each smoke test and each gate.`

phase('Korrektur')
const fix = await agent(`${common('FIX-ZS1', { mode: 'fresh', base: BASE }, 'render')}
${ROLE_FIX}`, { label: 'korrektur:FIX-ZS1', phase: 'Korrektur', schema: BUILD_R, isolation: 'worktree' })
if (!fix || !fix.commit) { log('FIX-ZS1 fehlt'); return { fix } }
log(`FIX-ZS1: ${fix.commit.slice(0, 7)} (${fix.acceptance.filter(a => a.result === 'fail').length} offen)`)

phase('Prüfung')
const qa = await agent(`${common('QA-ZS1', { mode: 'review', base: fix.commit }, 'render')}
YOUR ROLE: QA-ZS1 – INDEPENDENT CHECK OF THE REBUILT FIRST TEST BUILD before it goes to the user this morning. No
commits, no pushes. Use nice -n 5 and one Godot run at a time. The fix reports: ${INFO(fix)}; its report ${D('FIX-ZS1')};
QA1's report of the first build ${D('QA1')}.
Do not trust the reports – run and look yourself:
1. THE DELIVERED FILES exactly as the user gets them: ${SP}/deliver/FIX-ZS1/build/. Copy them into your scratch, check
   SHA256SUMS (sha256sum -c), unpack, check the archive contents (the program + LIZENZEN.txt), sizes and BUILDINFO
   (commit ${fix.commit}? version 0.8.0-zs1? user folder crossing-europe-zwischenstand?).
2. The Linux export under Xvfb with a fresh XDG_DATA_HOME: the first start like a player (the chooser "GRAFIK WÄHLEN",
   Modern, the title shows v0.8.0-zs1); then the standing start of Kiel – Hamburg in Modern: pictures in the countdown
   (1 s, 3 s) and after "LOS!" (0.7 s, 1.5 s, 4 s) next to Arcade at the same moments – is the player car visible at
   Arcade's place and size, the road and the ground complete behind and beside the car, the start gate and the signs
   where Arcade has them, no jump of the camera? Then the starts of at least three other stages of different kinds (a
   bend or slope at the start, a city start, night or rain) with "-- --stage=<id>" (tools/smoke_modern.sh shows how a
   player's build is started with arguments), and one flying start at km > 0 – compare that one with the OLD build in
   ${SP}/deliver/gate1/build/ (same commands): nothing may have changed there.
3. The Windows export under Wine (wine64, own WINEPREFIX, TMPDIR unset, Z:<abs path>): Modern starts and shows the car
   in the countdown; Arcade starts.
4. The code: git diff ${BASE}..${fix.commit} – only the intended files, no frozen Arcade file (contract rule 1). What
   reads the road path before z = 0 now (traffic behind the player at the start, police, the sight checks, chunk
   building, rebasing, the Leistungstest, the attract demos) – any side effect? Is the new render check a real guard
   (break the fix in a scratch copy: does it fail)? Run tools/golden.sh check once (20 von 20 and 17 von 17) and the
   new render check.
5. The two user documents in ${SP}/deliver/FIX-ZS1/ (was_neu.md, steamdeck_checkliste.md): true for this build, plain
   German, no internal labels; is there anything the user is asked to do that does not work in this build?
Every finding needs where, what, evidence (command + output or picture path; measured or inferred), how to reproduce
and a concrete fix. Severity: blocker = must not go to the user; high = the user notices at once; medium = noticeable;
low = polish. Also list what you checked and found fine. Pictures and bericht.md into ${SP}/deliver/QA-ZS1/.`,
  { label: 'prüfung:QA-ZS1', phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })
const found = qa ? qa.findings : []
const cnt = (s) => found.filter(f => f.severity === s).length
log(`QA-ZS1: ${cnt('blocker')} Blocker, ${cnt('high')} hoch, ${cnt('medium')} mittel, ${cnt('low')} niedrig`)

let fixr = null
let nach = null
if (cnt('blocker') + cnt('high') + cnt('medium') > 0) {
  phase('Nacharbeit')
  fixr = await agent(`${common('FIX-ZS1R', { mode: 'fresh', base: fix.commit }, 'render')}
YOUR ROLE: FIX-ZS1R – FIXES AFTER THE INDEPENDENT CHECK OF THE REBUILT FIRST TEST BUILD.
${URGENT}
Your base is FIX-ZS1's head ${fix.commit} (origin/wip/v080-fix-zs1). FIX-ZS1 reports: ${INFO(fix)}; its report
${D('FIX-ZS1')}. The independent check QA-ZS1 found (report ${D('QA-ZS1')}):
${JSON.stringify({ verdict: qa.verdict, findings: qa.findings })}
Reproduce each blocker, high and medium finding first (reject it with evidence if it is wrong), fix every confirmed
one, then the cheap low ones. Documents: fix them in ${SP}/deliver/FIX-ZS1/. If the game changed (anything outside
docs/ and tests/): ${BUILD_STEPS('FIX-ZS1R', `${SP}/deliver/FIX-ZS1/build/ (REPLACE the files there; keep the replaced ones in ${SP}/m1/FIX-ZS1R/alt/ until the new ones passed)`)}
Gates again on the final head: tests/check_scripts.gd; tools/run_tests.sh; tools/golden.sh check;
tools/golden.sh modern-check (modern-make only where a Modern picture changed on purpose); tools/run_render_checks.sh
all. Push every commit to origin wip/v080-fix-zs1r. Report ${D('FIX-ZS1R')}. Return the result format with package
"FIX-ZS1R": one acceptance entry per finding (pass = fixed and re-checked, fail = still open, not_run = rejected –
say why), then the build, the smoke tests and the gates.`,
    { label: 'nacharbeit:FIX-ZS1R', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
  const game = fixr && fixr.commit && (fixr.files_changed || []).some(f => !/^(\/|docs\/|tests\/|ARCHITECTURE|README|deliver|\(|Bericht|bericht)/.test(f))
  if (fixr) log(`FIX-ZS1R: ${fixr.commit ? fixr.commit.slice(0, 7) : '?'} (${fixr.acceptance.filter(a => a.result === 'fail').length} offen, Spiel geändert: ${game ? 'ja' : 'nein'})`)
  if (game) {
    phase('Nachprüfung')
    nach = await agent(`${common('NACH-ZS1', { mode: 'review', base: fixr.commit }, 'render')}
YOUR ROLE: NACH-ZS1 – FOCUSED RE-CHECK of the fix round FIX-ZS1R only (head ${fixr.commit}), before the build goes to
the user this morning. No commits, no pushes; nice -n 5, one Godot run at a time. The findings of the independent
check: ${JSON.stringify(qa.findings.filter(f => f.severity !== 'low'))}
FIX-ZS1R reports: ${INFO(fixr)}; its report ${D('FIX-ZS1R')}.
Check each finding against the DELIVERED build in ${SP}/deliver/FIX-ZS1/build/ (sha256sum -c; BUILDINFO names
${fixr.commit}?) – run the exported Linux build under Xvfb and the Windows build under Wine (own WINEPREFIX, TMPDIR
unset): the standing start of Kiel – Hamburg in Modern (countdown and 1.5 s after "LOS!", next to Arcade) and whatever
the findings concern; git diff ${fix.commit}..${fixr.commit} for side effects and frozen Arcade files; tools/golden.sh
check once; the documents in ${SP}/deliver/FIX-ZS1/. Return per finding fixed / partly / not_fixed / not_checked with
evidence, any new finding, and the gates you ran with their output. Pictures and bericht.md into ${SP}/deliver/NACH-ZS1/.`,
      { label: 'nachprüfung:NACH-ZS1', phase: 'Nachprüfung', schema: RECHECK, isolation: 'worktree' })
  }
}
return { fix, qa, fixr, nach }
