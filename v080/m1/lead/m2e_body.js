
// Early start of M2 environment models: two chains run side by side,
//   AS3 (vegetation, nature) -> KRITIK-3 -> AS3R   and   AS4 (buildings, furniture, bridge parts, ships) -> KRITIK-4 -> AS4R
const BASE = '8f58b2d7a890ac1aa6404e209f5d89153a9f50d7'   // RINT-B's pushed head: R1-R3, AS1b's 20 prop models, UI1, AU-B/D1
const BASE_WT = `${REPO}/.claude/worktrees/wf_ae4df3ba-14f-1`

const EARLY = `EARLY START – PRIORITY RULE: you are an early start of a later wave (M2). The assembly and QA of push M1 run at the
same time and are on the critical path for the user's first test build. Run EVERY heavy job (Blender exports and bakes,
Godot renders, test suites, check_sprite_geometry) with nice -n 19 (not 10) and one worker process (export_models.py
--jobs 1, check_sprite_geometry --jobs 1); never two heavy jobs of yours at once. Another early package (road and wind
sound, AU-C1) and a second model package run in parallel – the same rule binds them.`

const REVIEW_P = {
  type: 'object',
  properties: {
    overall: { type: 'string', description: 'honest answer for the user, 5-10 sentences: finer than the sprites? good enough to drive past for hours?' },
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

const PIPE_NOTE = `THE PIPELINE AND ITS STANDARD FOR ENVIRONMENT MODELS: AS1b built the first 20 prop models of the slice (oak and birch
with seed variants, bushes, ground cover, farmhouse, barn, haybale, wind turbine, windmill, power pylon, street light,
delineator, fuel station and pump, radar camera, customs booth) with the builders tree/bush/grass/building/lattice in
tools/blender/ce3d/{veg3d, leafatlas, props3d}.py. Read its report ${SP}/deliver/AS1b/bericht.md COMPLETELY – above all
§10–§13 (contract questions, needs of other packages, A/B observations, its honest assessment: that list of weaknesses
is the checklist of what not to repeat) – and its handover ${SP}/m1/AS1b/STAND.md (pitfalls: BC3 alpha quantisation –
halo alpha ≤ 0.30 for leaves with threshold 0.42, ≤ 0.33 for cutouts with 0.5; flat cards rather than tents; ccw
polygons for delaunay_2d_cdt; bake AO last; a comment change in veg3d.py/props3d.py changes the cache key). Its helper
scripts are in ${SP}/m1/AS1b (cycle.sh = export + bake + import + manifest + contact sheet, batch_build.sh, stage_sets.gd
= census of the sets a stage places) – copy them into your scratch folder, never edit them in place. Committed tools:
tools/models/prop_scene.sh <png> --models=a,b [--mode=dist|lods|road] (game camera at distances, LOD steps, road-side
scene), tools/models_contact_sheet.sh, tools/ab_shot.sh (Arcade | Modern from the same simulation state at a stage
position; the race draws every set that has a model, the others as Arcade-picture stand-ins), validate_models.py
--report, check_sprite_geometry.py. Known renderer state on your base: the shaders baked / leaves / billboard and
builders/props.gd belong to R2/R4, vpbr/glass to R3/R4 – never edit them; RINT-B lowered lamp_off and re-tuned the paint
light, so measure on your base, not from older reports. The art review of the vehicle models found that a contact-sheet
rig can silently skip the race look (materials created after the look was set): make sure your pictures really carry
it (compare against the in-race picture of tools/ab_shot.sh).`

const SHARED = (own) => `SHARED PIPELINE FILES (contract §5: ce3d core/glb/roles/bake/lod/manifest/catalog3d/export, export_models.py,
validate_models.py, tools/models/**, model_db.gd): another model package runs in parallel on the same base and later
both are merged with the vehicle models (AS2a/AS2b/AS2R) – so change shared files only backwards-compatibly and
additively, put your catalog entries into ONE clearly marked block of your own ("# --- ${own} ---") instead of
interleaving them, add new builders in your own module where you can, regenerate assets/models/manifest.json on your
branch (it is regenerated again after the merge), and list every shared-file change with one line of purpose in your
report.`

const GATES = `GATES on your final head (commands and output in bericht.md): python3 tools/blender/validate_models.py --report green;
budgets of §4.6.9 per model (triangles per level, cards, draw calls, bytes) in a table; check_sprite_geometry.py
--only props --jobs 1 without "ANDERS" (after every cesprites change, not only at the end); export determinism
(export_models.py --check-keys OK and a second forced bake of your models byte-identical); the race in Modern draws your
models without script errors (tools/ab_shot.sh at three stage positions where your sets stand – find them with the
census script); tools/run_tests.sh green (once, at the end); tools/golden.sh check 20 von 20 identisch (once, at the
end; Arcade is frozen).`

const DELIVER = (pkg) => `DELIVER to ${SP}/deliver/${pkg}/ (German file names and captions): contact sheets day and night of every
model and level; game-camera views at the switch distances next to the Arcade sprite; A/B pictures Arcade | Modern at
the three stage positions (--gfx-preset=high and medium, noon and dusk); bericht.md with the budget table, the
measurements and an honest assessment (good / not yet good / missing). An independent art reviewer inspects your
branch afterwards and a rework step follows – name what you consider weakest.`

const BAR_VEG = `THE QUALITY BAR FOR VEGETATION. Trees are the most frequent objects of the game (the first 75 km of Kiel – Hamburg
alone place 147 oaks and 88 birches; forests, avenues and southern landscapes elsewhere), seen from the chase camera
at 15–300 m while driving at 100–200 km/h. A finished tree:
- reads at once as its species and matches its Arcade sprite: silhouette within the sprite's outline (overlay picture
  per species and variant), colour family and value of the sprite by day (measured mean hue/value of the crown, as
  AS1b's table did). The sprite designs in cesprites/props_nature.py ARE the species' look – you add depth and detail,
  not a new design.
- has volume: a crown built from clumps, lit on the sun side and darker inside (per-card occlusion brightness), trunk
  and main branches where the sprite shows them, no light branch stubs inside the crown, no square card edges.
- never looks like stickers: cards seen edge-on must not draw dark streaks; no card pairs grazing each other; the crown
  stays calm up close (AS1b: restless under 25 m – fix that in the shared builder, oak and birch included).
- no shimmer or sparkle of the alpha-scissor leaves at 40–150 m (check the mip levels of the leaf atlas and the BC3
  alpha quantisation; make a 2 s clip of a passing tree row at 120 km/h and LOOK at consecutive frames).
- level swaps invisible: LOD0 → LOD1 → impostor at their distances (measure the share of changed pixels at the switch,
  AS1b measured at 60 m and 200 m); the impostor within 5 % of LOD1 in brightness and hue by day, at dusk and at night,
  and not pale in the far fog (AS1b: pale grey spots at 250 m – compare with the Arcade sprite in the same fog), its
  trunk as wide and as brown as LOD1's.
- grounded on slopes (trunk base below 0, no floating), two seed variants per species clearly different in silhouette,
  wind data in COLOR (sway amplitude by height, phase per card, stiffness, brightness): trunks stiff, crowns gentle,
  palm fronds livelier; no sway in the impostor.
- regional character true to the sprites: beech (broad, dense, smooth grey trunk), spruce (dark cone), pine (as its
  sprite – check whether it is a Scots or an umbrella pine), poplar (tall narrow column, avenues), cypress (narrow dark
  flame), olive (small silver-grey crown, gnarled trunk), palm (fronds with leaflets, ringed trunk).
- bushes and heather: low clumps with volume, heather purple-brown and fine; rocks with real facets and weathered
  colour; the cliff with strata as its sprite; all with their base below ground so they sit on slopes.
Night, rain and snow are the renderer's (R4): nothing emissive; keep card normals meaningful (outward and upward) so the
leaves shader can whiten up-facing cards in snow and darken them in rain – say exactly what you provide.
Budgets §4.6.9: tree 2,500 triangles LOD0 with ≤ 450 cards, 900 LOD1, impostor LOD2, draw calls 2/2/1, two seed
variants per species; bush, heather 400/120, 1 call; rock 1,500, cliff 6,000, 1 call. Report the alpha-test overdraw
per tree (cards, covered pixels at 20 m). Work in rounds: build, render, LOOK, list the worst defects, fix, repeat – at
least three rounds.`

const BAR_BLD = `THE QUALITY BAR FOR BUILDINGS, FURNITURE, BRIDGE PARTS AND SHIPS. They are seen at 30–400 m beside the road, mostly
from the side at speed; they make villages, farmland, river crossings and harbours. A finished model:
- has the proportions, roof shape, colours and features of its Arcade sprite (overlay of the silhouette; the designs in
  cesprites/{props, props_buildings, props_road}.py ARE the look – you add depth, not a new design).
- has real depth where the camera sees it: window reveals with frames, sills and glazing bars, doors with steps or
  canopies, roof overhangs with eaves, gutters and downpipes, chimneys and dormers where the sprite has them; a roof
  covering with a readable rhythm (tiles, slate, sheet metal) and facade materials (brick bond, plaster, timber framing,
  concrete panels) in the baked atlas with ambient occlusion – never a flat-coloured box; texel density on road-facing
  walls ≥ 26 px/m (AS1b reached 32–46 px/m).
- lives at night: windows lit warmly and irregularly from single rooms (not every window, not by day – check how the
  unlit lamp level looks by day on your base), the church tower and clock face, the factory's hall lights and sign,
  portholes and deck lights of the ships, the bridge lamps with light anchors; nothing glows by day.
- church with tower, louvres and clock; factory with halls, sheds, chimney and lettering as geometry; town houses
  (house_med, building_block_a/b, building_oldtown, building_shop, building_tall) as varied as their sprites, shop
  fronts with glazing and signs; ferry ship and houseboat with hull, superstructure, railings, portholes and a
  waterline; bridge pylon and truss arch as steel lattice or concrete that reads at 50–400 m without shimmer (thin
  members as AS1b's power pylon: a lattice at 250 m without flicker; coarser levels with thicker members or cards).
- coarser levels keep silhouette and window rhythm; no visible pop at the switch distances (measure).
Bridge parts: R5 (tunnels and bridges) builds decks, railings, girders and cables procedurally in a later wave and may
use your bridge_* models as parts – keep them true to the sprite's scale and report their dimensions and attachment
points (cable anchors, deck height) in bericht.md for R5. Budgets §4.6.9 (check the validator's category of each set –
building_* may be a city building): rural building 2,000 triangles, ≤ 2 draw calls; city building 10,000; road
furniture 1,500 (pylon 5,000), 1 call; textures inside the tier and byte budget (whole set: meshes ≤ 40 MB, S3TC ≤
240 MB in the PCK, ≤ 60 MB in the archive – report your share and the bake time per model). Work in rounds: build,
render day and night, LOOK, list the worst defects, fix, repeat – at least three rounds.`

const PKG = {
  AS3: {
    title: 'AS3 – VEGETATION AND NATURE (contract §6 wave 4 "AS3"; D22; §4.6 complete; docs/modelle.md)',
    models: `MODELS: props/tree_beech, tree_cypress, tree_olive, tree_palm, tree_pine, tree_poplar, tree_spruce, each with a
second seed variant (<name>_b with catalog variant_of, as AS1b did for oak and birch), props/heather, rock_a, rock_b,
cliff (check the sprite manifest for any further nature set still without a model and build it too). Revisit oak,
birch and the bushes only where AS1b's honest assessment names defects, by fixing the shared builder so that every
species benefits.`,
    files: `FILES YOU OWN: cesprites/props_nature.py (additive hooks only – no sprite vertex may move), tools/blender/ce3d/{veg3d,
leafatlas}.py, assets/models/props/{tree_*, bush_*, cover_*, heather, rock_*, cliff}/**, and the shared pipeline files
under the rule below. Never touch the renderer (scripts/race3d/**, assets/shaders/modern/** – write what foliage needs
from leaves.gdshader under notes_for_next), the vehicles, the files of AS4 (props3d.py, cesprites/{props,
props_buildings, props_road}.py, buildings), city buildings and landmarks, the frozen Arcade files and sprites.`,
    bar: BAR_VEG,
    reviewFocus: `Review every new species and variant, heather, rocks and cliff, and oak, birch and bushes again where the builder
changed: (1) the chase camera at 15, 40, 100 and 250 m beside the road by day (one shadowed sun), at dusk and at night,
(2) side by side with the Arcade sprite of the same set in the same camera and the overlay of the sprite outline,
(3) the level swaps at their distances (changed-pixel share) and the impostor in the far fog, (4) leaf shimmer in
motion (consecutive frames of a passing row at 120 km/h), (5) edge-on cards, crown calm up close, trunks grounded on a
slope, the two variants side by side, (6) in the race: tools/ab_shot.sh at stage positions where these species stand
(southern stages for palm, olive and cypress; avenues for poplars; mountains for spruce) – find them with the census
script of AS1b.`,
  },
  AS4: {
    title: 'AS4 – RURAL BUILDINGS, ROAD FURNITURE, BRIDGE PARTS, SHIPS (contract §6 wave 5 "AS4"; §4.6 complete; docs/modelle.md)',
    models: `MODELS: props/church, factory, house_med, building_block_a, building_block_b, building_oldtown, building_shop,
building_tall, bridge_lamp, bridge_pylon, bridge_truss_arch, houseboat, ferry_ship (check the sprite manifest for any
further rural or road set still without a model and build it too; the city_* sets belong to AS5a/AS5b and the
landmarks to AS6 – not yours). Revisit AS1b's buildings only where its honest assessment names defects (e.g. the
windmill tower's painted windows → real reveals).`,
    files: `FILES YOU OWN: cesprites/{props, props_buildings, props_road}.py (additive hooks only – no sprite vertex may move),
tools/blender/ce3d/props3d.py, assets/models/props/<the sets above and the others you build>/**, and the shared
pipeline files under the rule below. Never touch the renderer (scripts/race3d/**, assets/shaders/modern/** – write
what the buildings need under notes_for_next), the vehicles, the files of AS3 (veg3d.py, leafatlas.py,
cesprites/props_nature.py, trees, bushes, rocks), city_* sets and landmarks, the frozen Arcade files and sprites.`,
    bar: BAR_BLD,
    reviewFocus: `Review every new model and AS1b's buildings where the builder changed: (1) the chase camera at 30, 100, 250 and
400 m beside the road by day (one shadowed sun), at dusk and at night (lit windows: irregular, warm, none by day),
(2) side by side with the Arcade sprite of the same set in the same camera and the overlay of the sprite outline,
(3) close-ups of facades, roofs, windows and doors (depth, materials, texel density), (4) the level swaps at their
distances (changed-pixel share), lattice shimmer of bridge pylon and truss arch in motion, (5) ships on the water line,
(6) in the race: tools/ab_shot.sh at stage positions where these sets stand (villages, river crossings, harbours) –
find them with the census script of AS1b.`,
  },
}

const chain = async (key) => {
  const P = PKG[key]
  const build = await agent(`${common(key, { mode: 'fresh', base: BASE }, 'content')}
${EARLY}
YOUR ROLE: ${P.title}. Your base is the assembly head ${BASE} (it contains the renderer R1–R3, AS1b's prop models and
pipeline, UI1 and the music); the assembly continues in ${BASE_WT} – never work or commit there. If that worktree has
tools/blender/_cache3d, copy it first (cp -a; keyed by content, saves Blender time). Push every commit to origin
wip/v080-${key.toLowerCase()}.
${P.models}
${P.files}
${SHARED(key)}
${PIPE_NOTE}
${P.bar}
${GATES}
${DELIVER(key)} Return the result format with package "${key}".`,
    { label: `bau:${key}`, phase: 'Bau', schema: BUILD_C, isolation: 'worktree' })
  if (!build) { log(`${key} fehlt`); return { build: null } }
  log(`${key}: ${build.commit ? build.commit.slice(0, 7) : '?'} (${build.acceptance.filter(a => a.result !== 'pass').length} offen)`)
  const info = JSON.stringify({ branch: build.branch, commit: build.commit, worktree: build.worktree, summary: build.summary,
    open: build.acceptance.filter(a => a.result !== 'pass'), deviations: build.deviations, quality: build.quality_verdict,
    notes: build.notes_for_next, media: build.media })
  const rk = key === 'AS3' ? 'KRITIK-3' : 'KRITIK-4'

  const review = await agent(`${common(rk, { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT ART REVIEW OF ${key} (no building). ${key} delivered its models on branch ${build.branch} (commit
${build.commit}), worktree ${build.worktree} – READ-ONLY for you: no edits, no commits there. Work on a copy in your
scratch folder (cp -a the worktree without build/ and without tools/blender/_cache3d; absolute XDG_DATA_HOME;
cp -a ${REPO}/.godot into the copy and import before the first run). You make no commits.
Its report: ${info}
${PIPE_NOTE}
The bar the builder was given (judge against it, and against the Arcade sprites the player knows):
${P.bar}
Do not trust the report – render and look yourself. You are the art director who answers one question for the user:
are these models visibly FINER than the Arcade sprites and good enough to drive past for hours?
${P.reviewFocus}
Defects each with where, what, a picture as evidence and a fix the builder can carry out; rank by what the player sees
most. Also check validator, budgets, draw calls, bytes and the level distances. Comparison sheets and bericht.md into
${SP}/deliver/${rk}/.`,
    { label: `kritik:${key}`, phase: 'Kritik', schema: REVIEW_P })
  if (review) {
    const hm = review.models.flatMap(m => m.defects.filter(d => d.severity !== 'low'))
    log(`${rk}: ${review.models.filter(m => m.versus_sprite === 'finer').length}/${review.models.length} feiner; ${hm.length} Mängel hoch/mittel`)
  } else log(`${rk} ausgefallen – die Nacharbeit prüft selbst`)
  const reviewText = review ? JSON.stringify(review) : 'NOT AVAILABLE – the reviewer failed. Make your own strict review first (the views listed below) and fix what you find.'
  const rkey = key + 'R'

  const rework = await agent(`${common(rkey, { mode: 'fresh', base: build.commit }, 'content')}
${EARLY}
YOUR ROLE: ${rkey} – REWORK OF ${key} AFTER THE INDEPENDENT ART REVIEW. Your base is ${build.commit} (branch ${build.branch}).
Copy its export cache first: cp -a ${build.worktree}/tools/blender/_cache3d tools/blender/ (if present). Push every
commit to origin wip/v080-${rkey.toLowerCase()}.
${key} reported: ${info}
The independent art review found: ${reviewText}
Check each defect yourself first (reject it with evidence if it is wrong). Fix every confirmed high and medium defect
and the cheap low ones, most-seen first. Your files are those of ${key}, under the same rules:
${P.files}
${SHARED(key)}
${PIPE_NOTE}
${P.bar}
The reviewer's views to re-render after each round (LOOK at them): ${P.reviewFocus}
${GATES}
Deliver to ${SP}/deliver/${rkey}/ with bericht.md (before/after numbers per fixed defect). Return the result format with
package "${rkey}" (the state after the rework); rejected findings under deviations.`,
    { label: `nacharbeit:${rkey}`, phase: 'Nacharbeit', schema: BUILD_C, isolation: 'worktree' })
  if (rework) log(`${rkey}: ${rework.commit ? rework.commit.slice(0, 7) : '?'} (${rework.acceptance.filter(a => a.result !== 'pass').length} offen)`)
  return { build, review, rework }
}

const [as3, as4] = await parallel([() => chain('AS3'), () => chain('AS4')])
return { as3, as4 }
