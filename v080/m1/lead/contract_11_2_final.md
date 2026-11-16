
### 11.2 During M1 (2026-11-11/12; evidence: the reports of R1–R3, AS1/AS1R, AS1b, UI1, R3E, RINT-A/B, FIX1, QA1, the early M2 packages AS2a/b/R, AS3/AS3R, AS4/AS4R, AU-C1, AU-D1/D2, AU-R/R2/R3/R4 and their independent reviews)

**A-9 Stand-ins (lead decisions)**
- A vehicle set without a model is drawn with Arcade's own picture of that vehicle (R3E: the sprite cell chosen like
  `RoadRenderer._vehicle_cell` / `_draw_player`, measured 0–3 px against Arcade), not with a painted box; §4.4.2
  point 4 yields. The picture sheets are loaded in `prepare()`. Since AS2a/AS2b every vehicle set has a model; the
  stand-in stays as the fallback of §4.6.7.
- Stand-ins (vehicles and props) cast no sun shadow.

**A-10 Look laws (lead decisions)**
- F7 keeps its strict reading until the mountain pictures of gate 2; ground cover ≤ 0.5 m (`props/cover_bush`,
  `props/cover_grass`) fills the curve corridors instead of trees.
- Below the horizon row the far ground must read as distant land, as in Arcade (the fog law of F4) – no bright strip,
  no wall pattern.
- One analytic reflection source for `vpbr` and `glass` (sky colour of the palette), no reflection probes.

**A-11 Measurements (lead decisions)**
- Timing checks are load-robust: they compare against a reference measured in the same run or use CPU time, because
  several agents share the four cores. A check that fails only under load is a broken check.
- The whole renderer gets one budget table (render() ms average and maximum, chunk commit ms, draw calls,
  primitives, texture memory against the Arcade race of the same stage + 60 MB of A-6); RINT-B measures it on the
  slice, PERF finalises it per preset.

**A-12 Plan (lead decisions)**
- Early starts of M2 while the assembly and QA of M1 run, every heavy job at nice 19 with one worker: AS2a → (an
  independent art review ∥ AS2b) → rework AS2R; AU-D1 → AU-D2; AU-C1; AS3 and AS4, each with review and rework.
  AS5a/b and AS6 still never run beside a rendering QA package (§8).
- AU-D1 (title remaster, race track 1, MusicDirector) is merged into the first test build, because gate 1 asks for the
  user's judgement of sound direction and music level; AU-D2, AU-C1 and the new models follow in test build 2.
- Every mix decision the user may still change (sub and bass level, high shelf, music against the car, menu level,
  UI level) lives in `tools/audio/music/mischung.json`; one change re-renders every piece consistently.

**A-13 Models (findings of the reviews; confirm in the M2 integration)**
- Lamp channel 15 `retro` (RINT-B): retro-reflective tape and reflectors are a surface channel that lights up in the
  player's low beam (`vpbr`, the cone law of `inc/headlight.gdshaderinc`); the validator knows channels 0–15.
- The validator's lamp rule counts visible area by a ray test, not area by winding (three hidden lamps passed).
- Police LOD2 budget 1,400 triangles (livery, light bar and the outline-cut rear window do not fit into 1,200).
- The vehicle LOOK (exposure, clear coat, fill) lives in one place (`ModernMaterials`); the vehicle layer, the contact
  sheet and the showroom read it. The far-level albedo constants of the models (`TRAFFIC_GLASS_FAR`,
  `truck3d.GLASS_FAR`, `FAR_PLATE`, `CHECK_MEAN_EXP`) are re-measured whenever the LOOK changes.
- `police3d` uses official hook parameters of `traffic3d` instead of runtime patches.
- `tests/race3d/check_vehicles.gd` „kasten“ uses a test manifest with one model-less set; „leistung“ counts only cars
  that appear in the window, or the layer builds every level when a car appears.

**A-14 Modern sound: measuring criteria (lead decisions after the user's headphone verdict and the re-measurements
KRITIK-R / AU-R2)**
- The user's verdict on AU-C1's previews („solide", „die Musik ist sehr gut") fixes the character: a changed layer
  keeps its third-octave spectrum within ±1 dB and its loudness within ±0.5 LU of AU-C1 at the reference speeds
  (130 km/h asphalt and concrete, 50 km/h cobbles). The music is unchanged until the user has played a test build.
- R1 (no exact repetition: no envelope autocorrelation peak ≥ 0.40 at lags 0.3–3 s over 20 s at constant speed) is
  judged on concrete without the slab layer; the 5-m slab rhythm is wanted. `audio.modern.road.slabs.db` stays 3 until
  the user decides otherwise.
