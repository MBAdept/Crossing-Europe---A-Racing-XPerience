export const meta = {
  name: 'v080-m2-zusammenbau',
  description: 'v0.8.0 push M2, first assembly: merge the finished early content (all vehicle models, vegetation, rural buildings/bridge parts/ships, the reworked Modern sound) onto the first test build, then merge the fixes of the delivered first test build (start, Elbe, landmarks, night pylons), then independent QA with two lenses, one fix round and a focused re-check',
  phases: [
    { title: 'Zusammenbau', detail: 'M2INT: merges AS2R, AS3R, AS4R and the sound head onto ZS1; conflicts, exports, tests, A/B' },
    { title: 'ZS1-Merge', detail: 'M2ZS1: merges the delivered first test build 39849f0 (start fix, Elbe, landmark stand-ins, dark pylons) into the assembly; conflicts, gates, builds' },
    { title: 'Prüfung', detail: 'QA-M2-BILD (picture, fairness, performance) and QA-M2-SYSTEM (Arcade identity, sound, pipeline, robustness)' },
    { title: 'Nacharbeit', detail: 'FIX-M2: confirmed blocker/high/medium findings, gates again' },
    { title: 'Nachprüfung', detail: 'NACH-M2: focused re-check, only if the fix round changed the game' },
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

// M2, first assembly: M2INT merges the finished early content onto the first test build (ZS1) → QA with two lenses →
// FIX-M2. ARGS: { base: '<v0.8.0 head after ZS1 + contract §11.2>', zs1: '<QA1 head>', as4r: '<AS4R head>' | null,
//   sound: '<last sound head>' , soundNote: '<what the sound head is>', notes: '<extra lead notes>' }
const A = (args && args.base) ? args : {"base": "350b071661ad25ae4b91cbf2d81a4ec1121c0cb8", "zs1": "92ece73fc8bca9782a1e72f3f71b007ed96641f7", "as4r": "09f679b07770946e29027f72457b9ab13846a42e", "sound": "f2536878c0f426e44caeb522a94ceb3adf234955", "soundNote": "AU-R4 head (contains AU-D2, AU-C1, AU-R, AU-R2 and AU-R3; its focused independent re-check KRITIK-R3 is still running – if it finds something, the lead merges a later delta)", "notes": "TIMING AND THE START FIX: until the lead writes the file /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/ZS1_FERTIG (one line: the final commit of the corrected first test build), the start fix of the user's first test build runs beside you on the critical path (branches wip/v080-fix-zs1 and wip/v080-fix-zs1r, an independent check of the exported builds): run EVERY heavy job (Godot runs, Blender exports, test suites, renders) with nice -n 19 and one process at a time; once the file exists, nice -n 10 as usual. Before your final gates wait until ZS1_FERTIG exists (check it every 10–15 minutes while you do other work; expected by about 08:00 UTC), then merge the commit it names with --no-ff (German message). It fixes the start of every stage in Modern (road path before z = 0 so the camera stands 9 m behind the car, the player car visible in the countdown; scripts/race3d/road_path.gd, layers/vehicles.gd, builders/gantry.gd lamp-rim shadows, a new render check 'Start bei km 0', the Modern golden modern_start_mittel) and possibly boats on dry ground. Resolve conflicts, regenerate the Modern goldens once after this merge (after looking at the pictures), and run all gates on the merged head. If ZS1_FERTIG does not exist by 12:00 UTC, say so in your result and finish without that merge.", "zs1final": "39849f0263921f798da4326b83dff30d83a947d2"}
const BASE = A.base
const AS4R = A.as4r || null
const SOUND = A.sound || '3600eb76c136d5c2c66537675c87511e3518b0ba'
const SOUND_NOTE = A.soundNote || 'AU-R2 head (the acceptance AU-R3/KRITIK-R2 of the sound may still run; its later delta is merged afterwards)'
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

const MERGES = [
  `AS2R  = origin/wip/v080-as2r (c7546c1)  all vehicle models – 37 models for all 180 vehicle sets: the five player cars
          with interiors, transparent glass and rims (AS2a), the trucks in three types, the bus and the police (AS2b),
          reworked after an independent art review (AS2R; reports ${D('AS2R')}, review ${D('KRITIK-2')})`,
  `AS3R  = origin/wip/v080-as3r (638debc)  vegetation and nature – 18 trees (nine species × 2 variants), bushes, heather,
          rocks a/b, cliff (AS3 ${D('AS3')}, review ${D('KRITIK-3')}, rework AS3R ${D('AS3R')})`,
  AS4R ? `AS4R  = origin/wip/v080-as4r (${AS4R})  rural buildings, street furniture, bridge parts, ships – house, church,
          factory, shop, old-town house, blocks A/B, office tower, houseboat, ferry, bridge lamp, pylon, truss portal,
          windmill windows (AS4 ${D('AS4')}, review ${D('KRITIK-4')}, rework AS4R ${D('AS4R')})` : null,
  `SOUND = ${SOUND}  the Modern sound of M2 – ${SOUND_NOTE}: race tracks 2–3, interlude, stingers, UI sounds (AU-D2
          ${D('AU-D2')}); road, tyres, wind, impacts and a Modern-only limiter (AU-C1 ${D('AU-C1')}, reworked after the
          user's headphone verdict „solide", music „sehr gut": AU-R ${D('AU-R')}, AU-R2 ${D('AU-R2')}, AU-R3
          ${D('AU-R3')}, AU-R4 ${D('AU-R4')}; independent acceptance ${D('KRITIK-R2-MESS')}, ${D('KRITIK-R2-CODE')},
          re-check ${D('KRITIK-R3')})`,
].filter(Boolean).join('\n  ')

const LEAD = `LEAD NOTES FOR M2INT (decisions of the lead; measured facts from the reports and trial merges):
1. Trial merge by the lead (git merge-tree, chained in this order onto FIX1's head 28e4e8e – QA1 added goldens, test
   hooks and build-only changes on top, re-check on your base): AS2R conflicts in assets/models/manifest.json,
   assets/models/traffic/truck/{lod0_trailer,lod1_body,lod2_body}.res and model.json, docs/modelle.md,
   tools/blender/ce3d/catalog3d.py, tools/blender/export_models.py, tools/models/contact_sheet.gd; AS3R then in
   docs/modelle.md and export_models.py; AS4 (the base of AS4R) in manifest.json, docs/modelle.md, export_models.py; the
   sound only in docs/audio-modern.md (FIX1 rewrote two sentences of §1/§2 about the Klang setting – keep FIX1's text and
   the sound branch's new sections).
2. Trucks: RINT-B (9eac32f) added lamp channel 15 "retro" (contour tape and triangle reflectors light up in the
   player's low beam; roles.py SURFACE_CHANNELS += retro; validator LAMP_CHANNELS 16) and re-exported traffic/truck;
   AS2b/AS2R rebuilt the heavy vehicles as three truck types (truck, truck_transport, truck_tarp) + bus (heavy3d) +
   police (police3d). Resolution: take AS2R's builders, re-apply "retro:%.2f" % TAPE_NIGHT to every retro-reflective
   surface of ALL heavy types (red/yellow contour tape, triangle reflectors; bus and police reflectors if they have
   any; AS2R made the SUV reflectors visible – check their channel), keep RINT-B's roles.py and validator change, then
   tools/blender/export_models.py --check-keys and re-export ONLY what it names (props must stay byte-identical unless a
   merged prop package changed them), regenerate assets/models/manifest.json with --manifest-only (never hand-merge
   the manifest), run the validator, and prove export determinism (a second bake byte-identical). The Blender caches
   of the content packages speed up re-exports – copy them without overwriting (cp -an) into your
   tools/blender/_cache3d: AS2R .claude/worktrees/wf_72970c4d-66e-4/tools/blender/_cache3d (58 MB), AS3R
   .claude/worktrees/wf_aad8d49e-fb4-4/tools/blender/_cache3d (35 MB), AS4R .claude/worktrees/wf_aad8d49e-fb4-6/
   tools/blender/_cache3d (21 MB) – read only, never work in those worktrees.
3. contact_sheet.gd: combine all of AS2a (showroom AgX), AS2b (--arcade for traffic/police/heavy, beacon tile), AS2R
   (race look really applied: create the vpbr/glass materials before _apply_look), RINT-B (--showroom with STUDIO_LOOK)
   and AS3 (in-process set for variants without one). catalog3d.py and export_models.py: the union of all entries.
   docs/modelle.md: the union, one consistent numbering.
4. Tests made outdated by the content (you own them now): tests/race3d/check_vehicles.gd "kasten" expects model-less
   sets – none exist any more: use a test manifest with one model-less set; "leistung" counts the lazy first build of a
   level (34 → 35): build all levels at spawn if that is cheap (measure) or count only cars new in the window – timing
   load-robust (A-11). tests/unit/race3d/test_props.gd assumes props/tree_beech has no model – apply AS3's tested patch
   ${SP}/deliver/AS3/vorschlag_test_props_fuer_R2.diff (7/7 pass).
5. Memory, instances, size: every vehicle set is a model now, so the vehicle stand-in sheets must no longer load in
   prepare() – check it; texture memory against the Arcade race of the same stage (budget + 60 MB, A-6) on Kiel–Hamburg
   and on a city stage; the instance census with RINT-B's probe ${SP}/m1/RINT-B/probe/census_probe.gd
   (INSTANCE_BUDGET 128 of the vehicle layer); the export size with tools/pck_report.py against the download budget
   (the whole download about 280 MB at most; the sound is 19.0 of 23 MB).
6. Look after the content change (measure, fix what is cheap, list the rest): the far-level albedo constants
   TRAFFIC_GLASS_FAR, truck3d.GLASS_FAR, FAR_PLATE (heavy3d FAR_PLATE #c4c4c1 vs traffic #a2a2a0) and CHECK_MEAN_EXP
   against today's LOOK with AS2R's probes (${SP}/m1/AS2R/kritik/probe.sh, bin/winmean.py, platemean.py, bandmean.py,
   buswin.py – copy them, never commit them); LOD pops with RINT-B's cross-fade on (SUV and sports car 28–30 % at
   120 m, sedan 14 % at 40 m, police/be 38 % at 120 m, bus 22 % at 180 m before it); the metallic flakes of the GT at
   race distance (KRITIK-2 A4, 83 sparkle px/frame): couple them to fwidth or set flake_strength 0 in the race look;
   showroom flags with RINT-B's studio look (candidates kombi, limousine, sportwagen, gran_turismo; kompakt only if its
   yellow is right) – set showroom: true only where the same-camera A/B is at least as good as the sprite; the vehicle
   LOOK (exposure, clear coat, fill) in one place (ModernMaterials) read by the vehicle layer, the contact sheet and
   the showroom (A-13).
7. AS3R/AS4R items that belong to this merge (reports ${D('AS3R')}, ${D('AS4R')}): tree_olive/tree_olive_b lod1 is
   +5…+8 % brighter than lod0 at the swap (AS3R regression after its gates) – lift its lod1 and re-export; seed variants
   reference their species' leaves.png through variant_of – prove that the exported game (pck) loads them (a Modern
   stage with olives/cypresses from the Windows and the Linux export); AS4R's hook in cesprites/props_buildings.py
   changes the cache key of the builder "building" (AS1b models): --check-keys names them, re-export them and show
   that the files stay byte-identical; the AS1b buildings (farmhouse, customs hut, fuel station) still have vpbr
   channel-12 window panes that are brown/blue by day – move them into the night-light atlas like AS4R did (A-16) if
   that is cheap (props3d.py shares its cache key with AS3's bushes: re-export both, prove determinism), else list it;
   the ferry is never mirrored (mirror_left would turn its bow); houseboats and ferries only where the ground under
   them is water (A-16; the start fix below may already have done it for the stand-ins – keep one rule for models and
   stand-ins); the pylon is now one level with half fans of ±36 m whose cables end beside the deck – check it on the
   Köhlbrandbrücke in the race (drive over it, ≤ 40 m, by day and night): no cable over a lane; scaling it in height by
   height_m / 88.8 only if that is a one-line change of the props builder, else R5 (A-16). Window light is balanced at
   emit_energy 1.6 (A-16) – keep it. NOT yours (R7/R4 later): the tree LOD cross-fade, the tags ground_align /
   ground_sink / face_road, the impostor time-of-day relief, the bend-corridor rule, the rotor phase of the windmill
   (vpbr uses the origin-relative position and jumps at every 2-km rebase – list it).
8. Sound in the game: the Modern profile plays the new road, tyre, wind and impact layers with engine v3 and the
   Modern limiter; the MusicDirector rotates race tracks 1–3 with stingers and the interlude; UI sounds in the Modern
   menus; the Arcade sound stays byte-identical; tools/audio/qc/audio_qc.py over all folders green; quitting leaves no
   "leaked at exit".
9. QA1 created Modern goldens of the slice (tests/golden/modern_slice.md5): the new models change those pictures –
   regenerate them deliberately after you have LOOKED at the new pictures, and say so in the commit and the report.
${A.notes ? `10. ${A.notes}` : ''}`

const INFO = (r) => JSON.stringify({ branch: r.branch, commit: r.commit, summary: r.summary,
  open: (r.acceptance || []).filter(a => a.result !== 'pass'), deviations: r.deviations, notes: r.notes_for_next,
  look: r.look_verdict })

phase('Zusammenbau')
const m2 = await agent(`${common('M2INT', { mode: 'fresh', base: BASE }, 'render')}
YOUR ROLE: M2INT – FIRST ASSEMBLY OF PUSH M2 (contract §6 waves 3–5; §11.2 A-9 … A-16). Your base is ${BASE}
(origin/wip/v080-vertrag): QA1's head ${A.zs1 || '?'} = branch v0.8.0 = the user's first test build (Zwischenstand 1;
reports ${SP}/deliver/QA1/bericht.md and ${SP}/deliver/gate1/bericht.md) plus the lead's contract commit §11.2 – read
§11.2 completely before you start. The early content of M2 was built in parallel
on older heads, each with an independent review and a rework. Merge with --no-ff in this order (German messages,
trailer as above):
  ${MERGES}
${LEAD}
YOU NOW OWN EVERY FILE OF THIS PUSH. Make it one consistent game:
- After each merge: import clean, tests/check_scripts.gd, the unit tests of the merged area (filter of run_tests.sh).
- A/B with tools/ab_shot.sh at S1–S5, T1, T4, C1 (19:30), N1 (night, snow) and N2 (rain), --gfx-preset=high and the
  preset this machine picks, plus the player cars kombi, sportwagen and gran_turismo at S1; two 30-s A/B clips side by
  side with the HUD (the start of Kiel–Hamburg; a stretch with forest and villages, e.g. Dortmund – Frankfurt km 121
  or Hamburg – Hannover). LOOK at every picture against Arcade AND against ZS1 (${SP}/deliver/gate1/,
  ${SP}/deliver/RINT-B/) and improve what is cheap in light, materials and composition; write an honest list: what is
  now better than Arcade, what is still worse or unfinished, what the new models changed.
GATES on your final head (commands and output in bericht.md): import clean; tools/run_tests.sh green;
tools/golden.sh check 20 von 20; tools/run_render_checks.sh all; tests/sim/modern_sight.gd -- --full and
tests/sim/modern_path_check.gd -- --full; python3 tools/blender/validate_models.py --report; export determinism
(export_models.py --check-keys, a second bake byte-identical); check_sprite_geometry.py; audio_qc.py all folders;
ERGEBNIS identity Arcade vs Modern (tests/race/run_stage.gd) on kiel_hamburg, dev_testetappe (night, rain) and
saragossa_pau (snow); a complete Modern autopilot run of Kiel–Hamburg and of one stage with a city finish under Xvfb
without script errors, with perf_stats (render() ms average and max, chunk commit ms max, draw calls, primitives,
memory – llvmpipe, measured; real hardware inferred) next to ZS1's numbers; texture memory (A-6); tools/build_linux.sh
and tools/build_windows.sh succeed with the pck report inside the size budget, and the Windows build starts a Modern
stage under Wine (wine64, wineserver -w between runs, TMPDIR unset). Push every commit to origin wip/v080-m2int.
Deliver the A/B sheets, the two clips and bericht.md in ${SP}/deliver/M2INT/. Return the result format with package
"M2INT", one acceptance entry per merge, per lead note and per gate.`,
  { label: 'zusammenbau:M2INT', phase: 'Zusammenbau', schema: BUILD_R, isolation: 'worktree' })
if (!m2 || !m2.commit) { log('M2INT fehlt'); return { m2 } }
log(`M2INT: ${m2.commit.slice(0, 7)} (${m2.acceptance.filter(a => a.result === 'fail').length} offen)`)

// ---- ZS1 merge (added by the lead after M2INT finished without it: ZS1_FERTIG came after M2INT's deadline) ----
const ZS1F = A.zs1final
const RECHECK = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'is the fixed head a sound base for the next M2 packages? 3-6 sentences' },
    per_finding: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, status: { type: 'string', enum: ['fixed', 'partly', 'not_fixed', 'not_checked'] },
      evidence: { type: 'string' } }, required: ['id', 'status', 'evidence'] } },
    findings: FINDINGS.properties.findings,
    gates: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'per_finding', 'findings', 'gates'],
}
const ZS1_REF = `ZS1, the first test build (Zwischenstand 1 = commit ${ZS1F}, origin/v0.8.0, delivered to the user today;
archives in ${SP}/deliver/ZS1/; its pictures in ${SP}/deliver/FIX-ZS1/, ${SP}/deliver/FIX-WASSER/bilder/, ${SP}/deliver/FIX-WASSER-R/bilder/
and ${SP}/deliver/NACH-WASSER/bilder/; older pictures of the same line in ${SP}/deliver/gate1/ and ${SP}/deliver/RINT-B/)`

