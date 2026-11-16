
// AS5a – city buildings part 1, two batches one after the other; each batch: build -> independent art review -> rework.
// Batch 2 builds on batch 1's reworked head and starts with the lessons of batch 1's review.
// ARGS: { base: '<M2 head to build on>', only: ['1', '2'] (optional) }
const A = args || {}
const BASE = A.base
const D = (p) => `${SP}/deliver/${p}/bericht.md`

const REVIEW_P = {
  type: 'object',
  properties: {
    overall: { type: 'string', description: 'honest answer for the user, 5-10 sentences: finer than the sprites? good enough to drive through the cities for hours?' },
    models: { type: 'array', items: { type: 'object', properties: {
      model: { type: 'string' },
      versus_sprite: { type: 'string', enum: ['finer', 'equal', 'cruder'] },
      in_race_ready: { type: 'boolean', description: 'true if it can ship as it is' },
      defects: { type: 'array', items: { type: 'object', properties: {
        severity: { type: 'string', enum: ['high', 'medium', 'low'] }, where: { type: 'string' }, problem: { type: 'string' },
        evidence: { type: 'string', description: 'picture path or command + output; measured vs inferred' }, fix: { type: 'string' } },
        required: ['severity', 'where', 'problem', 'evidence', 'fix'] } } },
      required: ['model', 'versus_sprite', 'in_race_ready', 'defects'] } },
    pipeline_issues: { type: 'array', items: { type: 'string' } },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['overall', 'models', 'pipeline_issues', 'media'],
}

const SITUATION = `SITUATION OF PUSH M2 (lead): your base ${BASE} (origin/wip/v080-m2int) is the M2 assembly – M2INT merged all
vehicle models (AS2R), vegetation (AS3R), rural buildings, town houses, street furniture, bridge parts and ships (AS4R)
and the reworked Modern sound onto the first test build (report ${D('M2INT')}); M2ZS1 merged the fixes of the first
test build the user got (report ${D('M2ZS1')}). What the user has and what is still missing or worse than Arcade:
${SP}/deliver/ZS1/was_neu.md (German; read it) – among the missing: "Städte: die meisten Gebäude … sind noch
Arcade-Bilder; Stadtmodelle folgen". That is your package: the 46 props/city_* sets are still Arcade-picture stand-ins
(manifest entry "fallback": "sprite"). THE USER IS AWAY for an indefinite time and asked us to go on without their test
results: decide by the contract and by an honest comparison with Arcade (Modern has to look clearly better, not merely
different). BESIDE YOU run the wave-3 renderer packages R4 (light, night, weather), R5 (tunnels, bridges, water), R6
(fuel station, border, city street furniture, start/finish, radar), their independent reviews, and the QA and fix round
of the assembly (QA-M2, FIX-M2). They render and measure performance on this machine, so run EVERY heavy job of yours
(Blender exports and bakes, Godot renders, test suites, check_sprite_geometry) with nice -n 19 (not 10) and one worker
(export_models.py --jobs 1, check_sprite_geometry --jobs 1), never two heavy jobs at once, and before you start Blender
or Godot check free -g: below 3 GB "available", wait (sleep 60, check again). Nobody else touches tools/blender/** or
assets/models/** in this phase. Afterwards the lead merges your branch with R4, R5, R6 and FIX-M2 (RINT-M2), and the
renderer package R7 (landmarks, skyline, far LOD, LOD tuning) builds on your city models.`

const FILES = `FILES YOU OWN: tools/blender/cesprites/props_cities.py (additive hooks only – no sprite vertex may move; sprites are never
re-rendered), a new module tools/blender/ce3d/cities3d.py for what is specific to city buildings, AS4's builder
tools/blender/ce3d/buildings3d.py (builder "house"; AS4 and AS4R are finished, it is yours now), the model folders
assets/models/props/city_<your styles>_*/**, your catalog entries in ONE clearly marked block ("# --- AS5a ---"), and the
shared pipeline files (ce3d core/glb/roles/bake/lod/manifest/catalog3d/export, export_models.py, validate_models.py,
tools/models/**, model_db.gd) only backwards-compatibly and additively; regenerate assets/models/manifest.json on your
branch and list every shared-file change with one line of purpose in your report. Prefer the new module over edits to
buildings3d.py: a code change there changes the cache key of AS4's eight house models – if you fix something shared,
re-export them and prove they look the same (contact sheet before/after, changed-pixel share) or better, and say so.
Never touch the renderer (scripts/race3d/**, assets/shaders/modern/** – R4/R5/R6 work there now; write what your
buildings need from it under notes_for_next), the vehicles, the vegetation (veg3d.py, leafatlas.py, props_nature.py),
the landmarks (props_landmarks, AS6), the frozen Arcade files, sprites and the sprite manifest.`

const PIPE_NOTE = `THE PIPELINE AND ITS STANDARD: AS4 built the rural buildings and town houses (church, factory, house_med, building_block_a/b,
building_oldtown, building_shop, building_tall), bridge parts and ships with the builder "house" in
tools/blender/ce3d/buildings3d.py (read its module docstring: openings with reveals, frames, glazing bars and sills,
shutters, louvres, clocks, doors and gates, gutters, signs as geometry, curtain walls, octagon towers, lod1 without the
fine parts; two surfaces baked + vpbr; the houseboat already reads walls from props_cities.wallmat through
_log_city_walls). Read COMPLETELY: the reports ${D('AS4')} (incl. its weaknesses), the independent art review
${D('KRITIK-4')} and the rework ${D('AS4R')} (above all "Ehrliche Einordnung" – the list of what is still not good is
your checklist of what not to repeat: panes ~10 levels lighter than the sprite's painted glass and grey-lilac at 250 m,
shimmer of block B at 120 m (1.0 % vs the sprite's 0.2 %), shop windows lit as flat white areas without a display,
thin struts losing coverage in the alpha test of small mips) and AS4R's handover ${SP}/m1/AS4R/STAND.md; AS1b's
pitfalls in ${SP}/m1/AS1b/STAND.md (BC3 alpha quantisation – halo alpha <= 0.33 for cutouts with threshold 0.5; ccw
polygons for delaunay_2d_cdt; bake AO last; a comment change in a builder changes its cache key). Helper scripts to copy
into your scratch folder (never edit them in place): ${SP}/m1/AS1b/{cycle.sh, batch_build.sh, stage_sets.gd} and
${SP}/m1/AS4R/ (census_all.gd = where each set stands in the network, budget_table.py, lum.py, hue.py, ab.sh,
batch_views.sh). Copy AS4R's export cache first: cp -a ${REPO}/.claude/worktrees/wf_aad8d49e-fb4-6/tools/blender/_cache3d
tools/blender/ (keyed by content; saves Blender time). Committed tools: tools/models/prop_scene.sh <png>
--models=a,b [--mode=dist|lods|road] [--look=race] (game camera at distances, level steps, road-side scene),
tools/models_contact_sheet.sh, tools/ab_shot.sh (Arcade | Modern from the same simulation state at a stage position;
the race draws every set that has a model and the others as Arcade-picture stand-ins), validate_models.py --report,
check_sprite_geometry.py, tools/pck_report.py. Night windows on your base: AS4R made a pane the hole filler of its
window moved back into the reveal – by day the sprite's painted glass, at night the sprite's light of that window from
the emission atlas (emit_energy 1.6, matched against Arcade: peak 216 vs 225 at 23:00) – reuse that, do not invent a
second way. The class baked_cutout (alpha-scissor parts in the baked atlas) exists in the material code and the
validator but has no model yet – railings and wrought iron of your buildings are its first users: prove it works in
the race (no shimmer in motion, no halo, coverage kept in small mips).`

const BAR_CITY = `THE QUALITY BAR FOR CITY BUILDINGS. They line the road at every city arrival and departure: in the centres facades stand
0.3–3 m beyond the road edge on BOTH sides every 24–30 m (scenery "x": [0.3, 2.5], "align": "edge"), in the outskirts
4–12 m beyond it – so the chase camera passes them at 5–15 m for the last and first kilometres of many stages, closer
than anything except the cars, mostly at 50–100 km/h, by day, at dusk and at night. A finished city building:
- has the proportions, storeys, roof shape, gables, colours and features of its Arcade sprite (overlay of the
  silhouette in the sprite's view): the generators in props_cities.py ARE the look – the models come from the same
  Blender geometry with depth added, never a new design.
- has real depth where the camera sees it from the street: window reveals with frames, sills and glazing bars, shop
  fronts with glazing, a display or interior hint behind it and a fascia, doors with steps, arcades and passages as
  real openings, cornices, string courses, pilasters, window pediments and quoins as geometry, balconies with slabs and
  railings, oriels and dormers, roof overhangs with eaves and gutters, chimneys; brick bonds, plaster, stone, timber
  and roof coverings (tiles, slate, zinc) with a readable rhythm in the baked atlas with ambient occlusion – never a
  flat-coloured box. Texel density on road-facing walls >= 26 px/m (contract), and >= 40 px/m on the ground floor and
  first floor of the centre buildings (seen at 5–15 m); keep the bytes down by baking a repeated bay or window module
  once and reusing its texels, and by reusing coarse texels on walls away from the road and on the far side ("reused
  walls on the far side", contract).
- per style, true to the generator: hanse – brick stepped and curved gables, Kontor, warehouse (Speicher) with hoist
  beams and loading doors, the harbour crane as a steel structure with its lamp; german – Gründerzeit stucco facades with
  cornices, pilasters, window pediments and balconies, the Mietshaus, the office building, the suburban house;
  german_old – timber framing (Fachwerk) with jettied upper storeys, the Baroque facade with its gable and volutes;
  dutch – canal houses with neck, bell and step gables, hoist beams, tall sash windows, the terrace; belgian – terrace
  and stone houses; french – maison, sud (shutters, tiles), immeuble; paris – Haussmann blocks with stone facades,
  wrought-iron balconies, zinc mansard roofs with dormers, the corner building with its café; swiss – the chalet with
  wooden balconies and deep eaves, the Laube with its arcades. Look at the generator of each set for what it shows.
- gardens, trees, hedges, flowers, fences and bikes that the generator draws around a house: cheap versions (cards,
  simple boxes, the AS3 tree models if a tree stands there) inside the budget – never thousands of triangles (the
  contract names city_eastern_house_c with 23,000 garden triangles as the outlier to trim).
- lives at night: windows lit warmly and irregularly from single rooms (the same windows as the sprite's light layer,
  not every window, none by day), shop windows and café lit with something behind the glass, entrance and wall lamps as
  light anchors (lamp channel 12 + "lights"), the crane's lamp; nothing glows by day.
- is tintable: some scenery placements tint a city set and Arcade multiplies the sprite by that colour – city_german_house
  #e8b8a4 and city_german_mietshaus #e0b09c in the hanse outskirts (Kiel, Hamburg, Bremen, Rostock), city_german_mietshaus
  #f6eee2 in the bavarian outskirts, city_german_gruenderzeit #f6eedc in the bavarian and #ece4d0 in the swiss centre,
  city_dutch_terrace #ead6cc in the ruhr outskirts. The Modern renderer passes the tint only to stand-ins today (R7 adds
  it for model instances): bake the albedo in the sprite's own colours, no pre-tint, and show in a contact sheet how each
  tinted placement will look (your albedo atlas multiplied by the tint) next to the tinted sprite.
- coarser levels keep silhouette, storeys and window rhythm; lod1 from the props builder's switch distance (60 m at
  "Details: Mittel"), an impostor beyond 250 m only if it is cheaper and invisible; no visible pop at the switch
  distances (measure the changed-pixel share, the sprite's own swap as reference); no shimmer of railings, glazing bars
  or timber at 40–150 m in motion (consecutive frames of a 50 km/h drive through a centre).
- Budgets (§4.6.9): city building 10,000 triangles lod0, <= 2 draw calls per level; textures inside the tier. Archive
  share (tools/pck_report.py; M2ZS1 measured models 18.73 of 40 MB and textures 13.04 of 60 MB): at most 3 MB meshes and
  7 MB textures per batch – AS5b (12 more styles) and AS6 (33 landmarks) still have to fit. Report the bake time and the
  bytes per model.
Work in rounds: build, render day, dusk and night in the game camera, LOOK, list the worst defects, fix, repeat – at
least three rounds. The independent art reviewer after you will drive through the city centres.`

const GATES = `GATES on your final head (commands and output in bericht.md): python3 tools/blender/validate_models.py --report green;
the budget table per model (triangles per level, draw calls, bytes, texel density road side / far side, bake time);
check_sprite_geometry.py --only props --jobs 1 without "ANDERS" (after every change of props_cities.py, not only at
the end); export determinism (export_models.py --check-keys OK and a second forced bake of your models byte-identical);
AS4's house models byte-identical, or re-exported on purpose with before/after evidence; the race in Modern draws your
models without script errors (tools/ab_shot.sh at three city arrivals of your batch, --gfx-preset=high and medium, noon,
dusk and 22:00 – find the positions with census_all.gd); tools/run_tests.sh green (once, at the end); tools/golden.sh
check 20 von 20 and 17 von 17 identisch (once, at the end; Arcade is frozen); tools/golden.sh modern-check – where a
Modern golden changes because your models appear in it, LOOK at the new picture first, then modern-make, and say so in
the commit; the archive estimate of tools/pck_report.py inside your share (if it needs tools/build_linux.sh, delete the
build afterwards).`

const DELIVER = (pkg) => `DELIVER to ${SP}/deliver/${pkg}/ (German file names and captions): contact sheets day and night of every model
and level; game-camera views at 5–10, 30, 100 and 250 m beside the road next to the Arcade sprite; close-ups of the
street-level facades; the tinted placements; A/B pictures Arcade | Modern at three city arrivals (--gfx-preset=high and
medium, noon, dusk, 22:00); one 10-s clip at 50 km/h through a city centre with your buildings (fixed 60 fps);
bericht.md with the budget table, the measurements and an honest assessment (good / not yet good / missing). An
independent art reviewer inspects your branch afterwards and a rework step follows – name what you consider weakest.`

const BATCH = {
  '1': {
    sets: `props/city_hanse_gabled, city_hanse_kontor, city_hanse_speicher, city_hanse_crane, city_german_house,
city_german_mietshaus, city_german_gruenderzeit, city_german_office, city_german_old_fachwerk, city_german_old_fachwerk_b,
city_german_old_barock (11 sets – the styles hanse, german and german_old)`,
    where: `They make the cities of the race Kiel – Nürnberg, the route of the next test build: Kiel and Hamburg (hanse), Hannover
and Kassel (german), Würzburg and Nürnberg (german_old); also Bremen, Rostock, Berlin, Frankfurt, Köln, Erfurt, Fulda,
and through mixed styles Dortmund (ruhr: german_house), Leipzig and Magdeburg (german_east), München, Passau and
Regensburg (bavarian: german_old_barock, tinted gruenderzeit and mietshaus) and Bern (swiss centre: tinted
gruenderzeit). Order of work: first the sets the player sees most often on Kiel – Nürnberg (count them with the census
script), commit and push each finished style; if time runs short, a complete, reviewed-quality first half beats 11
half-done models.`,
    review: `the arrivals and departures of Kiel, Hamburg, Hannover, Kassel, Würzburg and Nürnberg on the race Kiel – Nürnberg
and one bavarian centre (München)`,
  },
  '2': {
    sets: `props/city_dutch_canal, city_dutch_canal_b, city_dutch_terrace, city_belgian_terrace, city_belgian_stone,
city_french_maison, city_french_sud, city_french_immeuble, city_paris_haussmann, city_paris_corner, city_swiss_chalet,
city_swiss_laube (12 sets – the styles dutch, belgian, french, paris and swiss)`,
    where: `They make Amsterdam (dutch), Brüssel, Lüttich and Calais (belgian), Tours and Pau (french), Bordeaux, Lyon, Montpellier
and Toulouse (french_south: french_immeuble, french_sud), Paris (paris) and Bern (swiss), and through mixed styles
Dortmund (ruhr: tinted dutch_terrace). Order of work: the sets the player sees most often first (census script); commit
and push each finished style.`,
    review: `the arrivals of Amsterdam, Brüssel, Paris, Lyon or Bordeaux, and Bern`,
  },
}

const REVIEW_FOCUS = (b) => `Review every model of the batch: (1) the chase camera passing at 5–10, 30, 100 and 250 m by day (one shadowed
sun), at dusk and at 22:00 (lit windows irregular and warm, shop windows with something behind the glass, none by day);
(2) side by side with the Arcade sprite of the same set in the same camera, with the overlay of the sprite outline;
(3) close-ups of the street-level facades (doors, shop fronts, reveals, cornices, timber framing, balconies, railings):
depth, materials, texel density (measure px/m), nothing flat-coloured; (4) the level swaps at their distances
(changed-pixel share) and shimmer of railings, glazing bars and timber in motion (consecutive frames at 50 km/h);
(5) the tinted placements (albedo x tint) against the tinted sprite; (6) in the race: tools/ab_shot.sh and a short clip
at ${BATCH[b].review} (find the positions with ${SP}/m1/AS4R/census_all.gd), --gfx-preset=high and medium.`

const INFO = (r) => JSON.stringify({ branch: r.branch, commit: r.commit, worktree: r.worktree, summary: r.summary,
  open: (r.acceptance || []).filter(a => a.result !== 'pass'), deviations: r.deviations, quality: r.quality_verdict,
  notes: r.notes_for_next, media: r.media })

const batchChain = async (b, base, lessons) => {
  const pkg = `AS5a${b}`
  const rk = `KRITIK-5a${b}`
  const rkey = `AS5aR${b}`
  const B = BATCH[b]
  const build = await agent(`${common(pkg, { mode: 'fresh', base }, 'content')}
${SITUATION}
YOUR ROLE: ${pkg} – CITY BUILDINGS PART 1, BATCH ${b} OF 2 (contract §6 wave 5 "AS5a"; §4.6 complete with §4.6.9; docs/modelle.md
sections 15–19). Your base is ${base}. Push every commit to origin wip/v080-${pkg.toLowerCase()}.
MODELS: ${B.sets}. ${B.where}
${b === '2' ? `BATCH 1 (hanse, german, german_old) is built, reviewed and reworked; your base contains it. What its review found
and how the rework ended – apply these lessons from the start: ${lessons}
` : ''}${FILES}
${PIPE_NOTE}
${BAR_CITY}
${GATES}
${DELIVER(pkg)} Return the result format with package "${pkg}".`,
    { label: `bau:${pkg}`, phase: 'Bau', schema: BUILD_C, isolation: 'worktree' })
  if (!build || !build.commit) { log(`${pkg} fehlt`); return { build: null } }
  log(`${pkg}: ${build.commit.slice(0, 7)} (${(build.acceptance || []).filter(a => a.result !== 'pass').length} offen)`)
  const info = INFO(build)

  const review = await agent(`${common(rk, { mode: 'readonly' }, 'content')}
${SITUATION}
YOUR ROLE: ${rk} – INDEPENDENT ART REVIEW OF ${pkg} (no building). ${pkg} delivered its city models on branch ${build.branch}
(commit ${build.commit}), worktree ${build.worktree} – READ-ONLY for you: no edits, no commits there. Work on a copy in
your scratch folder (cp -a the worktree without build/ and without tools/blender/_cache3d; absolute XDG_DATA_HOME;
cp -a ${REPO}/.godot into the copy and import before the first run). You make no commits.
Its report (bericht.md: ${D(pkg)}): ${info}
${PIPE_NOTE}
The bar the builder was given (judge against it, and against the Arcade sprites the player knows):
${BAR_CITY}
Do not trust the report – render and look yourself. You are the art director who answers one question for the user:
are these city buildings visibly FINER than the Arcade sprites and good enough to drive through the cities for hours?
${REVIEW_FOCUS(b)}
Defects each with where, what, a picture as evidence and a fix the builder can carry out; rank by what the player sees
most. Also check validator, budgets, draw calls, bytes, texel density and the level distances. Comparison sheets and
bericht.md into ${SP}/deliver/${rk}/.`,
    { label: `kritik:${pkg}`, phase: 'Kritik', schema: REVIEW_P })
  if (review) {
    const hm = review.models.flatMap(m => m.defects.filter(d => d.severity !== 'low'))
    log(`${rk}: ${review.models.filter(m => m.versus_sprite === 'finer').length}/${review.models.length} feiner; ${hm.length} Mängel hoch/mittel`)
  } else log(`${rk} ausgefallen – die Nacharbeit prüft selbst`)
  const reviewText = review ? JSON.stringify(review) : 'NOT AVAILABLE – the reviewer failed. Make your own strict review first (the views listed below) and fix what you find.'

  const rework = await agent(`${common(rkey, { mode: 'fresh', base: build.commit }, 'content')}
${SITUATION}
YOUR ROLE: ${rkey} – REWORK OF ${pkg} AFTER THE INDEPENDENT ART REVIEW. Your base is ${build.commit} (branch ${build.branch}).
Copy its export cache first: cp -a ${build.worktree}/tools/blender/_cache3d tools/blender/ (if present). Push every
commit to origin wip/v080-${rkey.toLowerCase()}.
${pkg} reported: ${info}
The independent art review found: ${reviewText}
Check each defect yourself first (reject it with evidence if it is wrong). Fix every confirmed high and medium defect
and the cheap low ones, most-seen first. Your files are those of ${pkg}, under the same rules:
${FILES}
${PIPE_NOTE}
${BAR_CITY}
The reviewer's views to re-render after each round (LOOK at them): ${REVIEW_FOCUS(b)}
${GATES}
Deliver to ${SP}/deliver/${rkey}/ with bericht.md (before/after numbers per fixed defect). Return the result format with
package "${rkey}" (the state after the rework); rejected findings under deviations.`,
    { label: `nacharbeit:${rkey}`, phase: 'Nacharbeit', schema: BUILD_C, isolation: 'worktree' })
  if (rework && rework.commit) log(`${rkey}: ${rework.commit.slice(0, 7)} (${(rework.acceptance || []).filter(a => a.result !== 'pass').length} offen)`)
  else log(`${rkey} fehlt – Stand von ${pkg} bleibt`)
  return { build, review, rework }
}

const want = (b) => !A.only || A.only.includes(b)
let r1 = null, r2 = null
let head = BASE
let lessons = 'NOT AVAILABLE – batch 1 was not run in this workflow; read its reports in ' + `${SP}/deliver/{KRITIK-5a1,AS5aR1}/` + ' if they exist.'
if (want('1')) {
  r1 = await batchChain('1', BASE, '')
  const end = (r1.rework && r1.rework.commit) ? r1.rework : r1.build
  if (end && end.commit) head = end.commit
  lessons = JSON.stringify({
    review_overall: r1.review ? r1.review.overall : 'no review',
    defects: r1.review ? r1.review.models.flatMap(m => m.defects.filter(d => d.severity !== 'low').map(d => `${m.model}: ${d.problem}`)).slice(0, 25) : [],
    pipeline_issues: r1.review ? r1.review.pipeline_issues : [],
    rework_summary: r1.rework ? r1.rework.summary : 'no rework',
    still_open: r1.rework ? (r1.rework.acceptance || []).filter(a => a.result !== 'pass') : [],
    notes: r1.rework ? r1.rework.notes_for_next : [],
    reports: `${D('KRITIK-5a1')}, ${D('AS5aR1')}`,
  })
  if (!end || !end.commit) { log('Charge 1 ohne Ergebnis – Charge 2 startet nicht'); return { r1 } }
}
if (want('2')) {
  if (A.base2) head = A.base2
  r2 = await batchChain('2', head, lessons)
}
return { r1, r2 }
