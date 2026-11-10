# Crossing Europe v0.8.0 – „Modern“: Build Contract

Status: **binding** for every build agent of v0.8.0. Written by the adversarial synthesis of the five design studies
(engine probe, renderer, assets, audio, product/UX/tests/release) plus own verification experiments.
Language of this contract: English. Code comments: English. Player-facing texts and all docs in `docs/`: German,
always through `tr("Deutscher Text")`.

How to use it
- Read §2 (rules), §4 (interfaces that concern your package), §5 (your files) and your package in §6 before you start.
- Where a study and this contract disagree, **the contract wins**. Where the contract is silent, the study of your
  area is the guideline (paths in §10). Where the contract is wrong or blocks you: stop, report to the lead with
  evidence, do not work around it silently. Existing public APIs in `ARCHITECTURE.md` stay contracts: extend, never
  change or remove.
- "measured" = measured on this VM (Mesa llvmpipe under Xvfb, 4 shared cores). "inferred" = not measurable here
  (anything about a real GPU, the Steam Deck, ANGLE/Direct3D). Never present an inferred number as measured.

---------------------------------------------------------------------------------------------------------------------

## 1. What v0.8.0 is

User request (German, verbatim meaning): the game gets a graphics option. Today's game becomes the mode **„Arcade“**.
New mode **„Modern“**: a clear graphical overhaul of the whole game – detailed graphics, finer models, better light
effects, reworked sound and music.

What we build
- One build with two renderers on Godot 4.7.2 **GL Compatibility**. „Arcade“ = today's pseudo-3D renderer, untouched
  and pixel-identical. „Modern“ = a second, real-3D renderer (true world-space road and terrain built from the same
  `Track`, real meshes baked from the existing procedural Blender generators, sun with shadows, headlights, emissive
  lights with glow, fog, particles, post effects), a real-time 3D showroom in the vehicle selection and a „Modern“ sound
  profile (engine v3, road/wind/world layers, remastered title theme, music in races).
- The simulation is shared and identical in both modes (same track, traffic, physics, collisions, records).
- Mode switch in the options and in a one-time chooser at the first start.

What v0.8.0 is not (moved to 0.8.x unless the user decides otherwise, §9)
- No living 3D title scene, no 3D menu background, no HUD re-skin, no mode switch inside the pause menu, no dynamic
  resolution, no Forward+/Mobile profile, no reflection probes, no interiors or driver figures for traffic, no
  country-specific siren research, no number-plate textures per country, music tracks 4–5 only if time allows.

---------------------------------------------------------------------------------------------------------------------

## 2. Rules (not negotiable)

**Rule 1 – Arcade is frozen.** These files are not edited at all in v0.8.0 (not even comments):
`scripts/race/{road_renderer,backdrop,geo_batch,sign_painter,box_vehicle,vehicle_pose,palette,projection,track,
track_segment,session_rules,autopilot,tutorial_coach}.gd`, everything in `scripts/gameplay/` and `scripts/data/`,
`scripts/audio/{engine_audio,engine_bank,engine_gearbox,room_audio,sfx_synth,traffic_audio}.gd`,
`assets/sprites/**`, `assets/audio/{engines,traffic,music}/**`, `tools/audio/{engine,traffic,music}_synth.py`,
`data/**`. Modern code may *use* them (instantiate, call static
helpers, subclass in a new file) – that is wanted (e.g. `RaceBackdrop`, `SignPainter`, `Palette`,
`RoadRenderer.prop_flipped`). Sprites are **not re-rendered** in v0.8.0.
A bug found in a frozen file is reported to the lead, not fixed on the side.

**Rule 2 – Arcade identity is a hard gate.** `tools/golden.sh check` (hash list generated from tag v0.7.0, §4.9.3) must
report every frame identical after every package. A package that changes one Arcade pixel is not done.

**Rule 3 – One simulation.** Nothing in `scripts/race3d/`, `scripts/audio/modern/` or the UI may feed back into the
simulation. `RoadProjection.visible_fraction` (one-third rule) stays the projection of the simulation in both modes.
The sprite manifest stays the source of vehicle dimensions for the simulation in both modes
(`traffic.set_dimensions(SpriteDB.sets)`). `run_stage.gd` must give the same `ERGEBNIS` in both modes (except `gfx`).

**Rule 4 – Graphics and sound are independent.** `AudioManager` and everything under `scripts/audio/` never read the
graphics mode or anything of the renderer; the renderer never reads the sound profile. Every combination
(Arcade/Modern picture × Arcade/Modern sound) must work.

**Rule 5 – Everything is generated here.** No third-party asset packs, samples, fonts or shaders. Blender 5.2 as Python
module `/home/user/tools/bpyenv/bin/python`, numpy/PIL, ffmpeg, ImageMagick, Godot 4.7.2.

**Rule 6 – Budgets** (§4.10, §4.11) are part of "done": archive < 350 MB hard (warn 300, build fails 330), draw-call /
primitive / script-time budgets per preset, asset budgets per category.

**Rule 7 – File ownership** (§5): you edit only files your package owns. Shared files have exactly one owner per wave. New
files go where §5 says. Generated shared files (`assets/models/manifest.json`) are regenerated, never hand-merged.

**Rule 8 – Runs.** Every game run of an agent sets `XDG_DATA_HOME` to a scratch folder. Every run of the full game or the
race scene from a tool or test passes `--graphics=arcade|modern` explicitly. Heavy jobs (Blender bakes, Xvfb render
checks, audio renders) run sequentially inside a package, with at most 2 worker processes, `nice -n 10`.
Render checks of one run share one `XDG_DATA_HOME` and one `MESA_SHADER_CACHE_DIR` (cold shader caches cost
0.5–1.9 s per shader variant on llvmpipe, measured).

**Rule 9 – No silent quality toggles.** Whatever the player must react to (vehicles, their lights and indicators, signs,
road edges, markings, guardrails, tunnel walls) is never thinned out, shortened or dimmed by a quality setting.
Quality settings may change shadows, anti-aliasing, resolution, decorative density, LOD distances of scenery, effects.

**Rule 10 – Determinism in test mode.** With `--gfx-sync` (set by every screenshot/golden/render check): chunk builds are
synchronous, particle systems use fixed seeds, nothing reads the wall clock (use `view["time"]`), the watchdog is off.
The audio mixer runs synchronously with `--audio-sync`.

---------------------------------------------------------------------------------------------------------------------

## 3. Decision record

Each decision names its evidence: [E] engine probe, [R] renderer study, [A] asset study, [S] audio study,
[P] product study, [X] synthesis experiment (own measurement, §10).

### 3.1 Architecture and engine

D1 **Compatibility renderer for both modes, switch without restart.** Arcade frames were bit-identical before and
after a 3D scene ran in the same process [E]; Forward+/Mobile cannot even be started here and would force a restart
and a second 2D backend. No project-wide render state is changed for Modern: `use_hdr_2d` stays off; MSAA 3D, 3D
scale, shadow atlas size and filter quality are set on entering Modern and restored on leaving.

D2 **True world-space 3D**, not a bent or sheared world [R]. Heading integrated per 3 m segment from the curve value;
within everything loaded at once the road never comes closer to itself than 267.6 m (all 128 stage directions). The
world is only *locally* consistent (8 stage directions cross themselves 2.5–6.6 km of path apart): stream strictly by
path distance, every piece of world is owned by its chunk and freed with it, **no world-space caches, no world grid**.
Insurance for the fallback (sheared mapping, §8): builders take every position from `RoadPath3D` / `ChunkContext`,
never assume chunk node transforms are static, and place rigid instances through `ChunkContext.frame()`.

D3 **Forcing the track generation ahead is harmless.** Modern integrates the path up to 1,900 m ahead of the camera;
that generates `Track` segments earlier than Arcade does. Verified [X]: with generation forced 1,900 m ahead every
frame, and with the real 3D spike renderer, `run_stage.gd` gives the identical `ERGEBNIS` (27 of 27 keys;
dev_testetappe night rain, Saragossa–Pau snow). The generator is sequential and its window is only cut behind the
camera.

D4 **Rendering on the main thread** (the separate render thread is flagged experimental by the engine [E]). The
draw-call count is therefore a CPU budget next to GDScript (§4.10). Chunk meshes are *built* on `WorkerThreadPool`
(arrays only), *committed* on the main thread, at most one chunk per frame.

D5 **Exactly one shadow-casting light**: one `DirectionalLight3D` (sun by day, moon by night) that **always** has
`shadow_enabled = true`. No shadowed omni/spot lights anywhere. Reasons: the first shadowed directional light costs
only the caster draws; shadowed lights are added in sRGB space, so the lit brightness depends on the shadow flag
(ambient 37 + sun 84 → 91 without, 120 with the flag [X], same finding [E]).
„Schatten: Aus“ therefore keeps the flag and switches the **casters** off (`cast_shadow = OFF`, atlas 1024):
identical brightness, 3 instead of 15 draw calls in the probe, and the same value for orthogonal, 2-split and
4-split shadows [X]. In tunnels the sun energy goes to 0 (equals
"ambient only" exactly [X]); the light is never hidden or disabled (that would be a new shader variant).

D6 **The post path is pinned on**: `Environment.adjustment_enabled = true` in every preset, in every scene of Modern
(neutral values unless graded). Glow, SSAO and 3D scale ≠ 1 also select the post path; with it pinned, quality
toggles do not change the base look ([E]; ±1 level in [X]). Glow is a preset option, not a requirement.
Tonemapper: `LINEAR`, constant for the whole game in v0.8.0 (colour parity with the Arcade palette).

D7 **Background = `BG_CANVAS`** with the existing `RaceBackdrop` on a canvas layer (sky gradient, sun/moon/stars,
clouds, all silhouette styles, skylines, landmark silhouettes) [R][E]. Never `BG_COLOR`/`BG_CLEAR_COLOR` (4× too
bright with glow [E]). A small `Sky` resource (palette gradient) is set on the same `Environment` **only** as
reflection source (car paint, glass, wet road): verified that sky reflections and sky ambient work with a canvas
background, also with glow + 3D scale 0.75 + MSAA 2× + depth fog [X]. Ambient light: `AMBIENT_SOURCE_COLOR` from the
palette. The sky resource is updated at most every 2 s and never uses `TIME`. Upgrade in wave 7: a canvas sky shader
(fbm clouds) replaces `draw_sky`; the silhouettes stay.

D8 **Real positional lights are capped at 8 omni + 2 spot in total**, all unshadowed: 2 `SpotLight3D` for the
player's headlights, a pool of `OmniLight3D` (2/4/8 by preset) moved to the nearest street/tunnel/canopy lamps and
the police beacon. Everything else is emissive geometry (+ glow) and **analytical light pools in the road and
terrain shaders** (player cone, ≤ 6 traffic cones, ≤ 16 lamp pools). With ≤ 8 + 2 lights the per-object limit
(8 omni + 8 spot per mesh, 32 in total [E]) can never be hit, so road chunks stay 96 m and no project limit is raised.

D9 **Unavailable features are not used**: Decal, volumetric fog, SSR, SSIL, SDFGI, TAA, FXAA, SMAA, FSR, debanding,
glow levels, particle trails/sub-emitters, alpha hash (renders white), `ReflectionProbe` `UPDATE_ALWAYS`, visibility
range fades, LightmapGI [E]. Substitutes: markings in the road shader, quads 1–2 cm above the road for skid marks
(only up to 250 m), alpha scissor for foliage and fences, dithering in shaders for gradients, hard LOD swaps hidden
by distance and fog, MSAA 3D + 3D resolution scale as the only AA/performance levers.

D10 **Shader warm-up is mandatory.** Every shader variant compiles on first use (0.5–1.9 s cold on llvmpipe [E]).
Per preset fog mode, PSSM mode, split blending and shadow filter quality are constant for a whole stage; the
renderer pre-warms behind the loading overlay by rendering the real materials in the real light combinations in the
main viewport (replay, not "everything once" [E]).

D11 **Coordinates are rebased** around the camera (floating origin, re-based when the camera is > 2 km from it;
the true path reaches 37.8 km = 4 mm float spacing) [R][E].

### 3.2 Camera and fairness

D12 **Camera = Arcade's projection, exactly**, plus a look-into-the-curve yaw. `Camera3D` with
`PROJECTION_FRUSTUM`, `keep_aspect = KEEP_HEIGHT`, `size = near · H / 711`, `frustum_offset = (0, −0.05 · size)`,
position = `(camera_z, camera_x, camera_y)` of the view, no pitch, no roll. Verified [X][R][P]: 0.000 px against the
Arcade formula at 1280×720, **1280×800 and 1680×720** – the focal length stays 711 logical px at every aspect.
Yaw = `look_gain` (0.6) × bearing of the centreline `look_m` (100 m) ahead, a function of position only (max 12.6°,
player car off-centre p99 57 px, max 135 px) [R]. Shake = frustum-offset jitter. No FOV kick, no depth of field, no
darkening vignette over the road in v0.8.0. `look_gain` is a config value, not an option.
Near plane 1.0 m, far plane 2,600 m: with the 24-bit depth buffer the depth step is d² / (near · 2²⁴) = 0.4 mm at
80 m, so decal patches ≥ 1.5 mm above a car body are clean up to the 80 m of LOD0 (computed; the formula reproduces
both observations of [A]: z-fighting at 150 m with near 0.3 m, clean with near 2 m).

D13 **Modern fills the window** (16:10 on the Steam Deck, ultrawide): the race uses stretch aspect `expand` in
Modern; the extra rows/columns only add view (D12), so the fairness tests made at 16:9 stay valid. Arcade keeps
`keep` (bars). The simulation's `RoadProjection` stays 1280×720 in both modes. Verified [X] with the spike on a
1280×800 screen: the 3D picture fills the screen and the **unchanged HUD code** lays itself out to the four corners
(`synthesis/out/terr/expand1610_kw60.jpg`).

D14 **Fairness is "practical", proven by tests, not literal.** Literal "visible at least as early as in Arcade
everywhere" is impossible in true 3D (one cannot look through the hill a road winds around) [R]. Binding criteria:
- F1 Everything on screen in Arcade within **270 m** is inside the Modern frustum (0 cases in 86.6 M samples [R]).
- F2 Beyond 270 m: stopping sight distance at the fastest drivable speed ≤ **0.6 ×** the distance at which Modern
  first shows the target (worst measured 0.59, dry/rain/snow [R]).
- F3 Crests: no vehicle (0.75 m) or sign (2.8 m) is seen later than in Arcade **and** inside the stopping sight
  distance (0 of 5,923 [R]).
- F4 Static scenery is never fogged more than in Arcade at the same road point: depth fog begin = 0.45 × visibility,
  end = 1.0 × visibility, linear.
- F5 Vehicles and signs fade by **path** distance with Arcade's law (`1 − t²`, in tunnels Arcade's tunnel law), as a
  dither discard – identical to the visibility model of the simulation ("seen" at 0.839 × visibility).
- F6 Indicators, tail and brake lights keep Arcade's minimum screen size through flare billboards
  (`RoadRenderer.INDICATOR_MIN_PX`, `INDICATOR_MIN_GLOW_PX`); at night a tail light at 0.839 × visibility is above
  the pixel-luminance threshold of the render check.
- F7 Art rules: terrain never rises above the road level of its cross-section inside the sight corridor (inside of
  a bend up to the sagitta of a 300 m chord, d²/8R; elsewhere up to 8 m from the paved edge); no decorative
  vegetation inside that corridor on the inside of bends; „Details“ never touches gameplay objects (Rule 9).
F1–F3 and F7 are headless tests in `tools/run_tests.sh` using the shipped camera and terrain parameters; F4–F6 are
render checks.

