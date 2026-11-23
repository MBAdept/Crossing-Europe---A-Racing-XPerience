### 11.4 After R7 (2026-11-22/23; evidence: the reports of QA-RINT-BILD/-SYSTEM, FIX-RINT, NACH-RINT, R7a/R7b/R7c with their reviews QA-R7a/-R7b/-R7c, fix rounds FIX-R7a/-R7b/-R7c and re-checks NACH-R7a/-R7b/-R7c)

**A-23 Wave 5 split and ownership (lead decision)**
- R7 ran as three packages on the assembly RINT-M2: R7a the sight corridor (kernel `terrain_profile`, `chunk_context`,
  new `sight_corridor.gd`, `tests/sim/modern_sight.gd` and `tests/race3d/fairness.gd`; exceptions `builders/border.gd`,
  `builders/city.gd`, `builders/terrain.gd`), R7b landmarks and skyline (new `builders/landmarks.gd`,
  `assets/shaders/modern/landmark.gdshader`, the skyline part of `layers/backdrop.gd`, a marked skip in `props.gd`),
  R7c the far LOD of buildings and plants (`builders/props.gd`, `prop_library.gd`, `baked/leaves/billboard`,
  `inc/lod_band.gdshaderinc`, `model_factory.gd`, `modern_materials.gd`, config `graphics`). After the assembly
  RINT-M3 the open-road package R7d (A-27) owns the files A-27 names; nothing else runs beside it.

**A-24 Sight corridor and the whole object (decision on FIX-R7a's contract issues)**
- A-17's strict reading applies to the whole object, not to its foot point: a prop whose model (the AABB of its largest
  variant, turned as it is placed) or crown reaches into the envelope is pushed out of it – depth + 0.3 m, at most
  12 m – and dropped only when that is not enough. "Nothing in the sight lines" wins over "exactly Arcade's position";
  the push-out is the measured way with the fewest losses (8 items of the base instead of 1,218). Props that a model
  brings along (`attach`) follow the same rule.
- `tests/race3d/check_props_footprint.gd` (network-wide; `list` and `attach_list`; the model AABB, not a footprint
  model of its own) is a gate in `tools/run_tests.sh`, owned by the owner of `props.gd`.
- The F2 need inside City Limits stays the one of the fastest drivable speed (not the speed limit): the few Arcade
  objects that stand in those sight lines stay out.

**A-25 Landmarks (replaces D24's "never mirrored and not turned")**
- A landmark is mirrored where Arcade mirrors its picture (a plain prop such as `props/church` standing as a
  landmark); a `landmarks/*` model is never mirrored. Models and procedural shapes face their approach (bearing from
  the road point 600 m before, at most 40°) and never come nearer the road than at Arcade's anchor. The node that is
  drawn stays within 12 m of Arcade's anchor, and a network test checks the drawn node, not only the resolved anchor.

**A-26 LOD band of buildings and plants (decisions on R7c's contract issues)**
- City houses keep lod0 up to 60 m; half-timbered houses, Haussmann and the corner house switch at 30 m. The look wins
  over the shimmer of the canal house and the chalet at 40–60 m; that shimmer is model work (AS5b).
- A-16's cross-fade is the path band of R7c whose width follows the camera speed (at most speed × 0.4 s, through one
  global, `ce_lod_band_m`): standing is a hard swap at the far end of the band, driving off never shows an ordered
  dither for seconds, crossing the far end fades in about 0.4 s at any speed. No per-instance state, no instance
  uniforms (A-19).
- A-22's per-model lod0 distance lives in `graphics.modern.props.lod0_m` (model.json belongs to the asset packages).
- Attachments that would lie beyond the 96-m chunk are skipped, not handed to the next chunk.

**A-27 The open road (R7d; lead decision after QA-RINT-BILD F-02)**
- On the open motorway, where the player spends most of every race, Modern must be recognisable at first glance and
  clearly more beautiful than Arcade – by day, at dusk, at night, in rain and snow. R7d runs after RINT-M3 and before
  QA-mid and test build 2.
- The sky of Modern becomes a canvas sky shader with clouds (`assets/shaders/modern/sky2d.gdshader`, pulled forward
  from R8; R8 keeps post, wet reflections, spray and droplets); Arcade's silhouettes, skylines and landmarks stay in
  front of it; it never uses `TIME`. The reflection sky of D7 follows its mean colours.
- Cloud shadows fall on terrain, far ground and scenery props, never on vehicles, signs or their lights; on the road
  at most a soft dimming that keeps the marking contrast ratio and ≥ 0.85 × the lit luminance.
- Aerial perspective only within F4: static scenery is never fogged more than in Arcade at the same road point; haze
  may live in the sky's horizon band and shift the hue of far scenery, never lower its contrast below Arcade's fog.
- The road surface may carry wear, patches, joints and resurfaced sections within Arcade's luminance band of the road
  type (mean ± 6 %) and with a marking contrast of at least 0.9 × Arcade's at 20, 60 and 120 m, day and night, dry and
  wet (Rule 9). Relief only outside the A-17 envelope. The Steam Deck preset keeps the sky and the cloud shadows.
- R7d owns for this: `environment_rig.gd`, the sky part of `layers/backdrop.gd`, `sky2d.gdshader`,
  `builders/road.gd` + `road.gdshader`, `builders/terrain.gd` + `terrain.gdshader`, far ground (layer and shader),
  `inc/ground*.gdshaderinc`, `terrain_profile.gd` (relief outside the envelope only), `baked/leaves/billboard` (cloud
  shadows, variation), `props.gd`/`prop_library.gd` (ground cover, per-instance variation), config `graphics`. Not:
  vehicles, lights, flares, models and their assets, `sight_corridor.gd`, the thresholds of the fairness tests.

**A-28 Streamer and main-thread budgets (lead decisions after FIX-RINT/NACH-RINT)**
- A chunk commits builder by builder within 2 ms per frame; a builder whose own commit exceeds 3 ms on the Deck
  preset splits into parts, and the chunk becomes visible only when every part hangs.
- A chunk that is dropped while it is still committing releases everything it already registered with a layer
  (reflectors, lamps, flares); every layer also skips entries whose node is no longer valid.
- Main-thread maxima (commit, `collect()`, hooks) are judged as the median of three runs on llvmpipe beside the base in
  the same session (A-11); the Steam Deck measurement of PERF decides.
- A-20's first sentence refers to `ce_headlight_light` of the road (`inc/headlight.gdshaderinc`); the light's
  `SPOT_SPECULAR` does not reach the road.

**A-29 Plan (lead decisions)**
- RINT-M3 (FIX-RINT + FIX-R7a/-R7b/-R7c, this §11.4) → R7d with review, fix round and re-check → QA-mid (the whole race
  Kiel – Nürnberg in every condition) → test build 2.
- Model work collected for AS5b in wave 6: sports car brake band 0.35 m and centre brake light; the Gran Turismo's
  silver at night; the limousine's hue at dusk; the fuel-station shop night atlas (A-16); AS1b panes; garden trees as
  attachments; corner-house back, wall lamps, office tower texel density, Maas house far windows, Bern arcades at night;
  Speicher lod1 door panels; Kontor lod1 shimmer; canal house and chalet lod0 shimmer; the night windows of the city
  houses where the bake decides (QA-RINT-BILD F-04).
- `tests/golden/modern_slice.*` stays with the integration (A-18); a package that regenerated it is superseded by the
  assembly, which regenerates once after looking.
- The paint flicker stays paused (A-21).
