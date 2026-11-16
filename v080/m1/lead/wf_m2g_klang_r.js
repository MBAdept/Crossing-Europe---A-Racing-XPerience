export const meta = {
  name: 'v080-klang-ueberarbeitung',
  description: 'v0.8.0 Modern sound: one rework after the user liked the sound and music on headphones – fix the measured faults of the road/tyre/wind/impact sounds without changing their character, music unchanged (AU-R), an independent re-measurement, and a fix round only if needed; low CPU priority',
  phases: [
    { title: 'Überarbeitung', detail: 'AU-R: repetition, cobble hash, slab phase, bridge joints per deck, Modern limiter, variety; new before/after previews' },
    { title: 'Nachmessung', detail: 'KRITIK-R: independent read-only re-measurement against the targets and the character limits' },
    { title: 'Nacharbeit', detail: 'AU-R2: only if the re-measurement finds blocker/high findings' },
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

// ONE rework of the Modern sound after the user's headphone verdict (AU-R) → independent re-measurement (KRITIK-R)
// → fix round AU-R2 only if the re-measurement finds blocker/high findings.
const BASE = '4209268f0bad80beb9abc2609d92a74cd7279db1'   // AU-C1 final head: AU-A, AU-B, AU-D1, AU-D2, AU-C1
const RF = `${SP}/deliver/KRITIK-FAHRBAHN/bericht.md`
const RM = `${SP}/deliver/KRITIK-MISCHUNG/bericht.md`
const VERDICT = (args && args.verdict) || '(no answer from the user)'

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement, 5-10 sentences; nothing about how it sounds is measured – say inferred' },
    findings: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, severity: { type: 'string', enum: ['blocker', 'high', 'medium', 'low'] },
      area: { type: 'string' }, where: { type: 'string' }, problem: { type: 'string' },
      evidence: { type: 'string', description: 'command + output excerpt or picture path; measured vs inferred' },
      repro: { type: 'string' }, fix: { type: 'string', description: 'concrete change: file, parameter, value' } },
      required: ['id', 'severity', 'area', 'where', 'problem', 'evidence', 'repro', 'fix'] } },
    knobs: { type: 'array', items: { type: 'string' }, description: 'data knobs (file → key) with the effect of a stated change, measured where possible' },
    checked_ok: { type: 'array', items: { type: 'string' }, description: 'what was checked and found fine (one line each), with before → after numbers' },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'findings', 'knobs', 'checked_ok', 'media'],
}

const EARLY = `PRIORITY RULE: other packages run on this machine at the same time (the assembly and QA of the user's first test
build, model packages); the test build is on the critical path. Run EVERY heavy job (audio renders, Godot runs, test
suites, audio_qc --determinism, analyses over many files) with nice -n 19 and one process; never two heavy jobs at once.
tools/run_tests.sh (about 15 min) runs as a background command with an explicit timeout of at least 3,600,000 ms.`