D15 **Records, savegames and leaderboards are shared between the modes.** Results and leaderboard entries carry a
hidden field `gfx` (`"arcade"|"modern"`) for later analysis; it is never shown and never filters. No data-module
code changes: `LeaderboardStore.sanitize_entry` keeps extra keys; the UI adds the field when it builds the entry.

### 3.3 Terrain

D16 **Ruled ribbon + valley floor.** Terrain is a ribbon owned by the chunk: rings at 0/5/15/40/100/220/480 m beyond
the shoulder (outer ring up to 1,000 m on „Details: Hoch“ where the clearance allows), heights = road height of the
same cross-section + `TerrainProfile` relief, width clamped on the inside of bends to `min(0.8 R, clearance)`.
Closure (verified [X] at four spike positions incl. the two worst): the **outer edge of the last ring lies on the valley floor**
`floor_y(k)` = lowest road within ±900 m of path − 4.5 m; a **far-ground plane** follows the camera at
(lowest road of the loaded window − 4.0 m), coloured like the far ring and fogged by depth; the backdrop silhouettes
stand on the **true horizon row**; the canvas below the horizon row is filled with the fog colour. The valley floor
only ever lies *below* the road, so it cannot hide anything (F7). Before/after:
`synthesis/out/terr/ab_sp172_before_after.jpg`. A world-grid heightfield is ruled out by D2.

### 3.4 Assets

D17 **The existing generators are the source of all models** [A]; sprites are not touched. New package
`tools/blender/ce3d` + `export_models.py`; changes inside `tools/blender/cesprites` are additive hooks whose defaults
reproduce today's geometry (regression fixture, §4.6.8).

D18 **Own GLB writer, then bake – no Godot scene import at build time.** Blender's stock glTF exporter loses every
procedural material [A][E]; Godot's `.glb` scene import is not byte-reproducible (random node ids [P]) and would end
the reproducible archives. Pipeline: generators → `ce3d` (own GLB writer) → `.glb` **intermediate** in the
git-ignored `tools/blender/_cache3d/` → `tools/models/bake_models.gd` (headless Godot: `GLTFDocument` →
`ImporterMesh.generate_lods` where allowed → node-free `ArrayMesh` `.res`, surface names = material class, **no
materials inside**, fixed resource ids) → committed `assets/models/**`. Verified [X]: the bake runs headless, is
byte-identical across runs and identical between headless and Xvfb/OpenGL; [P] measured the same with materials.

D19 **Three material translation paths** [A]: flat colours → vertex-PBR; procedural shader decals of vehicles →
real geometry (single layer, cast onto the body of that LOD); procedural materials of static props → baked atlas
(Cycles EMIT, 2× supersampled, 16 samples) or vertex-colour bake for lattice models.

D20 **Five material classes, one vertex format for everything untextured** (§4.6.3–4). Resolves [A] (≤ 10 role
surfaces per car) against [E] (4–6 surfaces + wheels) and the draw-call budget: a traffic car is **2 surfaces + 4
wheels at LOD0, 1 surface at LOD1/LOD2**. Lamps, paint slots and night windows are vertex codes evaluated by the
shader with per-instance uniforms. Verified end to end [X]: codes survive Godot's attribute compression in a
compressed `.res` (0.25 → 0.247, lamp channels exact), instance uniforms, a runtime global uniform and a 50 %
dither fade work in Compatibility.

D21 **LODs come from generator detail levels**, never from decimating finished patch-built cars [A]. Explicit LODs
with hard swap distances; Godot's automatic mesh LOD is generated in the bake **only for models without decal
patches** (buildings, landmarks, terrain props, wheels) – it is itself a decimation.

D22 **Vegetation is rebuilt as card foliage** (trunk + core + alpha-scissor leaf cards, wind weights) [A]; far LOD =
impostor baked from the card tree. The Arcade prop sprites are only the **stand-in** for sets that have no model yet
(`fallback: "sprite"`), never the final far LOD of a modelled set. From wave 1 on every stage is drivable in Modern
because every sprite set resolves to a model or an explicit fallback – there is no per-stage gating of Modern.

D23 **Textures**: VRAM-compressed S3TC (BC1 albedo and emission, BC3 with alpha) with mipmaps; tiers 2048×1024 for
city-centre blocks, 1024 for small houses and props, 2048 for landmarks, emission half size [A]. Sources committed as
PNG (≤ 1024) or WebP quality 95 (2048) with committed `.import` files written by a script.

D24 **Mirrored props use a mirrored MultiMesh node**, not a second mesh: a `MultiMeshInstance3D` whose node basis
has a negative determinant renders its instances mirrored with correct culling and lighting (verified [X]: identical
pixels to the unmirrored node). A single mirrored instance *inside* a MultiMesh renders inside-out [A] – so mirrored
and unmirrored instances of a set go into two MultiMesh nodes. Landmarks are never mirrored and not turned.

### 3.5 Audio

D25 **Modern sound is a second, self-contained implementation** [S]: `AudioManager` keeps its API and delegates to
`ModernAudio` when the profile is modern. Arcade audio files, classes and assets stay byte-identical; Modern buses
have own names (prefix `M`, into `MMaster` → `Master`); only the Master limiter is shared.

D26 **Mix rate stays 44.1 kHz** (fixed at driver start; an Arcade test counts 44.1 kHz frames [S][X]). Modern music,
ambience and one-shots at 44.1 kHz; engine banks 32 kHz stereo int16.

D27 **Engine v3**: per-car stereo cycle banks from the existing physical model (per-tailpipe panning, decorrelated
flow noise), same cycle-synchronous algorithm, load attack/release, slow modulation, saturation, clips; turbo,
driveline, tyres and wind as natively mixed loops [S]. The mixer feeds the `AudioStreamGenerator` from a **worker
thread** (0 underruns with 400 ms hitches vs 535 on the main thread [S]) with a synchronous fallback
(`audio.modern.engine_thread = false`, forced by `--audio-sync`).

