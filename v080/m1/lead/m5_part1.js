
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

