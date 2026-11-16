
// Early start of M2 vehicle models: AS2a -> [KRITIK-2 || AS2b] -> AS2R
// args: { as1r: '<sha of AS1R final head>', as1rBranch: '<branch>', as1rWt: '<worktree>' }
const AS1R = args.as1r
const AS1R_BRANCH = args.as1rBranch
const AS1R_WT = args.as1rWt
const R3_HEAD = '4d02ada71e079ab327511fe657220728396624ef'

const EARLY = `EARLY START – PRIORITY RULE: you are an early start of the next push (M2). The assembly of push M1 runs at the
same time and is on the critical path for the user's first test build. Run EVERY heavy job (Blender exports and bakes,
Godot renders, test suites) with nice -n 19 (not 10) and at most one worker process (export_models.py --jobs 1);
never two heavy jobs at once.`

const QUALITY_BAR = `${QBAR}`

const PIPE_NOTE = `THE PIPELINE AND ITS STANDARD: the vehicle models of the slice went through build (AS1), an independent art review
(${SP}/deliver/AS1-KRITIK/bericht.md – read it completely, its defect list is the checklist of what not to repeat)
and a rework (AS1R, ${SP}/deliver/AS1R/bericht.md and ${SP}/m1/AS1R/STAND.md – its fixes are the standard every
new car must meet from the start: lamp bodies, bumper ends, wheel-arch liners, brake discs, plates, glass, rims, LOD
pop limits, caster rules, validator rules). Its tools are in ${SP}/m1/AS1R/bin (rebuild.sh, sheet.sh, pop.sh,
popmeasure.py, probe.py …) and the reviewer's tools in ${SP}/m1/AS1-KRITIK/tools_kritik – reuse them (copy into
your own scratch folder, do not edit them in place).`

phase('Modelle')
const as2a = await agent(`${common('AS2a', { mode: 'fresh', base: AS1R }, 'content')}
${EARLY}
YOUR ROLE: AS2a – PLAYER CARS AND TRAFFIC CARS, THE REST (contract §6 wave 3 "AS2a"; D17–D24; §4.6 complete; A-4;
docs/modelle.md). Your base is the final head of the rework AS1R ${AS1R} (branch ${AS1R_BRANCH}). Right after the
fast-forward, merge the renderer package R3 (commit ${R3_HEAD}: paint with clear coat and flakes, glass, chrome, the
vehicle layer) with git merge --no-ff ${R3_HEAD} (German message), so you can judge every car through the game's own
shaders; and copy the export cache: cp -a ${AS1R_WT}/tools/blender/_cache3d tools/blender/ (keyed by content, saves
Blender time). Push every commit to origin wip/v080-as2a.
MODELS: player/kombi, player/sportwagen, player/gran_turismo (race mesh from the generator detail levels, show mesh,
shadow mesh – as AS1 did for limousine and kompakt), traffic/suv, traffic/van, traffic/sports (geometry decals,
LOD0–2, every colour set of the sprite manifest as "sets" paint). Then for ALL FIVE player cars: interiors (new
cesprites/carinterior.py: seats, headrests, dashboard, steering wheel on the left, door cards, rear shelf – visible
through the glass from the chase camera) and real transparent glass; the 3D fixes the contract names (wrap-around
lamps, grille mesh, mirror arms) and rim styles per car. Acceptance: as AS1; all 26 traffic car sets and all 5 player
cars resolve to models (no stand-in left among cars – buses, trucks and police are AS2b's); showroom flags decided by
same-camera A/B pictures against the sprites.
FILES YOU OWN: cesprites/{carbody, cardetail, player_cars, vehicles, designs}.py (additive hooks only – no sprite
vertex may move: tools/blender/check_sprite_geometry.py after every cesprites change, "REIHENFOLGE" lines are fine,
"ANDERS" is not), new cesprites/carinterior.py, tools/blender/ce3d/{vehicles3d, traffic3d, interior3d, extras3d}.py,
assets/models/player/**, assets/models/traffic/{suv,van,sports}/** (and the AS1 cars where interiors, glass, rims or
fixes change them), tools/models/contact_sheet.gd, and in this wave the shared pipeline files of §5 (ce3d core, glb,
roles, bake, lod, manifest, catalog3d, export, export_models.py, validate_models.py, tools/models/**, model_db.gd) –
changes there backwards-compatible; regenerate assets/models/manifest.json yourself on your branch. Never touch
assets/models/props/**, the renderer (scripts/race3d/**, assets/shaders/modern/** – report what the cars need from
the shaders), the frozen Arcade files and sprites.
${PIPE_NOTE}
${QUALITY_BAR}
DELIVER to ${SP}/deliver/AS2a/: contact sheets day and night (every lamp channel) of all five player cars and the
three new traffic types, chase-camera views from behind at 8 m and 30 m for each player car next to its Arcade sprite,
showroom A/B per player car, LOD steps at their switch distances, bericht.md. GATES: validator green, budgets of
§4.6.9, check_sprite_geometry, export determinism (--check-keys; a second bake byte-identical), tools/run_tests.sh
(once, at the end), tools/golden.sh check 20 von 20. An independent art reviewer will inspect your branch afterwards and
a rework step follows – leave clear notes on what you consider weakest. Return the result format with package "AS2a".`,
  { label: 'modelle:AS2a', phase: 'Modelle', schema: BUILD_C, isolation: 'worktree' })
