export const meta = {
  name: 'v080-klang-kritik',
  description: 'v0.8.0 Modern sound: two independent measurement reviews – road/wind/impact sounds and their in-game triggering (AU-C1), and the music mix plus the whole game mix (AU-D1/AU-D2 with engine and road) – to prepare one rework after the user listens tonight; read-only, low CPU priority',
  phases: [
    { title: 'Klangkritik', detail: 'KRITIK-FAHRBAHN and KRITIK-MISCHUNG in parallel, read-only, measurements only' },
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

// Two independent, read-only measurement reviews of the Modern sound before the user's headphone verdict arrives.
const HEAD = '4209268f0bad80beb9abc2609d92a74cd7279db1'   // AU-C1 final head: AU-A core, AU-B engine v3, AU-D1/AU-D2 music, AU-C1 road
const HEAD_WT = `${REPO}/.claude/worktrees/wf_f5d01292-ef8-1`

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement for the user, 5-10 sentences; nothing about how it sounds is measured – say inferred' },
    findings: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, severity: { type: 'string', enum: ['blocker', 'high', 'medium', 'low'] },
      area: { type: 'string' }, where: { type: 'string' }, problem: { type: 'string' },
      evidence: { type: 'string', description: 'command + output excerpt or picture path; measured vs inferred' },
      repro: { type: 'string' }, fix: { type: 'string', description: 'concrete change: file, parameter, value' } },
      required: ['id', 'severity', 'area', 'where', 'problem', 'evidence', 'repro', 'fix'] } },
    knobs: { type: 'array', items: { type: 'string' }, description: 'data knobs (file → key) with the effect of a stated change, measured where possible' },
    checked_ok: { type: 'array', items: { type: 'string' }, description: 'what was checked and found fine (one line each)' },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'findings', 'knobs', 'checked_ok', 'media'],
}

const EARLY = `PRIORITY RULE: the assembly and QA of the user's first test build run on this machine at the same time and are on
the critical path. Run EVERY heavy job (Godot runs, audio renders, analyses over many files) with nice -n 19 and one
process; never two heavy jobs at once. Never run tools/run_tests.sh or tools/golden.sh (not needed for a review).`

const COMMON_AU = `THE OBJECT OF REVIEW: the complete Modern sound profile on head ${HEAD} (branch origin/wip/v080-au-c1; the builder's
worktree ${HEAD_WT} is READ-ONLY for you – no edits, no commits there). Work on a copy in your scratch folder:
cp -a the worktree without build/ (and without .godot), then cp -a ${REPO}/.godot into the copy and import once
(godot --headless --path <copy> --import), absolute XDG_DATA_HOME for every run. You make no commits.
What it contains: AU-A (audio core: buses MCar/MWorld/MMusic/MImpact …, ModernMix, capture tools), AU-B (engine v3 –
the user heard and liked the engine A/B), AU-D1 (music chain tools/audio/music/, title remaster, race track 1 „Linke
Spur", MusicDirector), AU-D2 (race tracks 2 „Nachtfahrt" and 3 „Rückenwind", interlude, stingers, UI sounds; ONE mix
file tools/audio/music/mischung.json for every decision the user may still change), AU-C1 (AudioFeed, road, wind,
impacts). Reports: ${SP}/deliver/{AU-B,AU-D1,AU-D2,AU-C1}/bericht.md and the previews next to them; docs/audio-modern.md
(complete) and the audio study ${SP}/audio (src, out, deliver). Contract: docs/dev/v080_contract.md §3 D25–D30, §4.7,
§11 A-5.
THE USER: has heard the engine A/B (liked it), AU-D1's previews (track 1 and the title remaster: „der Stil passt
super"; bass and level are judged tonight with headphones) and gets AU-D2's and AU-C1's previews for tonight as well.
The user plays on a Steam Deck (small stereo speakers and headphones) and on Windows. A race lasts hours.
YOU CANNOT HEAR. Everything about how something sounds to a person is inferred; numbers are measured. Use objective
measurements (ITU-R BS.1770 loudness and true peak, third-octave/critical-band spectra, spectral tilt, crest factor,
stereo correlation and mono sum, modulation spectra, autocorrelation for repetition, onset/transient analysis, masking
estimates per critical band) and well-established acoustic facts about real sources; say plainly what a person must
judge. Python with numpy/scipy (if present)/PIL and ffmpeg are available; write your analysis scripts into your scratch
folder. Your job is to make the ONE rework after the user's verdict tonight fast and right: concrete, ranked findings
with file → parameter → value fixes, and a list of the data knobs with their measured effect.`

