
// M2 wave 3: R4, R5 and R6 side by side on the merged M2 head, each build → independent review → fix → re-check.
// ARGS: { base: '<M2ZS1 head = M2INT assembly + the fixes of the delivered first test build>', only: ['R4','R5','R6'] (optional) }
const A = args || {}
const BASE = A.base
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
    verdict: { type: 'string', description: 'is the fixed head a sound base for the M2 assembly? 3-6 sentences' },
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

const SITUATION = `SITUATION OF PUSH M2 (lead): your base ${BASE} (origin/wip/v080-m2int) is the first M2 assembly – M2INT merged
all vehicle models (AS2R), vegetation (AS3R), rural buildings, street furniture, bridge parts and ships (AS4R) and the
reworked Modern sound onto the first test build (report ${D('M2INT')}), and M2ZS1 merged the fixes of the first test
build the user got today (report ${D('M2ZS1')}): the car visible at the start, the far ground under the water at deep
bridges, stand-ins for six landmarks, dark bridge pylons at night. What the user has and what is still missing or worse
than Arcade: ${SP}/deliver/ZS1/was_neu.md (German; read it). THE USER IS AWAY for an indefinite time and asked us to go
on without their test results: decide by the contract and by an honest comparison with Arcade (Modern has to look
clearly better, not merely different); the curve camera, the Steam Deck preset and the music level stay as they are
(the user decides them later). BESIDE YOU run the independent QA of the assembly (QA-M2-BILD measures performance on
this machine), later its fix round FIX-M2 on the same base, and the other two wave-3 packages: R4 light/night/weather,
R5 tunnels/bridges/water, R6 fuel station/border/city/start-finish/radar. As long as the file ${SP}/m1/lead/QA_M2_FERTIG
does not exist, run heavy jobs (Godot renders, test suites, Blender) with nice -n 19, one at a time; afterwards
nice -n 10. FILE OWNERSHIP IN WAVE 3 (contract §5 table, column W3, with A-8): R4 owns the renderer core – race_session.gd
and race_renderers.gd, config graphics, modern_renderer.gd, quality.gd, prewarm.gd, perf_probe.gd, environment_rig.gd,
layers/{lights,backdrop,overlay,vehicles,flares}.gd, the shaders road/terrain/far_ground/vpbr/glass/baked/leaves/
billboard, builders/{road,roadside,terrain,props}.gd, prop_library.gd, model_factory.gd, modern_materials.gd, the kernel
files and tests/sim/modern_*; R5 and R6 own only what their brief names. Stay strictly inside your files and the lead
exceptions of your brief: the lead merges R4, R5, R6, FIX-M2, AS5a and R7 later (RINT-M2), and every other file you
touch becomes a merge conflict – where you need a change in somebody else's file, build your part so that it works
without it and write the exact change into notes_for_next. Every fix of the first test build must keep holding (render
checks check_start_km0, check_terrain_cover incl. K1, check_light_base; unit tests test_far_ground_water and
test_props).`