- The concrete share per country is held within ±0.05 only for countries with ≥ 10 autobahn sections.
- Limiter criteria are statistics: heavy crash at 130 km/h closing – p95 of the gain reduction over 60 crashes ≤ 3 dB
  and every crash ≤ −1.0 dBTP at master volume 1.0; cruising 130–200 km/h – the largest gain reduction per 60-s run
  ≤ 0.5 dB in each of at least four runs; the 0.05–0.14 dB that `AudioEffectHardLimiter` leaves standing after an
  intervention does not count.
- Old-town cobbles never on a bridge whose deck is not stone (AU-R3).

**A-15 Test builds and QA (lead decisions after QA1)**
- §4.9.2 gains position **S0**: the standing start of Kiel – Hamburg at km 0 with the countdown. Every A/B set and the
  Modern goldens (`modern_start_mittel`) contain it; QA1 found that the start of every stage was never in a picture
  (QA1-B1). Before track point 0 the road path continues straight along the tangent at z = 0, so the camera stands
  9 m behind the car as in Arcade (fix for the first test build).
- F1 also covers roadside signs: a sign Arcade shows must be on screen in Modern no later and no smaller than in
  Arcade from Arcade's first appearance until 1.5 s before the car passes it at 130 km/h (about 55 m). Closer than
  that it may leave the picture earlier (the curve camera looks into the bend, QA1-B2). The check is added before the
  curve camera is finalised.
- The curve camera is the user's decision after the first test build ("so lassen, stärker oder schwächer"). A-3 holds:
  weaker needs a new `modern_sight.gd -- --full` run (and a compensation if F1 fails) before it ships.
- The second Arcade identity list (menus, GameFlow start, pause, loading picture, 1280 × 800) hashes pixels after
  masks for the wall-clock arrows of vehicle and start-time choice and the version text; it runs in
  `tools/golden.sh check` beside the 20 race frames.
- The budget "draw calls including shadows" cannot be read in Compatibility (the engine reports 0 draw calls for
  shadow passes but counts their triangles): PERF counts shadow casters and shadow triangles instead. The `deck`
  budget of `render()` (1.5 ms) is measured headless at normal speed (`renderer_zeit`); the Leistungstest numbers on
  llvmpipe under load are information only; on real hardware the user's `leistungstest.json` counts.
- `tests/race3d/bench_modern.gd` is replaced by the real Leistungstest runner with a scene list from
  `user://game_config.json`; `scripts/race3d/benchmark.gd` stays UI1's file, QA owns the scene lists.
- Test builds: `tools/build_testbuild.sh <version> <name> <user folder>` sets the version, an own user folder and the
  Windows file version only for the export (nothing committed); `tools/smoke_modern.sh` checks Linux, OpenGL ES and
  Windows under Wine. A test build never touches the user's installed release (own names, own user folder).

**A-16 Environment models (lead decisions after AS3/AS3R and AS4/AS4R)**
- Seed variants (`_b`) share their species' leaf atlas through `variant_of` in `model.json`; §4.5's texture-source
  budget counts a shared atlas once; tools, test fixtures and the export include the base atlas.
- The tags of §4.6.6 gain `ground_align` (tilt plants and ground cover to the ground normal), `ground_sink` (set rocks
  and cliffs on the lowest ground point of their footprint) and `face_road` (turn a model at most ±20° away from
  facing the road). They are inputs of the props builder (R7); until then heather floats on steep slopes and a cliff
  can stand crosswise.
- Building windows that light at night live in the night-light atlas of the `baked` class (recessed fillers), not in
  `vpbr` channel 12 (channel 12 shows half its light colour when unlit, brown by day; it stays for lamps with a light
  anchor). D20 and §4.6.4 read so. The window light is balanced at `emit_energy` 1.6 against Arcade; whoever changes
  it re-balances. The AS1b buildings (farmhouse, customs hut, fuel station) move their window panes the same way.
- Bridge pylon: Arcade adapts height (`height_m` 50–120 m) and cable fan per bridge. Until R5 draws the cables per
  bridge from `height_m`, `cables` and the deck edge on `props/bridge_pylon_bare` (pylon scaled in height by
  `height_m` / 88.8), Modern uses `props/bridge_pylon` (one level, half fans ±36 m, every cable ends beside the deck).
  No part of a bridge prop may stand below 2.5 m inside the half deck width.
- `extent_m` of a prop that does not stand edge-flush (the pylon) comes from the sprite generator (`extent_source`);
  the validator accepts it.
- Boats (`props/houseboat`, `props/ferry_ship`) are only drawn where the ground under them is water; R5 sets them on
  the water surface.
- Impostors carry the sprite rig's relief, normalised (the billboard law of §4.4 is unchanged); dimming that relief
  at dusk and night needs a time-of-day factor in `billboard.gdshader` (R7 with R4).
- Tree LOD swaps get a dither cross-fade of 0.3–0.5 s like the vehicles' `xfade` (R7); the swap is decided per tree
  where possible, not per 96-m chunk.
