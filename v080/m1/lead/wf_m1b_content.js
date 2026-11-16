export const meta = {
  name: 'v080-m1b-content',
  description: 'v0.8.0 Modern, M1: independent art review of the vehicle models and their rework (AS1R); UI1 continues (options, chooser, showroom, Leistungstest)',
  phases: [
    { title: 'Sichtprüfung', detail: 'art review of the vehicle models, then their rework AS1R' },
    { title: 'Oberfläche', detail: 'UI1 continues from its predecessor\'s head' },
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

const as1 = {"package": "AS1", "branch": "worktree-wf_bade9e46-06a-1", "commit": "53bcc1b255c448c94953a80fca21688f690c5fb0", "worktree": "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1", "summary": "All six AS1 models exist, the validator is green and every budget holds (all numbers measured on software OpenGL). The showroom flag stays false for both player cars: the real-time picture has the richer mesh, but its paint and lighting are flatter than the Cycles sprite.\n\n- Player cars (limousine, kompakt): race level, show level and shadow caster. Lamps are recesses with depth; glass is transparent and tinted over a dark interior; the rear has a third brake light, plate frame with plate lamps, exhaust tips and badge; the front has grille depth, wipers and antenna.\n- Traffic cars (sedan, hatch, wagon): rebuilt on the smooth SmoothCar lofts. Windows, lamps and plates are cut in along their contours, so lod0, lod1 and lod2 share the same outlines and nothing crumples. All colour sets are paint values of one mesh.\n- Truck: tractor and box trailer as node groups with pivots, four liveries as paint. The rear reads at 20, 60 and 150 m, day and night.\n- Late fix: the dark hatching on the kompakt in the showroom A/B came from the shadow caster, not the mesh. The coarse hull stood 7.9 mm out of the body and its wheel caps shaded the rims. Hulls are now tucked 12 mm inside the skin.\n\nGates: sprite geometry 187 of 187 identical, full test run passed, Arcade 20 von 20 identisch, model render check OK. The tests ran one commit before HEAD; that last commit only adds an export guard and documentation, and a forced re-export afterwards left every model file byte-identical.\n\nFull report: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/bericht.md", "acceptance": [{"check": "Validator green", "result": "pass", "evidence": "Measured: python3 tools/blender/validate_models.py --report prints CHECK models OK (10 models, 180 sets, 25 with model). Budgets hold: limousine lod0 45,764 / show 99,670 / shadow 1,872; kompakt 50,080 / 107,042 / 1,872; sedan 17,695 / 5,805 / 1,123; hatch 17,317 / 5,753 / 1,136; wagon 17,888 / 5,937 / 1,103; truck 18,084 / 4,672 / 1,490. Output in deliver/AS1/pruefer_bericht.txt."}, {"check": "Contact sheets day and night with every lamp channel", "result": "pass", "evidence": "Day sheets 01_tag_spieler.jpg and 02_tag_verkehr.jpg; night sheets 03_nacht_spieler.jpg and 04_nacht_verkehr.jpg with one tile per lamp state for each vehicle (off, tail, brake, tail+brake, indicator left/right, reverse, head, front indicators). 05_lampenkanaele.jpg shows all 15 channels. I looked at the sedan and truck night tiles: every state lights the right lamp on the right side."}, {"check": "Same-camera A/B showroom sprite vs. real-time show level for both player cars, deciding the showroom flag", "result": "pass", "evidence": "06_showroom_ab.jpg, both cars, same camera. Decision: showroom = false for both. Real-time has more mesh detail (transparent glass with interior, lamp and grille depth, wipers, antenna). Missing against the sprite: clear-coat paint with environment reflections (real-time paint is flat and garish), ambient occlusion and contact shadow, reflecting rims and chrome, a soft showroom light rig. All four belong to the paint shader/renderer (R3) and the showroom (UI1), not the mesh."}, {"check": "At most 6 draw calls per traffic car at LOD0", "result": "pass", "evidence": "Measured by the validator report: sedan, hatch and wagon each 6 / 1 / 1 (lod0: body vpbr + glass, 4 wheels). The truck has 13 at lod0 (tractor 2 + 4 wheels, trailer 1 + 6 wheels); section 4.6.9 names no lod0 draw budget for heavy vehicles."}, {"check": "Geometry fixture identical (check_sprite_geometry.py after the cesprites changes)", "result": "pass", "evidence": "Measured on the final cesprites state, all sets, --jobs 2: 187 sprite sets built in 346 s, 187 identical, one of them a REIHENFOLGE line (landmarks/fernsehturm_berlin), 0 ANDERS. CHECK sprite_geometry OK. vehicles.py, designs.py and heavy.py are unchanged."}, {"check": "Byte report", "result": "pass", "evidence": "Measured mesh bytes: limousine 1,573,290; kompakt 1,742,534; sedan 260,279; hatch 256,895; wagon 269,062; truck 160,568. Together 4,262,628 B; all meshes of the game 4.18 MB of 40 MB; no textures. A forced re-export plus bake left every model file byte-identical."}, {"check": "Lamp rules, including indicators at least 60 cm2 from behind and 40 cm2 from ahead per side", "result": "pass", "evidence": "Measured with inspect_models.gd, projected cm2 per side. Indicators from behind: sedan 99, hatch 95, wagon 102 at all three levels; limousine 84; kompakt 102; truck 450. From ahead: sedan 95/95/86, hatch 112/100/95, wagon 95/90/50, truck 320. Player cars 20 and 28 from ahead, where the contract asks 15. Render check: sedan indicators 390/389, 390/390, 390/390 px from behind at lod0/1/2 (240 required); brake 2.63 x tail at every level."}, {"check": "LOD1/LOD2 keep silhouette and lamp outlines (bounds check between levels)", "result": "pass", "evidence": "New validator rule check_bounds (cars 3 cm, player 2 cm, heavy 5 cm) is green. Indicator areas are identical across lod0, lod1 and lod2 because the same contour is cut into each level. Level sheets 13_stufen_sedan.jpg, 14_stufen_hatch.jpg, 15_stufen_wagon.jpg, 17_stufen_lkw.jpg."}, {"check": "Truck rear reads at 20-150 m", "result": "pass", "evidence": "09_verfolger_lkw.jpg, game camera at 20, 60 and 150 m, day and night. Door frame, red-white contour marking (lit at night), top outline markers, lamp bar with amber indicator and plate are recognisable at every distance. At 150 m at night the tail lamps are about two pixels."}, {"check": "Complete tools/run_tests.sh", "result": "pass", "evidence": "One complete run, exit 0, 549 s: 569 unit tests with 0 failed, 64 CHECK lines OK, 0 FEHLER. It ran one commit before HEAD; the last commit adds only an export guard and documentation, and the re-export after it changed no model file."}, {"check": "Arcade identity (tools/golden.sh check)", "result": "pass", "evidence": "GOLDEN arcade: 20 von 20 identisch (151 s), run once at the end."}, {"check": "Render check of the models (tools/run_render_checks.sh modern check_models)", "result": "pass", "evidence": "1 of 1 render check files OK, 6 checks OK (material classes, lamp channels, paint codes, indicators, brake light, multimesh), on software OpenGL under Xvfb."}], "deviations": ["Traffic cars are built on the carbody.SmoothCar lofts instead of the vehicles.Car lofts, which crumpled at lod1/lod2 and let bumpers poke through. Dimensions, windows and lamps still come from cesprites.designs.", "The truck is a new 3D builder (ce3d/truck3d.py) using the dimensions of cesprites.heavy, not the box generator of the sprites.", "One truck mesh serves all four liveries through paint, paint2 and paint3; there is no tarp variant for red and green.", "Traffic lod2 drops plate, reverse light, daytime running light and sill split to stay inside 1,200 triangles; tail, brake, indicator and head lamps keep their contours.", "Player chase pictures are taken at 9 m and 30 m instead of 8 m: at 8 m the rear bumper is below the screen edge of the game camera.", "tests_total counts 569 unit tests plus 64 CHECK lines of the one complete run."], "contract_issues": ["PREMUL_ALPHA_FACTOR does not exist in the GLES3 scene shader of Godot 4.7.2 (compile error: premul_alpha undeclared). The glass uses blend_premul_alpha and premultiplies itself.", "glass.gdshader: the render_mode line (now blend_premul_alpha, depth_draw_never, cull_back) is shared between AS1 (look) and R3, so a merge conflict is possible. The instance uniforms fade and sun and the light() function are untouched.", "Grouped node names (tractor/body, trailer/wheel_0l) and the manifest key groups (pivots of tractor and trailer) are new. ModelFactory builds the parts but does not read groups, so the truck does not articulate yet.", "The contract says nothing about where the shadow caster lies. A caster outside the body skin shades its own body; the models now keep it 12 mm inside (truck 30 mm). The export stops if a car hull is not inside, but validate_models.py has no rule for it yet."], "notes_for_next": ["R3 paint shader: the cars need a clear coat with Fresnel and environment reflection over a slightly darker base tone. This is the main gap to the Cycles sprites; metallic flakes are optional after that.", "R3: rims and chrome (metallic 0.55-1.0, roughness 0.12-0.3) need an environment to reflect. Ambient occlusion and a contact shadow under the car must come from the renderer; no vertex channel is free for it.", "R3: the lit lamp parts sit up to 28 mm behind an almost clear lens (opacity 0.08-0.10) which must not darken them. Light anchors lie in the opening of the recess, up to 33 mm in front of the lit geometry.", "Renderer: tail lamps of a truck at 150 m at night are about two pixels; the glow at the light anchors (fairness rule F6) has to carry them. The truck also has two marker anchors on top of the trailer.", "RINT/R3: to articulate the truck, read groups from the manifest and turn the trailer/* parts about the trailer pivot [0, 1.19, -3.7] and the tractor about [0, 0, -3.1].", "Showroom flag: once the paint shader and the showroom light exist, repeat tools/models_contact_sheet.sh <png> --only=\"player/*\" --showroom. If real-time is at least equal, set \"showroom\": True for showroom/limousine and showroom/kompakt in tools/blender/ce3d/catalog3d.py and run export_models.py --manifest-only.", "Art review, weakest model-side points: traffic lamps are flat cut-in fields without lens or depth, the traffic rear is a nearly vertical face with a plain bumper and block-shaped plate characters, and lod2 has triangular wheel cut-outs with hexagonal wheels.", "Art review, further weak points: rims are simple, player headlights show little depth from ahead, door handles are small brackets, and the truck cab is a flat profile body without interior.", "AS2a/AS2b: new car bodies can reuse traffic3d (smooth_design, CAR_3D) and core.tuck_inside for shadow casters. Lod0 budgets are tight: the wagon has 112 triangles left of 18,000.", "CE_STATS=1 before an export prints triangles per object and per decal projection without changing files. docs/modelle.md section 13 describes the vehicle pipeline."], "quality_verdict": "What the player sees is clearly better than the wave-0 reference cars, but it is not yet the 'detailreiche Grafik' the wish describes, and the main reason is shading, not mesh.\n\nGood: the player cars have taut bodies with crisp panel gaps, lamp clusters with real depth, transparent tinted glass over a visible interior, a worked-out rear and front, and rims that now catch sunlight. From the chase camera at 9 m the rear reads cleanly by day and night. Traffic cars keep exactly the same silhouette and lamp outlines at all three levels; brake light and amber indicator are unmistakable at 8, 30 and 80 m. The truck rear reads at once from 20 to 150 m.\n\nNot yet good: the paint looks like bright plastic, with no clear coat, no environment reflections and no ambient occlusion. In the same-camera showroom A/B the Cycles sprite still looks more natural, so the showroom flag stays false for both cars. Traffic cars are clean but plain up close: flat lamps without lenses, a flat rear with a bare bumper, no interior. Traffic lod2 is angular and meant for beyond 120 m. Rims are simple; the truck cab has no curved front and no interior; one trailer mesh serves all four liveries.\n\nMissing or unproven: clear-coat paint shader and contact shadows (R3), showroom lighting (UI1), truck articulation in ModelFactory. Everything was rendered on software OpenGL through the contact-sheet rig; how it looks in the real race renderer, on a Steam Deck or on a real GPU is inferred, not measured.", "media": ["/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/06_showroom_ab.jpg – Showroom-Vergleich: links Echtzeit (Stufe show), rechts Cycles-Sprite, dieselbe Kamera, beide Spielerautos", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/01_tag_spieler.jpg – Kontaktbogen Tag: Spielerautos in Rennstufe, Showroom-Stufe und Schattenwerfer", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/02_tag_verkehr.jpg – Kontaktbogen Tag: Verkehrsautos und Sattelzug, alle Stufen und Farbsets", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/03_nacht_spieler.jpg – Kontaktbogen Nacht: Spielerautos, eine Kachel je Lampenzustand", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/04_nacht_verkehr.jpg – Kontaktbogen Nacht: Verkehrsautos und Sattelzug, eine Kachel je Lampenzustand", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/05_lampenkanaele.jpg – Prüfstreifen aller 15 Lampenkanäle", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/07_verfolger_spieler.jpg – Spielerautos aus der Spielkamera in 9 m und 30 m, Tag, Rücklicht, Bremslicht mit Blinker", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/08_verfolger_verkehr.jpg – Verkehrsmodelle aus der Spielkamera in 8, 30 und 80 m, Tag und Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/09_verfolger_lkw.jpg – Sattelzug von hinten aus 20, 60 und 150 m, Tag und Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/10_verfolger_nacht.jpg – Verkehr bei Nacht aus 30 m", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/11_review_limousine.jpg – Limousine groß: Heck, Front, Rad, Innenraum, Lampen nah, Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/12_review_kompakt.jpg – Kompakt groß: Heck, Front, Rad, Innenraum, Lampen nah, Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/13_stufen_sedan.jpg – Verkehrs-Limousine: lod0, lod1 und lod2 nebeneinander aus drei Blickwinkeln", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/14_stufen_hatch.jpg – Schrägheck: lod0, lod1 und lod2 nebeneinander", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/15_stufen_wagon.jpg – Kombi: lod0, lod1 und lod2 nebeneinander", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/16_review_lkw.jpg – Sattelzug groß: Heck, Seite, Front, Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/17_stufen_lkw.jpg – Sattelzug: lod0, lod1 und lod2 nebeneinander", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/18_review_sedan.jpg – Verkehrs-Limousine groß: Heck, Front, Seite, Lampen nah, Nacht", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/bericht.md – Vollständiger Bericht mit Zahlen, Runden, Showroom-Entscheidung und schwächsten Stellen", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/pruefer_bericht.txt – Ausgabe des Prüfers mit Dreiecken, Zeichenaufrufen und Bytes je Modell", "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1/lampenflaechen.txt – Gemessene Lampenflächen und Abstände der Lichtanker je Modell und Stufe"]}
const BASE = 'd025d1d68f5130fb0fcc8a5798d807aed9ade978'
const AUB_COMMIT = '84140023230515a502d59368dcd52e699e559366'
const CONT = {
  R1: { mode: 'continue', head: 'a8ec8b85bf5f1388d1ebbc007141c34c7ab99e00', branch: 'worktree-wf_3b561c53-566-2', oldWt: `${REPO}/.claude/worktrees/wf_3b561c53-566-2` },
  R2: { mode: 'continue', head: 'f21537c3b8ef3f37e527773852652798a1522fba', branch: 'worktree-wf_3b561c53-566-3', oldWt: `${REPO}/.claude/worktrees/wf_3b561c53-566-3` },
  UI1: { mode: 'continue', head: 'd46a06be5aecf446c93e18f21edde2b3df926fc9', branch: 'worktree-wf_bade9e46-06a-3', oldWt: `${REPO}/.claude/worktrees/wf_bade9e46-06a-3` },
}
const AS1_BRIEF = `YOUR PACKAGE: AS1 – FAHRZEUGMODELLE FÜR DEN SCHNITT (contract §6 wave 1 "AS1"; decisions D17–D24; interfaces §4.6
complete; amendment A-4; docs/modelle.md, above all its sections 4 and 9). Models: player/limousine and
player/kompakt (race mesh from the generator detail levels, show mesh, shadow mesh), traffic/sedan, traffic/hatch,
traffic/wagon (geometry decals, LOD0–2, all their colour sets as "sets" paint), traffic/truck (tractor and trailer
parts, four liveries). Prove every acceptance item (validator green; contact sheets day and night with every lamp
channel; same-camera A/B of the showroom sprite against the real-time "show" level for both player cars, which
decides the showroom flag; ≤ 6 draw calls per traffic car at LOD0; geometry fixture identical –
tools/blender/check_sprite_geometry.py after every cesprites change, "REIHENFOLGE" lines are fine, "ANDERS" is not;
byte report).
THE QUALITY BAR. The wave-0 reference cars are not good enough – look at ${SP}/deliver/FIX0/p5_kontaktbogen_tag.jpg and
p6_kontaktbogen_nacht.jpg first: blobby bodies, crumpled coarse levels, lamps as flat patches, opaque glass, no
interior, dull rims. "Feinere Modelle" is the user's explicit wish, and the player car is on screen for the whole
game, seen from behind and slightly above at 6–12 m. What a finished car needs, most-seen first:
- A clean, taut body: crisp character lines and wheel arches, smooth shading with hard edges only where metal is
  folded (split normals / marked sharp edges survive the export), correct proportions against the sprite generator's
  silhouette, panel gaps for doors, bonnet, boot and fuel flap, no dents or waves from decimation at any level.
- The rear: lamp clusters with depth (housing, lens, inner structure) whose lit areas pass the validator's lamp rules
  at every level, a third brake light, number plate with frame and lit plate lamp, bumper with diffuser/reflectors,
  exhaust tips, badge, rear window with a visible parcel shelf and headrests behind real transparent glass.
- Glass and interior for the player cars: transparent tinted glass (you own the look part of glass.gdshader, A-8;
  keep the instance uniforms and the fade untouched) over a simple dark interior – seats, headrests, dashboard,
  steering wheel on the left; traffic cars may keep dark glass with a reflective look but must not look painted.
- Wheels: multi-spoke rims with depth, brake discs behind them, tyres with a rounded shoulder and sidewall, real
  wheel arches with dark liners; nothing floating, nothing intersecting.
- Front: headlights with reflector and lens depth, daytime running lights, grille with depth, mirrors with glass,
  wipers, door handles, roof antenna.
- Coarser levels (LOD1/LOD2) keep the silhouette and the lamp outlines exactly (same outlines at all levels, bounds
  check between levels, decals cut along their contour – no saw teeth at bumper corners); they simplify, they never
  crumple. Indicators of every traffic design ≥ 60 cm² from behind and ≥ 40 cm² from ahead per side.
- The truck: a believable tractor (cab with windows, mirrors, steps, tanks, lights, mud flaps) and a box trailer
  with underrun bar, lamp bars, reflective contour marking, plates; liveries as paint sets. It is the most frequent
  obstacle of the game: its rear at 20–150 m must read at once (lamps, markings).
Stay inside the budgets of §4.6.9 – spend triangles where the camera looks (rear and sides of the player car at
LOD0; the "show" level for the vehicle selection may be generous). Use the generators' own detail levels and
design tables (cesprites, hooks only – additive, no sprite vertex may move) rather than decimating a dense mesh.
Shaders: vpbr.gdshader, model_factory.gd and modern_materials.gd belong to the renderer package R3 in this push –
do not edit them; say under notes_for_next what the cars would need from the paint shader (clear coat, flakes,
chrome …). Work in rounds: build, render the contact sheets (day, night, each lamp channel, the chase-camera view
from behind at 8 m and 30 m, the showroom A/B), LOOK at them, list the worst defects, fix, repeat – at least three
rounds for the two player cars. Set showroom: true only when the real-time show level is at least as good as the
sprite in the same-camera A/B; otherwise leave it false and say exactly what is missing.
An independent art reviewer will inspect your branch afterwards and a rework step follows – leave clear notes on
what you consider weakest.`
const REVIEW = {
  type: 'object',
  properties: {
    overall: { type: 'string' },
    models: { type: 'array', items: { type: 'object', properties: {
      model: { type: 'string' },
      versus_sprite: { type: 'string', enum: ['finer', 'equal', 'cruder'] },
      showroom_ready: { type: 'boolean' },
      defects: { type: 'array', items: { type: 'object', properties: {
        severity: { type: 'string', enum: ['high', 'medium', 'low'] }, where: { type: 'string' }, problem: { type: 'string' }, evidence: { type: 'string' }, fix: { type: 'string' } },
        required: ['severity', 'where', 'problem', 'evidence', 'fix'] } } },
      required: ['model', 'versus_sprite', 'showroom_ready', 'defects'] } },
    pipeline_issues: { type: 'array', items: { type: 'string' } },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['overall', 'models', 'pipeline_issues', 'media'],
}

const modelLane = async () => {
  const review = await agent(`${common('AS1-KRITIK', { mode: 'readonly' }, 'content')}
YOUR ROLE: INDEPENDENT ART REVIEW OF THE VEHICLE MODELS (no building). The package AS1 delivered the vehicle models of
the slice on branch ${as1.branch} (commit ${as1.commit}), worktree ${as1.worktree} – READ-ONLY for you: no edits, no
commits there. Work on a copy in your scratch folder (cp -a the worktree without build/ and without
tools/blender/_cache3d; set an absolute XDG_DATA_HOME). You make no commits, so skip the safety-copy step. A predecessor of yours made that copy
(${SP}/m1/AS1-KRITIK/wt) and was stopped by the usage limit before it had reviewed anything – reuse the copy after a
quick diff -rq of tools/blender, assets/models and assets/shaders against the worktree.
Its report: ${JSON.stringify({ summary: as1.summary, open: as1.acceptance.filter(a => a.result !== 'pass'), deviations: as1.deviations, quality: as1.quality_verdict, notes: as1.notes_for_next, media: as1.media })}
Do not trust the report – render and look yourself. You are the art director who has to answer one question for the
user: are these cars visibly FINER than the Arcade sprites, and good enough to be looked at for hours? For each of
player/limousine, player/kompakt, traffic/sedan, traffic/hatch, traffic/wagon, traffic/truck:
1. Render with tools/models_contact_sheet.sh and your own Godot scenes: the chase-camera view (from behind and above,
   8 m and 30 m, 1280×720, with the shipped shaders under a daylight rig with one shadowed sun and under a night rig),
   front and rear three-quarter views close up, side view, every LOD level at the distance it is used (40 m, 120 m)
   and enlarged, every lamp channel at night, a wireframe or flat-shaded view to judge the mesh itself.
2. Compare with the Cycles sprite of the same vehicle (assets/sprites, same camera angle) side by side, and with the
   generator's silhouette.
3. Hunt defects and name each one concretely with a picture: wrong proportions, waves or dents, faceting where the
   body should be smooth or soft edges where it should be crisp, holes, flipped or inconsistent normals, z-fighting
   or floating decals, saw-tooth decal edges, lamps without depth, lamp outlines that change between levels, LOD
   levels that crumple or pop, missing parts (mirrors, wipers, handles, exhaust, plate frame, third brake light,
   interior, brake discs, wheel-arch liners), glass that looks painted, wheels that intersect the body or float,
   shadow mesh that does not match, paint sets that look wrong, anything that would look broken in motion (wheel
   spin axis off-centre, steering pivot). Also check: validator green, budgets of §4.6.9, lamp rules, draw calls per
   car, the showroom flags (is "true" deserved, is "false" too cautious?), the geometry fixture
   (tools/blender/check_sprite_geometry.py result in the report – re-run only if you doubt it, it takes 6 minutes).
Be strict and specific: every defect needs where, what, a picture path as evidence and a fix the builder can carry
out. Rank by what the player sees most (rear of the player cars first). Put your comparison sheets into
${SP}/deliver/AS1-KRITIK/ and write bericht.md there.`,
    { label: 'kritik:AS1', phase: 'Sichtprüfung', schema: REVIEW })
  if (review) {
    const high = review.models.flatMap(m => m.defects.filter(d => d.severity !== 'low').map(d => `${m.model}: ${d.problem}`))
    log(`Sichtprüfung AS1: ${review.models.map(m => `${m.model} ${m.versus_sprite}`).join(', ')}; ${high.length} Mängel hoch/mittel`)
  } else log('Sichtprüfung AS1 ausgefallen – die Nacharbeit prüft selbst')
  const reviewText = review ? JSON.stringify(review) : 'NOT AVAILABLE – the reviewer failed. Make your own strict review first (chase camera 8/30 m day and night, close-ups, every LOD level at its distance, lamp channels, comparison with the Cycles sprites) and fix what you find.'
  const as1fix = await agent(`${common('AS1R', { mode: 'fresh', base: BASE }, 'content')}
YOUR ROLE: REWORK OF THE VEHICLE MODELS (second pass of package AS1; package id AS1R). Your fresh worktree starts
from ${BASE} = the renderer skeleton R1a merged with the AS1 head ${as1.commit} (branch ${as1.branch}). The first pass's
worktree ${as1.worktree} is READ-ONLY for you – but first copy its export cache (keyed by content, saves Blender time):
cp -a ${as1.worktree}/tools/blender/_cache3d tools/blender/
PARALLEL WORK ON THE SAME PIPELINE: the package AS1b builds the environment models at the same time from the same base.
You own the vehicle files (tools/blender/ce3d/{vehicles3d, traffic3d, truck3d, interior3d, extras3d}.py, the cesprites
car files, assets/models/player/**, assets/models/traffic/**, tools/models/contact_sheet.gd); AS1b owns
assets/models/props/** and the prop builders (ce3d props3d, veg3d, leafatlas, bake). Shared pipeline files (ce3d core,
decalgeo, lod, catalog3d, roles, export, manifest, glb; export_models.py, validate_models.py, docs/modelle.md, the
generated assets/models/manifest.json): change them only additively and backwards-compatibly, keep your catalog entries
in their own block, and list every shared-file change in your report – the lead merges both packages and regenerates
manifest.json. The renderer package R3 builds the paint, glass and chrome shaders and the vehicle layer in parallel
(vpbr.gdshader, model_factory.gd, modern_materials.gd stay R3's – report what the cars need from them).
The package brief was:
${AS1_BRIEF}
The first pass reported: ${JSON.stringify({ summary: as1.summary, open: as1.acceptance.filter(a => a.result !== 'pass'), quality: as1.quality_verdict, notes: as1.notes_for_next })}
The independent art review found: ${reviewText}
Check each defect yourself first (reject with evidence if it is wrong). Fix every confirmed high and medium defect and
the cheap low ones, most-seen first (rear of the player cars, then the traffic cars at 20–150 m, then the truck).
Re-render the reviewer's comparison views after each round and LOOK at them. Close the open acceptance items. Then
re-run: validator, check_sprite_geometry.py (if a cesprites file changed), contact sheets day and night, the showroom
A/B (and set the showroom flags honestly), export determinism (--check-keys, second bake byte-identical),
tools/run_tests.sh, tools/golden.sh check. Return the result format with package "AS1R" (the state after the rework),
rejected findings under deviations.`,
    { label: 'nacharbeit:AS1R', phase: 'Sichtprüfung', schema: BUILD_C, isolation: 'worktree' })
  if (as1fix) log(`AS1R: ${as1fix.commit ? as1fix.commit.slice(0, 7) : '?'} (${as1fix.acceptance.filter(a => a.result !== 'pass').length} offen)`)
  return { review, as1fix }
}

const uiLane = () => agent(`${common('UI1', CONT.UI1, 'content')}\nYOUR PACKAGE BRIEF (the same as your predecessor's):\nYOUR PACKAGE: UI1 – OPTIONEN, AUSWAHL, SHOWROOM, LADEBILD, LEISTUNGSTEST (contract §6 wave 2 "UI1"; decisions D31–D36;
interfaces §4.1, §4.2, §4.8; amendments A-2, A-5, A-8; docs/ui.md; prototype with a 10/10 gamepad check:
${SP}/product-ux/evidence/spike_scripts.diff and spike_tests.diff). Files: scripts/ui/screens/{options_screen,
graphics_choice_screen, benchmark_screen, title_screen, result_screen, race_result_screen}.gd, scripts/ui/{game_flow,
attract_mode}.gd, scripts/ui/widgets/{showroom_3d, car_showcase, loading_overlay}.gd,
scripts/core/{settings, gfx, gfx_self_test, screenshotter}.gd, tests/race/check_options_tabs.gd,
tests/unit/ui/test_showroom.gd, docs/ui.md, docs/grafik-modi.md – and, added by the lead for this push, the
Leistungstest runner scripts/race3d/benchmark.gd (class ModernBenchmark as specified in §4.8) with the command line
flags --bench=<scene id|all> and --bench-out=<file.json>, because the first test build for the user must contain a
working Leistungstest. Implement §4.8 except the watchdog offers (a later package), plus:
- What the user confirmed: ONE switch "Grafik: Arcade/Modern" changes picture and sound together; the sound can be
  chosen separately in the options ("Klang": Wie Grafik | Arcade | Modern); race music on by default with the Modern
  sound and switchable off, none in Arcade; a one-time chooser "GRAFIK WÄHLEN" for everyone at the first start of
  v0.8.0 (conditions D32); leaderboards shared between the modes (entries carry gfx).
- GameFlow calls AudioManager.set_profile(Settings.sound()) at boot and on Settings.sound_profile_changed (never
  during a stage), set_music_context() next to the existing set_music() calls, set_race_music() when the option
  changes – today no caller exists, so a stored "Modern" plays the Arcade sound.
- Attract demos run in the effective mode (setup.gfx only from Settings.effective_graphics()) and count their 30 s
  from RaceSession.stage_live / is_live(), not from the scene start; tests/race/check_attract*.gd pass with
  --graphics=arcade unchanged and are extended for Modern (the demo check pins content_scale_aspect == KEEP, which
  is Arcade only – Modern uses EXPAND, and GameFlow resets the aspect when it returns to the menus).
- Crash-guard question on the title (Settings.crash_guard, disarm_crash_guard()); LoadingOverlay.set_progress(p);
  gfx and gfx_fallback from the stage result into the leaderboard entry and onto the result screens.
- Gfx.watchdog_verdict judges against max(display frame time, 1/60 s) with a unit test (A-2).
- Showroom3D inside CarShowcase (SubViewport with own_world_3d in PHYSICAL pixels, key light with shadow, fill, two
  rim lights, slow turntable, materials through ModernMaterials.shared(), models through ModelDB/ModelFactory at the
  level "show", only for sets with showroom: true – today none has it, the vehicle package is working on that in
  parallel, so test with a fixture manifest and with the limousine forced; otherwise the sprite as today). Switching
  "Grafik" changes the showroom at once. Leaving Modern frees what it loaded.
- The preview pictures of the options page and the two cards of the chooser show the same road in both modes. The
  real Modern renderer is being built in parallel: ship a small tool that renders both pictures from one fixed stage
  position (Kiel–Hamburg, day) into the UI assets, run it with what exists today, and say in notes_for_next that the
  pictures must be regenerated at the end.
- The Leistungstest: three fixed 20 s autopilot scenes of graphics.benchmark.scenes with setup.gfx = "modern", fixed
  seed, result screen and user://leistungstest.json in the format of §4.8 (average and 1 %-low fps, frame time
  p95/p99, script ms, draw calls, primitives from the renderer's perf_stats(), adapter, preset, resolution,
  suggested preset). It must run with whatever Modern renderer the build contains (today the stub) and fall back
  cleanly when Modern cannot start. The user will run it on a Steam Deck and on Windows and send the file back.
Everything must be fully usable with a gamepad and on the Steam Deck: every new screen fits 1280×720 and 1280×800
with text ≥ 18 px (deliver screenshots in both sizes), focus order without traps, LB/RB for the tabs, one A confirms
the chooser. Prove every acceptance item: check_options_tabs 10/10 with real pad events; check_menu_pad 9/9,
test_steam_deck and test_menu_input unchanged; the chooser condition matrix (D32) unit-tested; settings round trip
of every new option. Any HUD or menu change must keep the Arcade goldens identical (tools/golden.sh check 20 von
20) – the existing screens look exactly as before in Arcade apart from the new options. tools/run_tests.sh is owned
by the integration in this push: if your new check files are not picked up by its existing lists, run them by hand
and say under notes_for_next what has to be hooked in. Return the result format.\n
UPDATE SINCE THE BRIEF WAS WRITTEN: the vehicle models AS1 (commit ${as1.commit}) and the engine sound AU-B (commit
${AUB_COMMIT}) are finished. Merge both into your branch early (git merge --no-edit ${as1.commit}, then
git merge --no-edit ${AUB_COMMIT}; the lead checked that both merge cleanly with your predecessor's head), so that you
can test Showroom3D with the real show level of player/limousine and player/kompakt (their showroom flag is still false
– force it in tests as the brief says) and the sound-profile switch with the real Modern engine. AU-B's notes for you:
EngineAudio3.preview(id) loads the bank on a worker task (22–75 ms) and blips once it is there; at most three banks stay
cached; frame.engine carries load (0..1). AS1's note for the showroom: the real-time paint is still flat (the paint
shader with clear coat comes from the renderer package R3 in parallel), so the showroom light rig has to carry the look;
check it with tools/models_contact_sheet.sh <png> --only="player/*" --showroom once your rig exists.`,
  { label: 'oberfläche:UI1', phase: 'Oberfläche', schema: BUILD_C, isolation: 'worktree' })

const [models, ui1] = await parallel([modelLane, uiLane])
return { models, ui1 }