D28 **All audio hooks come from the simulation and `Track`**, never from the renderer (Rule 4): the session passes
vehicle state and events; a pure `AudioFeed` derives surfaces, zones, joints and pass-by objects from `Track`
segments. (The audio study's "pass events from the 3D prop placement" is dropped.)

D29 **Loudness plan** [S]: full throttle −16 LUFS short-term, cruise ≈ −21, idle ≈ −24; in-race music 8 dB under the
car with scripted ducking (attack 50 ms, release 450 ms), menu music −20; masters −14 LUFS, true peak ≤ −1 dBTP.
Ducking is scripted bus volume, not the sidechain compressor (measured far stronger than nominal [S]).

D30 **Music**: remastered title theme (same composition, own file), in-race tracks with count-in → loop body →
bar-synced ending through `AudioStreamInteractive` (fallback: two players with manual crossfade), one interlude loop
for the screens between stages, stingers and UI sounds. **Must: remaster + 3 race tracks + interlude + stingers;
tracks 4–5 if time allows.** Option „Musik im Rennen“ (default on in the Modern profile; Arcade has no race music).

### 3.6 Product and UX

D31 **Settings**: `graphics_mode` (arcade|modern), `sound_profile` (auto|arcade|modern; **auto = follows the chosen
graphics mode**, so the user's "Modern" is picture + sound by default, yet a graphics fallback never changes the
sound and weak machines can still pick the Modern sound), quality preset + five quality values, `race_music`
(§4.1). Resolves [S] (one switch) against [P] (two switches).

D32 **Mode resolution**: command line `--graphics=` > config `graphics.force_mode` > crash-guard marker (→ Arcade) >
stored choice > **Arcade**. Without a stored choice the game is Arcade – every existing tool, test and CLI start
behaves as today. Interactive players always have a choice: a one-time chooser „GRAFIK WÄHLEN“ at the first start of
v0.8.0, for new and existing players, shown only when the game is started **without any user argument** and not
headless.

D33 **A change applies** in the menus at once (showroom), in a race from the next start of a stage. The renderer is
never swapped inside a timed stage; the pause menu has no graphics options.

D34 **Fallback in three layers**: (a) render self-test inside `prepare()` before the first Modern scene of a run
(96×96 SubViewport, lit sphere + custom-shader quad, read back; 140–156 ms first, ~50 ms later [P]); (b) crash guard
`user://modern_start.lock` written before the first Modern scene and removed after 2 s of drawn frames; (c) slowness
watchdog (one automatic preset step-down during the countdown, an offer on the result screen). A failure of (a) or a
broken/missing model manifest starts the stage in Arcade with a message. `--graphics=arcade` is the documented rescue
switch.

D35 **Quality settings** expose only what Compatibility honours: Voreinstellung, Schatten, Details, Auflösung (3D
scale), Kantenglättung (MSAA), Effekte (§4.10). Adapter tier by **name** (the adapter type is always OTHER in
Compatibility [P]): software / weak / deck / ok. Recommended mode in the chooser: Modern for deck/ok, Arcade for
software/weak.

D36 **"Das gesamte Spiel" in v0.8.0**: complete race view for every stage in both directions, every weather and time
of day; 3D showroom (per car only where the real-time model is at least as good as its Cycles sprite – manifest flag
`showroom`); loading overlay with progress and warm-up; attract demos in the current mode; HUD unchanged (same code,
fills 16:10 in Modern); built-in „Leistungstest“; Modern sound and music. Title picture, fonts, icons, map, stage,
result, leaderboard and ferry screens stay 2D and unchanged.

### 3.7 Tests and release

D37 **`tools/run_tests.sh` stays one headless pass** (today 434 s [P]); Modern adds headless checks (≤ 60 s) because
the simulation suites are renderer-independent (proved by a mode-independence scenario). Everything that needs
OpenGL goes into `tools/run_render_checks.sh` (Xvfb, fast-forward screenshots: 4× faster, same hashes [P]).

D38 **Goldens**: Arcade = exact MD5 list generated from tag v0.7.0 on the test machine (hard gate, Rule 2). Modern =
change detectors with tolerance tiers (same driver: exact; other driver/GLES: max channel difference ≤ 2 and
PSNR ≥ 60 dB; else contact sheet for a human) [P]. Modern correctness is asserted by render checks (positions,
occlusion, luminance, fog law), not by goldens.

D39 **User review gates** are part of the plan (§7): nobody can see or time the renderer on a real GPU here, and
nobody has heard the audio. Each gate delivers A/B sheets, clips, audio previews and a test build with the
Leistungstest.

D40 **Deliverables** are the two archives only (the bare executables are 620–710 MB, above the 400 MiB delivery
limit) + `LIZENZEN.txt` + `SHA256SUMS`, uploaded to the existing draft release „v0.8.0 Grafische Überarbeitungen -
neuer Modus“. `tools/build_release.sh` prints a per-category size table and enforces Rule 6.

---------------------------------------------------------------------------------------------------------------------

## 4. Interfaces

### 4.1 Settings and `Gfx`

`user://settings.json`, **`settings_version` 3**. New keys, each written only once the player has chosen it (pattern of
`fullscreen`); invalid values count as "not chosen"; keys the running version does not know are kept when saving.

| key | values | default when absent |
|---|---|---|
| `graphics_mode` | `"arcade"`, `"modern"` | not chosen → Arcade (D32) |
| `sound_profile` | `"auto"`, `"arcade"`, `"modern"` | `"auto"` |
| `gfx_preset` | `"deck"`, `"low"`, `"medium"`, `"high"`, `"custom"` | recommended for the adapter tier |
| `gfx_custom` | `{shadows 0..3, details 0..2, scale 50..150, aa 0..2, effects 0..2}` | values of the preset |
| `race_music` | bool | `true` |

Trap (found by [P], must be implemented exactly): `Settings.fullscreen_stored_as_choice()` compares against the fixed
constant `FULLSCREEN_CHOICE_SINCE := 2`, **not** against `SETTINGS_VERSION` (raising it to 3 would discard a stored
„Vollbild: Aus“ of every v0.6/v0.7 player). `tests/unit/ui/test_gamepad.gd` pins version 2 → update to 3.

`Settings` (autoload, `scripts/core/settings.gd`) additions:

```gdscript
const SETTINGS_VERSION := 3
const FULLSCREEN_CHOICE_SINCE := 2
var graphics_mode := ""            # "" = not chosen
var sound_profile := "auto"
var gfx_preset := ""               # "" = recommended for the adapter
var gfx_custom: Dictionary = {}
var race_music := true
signal graphics_changed(mode: String)          # chosen mode changed (options, chooser)
signal quality_changed(quality: Dictionary)
signal sound_profile_changed(profile: String)  # resolved profile changed
func effective_graphics() -> Dictionary   # {"mode": "arcade"|"modern", "reason": ""|"cli"|"config"|"crash_guard"|"default"}
func is_modern() -> bool                  # effective_graphics().mode == "modern"
func quality() -> Dictionary              # {"preset", "shadows", "details", "scale", "aa", "effects"} incl. CLI overrides
func quality_levels() -> Dictionary       # numeric renderer parameters: Gfx.levels(quality(), Config "graphics")
func sound() -> String                    # "arcade"|"modern": --sound > config audio.profile > sound_profile;
                                          # "auto" = graphics_mode if chosen, else "arcade"
func adapter_tier() -> String             # Gfx.classify_adapter(...) of the running adapter
```

`Gfx` (`scripts/core/gfx.gd`, `class_name Gfx`, `RefCounted`, pure static helpers, no autoload access; prototype in
`product-ux/evidence/spike_scripts.diff`):

```gdscript
const ARCADE := "arcade"; const MODERN := "modern"
const PRESET_ORDER: Array[String] = ["deck", "low", "medium", "high", "custom"]
const QUALITY_KEYS: Array[String] = ["shadows", "details", "scale", "aa", "effects"]
const SCALE_STEPS: Array[int] = [50, 67, 75, 85, 100, 125, 150]
const BOOT_MARKER := "user://modern_start.lock"
static func classify_adapter(adapter: String, vendor: String = "", api: String = "", gamescope: bool = false) -> String  # "software"|"weak"|"deck"|"ok"
static func recommended_mode(tier: String) -> String        # "modern" for deck/ok, "arcade" for software/weak
static func recommended_preset(tier: String) -> String      # deck→"deck", weak/software→"low", ok→"medium"
static func resolve_mode(chosen: String, cli: String, force: String, marker: bool) -> Dictionary   # D32
static func quality(preset: String, custom: Dictionary, presets: Dictionary) -> Dictionary
static func preset_of(q: Dictionary, presets: Dictionary) -> String
static func sanitized(q: Dictionary) -> Dictionary
static func with_cli(q: Dictionary, preset_arg: String, set_arg: String, presets: Dictionary) -> Dictionary  # --gfx-preset, --gfx
static func levels(q: Dictionary, gfx_cfg: Dictionary) -> Dictionary   # §4.10 tables → flat parameter dictionary
static func watchdog_verdict(median_ms: float, p95_ms: float, target_ms: float, wd_cfg: Dictionary, lowest: bool) -> String
        # "ok"|"slow"|"too_slow"; target_ms = frame time of the display refresh or frame cap (a 40 Hz Deck is not "slow")
```

`GfxSelfTest` (`scripts/core/gfx_self_test.gd`): `static func run(parent: Node, frames: int = 3) -> Dictionary`
(`{"ok": bool, "reason": ""|"black"|"shader"|"readback", "ms": float}`; awaitable; skipped headless → ok).

### 4.2 Command line (after `--`), all optional

| flag | meaning |
|---|---|
| `--graphics=arcade\|modern` | forces the mode; wins over everything (tests, screenshots, rescue switch) |
| `--gfx-preset=deck\|low\|medium\|high` | quality preset for this run |
| `--gfx=shadows=0,scale=75,…` | single quality values for this run (keys of `QUALITY_KEYS`) |
| `--gfx-sync` | deterministic test mode of Modern (Rule 10) |
| `--gfx-debug=<list>` | debug views of Modern: `cover` (magenta canvas fill, no fog), `ids` (flat id colours per vehicle), `nolight`, `chunks`, `wire`, `fail` (`healthy()` reports false – tests of the fallback) |
| `--no-prewarm`, `--no-watchdog` | skip the shader warm-up / the slowness watchdog |
| `--sound=arcade\|modern` | forces the sound profile for this run |
| `--audio-sync` | synchronous engine mixer (tests, Movie Maker) |
| `--shot-fast` | `Screenshotter`: render loop off until 0.1 s before each shot (same hashes, 4× faster) |
| `--bench=<scene id\|all>` `--bench-out=<file.json>` | runs the Leistungstest scenes and quits |
| `--no-chooser` | never show the first-start chooser |

Existing flags are unchanged. The chooser appears only when `OS.get_cmdline_user_args()` is empty (D32).

### 4.3 Configuration (`config/game_config.json`)

New top-level section **`graphics`** (owner: KERN in wave 0, afterwards the renderer owner of the wave, §5):

```json
"graphics": {
  "_doc": "…",
  "force_mode": "",
  "presets": { "deck": {"shadows":1,"details":1,"scale":100,"aa":1,"effects":1},
               "low": {"shadows":0,"details":0,"scale":75,"aa":0,"effects":0},
               "medium": {"shadows":2,"details":1,"scale":100,"aa":1,"effects":1},
               "high": {"shadows":3,"details":2,"scale":100,"aa":2,"effects":2} },
  "levels": { "shadows": [ … 4 entries … ], "details": [ … 3 … ], "aa": [0, 2, 4], "effects": [ … 3 … ] },
  "modern": {
    "camera": {"look_gain": 0.6, "look_m": 100.0, "yaw_max_deg": 14.0, "near_m": 1.0, "far_m": 2600.0},
    "chunk_segments": 32, "load_path_m": 1500.0, "landmark_path_m": 1900.0, "keep_behind_m": 150.0,
    "threaded_build": true, "commits_per_frame": 1,
    "fog": {"begin_frac": 0.45, "end_frac": 1.0},
    "terrain": {"rings_m": [0, 5, 15, 40, 100, 220, 480], "inside_bend_factor": 0.8,
                "floor_window_m": 900.0, "floor_drop_m": 4.5, "far_ground_drop_m": 4.0},
    "lights": {"spots": 2, "pools_lamps": 16, "pools_traffic": 6},
    "sky_update_s": 2.0, "prewarm": true
  },
  "watchdog": {"countdown_min_fps": 30.0, "slow_factor": 1.3, "too_slow_factor": 2.0},
  "benchmark": {"seconds": 20.0, "scenes": [ {"id": "autobahn", …}, {"id": "stadt_nacht_regen", …}, {"id": "berg_tunnel", …} ]},
  "budgets": { "deck": {"draw_calls": 650, "primitives": 450000, "script_ms": 1.5, "commit_ms": 3.0}, … }
}
```

Existing section `audio` gets `"profile": ""` (override for tests: `""`, `"arcade"`, `"modern"`) and the object
`"modern": { … }` (owner: audio). No other existing key changes. Arcade reads nothing of the new keys.

### 4.4 Renderer seam (race session ↔ renderers)

#### 4.4.1 Factory and contract

`scripts/race/race_renderers.gd` (`class_name RaceRenderers`):
`static func create(mode: String) -> Node` → `RoadRenderer.new()` for `"arcade"`,
`load("res://scripts/race3d/modern_renderer.gd").new()` for `"modern"`. The session's `renderer` variable becomes
untyped. Tests that use Arcade internals (`check_glow_occlusion`, `shoot_vehicles`, `bench_render`, `check_session`
"preload", `check_sprite_flip`) pass `--graphics=arcade` or set `setup.gfx = "arcade"`.

| method / signal | Arcade (`RoadRenderer`, unchanged) | Modern (`ModernRenderer`, `Node3D`) |
|---|---|---|
| `setup(track, proj, cfg, scenery_db)` | yes | yes |
| `render(view: Dictionary)` every frame | yes | yes |
| `perf_stats() -> Dictionary` | yes | yes (§4.4.5) |
| `apply_quality(levels: Dictionary)` | – | once, before `prepare()`; never during a stage |
| `prepare(ctx: Dictionary)` | – | starts self-test, asset loading, warm-up; spans frames |
| `is_prepared() -> bool`, `prepare_progress() -> float` | – | yes |
| `healthy() -> bool`, `fail_reason() -> String` | – | false + reason: `"selftest:<r>"`, `"manifest"`, `"shader"`, `"timeout"` |
| `debug_snapshot() -> Dictionary` | – | plain data for headless tests (§4.4.5) |
| `world_to_screen(z, x, h) -> Vector3` | – | (px x, px y, depth m) in logical pixels |
| `signal quality_lowered(preset: String)` | – | the watchdog stepped the preset down |

The session calls the Modern-only methods through `has_method("prepare")`.
`prepare(ctx)`: `ctx = {"sets": Array[String] (every sprite set id the stage can show – the list `_preload_sprites`
builds today), "plan": StagePlan, "vehicle": String, "weather": String, "hour": float, "sync": bool}`.

#### 4.4.2 Session flow (owner of `race_session.gd`: KERN in wave 0)

1. `mode = setup.get("gfx", Settings.effective_graphics().mode)` (attract demos, the Leistungstest and tests may
   pass `setup.gfx`). Modern: write the crash-guard marker **first**. `renderer = RaceRenderers.create(mode)`;
   `add_child`, `setup(...)`.
2. Modern: `get_tree().root.content_scale_aspect = EXPAND` (Arcade: untouched, GameFlow sets `KEEP`);
   `renderer.apply_quality(Settings.quality_levels())`; `renderer.prepare(ctx)`; show the loading overlay
   („Etappe wird geladen …“, progress from `prepare_progress()`); no simulation step, no countdown, the
   `Screenshotter` does not count, until `is_prepared()` (so equal shot times show equal simulation states in both
   modes). Headless, `prepare()` finishes without the self-test and without the warm-up.
3. `not healthy()` → free the Modern renderer, create the Arcade renderer, restore `KEEP`, HUD message
   „Der Modus „Modern“ lässt sich mit dieser Grafik nicht starten. Das Spiel läuft im Modus „Arcade“ weiter.“,
   result field `gfx = "arcade"`, `gfx_fallback = <reason>`.
4. Sprite sheets: Arcade preloads as today. Modern preloads only the `ui/*` icons through `SpriteDB`; everything else
   is the renderer's job in `prepare()`. Vehicle sprite sheets (281 MB of BPTC) must not be loaded in Modern.
5. After 2 s of rendered frames in Modern the crash-guard marker is removed.
6. Audio hooks (§4.7.2) are sent in both modes.
7. Pause: the tree is paused as today. In Modern the picture must freeze completely – everything animated runs on
   `view.time` / `ce_time`, particle systems stop with the paused tree (or get `speed_scale = 0`).

#### 4.4.3 View dictionary

Unchanged (ARCHITECTURE.md §6 + renn-modul.md §15). Added in wave 0, ignored by Arcade: `hour` (float),
`dt` (float, seconds of this frame), `player.type` (vehicle type id). No renderer may require a key the other mode's
session code does not send. `palette` is always the outside palette (`Palette.compute`); Modern derives its tunnel
state from `camera_in_tunnel` and the segments.

#### 4.4.4 Canvas layers in a race

| layer | content | owner |
|---|---|---|
| −10 | Modern backdrop (`BG_CANVAS`, `background_canvas_max_layer = −10`) | renderer |
| 1 | Modern screen post (droplets, speed effects; reads the screen texture) | renderer |
| 2 | Modern 2D overlays (chase lights at the screen corners) | renderer |
| 5 | HUD, pause menu (existing) | UI |
| 6 | loading overlay of the session | session |

Arcade keeps drawing everything itself as today. HUD flashes (`hud.flash`) are unchanged in both modes.

#### 4.4.5 `perf_stats()` and `debug_snapshot()` of Modern

`perf_stats()`: `mode` ("modern"), `preset`, `render_ms_avg`, `render_ms_max` (GDScript of `render()`), `chunks`,
`chunk_build_ms_avg`, `chunk_build_ms_max`, `chunk_commit_ms_max`, `draw_calls`, `draw_calls_shadow`, `primitives`,
`primitives_shadow` (from `RenderingServer.viewport_get_render_info`, 0 headless), `lights_omni`, `lights_spot`,
`vehicles`, `instances`, `frame_ms_median`, `frame_ms_p95`, `prewarm_ms`, `fallback_sets`, `tex_mem_mb`.

`debug_snapshot()` (headless-safe, no render counters): `camera {z, x, y, yaw_deg, frustum}`, `chunks
[{index, seg_a, seg_b, parts: {<builder id>: {...}}}]`, `vehicles [{id, set, model, lod, z, x, yaw_deg, lamps}]`,
`lights {omni, spot, pools}`, `props {<set id>: count}`, `signs [{kind, z, x}]`, `quality`.
Instance lists are kept as plain data by the renderer (MultiMesh read-back returns zero headless [P]).

#### 4.4.6 Results

`build_result()` adds `gfx` (mode the stage was driven in) and, if any, `gfx_fallback`. The result screens add `gfx`
to the leaderboard entry (D15).

### 4.5 The `race3d` kernel (shared by all renderer packages)

#### 4.5.1 Coordinates

- Road coordinates (unchanged): `z` along the road in visible metres, `x` lateral (+ right), `h` above the road.
- World = Godot: +X right, +Y up, heading 0 looks along **−Z**; a positive curve turns right.
  `fwd(θ) = (sin θ, 0, −cos θ)`, `right(θ) = (cos θ, 0, sin θ)`. Heading 0 = heading of the first integrated segment.
- Model space = Godot: travel direction / vehicle nose / far side of a prop = **−Z**, +X = right of travel, +Y up.
  Vehicles: origin on the ground under the centre of the collision box. Props and landmarks: origin = the sprite
  anchor (on the ground, centre of the near face = the face towards the approaching player); they extend to −Z.
- Heights: `Track` segment `y` as is (`render.hill_height_scale` is already baked in). No own scale in Modern.

#### 4.5.2 `RoadPath3D` (`scripts/race3d/road_path.gd`; prototype `renderer3d/out/spike_src/road_path3d.gd`)

```gdscript
func setup(track: Track, start_index: int, curve_radius_at_1: float) -> void
func ensure(index: int) -> void            # integrates boundaries (midpoint rule per segment); forces Track generation (D3)
var first: int ; func last() -> int
func point(k: int) -> Vector3 ; func heading(k: int) -> float       # boundary k, origin-relative
func centre_at(z: float) -> Vector3 ; func heading_at(z: float) -> float
func world(z: float, x: float, h: float) -> Vector3                  # road coordinates → world (origin-relative)
func frame_at(z: float, x: float = 0.0, h: float = 0.0) -> Transform3D   # +X right, +Y up, −Z road forward (yaw only)
func rebase(to_index: int) -> Vector3      # moves the floating origin, returns the shift applied to all positions
func trim(before_index: int) -> void
func clearance(k: int, side: int) -> float # free lateral width (m) before another part of the loaded road
func floor_y(k: int) -> float              # valley floor (D16): min road height within ±floor_window_m − floor_drop_m
static func right_of(a: float) -> Vector3 ; static func fwd_of(a: float) -> Vector3
```
Positions are kept in doubles (`PackedFloat64Array`); only origin-relative values leave the class.

#### 4.5.3 `ChaseCamera3D` (`scripts/race3d/chase_camera.gd`)

```gdscript
func setup(proj: RoadProjection, cam_cfg: Dictionary) -> void
func look_yaw(path: RoadPath3D, cam_z: float) -> float               # pure function of position (rad)
func transform(view: Dictionary, path: RoadPath3D) -> Transform3D
func frustum(viewport_size: Vector2, shake: Vector2) -> Dictionary   # {"size", "offset": Vector2, "near", "far"}, focal 711 px (D12)
static func project(cam: Transform3D, fr: Dictionary, viewport_size: Vector2, p: Vector3) -> Vector3   # px x, px y, depth
```

#### 4.5.4 `TerrainProfile` (`scripts/race3d/terrain_profile.gd`, pure; used by the mesh builder, the prop
placement and the fairness tests)

```gdscript
func setup(path: RoadPath3D, track: Track, terrain_cfg: Dictionary, scenery_db: Dictionary) -> void
func ring_offsets(k: int, side: int) -> PackedFloat32Array   # clamped ring distances beyond the shoulder (D16)
func height(k: int, side: int, lateral_m: float) -> float    # relative to the road height of cross-section k
func corridor_width(k: int, side: int) -> float              # sight corridor in which height() must be <= 0 (F7)
```

#### 4.5.5 Chunks

Chunk = `chunk_segments` (32) segments = 96 m; about 11 live at 900 m visibility, at most 16 + landmark stubs.
Load when path distance ≤ `load_path_m` **and** distance by air ≤ visibility + 96 m; free behind `keep_behind_m`.

```gdscript
class_name ChunkContext extends RefCounted          # scripts/race3d/chunk_context.gd
var index: int ; var seg_a: int ; var seg_b: int    # rows seg_a .. seg_b (33 rows)
var segs: Array[Dictionary]      # snapshot of every TrackSegment field incl. a deep copy of `sprites` (33 entries)
var rows_o: PackedVector3Array   # road centre per row, chunk-local
var rows_r: PackedVector3Array   # unit right vector per row
var rows_f: PackedVector3Array   # unit forward vector per row
var rows_edge: PackedVector2Array  # road edges per row (left, right incl. fuel lane), m
var floor_y: PackedFloat32Array  # valley floor per row, chunk-local y
var ring_x: PackedFloat32Array   # terrain ring distances per row and side (snapshot of TerrainProfile.ring_offsets)
var ring_h: PackedFloat32Array   # terrain heights at those rings (snapshot of TerrainProfile.height)
var path: RoadPath3D ; var terrain: TerrainProfile   # MAIN THREAD ONLY (collect/commit): the main thread extends them
var cfg: Dictionary ; var scenery_db: Dictionary ; var levels: Dictionary ; var sync: bool
func local(z: float, x: float, h: float) -> Vector3                           # road coordinates → chunk-local
func frame(z: float, x: float, h: float, yaw_rad: float = 0.0) -> Transform3D # rigid frame, −Z = road forward at z
func ground(z: float, x: float) -> float                                      # terrain height at a lateral position
# local(), frame() and ground() interpolate the snapshot arrays only – they are safe on a worker thread.

class_name ChunkBuilder extends RefCounted          # scripts/race3d/chunk_builder.gd (base class)
func id() -> String
func collect(ctx: ChunkContext) -> Variant            # main thread: cheap extra snapshot (or null)
func build(ctx: ChunkContext, input: Variant) -> Dictionary   # WORKER THREAD: arrays and plain data only – no nodes,
                                                              # no resources, no autoloads, no Track, no ctx.path/terrain
func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void   # main thread: ArrayMesh/MultiMesh/nodes under parent
func debug(part: Dictionary) -> Dictionary            # plain data for debug_snapshot()
```
`ChunkStreamer` (`scripts/race3d/chunk_streamer.gd`): `setup(path, terrain, track, cfg, levels, sync)`,
`register(builder)`, `update(cam_z, visibility_m)`, `chunk_count()`, `snapshot()`. It owns the chunk nodes and their
transforms (builders never move them), commits at most `commits_per_frame`, all visible chunks at load, and runs
`build()` on `WorkerThreadPool` unless `sync`.

Builder registry (`scripts/race3d/builder_registry.gd`, written once in wave 0 by GEO with **all** names below; a
missing file is skipped, so later packages only add their file and never edit the registry):

