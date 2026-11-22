export const meta = {
  name: 'v080-m2-welle5-r7',
  description: 'v0.8.0 push M2, wave 5 (R7 split in three): R7a sight corridor from the real geometry (A-17), R7b landmarks/skyline/backdrop, R7c far LOD of buildings and plants (cross-fade, impostors, far light, shimmer, attachments, the reworked city houses) – each built on the RINT-M2 assembly, independently reviewed, fixed and re-checked',
  phases: [
    { title: 'Bau', detail: 'R7a Sichtkorridor, R7b Wahrzeichen/Skyline, R7c Fern-LOD Bauten und Pflanzen (at most two at a time)' },
    { title: 'Prüfung', detail: 'QA-R7a / QA-R7b / QA-R7c: independent review of each package' },
    { title: 'Nacharbeit', detail: 'FIX-R7a / -R7b / -R7c on blocker/high/medium findings' },
    { title: 'Nachprüfung', detail: 'NACH-R7a / -R7b / -R7c: focused re-check of each fix round' },
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

// M2 wave 5: R7 split in three packages on the RINT-M2 assembly, each build → independent review → fix → re-check.
// ARGS: { base: '<RINT-M2 head>', as5r2: '<AS5aR2 head>', only: ['R7a','R7b','R7c'] (optional) }
const A = args || {}
const BASE = A.base
const AS5R2 = A.as5r2
const D = (p) => `${SP}/deliver/${p}/bericht.md`

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement, 5-10 sentences' },
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
    verdict: { type: 'string', description: 'is the fixed head a sound base for the next assembly? 3-6 sentences' },
    per_finding: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, status: { type: 'string', enum: ['fixed', 'partly', 'not_fixed', 'not_checked'] },
      evidence: { type: 'string' } }, required: ['id', 'status', 'evidence'] } },
    findings: FINDINGS.properties.findings,
    gates: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'per_finding', 'findings', 'gates'],
}
const INFO = (r) => JSON.stringify({ branch: r.branch, commit: r.commit, summary: r.summary,
  open: (r.acceptance || []).filter(a => a.result !== 'pass'), deviations: r.deviations, notes: r.notes_for_next,
  look: r.look_verdict })

const SITUATION = `SITUATION OF PUSH M2 (lead): your base ${BASE} (origin/wip/v080-rint-m2) is the second M2 assembly RINT-M2
(report ${D('RINT-M2')}): the first assembly with all vehicle models, vegetation, rural buildings and the Modern sound,
the fixes of the user's first test build, then wave 3 – R4 light/night/weather, R5 tunnels/bridges/water, R6 fuel
station/border/city/start-finish/radar – and the first city buildings (AS5aR1), plus the contract amendment §11.3
(A-17 … A-22; docs/dev/v080_contract.md – READ IT COMPLETELY, it binds you). The user (German) played the first test
build and wants quality over speed; Modern has to look clearly better than Arcade, not merely different – judge by an
honest comparison with Arcade of the same simulation state. BESIDE YOU run the independent QA of RINT-M2 and its fix
round FIX-RINT on the same base (they may change props.gd, lights, shaders) and the other two R7 packages. The lead
merges FIX-RINT, R7a, R7b and R7c afterwards (RINT-M3), then the whole race Kiel – Nürnberg is checked in every condition
(QA-mid) and the user gets test build 2. FILE OWNERSHIP IN WAVE 5 (contract §5 column W5 belongs to "R7"; the lead
splits it as named in your brief): stay strictly inside your files and the lead exceptions of your brief – every other
file you touch becomes a merge conflict; where you need a change in somebody else's file, build your part so that it
works without it and write the exact change into notes_for_next. Heavy jobs (Godot renders, test suites, Blender) with
nice -n 10, one at a time, memory guard (less than 3 GB available → wait). Every fix of the first test build must keep
holding (render checks check_start_km0, check_terrain_cover incl. K1, check_light_base; unit tests
test_far_ground_water and test_props). The paint flicker the user saw once is paused at the user's request (A-21):
change nothing for it.`

