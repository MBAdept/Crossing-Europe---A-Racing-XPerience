
// R7d "Freie Strecke" – DRAFT of the brief (lead, 22.11.); assembled into m6_body.js once the R7 results are in.
const R7D_WHY = `WHY THIS PACKAGE EXISTS (lead decision after QA-RINT-BILD F-02, severity high; ${SP}/deliver/QA-RINT-BILD/bericht.md
§F-02, pictures bilder/S1_00.jpg, S3_00.jpg, S1_DECK_00.jpg, S1_busch_links.jpg): on the open motorway – where the player
spends most of every race – Modern shows almost Arcade's picture: the same flat sky with Arcade's cloud sprites (the
canvas backdrop of D7), tree groups of nearly the same shape, the road a flat grey, the verge and fields barely
different. Only the grass texture and the steel guardrail are new. The user's wish ("das gesamte Spiel einer deutlichen
grafischen Überarbeitung unterziehen … Detailreiche Grafik … bessere Lichteffekte") is NOT met there. Your benchmark:
a player who switches the mode on the open motorway (S1, S3, Deck S1) recognises Modern AT FIRST GLANCE and finds it
clearly more beautiful – by day, at dusk, at night, in rain and in snow – without anything the player reacts to becoming
harder to see.`

const R7D_SCOPE = `WHAT TO BUILD – ordered by the share of the screen it covers (measure the shares at S1/S3 yourself first and say
which of these is missing, which exists but is invisible at the chase camera, and why; road.gdshader and
inc/ground.gdshaderinc already contain wear, patches, fields and furrows that the QA could not see):
1. SKY (about 35–45 % of the frame): a canvas sky shader (assets/shaders/modern/sky2d.gdshader, pulled forward from R8,
   contract wave 7; prototype ${SP}/engine-probe/evidence/prototypes/sky_clouds.gdshader and t_sky.gd) that replaces
   RaceBackdrop.draw_sky and Arcade's cloud sprites IN MODERN ONLY: layered fbm clouds with light and shade from the
   sun's direction (state.sun_pos, environment_rig's sun – sky, light and shadows must agree), fair-weather cumulus on
   a clear day, a closed grey deck in rain and snow, coloured clouds at dawn and dusk, moonlit clouds and stars at night,
   a bright hazy band at the horizon, a sun glow. Cover and colours from the palette and the weather of the simulation
   state (Arcade's cloud cover per weather and hour is the reference for HOW MUCH sky is clouded). Deterministic: a
   function of the simulation state and view.time, never TIME (goldens, Rule 10); drift slowly with the wind (ce_wind).
   Silhouettes, skylines and landmarks (R7b's work in backdrop.gd/landmarks.gd) stay in front of it, unchanged. The
   reflection Sky resource of D7 follows the new sky's mean colours (vehicles and wet road mirror the same sky).
   Cost: measure per preset; if needed render the cloud field at reduced resolution or refresh it every few frames
   (clouds move slowly) – the Deck preset keeps it.
2. CLOUD SHADOWS (what makes a landscape look real at first glance): soft, large, slowly drifting shadow patches from
   the same cloud field on the terrain, the far ground and the scenery props (trees, buildings). Never on vehicles,
   signs or their lights. On the road surface either none (fading in beyond the paved edge) or at most a soft dimming
   that keeps the marking contrast ratio and leaves the road at ≥ 0.85 × its lit luminance – choose by pictures (a sunlit
   band along the road that never sees a cloud looks fake; a dark road hides nothing only if the contrast holds) and
   justify it with numbers. Only by day with clouds; none under a closed deck (rain/snow: diffuse light).
3. ROAD SURFACE (about 25–30 %): make the asphalt read as a real motorway at the chase camera and up to about 150 m:
   polished/darker wheel tracks, resurfaced sections with a different tone and a seam, patches, crack sealing, the joints
   of concrete slabs where a motorway is concrete (choose per country/road type and say why), worn paint, dirt toward
   the edges, a little sheen at low sun. Inside Arcade's luminance band of each road type (mean ± 6 %), and marking
   contrast at 20/60/120 m at least 0.9 × Arcade's by day and night, dry and wet (Rule 9 – markings, road edges and
   guardrails are things the player reacts to). Wet: water stands in the wheel tracks (R4's wet law stays the base).
4. VERGE, MEADOW AND FIELDS (about 15–20 %): richer ground at the chase camera: mown verge vs. longer grass, wildflowers
   in season colours of the scenery, field parcels with crop rows that run in their own direction, farm tracks, hedgerow
   lines along field borders (decorative props only outside the A-17 envelope; ground cover ≤ 0.5 m – props/cover_grass,
   props/cover_bush – may fill the corridor, A-10/A-17), soft colour variation at 50–500 m. Nothing may make the far
   ground below the horizon brighter than Arcade's fog law (A-10: no bright strip, no wall pattern).
5. RELIEF: gentle rolling land beyond the A-17 envelope where the scenery is not flat by nature (the North German plain
   is gently undulating, not a table) – terrain_profile relief OUTSIDE the envelope only; sight_corridor.gd (R7a) and
   the envelope stay exactly as they are; F7 and the occlusion probe must stay as R7a left them.
6. TREES AND SHADE: per-instance variation of the tree models (hue, size, lean – within the placement's tint, A-19 via
   the MultiMesh colour, no instance uniforms), visible shadows of trees and bushes on the grass at „Mittel“ and „Hoch“,
   wind sway where the leaves shader allows it; nothing new inside the envelope – a larger or leaning tree counts
   with its real AABB in the footprint of A-24 (check_props_footprint stays 0).
7. AERIAL PERSPECTIVE – ONLY WITHIN F4: static scenery is never fogged more than in Arcade at the same road point (F4,
   depth fog 0.45 … 1.0 × visibility). Haze may live in the sky's horizon band and may shift the HUE of far scenery toward
   the horizon colour, but never lower its contrast below what Arcade's fog gives at that distance; vehicles, signs and
   their lights are never touched (F5/F6). If you find F4 forbids something the look needs, report it as a contract issue
   with pictures – do not bend it.`