const FAHRBAHN = `${common('KRITIK-FAHRBAHN', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT MEASUREMENT REVIEW OF THE ROAD, TYRE, WIND AND IMPACT SOUNDS (AU-C1) AND OF THEIR TRIGGERING IN THE
GAME. No building.
${COMMON_AU}
REVIEW (rank by what the player hears most – the motorway at 100–200 km/h first):
1. Plausibility per layer against the physics of real sources (measure the sounds in assets/audio/modern/{vehicle,sfx}
   and in the previews): tyre/road rolling noise (broadband, its main band and its rise with speed; the tyre cavity
   resonance), asphalt vs concrete slabs (joint thumps at the axle pair, slab length), steel deck and expansion joints
   (double hit at the wheelbase), cobbles (impact rate from stone pitch × speed), rumble strip (tonal buzz at
   speed / groove pitch with harmonics – note that its fundamental is around 100 Hz at motorway speed), gravel shoulder,
   grass, wet (spray hiss), snow, squeal (tonal with jitter) and scrub, wind (three bands, gusts, the open-window
   buffeting), impacts (layering, partner, side, the glass layer). Name each place where the measurements suggest an
   artificial sound (steady filtered noise, a pure tone, ringing glass) and how the generator could make it more
   natural (decorrelated layers, random modulation, granular playback, longer loops).
2. Repetition: the loops are 0.8–3 s long. Play constant speed for 20 s in the game mix and measure the self-similarity
   (autocorrelation of the envelope and of the spectrum frames); say which loops would likely be heard as repeating and
   what length or layering would hide it.
3. Triggering in the game: run headless Modern stages with logging of the AudioFeed state once per second (surface
   per side, deck, joints, rumble strip, paving, zone, delineators) – Kiel – Hamburg completely, plus one stage with a
   long bridge, one with a city centre and one southern stage – and compare with the Track data (motorway class,
   bridges, cities, tunnels, fuel lanes, border posts): wrong or missing triggers, joints off the bridge ends, cobbles
   outside towns, rumble strip off motorways, tunnel/cutting zones where there is none. AU-C1 notes that the capture
   tool capture_mix.gd sends no vehicle state – use AU-C1's scratch scripts (${SP}/m1/AU-C1/: drive_demo.gd,
   layers_demo.gd, worst_case.gd, perf.gd, phases.py, peaks.py; copy them) or your own.
4. Small speakers and mono: apply a 180 Hz high-pass and a typical small-speaker response (Steam Deck class) to the game
   mix at 130 km/h: does the road layer stay audible, does the rumble strip vanish (its fundamental), does the wind turn
   into hiss? Mono sum of the side-panned sounds (ModernAudioPan) and the centre loudness of its pan law.
5. Levels and safety: the plan of D29 against the measured sums (AU-C1's contract issues: full throttle at top speed
   −14.4/−14.6 LUFS with road and wind; engines alone −17.2 to −18.5), heavy impacts at −2.8 dBFS, the master limiter
   (sample-peak, threshold −0.8 dB before the master volume, overshoot 0.1–0.7 dB, worst case at master volume 1.0
   inferred −0.5 to −0.1 dBTP), the traffic and siren placeholders driving the limiter by up to 4 dB. Propose concrete
   lead decisions with numbers (e.g. a true-peak-safe limiter threshold for the Modern profile only, the top-speed row
   of the plan) – the Arcade profile and its config stay frozen.
6. Cost and hygiene: CPU per frame of road/impact under the frame budget, allocations per frame, no "leaked at exit"
   with either profile, the Arcade profile plays nothing new (verify).
DELIVER to ${SP}/deliver/KRITIK-FAHRBAHN/ (German): bericht.md with the ranked findings, the measurements (tables,
spectrum pictures with German captions) and the knobs; nothing else.`