const PKGS = [
  { id: 'R7a', title: 'SICHTKORRIDOR AUS DER WIRKLICHEN GEOMETRIE', brief: `YOUR ROLE: R7a – THE SIGHT CORRIDOR OF BENDS FROM THE REAL
GEOMETRY (contract §11.3 A-17, which replaces the open point of A-3/A-10; A-18 for structures). Files: the kernel
scripts/race3d/{terrain_profile,chunk_context}.gd (and road_path/chunk_streamer only if needed), tests/sim/modern_*
(modern_sight F7), the unit tests of the kernel; lead exceptions: builders/border.gd and builders/city.gd (R6's) for
the consequences below, builders/terrain.gd only if the terrain must read the new width differently. NOT yours:
builders/props.gd (R7c) – props drop through ChunkContext.in_bend_corridor(), so change the semantics there, not the
callers; if props.gd needs a change, write it into notes_for_next.
Today: terrain_profile.gd computes the corridor as a constant band of the sagitta of a corridor_chord_m = 300 m chord,
d²/8R, over a window of ±150 m around a bend (corridor_width(), line ~289, the window at ~346); ChunkContext.in_bend_corridor()
(chunk_context.gd ~216) answers for props, fences and structures. Measured by FIX-M2 (report ${D('FIX-M2')} section B-01,
probes in ${SP}/m1/FIX-M2/probe: fx_chord.gd, qa_occl.gd, qa_props.gd; sh/preview_corridor.py): the strict band drops
T4 9 of 12, T2 9/18, T1 5/13, C1 4/16, S4 3/12, T3 4/8 props within 150 m and the start oak S0; the F2 need is only
107–119 m at the mountain bends T3/T4 and above 300 m at T1, T2, C1, S0, S4 (88 % of corridor rows network-wide).
QA/AS5a found more consequences: houses missing in town bends (Lyon km 297.4, Bern km 302.7, München left side,
Nürnberg guild house, Belgrade suburb km 187.4, Hannover Mietshaus km ~142.4), 36 % of R6's city fences/hedges/walls
dropped in bends (QA-R6 B-05), 5 border roofs hang from masts because Arcade's second pillar stood in the band (A-18).
LEAD DECISIONS (A-17):
1. The corridor is the envelope of all sight lines (chords) of length L along the actual path with the camera in every
   lane; L(row) = min(300 m, F2 need at that row), the F2 need as fairness.speed_profile / modern_sight compute it
   (stopping distance at the fastest drivable speed / 0.6 + the camera offset). It runs out at the start and end of a
   bend, a short bend gets the sagitta of its real arc, a straight before a bend is free. Compute it once per stage
   (worker-safe snapshot arrays, A-3: no per-chunk state in builders), measure the cost (prepare time, memory).
2. Strict reading stays: nothing rising more than 0.5 m stands inside the envelope; ground cover ≤ 0.5 m fills it. The
   terrain uses the same envelope (corridor_width()).
3. Consequences: border.gd – where Arcade's pillar now stands outside the envelope, it stands again as a pillar (the
   mast hanger only where it is still inside); city.gd – fences/hedges/walls follow automatically, check the count
   against Arcade; city houses in town bends (N3): measure and show with pictures how many come back; F2 must hold.
4. Tests: modern_sight F7 checks the envelope (nothing taller than 0.5 m and no terrain above road level inside it); a
   unit test per case (long arc, short arc, straight before a bend, S-bend, mountain hairpin); the occlusion probe at
   T1–T4, C1, S0, S4 (test car in three lanes, 25–270 m) is never below what F2 requires; the count of props that came
   back per position, network-wide; no new terrain holes or seams (check_terrain_cover T1–T4, S1, C1, K1).
PICTURES (tools/ab_shot.sh, LOOK at each against Arcade and against the base): T1–T4, C1, S0 (start oak), S4, Lyon km
297.4, Bern km 302.7, München, Nürnberg old town, Belgrade km 187.4, Hannover km 142.4, the 5 border roofs of A-18 –
by day, --gfx-preset=high and medium; a 20-s clip through the Saragossa–Pau mountain bends.` },
  { id: 'R7b', title: 'WAHRZEICHEN, SKYLINE, HINTERGRUND', brief: `YOUR ROLE: R7b – LANDMARKS, SKYLINE AND BACKDROP (contract §6 wave 5
"R7 – Wahrzeichen, Skyline, Fern-LOD": the landmark part). Files: builders/landmarks.gd (new; contract §4.5 table:
"landmarks anchored on the path up to landmark_path_m"), a landmark shader of your own if you need one
(assets/shaders/modern/landmark.gdshader), their tests and render checks, docs section on landmarks; lead exceptions:
layers/backdrop.gd (skyline and landmark silhouettes; nobody owns it in W5) and a duck-typed skip in builders/props.gd
for the landmark stand-ins you take over (one clearly marked block, like R5/R6 did – say exactly which lines); config
graphics keys landmark_* only. NOT yours: billboard.gdshader, baked.gdshader, props.gd otherwise (R7c).
Today: landmarks reach Modern only through builders/props.gd – sprite stand-ins and, since FIX-WASSER-R/M2INT, stand-ins
for the six landmarks Arcade draws procedurally (Belgrade, Hannover, Leipzig, Dortmund, Calais, Madrid), dark_material
for prefer_proc stand-ins, landmarks lit at night up to landmark_far_m (M2INT c317625). Open points from the reviews:
N1 far landmarks are tinted for all but no test guards it; N2 a stand-in shape per procedural kind (a slim tower for
tv_tower/lighthouse instead of a wide block); B-09 distant landmarks fade with dither instead of softly (FIX-M2:
translucent variant needed); the Elbphilharmonie at night; landmark models themselves are AS6 (wave 6) – until then
the Arcade picture or the procedural stand-in is the landmark.
LEAD DECISIONS:
1. landmarks.gd places every landmark Arcade shows where Arcade shows it: on the path up to landmark_path_m (1,900 m)
   with Arcade's haze law (RoadRenderer.landmark_fade) and night floodlight; screen position within 5 % of the frame
   width at 600 m on a straight approach (contract acceptance); soft fade (no dither) in the distance.
2. Backdrop skyline and landmark silhouettes as in Arcade (A-10: below the horizon row the far ground reads as distant
   land – no bright strip, no wall pattern; check it at S1–S5 and at the ten city arrivals).
3. One interface for AS6: a landmark with a model in the manifest uses the model, otherwise the Arcade picture or the
   procedural stand-in – document it in §15/§16 of docs/renderer-modern.md.
4. Instance budget (A-19): landmarks never use instance uniforms.
PICTURES: A/B sheets of ten city arrivals (Hamburg with Michel and Elbphilharmonie, Hannover, Leipzig, Dortmund,
Nürnberg, Paris, Brussels, Belgrade, Calais, Madrid) by day, at 19:30 and at 22:00; a 20-s approach clip to Hamburg and
one to Paris; the skyline at S1–S5. LOOK at each against Arcade.` },
  { id: 'R7c', title: 'FERN-LOD VON BAUTEN UND PFLANZEN', brief: `YOUR ROLE: R7c – FAR LOD OF BUILDINGS AND PLANTS (contract §6 wave 5 "R7":
impostors as far LOD of modelled sets, LOD tuning; §11.3 A-19, A-22). Files: builders/props.gd (except the corridor
semantics in ChunkContext – R7a – and R7b's marked landmark skip block), prop_library.gd, the shaders
baked/leaves/billboard, model_factory.gd and modern_materials.gd, config graphics (except landmark_*), modern_renderer.gd/
quality.gd/prewarm.gd if needed, their tests and render checks; lead exception: one global or uniform from
environment_rig.gd (shadow end distance) if your far-light fix needs it – a few lines, marked. FIRST: merge the reworked
city houses origin/wip/v080-as5ar2 (${AS5R2}; AS5a batch 2 dutch/belgian/french/paris/swiss and a re-export of all 23
city houses; reports ${D('AS5a2')}, review ${D('KRITIK-5a2')}, rework ${D('AS5aR2')}) with --no-ff onto your base;
regenerate assets/models/manifest.json (--manifest-only), run the validator; LOOK at the Modern goldens before renewing
them in your branch (the assembly regenerates them once more).
Open points from the reviews (measured there): building level switch at 60 m changes 8–32 % of the pixels (AS5aR1,
AS5aR2: no cross-fade for buildings); thin half-timber beams shimmer 1.1–1.4 % against 0.1 % for the sprite; Haussmann
and corner house lod0 shimmer 0.9–1.1 % at 40–60 m (sprite 0.0–0.2 %), the garden-tree leaf cards 1.0–1.6 % at
100–150 m; far facades get 4–29 % brighter and their windows pale beyond the end of the real-time shadows (AS5aR2 K2:
medium ≈100 m, high ≈170 m – a renderer cause, not the models); at dusk (19:30) far fewer windows are lit in Modern than
in Arcade (AS5a1, Hamburg Kontor); the tree LOD cross-fade, the tags ground_align / ground_sink / face_road, the impostor
time-of-day relief and the windmill rotor phase (vpbr uses the origin-relative position and jumps at every 2-km rebase)
were left for R7 (M2INT note 7).
LEAD DECISIONS:
1. Buildings get the LOD dither cross-fade of the trees and a per-model lod0 distance read from model.json
   (max_dist_m; about 35 m for half-timbered houses against the beam shimmer) – A-22. The switch must not be visible in
   the clips at „Details: Mittel“ (contract acceptance).
2. Far light: beyond the shadow range buildings must not get brighter than with shadows – lower the directional part by
   a mean shadow fraction (or bake it) so that luminance from 60 to 250 m stays within ±5 % of the shadowed near look;
   the near look unchanged. Prove it with AS5aR2's k6_scene --mode=lodcol --shadow_m (${SP}/m1/AS5aR2/kt).
3. Shimmer of baked_cutout/leaf cards: a mip bias, alpha-to-coverage where the preset has MSAA, or a shorter lod0 –
   measured against the sprite at 40–150 m; no more than 2× the sprite's flicker.
4. Window light at dusk like Arcade (the law of the night windows over the hour, against Arcade's at 19:30 and 22:00).
5. Impostors as the far LOD of modelled sets where they exist, with the time-of-day relief; tree cross-fade.
6. Attachments (A-22 extension, lead decision): a model may name separate props to place with it (model.json
   "attach": [{"prop": "props/tree_beech", "offset": [x, y, z], "scale": s}] – read by props.gd, placed as ordinary
   instances with their own LOD); build and test the mechanism with a test manifest. The city houses keep their present
   in-model garden trees until a later model rework uses it; city houses may then use up to 3 surfaces where the third
   avoids drawing the whole facade as baked_cutout (record measurements of the GPU cost you can make).
7. The props.gd tags ground_align / ground_sink / face_road and the windmill rotor phase (no jump at the rebase).
8. Instance budget (A-19): no instance uniforms outside the vehicle layer; check_instance_budget* stay green.
PICTURES: city arrivals Hamburg, Nürnberg, Paris, Amsterdam, Bern, Lyon suburb by day, 19:30 and 22:00 at high and
medium; a forest stretch (Dortmund – Frankfurt km 40–60); 20-s clips driving into Paris and through a half-timbered
old town at „Mittel“ (look at the LOD switches frame by frame). LOOK at each against Arcade and against the base.` },
].filter(p => !A.only || A.only.includes(p.id))