phase('ZS1-Merge')
const z = await agent(`${common('M2ZS1', { mode: 'fresh', base: m2.commit }, 'render')}
YOUR ROLE: M2ZS1 – MERGE THE DELIVERED FIRST TEST BUILD INTO THE M2 ASSEMBLY. Your base is M2INT's head ${m2.commit}
(origin/wip/v080-m2int). M2INT merged AS2R, AS3R, AS4R and the sound onto 92ece73 + the lead's contract commit, but NOT
the fixes that went into the first test build afterwards (its lead note 10: the marker file came after its deadline).
M2INT reports: ${INFO(m2)}; its report ${D('M2INT')}.
The user now has ${ZS1_REF}. Its fixes on top of 92ece73:
  FIX-ZS1 (3a23cb8; report ${D('FIX-ZS1')}): the player car is visible in the countdown and at LOS at Arcade's place – the
    run-up before the start line (piece -1), the player car in the countdown, lamp rings without shadows; render check
    "Start bei km 0" (check_start_km0) and unit tests of the run-up.
  FIX-WASSER (0ad9012; ${D('FIX-WASSER')}): far ground = min(lowest road − 4 m, lowest water − 0.3 m) in
    scripts/race3d/layers/far_ground.gd; unit test test_far_ground_water; Modern golden S4 renewed.
  FIX-WASSER-R (39849f0; ${D('FIX-WASSER-R')}): scripts/race3d/builders/props.gd – stand-ins for the six landmarks that
    exist only as Arcade's procedural drawing (Belgrade, Hannover, Leipzig, Dortmund, Calais, Madrid); dark_material for
    prefer_proc stand-ins (the Köhlbrandbrücke pylon sprite's light layer glowed white at night); check_terrain_cover
    position K1 with a far-ground limit; the terrain-plan dump through FarGround.target_height().
  Independent checks of that line: ${D('QA-ZS1')}, ${D('QA-WASSER')}, ${D('NACH-WASSER')}.
Merge origin/wip/v080-fix-wasser-r (${ZS1F}) with --no-ff (German message, trailer as above). Known overlaps:
- far_ground.gd: M2INT fixed the Elbe on its own (its commit b341df8). Keep ONE rule. The ZS1 rule is the one the user
  has and it is guarded by test_far_ground_water and K1 – take parts of b341df8 only where they cover more (say which
  and why), and make both tests, K1 and every terrain_cover position pass.
- props.gd: keep both sides. With AS4R's pylon model the stand-in's dark_material may no longer apply to the pylon –
  check the Köhlbrandbrücke at 22:00 (the pylons must not be brighter than Arcade's; measure the pylon area the way
  FIX-WASSER-R did). Arcade blinks a red aviation light on the pylon: add it as a lamp if that is cheap, else list it.
  The landmark stand-ins must still appear on every approach into the six cities (FIX-WASSER-R's unit test).
- M2INT lists the render check light_base (shadows) as red until ZS1 – it must be green after the merge.
- The Modern goldens (tests/golden/modern_slice.md5/.env): regenerate them with tools/golden.sh modern-make only after
  you have LOOKED at the new pictures; say so in the commit and the report.
- docs (renderer-modern*.md, qa-v080.md, modelle.md …): the union of both sides, one consistent text.
PICTURES (A/B with tools/ab_shot.sh; LOOK at each against Arcade AND against the delivered ZS1 pictures): the standing
start of Kiel – Hamburg (countdown and 1.5 s after LOS, --gfx-preset=medium and deck), the Köhlbrandbrücke km 78.1 and
78.9 by day and at 22:00 (high and deck), the Holtenauer Hochbrücke, Belgrade km 199.8 (landmark stand-in). With the new
models nothing there may be worse than in the delivered ZS1: the car in the countdown, the water under the bridges, the
pylons at night.
GATES on your final head (commands and output in bericht.md): import clean; tests/check_scripts.gd; tools/run_tests.sh
green; tools/golden.sh check 20 von 20 and 17 von 17; tools/golden.sh modern-check; tools/run_render_checks.sh all
(including check_start_km0, terrain_cover with K1, light_base); tests/sim/modern_sight.gd -- --full and
tests/sim/modern_path_check.gd -- --full; tools/build_linux.sh and tools/build_windows.sh with the pck report inside the
size budget; tools/smoke_modern.sh on the Linux export (plain and DRIVER=opengl3_es) and on the Windows export under
Wine. Push every commit to origin wip/v080-m2int (a fast-forward from ${m2.commit}). Report and pictures in
${SP}/deliver/M2ZS1/. Return the result format with package "M2ZS1": one acceptance entry per ZS1 fix (does it still
hold after the merge?), per conflict and per gate.`,
  { label: 'zs1:M2ZS1', phase: 'ZS1-Merge', schema: BUILD_R, isolation: 'worktree' })
