
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
