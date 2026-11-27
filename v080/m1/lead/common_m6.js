
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

// R7d "Freie Strecke" – DRAFT of the brief (lead, 22.11.); assembled into m6_body.js once the R7 results are in.
const R7D_WHY = `WHY THIS PACKAGE EXISTS (lead decision after QA-RINT-BILD F-02, severity high; ${SP}/deliver/QA-RINT-BILD/bericht.md
§F-02, pictures bilder/S1_00.jpg, S3_00.jpg, S1_DECK_00.jpg, S1_busch_links.jpg): on the open motorway – where the player
spends most of every race – Modern shows almost Arcade's picture: the same flat sky with Arcade's cloud sprites (the
canvas backdrop of D7), tree groups of nearly the same shape, the road a flat grey, the verge and fields barely
different. Only the grass texture and the steel guardrail are new. The user's wish ("das gesamte Spiel einer deutlichen
grafischen Überarbeitung unterziehen … Detailreiche Grafik … bessere Lichteffekte") is NOT met there. Your benchmark:
a player who switches the mode on the open motorway (S1, S3, Deck S1) recognises Modern AT FIRST GLANCE and finds it
clearly more beautiful – by day, at dusk, at night, in rain and in snow – without anything the player reacts to becoming
harder to see.`

const R7D_SCOPE = `WHAT TO BUILD – ordered by the share of the screen it covers (measure the shares at S1/S3 yourself first and say
which of these is missing, which exists but is invisible at the chase camera, and why; road.gdshader and
inc/ground.gdshaderinc already contain wear, patches, fields and furrows that the QA could not see):
1. SKY (about 35–45 % of the frame): a canvas sky shader (assets/shaders/modern/sky2d.gdshader, pulled forward from R8,
   contract wave 7; prototype ${SP}/engine-probe/evidence/prototypes/sky_clouds.gdshader and t_sky.gd) that replaces
   RaceBackdrop.draw_sky and Arcade's cloud sprites IN MODERN ONLY: layered fbm clouds with light and shade from the
   sun's direction (state.sun_pos, environment_rig's sun – sky, light and shadows must agree), fair-weather cumulus on
   a clear day, a closed grey deck in rain and snow, coloured clouds at dawn and dusk, moonlit clouds and stars at night,
   a bright hazy band at the horizon, a sun glow. Cover and colours from the palette and the weather of the simulation
   state (Arcade's cloud cover per weather and hour is the reference for HOW MUCH sky is clouded). Deterministic: a
   function of the simulation state and view.time, never TIME (goldens, Rule 10); drift slowly with the wind (ce_wind).
   Silhouettes, skylines and landmarks (R7b's work in backdrop.gd/landmarks.gd) stay in front of it, unchanged. The
   reflection Sky resource of D7 follows the new sky's mean colours (vehicles and wet road mirror the same sky).
   Cost: measure per preset; if needed render the cloud field at reduced resolution or refresh it every few frames
   (clouds move slowly) – the Deck preset keeps it.
2. CLOUD SHADOWS (what makes a landscape look real at first glance): soft, large, slowly drifting shadow patches from
   the same cloud field on the terrain, the far ground and the scenery props (trees, buildings). Never on vehicles,
   signs or their lights. On the road surface either none (fading in beyond the paved edge) or at most a soft dimming
   that keeps the marking contrast ratio and leaves the road at ≥ 0.85 × its lit luminance – choose by pictures (a sunlit
   band along the road that never sees a cloud looks fake; a dark road hides nothing only if the contrast holds) and
   justify it with numbers. Only by day with clouds; none under a closed deck (rain/snow: diffuse light).
3. ROAD SURFACE (about 25–30 %): make the asphalt read as a real motorway at the chase camera and up to about 150 m:
   polished/darker wheel tracks, resurfaced sections with a different tone and a seam, patches, crack sealing, the joints
   of concrete slabs where a motorway is concrete (choose per country/road type and say why), worn paint, dirt toward
   the edges, a little sheen at low sun. Inside Arcade's luminance band of each road type (mean ± 6 %), and marking
   contrast at 20/60/120 m at least 0.9 × Arcade's by day and night, dry and wet (Rule 9 – markings, road edges and
   guardrails are things the player reacts to). Wet: water stands in the wheel tracks (R4's wet law stays the base).
4. VERGE, MEADOW AND FIELDS (about 15–20 %): richer ground at the chase camera: mown verge vs. longer grass, wildflowers
   in season colours of the scenery, field parcels with crop rows that run in their own direction, farm tracks, hedgerow
   lines along field borders (decorative props only outside the A-17 envelope; ground cover ≤ 0.5 m – props/cover_grass,
   props/cover_bush – may fill the corridor, A-10/A-17), soft colour variation at 50–500 m. Nothing may make the far
   ground below the horizon brighter than Arcade's fog law (A-10: no bright strip, no wall pattern).
5. RELIEF: gentle rolling land beyond the A-17 envelope where the scenery is not flat by nature (the North German plain
   is gently undulating, not a table) – terrain_profile relief OUTSIDE the envelope only; sight_corridor.gd (R7a) and
   the envelope stay exactly as they are; F7 and the occlusion probe must stay as R7a left them.
6. TREES AND SHADE: per-instance variation of the tree models (hue, size, lean – within the placement's tint, A-19 via
   the MultiMesh colour, no instance uniforms), visible shadows of trees and bushes on the grass at „Mittel“ and „Hoch“,
   wind sway where the leaves shader allows it; nothing new inside the envelope – a larger or leaning tree counts
   with its real AABB in the footprint of A-24 (check_props_footprint stays 0).
7. AERIAL PERSPECTIVE – ONLY WITHIN F4: static scenery is never fogged more than in Arcade at the same road point (F4,
   depth fog 0.45 … 1.0 × visibility). Haze may live in the sky's horizon band and may shift the HUE of far scenery toward
   the horizon colour, but never lower its contrast below what Arcade's fog gives at that distance; vehicles, signs and
   their lights are never touched (F5/F6). If you find F4 forbids something the look needs, report it as a contract issue
   with pictures – do not bend it.`

