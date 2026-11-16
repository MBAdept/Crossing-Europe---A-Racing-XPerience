export const meta = {
  name: 'v080-m1-zusammenbau',
  description: 'v0.8.0 Modern, M1: assemble all packages (RINT), independent QA in two lenses, fixes, gate 1 with the first test build (Zwischenstand 1)',
  phases: [
    { title: 'Zusammenbau', detail: 'merge the renderer, model, sound and UI packages; make Kiel–Hamburg drive in Modern; look pass; gates' },
    { title: 'Prüfung', detail: 'QA-BILD and QA-SYSTEM, independent and without commits' },
    { title: 'Nacharbeit', detail: 'fix the confirmed findings, gates again' },
    { title: 'Zwischenstand', detail: 'gate 1: A/B sheets, clips, Leistungstest, goldens, test builds for Linux/Steam Deck and Windows' },
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

// ---- args: { v080: '<sha>', merge: [{package, branch, commit}], reports: [...package results...], notes: '<lead notes>' }
const V080 = args.v080
const MERGE = args.merge
const REPORTS = args.reports
const LEAD_NOTES = args.notes || ''

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement for the user, 5-10 sentences' },
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

phase('Zusammenbau')
const rint = await agent(`${common('RINT', { mode: 'fresh', base: V080 }, 'render')}
YOUR ROLE: RINT – ASSEMBLY OF THE WHOLE PUSH M1 (A-8). Your fresh worktree starts from the v0.8.0 head ${V080}. Merge
the package branches with --no-ff in this order (commit messages in German, trailer as above):
${MERGE.map(m => `${m.package} = ${m.branch} (${m.commit})`).join('\n')}
Resolve conflicts by file ownership (R1 owns modern_renderer.gd, the kernel, race_session.gd and the "graphics"
config section; R3 owns vpbr/glass/sign/flare shaders, model_factory.gd, modern_materials.gd; R2 terrain/props/far
ground and their shaders; AS1R the vehicle models and ce3d vehicle builders; AS1b the environment models and prop
builders; AU-B the engine; UI1 the screens, settings, gfx). Generated files are regenerated, never hand-merged:
assets/models/manifest.json (tools/blender/export_models.py --manifest-only, then the validator), .import/.uid files
(godot --headless --import). ${LEAD_NOTES}
Package reports (open items, deviations, contract issues, notes for you):
${JSON.stringify(REPORTS)}
Then make everything work together – you own every file of this push now:
- Kiel–Hamburg drives in Modern from start to finish with the real road, environment, terrain, props (models where
  they exist, lit stand-ins elsewhere), vehicles, flares and signs; street-light lamps reach the light pools and the
  far-field glow through add_lamps(); road and terrain get the pool uniforms; warm-up covers every layer and builder;
  no per-frame errors or warnings in the log; pause freezes the picture; the fallback (--gfx-debug=fail) still gives
  an Arcade stage; leaving Modern frees what it loaded.
- Fix what the combination breaks or leaves ugly: z-fighting between road and terrain, seams at chunk borders, props
  in the road or floating, wrong light on stand-ins, shadows cut off, flares through terrain, sign posts in the air,
  LOD pops, cars that do not sit on the road in bends and on crests, wheels that do not turn.
- UI and sound: hook the new checks of UI1 (and of every package) into tools/run_tests.sh / run_render_checks.sh;
  regenerate the preview pictures of the options page and of the chooser with the real renderer (UI1's tool); check
  the showroom with the real paint shader and set the showroom flags honestly (the A/B against the sprite decides,
  AS1's notes say how); the Leistungstest (--bench=all) runs on the merged renderer and writes leistungstest.json;
  the Modern sound profile with engine v3 plays in the race, switching Grafik/Klang in the options works, the
  Arcade sound and picture stay unchanged.
- LOOK PASS: A/B sheets with tools/ab_shot.sh at S1–S5, T1, C1 (19:30), N1 (night, snow) and N2 (rain) – weather
  effects and tunnels come in a later wave, but nothing may look broken there. LOOK at each and improve what is cheap
  to improve in light, materials and composition until Modern is clearly the better picture by day on the slice.
  Write an honest list of what still looks worse than Arcade or unfinished.
GATES on the merged tree (record the commands and the output in bericht.md): import clean; tools/run_tests.sh green;
tools/golden.sh check 20 von 20; tools/run_render_checks.sh all; tests/sim/modern_sight.gd -- --full and
tests/sim/modern_path_check.gd -- --full; python3 tools/blender/validate_models.py --report; export determinism
(export_models.py --check-keys, second bake byte-identical); check_sprite_geometry.py if any package changed a
cesprites file; ERGEBNIS identity Arcade vs Modern (tests/race/run_stage.gd) on kiel_hamburg, dev_testetappe (night,
rain) and saragossa_pau (snow); a complete Modern autopilot run of Kiel–Hamburg under Xvfb without script errors with
perf_stats at the end (render() ms average and max, chunk commit ms max, draw calls, primitives – measured on
llvmpipe; real hardware is inferred); texture memory against the Arcade race of the same stage (budget + 60 MB, A-6);
tools/build_linux.sh and tools/build_windows.sh succeed with the pck report inside the size budget, and the Windows
build starts a Modern stage under Wine (wine64, wineserver -w between runs, TMPDIR unset).
Deliver: the A/B sheets and a 20 s A/B clip of the start of Kiel–Hamburg (ffmpeg, side by side) in
${SP}/deliver/RINT/, with bericht.md. Return the result format with package "RINT", one acceptance entry per gate.`,
  { label: 'zusammenbau:RINT', phase: 'Zusammenbau', schema: BUILD_R, isolation: 'worktree' })
if (!rint) return { rint: null }
log(`RINT: ${rint.commit ? rint.commit.slice(0, 7) : '?'} (${rint.acceptance.filter(a => a.result !== 'pass').length} offen)`)

const RINT_INFO = JSON.stringify({ branch: rint.branch, commit: rint.commit, summary: rint.summary,
  open: rint.acceptance.filter(a => a.result !== 'pass'), deviations: rint.deviations, notes: rint.notes_for_next, look: rint.look_verdict })
const LENSES = [
  { id: 'QA-BILD', prompt: `LENS: PICTURE, FAIRNESS, PERFORMANCE. Judge what the player sees in Modern against Arcade of the same
simulation state (tools/ab_shot.sh) at S1–S5, T1–T4, C1, N1, N2, U1 and DEV, and in motion (record 10-20 s clips with
the autopilot at 60 fps fixed and look at single frames from them): road paint at grazing angles (shimmer, aliasing),
terrain seams and holes, props (placement, LOD pops, stand-ins, shadows), vehicles (sit on the road, wheels, lamps,
indicators at 50/150/300 m, brake lights, articulation of trucks), flares and occlusion behind crests and trucks,
signs (legible, posts on the ground), light at every hour (dawn, noon, dusk, night with headlight cone and pools),
curve camera, fallback. Fairness: re-run tests/sim/modern_sight.gd -- --full and modern_path_check.gd -- --full and
compare F1–F7 limits with the contract; a car or a sign must never be visible later or smaller than in Arcade.
Performance: perf_stats over a complete Kiel–Hamburg autopilot run per preset (low, medium, high) on llvmpipe,
spikes during chunk commits, memory over 20 minutes of driving (leaks), warm-up time; say what real hardware would
need (inferred).` },
  { id: 'QA-SYSTEM', prompt: `LENS: ARCADE IDENTITY, SOUND, MENUS, ROBUSTNESS, MODELS PIPELINE. Arcade must be pixel- and
sound-identical to v0.7.0 (tools/golden.sh check; compare the Arcade ERGEBNIS of run_stage.gd with v0.7.0 = main on
three stages); every frozen file unchanged against main (git diff --stat main -- <frozen list of the contract>).
Settings: a v0.7.0 settings file and records are migrated (settings v3) without loss, the chooser appears exactly
once, the leaderboard entries carry gfx, switching Grafik/Klang in the options and in the middle of a championship
works; everything works with a gamepad alone (focus order, LB/RB tabs, no traps) at 1280×720 and 1280×800 with text
≥ 18 px. Sound: Modern profile in race and menus, engine v3 of all five cars (spectrogram per car from a short
capture), ducking, race music on/off, no clicks at loop seams, clean shutdown; Arcade sound unchanged. Robustness:
--gfx-debug=fail and a missing manifest fall back to Arcade with the right message; Leistungstest (--bench=all) runs
and writes a valid leistungstest.json; quitting and restarting in every screen; 20 minutes of Modern driving without
errors in the log; the Windows build under Wine starts Modern and Arcade. Models pipeline: validator, export
determinism, manifest regenerated and consistent, sizes inside the budget (tools/pck_report.py).` },
]
phase('Prüfung')
const reviews = (await parallel(LENSES.map(l => () => agent(`${common(l.id, { mode: 'review', base: rint.commit }, 'render')}
YOUR ROLE: INDEPENDENT QA OF THE ASSEMBLED PUSH M1 (head ${rint.commit}, branch ${rint.branch}) – no commits, no
pushes. The assembly reports: ${RINT_INFO}
Do not trust the reports – run and look yourself. ${l.prompt}
Every finding needs where, what, evidence (command + output or picture path, measured or inferred), how to reproduce
and a concrete fix. Severity: blocker = the test build must not go out with it; high = the user will notice at once;
medium = noticeable; low = polish. Also list what you checked and found fine. Pictures and the report (bericht.md)
into ${SP}/deliver/${l.id}/.`,
  { label: `prüfung:${l.id}`, phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })))).filter(Boolean)
const all = reviews.flatMap(r => r.findings)
log(`Prüfung: ${all.filter(f => f.severity === 'blocker').length} Blocker, ${all.filter(f => f.severity === 'high').length} hoch, ${all.filter(f => f.severity === 'medium').length} mittel, ${all.filter(f => f.severity === 'low').length} niedrig`)

phase('Nacharbeit')
const fix = await agent(`${common('FIX1', { mode: 'fresh', base: rint.commit }, 'render')}
YOUR ROLE: FIXES AFTER THE QA OF M1. Your base is the assembled head ${rint.commit} (branch ${rint.branch}). The
assembly reports: ${RINT_INFO}
Independent QA found (verdicts and findings): ${JSON.stringify(reviews.map(r => ({ verdict: r.verdict, findings: r.findings })))}
Reproduce each blocker, high and medium finding first (reject it with evidence if it is wrong), fix every confirmed
one, most-seen first, and the cheap low ones. Re-render the pictures the findings point to and LOOK at them. Then the
gates once more on your final head: import clean; tools/run_tests.sh green; tools/golden.sh check 20 von 20;
tools/run_render_checks.sh all; modern_sight --full and modern_path_check --full if the kernel or a vehicle/prop
placement changed; the validator if a model changed. Return the result format with package "FIX1": one acceptance
entry per finding you handled (pass = fixed and re-checked, fail = still open, not_run = rejected – say why), then
the gates.`,
  { label: 'nacharbeit:FIX1', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
const head = fix || rint
if (fix) log(`FIX1: ${fix.commit ? fix.commit.slice(0, 7) : '?'} (${fix.acceptance.filter(a => a.result === 'fail').length} offen)`)

phase('Zwischenstand')
const qa1 = await agent(`${common('QA1', { mode: 'fresh', base: head.commit }, 'render')}
YOUR ROLE: QA1 – GATE 1 AND THE FIRST TEST BUILD FOR THE USER (Zwischenstand 1). Your base is ${head.commit} (branch
${head.branch}). State: ${JSON.stringify({ summary: head.summary, open: head.acceptance.filter(a => a.result !== 'pass'), notes: head.notes_for_next, look: head.look_verdict })}
QA verdicts: ${JSON.stringify(reviews.map(r => r.verdict))}
Produce, measured on this machine (llvmpipe; real hardware inferred):
1. A/B sheets (Arcade | Modern, same simulation state, tools/ab_shot.sh, --gfx-preset=high and the preset the
   machine picks) at every reference position of §4.9.2: S1–S5, T1–T4, N1, N2, C1, U1, DEV. LOOK at every one.
2. Three A/B clips of 30 s each, side by side with the HUD (ffmpeg, H.264, ≤ 25 MB each): the start of Kiel–Hamburg by
   day, a night drive (dev_testetappe km 48, 21:00) and rain (N2).
3. The Leistungstest on llvmpipe per preset (low, medium, high) through the real runner (--bench=all --bench-out=…),
   the three leistungstest.json files and a short table.
4. tests/golden/modern_slice.md5 (Modern goldens of the slice, rendered without --shot-fast; prove that two runs give
   the same hashes, otherwise document why not and what tolerance the check uses) and the second identity list of the
   contract; hook both into tools/golden.sh or run_render_checks.sh; commit on your branch.
5. TEST BUILDS for the user: Linux x86_64 (also for the Steam Deck) and Windows x86_64 from your final commit with
   tools/build_linux.sh and tools/build_windows.sh (or build_release.sh with ALLOW_DIRTY=1 when you have to change
   project.godot only for the build). They must not touch the user's normal v0.7.0 installation: version string
   "0.8.0-zs1" visible on the title screen, application/config/use_custom_user_dir = true with
   custom_user_dir_name "crossing-europe-zwischenstand" (records, settings and saves separate), executable names
   CrossingEurope-ZS1.x86_64 / CrossingEurope-ZS1.exe, archives CrossingEurope-ZS1-linux-x86_64.tar.gz and
   CrossingEurope-ZS1-windows-x86_64.zip with LIZENZEN.txt, SHA256SUMS, each archive ≤ 400 MiB. Do these build-only
   changes without committing them to the shared files (or as a separate commit that is clearly marked "nur für
   den Testbuild" and reverted right after). Smoke-test both: Linux under Xvfb (chooser → Modern → a race start,
   Leistungstest), Windows under Wine (start, Modern race start). Put the archives, LIZENZEN.txt and SHA256SUMS into
   ${SP}/deliver/gate1/build/.
6. ${SP}/deliver/gate1/: bericht.md (German, for the lead: every gate with its result), steamdeck_checkliste.md
   (German, for the user: how to install the test build on the Steam Deck next to v0.7.0 – desktop mode, unpack,
   "Add a Non-Steam Game", Proton not needed for the Linux build; what to try: chooser, Modern on Kiel–Hamburg,
   options Grafik/Klang, Leistungstest and where leistungstest.json lies on Deck and Windows), was_neu.md (German,
   short, for the user: what Modern already shows and what is still missing in this intermediate state – honest).
Return the result format with package "QA1": one acceptance entry per item above.`,
  { label: 'zwischenstand:QA1', phase: 'Zwischenstand', schema: BUILD_R, isolation: 'worktree' })
return { rint, reviews, fix, qa1 }
