export const meta = {
  name: 'v080-m2-frueh-musik',
  description: 'v0.8.0 Modern, early start of M2 audio: music chain, title remaster and race track 1 with the music director (AU-D1), low CPU priority',
  phases: [
    { title: 'Musik', detail: 'AU-D1: music chain, remaster, race track 1, MusicDirector, previews for the user' },
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

// Early start of M2 audio: AU-D1 (music chain, title remaster, race track 1)
phase('Musik')
const EARLY = `EARLY START – PRIORITY RULE: you are an early start of the next push (M2). The assembly of push M1 runs at the
same time and is on the critical path for the user's first test build. Run EVERY heavy job (audio renders, Godot runs,
test suites) with nice -n 19 (not 10) and one worker process; never two heavy jobs at once.`

const AUD1 = `${common('AU-D1', { mode: 'fresh', base: '3b89a3326285d5c186709c391c52838dccbab01f' }, 'content')}
${EARLY}
YOUR ROLE: AU-D1 – MUSIC CHAIN, TITLE REMASTER, RACE TRACK 1 (§6 wave 4 of the contract, D25, D26, D29, D30, §4.7,
A-5). Your base is UI1's head 3b89a33 (branch worktree-wf_9693abb2-cee-2): v0.8.0 with the audio core AU-A, the engine
v3 AU-B, the vehicle models AS1 and UI1's options (Klang, „Musik im Rennen“) and GameFlow's set_music_context calls.
Read docs/audio-modern.md completely (MusicDirector is already planned there as a building block on MMusic) and the
audio study: its sources ${SP}/audio/src (title_remaster.py, race_track.py = sketch "Linke Spur", D minor, 132 bpm,
music2lib.py, race_mix_demo.py, media_music.py), its numbers ${SP}/audio/out and its previews
${SP}/audio/deliver/musik (the user got titel_ab_erst_alt_dann_remaster.mp3, rennmusik_linke_spur_skizze.mp3 and
rennmix_musik_unter_motor.mp3 on 10 Nov; the user loved the v0.5.0 title theme – synthwave rock, 128 bpm – so stay in
that brand sound; no feedback on the sketches yet).
BUILD (files you own: tools/audio/music/**, scripts/audio/modern/music_director.gd, assets/audio/modern/music/**,
tests for them, the music section of docs/audio-modern.md; additive wiring in scripts/audio/modern/modern_audio.gd
only where the director is created and fed; the frozen Arcade tools tools/audio/music_synth.py etc. are imported,
never edited):
1. The music chain in the repo: tools/audio/music/ (generators that import the frozen Arcade instruments plus the
   modern layers of music2lib, a mastering stage: −14 LUFS integrated, true peak ≤ −1 dBTP after Ogg Vorbis q5,
   44.1 kHz; deterministic: two renders are byte-identical; --out <dir>; manifest.json with file, LUFS, true peak,
   bpm, bars, loop points, bytes – audio_qc.py must pass).
2. The title remaster: the same composition as the v0.5.0 title theme (key and chord-root check against the original
   – the audio study has compare_music.py), own file, used by the Modern profile on the title and menu screens at
   −20 LUFS menu level.
3. Race track 1 ("Linke Spur", grown from the study's sketch into a full piece of about 2.5–3.5 min): count-in that
   lands on the "Go", loop body, bar-synced ending at the finish, through AudioStreamInteractive (prove with a Godot
   test that the switch is gapless and bar-synced) or the two-player fallback of D30.
4. MusicDirector (scripts/audio/modern/music_director.gd): contexts title / menu / race_menu / race / result / off
   (set_music_context), set_race_music(on) honoured (default on in the Modern profile, Arcade has no race music),
   race music 8 dB under the car with the scripted ducking of A-5 (AudioEffectAmplify fader, key = ModernMix.car_lufs,
   attack 50 ms, release 450 ms), pause low-pass, crossfades without clicks, nothing in the Arcade profile, clean stop
   on exit (no "leaked at exit").
5. Tests: unit tests for the director's state machine; a headless check that plays a short race with the Modern
   profile and measures that the music ducks ≥ 3 dB under full throttle and recovers (frame time × time scale < 0.35 s,
   A-5); audio_qc.py on every new file; the size against the budget (§4.11: Modern sounds/music ≤ 23/≤ 25 MB).
DELIVER for the user (German file names, into ${SP}/deliver/AU-D1/): a 30–45 s sketch MP3 of race track 1 alone,
the same 40 s in the race mix under the engine (full throttle through the gears, then cruise – rendered from the game
or the study's race_mix_demo), the complete track 1 as MP3, the title A/B (old v0.5.0 → remaster) as MP3, spectrogram
pictures, and bericht.md. You cannot hear: judge with measurements (loudness, spectrum, chords, seams) and say
plainly that the user must judge the sound.
GATES: tools/run_tests.sh green (once, at the end); tools/golden.sh check 20 von 20 (Arcade identity); audio_qc.py
green; the Arcade profile plays no new sound (prove it). Push every commit to origin wip/v080-au-d1.
Return the result format with package "AU-D1".`

const aud1 = await agent(AUD1, { label: 'musik:AU-D1', phase: 'Musik', schema: BUILD_C, isolation: 'worktree' })
log(aud1 ? `AU-D1: ${aud1.commit ? aud1.commit.slice(0, 7) : '?'} (${aud1.acceptance.filter(a => a.result !== 'pass').length} offen)` : 'AU-D1 fehlt')
return { aud1 }