const TASK = `THE USER'S VERDICT after listening to all previews with headphones (verbatim, German):
„${VERDICT}"
WHAT IT MEANS (lead decision): the user likes the Modern sound and the music as they are. So:
- KEEP THE CHARACTER. Change the level or timbre of a sound the user heard only where a measured FAULT below forces it.
  Every change below keeps the third-octave spectrum of the layer within ±1 dB at the reference speeds (130 km/h asphalt
  and concrete, 50 km/h cobbles) and its loudness within ±0.5 LU, unless stated otherwise – measure before → after.
- MUSIC: no change – no re-render, no change of race EQ, ducking or levels (the user judges the music in the race on the
  Steam Deck with the first test build; the knobs stay in config). Only if trivial: the new keys low_shelf_db /
  low_shelf_hz in tools/audio/music/mischung.json (music_lib PREFS_DEFAULT and Master.__init__, like high_shelf_db) with
  default 0 – no audible change, no re-render.

FIX THESE MEASURED FAULTS (from the two independent measurement reviews; the B-numbers are those of the road review):
R1 Exact repetition (B1): every surface, wet and wind layer plays ONE 2–2.5-s loop on two panned players offset by L/2 at
   the same pitch, so the channel sum repeats exactly every 0.97 s at 130 km/h (game-mix envelope autocorrelation 0.64 in
   0.6–1.6 kHz; concrete 0.89 with its 8-slab accent pattern every 40 m; cobbles 0.98). Remove the exact repetition
   WITHOUT changing the sound: per side an own loop from the SAME generator with a second seed, coprime lengths around
   4–7 s (the slab pattern with ≥ 24 slabs), each player started at a random offset, a slow level drift per side
   (Ornstein-Uhlenbeck ±1.5 dB, τ ≈ 0.8 s, like the gusts) and a small pitch offset between the sides (×1.01–1.03).
   Event textures (cobbles, gravel, slab joints) may use random-offset playback or feed events instead. File format:
   whatever keeps the sound budget (contract §4.6.9; 5.1 MB left) and exact seams – Ogg Vorbis q4–q5 is fine if the
   in-game seam check stays exact (measure). TARGET (game mix, Limousine on Kiel–Hamburg, 20 s at constant speed):
   asphalt 130 km/h (0.6–1.6 kHz), concrete 130 km/h (2.5–8 kHz), cobbles 50 km/h – no envelope autocorrelation peak
   ≥ 0.40 at lags 0.3–3 s; report every peak up to 8 s.
R2 Cobble hash (B2, a bug): AudioFeed.unit_hash() feeds djb2 keys whose last character alone changes, so every city is
   cobbled all-or-nothing (Hamburg always, Paris never). Mix the hash (murmur fmix32 on key.hash(), 32-bit mask) and prove
   it: the effective cobble and concrete shares per country/city over all stages hit the CONFIGURED values within ±0.05
   (the review's hash_check/enumeration scripts). The configured shares stay as they are (cobble_share 0.6).
R3 Slab phase and tunnel wind (B4, B12): the two slab loops between 110 and 150 km/h must never run out of phase (a
   restarted loop starts at the running loop's position) – no doubled hits; levels unchanged (slabs.db stays 3).
   road.wind.zone_db.tunnel −3 → 0 (the car's own wind noise does not drop in a tunnel; the user has not heard a tunnel).
R4 Bridge joints (B5): feed.joint_every_m becomes a table per deck type – steel: joints at both ends and between spans
   about every 100 m (the Köhlbrandbrücke in the game: about 4 instead of 12); stone: no joints at all (never concrete
   joints on stone); concrete: every 32 m. Keep the joint sounds themselves (the user liked the double hit). Prove it
   with the trigger log on the Köhlbrandbrücke, the Elbbrücken, the Venice causeway and the Paris stone arch.
R5 Peaks (B7, D29 ≤ −1 dBTP): a Modern-only limiter on MMaster after the glue compressor (AudioEffectHardLimiter,
   ceiling −2.0 dB, release 0.12 s; data audio.modern.limiter; modern_buses.gd). TARGET at master volume 1.0, true peak
   with 4× oversampling: a heavy crash at 130 km/h closing, steady top speed with road and wind, and AU-C1's worst-case
   stack each ≤ −1.0 dBTP; cruising at 130–200 km/h is not limited (gain reduction ≤ 0.5 dB). Impact layer levels stay
   unless the limiter's gain reduction during a heavy crash exceeds 3 dB – then lower only the loudest heavy layer until
   it does not. The top-speed row of the plan (engine + road + wind −15 ± 1 LUFS, measured today −14.9) goes into the plan
   and its test. Arcade's buses, its limiter and its config stay byte-identical.
R6 Variety without a new timbre (B12, B13, B14, B15): ≥ 4 variants each for glass, debris and the truck hit from the SAME
   generators with other seeds (spectrum within ±1 dB of today's file); random variant choice with ±2 dB / ±10 ms per
   layer instead of round-robin (pass-bys and crash layers); the glass layer only above ~80 km/h closing speed or with
   probability 0.4; squeal pitch per event ±5 % at random; no right-side rumble while the segment has a fuel lane
   (fuel_lane > 0); snow gets its own loop (soft crunch, no stone pings – the user has not heard snow yet).
NOT IN THIS ROUND (list them under notes_for_next for the final mix after the user played the test builds on the Steam
Deck): the reviews' timbre proposals for glass (noise grains), squeal (several voices), guard rail and truck (shorter
ring), the cobbles level (19 → 12), the slab level (3 → −3), the tyre-cavity peak, the small-speaker clack for joints and
slabs, a handheld mix, and every music mix proposal of the mix review.

DELIVER for the user (German file names and captions, ${SP}/deliver/AU-R/):
- fahrt_kiel_hamburg_vorher_nachher.mp3: the same drive and timestamps as AU-C1's fahrt_kiel_hamburg_spielmix.mp3
  (motorway asphalt → concrete, Köhlbrandbrücke, rumble strip, shoulder, guard rail, Hamburg) – first the old sound
  (reuse AU-C1's MP3 if your drive is identical; otherwise capture the old head from a copy), 2 s of silence, then the
  new one; plus the new drive alone (fahrt_kiel_hamburg_spielmix_neu.mp3). With the hash fixed, Hamburg alternates
  cobbles and asphalt – say where in the .txt.
- aufprall_abwechslung_neu.mp3 (eight heavy and medium crashes in a row: variants and the rarer glass),
  schnee_neu.mp3 (snow at 50, 90, 130 km/h), and a short A/B of the Köhlbrandbrücke joints (old 24 m / new).
- One .txt per MP3 with timestamps (what to listen for), and bericht.md: at the top a short table „Was sich geändert hat –
  worauf du achten kannst" in plain German, then the measurements (every target above, before → after).
You cannot hear: judge with measurements and say plainly that the user must judge the sound.
GATES: audio_qc.py green (seams, levels, determinism); every target above measured and reported; the spectra and
loudness of the changed layers within the limits of KEEP THE CHARACTER; check_arcade_lean OK and the frozen Arcade files
identical to v0.7.0; tools/run_tests.sh green (once, at the end); tools/golden.sh check 20 von 20.`