| file in `scripts/race3d/builders/` | content | package |
|---|---|---|
| `road.gd` | asphalt, shoulders, curbs, sidewalks, fuel lane; all paint in `road.gdshader` | R1 |
| `roadside.gd` | guardrails, posts, reflectors, delineators | R1 |
| `terrain.gd` | ribbon rings, valley-floor edge | R2 |
| `props.gd` | scenery props as MultiMesh (+ sprite stand-ins) | R2 |
| `signs.gd` | signs on posts and tunnel walls | R3 |
| `tunnel.gd` | tube, walkways, lamps, niches, portal, mound | R5 |
| `bridge.gd` | deck, banks, railings, girders, pylons, lamps, water plane | R5 |
| `station.gd` | fuel lane islands, canopies, pumps, shop, price pylon | R6 |
| `border.gd` | roof, fascia, booths | R6 |
| `city.gd` | street lights, fences/hedges/walls, crosswalk data | R6 |
| `gantry.gd` | start gantry with countdown lamps, finish gantry | R6 |
| `radar.gd` | radar posts and camera flash | R6 |
| `landmarks.gd` | landmarks anchored on the path up to `landmark_path_m` | R7 |

Dynamic layers (`scripts/race3d/layers/`, created by `modern_renderer.gd` if the file exists):
`vehicles.gd` (R3), `flares.gd` (R3), `backdrop.gd` (R1), `far_ground.gd` (R2), `lights.gd` (R1 → R4),
`weather.gd` (R4), `overlay.gd` (R1), `post.gd` (R8). Each: `setup(renderer)`, `update(view, dt)`,
`snapshot() -> Dictionary`.

#### 4.5.6 Global shader uniforms

Added at runtime by `ModernMaterials.ensure_globals()` (idempotent: adds every missing `ce_*` global with
`RenderingServer.global_shader_parameter_add`; verified [X]) – **nothing is declared in `project.godot`**, so
Arcade and every branch without the renderer stay untouched. Whoever loads a Modern shader (renderer, showroom,
contact sheet, tests) creates its materials through `ModernMaterials`, which calls `ensure_globals()` first; Modern
shaders are loaded with `load()` after that, **never with `preload()`**. The values are set by `EnvironmentRig` (in
the showroom and the contact sheet by their own small rig).

| name | type | meaning |
|---|---|---|
| `ce_night` | float | lights on, 0..1 (`palette.lights`) |
| `ce_wet`, `ce_snow` | float | 0..1 |
| `ce_time` | float | seconds (`view.time`), never `TIME` in gameplay-relevant shaders |
| `ce_wind` | vec4 | direction x, direction z, strength, gust |
| `ce_fog_color` | color | `palette.fog` |
| `ce_fog_range` | vec2 | fog begin, visibility (m) |
| `ce_sun_dir` | vec3 | direction to the sun/moon (world) |
| `ce_sun_color` | color | colour × energy |
| `ce_ambient` | color | ambient colour × energy |
| `ce_tunnel` | float | camera inside a tunnel, 0..1 |
| `ce_headlight_pos`, `ce_headlight_dir` | vec3 | player headlights (world) |
| `ce_headlight` | vec2 | range (m), intensity |
| `ce_far_y` | float | y of the far-ground plane (world) |

Light pools of the road/terrain materials are material uniform arrays (`pool_pos_r[22]` vec4 = position + radius,
`pool_col[22]` vec4 = colour + kind), set once per frame on the two shared materials.

### 4.6 Models: pipeline, conventions, manifest

#### 4.6.1 Pipeline and commands

```
# 1 export: generators → own GLB writer → intermediates (git-ignored)
/home/user/tools/bpyenv/bin/python tools/blender/export_models.py [--only=<glob>] [--force] [--jobs=2] [--list]
      → tools/blender/_cache3d/<group>/<name>/{model.glb, model_meta.json, *.png}
# 2 bake: headless Godot → committed resources
godot --headless --path . -s res://tools/models/bake_models.gd -- [--only=<glob>]
      → assets/models/<group>/<name>/{<lod>_<node>.res …, model.json, *.png|*.webp (+ .import)}
# 3 manifest: merge all model.json fragments (sorted, deterministic)
/home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only   → assets/models/manifest.json
# 4 validate + look
python3 tools/blender/validate_models.py
tools/models_contact_sheet.sh <out.png> [--only=<glob>] [--night]
```
`<group>` = `player | traffic | police | props | landmarks` (the prefixes of the sprite set ids). `.glb` files are
never committed and never exported. `assets/models/manifest.json` is generated: on a merge conflict regenerate it
(step 3); `tests/unit/core/test_model_db.gd` fails if it differs from the merge of the fragments.
The cache key of step 1 = hash of builder code + parameters + exporter version (as `render_all.py` does).

#### 4.6.2 Node conventions (in the GLB and, flattened, in `model.json`)

- Root children are the LODs: `lod0`, `lod1`, `lod2`, optional `show` (showroom, player cars), optional `shadow`
  (low-poly caster; then the visible meshes do not cast).
- Vehicle parts under a LOD: `body`; `wheel_<axle><l|r>` with axle 0 = front (`wheel_0l`, `wheel_0r`, `wheel_1l`, …),
  pivot at the wheel centre, spin axis = local X, front wheels steer about Y; left wheels are the right wheel mesh
  turned 180° (no negative scales); brake calipers belong to `body`. Articulated vehicles: `tractor` and `trailer`
  groups with their own `body` and wheels, trailer pivot at the kingpin.
  `lod1` and `lod2` are one merged mesh (`body`) including the wheels.
- Props, buildings, landmarks, trees: `body` only (plus `shadow` if useful). A second seed variant of a tree is its
  own model (`props/tree_oak_b`), listed in the set's `variants`.
- Generators tag objects and materials with custom properties `ce_node` and `ce_role` (name matching was fragile
  in the spike [A]); the exporter fails on an untagged object.

#### 4.6.3 Material classes (= surface names of the baked meshes; the renderer binds one material per class)

| class | used for | textures | shader |
|---|---|---|---|
| `vpbr` | all vehicles incl. wheels and lamps, road furniture, lattice landmarks (vertex-colour bake), trunks | none | `vpbr.gdshader` |
| `glass` | vehicle glazing at `lod0`/`show`, clear lamp lenses | none | `glass.gdshader` |
| `baked` | buildings, landmarks, rocks, props with an atlas | albedo (BC1), optional emission (BC1, half size) | `baked.gdshader` |
| `baked_cutout` | railings, fences, lattice parts of baked models | albedo with alpha (BC3) | `baked.gdshader` (scissor) |
| `leaves` | foliage cards | leaf atlas with alpha (BC3) | `leaves.gdshader` |

A mesh has at most one surface per class. No other surface names exist. No tangents, no normal maps in v0.8.0.

#### 4.6.4 Vertex data

**`vpbr` ("VPBR-L")** – verified through a compressed `.res` [X]:

| attribute | content |
|---|---|
| `COLOR.rgb` | albedo as sRGB bytes (the shader converts to linear) |
| `COLOR.a` | paint code: `1.0` fixed colour · `0.0` paint · `0.25` paint2 · `0.5` paint3 (shader thresholds 0.125 / 0.375 / 0.75) |
| `UV` | (roughness, metallic) |
| `UV2.x` | lamp channel + 0.5, or `−1` for "no lamp" |
| `UV2.y` | lamp weight 0..1 |

Codes are read as `flat` varyings; the exporter never shares a vertex between two codes.
Lamp channels: 0 tail · 1 brake · 2 tail+brake (tail at 0.35, brake at 1.0) · 3 indicator left · 4 indicator right ·
5 head · 6 daytime running · 7 reverse · 8 plate · 9 marker/contour · 10 beacon A · 11 beacon B · 12 `lights`
(lamps and window panes of props at night, driven by `ce_night`) · 13 always on · 14 `flood` (flood-lit surface: keeps
its albedo and adds albedo × weight × `ce_night`) · 15 reserved.
For the lamp channels 0–13 `COLOR.rgb` is the **lit** colour; unlit the lamp is drawn at 25 % with a glossy lens.
Per-instance uniforms of `vpbr` (`set_instance_shader_parameter`, also on a `MultiMeshInstance3D` node [X]):
`paint`, `paint2`, `paint3` (colour), `lamp_a` = (tail, brake, indicator left, indicator right),
`lamp_b` = (head, reverse, beacon A, beacon B), `fade` (0..1 path-distance fade, dither discard in the opaque pass),
`sun` (0..1, 0 inside tunnels).

**`glass`**: `COLOR.rgb` tint, `COLOR.a` opacity, `UV` = (roughness, metallic). Traffic LOD1/LOD2 have no glass class:
their glazing is dark `vpbr` with low roughness.
**`baked` / `baked_cutout`**: `UV` = atlas coordinates inside 0..1; night emission from the emission atlas × `ce_night`;
roughness is one number per model (`model.json`).
**`leaves`**: `UV` = leaf atlas; `COLOR` = (sway amplitude by height, phase per card, stiffness, brightness);
shading normals point outwards from the crown.

#### 4.6.5 Textures

Sources in `assets/models/<group>/<name>/`: `albedo.webp|png`, `emit.webp|png`, `leaves.png`, `impostor.png`;
`.import` files are written by `tools/models/set_model_import.py` (compress mode VRAM, mipmaps on, `detect_3d` off)
and committed. Tiers: D23. Bake at 2× resolution with 16 samples and downsample (1-sample bakes alias [A]).
Texel density is weighted by visibility (road and approach faces 1.0, away faces 0.3, undersides 0.05); the detailed
road-facing wall is reused on the wall facing away from the road (blank backs become visible across bends in true 3D).

#### 4.6.6 Manifest `assets/models/manifest.json` (version 1)

```json
{ "version": 1, "exporter": "ce3d 1",
  "models": {
    "traffic/sedan": {
      "kind": "vehicle",
      "object": {"width_m": 1.82, "length_m": 4.7, "height_m": 1.48},
      "lods": [
        {"name": "lod0", "max_dist_m": 40, "tris": 17650, "parts": [
          {"node": "body", "mesh": "traffic/sedan/lod0_body.res", "classes": ["vpbr", "glass"]},
          {"node": "wheel_0l", "mesh": "traffic/sedan/wheel.res", "classes": ["vpbr"],
           "pos": [-0.78, 0.31, -1.42], "yaw_deg": 180, "wheel": {"radius": 0.31, "steer": true}} ]},
        {"name": "lod1", "max_dist_m": 120, "tris": 5800,
         "parts": [{"node": "body", "mesh": "traffic/sedan/lod1_body.res", "classes": ["vpbr"]}]},
        {"name": "lod2", "max_dist_m": 100000, "tris": 1100,
         "parts": [{"node": "body", "mesh": "traffic/sedan/lod2_body.res", "classes": ["vpbr"]}]} ],
      "shadow": {"mesh": "traffic/sedan/shadow.res", "tris": 900},
      "lights": [{"role": "head", "pos": [0.62, 0.66, -2.3], "size": 0.16, "color": "#fff3d6"}],
      "paint": {"paint": "#b01818"},
      "auto_lod": false, "tags": ["traffic", "car"], "bytes": 412000, "hash": "<sha1 of all files>" },
    "props/city_hanse_gable_a": {
      "kind": "building", "object": {"width_m": 12.4, "length_m": 11.0, "height_m": 14.5},
      "extent_m": {"left": 6.2, "right": 6.2},
      "lods": [{"name": "lod0", "max_dist_m": 100000, "tris": 2989,
                "parts": [{"node": "body", "mesh": "props/city_hanse_gable_a/lod0_body.res", "classes": ["baked", "baked_cutout"]}]}],
      "textures": {"albedo": "props/city_hanse_gable_a/albedo.webp", "emit": "props/city_hanse_gable_a/emit.png"},
      "roughness": 0.9, "impostor": {"texture": "props/city_hanse_gable_a/impostor.png", "size_m": [12.4, 14.5]},
      "auto_lod": true, "tags": ["prop", "building", "mirror_left"] } },
  "sets": {
    "traffic/sedan_red":  {"model": "traffic/sedan", "paint": {"paint": "#b01818"}},
    "player/kompakt":     {"model": "player/kompakt"},
    "showroom/kompakt":   {"model": "player/kompakt", "lod": "show", "showroom": false},
    "police/de":          {"model": "police/de"},
    "props/ferry_ship":   {"fallback": "sprite"} } }
```
Rules: paths are relative to `assets/models/`. `kind` ∈ `vehicle | heavy | tree | plant | rock | building | landmark |
furniture`. `object` (and `extent_m`) must equal the sprite manifest within 2 % – both modes share the simulation and
the placement helpers. `lights[].role` ∈ the lamp channel names (`head`, `tail`, `brake`, `ind_l`, `ind_r`, `beacon_a`,
`beacon_b`, `lights`, `marker`); they anchor headlight pools, flares (F6) and the omni pool. **Every sprite set id
except `ui/*` has a `sets` entry**: a model, or `{"fallback": "sprite"}` (billboard of the Arcade sprite) or
`{"fallback": "box"}`. A set may list `variants` (model ids, e.g. `["props/tree_oak", "props/tree_oak_b"]`); the
prop layer picks one by a stable hash of segment index and prop index. `showroom: true` is set by the asset owner
only after an A/B picture shows the real-time model at least equal to the Cycles sprite (D36).

#### 4.6.7 Godot side

`ModelDB` (`scripts/core/model_db.gd`, `class_name ModelDB`, static, lazy – **not** an autoload, Arcade pays nothing):

```gdscript
const ROOT := "res://assets/models/"
static func available() -> bool                       # manifest present and valid
static func reload(manifest_path: String = "") -> bool  # tests load fixtures
static func resolve(set_id: String) -> Dictionary     # {"model_id", "model": Dictionary, "paint": Dictionary, "lod": String, "fallback": String, …}; {} = unknown
static func has_model(set_id: String) -> bool         # resolves to a model (not a fallback)
static func object_size(set_id: String) -> Dictionary
static func mesh(rel_path: String) -> ArrayMesh       # cached
static func texture(rel_path: String) -> Texture2D    # cached
static func request(set_ids: Array, lods: Array = []) -> void   # ResourceLoader.load_threaded_request for all files
static func pending() -> int                          # 0 = everything requested is loaded
static func release_all() -> void                     # drop caches (leaving Modern)
```
`ModernMaterials` (`scripts/race3d/modern_materials.gd`): `material(class_id: String, model: Dictionary) -> Material`
(shared `ShaderMaterial` per class; `baked*` and `leaves` one per texture set).
`ModelFactory` (`scripts/race3d/model_factory.gd`): `build(set_id: String, lod: String, mats: ModernMaterials) -> Node3D`
(node tree as in §4.6.2, meshes and class materials assigned; used by the vehicle layer, the showroom and the contact
sheet), `multimesh_parts(set_id, lod) -> Array` (mesh + material pairs for MultiMesh layers).

#### 4.6.8 Validation and regression

`validate_models.py` fails on: manifest ≠ files; triangles/surfaces/bytes over the budget of the category (§4.6.9);
unknown class or node names; decoded paint/lamp codes not on their values (±0.02) after the bake; UVs of `baked`
outside 0..1; `object`/`extent_m` deviating > 2 % from the sprite manifest; a wheel not touching the ground (±1 cm);
a sprite set without a `sets` entry; texture tier or bytes over budget; a missing `.import`.
`tools/blender/check_sprite_geometry.py` compares vertex counts, bounding boxes and a position hash of every
**sprite** build of the generators with `tools/blender/fixtures/geometry_v070.json` (written in wave 0 before any
hook) – the hooks in `cesprites` must not move a single sprite vertex.

#### 4.6.9 Asset budgets

