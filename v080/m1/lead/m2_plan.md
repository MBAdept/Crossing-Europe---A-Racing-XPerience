# M2 plan (draft, lead) – waves 3–5 → gate 2 / test build 2 (ZS2)

Goal of ZS2 (told to the user): the whole race in Modern in night, rain, snow, tunnels, cities (contract: Kiel – Nürnberg
in every condition), all vehicles, vegetation, first cities.

## Order
0. ZS1 delivered (QA1 head = H1). Fast-forward v0.8.0 to H1, commit contract §11.2 (contract_11_2_draft.md).
1. M2INT (one agent, render kind): merge onto H1 the early content – AS2R c7546c1, AU-D2 2f4f260 (+ the user's
   headphone mix if it arrived: mischung.json re-render), AU-C1 (final), AS3R, AS4R (if done) – conflict notes in
   m2_integration_notes.md; re-export what --check-keys names; manifest; validator; run_tests; golden; ERGEBNIS;
   census + texmem with every vehicle a model; A/B S1–S5 again. Owner of check_vehicles kasten/leistung fix.
2. Renderer wave from the M2INT head, three workflows side by side (2 agents each at most):
   - R4 light/night/weather (+ the open renderer items of KRITIK-2: paint exposure A1 if still open, flakes A4,
     night fill A2, LOOK in one place) → its own review lens → fix
   - R5 tunnels/bridges (zones through EnvironmentRig.set_zone; uses AS4's bridge_* where they fit)
   - R6 station/border/city/gantry/radar (SignAtlas lettering; fuel lane = Track.fuel_lane_*)
   - AS5a city buildings part 1 – NOT beside a rendering QA (§8); start when no QA renders
   - AU-C2 world/ambience/traffic/sirens (early from wave 6) if CPU allows
3. R7 landmarks/skyline/far LOD (needs AS5a for city impostors; AS6 landmarks are M3) – wave 5
4. RINT-M2 assembly → QA-mid (whole race Kiel – Nürnberg in every condition; render checks; bench per preset; A/B
   sheets and clips night rain, snow, tunnel, bridge, city) → fixes → test build 2 → gate-2 package.

## User decisions from gate 1 that change M2
- look/style (contrast, saturation, fog), curve camera (on/off/strength), terrain, Deck preset (Leistungstest
  numbers), Windows/ANGLE, sound direction, music level (mischung.json).
- If the user's feedback arrives while R4–R6 run: send the decisions as a lead note into the running briefs only by
  restarting with STAND.md continuation (resume protocol), never by force.