const AUR = `${common('AU-R', { mode: 'fresh', base: BASE }, 'content')}
${EARLY}
YOUR ROLE: AU-R – THE ONE REWORK OF THE MODERN SOUND after the user listened to the previews with headphones. Your base is
AU-C1's final head ${BASE} (origin/wip/v080-au-c1): v0.8.0 with the audio core AU-A, the engine v3 AU-B (leave the
engine sound alone), the music AU-D1/AU-D2 (title remaster, race tracks „Linke Spur", „Nachtfahrt", „Rückenwind",
interlude, stingers, UI sounds; one mix file tools/audio/music/mischung.json) and the road/tyre/wind/impact sounds of
AU-C1. You own the files of AU-C1 (tools/audio/modern/{vehicle_loops,sfx_modern}.py,
scripts/audio/modern/{road_audio,impact_audio,audio_feed,modern_audio_pan}.gd, assets/audio/modern/{vehicle,sfx}/**),
config/game_config.json → audio.modern, modern_buses.gd/modern_mix.gd (for the limiter and the plan only),
tools/audio/music/{music_lib.py,mischung.json} (for the optional keys only), their tests and docs/audio-modern.md.
Never the engine v3 sound files, the music and UI sound files, or the frozen Arcade audio (tools, sounds, buses, the
Arcade path of AudioManager).
READ FIRST: the two independent measurement reviews of this head – ${RF} (road, tyres, wind, impacts, triggering) and
${RM} (music mix and whole game mix) – and their scripts and logs in ${SP}/m1/KRITIK-FAHRBAHN/ and
${SP}/m1/KRITIK-MISCHUNG/ (copy what you reuse: const_capture.gd, ana_capture.py, hash_check.gd, trigger_log.gd,
impact_check.gd, ana_*.py, dsp.py). AU-C1's report ${SP}/deliver/AU-C1/bericht.md and its scratch scripts
${SP}/m1/AU-C1/ (drive_demo.gd, layers_demo.gd, worst_case.gd, deliver.py, media.py) made the previews the user heard –
reuse them for the new previews.
${TASK}
Push every commit to origin wip/v080-au-r. Return the result format with package "AU-R".`