if (!z || !z.commit) { log('M2ZS1 fehlt – keine Prüfung ohne die Korrekturen des Testbuilds'); return { m2, z } }
log(`M2ZS1: ${z.commit.slice(0, 7)} (${z.acceptance.filter(a => a.result === 'fail').length} offen)`)
const HEAD = z.commit

const LENSES = [
  { id: 'QA-M2-BILD', prompt: `LENS: PICTURE, FAIRNESS, PERFORMANCE. Judge what the player sees in Modern against Arcade of the same
simulation state (tools/ab_shot.sh) at S1–S5, T1–T4, C1, N1, N2, U1 and DEV, and in motion (10–20 s clips with the
autopilot at 60 fps fixed; look at single frames): the new vehicle models (every player car from behind at 8 and 30 m,
traffic at 20/60/150 m by day and at night: lamps, indicators, brake lights, beacons, the retro-reflective truck contour
in the low beam, LOD swaps, sitting on the road, wheels), the new vegetation (species read like their sprites, LOD swap
at 60 m, impostors, fog, at dusk and night), the new buildings, bridge parts and ships (where Arcade draws them, size,
colour, windows by day and night, LOD), shadows, light at every hour, the curve camera. Compare with ${ZS1_REF}:
nothing may look worse than in ZS1 – above all the car at the start, the water under bridges, the pylons at night. Fairness:
re-run tests/sim/modern_sight.gd -- --full and modern_path_check.gd -- --full and compare F1–F7 with the contract; a car
or a sign must never be visible later or smaller than in Arcade (taller tree models next to bends!). Performance:
perf_stats over a complete Kiel–Hamburg autopilot run per preset (low, medium, high) on llvmpipe next to ZS1's numbers,
spikes during chunk commits, memory over 20 minutes of driving (leaks), warm-up time and texture memory; say what real
hardware would need (inferred).` },
  { id: 'QA-M2-SYSTEM', prompt: `LENS: ARCADE IDENTITY, SOUND, MODELS PIPELINE, ROBUSTNESS. Arcade must be pixel- and sound-identical
to v0.7.0 (tools/golden.sh check; the Arcade ERGEBNIS of run_stage.gd against v0.7.0 = main on three stages); every
frozen file unchanged against main (git diff --stat main -- <frozen list of the contract>). Sound: the Modern profile in
race and menus – engine v3, the new road/tyre/wind/impact layers (Kiel–Hamburg: concrete slabs, the Köhlbrandbrücke
joints, Hamburg's cobbles alternating with asphalt), the Modern limiter (true peak ≤ −1 dBTP at master volume 1.0 in a
heavy crash), race tracks 1–3 rotating with stingers and interlude, ducking, race music on/off, UI sounds, no clicks at
loop seams, clean shutdown without "leaked at exit"; the Arcade sound unchanged; audio_qc.py all folders. Models
pipeline: export_models.py --check-keys clean, a second bake byte-identical, the manifest regenerated and consistent
with every model folder, the validator, check_sprite_geometry.py (sprites unchanged), sizes inside the budget
(tools/pck_report.py; the download about 280 MB at most). Tests: tools/run_tests.sh and run_render_checks.sh all green
on the head, and the tests changed by the merge (check_vehicles kasten/leistung, test_props, the Modern goldens) still
guard their rule – break one line per rule in a scratch copy and see the test fail. Robustness: --gfx-debug=fail and a
missing manifest fall back to Arcade with the right message; the Leistungstest (--bench=all) writes a valid
leistungstest.json; quitting and restarting in every screen; 20 minutes of Modern driving without errors in the log;
the Windows build under Wine starts Modern and Arcade.` },
]
phase('Prüfung')
const reviews = (await parallel(LENSES.map(l => () => agent(`${common(l.id, { mode: 'review', base: HEAD }, 'render')}
YOUR ROLE: INDEPENDENT QA OF THE FIRST ASSEMBLY OF PUSH M2 (head ${HEAD}, branch origin/wip/v080-m2int) – no
commits, no pushes. The assembly reports: ${INFO(m2)}; its report ${D('M2INT')}. Then the fixes of the delivered first
test build were merged on top: ${INFO(z)}; report ${D('M2ZS1')}.
Do not trust the reports – run and look yourself. ${l.prompt}
Every finding needs where, what, evidence (command + output or picture path, measured or inferred), how to reproduce
and a concrete fix. Severity: blocker = must not go into the next test build; high = the user will notice at once;
medium = noticeable; low = polish. Also list what you checked and found fine. Pictures and the report (bericht.md)
into ${SP}/deliver/${l.id}/.`,
  { label: `prüfung:${l.id}`, phase: 'Prüfung', schema: FINDINGS, isolation: 'worktree' })))).filter(Boolean)