const MISCHUNG = `${common('KRITIK-MISCHUNG', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT MEASUREMENT REVIEW OF THE MUSIC MIX (AU-D1, AU-D2) AND OF THE WHOLE GAME MIX (music with engine,
road and wind). No building.
${COMMON_AU}
REVIEW:
1. The pieces: title remaster, „Linke Spur", „Nachtfahrt", „Rückenwind", the interlude, the stingers, the UI sounds
   (assets/audio/modern/{music,ui}/**, as shipped after Ogg Vorbis): integrated and short-term loudness against the
   plan (race −14 LUFS, menu −20 LUFS), true peak, crest factor, spectral balance per band (sub < 60 Hz, bass 60–250,
   low mids, presence 2–5 kHz, air > 8 kHz), long-term spectral tilt, stereo width and correlation per band (bass
   should be centred and in phase), and how consistent the three race tracks are with each other. The reference of the
   brand sound is the v0.5.0 title theme the user loved (the frozen Arcade music; find it in assets/audio and
   tools/audio/music_synth.py) – measure it the same way and show where the new pieces differ.
2. Headphones over hours: excessive sub energy (< 40 Hz), out-of-phase bass, harsh 2–5 kHz, sharp > 8 kHz, low crest
   factor (fatigue), loudness jumps between pieces and at the switches (count-in, loop, ending, stingers ducking the
   music, the interlude). Check the loop seams and the bar-synced endings once more in the game (AU-D1's interactive
   checks) – no gap, no double hit.
3. The game mix: music under the car at 80, 130, 200 and 250 km/h (engine v3 + road + wind of AU-C1, no traffic):
   measured ducking depth and recovery, and a masking estimate per critical band – is the melody/hook of each race
   track still above the car noise at 130 km/h on headphones and on small speakers (180 Hz high-pass)? Does the wind at
   200–250 km/h cover the music? What race music level (mischung.json race_music_db / the director's offset) keeps
   the music audible without fighting the engine?
4. THE KNOB SHEET for tonight: the user will say things like „zu viel Bass", „zu wenig Bass", „Musik im Rennen zu
   leise/zu laut", „zu schrill", „zu dumpf", „Menü zu laut". For each, which key of tools/audio/music/mischung.json
   (sub_db, bass_db, high_shelf_db/hz, race_music_db, menu_music_db, ui_db, …) or of config audio.modern changes by
   how much, with the predicted (where possible measured) effect on the numbers above. Measure how long a full
   re-render takes (tools/audio/music/render_all.py; AU-D2 reported 25–27 min at nice 19) and whether only the mix and
   master stage could be re-run for a mix change (read the code; do not change it).
DELIVER to ${SP}/deliver/KRITIK-MISCHUNG/ (German): bericht.md with the ranked findings, the measurements (tables,
spectrum pictures with German captions) and the knob sheet; nothing else.`

phase('Klangkritik')
const [fahrbahn, mischung] = await parallel([
  () => agent(FAHRBAHN, { label: 'kritik:Fahrbahn', phase: 'Klangkritik', schema: FINDINGS }),
  () => agent(MISCHUNG, { label: 'kritik:Mischung', phase: 'Klangkritik', schema: FINDINGS }),
])
for (const [n, r] of [['Fahrbahn', fahrbahn], ['Mischung', mischung]]) {
  if (r) log(`${n}: ${r.findings.length} Befunde (${r.findings.filter(f => ['blocker', 'high'].includes(f.severity)).length} hoch)`)
  else log(`${n}: ausgefallen`)
}
return { fahrbahn, mischung }