| category | LOD0 tris | LOD1 | LOD2 | draw calls LOD0 / 1 / 2 | notes |
|---|---|---|---|---|---|
| player car (race) | 55,000 | – | – | 2 + 4 wheels | plus `show` ≤ 120,000, `shadow` ≤ 3,000; interior ≤ 6,000 inside `body` |
| traffic car, van | 18,000 | 6,000 | 1,200 | 2 + 4 / 1 / 1 | decal patches only in LOD0, ≥ 1.5 mm above the body |
| truck, bus | 25,000 | 7,000 | 1,500 | (2 + wheels) per part / 1 / 1 | footprint = collision box (2.55 × 16.5 m, 12.8 m) |
| police | base + 4,000 | 6,000 | 1,200 | 2 + 4 / 1 / 1 | 18 sets; liveries as paint codes, words as geometry |
| tree | 2,500 (≤ 450 cards) | 900 | impostor | 2 / 2 / 1 | two seed variants per species |
| bush, heather | 400 | 120 | – | 1 | |
| rock / cliff | 1,500 / 6,000 | auto | – | 1 | |
| rural building | 2,000 | auto | – | ≤ 2 | |
| city building | 10,000 | auto | impostor optional | ≤ 2 | |
| landmark | 25,000 | auto | – | ≤ 2 | all-round check, never mirrored |
| road furniture | 1,500 (pylon 5,000) | auto | – | 1 | lamps as channel 12 + `lights` anchors |

Whole set: meshes ≤ 40 MB, S3TC textures ≤ 240 MB in the PCK (≤ 60 MB in the archive).

### 4.7 Audio

#### 4.7.1 `AudioManager` additions (all existing methods keep signature and Arcade behaviour)

```gdscript
func set_profile(id: String) -> void      # "arcade"|"modern"; idempotent; builds or frees ModernAudio; never during a stage
func profile() -> String
func set_race_music(on: bool) -> void
func set_music_context(ctx: String, args: Dictionary = {}) -> void
        # "title" | "menu" | "race_menu" (screens between stages) | "race" | "result" | "off". Arcade: no-op.
func set_track(track: Object, plan: Object) -> void     # race session after building the track; (null, null) on exit. Arcade: no-op
func set_vehicle_state(state: Dictionary) -> void       # every frame of a race. Arcade: no-op
func event(name: String, args: Dictionary = {}) -> void # Arcade: no-op
```
`GameFlow` calls `set_profile(Settings.sound())` at boot and on `Settings.sound_profile_changed`, and
`set_music_context` next to its existing `set_music()` calls (which stay). With the Modern profile every existing
call (`set_engine`, `set_wind`, `set_siren`, `set_rain`, `set_skid`, `play`, `set_traffic`, `set_environment`,
`set_vehicle`, `preview_engine`, `stop_all`, `set_music`) is delegated to `ModernAudio`.

#### 4.7.2 Session → audio (sent in both modes and both profiles)

`set_vehicle_state` keys: `z`, `x` (car centre, m), `speed` (km/h), `throttle`, `brake` (0..1), `steer` (−1..1),
`understeer` (0..1), `lat_speed` (m/s), `off_road` (0 road, 1 shoulder, 2 limit), `rail_contact` (bool),
`road_left`, `road_right`, `shoulder_m` (m), `in_tunnel` (bool, camera), `weather`, `hour`, `crash` (bool),
`finished` (bool).
Events (in addition to the unchanged `play()` calls; `ModernAudio` de-duplicates a `play()` against its event
within 50 ms): `stage_start {countdown_s}`, `countdown {n}`, `go {}`, `collision {speed_kmh, heavy, side}`,
`rail_hit {impact_mps, side}`, `radar_flash {}`, `chase_start {}`, `escaped {}`, `busted {}`, `refuel_start {}`,
`refuel_done {liters}`, `out_of_fuel {}`, `tow {}`, `stage_finish {record, last_stage}`.
Everything else the Modern sound needs (surface per side, rumble strip, joints, bridges, cuttings, city/forest/open
zones, pass-by of roadside objects) is derived by `AudioFeed` (`scripts/audio/modern/audio_feed.gd`, pure) from the
`Track` given in `set_track` and the state – read-only, at and behind the car's position only.

#### 4.7.3 Buses, assets, tools

- Buses (created at runtime by `ModernAudio`, removed with it): `MMaster` (→ `Master`), `MMusic`, `MUI`, `MSfx`,
  `MCar`, `MEngine`, `MEngineFx`, `MRoad`, `MWind`, `MImpact`, `MWorld`, `MTrafficV0`…`MTrafficV7`, `MSiren`, `MAmb`,
  `MEnv`. The three volume settings act on `Master`, `MSfx` (effects group) and `MMusic`. Arcade buses and their
  effects are never touched.
- Assets: `assets/audio/modern/{engines,vehicle,traffic,sfx,ambience,ui,music}/`, each folder with its own
  `manifest.json` (file, measured LUFS, true peak, loop points, bpm/bars, bytes). Engine banks = `<car>.json` +
  `<car>.i16` (raw interleaved int16, 32 kHz stereo). **`*.i16` is added to `include_filter` of both export presets
  and to `.gitattributes`** (wave 0, KERN).
- Formats: music Ogg Vorbis q5, ambience q3–q4, tonal loops and one-shots 16-bit WAV, all 44.1 kHz.
- Tools: `tools/audio/modern/*.py` (import the frozen Arcade tools, never edit them), `tools/audio/qc/audio_qc.py`
  (loudness, range, true peak, loop seams, DC, clipping, determinism by double render, size report).
- Preview files for the user (MP3/MP4) go to `<scratch>/v080/deliver/<package>/`, never into the repo.

### 4.8 UI

- **Options** („Optionen“): two pages, tabs right of the title, LB/RB (keyboard Bild auf/ab, mouse click).
  „ALLGEMEIN“: Gesamtlautstärke, Effekte, Musik, „Klang“ [Wie Grafik | Arcade | Modern], „Musik im Rennen“ [Aus | An]
  (only focusable with the Modern sound), Vibration, Spielername, Zurück.
  „GRAFIK“: „Grafik“ [Arcade | Modern], „Vollbild“ [Aus | An], heading „QUALITÄT IM MODUS MODERN“, „Voreinstellung“
  [Steam Deck | Niedrig | Mittel | Hoch | Eigene], „Schatten“ [Aus | Niedrig | Mittel | Hoch], „Details“ [Niedrig |
  Mittel | Hoch], „Auflösung“ [50 % … 150 %], „Kantenglättung“ [Aus | MSAA 2× | MSAA 4×], „Effekte“ [Aus | Einfach |
  Voll], „Leistungstest“, Zurück. Quality rows are dimmed and skipped by the focus while Grafik = Arcade; changing one
  value turns the preset into „Eigene“. Right panel: preview picture, explanation of the focused row, graphics
  adapter, recommendation, „Änderungen gelten in den Menüs sofort, im Rennen ab dem nächsten Start“.
  Prototype with a 10/10 gamepad check: `product-ux/evidence/spike_scripts.diff`.
- **Chooser** „GRAFIK WÄHLEN“ (`scripts/ui/screens/graphics_choice_screen.gd`): two cards with a picture of the same
  road in each mode, the recommended one focused with the badge „EMPFOHLEN FÜR DIESEN RECHNER“, subtitle for
  existing players „Neu in v0.8.0: der Modus „Modern““, one A confirms, no cancel. It sets `graphics_mode`
  (and leaves `sound_profile` = `auto`). Conditions: D32.
- **Showroom**: `Showroom3D` (`scripts/ui/widgets/showroom_3d.gd`) as a child inside `CarShowcase` – same place,
  same `show_vehicle()` call, `VehicleScreen` untouched. `SubViewport` with `own_world_3d`, `transparent_bg`, sized
  in **physical pixels** (control size × stretch scale; the naive size is visibly soft at 1080p [P]), key light with
  shadow, fill, two rim lights, slow turntable. Only for sets with `showroom: true`; otherwise the sprite.
- **Loading overlay**: `LoadingOverlay` gets `set_progress(p: float)`; the session shows it during `prepare()`.
- **Messages** (German, fixed): fallback (§4.4.2); crash guard on the title: „Der Modus „Modern“ wurde beim letzten
  Start nicht richtig beendet.“ with „Bei Arcade bleiben“ / „Modern noch einmal versuchen“; watchdog in the HUD:
  „Grafikqualität gesenkt: %s“; on the result screen: „Qualität senken“ / „Zu Arcade wechseln“.
- **Leistungstest**: three fixed 20 s autopilot scenes (`graphics.benchmark.scenes`), result screen with average
  and 1 %-low fps, frame time p95/p99, script ms, draw calls, primitives, adapter, preset, resolution, suggested
  preset; written to `user://leistungstest.json` (and `--bench-out`). Runner `scripts/race3d/benchmark.gd`
  (`class_name ModernBenchmark extends Node`: `start(scene_ids: Array = [])`, `signal progress(scene_id, p01)`,
  `signal finished(result: Dictionary)`; it drives the race scene with `setup.gfx = "modern"`, autopilot and a fixed
  seed), screen `scripts/ui/screens/benchmark_screen.gd`. Result format (also the file):
  `{"version": 1, "date", "adapter", "api", "tier", "preset", "quality": {…}, "resolution": [w, h], "scenes":
  [{"id", "avg_fps", "low1_fps", "frame_ms_p95", "frame_ms_p99", "script_ms", "draw_calls", "primitives"}],
  "suggested_preset"}`.
- **Attract mode** runs the demos in the effective mode; the demo timer starts when the scene is prepared.
- HUD: same code in both modes; it must lay out from its own size (1280×800, 1680×720). Any HUD edit must keep the
  Arcade goldens identical (they contain the full HUD).

### 4.9 Tests and tools

#### 4.9.1 Headless (`tools/run_tests.sh`, one pass, must stay green; target ≤ 9 min in total)

- Unit tests are discovered as today: `tests/unit/**/test_*.gd`. New folders: `tests/unit/core/`,
  `tests/unit/race3d/`, `tests/unit/audio_modern/`.
- Wave 0 adds one generic hook: every `tests/race3d/check_*.gd` and `tests/sim/modern_*.gd` is run with
  `godot --headless --path . -s <file>`; each prints `CHECK <name> OK|FEHLER` lines and returns an exit code.
  Later packages add files, nobody edits `run_tests.sh` again.
- `tests/sim/modern_sight.gd` (F1–F3, F7; sampled set of the 12 hardest stage directions in the normal run,
  `-- --full` for the whole network at the milestones), `tests/sim/modern_path_check.gd` (clearance ≥ 250 m within
  1,900 m of path, loops only beyond 2,000 m – a future stage that fails gets another seed).
- `tests/race/check_session.gd` scenario `gfx_independent`: the same stage with each renderer class headless →
  identical result and identical per-second traffic hash.
- What headless can test [P]: `ArrayMesh` surfaces and read-back, Camera3D math, `debug_snapshot()` data. Not:
  MultiMesh read-back, render counters.

#### 4.9.2 Render checks (`tools/run_render_checks.sh [arcade|modern|all] [filter]`, Xvfb, not in `run_tests.sh`)

Runs every `tests/race3d/render/check_*.gd` (and the existing Arcade render checks) with
`xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy
--fixed-fps 60 … -- --graphics=modern --gfx-sync --audio-sync`; output `RENDER-CHECK <name> OK|FEHLER`.
Mandatory checks of Modern: lane-line pixels at the predicted positions on a straight (≤ 1 px, F-parity); a car
behind a crest and a brake light behind a truck change 0 pixels (occlusion); tail light at 0.839 × visibility above
the luminance threshold at night (F6); object at the visibility limit below 3 % contrast (F4/F5); mean luminance and
no black/NaN frame per weather × hour; tunnel interior and exit; terrain cover (`--gfx-debug=cover`: magenta pixels
below the horizon row ≤ 0.2 % at the reference positions); shadow present / absent with „Schatten: Aus“ at equal
mean brightness (±2 %); 1280×800 filled; the OpenGL ES path (`--rendering-driver opengl3_es`) renders the same
picture (max difference ≤ 2, PSNR ≥ 60 dB).

Reference positions (used by checks, A/B sheets and the terrain gate):

| id | stage, km, conditions | what it shows |
|---|---|---|
| S1–S5 | Kiel–Hamburg km 2 / first fuel lane / 60 / 80 (City Limits) / 94 (finish), day | the slice |
| T1, T2 | Kassel–Würzburg km 46.5 (bend into a descent), km 61.9 (crest) | terrain, sight |
| T3, T4 | Saragossa–Pau km 172.8 (climbing bend), km 198.8 (R ≈ 136 m) | terrain worst cases |
| N1 | Hamburg–Hannover km 71, snow, 22:00 | night, snow, headlights |
| N2 | Dortmund–Frankfurt km 121, rain | rain, spray, traffic |
| C1 | Dortmund–Frankfurt km 221, 19:30 | City Limits, rush hour, landmark |
| U1 | Bern–Mailand km 186 | Gotthard tunnel |
| B1 | a river bridge arrival (Köln or Wien) | bridge, water |
| DEV | dev_testetappe km 48, 21:00 | every special element |

#### 4.9.3 Goldens

`tools/golden.sh make` builds a worktree of tag v0.7.0 and writes `tests/golden/arcade_v070.md5`: 14 attract frames
(seven scenes at 4 s and 12 s) + 6 race frames with the full HUD (S1, T1, N1, N2, C1, U1) at `--fixed-fps 60`, fixed
seed, `--shot-fast`. `tools/golden.sh check` renders the same frames with the current tree and `--graphics=arcade`
and compares the hashes (regenerate from the tag after a Mesa or Godot change). `tests/golden/modern_*.md5` are change
detectors with the tolerance tiers of D38.

#### 4.9.4 Performance proxies

`tests/race3d/bench_modern.gd` (Xvfb for counters, headless for script time) at C1, N2, U1, T4, DEV and a dense
Autobahn position: draw calls visible/shadow, primitives, real lights, GDScript ms of `render()`, chunk build/commit
ms, texture memory – compared with `graphics.budgets` of each preset; exit code ≠ 0 over budget.
Shader warm-up check (once per milestone, cold `XDG_DATA_HOME` and Mesa cache): after the loading overlay no frame
of the first 30 s takes longer than 3 × the median.
Leak check: three stages back to back and 20 mode switches – node, chunk, MultiMesh, SubViewport counts and texture
memory return to the baseline within 5 %.

#### 4.9.5 Platforms

Linux export and Windows export under wine64 run the Modern smoke scene; Wine pictures may be compared exactly with
the Linux export [P]. ANGLE cannot be shown under Wine: the OpenGL ES run on Linux is the proxy; a real Windows PC
with `--rendering-driver opengl3_angle` is a user check (§7).

### 4.10 Quality levels and budgets

Start values of `graphics.levels` (data, tunable next to the executable):

| „Schatten“ | casters | splits | atlas | distance | filter |
|---|---|---|---|---|---|
| 0 Aus | none (flag stays on, D5); blob shadows under vehicles | orthogonal | 1024 | – | hard |
| 1 Niedrig | vehicles, structures | 2 | 2048 | 80 m | soft low |
| 2 Mittel | + buildings, tree proxies | 2 | 2048 | 120 m | soft low |
| 3 Hoch | + all props | 4 (blend) | 4096 | 200 m | soft medium |

| „Details“ | vehicle LOD0 / LOD1 to | prop LOD0 / LOD1 to | decorative density | outer terrain ring |
|---|---|---|---|---|
| 0 Niedrig | 25 m / 90 m | 40 m / 120 m | 0.6 | 480 m |
| 1 Mittel | 40 m / 120 m | 60 m / 200 m | 1.0 | 480 m |
| 2 Hoch | 60 m / 160 m | 120 m / 350 m | 1.3 | 1,000 m |

| „Effekte“ | glow | particles | spray | wet-road reflections | SSAO | sky reflections | omni pool |
|---|---|---|---|---|---|---|---|
| 0 Aus | off | 300 | off | off | off | off | 2 |
| 1 Einfach | on | 1,500 | on | off | off | on | 4 |
| 2 Voll | on | 4,000 | on | on | quality 0–1 | on | 8 |

