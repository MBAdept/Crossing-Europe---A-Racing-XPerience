const RINT_INFO = JSON.stringify({ branch: rint.branch, commit: rint.commit, summary: rint.summary,
  open: rint.acceptance.filter(a => a.result !== 'pass'), deviations: rint.deviations, notes: rint.notes_for_next, look: rint.look_verdict })
const LENSES = [
  { id: 'QA-BILD', prompt: `LENS: PICTURE, FAIRNESS, PERFORMANCE. Judge what the player sees in Modern against Arcade of the same
simulation state (tools/ab_shot.sh) at S1–S5, T1–T4, C1, N1, N2, U1 and DEV, and in motion (record 10-20 s clips with
the autopilot at 60 fps fixed and look at single frames from them): road paint at grazing angles (shimmer, aliasing),
terrain seams and holes, props (placement, LOD pops, stand-ins, shadows), vehicles (sit on the road, wheels, lamps,
indicators at 50/150/300 m, brake lights, articulation of trucks, paint against the Cycles sprites), the vehicle
stand-ins (Arcade pictures for every set without a model: player cars kombi, sportwagen, gran_turismo; traffic
sports, van, SUV, buses, police – never worse than Arcade), flares and occlusion behind crests and trucks,
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
   options Grafik/Klang, Leistungstest and where leistungstest.json lies on Deck and Windows; the curve camera –
   in Modern the camera turns slightly into bends, and the user decides after driving whether it stays, gets
   stronger or weaker; records and settings of the test build live in their own folder, name the paths on Deck and
   Windows), was_neu.md (German, short, for the user: what Modern already shows and what is still missing in this
   intermediate state – honest; vehicles without a model still show their Arcade picture, their models are being
   built; the race music: track 1 „Linke Spur“ and the remastered title theme are in, tracks 2–3 follow).
Return the result format with package "QA1": one acceptance entry per item above.`,
  { label: 'zwischenstand:QA1', phase: 'Zwischenstand', schema: BUILD_R, isolation: 'worktree' })
return { rint, reviews, fix, qa1 }