const PKGS = [
  { id: 'R4', title: 'LICHT, NACHT, WETTER', brief: `YOUR ROLE: R4 – LIGHT, NIGHT, WEATHER (contract §6 wave 3 "R4 – Licht, Nacht, Wetter", §4.9.2 positions N1, N2,
C1, DEV, the render checks and luminance tables of your area, amendments §11). New files: layers/weather.gd,
assets/shaders/modern/{particles_rain, particles_snow, spray}.gdshader, tests tests/race3d/render/{check_night,
check_weather}.gd, tests/unit/race3d/test_light_pool.gd; you own the renderer core listed above for wave 3. LEAD
DECISIONS:
1. Priority 1 is the biggest gap the user will see: "Kein Wetter in der Luft" – no rain drops, no snowfall, no spray
   behind the cars; at rain and snow Arcade shows MORE than Modern today. Rain and snow as GPUParticles3D in camera
   space (cast_shadow off, off in tunnels), spray behind every car on a wet road, wet road (darker, smoother, sky
   reflection, analytical tail-light streaks), snow ground and banks; particles visible at every "Effekte" level
   (Steam Deck preset included) and inside the Deck budget.
2. Night: calibration (ambient, moon, emission), omni pool on the nearest lamps and the beacon, analytical pools (player
   cone 80 m, ≤ 6 traffic cones, ≤ 16 lamps), emissive lamps with glow, retro-reflection of markings, delineators and
   signs; F6 at N1; no light through hills or trucks; N1 mean road luminance within 15 % of Arcade and never darker;
   the luminance/contrast table per weather × hour inside its bounds; the light cap holds along three night stages.
3. Day: dawn, dusk, overcast; the sun disc on the day sky ("Keine Sonnenscheibe" is listed as missing in ZS1); the sky
   reflection resource.
4. Zones: add EnvironmentRig.set_zone(kind, amount) EARLY (interface of the contract; R5 calls it duck-typed from its
   tunnel/bridge code): kind "tunnel" gives tunnel ambient and fog, no sky, and the exposure ramp at the exit (ZS1 lists
   "kein überstrahltes Draußen an der Tunnelausfahrt" as missing); keep today's tunnel01 path (tunnel_blend) working as
   long as nobody calls set_zone. Document the interface in docs/renderer-modern.md.
5. Open look items: take what M2INT left open from its note 6 (report ${D('M2INT')}, chapter "Notiz 6"; the vehicle LOOK
   is already in ModernMaterials, the flakes are off in the race look) and the night fill / paint exposure items of the
   art review (${D('KRITIK-2')}) if they are still open – measure first.
6. API for R6: R6 places street lights every 33 m and station/border lamps through the existing renderer.add_lamps()
   roles – keep that API working (a compatible wrapper if you change it). R5 and R6 may add a one-line skip in
   builders/props.gd for prop kinds their own builders draw now (bridge parts, street lamps) – keep such skips when the
   lead merges.
7. Cold-cache warm-up check on N1 and N2 (no hitch when rain/snow/lamps first appear); perf_stats per preset.
8. Night law for models (M2ZS1, report ${D('M2ZS1')} §3 and §7): M2ZS1 added in your files the baked.gdshader parameter
   night_albedo (default 1 = no change), props.gd _dark_model_override() for the cable-stayed pylons (material copy,
   emit_energy 0, night_albedo 0.45) and the blink rhythm of the red aviation light (props.gd PYLON_BLINK, flares.gd
   blink_lit()) – keep them working. It measured that bright VERTICAL surfaces get more light from the low moon than
   Arcade's ambient law gives them (pylon +40 % before the fix); the player car at night is also brighter than its
   sprite. Measure other bright vertical surfaces at N1/C1/DEV (houses, bridge parts, the player car) against Arcade
   and decide: a general night law for vertical faces, or per-material night_albedo – never brighter than Arcade where
   Arcade is dark.
PICTURES (tools/ab_shot.sh, LOOK at each against Arcade): N1 (Hamburg – Hannover km 71, snow, 22:00), N2
(Dortmund – Frankfurt km 121, rain), C1 (19:30), DEV (dev_testetappe km 48, 21:00), S1 at dawn and at dusk, one
overcast day, a tunnel exit by day; --gfx-preset=high and deck. Clips (60 fps fixed, 20–30 s): night rain with
traffic, snowfall at night, a tunnel exit by day.` },
  { id: 'R5', title: 'TUNNEL, BRÜCKEN, WASSER UND UFER', brief: `YOUR ROLE: R5 – TUNNELS AND BRIDGES (contract §6 wave 3 "R5 – Tunnel und Brücken", renderer inventory B,
render checks U1 and B1 of §4.9.2, amendments §11). Files: builders/{tunnel, bridge}.gd, assets/shaders/modern/{tunnel,
water}.gdshader, tests tests/unit/race3d/{test_tunnel, test_bridge}.gd, tests/race3d/render/check_tunnel_bridge.gd.
Today: tunnel.gd (458 lines) draws a simple tube with lamps and a portal; there is NO bridge.gd – the deck and railings
come from the road builders (R4's files in wave 3), the pylon, lamp and truss parts are props (AS4R models placed by
builders/props.gd, R4's), the water is terrain rows plus the far ground. LEAD DECISIONS:
1. Ownership of water and banks (contract issue raised by QA-WASSER and FIX-WASSER-R): in this push R5 owns what is
   built at water – bridge structures, banks, quay walls and embankments, the water look (water.gdshader) and the far
   water / far bank beyond rivers and canals. You take over scripts/race3d/layers/far_ground.gd (R2's file; nobody else
   owns it in wave 3) – keep the ZS1 rule "far ground at most lowest water − 0.3 m"; test_far_ground_water and
   check_terrain_cover K1 stay green. far_ground.gdshader is R4's: draw the far water and the far bank as your own
   geometry with your own material instead of changing that shader. Seen in the first test build (pictures
   ${SP}/deliver/QA-WASSER/bilder/, ${SP}/deliver/FIX-WASSER-R/bilder/): at the end of the Köhlbrandbrücke Arcade shows
   a grey quay wall, Modern water fading into a green bank; at the Holtenauer Hochbrücke the Kiel Canal reads like a
   lake because the far bank is missing (a strip of meadow at the horizon instead of Arcade's shore).
2. The Köhlbrandbrücke (Kiel – Hamburg km 77.5–81) is the user's showcase bridge: the AS4R pylon model (one level, half
   fans of ±36 m, cables end beside the deck – check that no cable crosses a lane); scale it in height by
   height_m / 88.8 (A-16 gives that to you); bridge_pylon_bare gets its cables from you (A-16). Already done
   by M2ZS1 (report ${D('M2ZS1')} §3, §7): the pylon model is dark at night (props.gd _dark_model_override(): material
   copy with emit_energy 0 and night_albedo 0.45 – km 78.1 at 22:00: 55.9 against Arcade 60.1 and ZS1 58.4; its
   measurement row along the bridge must keep holding) and the red aviation light blinks in Arcade's rhythm (lamp anchor
   of the model at 88.3 m, PYLON_BLINK in props.gd, blink_lit() in flares.gd). If you move the pylon placement into
   bridge.gd, carry both over unchanged and put the light where Arcade has it after your height scaling (height_m +
   1.6 m). By day the pylon legs near the road read bright in the picture – compare with Arcade. Lead exception: you may move the placement of the bridge parts (bridge_* kinds and the pylon) from
   builders/props.gd into bridge.gd – in props.gd only a one-line skip for the kinds your builder claims (duck-typed),
   nothing else; say exactly which lines. Every bridge type of the network (data scan of all stages – cable-stayed,
   truss, stone arch, suspension, viaduct, causeway, whatever the data name) builds headless without error and looks
   like its Arcade picture at the B1 position and three more. If the road builders' deck or railings must change at
   bridges, build bridge.gd so that it works with them as they are and write the exact change into notes_for_next.
3. Tunnels: U1 (Bern – Mailand km 186, Gotthard) and Somport: no sky inside, lamps lit, the exit neither black nor a
   blown-out hole, cars inside follow the tunnel fade law, the end cap after render.tunnel.peek_m seen from outside,
   portal frame and mound closing the terrain (terrain cover ≤ 0.2 % at portals), niches, walkways, wall signs. Short
   old-town tunnels and galleries too, if the data have them.
4. Environment: R4 (beside you) adds EnvironmentRig.set_zone(kind, amount) – tunnel ambient, fog and the exposure ramp
   at the exit are R4's. Do NOT edit environment_rig.gd: call set_zone duck-typed (has_method) from your code, keep
   today's tunnel01 path working without it, and document the exact calls in docs/renderer-modern.md.
5. Fairness: tunnel walls, portals, girders, pylons, quay walls must never make a car or a sign visible later or smaller
   than in Arcade (F1) and must not stand in a bend's sight corridor (F7).
PICTURES (tools/ab_shot.sh, LOOK at each against Arcade; by day and at night; --gfx-preset=high and deck): U1 approach,
inside and exit; Somport; the Köhlbrandbrücke from the ramp, on the deck and at its end, and at 22:00 one picture with a pylon top in view showing
the blinking aviation light (M2ZS1 could not: the top was behind the HUD bar); the Holtenauer Hochbrücke; B1
(a river bridge arrival in Köln or Wien); one truss and one stone bridge; DEV (dev_testetappe km 48, 21:00). A 30-s clip
through U1 and one over the Köhlbrandbrücke at 60 fps fixed.` },
  { id: 'R6', title: 'TANKSTELLE, GRENZE, STADT, START/ZIEL, BLITZER', brief: `YOUR ROLE: R6 – STATION, BORDER, CITY, START/FINISH, RADAR (contract §6 wave 3 "R6 – Tankstelle, Grenze, Stadt,
Start/Ziel, Radar", renderer inventory B/C, amendments §11). Files: builders/{station, border, city, gantry, radar}.gd,
tests tests/unit/race3d/test_structures.gd, tests/race3d/render/check_structures.gd. Today: station.gd (257 lines) is
FIX1's MINIMAL station in Arcade's shapes (island, canopy, fascia with a Label3D "TANKSTELLE"); gantry.gd (264 lines)
draws the start gantry with countdown lamps and the finish gantry – FIX-ZS1 changed it for the first test build (lamp
rings without shadows, the run-up before the start line; report ${D('FIX-ZS1')}); border.gd, city.gd and radar.gd do not
exist – Modern shows no border station at all (Arcade: roof, fascia, booths). LEAD DECISIONS:
1. Fuel station: the real one – shop, price pylon, canopy details, the AS1b pumps and station models where they fit; the
   fuel-lane geometry equals Track.fuel_lane_* exactly (unit test); the refuel sequence of the tutorial stop on
   Kiel – Hamburg (km 15) works and reads well in a clip; nothing hides the lane entry (F1).
2. Border: roof, fascia with the country lettering, booths (AS1b customs hut model if it fits), barrier and stop line
   where Arcade has them; the police stop sequence visible in a clip.
3. City: street lights every 33 m on alternating sides with their light pools through the existing renderer.add_lamps()
   roles (the light system is R4's, beside you: change nothing in layers/lights.gd), fences, hedges and walls,
   crosswalk data. City BUILDINGS are AS5a's, not yours. Lead exception: if builders/props.gd already places street
   lamps that your city.gd now draws, add a one-line skip for those kinds there (duck-typed), nothing else; say
   exactly which lines.
4. Start/finish: countdown lamps and the finish banner visible in a clip; check_start_km0 and check_light_base stay
   green; the car in the countdown stays where Arcade has it.
5. Radar: posts and the camera flash (AS1b speed-camera model where it fits); the flash visible in a clip.
6. Lettering through pre-rendered SignAtlas panels (contract), not Label3D – including "TANKSTELLE".
7. Fairness: canopies, roofs, booths, posts and street lights must never make a car or a sign visible later or smaller
   than in Arcade (F1) and must not stand in a bend's sight corridor (F7).
PICTURES (tools/ab_shot.sh, LOOK at each against Arcade; by day and at night; --gfx-preset=high and deck): every element
on DEV (dev_testetappe km 48, 21:00 – every special element) and by day; the fuel stop of Kiel – Hamburg km 15; one
border crossing of the race Kiel – Nürnberg or the nearest one; a city arrival with street lights at night; start and
finish of Kiel – Hamburg. Clips (60 fps fixed): refuel sequence, police stop, radar flash, countdown with LOS, finish
banner.` },
].filter(p => !A.only || A.only.includes(p.id))

const GATES = `GATES on your final head (commands and output in bericht.md): import clean; tests/check_scripts.gd;
tools/run_tests.sh green (full run at most twice); tools/golden.sh check (20 von 20 and 17 von 17 identisch);
tools/golden.sh modern-check (modern-make only where a Modern golden changed on purpose – LOOK at the new pictures
first and say so in the commit); tools/run_render_checks.sh all; tests/sim/modern_sight.gd -- --full and
tests/sim/modern_path_check.gd -- --full; a complete Modern autopilot run of a stage with your elements under Xvfb
without script errors, with perf_stats (render() ms average and max, chunk commit ms max, draw calls, primitives)
next to the same run on your base (llvmpipe, measured; real hardware inferred).`

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