„Kantenglättung“: MSAA 3D off / 2× / 4×. „Auflösung“: `scaling_3d_scale` 0.5–1.5, bilinear (HUD stays sharp).
Fog mode, PSSM mode, split blending and filter quality are set in `apply_quality()` and are constant for the stage
(D10). Presets: `deck` {1,1,100,1,1}, `low` {0,0,75,0,0}, `medium` {2,1,100,1,1}, `high` {3,2,100,2,2}.

Frame budgets per preset – **inferred targets** for a real GPU, measured here as proxies (§4.9.4); the Steam Deck
numbers must be confirmed by the user's Leistungstest (§7):

| preset | draw calls incl. shadow passes | primitives incl. shadows | `render()` GDScript avg (this VM) | chunk commit max |
|---|---|---|---|---|
| deck | 650 | 450,000 | 1.5 ms | 3 ms |
| low | 400 | 250,000 | 1.2 ms | 3 ms |
| medium | 900 | 700,000 | 1.5 ms | 3 ms |
| high | 1,500 | 1,500,000 | 2.0 ms | 4 ms |

Basis: 4–5 µs CPU per draw call measured here incl. llvmpipe vertex work [E]; Arcade's `_draw` costs 5.4 ms that
Modern gets back [R]; the Deck core is ≈ 1.5× slower. Main-thread sum on the Deck at the `deck` budget (inferred):
simulation 0.5 ms + renderer GDScript 2.3 ms + HUD and session ≈ 1.5 ms + submission of 650 draw calls 3–5 ms ≈ 7–9 ms
of the 16.7 ms of a 60 fps frame; the GPU time is unknown until the Leistungstest. Real lights ≤ 8 omni + 2 spot in
every preset (D8).

### 4.11 Size and memory budgets

| part (Windows zip, the larger archive) | today | v0.8.0 budget |
|---|---|---|
| engine template | 38 MB | 38 |
| Arcade sprites / Arcade audio | 71 / 14.7 MB | unchanged |
| UI, fonts, scripts, data | ≈ 3 MB | ≤ 5 |
| Modern meshes (not compressible) | – | ≤ 40 |
| Modern textures (S3TC, ≈ 4:1 in the archive) | – | ≤ 60 |
| Modern sounds / music | – | ≤ 23 / ≤ 25 |
| **total** | 126.9 MB | **≤ 277 MB** (warn > 300, fail > 330, hard limit 350) |

`tools/pck_report.py` prints this table for every build. Texture memory in a Modern race ≤ 260 MB (Arcade today
247–259 MB): each mode loads only its own assets; leaving Modern calls `ModelDB.release_all()`.

---------------------------------------------------------------------------------------------------------------------

## 5. File ownership

General
- New code of Modern lives in new files: `scripts/race3d/**`, `assets/shaders/modern/**`, `assets/models/**`,
  `scripts/audio/modern/**`, `assets/audio/modern/**`, `tools/blender/ce3d/**`, `tools/models/**`,
  `tools/audio/modern/**`, `tools/audio/qc/**`, `tests/unit/{core,race3d,audio_modern}/**`, `tests/race3d/**`,
  `tests/golden/**`. A file belongs to the package that §6 names; when a package is finished its files pass to the
  owner named below for later waves.
- One branch per package from the base commit of its wave; the lead merges at the end of the wave. A package never
  commits generated intermediates (`_cache3d`, previews, screenshots outside `docs/`).
- Docs: one owner per file – `docs/grafik-modi.md` (UI), `docs/renderer-modern.md` (renderer), `docs/modelle.md`
  (assets), `docs/audio-modern.md` (audio), `docs/qa-v080.md` (QA). `ARCHITECTURE.md` and `README.md`: KERN in wave
  0, DOC in wave 8, nobody in between (send text to the lead).

Shared files – exactly one owner per wave ("–" = nobody edits it in that wave):

| file(s) | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 |
|---|---|---|---|---|---|---|---|---|---|
| `scripts/race/race_session.gd`, `race_renderers.gd` | KERN | R1 | QA1 | R4 | – | QA-mid | – | UI2 | PERF |
| `project.godot` (no change expected before the version bump), `export_presets.cfg`, `.gitattributes`, `.gitignore` | KERN | – | – | – | – | – | – | – | REL |
| `scripts/core/{settings,gfx,gfx_self_test,screenshotter}.gd` | KERN | – | UI1 | – | – | – | – | UI2 | PERF |
| `config/game_config.json` → `graphics` | KERN | R1 | QA1 | R4 | – | R7 | – | R8 | PERF |
| `config/game_config.json` → `audio.modern`, `audio.profile` | AU-A | – | AU-B | – | AU-C1 | – | AU-C2 | AU-E | – |
| `scripts/audio/audio_manager.gd` | AU-A | – | – | – | – | – | – | AU-E | – |
| `scripts/ui/**` (GameFlow, screens, widgets, HUD) | – | – | UI1 | – | – | – | – | UI2 | – |
| `tools/{run_tests,run_render_checks,golden}.sh`, `tests/golden/**` | KERN | – | QA1 | – | – | QA-mid | – | QA2 | QA3 |
| `tools/build_*.sh`, `tools/pck_report.py` | KERN | – | QA1 | – | – | – | – | – | QA3 |
| `scripts/race3d/modern_renderer.gd`, `quality.gd`, `prewarm.gd`, `perf_probe.gd` | KERN (stub) | R1 | – | R4 | – | R7 | – | R8 | PERF |
| `scripts/race3d/environment_rig.gd`, `layers/{lights,backdrop,overlay}.gd` | – | R1 | – | R4 | – | – | – | R8 | PERF |
| `assets/shaders/modern/{road,terrain,far_ground}.gdshader`, `builders/{road,roadside,terrain}.gd` | – | R1 / R2 | – | R4 | – | – | – | R8 | PERF |
| `assets/shaders/modern/{vpbr,glass}.gdshader`, `model_factory.gd`, `modern_materials.gd`, `layers/{vehicles,flares}.gd` | PIPE | R3 | – | R4 | – | R7 | – | R8 | PERF |
| `assets/shaders/modern/{baked,leaves,billboard}.gdshader`, `builders/props.gd`, `prop_library.gd` | PIPE | R2 | – | R4 | – | R7 | – | R8 | PERF |
| kernel: `road_path`, `chase_camera`, `terrain_profile`, `chunk_*`, `builder_registry`, `tests/sim/modern_*` | GEO | R1 | – | R4 | – | R7 | – | R8 | PERF |
| `scripts/core/model_db.gd`, `tools/blender/ce3d/{core,glb,roles,bake,lod,manifest,catalog3d,export}.py`, `export_models.py`, `validate_models.py`, `tools/models/**`, shared `cesprites/{materials,meshutil,rig,catalog,compose,curves,textgeo,icons,__init__}.py` | PIPE | AS1 | AS1b | AS2a | AS3 | AS4 | AS6 | – | PERF |
| `assets/models/manifest.json` | generated – regenerate after every merge (§4.6.1) |

`cesprites` generator files (additive hooks only; in wave 0 PIPE is the only asset package and may add hooks to any
of them for the reference models): `carbody, cardetail, player_cars, vehicles, designs` → AS1 (W1), AS2a (W3); `heavy` → AS1 (W1), AS2b (W4); `police` → AS2b; `props_nature` → AS1b (W2), AS3 (W4);
`props, props_buildings, props_road` → AS1b (W2), AS4 (W5); `props_cities` → AS5a (W5), AS5b (W6);
`props_landmarks` → AS6 (W6).

---------------------------------------------------------------------------------------------------------------------

## 6. Build plan

Nine waves, at most four packages in parallel (4 shared CPU cores). Milestones: **M0** = wave 0 (scaffolding of the
slice), **M1** = waves 1–2 (vertical slice: Kiel – Hamburg end to end in Modern with real assets, option switch,
screenshots, test build), **M2** = waves 3–5 (breadth: all conditions, all special sections, all vehicles,
vegetation, first cities), **M3** = waves 6–7 (all of Europe, effects and polish, the whole game), **M4** = wave 8
(performance, QA, docs, release).

Package ids: KERN, PIPE, AU-A, GEO (wave 0) · R1–R8 renderer · AS1, AS1b, AS2a, AS2b, AS3, AS4, AS5a, AS5b, AS6
assets · AU-B, AU-C1, AU-C2, AU-D1, AU-D2, AU-E audio · UI1, UI2 · QA1, QA-mid, QA2, QA3 · PERF, DOC, REL.
(Evidence tags are always in square brackets; "Rule n" is §2; F1–F7 are the fairness criteria of D14.)

Definition of done for every package: its acceptance checks pass; `tools/run_tests.sh` is green; `tools/golden.sh
check` is identical (Rule 2); no file outside its ownership is changed; German docs of its area are written; it reports
changed files, test output, measured numbers (marked measured/inferred), deviations from this contract and open
points. Screenshots and previews for review go to `<scratch>/v080/deliver/<package>/`.

### Wave 0 – M0 „Gerüst“

**KERN – Kern, Sitzungsnaht, Werkzeuge**
- Files: see §5 column W0, plus new `scripts/core/gfx.gd`, `gfx_self_test.gd`, `scripts/race/race_renderers.gd`,
  `scripts/race3d/modern_renderer.gd` (stub: camera, sky colour through a canvas layer, one grey plane; `prepare()`
  done on the next frame; `--gfx-debug=fail` makes `healthy()` false), `tests/unit/core/test_gfx_settings.gd`,
  `tests/unit/ui/test_gamepad.gd` (version pin), `tests/race/check_session.gd` (scenarios `gfx_independent`,
  `gfx_fallback`), `tools/golden.sh`, `tools/run_render_checks.sh`, `tools/pck_report.py`, `ARCHITECTURE.md`.
- Inputs: `product-ux/evidence/spike_scripts.diff`, `spike_tests.diff`; `renderer3d/out/spike_src/race_session.diff`.
- Outputs: §4.1–§4.4 implemented; `*.i16` in the export include filter; `.gitattributes`
  (`*.res`, `*.glb`, `*.webp`, `*.i16` binary); `.gitignore` (`/tools/blender/_cache3d/`); the session's audio hooks
  (§4.7.2, guarded by `has_method`); `Screenshotter --shot-fast`; the `run_tests.sh` hook (§4.9.1); size table and
  gate in `tools/build_release.sh`.
- Acceptance: (1) `tools/run_tests.sh` green incl. settings tests (v1/v2 → v3, fullscreen trap, unknown keys kept,
  `sound()` matrix, `resolve_mode` matrix, CLI overrides); (2) `tools/golden.sh make` + `check`: 20 of 20 identical;
  (3) `run_stage.gd` on dev_testetappe and kiel_hamburg: `ERGEBNIS` identical for `--graphics=arcade|modern` except
  `gfx`; (4) `gfx_fallback`: forced failure → Arcade renderer, message, result `gfx_fallback`; (5) crash-guard marker
  written and removed; (6) both exports build, `pck_report.py` prints the table, the Arcade Wine smoke run is unchanged.

**PIPE – Asset-Pipeline-Kern und Referenzmodelle**
- Files: `tools/blender/ce3d/**`, `tools/blender/{export_models.py, validate_models.py, check_sprite_geometry.py,
  fixtures/**}`, `tools/models/**`, `tools/models_contact_sheet.sh`, shared `cesprites` core (hooks),
  `scripts/core/model_db.gd`, `scripts/race3d/{modern_materials.gd, model_factory.gd}`,
  `assets/shaders/modern/{vpbr,glass,baked,leaves}.gdshader`, `assets/models/**`, `tests/unit/core/test_model_db.gd`,
  `docs/modelle.md`.
- Inputs: `assets3d/tools/ce3d/*.py`, `assets3d/tools/spike_export.py`, `assets3d/godot_spike/**`,
  `product-ux/evidence/bake_mesh_deterministic.gd`, `synthesis/out/bake_probe.gd`, `synthesis/out/probe2_vpbr.gdshader`.
- Outputs: §4.6 complete; `geometry_v070.json` written **before** the first hook; reference set: `player/limousine`
  (race, show, shadow), `traffic/sedan` (LOD0–2, four colour sets), `props/tree_oak` (card tree, two LODs, impostor),
  `props/farmhouse` (baked), `props/streetlight` (vpbr, light anchor), `landmarks/michel` (baked); a `sets` entry for
  every sprite set (model or `fallback: "sprite"`, generated from the sprite manifest).
- Acceptance: validator green; two bakes byte-identical; contact sheet by day and at night (each lamp channel lit);
  `check_sprite_geometry.py` identical after the hooks; `test_model_db.gd` green (all 180 non-UI sets resolve, object
  sizes equal the sprite manifest); report with triangles, surfaces, bytes, export and bake times per model.

**AU-A – Audio-Kern**
- Files: `scripts/audio/audio_manager.gd` (delegation and §4.7.1 only), `scripts/audio/modern/**`,
  `tools/audio/modern/**`, `tools/audio/qc/**`, `assets/audio/modern/**` (placeholders, manifests), config keys
  `audio.profile` and `audio.modern`, `tests/unit/audio_modern/**`, `docs/audio-modern.md`.
- Inputs: `audio/src/*.py`, `audio/src/scratch_*.gd`, the audio study's step 0.
- Outputs: `ModernAudio` skeleton that owns all Modern parts; bus graph (§4.7.3) with `MEnv` as dry + reflections +
  reverb path; loudness plan, scripted ducking, snapshots (pause low-pass, impact dip, siren dip, result); manifest
  loader; `AudioFeed` v0; `MusicDirector` stub; `audio_qc.py`; stubs so AU-B/C/D plug in without touching each other.
- Acceptance: every existing audio unit test unchanged and green; seeded golden test – the Arcade engine mixer output
  is byte-identical with the Modern code present; Arcade bus list and effect parameters identical before/after; 20×
  `set_profile` arcade ↔ modern leaves no extra node or bus; a headless race with the Modern profile and placeholders
  runs without errors; QC tool runs on the placeholders.

**GEO – Geometrie-Kern und Fairness-Prüfungen**
- Files: `scripts/race3d/{road_path, chase_camera, terrain_profile, chunk_context, chunk_builder, chunk_streamer,
  builder_registry}.gd`, `scripts/race3d/builders/debug_road.gd`, `tests/unit/race3d/{test_road_path,
  test_chase_camera, test_terrain_profile, test_chunk_streamer}.gd`, `tests/sim/{modern_sight, modern_path_check}.gd`,
  `docs/renderer-modern.md` (Weltmodell, Kamera, Fairness).
- Inputs: `renderer3d/out/spike_src/{road_path3d.gd, dump_tracks.gd}`, `renderer3d/out/{scan2, scan_loops, scan3b,
  fair_frustum2, fair_crest}.py` and their `.txt` results; `synthesis/out/terr/valley_floor_*.diff`.
- Acceptance: arcs match the closed form (≤ 1 cm over 900 m at R = 134 m); rebase keeps positions within 1 mm; camera
  math ≤ 0.5 px against `RoadProjection` on a straight up to 600 m at 1280×720, 1280×800 and 1680×720; with `--full`
  the study's numbers are reproduced (minimum clearance 267.6 m; F1 0 cases up to 270 m; F2 worst ratio ≤ 0.60 in
  dry, rain, snow; F3 0 cases); the sampled run takes ≤ 45 s; the streamer holds ≤ 16 chunks, sync mode gives the
  same snapshot twice, threaded mode ends in the same snapshot; `floor_y` and `clearance` are tested on synthetic tracks.

### Wave 1 – M1 „Vertikaler Schnitt“, part 1

