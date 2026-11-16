export const meta = {
  name: 'v080-zs1-startfix',
  description: 'v0.8.0 first test build: fix the start of every stage in Modern (camera 9 m too far ahead, own car invisible in the countdown) and the start-gate lamp rims that cast shadows with shadows off, check boats on dry ground, rebuild the test build for Steam Deck and Windows with smoke tests, then an independent check of the delivered archives, a fix round only on blocker/high/medium findings and a focused re-check',
  phases: [
    { title: 'Korrektur', detail: 'FIX-ZS1: start at km 0, lamp rim shadows, boats; new test build, smoke tests, gates' },
    { title: 'Prüfung', detail: 'QA-ZS1: independent check of the delivered archives (Linux, Wine), the diff and the user documents' },
    { title: 'Nacharbeit', detail: 'FIX-ZS1R: only on blocker/high/medium findings' },
    { title: 'Nachprüfung', detail: 'NACH-ZS1: focused re-check, only if the fix round changed the game' },
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