const GATES = `GATES on your final head (commands and output in bericht.md): import clean; tests/check_scripts.gd;
tools/run_tests.sh green (full run at most twice; load-only timing failures: rerun alone and against the base in the
same run, A-11); tools/golden.sh check (20 von 20 and 17 von 17 identisch); tools/golden.sh modern-check (modern-make only
where a Modern golden changed on purpose – LOOK at the new pictures first and say so in the commit);
tools/run_render_checks.sh all (each file within the timeout of its header); tests/sim/modern_sight.gd -- --full and
tests/sim/modern_path_check.gd -- --full; a complete Modern autopilot run of a stage with your elements under Xvfb
without script errors, with perf_stats (render() ms average and max, chunk commit ms max, collect() ms, draw calls,
primitives) next to the same run on your base (llvmpipe, measured; real hardware inferred).`

const chain = async (p) => {
  const b = await agent(`${common(p.id, { mode: 'fresh', base: BASE }, 'render')}
${SITUATION}
${p.brief}
${GATES} Push every commit to origin wip/v080-${p.id.toLowerCase()}. Report and pictures in ${SP}/deliver/${p.id}/.
Return the result format with package "${p.id}": one acceptance entry per contract acceptance item of your package,
per lead decision and per gate.`,
    { label: `bau:${p.id}`, phase: 'Bau', schema: BUILD_R, isolation: 'worktree' })
  if (!b || !b.commit) { log(`${p.id} fehlt`); return { id: p.id, b } }
  log(`${p.id}: ${b.commit.slice(0, 7)} (${b.acceptance.filter(a => a.result === 'fail').length} offen)`)

  const qid = `QA-${p.id}`
  const qa = await agent(`${common(qid, { mode: 'review', base: b.commit }, 'render')}
${SITUATION}
YOUR ROLE: ${qid} – INDEPENDENT REVIEW OF PACKAGE ${p.id} (${p.title}; head ${b.commit}, branch origin/wip/v080-${p.id.toLowerCase()})
– no commits, no pushes. Its brief was:
${p.brief}
The package reports: ${INFO(b)}; its report ${D(p.id)}.
Do not trust the report – run and look yourself: (1) PICTURES with tools/ab_shot.sh at the places of the brief, by day and
at night, --gfx-preset=high and deck, against Arcade of the same simulation state AND against the base ${BASE} (nothing may
look worse than before); LOOK at every picture and say honestly where Modern is better, equal or worse than Arcade.
(2) FUNCTION: every element of the brief appears where Arcade has it, on every stage of the network (data scan,
headless builds of all instances; name the ones that fail). (3) FAIRNESS: tests/sim/modern_sight.gd -- --full and
modern_path_check.gd -- --full against the contract (F1–F7). (4) ARCADE IDENTITY AND OWNERSHIP: tools/golden.sh check;
git diff ${BASE}..${b.commit} --stat – only the package's files and the lead exceptions of its brief, no frozen Arcade
file. (5) TESTS: tools/run_tests.sh and tools/run_render_checks.sh all green; do the new tests guard their rule (break one
line per rule in a scratch copy and see the test fail)? (6) PERFORMANCE: perf_stats on a stage with the package's
elements next to the base (spikes at chunk commits, draw calls; the Steam Deck preset). Every finding needs where,
what, evidence (command + output or picture path, measured or inferred), how to reproduce and a concrete fix.
Severity: blocker = must not go into test build 2; high = the user will notice at once; medium = noticeable; low =
polish. Also list what you checked and found fine. Pictures and bericht.md into ${SP}/deliver/${qid}/.`,
    { label: `prüfung:${qid}`, phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })
  const found = qa ? qa.findings : []
  const n = (s) => found.filter(f => f.severity === s).length
  log(`${qid}: ${n('blocker')} Blocker, ${n('high')} hoch, ${n('medium')} mittel, ${n('low')} niedrig`)
  if (!qa || n('blocker') + n('high') + n('medium') === 0) return { id: p.id, b, qa }

  const fid = `FIX-${p.id}`
  const fix = await agent(`${common(fid, { mode: 'fresh', base: b.commit }, 'render')}
${SITUATION}
YOUR ROLE: ${fid} – FIXES AFTER THE INDEPENDENT REVIEW OF PACKAGE ${p.id} (${p.title}). Your base is ${p.id}'s head ${b.commit}
(origin/wip/v080-${p.id.toLowerCase()}); you own the same files and lead exceptions as ${p.id}. Its brief was:
${p.brief}
${p.id} reports: ${INFO(b)}; its report ${D(p.id)}. The independent review ${qid} found (report ${D(qid)}):
${JSON.stringify({ verdict: qa.verdict, findings: qa.findings })}
Reproduce each blocker, high and medium finding first (reject it with evidence if it is wrong), fix every confirmed
one, most-seen first, then the cheap low ones. Re-render the pictures the findings point to and LOOK at them.
${GATES} Push every commit to origin wip/v080-${fid.toLowerCase()}. Report ${D(fid)}. Return the result format with package
"${fid}": one acceptance entry per finding you handled (pass = fixed and re-checked, fail = still open, not_run =
rejected – say why), then the gates.`,
    { label: `nacharbeit:${fid}`, phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
  const game = fix && fix.commit && (fix.files_changed || []).some(f => !/^(\/|docs\/|tests\/|ARCHITECTURE|README|deliver|\(|Bericht|bericht)/.test(f))
  if (fix) log(`${fid}: ${fix.commit ? fix.commit.slice(0, 7) : '?'} (${fix.acceptance.filter(a => a.result === 'fail').length} offen, Spiel geändert: ${game ? 'ja' : 'nein'})`)
  if (!game) return { id: p.id, b, qa, fix }

  const nid = `NACH-${p.id}`
  const nach = await agent(`${common(nid, { mode: 'review', base: fix.commit }, 'render')}
${SITUATION}
YOUR ROLE: ${nid} – FOCUSED RE-CHECK of the fix round ${fid} only (head ${fix.commit}, origin/wip/v080-${fid.toLowerCase()}). No
commits, no pushes. The findings ${fid} had to handle: ${JSON.stringify(found.filter(f => f.severity !== 'low'))}
${fid} reports: ${INFO(fix)}; its report ${D(fid)}.
Do not trust the report – reproduce each finding on the new head and judge it (pictures with tools/ab_shot.sh against
Arcade and against ${b.commit}; LOOK at them); git diff ${b.commit}..${fix.commit} for side effects, files outside the
package and frozen Arcade files; tools/golden.sh check once (20 von 20, 17 von 17); the render checks and tests that
belong to the changed files; modern_sight --full if a placement changed. Return per finding fixed / partly /
not_fixed / not_checked with evidence, any new finding, and the gates you ran with their output. Pictures and
bericht.md into ${SP}/deliver/${nid}/.`,
    { label: `nachprüfung:${nid}`, phase: 'Nachprüfung', schema: RECHECK, isolation: 'worktree' })
  return { id: p.id, b, qa, fix, nach }
}

const results = await parallel(PKGS.map(p => () => chain(p)))
return { results: results.filter(Boolean) }