**R1 – Renderer-Kern** (road, environment, camera, streaming, warm-up)
- Files: `scripts/race3d/{modern_renderer, environment_rig, quality, prewarm, perf_probe}.gd`,
  `builders/{road, roadside}.gd`, `layers/{backdrop, lights, overlay}.gd`, `assets/shaders/modern/{road,
  overlay}.gdshader`, `tests/unit/race3d/{test_road_builder, test_quality, test_environment_rig}.gd`,
  `tests/race3d/check_modern_stage.gd`, `tests/race3d/render/{check_road_parity, check_light_base}.gd`,
  `docs/renderer-modern.md` (Aufbau).
- Inputs: KERN seam, GEO kernel; `renderer3d/out/spike_src/{road_renderer_3d, road_chunk3d, backdrop_layer}.gd`;
  `engine-probe/evidence/prototypes/*`.
- Outputs: Kiel – Hamburg drivable in Modern: asphalt per road type with all paint in the shader (edge and lane
  lines, dashes 6/12 m and 3/6 m, fuel-lane wedge and separator, start/finish checker, crosswalks), shoulders,
  median, curbs, sidewalks, fractional lane transitions, guardrails with posts and reflectors, delineators; sun with
  shadows per preset; ambient, fog and globals from the palette; backdrop at any aspect ratio; headlight spots; HUD
  over 3D; warm-up v1; countdown watchdog; `perf_stats`, `debug_snapshot`; optional loading of all planned builders
  and layers by their fixed file names.
- Acceptance: `check_road_parity` (lane-line pixels ≤ 1 px on a straight at S1; within the study's bounds in
  curves: R 400 m ≤ 6 px to 150 m, R 136 m ≤ 22 px to 100 m, with `look_gain` 0); daylight probes within 10 % of
  Arcade (grass, asphalt, sky) at S1; „Schatten: Aus“ vs „Mittel“ mean brightness ± 2 %; renderer core ≤ 0.6 ms
  GDScript per frame without the vehicle and prop layers (the whole `render()` budget of 1.5 ms is checked by QA1),
  chunk commit ≤ 3 ms; 1280×800 and 1680×720 filled without gaps; cold-cache warm-up check on the slice stage;
  `check_modern_stage`: `ERGEBNIS` = Arcade.

**R2 – Gelände, Requisiten, Fernboden**
- Files: `builders/{terrain, props}.gd`, `layers/far_ground.gd`, `scripts/race3d/prop_library.gd`,
  `assets/shaders/modern/{terrain, far_ground, billboard}.gdshader` (+ takes over `baked`, `leaves`),
  `tests/unit/race3d/{test_terrain_builder, test_props}.gd`, `tests/race3d/render/check_terrain_cover.gd`.
- Inputs: D16, `synthesis/out/terr/*`, `renderer3d/out/{scan3b.txt, shots/pair_sp*.png}`, PIPE's `ModelDB`.
- Outputs: ribbon terrain with verge/ditch and mild relief outside the sight corridor, two-tone scenery bands and the
  outskirts → centre blend, valley-floor edge, far ground; props as MultiMesh per mesh and chunk (mirrored node, D24)
  standing on `ctx.ground()`, LOD ranges from the levels, sprite stand-ins for sets without a model, props beyond
  the clamped ribbon dropped.
- Acceptance: **terrain gate** – `check_terrain_cover` ≤ 0.2 % at T1–T4, S1, C1; A/B sheet T1–T4 without void,
  visible ribbon edge or underside; headless: no terrain triangles of different chunks overlap in plan view inside
  the loaded window (12 hardest stage directions, sampled); a chunk's prop list equals the props of its
  `TrackSegment.sprites` minus the documented drops (five sceneries); F7 test green with the shipped relief;
  ≤ 1,100 terrain triangles per chunk, ≤ 2 draw calls per prop set and chunk.

**R3 – Fahrzeuge und Schilder**
- Files: `layers/{vehicles, flares}.gd`, `scripts/race3d/{vehicle_pose3d, sign_atlas, sign_canvas}.gd`,
  `builders/signs.gd`, `assets/shaders/modern/{sign, flare}.gdshader` (+ takes over `vpbr`, `glass`,
  `model_factory.gd`, `modern_materials.gd`), `tests/unit/race3d/{test_vehicles, test_sign_atlas,
  test_fade_law}.gd`, `tests/race3d/render/{check_vehicle_lights, check_occlusion}.gd`.
- Inputs: PIPE's reference models, `renderer3d/out/spike_src/sign_canvas.gd`, renderer inventory C and D.
- Outputs: vehicle pool keyed by view id; pose from two path points (rear and front of the collision box) so yaw
  and pitch follow the road; own heading from the lateral speed; player terms (steer × 3°, understeer × 6°, roll ≤
  2.5°, blinking through `visible`); wheels spin and steer; LOD by path distance; lamps through `lamp_a`/`lamp_b`
  (tail = night or tunnel, brake, indicators with the 0.72 s period, beacons); flares with Arcade's minimum sizes;
  path-distance fade (F5); `sun` mask; shadow caster or blob shadow; box for sets without a model; trucks and buses
  articulated from their parts. Signs: every sign texture of a stage is pre-rendered in `prepare()` by `SignPainter`
  into SubViewports and kept as mipmapped `ImageTexture` (headless: placeholders); quads with real posts in the
  cross-section plane, wall-mounted variants, retro-reflection.
- Acceptance: footprint corners = collision box ± 0.3 m at 20 poses incl. the tightest bend; lamps in the snapshot
  follow the view flags; `check_vehicle_lights` (indicator ≥ `INDICATOR_MIN_PX` at 300 m; tail light at 0.839 ×
  visibility above the threshold at N1); `check_occlusion` (car behind a crest, brake light behind a truck: 0 px);
  no SubViewport or texture created during the drive (counter); every sign kind `Track` can emit is drawn (test over
  the kinds of `SignPainter.HALF_WIDTH_M`); `test_fade_law` equals the formula of Arcade's `_item_alpha` at 20
  distances (open road and tunnel);
  ≤ 40 µs per car and frame at 23 cars.

**AS1 – Fahrzeugmodelle für den Schnitt**
- Files: `cesprites/{carbody, cardetail, player_cars, vehicles, designs, heavy}.py` (hooks),
  `tools/blender/ce3d/{vehicles3d, decalgeo}.py`, `assets/models/{player/{limousine,kompakt},
  traffic/{sedan,hatch,wagon,truck}}/**`.
- Outputs: two player cars (race mesh from generator detail levels, show mesh, shadow mesh), three traffic bodies
  with geometry decals (adaptive grid, ≤ 6,000 decal triangles) and LOD0–2, all their colour sets as `sets` paint,
  the truck with tractor/trailer parts and its four liveries.
- Acceptance: validator green; contact sheets day/night; A/B showroom sprite vs real-time `show` for both player
  cars (decides `showroom`); draw calls per traffic car at LOD0 ≤ 6; geometry fixture identical; byte report.

### Wave 2 – M1, part 2 → gate 1

**UI1 – Optionen, Auswahl, Showroom, Ladebild**
- Files: `scripts/ui/screens/{options_screen, graphics_choice_screen, benchmark_screen, title_screen, result_screen,
  race_result_screen}.gd`, `scripts/ui/{game_flow, attract_mode}.gd`, `scripts/ui/widgets/{showroom_3d,
  car_showcase, loading_overlay}.gd`, `tests/race/check_options_tabs.gd`, `tests/unit/ui/test_showroom.gd`,
  `docs/ui.md`, `docs/grafik-modi.md`.
- Outputs: §4.8 except the watchdog offers (UI2); `gfx` in leaderboard entries; `set_profile` and
  `set_music_context` calls.
- Acceptance: `check_options_tabs` 10/10 with real pad events; `check_menu_pad` 9/9, `test_steam_deck`,
  `test_menu_input` unchanged; chooser condition matrix (D32) unit-tested; switching „Grafik“ changes the showroom at
  once; showroom in physical pixels at 1080p; all new screens fit 1280×720 and 1280×800 with text ≥ 18 px
  (screenshots in both sizes); crash-guard question on the title.

**AS1b – Umgebung für den Schnitt**
- Files: `cesprites/{props, props_nature, props_buildings, props_road}.py` (hooks), `tools/blender/ce3d/{veg3d,
  leafatlas, props3d}.py`, `assets/models/props/{tree_oak, tree_birch, bush_round, bush_low, farmhouse, barn,
  haybale, wind_turbine, windmill, power_pylon, streetlight, delineator, fuel_station, fuel_pump, radar_camera,
  customs_booth}/**`.
- Acceptance: validator green; contact sheets; card trees inside the budget with impostors; A/B sheet S1–S3 without
  a sprite stand-in in the first 75 km of Kiel – Hamburg.

**AU-B – Motor v3**
- Files: `tools/audio/modern/engine_synth3.py`, `scripts/audio/modern/{engine_bank2, engine_audio3,
  engine_mix_thread, vehicle_layers}.gd`, `assets/audio/modern/{engines, vehicle}/**`,
  `tests/unit/audio_modern/test_engine3*.gd`, `docs/motorsound.md` (Abschnitt Modern).
- Inputs: `audio/src/{bank3, engine3, render_new}.py`, the character table of the five cars.
- Acceptance: junction/click tests on both channels; L/R balance within 0.5 dB over a sweep; mono sum not below
  −3 dB of a channel; full throttle −16 ± 1.5 LUFS short-term through the Modern buses; thread bench: 0 underruns
  with six 400 ms main-thread hitches, 20 clean shutdowns; sync mode sample-identical twice; cost per frame reported;
  A/B MP3 per car.

**QA1 – Prüfungen und Vorabversion des Schnitts**
- Files: `tests/race3d/render/check_modern_render.gd`, `tests/race3d/bench_modern.gd`, `scripts/race3d/benchmark.gd`,
  `tools/{ab_sheet, ab_clip, smoke_modern}.sh`, `tests/golden/modern_slice.md5`, `docs/qa-v080.md`.
- Outputs: A/B contact sheets (Arcade | Modern from identical simulation states) for every reference position;
  three A/B clips of 20–30 s; bench numbers per preset; test build of both platforms from a commit with the size
  table; Wine and OpenGL ES smoke runs; the gate-1 package in `<scratch>/v080/deliver/gate1/`.
- Acceptance: every render check of §4.9.2 the slice can satisfy is green, the open ones are listed; bench inside
  the `deck` budget at S3 and C1 or the deviation reported; fairness tests green with the shipped camera and terrain;
  a paused Modern frame is identical over 30 frames; `render()` ≤ 1.5 ms average at 12 cars (headless).

### Wave 3 – M2, part 1

**R4 – Licht, Nacht, Wetter**: `layers/weather.gd`, `assets/shaders/modern/{particles_rain, particles_snow,
spray}.gdshader`, takes over the files of §5; tests `tests/race3d/render/{check_night, check_weather}.gd`,
`tests/unit/race3d/test_light_pool.gd`. Outputs: night calibration (ambient, moon, emission), omni pool on the
nearest lamps and the beacon, analytical pools (player cone 80 m, ≤ 6 traffic cones, ≤ 16 lamps), emissive lamps
with glow, retro-reflection of markings/delineators/signs, rain and snow as `GPUParticles3D` in camera space
(`cast_shadow` off, off in tunnels), wet road (darker, smoother, sky reflection, analytical tail-light streaks),
snow ground and banks, dawn/dusk/overcast, sky reflection resource. Acceptance: F6 at N1; no light through hills or
trucks at night; luminance/contrast table per weather × hour inside its bounds, N1 mean road luminance within 15 %
of Arcade and never darker; particles visible at every „Effekte“ level; the light cap holds along three night
stages (snapshot); cold-cache warm-up check on N1 and N2.

**R5 – Tunnel und Brücken**: `builders/{tunnel, bridge}.gd`, `assets/shaders/modern/{tunnel, water}.gdshader`,
tests `tests/unit/race3d/{test_tunnel, test_bridge}.gd`, `tests/race3d/render/check_tunnel_bridge.gd`. Environment
changes are requested from R4 (owner of `environment_rig.gd`) through `EnvironmentRig.set_zone(kind, amount)`.
Outputs per renderer inventory B: tube, haunches, ceiling, two lamp rows, niches, walkways, wall signs, portal frame
and mound closing the terrain, end cap after `render.tunnel.peek_m` seen from outside, tunnel ambient and fog,
exposure ramp at the exit; bridge deck, banks and quay walls, railings per type, truss girders and portals, pylons
with cables and warning lights, lamps, water plane. Acceptance: U1 and Somport (no sky inside, lamps lit, exit not
black, cars inside follow the tunnel fade law); B1 A/B sheet; terrain cover ≤ 0.2 % at portals; every bridge of the
network builds headless without error.

**R6 – Tankstelle, Grenze, Stadt, Start/Ziel, Radar**: `builders/{station, border, city, gantry, radar}.gd`, tests
`tests/unit/race3d/test_structures.gd`, `tests/race3d/render/check_structures.gd`. Outputs per renderer inventory
B/C; lettering through pre-rendered `SignAtlas` panels. Acceptance: A/B sheets of every element on DEV; refuel
sequence, police stop, radar flash, countdown lamps and finish banner visible in a clip; fuel-lane geometry equals
`Track.fuel_lane_*`; street lights every 33 m on alternating sides with their pools.

**AS2a – Spielerautos und Verkehr, Rest**: `cesprites/{carbody, cardetail, player_cars, vehicles, designs}.py`, new
`cesprites/carinterior.py`, `assets/models/{player/{kombi,sportwagen,gran_turismo}, traffic/{suv,van,sports}}/**`;
interiors and transparent glass for the five player cars, 3D fixes (wrap-around lamps, grille mesh, mirror arms),
rim styles. Acceptance: as AS1; all 26 car sets resolve to models; `showroom` flags decided by A/B pictures.

### Wave 4 – M2, part 2

**AS2b – Lkw, Busse, Polizei**: `cesprites/{heavy, police}.py`, `tools/blender/ce3d/{heavy3d, police3d}.py`,
`assets/models/{traffic/{truck_*,bus_*}, police/**}`. Acceptance: validator; all 7 heavy and 18 police sets resolve;
beacon channels A/B alternate; part boxes equal the Arcade box parts (collision unchanged).

**AS3 – Vegetation und Natur**: `cesprites/props_nature.py`, `tools/blender/ce3d/{veg3d, leafatlas}.py`,
`assets/models/props/{tree_*, bush_*, heather, rock_*, cliff}/**`: nine tree species × two variants, bushes,
heather, rocks, cliff. Acceptance: validator; silhouette of each card tree matches its sprite (overlay picture);
alpha-test overdraw report (cards per tree, covered pixels at 20 m).

**AU-C1 – Fahrbahn, Wind, Aufprall**: `tools/audio/modern/{vehicle_loops, sfx_modern}.py`,
`scripts/audio/modern/{road_audio, impact_audio, audio_feed}.gd`, `assets/audio/modern/{vehicle, sfx}/**`, tests.
Acceptance: loop seams click-free (QC); tyre and wind levels follow the plan of [S] (wind 3 dB, tyres 4 dB under the
engine at top speed, parameters in data); collisions layered by speed and partner; worst case (tunnel + trucks +
siren + crash + music) ≤ −0.5 dBTP; MP3 previews per layer.

**AU-D1 – Musik-Kette, Titel-Remaster, Stück 1**: `tools/audio/music/**`, `scripts/audio/modern/music_director.gd`,
`assets/audio/modern/music/**`. Acceptance: remaster = same notes (key and chord-root check against the original),
−14 LUFS, true peak ≤ −1 dBTP after Vorbis; track 1 with count-in, loop body and bar-synced ending switching
gaplessly (`AudioStreamInteractive` test, or the two-player fallback); a 30–45 s sketch MP3 goes to the user before
the full arrangement.

### Wave 5 – M2, part 3 → gate 2

**AS4 – Ländliche Gebäude, Straßenmöbel, Brückenteile**: `cesprites/{props, props_buildings, props_road}.py`,
`tools/blender/ce3d/props3d.py`, `assets/models/props/{church, factory, house_med, building_*, bridge_*, houseboat,
ferry_ship, …}/**`. Acceptance: validator; road-side check by day and at night; bake time and bytes per model.