const all = reviews.flatMap(r => r.findings)
const cnt = (s) => all.filter(f => f.severity === s).length
log(`Prüfung: ${cnt('blocker')} Blocker, ${cnt('high')} hoch, ${cnt('medium')} mittel, ${cnt('low')} niedrig`)

let fix = null
let nach = null
if (cnt('blocker') + cnt('high') + cnt('medium') > 0) {
  phase('Nacharbeit')
  fix = await agent(`${common('FIX-M2', { mode: 'fresh', base: HEAD }, 'render')}
YOUR ROLE: FIXES AFTER THE QA OF THE FIRST M2 ASSEMBLY. Your base is ${HEAD} (origin/wip/v080-m2int: M2INT's assembly
plus the merged fixes of the delivered first test build). The assembly reports: ${INFO(m2)}; its report ${D('M2INT')};
the ZS1 merge reports: ${INFO(z)}; its report ${D('M2ZS1')}. The user has ${ZS1_REF} – what it fixed must stay fixed.
Independent QA found (verdicts and findings; reports ${D('QA-M2-BILD')} and ${D('QA-M2-SYSTEM')}):
${JSON.stringify(reviews.map(r => ({ verdict: r.verdict, findings: r.findings })))}
Reproduce each blocker, high and medium finding first (reject it with evidence if it is wrong), fix every confirmed
one, most-seen first, and the cheap low ones. Re-render the pictures the findings point to and LOOK at them. Then the
gates once more on your final head: import clean; tools/run_tests.sh green; tools/golden.sh check 20 von 20;
tools/run_render_checks.sh all; modern_sight --full and modern_path_check --full if a vehicle/prop placement or a model
size changed; the validator and export determinism if a model changed; audio_qc.py if a sound changed. Push every
commit to origin wip/v080-fix-m2. Report in ${SP}/deliver/FIX-M2/bericht.md. Return the result format with package
"FIX-M2": one acceptance entry per finding you handled (pass = fixed and re-checked, fail = still open, not_run =
rejected – say why), then the gates.`,
    { label: 'nacharbeit:FIX-M2', phase: 'Nacharbeit', schema: BUILD_R, isolation: 'worktree' })
  const game = fix && fix.commit && (fix.files_changed || []).some(f => !/^(\/|docs\/|tests\/|ARCHITECTURE|README|deliver|\(|Bericht|bericht)/.test(f))
  if (fix) log(`FIX-M2: ${fix.commit ? fix.commit.slice(0, 7) : '?'} (${fix.acceptance.filter(a => a.result === 'fail').length} offen, Spiel geändert: ${game ? 'ja' : 'nein'})`)
  if (game) {
    phase('Nachprüfung')
    nach = await agent(`${common('NACH-M2', { mode: 'review', base: fix.commit }, 'render')}
YOUR ROLE: NACH-M2 – FOCUSED RE-CHECK of the fix round FIX-M2 only (head ${fix.commit}, origin/wip/v080-fix-m2). No
commits, no pushes. The findings of the independent QA that FIX-M2 had to handle:
${JSON.stringify(all.filter(f => f.severity !== 'low'))}
FIX-M2 reports: ${INFO(fix)}; its report ${D('FIX-M2')}.
Do not trust the report – reproduce each finding on the new head and judge it (pictures with tools/ab_shot.sh against
Arcade and against ${HEAD}; LOOK at them); git diff ${HEAD}..${fix.commit} for side effects and frozen Arcade files;
tools/golden.sh check once (20 von 20, 17 von 17); the render checks and tests that belong to the changed files; what
the user has in ${ZS1_REF} must still hold (the car at the start, the water under bridges, the pylons at night).
Return per finding fixed / partly / not_fixed / not_checked with evidence, any new finding, and the gates you ran with
their output. Pictures and bericht.md into ${SP}/deliver/NACH-M2/.`,
      { label: 'nachprüfung:NACH-M2', phase: 'Nachprüfung', schema: RECHECK, isolation: 'worktree' })
  }
}
return { m2, z, reviews, fix, nach }