const R7D_RULES = `RULES FOR THIS PACKAGE
- You build on the third M2 assembly (RINT-M3) and are the only renderer package running: you may change
  environment_rig.gd, layers/backdrop.gd (the sky part only; R7b's skyline and landmark code unchanged), the new
  sky2d.gdshader, road.gd/road.gdshader, terrain.gd/terrain.gdshader/far_ground (layer and shader), inc/ground*.gdshaderinc,
  terrain_profile.gd (relief outside the envelope), leaves/baked/billboard shaders for cloud shadows and variation,
  props.gd/prop_library.gd for ground cover density and per-instance variation, config graphics (new levels per preset),
  docs. NOT: vehicles, lights/flares, models and their assets, sight_corridor.gd, the fairness tests' thresholds, the
  frozen Arcade files (Rule 1).
- „Details“/„Effekte“ levels may scale your additions down for the Deck/Niedrig presets but never what the player
  reacts to (Rule 9). The Steam Deck preset must keep the sky and the cloud shadows (they ARE the first glance).
- tests/golden/modern_slice.* belongs to the integration (A-18): do not regenerate it; list which of the six pictures
  changed and why.
- Show what you change, A/B against Arcade AND against your base, at S1, S3, S0, S4, T2, Deck S1, at 08:00, 12:00,
  19:30, 22:00, clear, rain and snow (at least S1 and S3 in all seven), plus two 20-s clips on the open motorway (day
  clear; dusk) side by side with Arcade. LOOK at every picture. Say plainly per picture whether Modern is now
  recognisable at first glance and where it is still Arcade's picture.`

const R7D_GATES = `GATES on your final head: import clean; tests/check_scripts.gd; tools/run_tests.sh green (A-11 for load-only timing);
tools/golden.sh check 20 von 20 and 17 von 17 (once); tools/run_render_checks.sh all (F4–F6 and the night/wet checks
included); tests/sim/modern_sight.gd -- --full and modern_path_check.gd -- --full; the A-17 occlusion probe at T1–T4,
C1, S0, S4 unchanged against your base; a new render check that guards your rules (marking contrast ≥ 0.9 × Arcade at
20/60/120 m on your new road surface, cloud shadows never on road/vehicles, the far-ground fog law of F4); perf_stats of
complete autopilot runs of Kiel–Hamburg at deck, medium and high next to your base in the same session (render() ms
mean/max, the sky's own cost, draw calls, primitives, memory; llvmpipe measured, Deck inferred) inside §4.10; ERGEBNIS
identity Arcade vs Modern on kiel_hamburg (Rule 3).`