**AS5a – Stadtgebäude, Teil 1** (`props_cities.py`: the styles german, german_old, hanse, dutch, belgian, french,
paris, swiss) and, in wave 6, **AS5b – Teil 2** (italian, spanish, vienna, central, eastern, balkan, baltic and the
rest). Acceptance: validator; texel density of road-facing walls ≥ 26 px/m; reused walls on the far side; outliers
trimmed (e.g. `city_eastern_house_c` with 23,000 garden triangles); atlas bytes inside the budget.

**R7 – Wahrzeichen, Skyline, Fern-LOD**: `builders/landmarks.gd`; takes over `builders/props.gd`,
`prop_library.gd`. Outputs: landmarks on the path up to 1,900 m with Arcade's landmark haze law
(`RoadRenderer.landmark_fade`) and night floodlight, impostors as far LOD of modelled sets, LOD tuning, backdrop
skyline and landmark silhouettes as in Arcade. Acceptance: A/B sheets of ten city arrivals; a landmark stands where
Arcade shows it (screen position within 5 % of the frame width at 600 m on a straight approach); LOD swaps not
visible in the clips at „Details: Mittel“.

**QA-mid – Zwischenabnahme**: whole race Kiel – Nürnberg in Modern in every condition; all render checks; bench per
preset; A/B sheets and clips (night rain, snow, tunnel, bridge, city); test build 2; gate-2 package.

### Wave 6 – M3, part 1

**AS5b – Stadtgebäude, Teil 2** (see AS5a). **AS6 – Wahrzeichen**: `cesprites/props_landmarks.py`,
`tools/blender/ce3d/landmarks3d.py`, `assets/models/landmarks/**` – 33 landmarks, atlas or vertex-colour bake
(lattice and pinnacle models: Eiffel tower, Riesenrad, Cologne, Regensburg, Linz, Milan, Warsaw), floodlight
emission, aviation lights as anchors, all-round check. **AU-D2 – Stücke 2–3, Zwischenspiel, Stinger, UI-Klänge**
(`tools/audio/music/**`, `assets/audio/modern/{music, ui, sfx}/**`). **AU-C2 – Welt, Ambiente, Verkehr, Sirenen**
(`tools/audio/modern/{ambience_synth, traffic_modern}.py`, `scripts/audio/modern/{ambience_audio, env_acoustics,
traffic_extras}.gd`, `assets/audio/modern/{ambience, traffic}/**`). Acceptance as in their studies plus the QC tool
and the size report against §4.11.

### Wave 7 – M3, part 2 → gate 3

**R8 – Effekte und Feinschliff**: `layers/post.gd`, `assets/shaders/modern/{post, sky2d, wet_reflect}.gdshader`,
takes over the files of §5. Canvas sky shader with clouds (replaces `draw_sky`, silhouettes stay), wet-road
reflection overlay and SSAO for „Effekte: Voll“, pooled spray emitters, droplets and speed effects on layer 1 (never
a darkening vignette over the road), dithering for gradients. Acceptance: every render check still green; „Effekte“
levels differ only in effects (base luminance ± 2 %); bench inside the budgets.

**UI2 – Leistungstest, Watchdog, Attract, Dialoge**: `scripts/ui/**` – Leistungstest screen final, watchdog offers
on the result screen, attract demos in Modern, final texts, `docs/grafik-modi.md`, `docs/steam-deck.md`,
`docs/windows.md` (requirements, rescue switch). Acceptance: end-to-end checks with pad events; killed-process test
of the crash guard; `check_attract*` green in both modes.

**AU-E – Audio-Integration und Pegel**: `scripts/audio/audio_manager.gd` (if needed), `scripts/audio/modern/**`,
config `audio.modern`; one full race recorded per profile; loudness plan verified in Movie Maker scenarios
(`tests/race/check_audio_modern.gd`: full throttle −16 ± 1.5 LUFS, music ducks ≥ 3 dB and recovers, worst case
≤ −0.5 dBTP, pass-by left/right and Doppler, tunnel reverb time); small-speaker check (high-pass 180 Hz); tracks 4–5
only if everything else is done.

**QA2 – Netzweite Prüfung**: `tests/race3d/check_all_stages.gd` (every stage direction 60 s headless in Modern with
the leak check), render samples at 40 positions, A/B contact sheets for all 22 sceneries and all 55 city arrivals
with the per-picture checklist (road continuous, objects grounded, scale as in Arcade, light fits the hour, no
missing texture, signs and HUD legible, landmark where Arcade has it); test build 3 (beta); gate-3 package.

### Wave 8 – M4 „Leistung, Abnahme, Release“

**PERF** – budgets per preset at all bench positions, Deck preset tuned against the user's Leistungstest results,
warm-up completeness (cold-cache check on eight stages), leak check, memory ≤ 260 MB of textures, city draw calls
(merge buildings of one style per chunk if the budget is missed).
**QA3** – Arcade goldens final, every headless and render check, fairness `--full`, Wine run of both modes against
the Linux pictures, OpenGL ES pass, size gate, reproducibility (two release builds → same checksums),
`docs/qa-v080.md` final.
**DOC** – `README.md` („Neu in v0.8.0“ with A/B screenshots), `ARCHITECTURE.md` (§1, §3, §6, §11, §12a models,
§13, §14), `docs/{renn-modul, sprites, steam-deck, windows, ui, motorsound, verkehrsgeraeusche}.md` updates, new
screenshots under `marketing/`.
**REL** – version 0.8.0 in `project.godot`, `tools/build_release.sh 0.8.0`; upload of the two archives,
`LIZENZEN.txt` and `SHA256SUMS` to the draft release **only on the lead's explicit instruction**.

---------------------------------------------------------------------------------------------------------------------

## 7. Gates (user review)

Nobody here can see the picture on a real GPU, time it on a Steam Deck or hear the sound. Each gate hands the user a
package in `<scratch>/v080/deliver/gate<n>/`; the lead decides how long to wait for an answer. Asset and audio
breadth may continue while a gate is open; look, camera and preset decisions of the renderer wait for it.

| gate | after | package for the user | decisions that depend on it |
|---|---|---|---|
| 1 | wave 2 | A/B sheets of all reference positions, three A/B clips, engine A/B per car, the audio study's previews (title remaster, track sketch, race mix), test build for Linux/Steam Deck and Windows (Kiel – Hamburg with real assets, other stages with stand-ins), Leistungstest | look and style, curve camera, terrain (or the fallback of §8), Deck preset, Windows/ANGLE, sound direction, music level |
| 2 | wave 5 | whole race Kiel – Nürnberg in every condition (night, rain, snow, tunnel, bridge, border, city), clips, test build 2, music track 1 and sketches of 2–3 | night look, weather, vehicle quality bar, showroom per car, music style |
| 3 | wave 7 | beta build with everything, contact sheets of all sceneries and city arrivals, Leistungstest results per preset | release cut, default presets |

Steam Deck checklist (about 15 minutes, goes into `docs/steam-deck.md`): 1 first start in game mode – which card is
preselected, is the preset „Steam Deck“; 2 Optionen → Grafik → Leistungstest, send `leistungstest.json`; 3 Kiel –
Hamburg in Modern with the performance overlay: fps on the open Autobahn, in dense traffic, in the City Limits;
stutter when something appears for the first time; 4 a night stage in the rain: headlights, glare, legibility of
signs, fps; 5 switch to Arcade and back; 6 40/45 fps limit, battery and fan; 7 docked at 1080p; 8 suspend and
resume inside a Modern race; 9 screenshots of anything that looks wrong, with stage and km from the HUD.
Windows: start normally and with `--rendering-driver opengl3_angle`; title, vehicle selection, one day stage and one
night-rain stage in Modern.

---------------------------------------------------------------------------------------------------------------------

## 8. Risks and prepared fallbacks

| risk | early signal | fallback |
|---|---|---|
| Steam Deck / weak GPUs too slow (GPU cost is unmeasured here) | Leistungstest at gate 1 | lower `deck` preset (shadows off, MSAA off, scale 85 %), watchdog step-down; Arcade stays recommended for tier weak/software |
| Terrain or horizon does not close in true 3D | terrain gate of R2 (wave 1) | first: wider outer ring + valley floor tuning (D16); last resort, decided by the lead at gate 1: the sheared Arcade-parity mapping behind `RoadPath3D` (Arcade camera, no yaw, chunk transforms updated per frame, rigid instances through `ChunkContext.frame()`) – the reason for the three builder rules in D2 |
| Fairness regresses through art (relief, vegetation, dark nights, small lights) | `modern_sight.gd`, render checks F4–F6 | the tests are gates; never relax a threshold without the lead |
| Asset breadth or quality bar (backsides, crude fronts, vegetation) | contact sheets per wave, A/B vs sprite | per-set stand-in (`fallback: "sprite"`) keeps every stage drivable; `showroom` flag per car; wall reuse on blank backs |
| First-use shader stutter | cold-cache warm-up check | warm-up list generated from the materials and light states the stage really uses; `--no-prewarm` only for debugging |
| Windows ANGLE / old Intel and Radeon chips | cannot be tested here (Wine cannot run ANGLE) | self-test → Arcade with a message; crash guard; `--graphics=arcade`; OpenGL ES run on Linux as proxy |
| Arcade regression through shared files (session, HUD, settings, GameFlow, AudioManager) | `tools/golden.sh check`, seeded audio golden | Rules 1 and 2: the package is not done |
| Engine quirks (sRGB-space shadowed light, post path, light limits) change with an engine update | render checks „Schatten: Aus“ brightness, light cap snapshot | each workaround lives in one place (`environment_rig.gd`, `layers/lights.gd`) |
| Archive grows past the limit | `pck_report.py` at every test build | city blocks 2048×1024 → 1024, music q5 → q4, drop tracks 4–5, fewer impostors |
| Audio worker thread on Windows/PipeWire (verified only headless on Linux) | underrun counter, shutdown test under Wine | `audio.modern.engine_thread = false` (≈ 0.7 ms per frame on a PC core, inferred) |
| Music cannot be judged by the agents | user feedback at gates 1–2 | ship remaster + interlude, „Musik im Rennen“ default off |
| Draw calls in City Limits (many building types per chunk) | bench at C1 | merge the buildings of one style per chunk into one mesh (shared style atlas) in PERF |
| Memory with two asset sets in one process | texture memory in the bench | each mode loads only its own assets; release on leaving a mode |
| Machine load (Blender bakes, llvmpipe checks, audio renders on 4 cores) | wall-clock of the waves | Rule 8; bake-heavy packages (AS5a/b, AS6) never run together with a QA package that renders |

---------------------------------------------------------------------------------------------------------------------

## 9. Open questions for the user – defaults used until answered

1. One switch or two? Default: the chooser and „Grafik“ set the mode; „Klang“ = „Wie Grafik“ unless the player picks
   Arcade or Modern sound separately.
2. Music in races with the Modern sound – on by default? Default: yes („Musik im Rennen: An“, can be switched off).
3. First start of v0.8.0: chooser also for existing players? Default: yes, one time; nobody is switched silently.
4. Can the user test pre-release builds on a Steam Deck and a Windows PC at the gates and send back the
   Leistungstest result? Default: builds are prepared at every gate; without answers the Deck preset stays
   conservative and Modern is not preselected on weak/unknown hardware.
5. Shared leaderboards for both modes? Default: shared (identical simulation), mode stored invisibly.
6. Steam Deck: Modern fills 16:10, Arcade keeps its bars? Default: yes.
7. Title picture, map and result screens stay as they are in both modes? Default: yes (a living 3D title may follow).
8. Release cut: three race tracks + remastered title theme (tracks 4–5 later), interiors only for the player cars,
   country siren styles and number plates per country later? Default: as stated in §1.
9. Curve camera (the view turns into bends, the car moves up to ≈ 10 % of the screen width off centre in the
   tightest bends): keep as default? Default: yes; judged by playing the gate-1 build.

---------------------------------------------------------------------------------------------------------------------

## 10. Evidence index

Root: `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/`
(keep these folders until the release; prototypes are starting points, not code to copy unread).

| folder | content |
|---|---|
| `engine-probe/evidence/` | [E] sheets and logs of ≈ 60 engine experiments, shader prototypes (`prototypes/`: sky_clouds, wet_ssr, post_screen, inst_uniform, bend), `game_switch_test.gd`, class reference of this build, renderer-restriction strings |
| `renderer3d/out/` | [R] spike renderer (`spike_src/`), A/B screenshots (`shots/`), world scans and fairness scripts with results, `spike_numbers.txt` |
| `assets3d/` | [A] prototype exporter (`tools/ce3d/`, `tools/spike_export.py`, `tools/tree_cards.py`), Godot viewer and role shaders (`godot_spike/`), inventory and sweep reports (`out/`), contact sheets (`shots/`), sample `.glb` (`out/samples/`) |
| `audio/` | [S] prototypes (`src/`), measurements (`out/`), user previews (`deliver/motor`, `deliver/musik`) |
| `product-ux/` | [P] prototype diffs (`evidence/spike_scripts.diff`, `spike_tests.diff`), bake script, PCK reports, golden hashes, logs, screenshots (`shots/`) |
| `synthesis/out/` | [X] own experiments of this contract (below) |

[X] experiments (all on Godot 4.7.2, Compatibility, Mesa llvmpipe under Xvfb or headless):
- `probe_results.json`, `e1_sheet.png`, `e2_sheet.png`, `probe1_main.gd` – light additivity (ambient 37, sun 84,
  sum without shadow flag 91, with flag 120, with flag and no casters 120 at 3 instead of 15 draw calls, sun energy
  0 = ambient only); post path pinned by adjustments (± 1 level); `BG_CANVAS` + sky as reflection and ambient source,
  also with glow, 3D scale 0.75, MSAA 2× and depth fog. `probe_e3_shadow_modes.txt` – lit brightness 121 for
  orthogonal / 2 / 4 splits, with and without casters (6 / 9 / 15 draw calls with, 3 without).
- `probe2_results.json`, `t1_day.png`, `t1_night_fade.png`, `probe2_main.gd`, `probe2_vpbr.gdshader` – VPBR-L vertex
  format through a compressed `.res` (paint codes, lamp channels, `flat` varyings), instance uniforms, runtime
  global uniform, 50 % dither fade; mirrored `MultiMeshInstance3D` node = identical pixels to the unmirrored one;
  frustum camera with constant focal: 0.000 px against the Arcade formula at 1280×720, 1280×800, 1680×720.
- `bake_probe.gd`, `bake_a.md5`, `bake_b.md5`, `bake_c.md5`, `bake_nodes.json` – headless bake of
  `player_kompakt_d2.glb` (49,984 triangles, 5 meshes) to node-free `.res`: byte-identical in two headless runs and
  under Xvfb/OpenGL.
- `e10_*.txt`, `race_session.e10.gd` – track generation forced 1,900 m ahead, and the 3D spike renderer: identical
  `ERGEBNIS` (27 keys) on dev_testetappe (night, rain) and Saragossa – Pau (snow).
- `terr/` – valley-floor terrain closure in the spike: `ab_sp172_before_after.jpg` (before: pale void on the outside
  of a climbing bend; after: closed), `floor_other_positions.jpg` (tightest bend, bend into a descent, crest),
  `valley_floor_chunk.diff`, `valley_floor_renderer.diff` (≈ 30 changed lines), `race_session_spike.diff`;
  `expand1610_kw60.jpg` – the spike at 1280×800 with stretch aspect `expand`: picture fills 16:10, HUD unchanged.

Not verified by anyone and therefore inferred everywhere in this contract: real-GPU frame times, the Steam Deck,
ANGLE/Direct3D 11, how anything sounds.
