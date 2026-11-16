export const meta = {
  name: 'v080-m1b-r3-as1b',
  description: 'v0.8.0 Modern, M1: vehicles/flares/signs (R3) and environment models of the slice (AS1b), both from the merged base R1a + AS1',
  phases: [
    { title: 'Fahrzeuge', detail: 'R3 – vehicle and flare layers, paint and glass look, signs' },
    { title: 'Umgebungsmodelle', detail: 'AS1b – trees, buildings and technical props of the slice' },
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
${start.mode === 'readonly' ? '' : `- SAFETY COPY: after EVERY commit run  git push origin HEAD:refs/heads/wip/v080-${pkg.toLowerCase()}  (plain push, never
  force; never push to v0.8.0 or main, never merge into them, never create tags or pull requests).
`}- RESTART PROTOCOL: the container can restart, or an account usage limit can stop you, at any moment; a successor with
  this same brief is then started (both have already happened in this push). (1) Your START instruction above says how
  to find and continue a predecessor; its background processes are gone and half-written output files may be
  incomplete. (2) Keep ${SP}/m1/${pkg}/STAND.md up to date after every step you finish: worktree path and branch,
  done / doing now / next / pitfalls, where your scratch results are.${start.mode === 'readonly' ? '' : ` (3) Commit and push work in progress at
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
- ${start.mode === 'readonly' ? 'You make no commits and change no branch.' : `Commits: sensible steps on your branch; every commit message (German subject line) ends with
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

const R1A = {"commit": "65c7560c1b601df31081095d0d243d6dceb12e55", "branch": "worktree-wf_3b561c53-566-1", "summary": "Successor run: a predecessor was killed after ~35 min (commit 7dbd654); I continued in its worktree and branch. Head 65c7560 equals origin wip/v080-r1a (hash compared), tree clean.\n\nDelivered: modern_renderer.gd skeleton with the A-7 facade and duck-typed hooks; built-in plain environment and sky; ChunkStreamer/ChunkContext.services; inc/pools.gdshaderinc; tools/ab_shot.sh; check_facade.gd, check_seam.gd \"vertrag\", adapted check_seam_render.gd, new render/check_facade_render.gd, fixtures with a \"bare\" probe renderer; docs/renderer-modern.md §9.\n\nIMPORTANT – the complete gates did NOT run on the head. They ran on 72938cd (measured): tools/run_tests.sh green (576 unit tests + 73 checks), tools/golden.sh check 20 von 20 identisch, render checks 5 of 5 files, ERGEBNIS identical on kiel_hamburg and dev_testetappe (28 keys, only gfx differs). The head differs from 72938cd in four files: the docs, check_facade.gd (tunnel part), render/check_facade_render.gd (new check), tools/ab_shot.sh (label-font fix). On the head only check_scripts, check_facade.gd (8 OK), check_facade_render.gd (5 OK) and the A/B tool ran.\n\nNever run or observed: --gfx-debug=cover; any reader of the ce_* globals; the timeout's \"does not fire while nothing is drawn\" side; an export.\n\nCorrections of my own earlier statements: \"80 checks\" in the pushed commit message of 72938cd is wrong (73); the built-in light law matches Arcade only for mid albedos in daylight (computed up to −59 % / +35 % at night), the header comment of plain_environment.gd still says otherwise.\n\nThe skeleton's picture is clearly worse than Arcade. Details: deliver/R1a/bericht.md.", "open": [{"check": "tools/run_tests.sh green once at the end", "result": "partial", "evidence": "Complete and green on 72938cd (measured: 576 unit tests, 73 checks, 0 FEHLER, 534 s) and before that on faaf3e7. NOT run on the head 65c7560, which changes docs, two test files and tools/ab_shot.sh; of those only check_facade.gd (8 OK) and check_scripts (228 scripts) were rerun. Three starts in total: one aborted by me after 3.5 min, two complete."}, {"check": "tools/golden.sh check: 20 von 20 identisch", "result": "partial", "evidence": "Measured on 72938cd with a clean tree: 'GOLDEN arcade: 20 von 20 identisch (149 s)'. Not rerun on 65c7560. An earlier 20/20 run happened on a mixed tree (a file was being edited) and is not counted."}, {"check": "tools/run_render_checks.sh all green", "result": "partial", "evidence": "5 of 5 files OK on faaf3e7 and again on the content of 72938cd just before that commit (glow 16, flip 1, check_facade_render 4, check_models 6, check_seam_render 6 - counted from the log). On the head only render/check_facade_render.gd ran (5 OK incl. the new check 'strasse')."}, {"check": "ERGEBNIS identity Arcade vs Modern (run_stage.gd, kiel_hamburg and dev_testetappe)", "result": "partial", "evidence": "Measured on 300a571 and on 72938cd: 28 keys each, only gfx differs (both ERGEBNIS lines of Kiel-Hamburg read side by side; no warning or error line in the four logs). Not rerun on 65c7560. The file is tests/race/run_stage.gd, not tests/sim/."}, {"check": "healthy()/fail_reason() incl. --gfx-debug=fail and the hooks' fail_reason()", "result": "partial", "evidence": "Observed: hook reasons 'manifest' and 'shader', 'script:layers/weather.gd', and a 0.3 s timeout firing headless ('ausfall', head); selftest:debug in check_session and render 'rueckfall' (72938cd). Not observed: that the timeout stays quiet while nothing is drawn (minimised window, sleep) - that logic has no test."}, {"check": "Built-in environment: BG_CANVAS sky, ambient from the palette, exactly ONE DirectionalLight3D with shadow, ce_* globals", "result": "partial", "evidence": "Observed on the head: one shadow-casting light, BG_CANVAS behind layer -10, fog; lit plate 99/99/99 vs Arcade 97/97/97 at noon, shadow 47/48/51; night plate 17/22/34 vs 21/25/36; tunnel state values at Bern-Mailand km 186. NOT observed: the ce_* globals (set in code, nothing in this package reads them) and --gfx-debug=cover (never run). The light law is only close to Arcade for mid albedos in daylight (computed table in the deliver folder)."}], "deviations": ["The complete gates stand on 72938cd, not on the head: two later commits changed the docs, two test files and tools/ab_shot.sh. tests_total = 576 unit tests + 73 checks of that run; render checks and golden frames are not included in the number.", "tools/run_tests.sh was started three times (one start aborted by me after 3.5 min, two complete runs); the brief allows two complete runs.", "update(view, dt) and rebased(shift) are also called on builders that have them; A-7 comments them as layer hooks, the brief lists them for layers and builders.", "While the stage is prepared the hooks get dt = 0 although the session sends the frame time; this is not in the contract.", "Kernel file builders/debug_road.gd was changed without being asked: an update() hook tints the unshaded stand-in with palette.ambient (before, the ground was day-bright at night).", "The built-in environment is two extra files (plain_environment.gd, plain_sky.gd), sets more globals than asked, gives no moonlight at night (energy 0) and is not exposed as env.", "pools.gdshaderinc has three helpers beyond the contract (ce_pools_emission, ce_pools_encode, ce_pools_to_lin).", "Additional fail reasons 'script:<file>' and a time limit graphics.modern.prepare_timeout_s (code default 120 s, counting drawn frames only); config/game_config.json was not edited.", "modern_bild and fenster_16_10 are split: exact assertions on the skeleton alone (bare probe), generic ones on the shipped renderer.", "ab_shot.sh adds shortcuts S1-S5 (S2 = km 13.6), a default shot time of 2 s and --shot-fast for the Arcade run."], "contract_issues": ["A-7 marks update and rebased as layer hooks, the package brief lists them for layers and builders: I implemented the superset.", "The brief names tests/sim/run_stage.gd; the file is tests/race/run_stage.gd.", "§4.9.2 gives no kilometre for S2 (first fuel lane): measured from the stage plan, the lane runs from km 13.52 to 15.0; the tool uses 13.6.", "A-4 says leaving Modern means ModelDB.release_all() + ModernMaterials.drop_shared(), but names no owner: nothing calls it; the renderer creates ModernMaterials.shared() in every stage and never drops it.", "§4.4.1 lists the fail reason 'timeout', §4.3 has no configuration key for it.", "D5 asks for a moon light at night; with the measured display floor the built-in fallback uses energy 0 instead. The measured night picture is darker than Arcade (road 6/13/27 vs 16/21/32).", "The self-test and the warm-up both wait for drawn frames (as the wave-0 stub did): whether a window that draws nothing stalls the preparation was reasoned about, not tried.", "ARCHITECTURE.md §15 still describes the wave-0 stub renderer; the file is locked until wave 8."], "notes": ["Integration: run tools/run_tests.sh, tools/golden.sh check and tools/run_render_checks.sh on 65c7560 - they were last complete on 72938cd.", "The header comment of scripts/race3d/plain_environment.gd states too favourable numbers for the light law ('by day within -4..+7 %', 'at night up to a quarter brighter'); computed: up to -59 % / +35 % at night. I left it because it is under scripts/; the docs §9.6 are corrected.", "The pushed commit message of 72938cd says '80 Prüfungen'; the real count is 73.", "R1: environment_rig.gd replaces the built-in environment (it must then set the ce_* globals and hold the one shadow light); layers/backdrop.gd replaces the plain sky; builders/road.gd replaces the debug road.", "R1: not in the skeleton - MSAA / 3D scale / shadow atlas per quality level, the countdown watchdog and quality_lowered (declared, never emitted), max_chunks = 18, prepare_timeout_s in the config.", "R1: layers/lights.gd must set pool_pos_r, pool_col, pool_count on every material of renderer.pool_materials() each frame and offer add_static(parent, lamps); without it pool_count stays 0.", "R3: the debug road is unshaded and takes no shadow (measured: 0 of 1,296 pixels change under a caster) - a missing vehicle shadow on it is not a bug of the vehicle layer. Positions exist only from the first update().", "All: night and tunnel pictures on the skeleton are only a background - no lights, darker than Arcade, no tunnel tube.", "All: the facade checks run 'bare' and should stay green when content files are added; check_facade 'geruest' requires that every node is freed after a stage.", "--gfx-debug=cover in the built-in environment and sky has never been run; R2's terrain cover check will be its first use."]}
const AS1 = {"package": "AS1", "branch": "worktree-wf_bade9e46-06a-1", "commit": "53bcc1b255c448c94953a80fca21688f690c5fb0", "worktree": "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1", "summary": "All six AS1 models exist, the validator is green and every budget holds (all numbers measured on software OpenGL). The showroom flag stays false for both player cars: the real-time picture has the richer mesh, but its paint and lighting are flatter than the Cycles sprite.\n\n- Player cars (limousine, kompakt): race level, show level and shadow caster. Lamps are recesses with depth; glass is transparent and tinted over a dark interior; the rear has a third brake light, plate frame with plate lamps, exhaust tips and badge; the front has grille depth, wipers and antenna.\n- Traffic cars (sedan, hatch, wagon): rebuilt on the smooth SmoothCar lofts. Windows, lamps and plates are cut in along their contours, so lod0, lod1 and lod2 share the same outlines and nothing crumples. All colour sets are paint values of one mesh.\n- Truck: tractor and box trailer as node groups with pivots, four liveries as paint. The rear reads at 20, 60 and 150 m, day and night.\n- Late fix: the dark hatching on the kompakt in the showroom A/B came from the shadow caster, not the mesh. The coarse hull stood 7.9 mm out of the body and its wheel caps shaded the rims. Hulls are now tucked 12 mm inside the skin.\n\nGates: sprite geometry 187 of 187 identical, full test run passed, Arcade 20 von 20 identisch, model render check OK. The tests ran one commit before HEAD; that last commit only adds an export guard and documentation, and a forced re-export afterwards left every model file byte-identical.\n\nFull report: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/bericht.md", "acceptance": [{"check": "Validator green", "result": "pass", "evidence": "Measured: python3 tools/blender/validate_models.py --report prints CHECK models OK (10 models, 180 sets, 25 with model). Budgets hold: limousine lod0 45,764 / show 99,670 / shadow 1,872; kompakt 50,080 / 107,042 / 1,872; sedan 17,695 / 5,805 / 1,123; hatch 17,317 / 5,753 / 1,136; wagon 17,888 / 5,937 / 1,103; truck 18,084 / 4,672 / 1,490. Output in deliver/AS1/pruefer_bericht.txt."}, {"check": "Contact sheets day and night with every lamp channel", "result": "pass", "evidence": "Day sheets 01_tag_spieler.jpg and 02_tag_verkehr.jpg; night sheets 03_nacht_spieler.jpg and 04_nacht_verkehr.jpg with one tile per lamp state for each vehicle (off, tail, brake, tail+brake, indicator left/right, reverse, head, front indicators). 05_lampenkanaele.jpg shows all 15 channels. I looked at the sedan and truck night tiles: every state lights the right lamp on the right side."}, {"check": "Same-camera A/B showroom sprite vs. real-time show level for both player cars, deciding the showroom flag", "result": "pass", "evidence": "06_showroom_ab.jpg, both cars, same camera. Decision: showroom = false for both. Real-time has more mesh detail (transparent glass with interior, lamp and grille depth, wipers, antenna). Missing against the sprite: clear-coat paint with environment reflections (real-time paint is flat and garish), ambient occlusion and contact shadow, reflecting rims and chrome, a soft showroom light rig. All four belong to the paint shader/renderer (R3) and the showroom (UI1), not the mesh."}, {"check": "At most 6 draw calls per traffic car at LOD0", "result": "pass", "evidence": "Measured by the validator report: sedan, hatch and wagon each 6 / 1 / 1 (lod0: body vpbr + glass, 4 wheels). The truck has 13 at lod0 (tractor 2 + 4 wheels, trailer 1 + 6 wheels); section 4.6.9 names no lod0 draw budget for heavy vehicles."}, {"check": "Geometry fixture identical (check_sprite_geometry.py after the cesprites changes)", "result": "pass", "evidence": "Measured on the final cesprites state, all sets, --jobs 2: 187 sprite sets built in 346 s, 187 identical, one of them a REIHENFOLGE line (landmarks/fernsehturm_berlin), 0 ANDERS. CHECK sprite_geometry OK. vehicles.py, designs.py and heavy.py are unchanged."}, {"check": "Byte report", "result": "pass", "evidence": "Measured mesh bytes: limousine 1,573,290; kompakt 1,742,534; sedan 260,279; hatch 256,895; wagon 269,062; truck 160,568. Together 4,262,628 B; all meshes of the game 4.18 MB of 40 MB; no textures. A forced re-export plus bake left every model file byte-identical."}, {"check": "Lamp rules, including indicators at least 60 cm2 from behind and 40 cm2 from ahead per side", "result": "pass", "evidence": "Measured with inspect_models.gd, projected cm2 per side. Indicators from behind: sedan 99, hatch 95, wagon 102 at all three levels; limousine 84; kompakt 102; truck 450. From ahead: sedan 95/95/86, hatch 112/100/95, wagon 95/90/50, truck 320. Player cars 20 and 28 from ahead, where the contract asks 15. Render check: sedan indicators 390/389, 390/390, 390/390 px from behind at lod0/1/2 (240 required); brake 2.63 x tail at every level."}, {"check": "LOD1/LOD2 keep silhouette and lamp outlines (bounds check between levels)", "result": "pass", "evidence": "New validator rule check_bounds (cars 3 cm, player 2 cm, heavy 5 cm) is green. Indicator areas are identical across lod0, lod1 and lod2 because the same contour is cut into each level. Level sheets 13_stufen_sedan.jpg, 14_stufen_hatch.jpg, 15_stufen_wagon.jpg, 17_stufen_lkw.jpg."}, {"check": "Truck rear reads at 20-150 m", "result": "pass", "evidence": "09_verfolger_lkw.jpg, game camera at 20, 60 and 150 m, day and night. Door frame, red-white contour marking (lit at night), top outline markers, lamp bar with amber indicator and plate are recognisable at every distance. At 150 m at night the tail lamps are about two pixels."}, {"check": "Complete tools/run_tests.sh", "result": "pass", "evidence": "One complete run, exit 0, 549 s: 569 unit tests with 0 failed, 64 CHECK lines OK, 0 FEHLER. It ran one commit before HEAD; the last commit adds only an export guard and documentation, and the re-export after it changed no model file."}, {"check": "Arcade identity (tools/golden.sh check)", "result": "pass", "evidence": "GOLDEN arcade: 20 von 20 identisch (151 s), run once at the end."}, {"check": "Render check of the models (tools/run_render_checks.sh modern check_models)", "result": "pass", "evidence": "1 of 1 render check files OK, 6 checks OK (material classes, lamp channels, paint codes, indicators, brake light, multimesh), on software OpenGL under Xvfb."}], "deviations": ["Traffic cars are built on the carbody.SmoothCar lofts instead of the vehicles.Car lofts, which crumpled at lod1/lod2 and let bumpers poke through. Dimensions, windows and lamps still come from cesprites.designs.", "The truck is a new 3D builder (ce3d/truck3d.py) using the dimensions of cesprites.heavy, not the box generator of the sprites.", "One truck mesh serves all four liveries through paint, paint2 and paint3; there is no tarp variant for red and green.", "Traffic lod2 drops plate, reverse light, daytime running light and sill split to stay inside 1,200 triangles; tail, brake, indicator and head lamps keep their contours.", "Player chase pictures are taken at 9 m and 30 m instead of 8 m: at 8 m the rear bumper is below the screen edge of the game camera.", "tests_total counts 569 unit tests plus 64 CHECK lines of the one complete run."], "contract_issues": ["PREMUL_ALPHA_FACTOR does not exist in the GLES3 scene shader of Godot 4.7.2 (compile error: premul_alpha undeclared). The glass uses blend_premul_alpha and premultiplies itself.", "glass.gdshader: the render_mode line (now blend_premul_alpha, depth_draw_never, cull_back) is shared between AS1 (look) and R3, so a merge conflict is possible. The instance uniforms fade and sun and the light() function are untouched.", "Grouped node names (tractor/body, trailer/wheel_0l) and the manifest key groups (pivots of tractor and trailer) are new. ModelFactory builds the parts but does not read groups, so the truck does not articulate yet.", "The contract says nothing about where the shadow caster lies. A caster outside the body skin shades its own body; the models now keep it 12 mm inside (truck 30 mm). The export stops if a car hull is not inside, but validate_models.py has no rule for it yet."], "notes_for_next": ["R3 paint shader: the cars need a clear coat with Fresnel and environment reflection over a slightly darker base tone. This is the main gap to the Cycles sprites; metallic flakes are optional after that.", "R3: rims and chrome (metallic 0.55-1.0, roughness 0.12-0.3) need an environment to reflect. Ambient occlusion and a contact shadow under the car must come from the renderer; no vertex channel is free for it.", "R3: the lit lamp parts sit up to 28 mm behind an almost clear lens (opacity 0.08-0.10) which must not darken them. Light anchors lie in the opening of the recess, up to 33 mm in front of the lit geometry.", "Renderer: tail lamps of a truck at 150 m at night are about two pixels; the glow at the light anchors (fairness rule F6) has to carry them. The truck also has two marker anchors on top of the trailer.", "RINT/R3: to articulate the truck, read groups from the manifest and turn the trailer/* parts about the trailer pivot [0, 1.19, -3.7] and the tractor about [0, 0, -3.1].", "Showroom flag: once the paint shader and the showroom light exist, repeat tools/models_contact_sheet.sh <png> --only=\"player/*\" --showroom. If real-time is at least equal, set \"showroom\": True for showroom/limousine and showroom/kompakt in tools/blender/ce3d/catalog3d.py and run export_models.py --manifest-only.", "Art review, weakest model-side points: traffic lamps are flat cut-in fields without lens or depth, the traffic rear is a nearly vertical face with a plain bumper and block-shaped plate characters, and lod2 has triangular wheel cut-outs with hexagonal wheels.", "Art review, further weak points: rims are simple, player headlights show little depth from ahead, door handles are small brackets, and the truck cab is a flat profile body without interior.", "AS2a/AS2b: new car bodies can reuse traffic3d (smooth_design, CAR_3D) and core.tuck_inside for shadow casters. Lod0 budgets are tight: the wagon has 112 triangles left of 18,000.", "CE_STATS=1 before an export prints triangles per object and per decal projection without changing files. docs/modelle.md section 13 describes the vehicle pipeline."], "quality_verdict": "What the player sees is clearly better than the wave-0 reference cars, but it is not yet the 'detailreiche Grafik' the wish describes, and the main reason is shading, not mesh.\n\nGood: the player cars have taut bodies with crisp panel gaps, lamp clusters with real depth, transparent tinted glass over a visible interior, a worked-out rear and front, and rims that now catch sunlight. From the chase camera at 9 m the rear reads cleanly by day and night. Traffic cars keep exactly the same silhouette and lamp outlines at all three levels; brake light and amber indicator are unmistakable at 8, 30 and 80 m. The truck rear reads at once from 20 to 150 m.\n\nNot yet good: the paint looks like bright plastic, with no clear coat, no environment reflections and no ambient occlusion. In the same-camera showroom A/B the Cycles sprite still looks more natural, so the showroom flag stays false for both cars. Traffic cars are clean but plain up close: flat lamps without lenses, a flat rear with a bare bumper, no interior. Traffic lod2 is angular and meant for beyond 120 m. Rims are simple; the truck cab has no curved front and no interior; one trailer mesh serves all four liveries.\n\nMissing or unproven: clear-coat paint shader and contact shadows (R3), showroom lighting (UI1), truck articulation in ModelFactory. Everything was rendered on software OpenGL through the contact-sheet rig; how it looks in the real race renderer, on a Steam Deck or on a real GPU is inferred, not measured.", "media": ["/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/06_showroom_ab.jpg – Showroom-Vergleich: links Echtzeit (Stufe show), rechts Cycles-Sprite, dieselbe Kamera, beide Spielerautos", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/01_tag_spieler.jpg – Kontaktbogen Tag: Spielerautos in Rennstufe, Showroom-Stufe und Schattenwerfer", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/02_tag_verkehr.jpg – Kontaktbogen Tag: Verkehrsautos und Sattelzug, alle Stufen und Farbsets", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/03_nacht_spieler.jpg – Kontaktbogen Nacht: Spielerautos, eine Kachel je Lampenzustand", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/04_nacht_verkehr.jpg – Kontaktbogen Nacht: Verkehrsautos und Sattelzug, eine Kachel je Lampenzustand", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/05_lampenkanaele.jpg – Prüfstreifen aller 15 Lampenkanäle", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/07_verfolger_spieler.jpg – Spielerautos aus der Spielkamera in 9 m und 30 m, Tag, Rücklicht, Bremslicht mit Blinker", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/08_verfolger_verkehr.jpg – Verkehrsmodelle aus der Spielkamera in 8, 30 und 80 m, Tag und Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/09_verfolger_lkw.jpg – Sattelzug von hinten aus 20, 60 und 150 m, Tag und Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/10_verfolger_nacht.jpg – Verkehr bei Nacht aus 30 m", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/11_review_limousine.jpg – Limousine groß: Heck, Front, Rad, Innenraum, Lampen nah, Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/12_review_kompakt.jpg – Kompakt groß: Heck, Front, Rad, Innenraum, Lampen nah, Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/13_stufen_sedan.jpg – Verkehrs-Limousine: lod0, lod1 und lod2 nebeneinander aus drei Blickwinkeln", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/14_stufen_hatch.jpg – Schrägheck: lod0, lod1 und lod2 nebeneinander", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/15_stufen_wagon.jpg – Kombi: lod0, lod1 und lod2 nebeneinander", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/16_review_lkw.jpg – Sattelzug groß: Heck, Seite, Front, Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/17_stufen_lkw.jpg – Sattelzug: lod0, lod1 und lod2 nebeneinander", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/18_review_sedan.jpg – Verkehrs-Limousine groß: Heck, Front, Seite, Lampen nah, Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/bericht.md – Vollständiger Bericht mit Zahlen, Runden, Showroom-Entscheidung und schwächsten Stellen", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/pruefer_bericht.txt – Ausgabe des Prüfers mit Dreiecken, Zeichenaufrufen und Bytes je Modell", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/lampenflaechen.txt – Gemessene Lampenflächen und Abstände der Lichtanker je Modell und Stufe"]}
const BASE = 'd025d1d68f5130fb0fcc8a5798d807aed9ade978'
const SKEL = `The skeleton R1a is the base of every renderer package: commit ${R1A.commit} (branch ${R1A.branch}). What it delivers and leaves open:
${JSON.stringify(R1A)}
Use tools/ab_shot.sh for every picture judgement (Arcade | Modern of the same state). The other renderer
packages work in parallel and you will not see their files: R1 = modern_renderer.gd,
environment_rig.gd, quality/prewarm/perf_probe, builders/{road, roadside}.gd, layers/{backdrop, lights, overlay}.gd,
road shader; R2 = builders/{terrain, props}.gd, layers/far_ground.gd, prop_library.gd, terrain/far_ground/billboard/
baked/leaves shaders; R3 = layers/{vehicles, flares}.gd, vehicle_pose3d, sign_atlas, sign_canvas, builders/signs.gd,
sign/flare/vpbr/glass shaders, model_factory.gd, modern_materials.gd. Only R1 edits modern_renderer.gd, the kernel
files, race_session.gd and the "graphics" section of config/game_config.json; R2 and R3 only ADD their files and
report what they need changed. Everything must also work when the other packages' files are missing.
After this push the lead's assembly step (RINT) merges R1, R2 and R3 and makes them work together.`
const PACKAGES = [
  { id: 'R1', prompt: `YOUR PACKAGE: R1 – RENDERER-KERN: road, environment, camera, streaming, warm-up (contract §6 wave 1 "R1"; decisions
D1–D13; interfaces §4.4, §4.5, §4.10; amendments A-2, A-3, A-4, A-6, A-7). Implement all outputs and prove every
acceptance item (curve parity bounds as amended: 8 px and 27 px). Points that matter:
- Road: asphalt per road type with ALL paint in the shader (edge and lane lines, dashes 6/12 m and 3/6 m, fuel-lane
  wedge and separator, start/finish checker, crosswalks), shoulders, median, curbs, sidewalks, fractional lane
  transitions; guardrails with posts and reflectors, delineators. Fine detail is the point of this mode: believable
  asphalt (grain, wear lanes, patched seams, tyre marks near braking zones are welcome if cheap), crisp anti-aliased
  paint at grazing angles (derivative-based edges, no shimmer at distance), retro-reflective line paint and reflectors
  in the headlight cone at night, soft contact of guardrail posts with the ground. Road shader includes
  inc/pools.gdshaderinc and is registered with add_pool_material().
- EnvironmentRig (replaces the skeleton's fallback): sun/moon with shadows per preset (exactly one shadow-casting
  DirectionalLight3D, D5), ambient, depth fog with the fog laws F4, palette-driven for every hour and weather, the
  ce_* globals (linear light values through ModernMaterials.light_value(); respect the night floor of A-4), the
  small Sky resource as reflection source (D7), post path pinned (D6). Backdrop layer: the existing RaceBackdrop at
  any aspect ratio on canvas layer −10 with the true horizon row. Lights layer: player headlight spots, omni pool,
  analytical pools (player cone, traffic cones from view, static lamps through add_static(parent, lamps) of A-7) set
  on all pool_materials() once per frame. Overlay layer. Quality (apply the Gfx levels: shadows, scale, MSAA,
  details, effects; nothing gameplay-relevant is ever toggled – Rule 9), prewarm (cold-cache warm-up check),
  perf_probe (frame-time median/p95, counters), countdown watchdog with Gfx.watchdog_verdict as it is (UI1 owns
  gfx.gd and fixes the 120 Hz verdict), quality_lowered wired into the session.
- graphics.modern.max_chunks = 18 in the config (A-3). Kernel changes need a new tests/sim/modern_sight.gd -- --full
  and modern_path_check.gd -- --full run (fairness F1–F3, F7 must stay green; never relax a limit).
- Daylight probes within 10 % of Arcade at S1 are a floor, not the goal: tune the light so that the picture has depth
  (soft shadows of guardrails, posts and later trees and cars; a believable sky gradient; distance haze), at every
  hour of the day palette. Deliver A/B pictures S1–S5 plus dawn, dusk and night on the open Autobahn.
Notes from wave 0: render(view) is also called while preparing (frozen start view); the session sets
content_scale_aspect = EXPAND before the HUD is built; nothing may depend on per-frame GPU state (use view.time);
"-s" scripts must not name RaceRenderers statically; the first streamer update costs 77–114 ms (behind the loading
overlay); the engine keeps the 3D render buffers after the first Modern stage (+7.4 MB, part of the baseline).` },
  { id: 'R2', prompt: `YOUR PACKAGE: R2 – GELÄNDE, REQUISITEN, FERNBODEN (contract §6 wave 1 "R2"; decisions D14, D16, D21–D24; interfaces §4.5,
§4.6.7; amendments A-3, A-4, A-7). Implement all outputs and pass the terrain gate (check_terrain_cover ≤ 0.2 % at
T1–T4, S1, C1; no void, no visible ribbon edge, no underside) and every other acceptance item. Points that matter:
- Terrain: ribbon with verge and ditch, mild relief outside the sight corridor, two-tone scenery bands with the
  outskirts → centre blend, valley-floor edge; far-ground layer that also covers the 12 m gap at medial axes and the
  hole at the centre of tight bends (A-3). A terrain shader with real surface detail instead of flat colour: grass
  with fine procedural variation and mowing/field structure per scenery, verge and gravel strip at the road edge,
  earth in the ditch, snow cover from ce_snow, wetness from ce_wet, distance fade into the far ground; includes
  inc/pools.gdshaderinc and is registered with add_pool_material() (through ctx.services.renderer when present).
  F7 with the shipped relief must stay green (tests/sim/modern_sight.gd).
- Props: MultiMesh per mesh and chunk (mirrored node, D24) standing on ctx.ground(), LOD ranges from the levels,
  impostors, sprite stand-ins (billboard) for every set without a model – today only tree_oak, farmhouse,
  streetlight and michel have models, so the stand-ins decide how Kiel–Hamburg looks until the environment models
  arrive: light them from the scene (sun colour and direction, ambient, night), give them a contact shadow on the
  ground, and tune sun_min/sun_max for baked sprite lighting. Check ModelFactory.multimesh_parts() and the mirrored
  node in a REAL MultiMesh first (never rendered that way in wave 0). A prop model is placed like a vehicle (local
  −Z along the road, the side the sprite shows faces +Z, origin = sprite anchor). Props beyond the clamped ribbon are
  dropped; inside the bend corridor (ctx.in_bend_corridor) no vegetation, only ground cover of at most 0.5 m once
  such models exist (A-3) – build the mechanism (a config list of set ids allowed there), leave the list empty.
  Static lamps of prop models (street lights: their "lights" anchors with dir) are registered per chunk through
  ctx.services.renderer.add_lamps(parent, lamps) (A-7) for light pools and the far-field glow.
- ModelDB: request(sets, lods, self) in prepare(), missing() → stand-in or fail_reason "manifest",
  release_all(self) when done; ModernMaterials.shared().
- Budgets: ≤ 1,100 terrain triangles per chunk, ≤ 2 draw calls per prop set and chunk; build() on worker threads uses
  ctx snapshot arrays only. Deliver A/B pictures T1–T4, S1–S3, C1 and top views of the terrain at T1–T4.` },
  { id: 'R3', prompt: `YOUR PACKAGE: R3 – FAHRZEUGE UND SCHILDER (contract §6 wave 1 "R3"; decisions D8, D12–D15, D17–D20; fairness F5, F6;
interfaces §4.5, §4.6.2–§4.6.7; amendments A-4, A-7). Implement all outputs and prove every acceptance item. Points
that matter:
- Vehicle layer, data-driven by the manifest (models exist today for player/limousine and traffic/sedan; the asset
  package delivers more in parallel – a new model must appear without a code change; sets without a model are drawn
  as a correctly sized, shaded box with paint, lamps and a shadow, never a missing car). Pose from two path points so
  yaw and pitch follow the road; own heading from the lateral speed; player terms (steer × 3°, understeer × 6°, roll
  ≤ 2.5°, blinking through visible); wheels spin and steer (left wheels are the right mesh turned 180°: spin sign
  flips); LOD by path distance (40 m / 120 m, lod_for_distance may answer ModelDB.IMPOSTOR); lamps through
  lamp_a/lamp_b (tail = night or tunnel, brake, indicators with the 0.72 s period from view.time, beacons); the sun
  mask; path-distance fade exactly as Arcade's _item_alpha (F5); shadow caster or blob shadow per preset;
  articulated trucks and buses from their parts. Footprint = collision box ± 0.3 m.
- Flare layer: Arcade's minimum sizes (F6) so that a brake light or an indicator is never smaller than in Arcade;
  flares sit a little along lights[].dir; add_static(parent, lamps) of A-7 for static lamps with a far-field glow
  beyond the distance where the lamp geometry is smaller than a pixel; occlusion by the depth buffer (a car behind a
  crest or a truck shows 0 px – check_occlusion).
- The look of the cars in the race is yours (vpbr and glass shaders, ModelFactory, ModernMaterials): paint with a
  clear coat that reflects the sky (Sky reflection source of the environment), metallic flake, chrome, rubber, glass
  with reflection, lamps that glow without clipping to white (lamp_energy / lamp_gain are tuned for a picture without
  a glow pass, A-4), a soft contact shadow under every car at every preset. The player car is on screen all the
  time: its rear three-quarter view at 6–12 m is the most-seen picture of the mode. glass.gdshader: you own the
  instance uniforms and the fade; the asset package may tune the look of the glass – keep its part untouched.
- Signs: every sign texture of a stage pre-rendered in prepare() by the frozen SignPainter into SubViewports and kept
  as mipmapped ImageTexture (headless: placeholders; prepare_pending() until done; no SubViewport or texture created
  during the drive – counter); quads with real posts in the cross-section plane, wall-mounted variants,
  retro-reflection in the headlight cone; every sign kind Track can emit is drawn.
- ≤ 40 µs per car and frame at 23 cars; no per-frame allocations in the hot path. Never name a class of another
  package of this push; reach layers through renderer.layer(id) and has_method.
Deliver A/B pictures: the player car from behind at S1 (day) and at night, dense traffic, a truck overtaking a truck,
indicator and brake light at 50/150/300 m, signs at S1–S5.` },
]

const AS1NOTE = `UPDATE SINCE THE BRIEF WAS WRITTEN: the vehicle-model package AS1 is finished and is part of your base
(merge commit ${BASE} = R1a ${R1A.commit} + AS1 ${AS1.commit}). Models now exist for player/limousine and player/kompakt
(race level, show level, shadow caster) and for traffic/sedan, traffic/hatch, traffic/wagon and traffic/truck (lod0–lod2;
the truck as tractor and trailer node groups with pivots in the manifest). An independent art review and a rework of
these models (AS1R) run in parallel – they change meshes and the ce3d/cesprites files, not your files; a new manifest
must keep working without a code change. What AS1 reports for you (quality verdict, contract issues, notes):
${JSON.stringify({ summary: AS1.summary, quality: AS1.quality_verdict, contract_issues: AS1.contract_issues, notes: AS1.notes_for_next })}
Its pictures: ${AS1.media.slice(0, 6).join(' ; ')}`
const AS1B = `YOUR PACKAGE: AS1b – UMGEBUNG FÜR DEN SCHNITT (contract §6 wave 2 "AS1b"; decisions D17–D24; interfaces §4.6; amendments
A-3 and A-4; docs/modelle.md). Your base ${BASE} is the renderer skeleton R1a merged with
the vehicle package AS1 (${AS1.commit}, branch ${AS1.branch}). First copy AS1's export cache (keyed by content, saves
Blender time): cp -a ${AS1.worktree}/tools/blender/_cache3d tools/blender/ . AS1's notes: ${JSON.stringify(AS1.notes_for_next)}
PARALLEL WORK ON THE SAME PIPELINE: the vehicle models get an art review and a rework at the same time (package AS1R,
branch wip/v080-as1r, same base). AS1R owns the vehicle files (tools/blender/ce3d/{vehicles3d, traffic3d, truck3d,
interior3d, extras3d}.py, the cesprites car files, assets/models/player/**, assets/models/traffic/**,
tools/models/contact_sheet.gd); you own assets/models/props/**, assets/models/landmarks/** if you touch them, and the
prop builders (ce3d/props3d.py, veg3d.py, leafatlas.py, bake.py). Shared pipeline files (ce3d core, decalgeo, lod,
catalog3d, roles, export, manifest, glb; export_models.py, validate_models.py, docs/modelle.md, the generated
assets/models/manifest.json): change them only additively and backwards-compatibly, keep your catalog entries in
their own block, and list every shared-file change in your report – the lead merges both packages and regenerates
manifest.json. The renderer package R2 (terrain, props builder with PropLibrary, sprite stand-ins, the billboard,
baked and leaves shaders) is still in progress on branch wip/v080-r2: for pictures of your models in the race you may
merge it into a throwaway branch in a second worktree under your scratch folder (never into your package branch);
otherwise show the models in your own scene.
Models (assets/models/props/…): tree_oak, tree_birch, bush_round, bush_low, farmhouse, barn, haybale, wind_turbine,
windmill, power_pylon, streetlight, delineator, fuel_station, fuel_pump, radar_camera, customs_booth – the sets a
player sees in the first 75 km of Kiel–Hamburg (check which sprite sets the stage really emits with the Track
generator and add any that is missing from this list; say which). tree_oak, farmhouse and streetlight exist as
wave-0 reference models and are to be brought up to the bar below. Also deliver ground cover of at most 0.5 m for the
insides of bends (A-3): a low bush and grass tufts as their own sets, and name their set ids for the props builder.
Prove every acceptance item (validator green; contact sheets day and night; card trees inside the budget with
impostors; an A/B sheet of S1–S3 without a sprite stand-in in the first 75 km – as far as the props builder of the
parallel renderer workflow is available; otherwise show the models in your own scene on a ground plane at the
camera distances of the game: 15, 40, 100 and 250 m beside a road).
THE QUALITY BAR ("detailreiche Grafik, feinere Modelle"): these props fill most of the picture.
- Trees and bushes: a believable crown silhouette from every side (no visible card planes, no see-through crown
  against the sky), leaf cards with alpha-tested detail and soft shading (normals bent outward), a real trunk and
  main branches, sway from ce_wind, snow/wet response where the shader offers it, LOD levels and an impostor that do
  not pop in colour or size; several variants per species through seed/scale/rotation rather than one clone.
- Buildings (farmhouse, barn, windmill, fuel station, customs booth): real depth instead of painted walls – roof
  overhang, window reveals and frames, doors, gutters, chimney; texel density ≥ 26 px/m on road-facing walls; bake
  ambient occlusion into the atlas (the wave-0 atlas holds colour only and looks flat); windows that light up at
  night through the lamp channel 12; the back and the far side are not blank.
- Technical objects (wind turbine with turning rotor through ce_time, power pylon with lattice read at distance and
  sagging cables to the next pylon if cheap, street light with a "lights" anchor and dir, delineator with
  reflectors, fuel pump, radar camera): correct scale against the sprite object size, thin parts that do not shimmer
  (keep minimum thickness, use the cut-out class with mipmap-safe alpha where a lattice is needed – it is the first
  end-to-end run of the cut-out path: test it).
- No auto_lod on meshes with lamp channels; every model inside the budgets of §4.6.9; stand-ins stay for every other set.
Shaders baked/leaves/billboard belong to the renderer package R2 in this push – do not edit them; report what you
need. Work in rounds: build, render, LOOK, list the worst defects, fix, repeat. Run check_sprite_geometry.py after
every cesprites change, export determinism (--check-keys, second bake byte-identical), tools/run_tests.sh and
tools/golden.sh check at the end. Return the result format: every acceptance item as its own entry.`

const [r3, as1b] = await parallel([
  () => agent(`${common('R3', { mode: 'fresh', base: BASE }, 'render')}\n${SKEL}\n${AS1NOTE}\nYOUR PACKAGE BRIEF:\n${PACKAGES.find(p => p.id === 'R3').prompt}\nReturn the result format: every acceptance item of your package as its own entry with pass/fail and evidence.`,
    { label: 'bau:R3', phase: 'Fahrzeuge', schema: BUILD_R, isolation: 'worktree' }),
  () => agent(`${common('AS1b', { mode: 'fresh', base: BASE }, 'content')}\n${AS1B}`,
    { label: 'modelle:AS1b', phase: 'Umgebungsmodelle', schema: BUILD_C, isolation: 'worktree' }),
])
if (r3) log(`R3: ${r3.commit ? r3.commit.slice(0, 7) : '?'} (${r3.acceptance.filter(a => a.result !== 'pass').length} offen)`)
if (as1b) log(`AS1b: ${as1b.commit ? as1b.commit.slice(0, 7) : '?'} (${as1b.acceptance.filter(a => a.result !== 'pass').length} offen)`)
return { r3, as1b }
