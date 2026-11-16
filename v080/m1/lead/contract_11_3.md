### 11.3 During M2 (2026-11-12/16; evidence: the reports of M2INT, M2ZS1, QA-M2-BILD/-SYSTEM, FIX-M2, NACH-M2, R4/R5/R6 with their reviews QA-R4/-R5/-R6, fix rounds FIX-R4/-R5/-R6 and re-checks NACH-R4/-R5/-R6, AS5a1/KRITIK-5a1/AS5aR1, FLACKER-ANALYSE)

**A-17 Sight corridor of bends (lead decision; replaces the open point of A-3 and A-10)**
- The F7 corridor is computed from the real geometry, not as a constant band d²/8R over ±L/2: for every row and the
  inside of every bend it is the envelope of all sight lines (chords) of length L along the actual path, with the
  camera in every lane. L(row) = min(300 m, F2 need at that row); the F2 need is the one of `fairness.speed_profile` /
  `modern_sight` (stopping distance at the fastest drivable speed / 0.6 + the camera offset). The band thus runs out
  at the start and end of a bend, a short bend gets the sagitta of its real arc, a straight before a bend is free, and
  slow mountain bends (Saragossa–Pau T3/T4: 107–119 m) get their trees back.
- Strict reading stays: nothing that rises more than 0.5 m (trees, rocks, houses, fences, posts that are not Arcade's)
  stands inside the envelope; ground cover ≤ 0.5 m fills it. The terrain uses the same envelope
  (`corridor_width()`).
- Acceptance: `modern_sight --full` (F1–F3; F7 checks the envelope) green; the occlusion probe at T1–T4, C1, S0, S4
  (test car in three lanes, 25–270 m) never below what F2 requires; the number of props that came back per position;
  A/B pictures against Arcade; no new terrain holes or seams. City houses in town bends: measured and shown with
  pictures by the package; F2 must hold.

**A-18 Structures (lead decisions after R6/QA-R6/FIX-R6)**
- A border roof whose second front pillar would stand in the sight corridor hangs from masts with stays on the
  carried side (5 of 48 roofs). With the envelope of A-17 a pillar of Arcade's that is then outside the envelope
  stands again as a pillar.
- A pillar or column that Arcade does not draw never covers a gameplay board (curve, speed, exit, fuel station,
  border) by 6 px or more at any distance up to 600 m; where the only alternative is a roof without support, the roof
  hangs as above.
- Main-thread budget for `collect()` of every layer and builder: at most 2 ms per frame on the Deck preset (llvmpipe
  measured, real hardware inferred); line-of-sight decisions belong in `prepare()` or on the worker threads.
- `assets/shaders/modern/flare.gdshader` belongs to the owner of `layers/flares.gd`. `tests/golden/modern_slice.*`
  belongs to the integration and QA: packages do not regenerate it; the assembly regenerates it once after the merge,
  after looking at the pictures.
- Bridge railings per type (Arcade's balusters on stone bridges included) belong to the owner of
  `builders/roadside.gd`. The tunnel light crosses package lines through data: the tunnel builder publishes
  `tunnel_state.light` and `tunnel_state.exit_z`; the road shader and the exit exposure read them (duck typing, A-7).

**A-19 Shader instance uniforms (lead decision after M2INT and FLACKER-ANALYSE)**
- Godot's global buffer for instance uniforms holds about 254 instances per scene (4,096 slots, 16 per instance,
  minus the `ce_*` globals); an instance it refuses reads wrong values until it is freed. Only the vehicle layer uses
  instance uniforms (budget 128); every other model uses `VPBR_STATIC` or `baked` without instance uniforms.
- Gate: the whole scene stays at or below 230 instances with instance uniforms at „Hoch“ with full traffic on a
  forest stage, a city finish and Kiel–Hamburg (`check_instance_budget*`), and that check really loads the budget.
- The placement tint of a prop (`tint`, `fallback_tint`) reaches model instances too, through the MultiMesh colour
  (or another per-instance channel that is not an instance uniform); `baked`/`vpbr` multiply the albedo by it as
  Arcade multiplies the sprite.

**A-20 Light at night (lead decisions after FIX-M2/NACH-M2 and R4/FIX-R4)**
- The low beam keeps its specular on the road (wet road, R4); vehicles are kept from blowing out in the low beam
  through their material, not by switching off the light's specular for everything.
- The extra glow gain of model brake lights and beacons (`model_glow_gain`) is for daylight; at night the glow stays
  within Arcade's +10 %.
- The wet night is part of R4's acceptance (`check_night_nass`): wet cone 0.7–1.15× Arcade, edge line at least 0.8×
  Arcade's contrast, no reflection pixels above a car roof.

**A-21 Plan (lead decisions)**
- AS5a runs beside wave 3 at nice 19 with one worker and a memory guard (< 3 GB free → wait); the risk table's „never
  beside a rendering QA“ yields for AS5a, because AS5a would otherwise lie wholly on the critical path to test build 2.
- After the assembly RINT-M2 (FIX-M2, R4, R5, R6, AS5aR1) come R7 (landmarks, skyline, far LOD, the corridor of
  A-17, AS5a batch 2), then QA-mid (the whole race Kiel – Nürnberg in every condition), then test build 2.
- The paint flicker the user saw once in test build 1 (a white car at about 40 m) is paused at the user's request
  („ich vermute einen ladefehler“); the analysis is kept (FLACKER-ANALYSE) and nothing is changed for it until the
  user asks.

**A-22 City buildings (lead decisions after AS5a1/KRITIK-5a1/AS5aR1)**
- A side wall that the camera sees from the street gets windows and doors built only from the generator's own means
  (the same grids, window types and colours as the front) behind `close3d`; the sprites stay byte-identical. This
  holds for AS5a2 and AS5b too.
- Railings keep their coverage in the small mip levels through the bake (`cut_fill`: gaps with alpha 0.4 and the
  colour of the wall behind); the alpha test at 0.5 in `baked.gdshader` stays.
- Buildings get the LOD dither cross-fade of the trees and a per-model lod0 distance (`max_dist_m` in `model.json`,
  about 35 m for half-timbered houses against the shimmer of thin beams) – R7.