const CHECK = (aur) => `${common('KRITIK-R', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT RE-MEASUREMENT OF THE SOUND REWORK AU-R. No building, no commits.
THE OBJECT: AU-R's head ${aur.commit} (origin/wip/v080-au-r; its worktree ${aur.worktree} is READ-ONLY for you). Work on
a copy as the first reviews did: cp -a the worktree without build/ and .godot, cp -a ${REPO}/.godot into the copy,
import once (godot --headless --path <copy> --import), absolute XDG_DATA_HOME for every run. AU-R's report:
${SP}/deliver/AU-R/bericht.md. The first reviews (${RF}, ${RM}) and their scripts (${SP}/m1/KRITIK-FAHRBAHN/,
${SP}/m1/KRITIK-MISCHUNG/) are your measuring tools – copy them and re-run them unchanged where possible, so that before
(head ${BASE}) and after compare 1:1.
YOU CANNOT HEAR. Numbers are measured; everything about how it sounds to a person is inferred – say so.
CHECK (rank by what the player hears most – the motorway at 100–200 km/h first):
1. Every target of the brief below, measured by you, not copied from AU-R's report: repetition peaks, hash shares, slab
   phase after speed changes across 110 km/h, bridge joints per deck, true peak at master volume 1.0 (heavy crash, top
   speed, worst-case stack), limiter gain reduction while cruising and during a heavy crash, variants and random choice,
   fuel-lane rumble, the snow loop.
2. KEEP THE CHARACTER: third-octave spectra and loudness of every changed layer at the reference speeds against head
   ${BASE} (limits in the brief); engine v3 and music files byte-identical; mischung.json values unchanged.
3. Regressions: a new artificial sound (a pure tone where there was none, clicks at new seams, a pumping limiter, zipper
   noise from the level drift), triggering on the four stages of the first review (tunnels, bridges, zones, rumble,
   cobbles only in cities), CPU per frame, leaks at exit, Arcade plays nothing new and stays byte-identical.
SEVERITY: blocker = a gate missed, or a regression the player hears; high = a target missed or the character changed
beyond the limits; medium/low = the rest.
DELIVER to ${SP}/deliver/KRITIK-R/ (German): bericht.md with a before/after table per target and the ranked findings;
nothing else.
THE BRIEF AU-R WORKED FROM (for reference):
${TASK}`

const FIX = (aur, chk) => `${common('AU-R2', { mode: 'fresh', base: aur.commit }, 'content')}
${EARLY}
YOUR ROLE: AU-R2 – FIX ROUND OF THE SOUND REWORK. Your base is AU-R's head ${aur.commit} (origin/wip/v080-au-r; its report
${SP}/deliver/AU-R/bericht.md). An independent re-measurement (${SP}/deliver/KRITIK-R/bericht.md, its scripts in
${SP}/m1/KRITIK-R/) found the findings below. Fix every blocker and high finding, the medium ones where cheap, and
re-measure each with the reviewer's method. Your files are those of AU-R, under the same rules (brief below). Update
${SP}/deliver/AU-R/ in place (previews and bericht.md; mark what changed in this round) – the user gets one set of
previews. Push every commit to origin wip/v080-au-r2. Return the result format with package "AU-R2".
FINDINGS (JSON): ${JSON.stringify(chk.findings.filter(f => f.severity !== 'low'))}
THE BRIEF OF AU-R:
${TASK}`

phase('Überarbeitung')
const aur = await agent(AUR, { label: 'klang:AU-R', phase: 'Überarbeitung', schema: BUILD_C, isolation: 'worktree' })
if (!aur || !aur.commit) { log('AU-R fehlt'); return { aur } }
log(`AU-R: ${aur.commit.slice(0, 7)} (${aur.acceptance.filter(a => a.result !== 'pass').length} offen)`)

phase('Nachmessung')
const chk = await agent(CHECK(aur), { label: 'kritik:Nachmessung', phase: 'Nachmessung', schema: FINDINGS })
const hard = chk ? chk.findings.filter(f => ['blocker', 'high'].includes(f.severity)) : []
log(chk ? `Nachmessung: ${chk.findings.length} Befunde (${hard.length} hoch)` : 'Nachmessung ausgefallen')

let fix = null
if (hard.length) {
  phase('Nacharbeit')
  fix = await agent(FIX(aur, chk), { label: 'klang:AU-R2', phase: 'Nacharbeit', schema: BUILD_C, isolation: 'worktree' })
  log(fix ? `AU-R2: ${fix.commit ? fix.commit.slice(0, 7) : '?'} (${fix.acceptance.filter(a => a.result !== 'pass').length} offen)` : 'AU-R2 fehlt')
}
return { aur, chk, fix }