const R7D_RULES = `RULES FOR THIS PACKAGE
- You build on the third M2 assembly (RINT-M3) and are the only renderer package running: you may change
  environment_rig.gd, layers/backdrop.gd (the sky part only; R7b's skyline and landmark code unchanged), the new
  sky2d.gdshader, road.gd/road.gdshader, terrain.gd/terrain.gdshader/far_ground (layer and shader), inc/ground*.gdshaderinc,
  terrain_profile.gd (relief outside the envelope), leaves/baked/billboard shaders for cloud shadows and variation,
  props.gd/prop_library.gd for ground cover density and per-instance variation, config graphics (new levels per preset),
  docs. NOT: vehicles, lights/flares, models and their assets, sight_corridor.gd, the fairness tests' thresholds, the
  frozen Arcade files (Rule 1).
- „Details“/„Effekte“ levels may scale your additions down for the Deck/Niedrig presets but never what the player
  reacts to (Rule 9). The Steam Deck preset must keep the sky and the cloud shadows (they ARE the first glance).
- tests/golden/modern_slice.* belongs to the integration (A-18): do not regenerate it; list which of the six pictures
  changed and why.
- Show what you change, A/B against Arcade AND against your base, at S1, S3, S0, S4, T2, Deck S1, at 08:00, 12:00,
  19:30, 22:00, clear, rain and snow (at least S1 and S3 in all seven), plus two 20-s clips on the open motorway (day
  clear; dusk) side by side with Arcade. LOOK at every picture. Say plainly per picture whether Modern is now
  recognisable at first glance and where it is still Arcade's picture.`

const R7D_GATES = `GATES on your final head: import clean; tests/check_scripts.gd; tools/run_tests.sh green (A-11 for load-only timing);
tools/golden.sh check 20 von 20 and 17 von 17 (once); tools/run_render_checks.sh all (F4–F6 and the night/wet checks
included); tests/sim/modern_sight.gd -- --full and modern_path_check.gd -- --full; the A-17 occlusion probe at T1–T4,
C1, S0, S4 unchanged against your base; a new render check that guards your rules (marking contrast ≥ 0.9 × Arcade at
20/60/120 m on your new road surface, cloud shadows never on road/vehicles, the far-ground fog law of F4); perf_stats of
complete autopilot runs of Kiel–Hamburg at deck, medium and high next to your base in the same session (render() ms
mean/max, the sky's own cost, draw calls, primitives, memory; llvmpipe measured, Deck inferred) inside §4.10; ERGEBNIS
identity Arcade vs Modern on kiel_hamburg (Rule 3).`