if (!as2a) return { as2a: null }
log(`AS2a: ${as2a.commit ? as2a.commit.slice(0, 7) : '?'} (${as2a.acceptance.filter(a => a.result !== 'pass').length} offen)`)
const AS2A_INFO = JSON.stringify({ branch: as2a.branch, commit: as2a.commit, worktree: as2a.worktree, summary: as2a.summary,
  open: as2a.acceptance.filter(a => a.result !== 'pass'), deviations: as2a.deviations, quality: as2a.quality_verdict,
  notes: as2a.notes_for_next, media: as2a.media })

phase('Kritik und Lkw/Busse/Polizei')
const [review, as2b] = await parallel([
  () => agent(`${common('KRITIK-2', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT ART REVIEW OF THE CAR MODELS (no building). AS2a delivered the remaining player and traffic cars
on branch ${as2a.branch} (commit ${as2a.commit}), worktree ${as2a.worktree} – READ-ONLY for you: no edits, no commits
there. Work on a copy in your scratch folder (cp -a the worktree without build/ and without tools/blender/_cache3d;
absolute XDG_DATA_HOME). You make no commits.
Its report: ${AS2A_INFO}
The review of the first cars and its tools: ${SP}/deliver/AS1-KRITIK/bericht.md and ${SP}/m1/AS1-KRITIK/tools_kritik
(the game camera of D12, the sprite comparison as road_renderer.gd draws it, mesh dumps) – reuse them.
Do not trust the report – render and look yourself. You are the art director who answers one question for the user:
are these cars visibly FINER than the Arcade sprites and good enough to be looked at for hours? Review all five player
cars (kombi, sportwagen, gran_turismo, and limousine and kompakt again because interiors, glass and rims changed) and
traffic suv, van, sports (plus a quick look at sedan, hatch, wagon for consistency of the fleet):
1. The chase camera from behind and above at 8 m and 30 m (1280×720, the shipped shaders, a daylight rig with one
   shadowed sun and a night rig), front and rear three-quarter close-ups, side views, every LOD level at its distance
   (40 m, 120 m) and enlarged, every lamp channel at night, interiors through the glass, a flat-shaded or wireframe view.
2. Side by side with the Cycles sprite of the same vehicle in the same camera, and with the generator's silhouette.
3. Defects, each with where, what, a picture as evidence and a fix the builder can carry out: proportions, waves,
   faceting, holes, normals, z-fighting, floating or saw-tooth decals, lamps without depth, lamp outlines that change
   between levels, LOD pops, missing parts, glass that looks painted, interiors that clip through the body, wheels
   that intersect or float, wrong spin or steering pivots, shadow meshes that do not match, paint sets that look
   wrong; validator, budgets, lamp rules, draw calls per car, the showroom flags (deserved or too cautious?).
Rank by what the player sees most (the rear of the player cars first). Comparison sheets and bericht.md into
${SP}/deliver/KRITIK-2/.`,
    { label: 'kritik:AS2a', phase: 'Kritik und Lkw/Busse/Polizei', schema: REVIEW }),
  () => agent(`${common('AS2b', { mode: 'fresh', base: as2a.commit }, 'content')}
${EARLY}
YOUR ROLE: AS2b – TRUCKS, BUSES, POLICE (contract §6 wave 4 "AS2b"; D17–D24; §4.6; A-4; docs/modelle.md). Your base
is AS2a's final head ${as2a.commit} (branch ${as2a.branch}; it contains AS1, AS1R, R3 and AS2a). Copy its export cache
first: cp -a ${as2a.worktree}/tools/blender/_cache3d tools/blender/ . Push every commit to origin wip/v080-as2b.
AS2a's report: ${AS2A_INFO}
MODELS: every heavy set (traffic/truck_* and traffic/bus_*: 7 sets – check whether the AS1 truck already covers the
truck liveries and build what is missing; buses as articulated or rigid bodies like the Arcade box parts) and all 18
police sets (police/<country>: the car bodies come from AS2a's cars with the country liveries, light bars and
beacons). Acceptance: validator green; all 7 heavy and 18 police sets resolve to models; beacon channels A and B
alternate; the part boxes equal the Arcade box parts (collision unchanged); trucks and buses articulate through groups
with pivots like the AS1 semitrailer (R3's vehicle layer builds the articulation from groups).
FILES YOU OWN: cesprites/{heavy, police}.py (additive hooks only – check_sprite_geometry.py after every change),
tools/blender/ce3d/{heavy3d, police3d}.py (new) and truck3d.py, assets/models/traffic/{truck_*, bus_*}/**,
assets/models/police/**, the shared pipeline files of §5 (backwards-compatible), the regenerated manifest. Never
touch the car models of AS2a (an art review of them runs in parallel; its rework follows after you), the renderer,
the frozen Arcade files and sprites.
${PIPE_NOTE}
THE QUALITY BAR for heavy vehicles: the truck is the most frequent obstacle of the game – its rear at 20–150 m must
read at once (lamps, underrun bar, reflective contour marking, plates, mud flaps); cabs with windows, mirrors, steps,
tanks and lights; buses with windows, doors, destination display, wheels in real arches; police cars as finished as the
traffic cars they are built on, with livery decals that follow the body and light bars with depth. Work in rounds:
build, contact sheets day and night (every lamp channel incl. beacons A/B), chase-camera views at 20/60/150 m next to
the Arcade sprite or box, LOOK, fix, repeat. DELIVER to ${SP}/deliver/AS2b/ with bericht.md. GATES: validator,
budgets of §4.6.9, check_sprite_geometry, export determinism, tools/run_tests.sh (once, at the end), tools/golden.sh
check 20 von 20. Return the result format with package "AS2b".`,
    { label: 'modelle:AS2b', phase: 'Kritik und Lkw/Busse/Polizei', schema: BUILD_C, isolation: 'worktree' }),
])
if (review) {
  const high = review.models.flatMap(m => m.defects.filter(d => d.severity !== 'low'))
  log(`Kritik: ${review.models.map(m => `${m.model} ${m.versus_sprite}`).join(', ')}; ${high.length} Mängel hoch/mittel`)
} else log('Kritik ausgefallen – die Nacharbeit prüft selbst')
if (as2b) log(`AS2b: ${as2b.commit ? as2b.commit.slice(0, 7) : '?'} (${as2b.acceptance.filter(a => a.result !== 'pass').length} offen)`)
const base = as2b || as2a
const reviewText = review ? JSON.stringify(review) : 'NOT AVAILABLE – the reviewer failed. Make your own strict review first (chase camera 8/30 m day and night, close-ups, every LOD level at its distance, lamp channels, interiors, comparison with the Cycles sprites) and fix what you find.'

