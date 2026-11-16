
// ---- ARGS: { rintA: {compact result}, r3e: {compact result} | null, as1r: {compact result}, notes: '<lead notes>' }
const RA = ARGS.rintA
const R3E = ARGS.r3e
const AS1R = ARGS.as1r
const LEAD_NOTES = ARGS.notes || ''

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement for the user, 5-10 sentences' },
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

phase('Zusammenbau 2')
const AUD1 = ARGS.aud1
const mergeList = [
  R3E ? `R3E  = ${R3E.branch} (${R3E.commit})  Arcade pictures as stand-ins for vehicles without a 3D model` : null,
  `AS1R = ${AS1R.branch} (${AS1R.commit})  rework of the AS1 vehicle models after the independent art review`,
  AUD1 ? `AU-D1 = ${AUD1.branch} (${AUD1.commit})  music: chain, title remaster, race track 1 "Linke Spur", MusicDirector (early start of M2, built on UI1's head; the user gets the music in this test build because gate 1 asks for their judgement of sound direction and music level)` : null,
].filter(Boolean).join('\n  ')
const rint = await agent(`${common('RINT-B', { mode: 'fresh', base: RA.commit }, 'render')}
YOUR ROLE: RINT-B – SECOND HALF OF THE ASSEMBLY OF PUSH M1 (A-8). Your base is RINT-A's head ${RA.commit} (branch
${RA.branch}): v0.8.0 with R1, R2, R3, AS1b and UI1 (which brought AS1 and AU-B) merged and made into one picture.
Merge with --no-ff in this order (German messages, trailer as above):
  ${mergeList}
Both were built in parallel with RINT-A: R3E on R3's head (it owns scripts/race3d/layers/vehicles.gd,
model_factory.gd, vehicle_pose3d.gd and its new stand-in files – RINT-A renamed R3's vehicle shadow class to
vehicle_shadow in vehicles.gd, keep that), AS1R on d025d1d (vehicle models, ce3d vehicle builders, cesprites car files,
validator, contact_sheet.gd). AS1R changed tools/blender/ce3d/lod.py, which is part of every model's cache key: after
the merge run tools/blender/export_models.py --check-keys; re-export only what it names (the vehicles; props must stay
byte-identical), regenerate assets/models/manifest.json (--manifest-only), then the validator.
RINT-A reported: ${JSON.stringify(RA)}
${R3E ? `R3E reported: ${JSON.stringify(R3E)}` : 'R3E FAILED – vehicles without a model are still R3\'s painted boxes. Replace them yourself with Arcade\'s own pictures (the sprite cell chosen like RoadRenderer._vehicle_cell/_draw_player, box sets as textured 3D boxes) before the look pass; this is a lead decision for gate 1.'}
AS1R reported: ${JSON.stringify(AS1R)}
${AUD1 ? `AU-D1 reported: ${JSON.stringify(AUD1)}` : ''}
${LEAD_NOTES}
YOU NOW OWN EVERY FILE OF THIS PUSH. Make it the build the user gets:
- Vehicles in the real rig (decisions that R3 left open, now yours): unlit vehicle lamps at 0.25–0.3 of their lit
  colour (AS1R/KRITIK B1: today 0.5 reads as switched on by day); tail level of channel 2 about 0.5 with brake ≥ 2×
  tail (measured); paint exposure – compare the player car and the traffic colours with their Cycles sprites in the
  game camera at noon and dusk (KRITIK A1/B8/C2: kompakt amber turned lemon, reds +46 %) and fix it in vpbr (soft clip
  of the paint, the clear coat from R3, the exposure of the rig) until hue and value are within 10 % of the sprite;
  retro-reflective contour and sign retro-reflection driven by the real low beam (ce_headlight_*), not by ce_night;
  the lod1→lod2 pop at 120 m (22–34 % of a car's pixels, AS1R): a short dithered cross-fade between the levels if it
  is cheap, otherwise the best swap distance – measure before/after.
- Showroom: re-test with the real paint shader (tools/models_contact_sheet.sh <img> --only="player/*" --showroom and
  UI1's check_showroom_render); set showroom: true in catalog3d.py only where the same-camera A/B is at least as good
  as the sprite; regenerate the manifest.
- UI: regenerate the preview pictures of the options page and the chooser with the merged renderer
  (XDG_DATA_HOME=<abs> tools/gfx_previews.sh) and LOOK at them – the "Modern" card must advertise the real picture;
  every new check of UI1 and of the packages is hooked into tools/run_tests.sh / run_render_checks.sh (RINT-A started
  this – complete it).
- Sound: the Modern sound profile with engine v3 plays in the race, the race music "Linke Spur" starts on the count-in
  and ducks under the engine (option „Musik im Rennen“ switches it off), the title remaster plays on the title and
  menu screens; switching Grafik and Klang in the options works; quitting leaves no "leaked at exit" line with either
  profile (AU-D1: GameFlow.quit_game() should shut the sound down, wait about 0.3 s, then quit()); the Arcade sound and
  picture stay unchanged.
- Leistungstest: --bench=all runs on the merged renderer and writes leistungstest.json with real perf_stats.
- LOOK PASS (yours – RINT-A only fixed integration faults): A/B sheets with tools/ab_shot.sh at S1–S5, T1, T4, C1
  (19:30), N1 (night, snow) and N2 (rain), --gfx-preset=high and the preset this machine picks; vehicles at S1 with the
  player cars kombi, sportwagen and gran_turismo too (stand-ins). LOOK at each and improve what is cheap to improve in
  light, materials and composition until Modern is clearly the better picture by day on the slice. Weather effects and
  tunnels come in a later wave, but nothing may look broken there. Write an honest list of what still looks worse than
  Arcade or unfinished.
GATES on your final head (commands and output in bericht.md): import clean; tools/run_tests.sh green;
tools/golden.sh check 20 von 20; tools/run_render_checks.sh all; tests/sim/modern_sight.gd -- --full and
tests/sim/modern_path_check.gd -- --full if the kernel or any placement changed; python3
tools/blender/validate_models.py --report; export determinism (export_models.py --check-keys, a second bake
byte-identical); check_sprite_geometry.py (AS1R changed cesprites files); ERGEBNIS identity Arcade vs Modern
(tests/race/run_stage.gd) on kiel_hamburg, dev_testetappe (night, rain) and saragossa_pau (snow); a complete Modern
autopilot run of Kiel–Hamburg under Xvfb without script errors, with perf_stats at the end (render() ms average and
max, chunk commit ms max, draw calls, primitives – llvmpipe, measured; real hardware inferred); texture memory against
the Arcade race of the same stage (budget + 60 MB, A-6); tools/build_linux.sh and tools/build_windows.sh succeed with
the pck report inside the size budget, and the Windows build starts a Modern stage under Wine (wine64, wineserver -w
between runs, TMPDIR unset). Push every commit to origin wip/v080-rint-b.
Deliver the A/B sheets and a 20 s A/B clip of the start of Kiel–Hamburg (ffmpeg, side by side) in ${SP}/deliver/RINT-B/,
with bericht.md. Return the result format with package "RINT-B", one acceptance entry per item and per gate.`,
  { label: 'zusammenbau:RINT-B', phase: 'Zusammenbau 2', schema: BUILD_R, isolation: 'worktree' })
if (!rint) return { rint: null }
log(`RINT-B: ${rint.commit ? rint.commit.slice(0, 7) : '?'} (${rint.acceptance.filter(a => a.result !== 'pass').length} offen)`)