phase('Nacharbeit')
const as2r = await agent(`${common('AS2R', { mode: 'fresh', base: base.commit }, 'content')}
${EARLY}
YOUR ROLE: AS2R – REWORK OF THE CAR MODELS AFTER THE INDEPENDENT ART REVIEW, AND A STRICT SELF-REVIEW OF THE HEAVY AND
POLICE MODELS. Your base is ${base.commit} (branch ${base.branch}; it contains AS2a${as2b ? ' and AS2b' : ' – AS2b failed, so only the car models are there'}).
Copy the export cache first: cp -a ${base.worktree}/tools/blender/_cache3d tools/blender/ . Push every commit to origin
wip/v080-as2r.
AS2a reported: ${AS2A_INFO}
${as2b ? `AS2b reported: ${JSON.stringify({ summary: as2b.summary, open: as2b.acceptance.filter(a => a.result !== 'pass'), deviations: as2b.deviations, quality: as2b.quality_verdict, notes: as2b.notes_for_next, media: as2b.media })}` : ''}
The independent art review of the car models found: ${reviewText}
Check each defect yourself first (reject it with evidence if it is wrong). Fix every confirmed high and medium defect
and the cheap low ones, most-seen first (the rear of the player cars, then the traffic cars at 20–150 m). Then review
the heavy and police models of AS2b yourself with the same strictness (chase camera at 20/60/150 m day and night,
beacons, LOD steps, comparison with the Arcade sprite or box) and fix what you find. Files: everything AS2a and AS2b
owned (see their reports); the same rules (additive cesprites hooks, check_sprite_geometry, no renderer files, no
props, no frozen files).
${PIPE_NOTE}
Re-render the reviewer's comparison views after each round and LOOK at them. Then: validator, check_sprite_geometry,
contact sheets day and night, the showroom A/B with honest flags, export determinism, tools/run_tests.sh,
tools/golden.sh check 20 von 20. Deliver to ${SP}/deliver/AS2R/ with bericht.md. Return the result format with
package "AS2R" (the state after the rework); rejected findings under deviations.`,
  { label: 'nacharbeit:AS2R', phase: 'Nacharbeit', schema: BUILD_C, isolation: 'worktree' })
if (as2r) log(`AS2R: ${as2r.commit ? as2r.commit.slice(0, 7) : '?'} (${as2r.acceptance.filter(a => a.result !== 'pass').length} offen)`)
return { as2a, review, as2b, as2r }
