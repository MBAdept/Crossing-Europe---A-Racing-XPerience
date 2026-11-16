# M2 integration – lead notes (collected while ZS1 runs)

Base: the final ZS1 head (RINT-B → FIX1 → QA1). Merge with --no-ff in this order:

1. AS2R = wip/v080-as2r c7546c1 (contains AS2a 19aa138 and AS2b 19624cd; base AS1R c478902, already in RINT-B)
   – every vehicle set has a model now (37 models, 180 sets, meshes 16.45/40 MB); worktree wf_72970c4d-66e-4 kept
   (tools/blender/_cache3d, 58 MB, speeds up a re-export)
2. AU-D2 = wip/v080-au-d2 2f4f260 (base AU-D1 03eaeff, already in RINT-B): race tracks 2–3, interlude, stingers,
   UI sounds; one shared mix file tools/audio/music/mischung.json (user's headphone verdict pending)
3. AU-C1 = wip/v080-au-c1 4209268 (DONE; base 2f4f260, so it contains AU-D2 – merge AU-C1 alone): AudioFeed, road,
   wind, impacts, ModernAudioPan (new file), 17 loops + 17 one-shots (4.52 MB; sound budget 17.9/23 MB),
   config audio.modern.{feed,road,impact}, snapshots.impact; two AU-A tests adapted. Previews sent to the user
   (15:4x UTC). Open (lead/AU-E): D29 top-speed row (+2.8 dB sum with road+wind; engines alone −17.2…−18.5 LUFS),
   master limiter is sample-peak (−0.8 dB before master volume; overshoot 0.1–0.7 dB → at master 1.0 worst case
   −0.5…−0.1 dBTP inferred) → Modern-only true-peak-safe threshold; traffic/siren placeholders drive the limiter
   by up to 4 dB (AU-C2); capture_mix.gd sends no vehicle state (AU-E tool gap); no data for cuttings/delineators
   (heuristics); no own snow sound; wheelbase = 0.6 × length.
   Independent sound reviews DONE (wf_efa77159-fa4; reports deliver/KRITIK-FAHRBAHN, deliver/KRITIK-MISCHUNG):
   road – loop sum exactly periodic 0.97 s (corr 0.64), cobble hash bug (djb2, Hamburg always cobbled), cobbles +19 dB,
   slabs dominate, joints every 24 m on every deck, glass/squeal tonal, small speakers flip the balance, top speed and
   heavy crash > −1 dBTP at volume 1.0 → Modern MMaster limiter −2 dB; music – all −14.1 LUFS, seams exact, melody
   41/33/27 % audible under full throttle (model), sub 50 Hz +10.5 dB and > 5 kHz +3.5…6.3 dB vs v0.5.0 title,
   sub_db/bass_db weak → new low_shelf_db; render_all 32.6 min (> 30-min background default).
   USER VERDICT (~17:40 UTC, headphones): „die sounds scheinen solide, auf kopfhörer getestet. auch die musik ist
   sehr gut" → AU-R scope reduced to measured faults, character kept (spectra ±1 dB, loudness ±0.5 LU), music unchanged.
   AU-R RUNNING: wsrpqyxcc / wf_5dca29a9-6fb, script wf_m2g_klang_r.js, args_m2g.json; chain AU-R (base 4209268,
   wip/v080-au-r) → KRITIK-R → AU-R2 only on blocker/high (wip/v080-au-r2). Content: R1 repetition (own loop per side,
   random offsets, OU drift), R2 hash fmix32 (shares as configured, cobble_share 0.6 stays), R3 slab phase + tunnel wind 0,
   R4 joints per deck (steel ends + ~100 m, stone none, concrete 32 m), R5 Modern MMaster limiter −2 dB (≤ −1 dBTP at
   volume 1.0), R6 variants/random choice, glass ≥ 80 km/h or p 0.4, snow loop, no fuel-lane rumble.
   Deferred to AU-E (after the user's Deck test): cobbles 19 → 12, slabs 3 → −3, glass grains, squeal voices, rail ring,
   cavity peak, small-speaker clack, handheld mix, all music mix proposals (melody under full throttle 41/33/27 %;
   D29 8 → 6.5 dB; low shelf for the sub) – the knob sheet is in deliver/KRITIK-MISCHUNG/bericht.md §6.
   M2INT then merges the last AU-R head INSTEAD of AU-C1 (it contains AU-C1 and AU-D2).
   DONE 23:19 UTC: AU-R 3d2e6e1 → KRITIK-R (H1 slab layer +1.75 dB @398 Hz, H2 R1 concrete 0.642 = slab rhythm,
   M1 AudioServer lock every frame, M2/M3 limiter at its limits, M4 truck −1 dB unjustified, M5 standout cobbles;
   L2 Venice causeway cobbled) → AU-R2 3600eb7 (wip/v080-au-r2; slab patterns from AU-C1's 8 joints, slab law above
   150 km/h 4 dB/decade, cobble right seed +64 matched at pitch 1.02, lock only at start/0.5 s, truck −11 kept by
   60-crash p95 3.02 dB at −10; run_tests 653/0, golden 20/20; sound 19.0/23 MB). Previews re-sent to the user ~23:25.
   Lead decisions V1–V3 (contract draft A-14): R1 on concrete without slab layer; concrete ±0.05 only for ≥ 10
   sections; limiter p95 over 60 crashes / max per 60-s run over ≥ 4 runs.
   ACCEPTANCE RUNNING: wedxtmfb2 / wf_15398915-ab3, script wf_m2h_klang_abnahme.js: AU-R3 (L2 fix, base 3600eb7,
   wip/v080-au-r3) → KRITIK-R2-MESS ∥ KRITIK-R2-CODE (read-only) → AU-R4 on blocker/high (wip/v080-au-r4) → KRITIK-R3.
   M2INT merges the LAST head of that chain (AU-R4, else AU-R3; fallback AU-R2 3600eb7). Worktrees of AU-R/AU-R2 removed.
   ZS1 has only AU-D1 audio (title remaster, race track 1, MusicDirector, engine v3 AU-B) – the road/wind/impact sounds
   come in test build 2: say so when the user judges the melody under full throttle in ZS1.

## Predicted conflicts and how to resolve them

- tools/blender/ce3d/truck3d.py, roles.py, validate_models.py, assets/models/traffic/truck/**, manifest.json,
  docs/modelle.md: RINT-B 9eac32f introduced lamp channel 15 "retro" (contour tape + triangle reflectors light up in
  the player's low beam; SURFACE_CHANNELS += retro; validator LAMP_CHANNELS 16) and re-exported traffic/truck.
  AS2b/AS2R rebuilt the trucks as three types (truck, truck_transport, truck_tarp) + bus (heavy3d) + police (police3d).
  Resolution: take AS2R's builders, re-apply "retro:%.2f" % TAPE_NIGHT to every retro-reflective surface of ALL heavy
  types (tape red/yellow, triangle reflectors; also bus/police reflectors if any – AS2R made SUV reflectors visible,
  check their channel), keep RINT-B's roles.py/validator change, re-export ONLY what --check-keys names, regenerate
  the manifest (--manifest-only), validator, export determinism (second bake byte-identical).
- tools/models/contact_sheet.gd: AS2a (showroom AgX), AS2b (--arcade for traffic/police/heavy, beacon tile), AS2R
  (C2: race look really applied – create vpbr/glass materials before _apply_look) and RINT-B (--showroom with
  STUDIO_LOOK). Combine all four.
- tests/race3d/check_vehicles.gd: RINT-B added "instanzen" and "ueberblendung"; R3's "kasten" expects model-less sets
  (traffic/sports_red, police/at) – none exist after AS2a/b → switch kasten to a test manifest with one model-less set;
  "leistung" counts the lazy first build of a level (34 → 35) → either build all levels at spawn (preferred if cheap;
  measure) or count only new cars. Both red in AS2a/AS2b/AS2R runs, owner R3 → the integrator owns it now.
- assets/models: up to 8f58b2d RINT-B touched only traffic/truck/** (9eac32f, retro channel) – verified; re-check
  RINT-B's final head and FIX1 before the merge (git log <zs1-head> ^b473e90 -- assets/models tools/blender).

## Renderer follow-ups found by KRITIK-2 / AS2R (verify against RINT-B's final state first)

- A1 paint exposure: RINT-B set knee 0.45 (S1 limo noon +6.7 %, kompakt dusk −16.2 %) – re-measure with AS2R's tools
  (m1/AS2R/kritik/probe.sh, bin/winmean.py, platemean.py, bandmean.py, buswin.py) on the merged head.
- A3/B5 lamp_off 0.25–0.3 and tail 0.5 / brake ≥ 2×: RINT-B measured brake/tail 3.93 – check unlit lamps by day.
- A4 metallic flakes alias at race distance (GT 83 sparkle px/frame): flake_near_m ~3 m or cells coupled to fwidth,
  else flake_strength 0 in the race look.
- C1 showroom look: RINT-B added the showroom's own look (studio_look) – re-test showroom flags (candidates kombi,
  limousine, sportwagen, gran_turismo; kompakt only after its yellow is right).
- LOOK has no shared home (vehicle layer, contact sheet and showroom each set it) → one constant in ModernMaterials.
- Far-level albedo constants tuned to the LOOK at AS2R time: TRAFFIC_GLASS_FAR #3a4652, truck3d.GLASS_FAR,
  FAR_PLATE #a2a2a0 (heavy3d FAR_PLATE #c4c4c1 not aligned), CHECK_MEAN_EXP 0.6 → re-measure after any exposure/tone
  change.
- Night: player tail lights 36–60 % of Arcade's lit area without flares, body black (Arcade lifts the player sprite
  ×1.15+0.08) → R3 flares + R4 night fill; RINT-B did env_night 35 % / fill_night 30 % – re-measure.
- Articulated semis: groups tractor/trailer with pivots exist (king pin 0,1.19,−3.7) → R4 should evaluate them.
- LOD pops left (with race look): SUV 29.8 %, sports 28.4 % at 120 m (silhouette + normals), sedan 14.4 % at 40 m
  (seam aliasing), police/be 38 % at 120 m (checks as texture), bus 21.7 % at 180 m – RINT-B's xfade (0.5 s dithered
  cross-fade lod1↔lod2) should hide most; measure with xfade on.
- Instance budget: RINT-B set INSTANCE_BUDGET 128 for the vehicle layer; with every set a model (no Arcade-picture
  stand-ins) re-run the census probe (m1/RINT-B/probe/census) and texture memory (stand-in sheets no longer loaded?).

## Contract amendments to write (§11)

- A-9 (proposal): validator lamp rule counts visible area by ray test (KRITIK-2 lamp_vis.py, ~5 s/model) – hidden
  lamps passed (kombi reverse 10 %, kompakt reverse 0 %, SUV reflectors 0 %; fixed by AS2R).
- A-10 (proposal): police lod2 budget 1,200 → 1,400 (livery + light bar + outline-cut rear window); police lod1 is at
  5,975–5,991/6,000.
- §5 ownership: police3d hooks into traffic3d internals (traffic_design, decalgeo.car_surfaces, SmoothCar.lower_half,
  bumper_half_fn) → make official hook parameters in traffic3d.
- Lead decisions of M1 (already listed in the summary): stand-ins = Arcade pictures (R3E), stand-ins cast no sun
  shadow, F7 strict until gate-2 mountains, horizon law, single analytic reflection source, load-robust timing checks,
  whole-renderer budget, AU-D2 to ZS2.

## Status 2026-11-12 ~03:10 UTC (lead)

- QA1 DONE: head 92ece73 (docs) / test build from 10d836f; v0.8.0 fast-forwarded to 92ece73 and pushed. Findings:
  QA1-B1 high (start at km 0: camera 9 m ahead, own car invisible in the countdown), QA1-B3 medium (gantry lamp rims
  cast shadows with shadows off → run_render_checks 16/17), QA1-B2 medium (curve camera pushes near edge signs out).
  Verdict: Modern "Hoch" by day equal to slightly better than Arcade; nowhere clearly better yet; worse in rain/snow,
  at crests and bend insides, at the start, with "Niedrig". Old build in deliver/gate1/build (NOT to be sent).
- ZS1 START FIX RUNNING: wewtrkyn9 / wf_9559b070-4dd, script wf_m2j_zs1_startfix.js, args_m2j.json: FIX-ZS1
  (wip/v080-fix-zs1; new build into deliver/FIX-ZS1/build, docs into deliver/FIX-ZS1/) → QA-ZS1 (independent, archives)
  → FIX-ZS1R on blocker/high/medium (wip/v080-fix-zs1r) → NACH-ZS1 if the game changed. When done: copy
  deliver/FIX-ZS1/build/* and the two docs into deliver/gate1/ (replace), write m1/lead/ZS1_FERTIG with the final
  commit (M2INT waits for it), ff v0.8.0 to that commit, push, send the user the build.
- AS3/AS4 DONE (wt9f22qym / wf_aad8d49e-fb4): AS3R 638debc, AS4R 09f679b (pylon M1 fixed, windows in night atlas).
- Sound chain: AU-R3 b6339ad → acceptance (MESS: no high; CODE: H1–H4 tests unguarded, M1/M2) → AU-R4 f253687 (all 7
  fixed, 662/0, Kiel–Hamburg road sound bit-identical, truck body hit −11.5 dB) → KRITIK-R3 running (wedxtmfb2).
- Contract §11.2 (A-9 … A-16) committed by plumbing as 350b071 on origin/wip/v080-vertrag (parent 92ece73); NOT on
  v0.8.0 yet (would break the ff of the ZS1 worktrees) – v0.8.0 gets it through the M2 line.
- M2INT RUNNING: w4imccvl1 / wf_438996b0-243, script wf_m2i_zusammenbau.js, args_m2i.json (base 350b071, AS2R, AS3R,
  AS4R 09f679b, sound AU-R4 f253687; nice 19 until ZS1_FERTIG exists, then merges the ZS1 fix before final gates).
- Worktrees removed: wf_ae4df3ba-14f-1..5, wf_aad8d49e-fb4-1/-2 (all pushed). Kept: AS2R wf_72970c4d-66e-4, AS3R
  fb4-4, AS4R fb4-6 (Blender caches), sound ab3-1/-4 (KRITIK-R3 may use them).
- SOUND CHAIN DONE (wedxtmfb2 / wf_15398915-ab3, ~03:00 UTC): KRITIK-R3 accepts AU-R4 f253687 (all 7 findings fixed,
  40/40 mutations red, V3 truck p95 2.13–2.85 dB in 5×60 crashes, TP ≤ −1.26 dBTP, Kiel–Hamburg feed bit-identical,
  run_tests 662/0, golden 20/20). M2INT already merges f253687 – no later sound delta needed.
  For AU-E (later, low): test-guard gaps L-A (pitch actually played per squeal), L-B (jitter/delay reaching the
  player; stand-in players in ImpactAudio tests), L-C (slab realign at 145 km/h, other direction), L-D (pair-share band
  brittle → 0.15–0.52 or chi-square); stone-bridge metres as pre-cobbled in cobbled_blocks (16 towns, not Hamburg);
  tunnels inside old towns count as streets; re-measure with AU-R3 scratch tools enum_bridges.gd / stage_compare.gd /
  diff_trig.py; optional Venice preview if the user wants to hear it.
- LEAD OBSERVATION (03:45, FIX-ZS1 A/B starts, medium): at the start of Kiel–Hamburg AND Saragossa–Pau (from Pau, 22 h)
  Arcade shows a big tree on the LEFT at screen x≈150/1000, base just below the horizon (≈100 m ahead, ≈40 m left,
  estimated) – Modern has nothing there (Köln start: no such tree in either). deco_density at medium is 1.0, so not
  "density"; suspects: "ribbon" drop near z = 0, the mirrored left MultiMesh of chunk 0, or a start event. Not a ZS1
  blocker. TODO after ZS1: diagnose headless (drop_reason of the props of chunk 0 on both stages) and fix in the M2
  line (pictures: m1/FIX-ZS1/shots/kh0_ab_00.jpg, m1/FIX-ZS1/starts/sp22_ab_00.jpg).
- 05:20 UTC: FIX-ZS1 DONE 3a23cb8 (start fixed: car at Arcade's place ≤ 1 %, also in the exports; lamp rims; new
  render check start_km0 red on 92ece73/green now; run_tests 699/0, golden 20/20+17/17, modern 6/6 (only
  modern_start_mittel changed), render checks 18/18; build deliver/FIX-ZS1/build from 3a23cb8; docs deliver/FIX-ZS1/).
  CHECK 3 found: Köhlbrandbrücke shows MEADOW instead of the Elbe (far-ground plane road−4 m covers water at −9 m),
  ferries on the meadow – not fixed by FIX-ZS1 (noted in was_neu.md).
  QA-ZS1 running since 05:17 on the 3a23cb8 build (wewtrkyn9).
  WATER FIX LAUNCHED in parallel: wfm2f4g4r / wf_bdb6e1e1-c64, script wf_m2k_zs1_wasser.js, args_m2k.json: FIX-WASSER
  (base 3a23cb8, wip/v080-fix-wasser, build into deliver/FIX-WASSER/build, docs deliver/FIX-WASSER/) → QA-WASSER →
  FIX-WASSER-R → NACH-WASSER. If QA-ZS1 also triggers FIX-ZS1R: if FIX-ZS1R fixes the water too, stop the duplicate;
  otherwise merge both heads before the final build. Final ZS1 = the water head (if verified) → ZS1_FERTIG.
- 06:54 UTC QA-ZS1 DONE (verdict: may go to the user; start fixed in the exports, Wine = Linux pixel-identical, Arcade
  20/20+17/17, km 2 bit-identical with the old build). Findings: B1 high water (→ FIX-WASSER), B2 medium F7 corridor
  window ±156 m (corridor_chord_m/2) makes the whole start straight before an early left bend an inside → trees on the
  left dropped (Kiel oak z 27.9 x −17.1; Paris–Tours, Hamburg–Hannover, Saragossa–Pau 8 poplars) → M2/R2 with
  fairness proof (modern_sight --full), probe m1/QA-ZS1/probe_start_props.gd; B3 low SHA256SUMS lists the 2 bare
  programs → lead writes SHA256SUMS of the delivered files only; B4 low was_neu.md: bend insides also on flat stages
  (sentence in the report §6) → lead edits the final doc.
  Lead STOPPED the ZS1 workflow (wewtrkyn9) right after QA-ZS1 to avoid a duplicate water fix and a rushed F7 change
  (FIX-ZS1R had only imported; scratch moved to m1/_abgebrochen_FIX-ZS1R; worktrees wf_9559b070-4dd-1..3 removed).

## Status 12.11. 12:55 UTC – ZS1 ausgeliefert
- Wasser-Workflow wf_bdb6e1e1-c64 fertig: FIX-WASSER 0ad9012 (Fernboden = min(tiefste Straße − 4 m, tiefstes Wasser − 0,3 m)),
  QA-WASSER: Ja + B1 (6 Wahrzeichen fehlen in Modern, medium), B2 (Pylone nachts weiß, medium), B3 (Ufer, low), B4 (Doku), B5 (Render-Wächter);
  FIX-WASSER-R 39849f0 (props.gd: Wahrzeichen-Ersatzbild aus landmark_info-Fallback, dark_material für prefer_proc-Ersatz; K1 in
  check_terrain_cover mit Fernboden ≤ 2 %; Plan-Dump über FarGround.target_height()); NACH-WASSER: Ja, N1–N3 low.
- ZS1 = 39849f0 (BUILDINFO), ausgeliefert aus deliver/ZS1 (SHA256SUMS nur die 3 gelieferten Dateien; nackte Programme in BUILDINFO).
  Doku: N3 (Häuser in Stadtkurven) und N2 (Ersatz-Hochhaus Dortmund/Madrid zu wuchtig) ergänzt.
- origin/v0.8.0 per Push auf 39849f0 vorgespult. LOKALER Checkout bleibt auf 92ece73, solange Workflows Worktrees von HEAD ziehen
  und auf die M2-Linie (350b071…) vorspulen müssen.
- m1/lead/ZS1_FERTIG = 39849f0 geschrieben (12:47, nach der Frist) – M2INT schließt ohne ZS1-Merge ab.
- NÄCHSTER SCHRITT M2: 39849f0 --no-ff in die M2INT-Linie mergen. Konflikte erwartet:
  * far_ground.gd: M2INT b341df8 hat die Elbe selbst behoben; EINE Lösung behalten – bevorzugt die ZS1-Lösung (Unit-Test
    test_far_ground_water, Render-Prüfung K1, QA-WASSER/NACH-WASSER geprüft), b341df8-Teile nur übernehmen, wenn sie mehr abdecken.
  * props.gd: FIX-WASSER-R (Ersatz-Wahrzeichen, dark_material) gegen M2INT/AS-Änderungen; mit dem AS4R-Pylonmodell greift
    dark_material nicht mehr → rotes Flugwarnlicht als Lampe (add_lamps) oder im Modell.
  * Modern-Goldens (modern_slice.md5/env) neu erzeugen und ansehen.
- Offene Kleinpunkte aus ZS1 für M2: N1 (Fern-Wahrzeichen jetzt für alle getönt, Test fehlt), N2 (Ersatzform je proc-Art:
  schlanker Turm für tv_tower/lighthouse oder Breitendeckel), N3 (F7 wirft Stadthäuser in Kurven – Entscheidung R2/Leitung),
  B2-Rest (Pylonfüße tags), B3 (Kaimauern/Böschungen R5, ferne Ufer R2 – ein Eigentümer im Vertrag), Elbphilharmonie nachts,
  Belgrad-Vorort km 187,4 (Häuser rechts fehlen = F7-Korridor, s. N3), Vertrag D16/A-3 auf neue Fernboden-Regel nachziehen,
  §4.9.2 Fernboden-Grenze an Wasserpositionen.
- Aufräumen später: m1/FIX-WASSER-R/alt/ (290 MB), deliver/gate1/build (alter Build), deliver/FIX-ZS1/build, Worktrees wf_bdb6e1e1-c64-*.

## Status 12.11. 13:05 UTC – M2INT fertig, ZS1-Merge läuft
- M2INT = 49f221e (origin/wip/v080-m2int), offen laut eigener Liste: ZS1-Merge, Notiz 6 (Look) und 7 (AS3R/AS4R) teilweise,
  Render-Prüfungen all (light_base Schatten rot bis ZS1), A/B-Bögen/Clips teilweise. Bericht deliver/M2INT/bericht.md.
- Workflow wf_438996b0-243 nach M2INT gestoppt (die zwei QA-Linsen liefen erst Sekunden; ihre Ordner als _abgebrochen_* abgelegt,
  Worktrees -2/-3 entfernt) und mit wf_m2l_zusammenbau.js fortgesetzt (Task wjloz8ye4): M2INT aus dem Cache (Prompt
  byte-gleich geprüft), NEU M2ZS1 (merged 39849f0 --no-ff auf 49f221e, Gates, Builds, Smoke), dann QA-M2-BILD/-SYSTEM auf
  dem Merge-Kopf, FIX-M2, NEU NACH-M2 bei Spieländerung. Args stecken im Skript (args_m2l.json eingebettet).

## 12.11. ~13:20 UTC – Nutzer auf unbestimmte Zeit verhindert („bitte ohne meine Testergebnisse erst einmal weitermachen“)
- Entscheidungen ohne Nutzer: Kurvenkamera, Deck-Voreinstellung, Musikpegel bleiben wie in ZS1; Look nach Vertrag und
  ehrlichem Vergleich mit Arcade. ZS2 wird fertig bereitgelegt und geschickt, der Nutzer testet, wenn er zurück ist.
- Welle 3 vorbereitet: wf_m3a_welle3.js (R4 Licht/Nacht/Wetter, R5 Tunnel/Brücken/Wasser/Ufer, R6 Tankstelle/Grenze/
  Stadt/Start-Ziel/Blitzer; je Bau → QA → FIX → NACH). Start mit args {base: <M2ZS1-Kopf>}, sobald M2ZS1 fertig ist
  (Hintergrund-Warter b1rbxdav7). Eigentum W3: R4 = Renderer-Kern laut §5-Tabelle; R5 = tunnel/bridge/water + far_ground.gd
  (Wasserteile; Shader bleibt R4) + Ausnahme: Brückenteile aus props.gd in bridge.gd verlegen (eine Skip-Zeile);
  R6 = station/border/city/gantry/radar + Ausnahme: Skip-Zeile für Straßenlaternen in props.gd; set_zone baut R4,
  R5 ruft es duck-typed. Marker m1/lead/QA_M2_FERTIG anlegen, sobald beide QA-M2-Linsen fertig sind (dann nice 10).
- Danach: AS5a (Stadtgebäude, Blender-lastig – nicht neben rendernder QA), R7 (Wahrzeichen/Skyline/Fern-LOD, braucht
  AS5a), RINT-M2 (R4+R5+R6+FIX-M2+AS5a+R7), QA-mid, ZS2.

## Stand 2026-11-12 15:20 UTC – M2ZS1 fertig, Welle 3 gestartet
- M2ZS1 fertig: Endkopf 6e48405 (25be6c7 Merge, efff1ed Pylon/Befeuerung, b693d33 night_albedo 0,45, 6e48405 Goldens).
  Alle Gates grün (749/0, render 19/19, golden 20/20+17/17, modern 6/6+GLES, sight/path --full, Builds, Smoke 3×).
  origin/wip/v080-m2int = origin/wip/v080-m2zs1 = 6e48405. Bericht deliver/M2ZS1/bericht.md.
  Vertragsfragen offen: D16/A-3 Fernbodenregel; A-4/A-9 Tönung der Wahrzeichen-Ersatzmodelle (Leipzig, Madrid);
  A-16/D19 Nachtatlas des Pylonmodells (Assets: nur Befeuerung backen); Nachtgesetz senkrechter Flächen (R4).
- m2l (wjloz8ye4, Lauf wf_438996b0-243) läuft weiter: QA-M2-BILD + QA-M2-SYSTEM auf 6e48405, dann FIX-M2, NACH-M2.
- Welle 3 gestartet: Workflow wwrmqxal6, Lauf wf_2c31531c-63a, Skript wf_m3a_welle3.js, args {base: 6e48405…}.
  Briefe ergänzt um M2ZS1-Erkenntnisse (R4 Punkt 8 Nachtgesetz/night_albedo; R5 Pylon dunkel + Blinklicht schon da).
  Resume: Workflow({scriptPath: wf_m3a_welle3.js, resumeFromRunId: 'wf_2c31531c-63a'}).
- Wächter bne5ad8hj: wait_labels.py auf QA-M2-BILD + QA-M2-SYSTEM → touch QA_M2_FERTIG (Welle 3 dann nice 10).
- Danach: AS5a (Blender, nie neben einer Render-QA) → R7 → RINT-M2 → QA-mid → ZS2.
- 15:25 UTC KORREKTUR: Workflow-Deckel = 2 gleichzeitige Agenten je Workflow (4 CPUs − 2) → R6 hätte Stunden gewartet.
  wwrmqxal6 nach 3 min gestoppt (R4/R5 hatten nur Import gemacht; Worktrees, Branches, m1/R4, m1/R5 gelöscht) und neu:
  • R4 + R5: Workflow wpy9837xo, Lauf wf_fd1de4ee-28b, Skript wf_m3a_welle3.js, args {base: 6e48405…, only: [R4, R5]}
  • R6:      Workflow w9w4pw4m9, Lauf wf_3b3101bc-877, Skript wf_m3a_welle3_r6.js (Kopie), args {…, only: [R6]}
  Resume je mit eigenem scriptPath + resumeFromRunId. Worktrees von M2INT (-243-1) und M2ZS1 (-243-2) entfernt (Platz).
- 15:40 UTC AS5a gestartet (Stadtgebäude Teil 1, zwei Chargen nacheinander, je Bau → KRITIK → Nacharbeit):
  Workflow w60djlybe, Lauf wf_db8ba6cd-508, Skript wf_m3b_stadt1.js (= m3b_meta + c1_head + m3b_body), args {base: 6e48405…}.
  Charge 1 AS5a1/KRITIK-5a1/AS5aR1: hanse, german, german_old (11 Sets – Rennen Kiel–Nürnberg); Charge 2 AS5a2/…/AS5aR2:
  dutch, belgian, french, paris, swiss (12 Sets), Basis = Kopf von AS5aR1. Resume: args gleich lassen; nur Charge 2:
  {base, only:['2'], base2:<Kopf>}. Branches wip/v080-as5a1, -as5ar1, -as5a2, -as5ar2.
  LEITUNGSENTSCHEIDUNG (Abweichung von der Risikotabelle „AS5a/b nie neben einer rendernden QA“): AS5a läuft neben
  Welle 3 mit nice 19, einem Arbeiter und Speicherwächter (< 3 GB frei → warten); sonst läge AS5a ganz auf dem
  kritischen Pfad zu ZS2. Vertrag bei Gelegenheit nachziehen.
- FÜR R7 / RINT-M2 (neu gefunden): props.gd gibt die Platzierungs-Tönung ("tint", "fallback_tint") nur an
  Vertretungen weiter, nicht an Modell-Instanzen (Zeile ~643: `if not is_model: buf.append…tint`). Heute schon
  ungetönt in Modern: building_shop ×9, building_block_a ×3, building_oldtown ×1, bush_low ×1 (Szenerie-Platzierungen
  mit tint); mit AS5a dazu city_german_house #e8b8a4 + city_german_mietshaus #e0b09c (Hanse-Stadtrand: Kiel,
  Hamburg!), gruenderzeit/mietshaus bayerisch/schweiz, dutch_terrace Ruhr. Lösung: Instanzfarbe auch für Modelle
  (MultiMesh use_colors) und baked/vpbr multiplizieren die Albedo damit – wie Arcade das Sprite multipliziert.
- Wächter bsovsum2g: meldet, wenn < 5 GB Platz frei sind.
- 17:15 UTC: Last 24 (6 Agenten, je ein llvmpipe-Godot mit 15–22 Threads; QA-M2 nice 10, Rest nice 19). Platz 9,4 GB →
  alte Worktrees AS2R (wf_72970c4d-66e-4), AS3R (wf_aad8d49e-fb4-4), AS4R (wf_aad8d49e-fb4-6) entfernt (alle Köpfe in
  6e48405 enthalten, nichts Ungesichertes) → 11 GB frei. Branches worktree-wf_* bleiben als Refs.
  Wächter bne5ad8hj nach 2 h abgelaufen (QA-M2 noch nicht fertig) → neu: bjacr2jge (gleicher Befehl).
  Falls Platz wieder knapp: scratchpad/v070 (343 MB), steam/{work,final_work} (300 MB), m1-Ordner alter Pakete
  (QA1, QA-BILD, QA-SYSTEM, RINT-B, KRITIK-*, QA-WASSER, FIX-WASSER: Rohbilder) – Skripte in m1/AS1b, m1/AS4R,
  m1/NACH-WASSER/tools werden noch von Briefen referenziert: NICHT löschen.
- Zeitplan grob: QA-M2 fertig ~18–19 Uhr → FIX-M2 → NACH-M2 ~01 Uhr; Welle 3 Bau bis ~23 Uhr, QA/FIX/NACH bis ~07 Uhr;
  AS5a1+KRITIK+AS5aR1 bis ~06 Uhr → RINT-M2 (R4, R5, R6, FIX-M2, AS5aR1) ab ~07 Uhr → R7 → QA-mid → ZS2.
- 19:10 UTC: QA-M2 läuft noch (SYSTEM: Warteschlange seit 16:47 – Mutationen, Klang, Mischung, Musik, Export-Determinismus,
  Rückfall, Bench, Soak, Builds, Smoke, Golden). Wächter bjacr2jge abgelaufen → biu36cvw5. R4 bei check_night
  (Fahrbahn N1 +4,9 % OK, Spielerauto nachts zu hell → arbeitet daran), AS5a1 exportiert german (bake_samples 4).
  ACHTUNG Lastartefakte: QA-M2-SYSTEM meldet „wald“ (check_instance_budget_wald) nach > 21 min abgebrochen, ohne Urteil
  → als Befund. Unter Last 22–25 möglich, dass das nur die Last ist: FIX-M2/RINT-M2/QA-mid müssen Zeitüberschreitungen
  unter normaler Last nachstellen, bevor sie als Fehler gelten.
- 19:45 UTC NUTZER-TEST ZS1 (Haupt-PC, Windows): Kassel–Erfurt gespielt, „keine größeren Bugs“, aber „leichtes Clipping
  bei einem weissen PKW, trat 2 mal auf, hing offenbar mit meiner Lenkbewegung zusammen, kein Game Breaker“.
  → Workflow wxafuecro, Lauf wf_35a3e468-d89, Skript wf_m3d_clipping.js (m3d_meta + c1_head + m3d_body),
  args {zs1: 39849f0…, base: 6e48405…}. Stufen: CLIP-NACHSTELLEN ∥ CLIP-ANALYSE → CLIP-DIAGNOSE → 2 Gegenproben →
  FIX-CLIP (wip/v080-fix-clip, eigene Datei + kleiner Haken „# FIX-CLIP“ in layers/vehicles.gd = R4-Datei!) → QA-CLIP
  → ggf. FIX-CLIP2 (wip/v080-fix-clip2) + NACH-CLIP. Ergebnis kommt in RINT-M2.
  Spuren (ungeprüft): hitbox_scale 0,95 (≈ 5 % Überlappung ohne Unfall), Hinten-Regel rear_min_visible_fraction 1/3
  (Auto schräg hinten kollidiert nicht, wenn Arcade es nicht zeigt), Unverwundbarkeit nach Unfall, Modell-Gier
  Spieler bis 20° (Lenkung 3°/Einheit), Verkehr bis 30°; Kollisionsboxen drehen nicht mit.
  Task #76. Wächter Platz: bgzgc4nvq.
- 20:05 UTC KORREKTUR durch den Nutzer: „Clipping“ = GRAFIKFLACKERN – „Der Wagen war schätzungsweise "reale" 40 Meter
  vor mir und "verlor" kurz seine Lackierung“. Clipping-Workflow wxafuecro gestoppt (falsches Problem), Worktree
  entfernt, Ordner → _abgebrochen_CLIP-*. Neu: Workflow wg7wzaawo, Lauf wf_17007edf-ec9, Skript wf_m3e_flackern.js
  (m3e_meta + c1_head + m3e_body), args {zs1: 39849f0…, base: 6e48405…}. Pakete FLACKER-NACHSTELLEN ∥ FLACKER-ANALYSE
  → FLACKER-DIAGNOSE + FLACKER-GEGEN-URSACHE/-ENTWURF → FIX-FLACKERN (wip/v080-fix-flackern) → QA-FLACKERN →
  ggf. FIX-FLACKERN2 + NACH-FLACKERN. Ergebnis in RINT-M2 (berührt R4-Dateien, markiert „FIX-FLACKERN“).
  Spur: lod0↔lod1 genau bei 40 m (Details Mittel; Niedrig 25, Hoch 60), KEINE Überblendung (XFADE nur lod1/lod2),
  Hysterese ±5 %; Lack = Instanz-Uniform paint (Vorgabe GRAU 0,5/0,5/0,52), apply_paint beim Bau; _set_uniforms
  pusht fade/sun/lamps nur bei Änderung gegen Cache, den _set_level nicht zurücksetzt.

## 2026-11-13 05:30 UTC – Neustart nach Ausgabenlimit
- Gestern ~20:00–20:22 UTC brachen ALLE Agenten mit „monthly spend limit“ ab (Wochenlimit setzt Nov 15 08:00 UTC zurück).
  Nutzer: „Versuch es noch einmal“. Container neu gestartet (Dateien erhalten, keine Hintergrundprozesse).
- Stand vorher: QA-M2-BILD fertig (Ergebnis gecacht, „teilweise“), QA-M2-SYSTEM/FIX-M2 abgebrochen; R4 33ded9a, R5 8456140,
  R6 bb38876, AS5a1 a5315cd gepusht (WIP, R4/R5/AS5a1 mit ungesicherten Änderungen im Worktree – Nachfolger committen sie);
  FLACKER-ANALYSE fast fertig: Ursache wahrscheinlich ÜBERLAUF DES INSTANZ-UNIFORM-PUFFERS (Godot GLES3: 4096 vec4,
  16 je Instanz → ~254 Instanzen; abgelehnte Instanz liest falsche Werte: Lack fehlt/überstrahlt, schachbrettartig
  durchsichtig; bleibt abgelehnt; sichtbar beim 40-m-Stufenwechsel). In ZS1 belegten auch Requisiten (vpbr) Plätze;
  M2INT b2c6b52 (VPBR_STATIC) behebt das für Requisiten – NICHT in ZS1. Fahrzeuge allein bis 127/128 Budget → prüfen.
  Widerlegt: Atlas/Mip/BC (Lack = Vertexcode + Instanz-Uniform), veralteter Cache (_set_level setzt zurück), lod1 ohne Lack.
- Neu gestartet (Resume, gleiche Lauf-IDs): Flackern wnslonszs (wf_17007edf-ec9), m2l wag0bo61m (wf_438996b0-243),
  R4/R5 wpl1dvwj4 (wf_fd1de4ee-28b), R6 wtzp3prmm (wf_3b3101bc-877), AS5a wel2sttli (wf_db8ba6cd-508).
  Worktree QA-M2-BILD (-243-3) entfernt. Wächter: bj74ae90t (QA-M2-SYSTEM → QA_M2_FERTIG), b4fjhyek1 (Platz < 4 GB).
- 2026-11-13 ~05:40: alle Neustarts nach ~10 min am WOCHENLIMIT gescheitert (Rücksetzung Nov 15 08:00 UTC).
- 2026-11-15 08:03 UTC: Nutzer „Versuch es noch einmal“ → alle fünf Läufe erneut fortgesetzt (gleiche Lauf-IDs):
  Flackern wkynzdqh5, m2l wj22t0pbg, R4/R5 w310m4hdu, R6 wmxp4wojx, AS5a wxfn6rvhu. Wächter bi7674ntl (QA-M2-SYSTEM),
  bz4bwlmv2 (Platz). Achtung Budget: 7 Agenten parallel verbrauchen das Wochenlimit schnell – bei erneutem Abbruch
  Reihenfolge priorisieren: Flackern → QA-M2-SYSTEM/FIX-M2 → R4/R5/R6 → AS5a.
- 2026-11-15 NUTZER: „nein, das passt schon 🙂 mir ist Geschwindigkeit nicht so wichtig, hauptsache, das wird gut <3“
  → alles parallel weiterlaufen lassen; QUALITÄT VOR TEMPO: keine Abkürzungen bei Prüfungen/Nacharbeit, bei Budget-
  Abbruch auf Rücksetzung warten und sauber fortsetzen statt Schritte zu streichen.

## 15.11. ~09:45 UTC – Lackflackern PAUSIERT (Nutzerwunsch)
NUTZER: "den grafikfehler im Moment bitte nicht weiterverfolgen, ich kann ihn gerade nicht nachstellen, ich vermute einen ladefehler"
- Workflow wkynzdqh5 (run wf_17007edf-ec9) gestoppt; Nachstell-Prozesse (chain4/chain5/queue4/godot) beendet; Worktree wf_17007edf-ec9-1 entfernt (sauber, nichts Ungepushtes).
- Erhalten: deliver/FLACKER-ANALYSE/bericht.md (fertig), m1/FLACKER-NACHSTELLEN/STAND.md + runs4 (Teilstand), deliver/FLACKER-NACHSTELLEN.
- Stand der Analyse: M2-LOD-POP (hart lod0<->lod1 ohne Überblendung, Kennzeichen/Lampen/Fenster springen; hoch), M1-INSTANCE-REFUSAL (Global-Shader-Puffer 254 Instanzen; echter Lackverlust; auf Erfurt–Kassel nicht ausgelöst, Reserve >= 40; niedrig), M3-CASCADE (niedrig).
- FOLGEN: FIX-FLACKERN entfällt aus RINT-M2. KEIN Flacker-Fix nebenbei einbauen. Wiederaufnahme nur auf Nutzerwunsch (dann resumeFromRunId wf_17007edf-ec9 möglich, NACHSTELLEN läuft neu).
- Merkposten (kein Auftrag): Instanz-Uniform-Reserve ~40 im Fahrzeugbetrieb – neue Modern-Inhalte (AS5a, R6) sollen keine instance uniforms pro Objekt einführen (VPBR_STATIC nutzen); QA prüft das ohnehin über den Engine-Zähler.

## 15.11. 09:55 UTC – QA-M2-SYSTEM fertig, QA_M2_FERTIG gesetzt
- Urteil: kein Blocker, kein hoher Befund; 1 mittel (M2S-01), 6 niedrig. Arcade = v0.7.0 (0 eingefrorene Dateien geändert, ERGEBNIS auf 3 Etappen identisch, Klang-Fingerabdruck identisch).
- FIX-M2 neu gestartet (Agent afdea2b2…, Worktree wf_438996b0-243-5) mit BEIDEN Prüfungen; alter FIX-M2-Start vom 13.11. (nur BILD) war am Wochenlimit gestorben, kein Push.
- Ab jetzt nice 10 für schwere Jobs (Flagge gesetzt).

## 15.11. ~14:10 UTC – m2l FERTIG (FIX-M2 515dd51, NACH-M2: tragfähige Basis)
- FIX-M2 515dd51 (origin/wip/v080-fix-m2): B-03 Blaulicht, B-05 Abblendlicht behoben (Mutationen fangen); B-04 Bremslicht + B-06 Spielerlack teilweise (Tag); M2S-01..07 behoben; Gates: Arcade 20/20 + 17/17, Render 19/19, Modern-Goldens neu (angesehen). merge-tree mit r4/r5/r6: nur modern_slice.{md5,env}.
- NACH-M2: Basis tragfähig; neue Befunde nur niedrig:
  N-01 Bremsschein x2.2 gilt auch nachts (60 m über Arcade) -> Gewinn nach Tageslicht (1-night) skalieren.
  N-02 Waldprüfung mit 20 s belastet das Budget nicht mehr -> Abdeckung "Hoch + voller Verkehr + Wald" wiederherstellen (eigene lange Datei in "all" mit Kopfzeit-Limit, oder Verkehr vorab füllen).
  N-03 SPOT_SPECULAR = 0 nimmt nach R4 auch der nassen Fahrbahn den Glanz -> nur Fahrzeuge (Material) dämpfen, Licht-Glanz zurück. IN RINT-M2 LÖSEN (R4 nasse Fahrbahn).
  N-04 Doku renderer-modern 14.10: vier Testsätze.
- Offen für später: B-04 Sportwagen Bremsband 0,35 m + Mittelbremslicht (Asset), B-06 Sportwagen Dämmerung +14..19 %, B-07 PERF (Verkehrsmodelle in prepare() vorbauen), B-09 Wahrzeichen weich ausblenden (R7), test_modern_checks Bildzahl-Wächter.
- Worktrees wf_438996b0-243-5/-6 entfernt (515dd51 auf origin).

### LEITUNGSENTSCHEIDUNG B-01 (F7-Kurvenkorridor) – gilt ab R7
Grundlage: FIX-M2 bericht.md B-01 (Sehnenstudie, Vorschau T4), A-3/A-10 ("Entscheidung mit den Bildern von ZS2").
- Der Korridor wird aus der WIRKLICHEN Geometrie gerechnet statt als konstantes Band d²/8R über ±L/2:
  Je Reihe und Innenseite = Hülle aller Sichtlinien (Sehnen) der Länge L entlang des tatsächlichen Pfads, Kamera in
  jeder Spur; L(Reihe) = min(300 m, F2-Bedarf an dieser Stelle) (F2-Bedarf wie fairness.speed_profile/modern_sight:
  Anhalteweg bei schnellster fahrbarer Geschwindigkeit / 0,6 + Kameraversatz).
  Folge: Band läuft an Kurvenein-/-ausgang aus, kurze Bögen bekommen die Pfeilhöhe des echten Bogens, Geraden vor
  Kurven (Starteiche S0, B2) werden frei, langsame Bergkurven (T3/T4: 107–119 m) bekommen ihre Bäume zurück.
- Strenge Lesart bleibt (Bäume, Felsen, Häuser – alles, was über 0,5 m ragt); Bodendecker ≤ 0,5 m füllen weiter.
  Gelände nutzt dieselbe Hülle (corridor_width). Stadthäuser in Ortskurven (N3): R7 misst und zeigt Bilder; F2 muss halten.
- Abnahme: modern_sight --full (F1–F3, F7 auf die Hülle umgestellt) grün; Verdeckungssonde T1–T4, C1, S0, S4 (Testauto
  in 3 Spuren 25–270 m) nie schlechter als F2 verlangt; Zählung zurückgekehrter Requisiten je Stelle; A/B-Bilder gegen
  Arcade; Gelände ohne neue Löcher/Nähte.
- Gehört in R7 (dort ohnehin B2 + N3 + props.gd-Tönung).

## 16.11. 02:30 UTC – R6 FERTIG (FIX-R6 2b7dcc0 = origin/wip/v080-fix-r6, NACH-R6: tragfähig)
- QA-R6: B-01 5/48 Grenzdächer ohne rechten Pfeiler (mittel), B-02 Endstützen verdecken ferne Tafeln in Kurven, B-03 Look nachts nicht besser, B-04 Wächter gegen eigene Konstante, B-05 Stadtzäune im Korridor (36 % fehlen), B-08 Perf.
- FIX-R6: B-01 Masten + Zugstangen über der Platte (statt Pfeiler in den Korridor – der würde 36–174 Sichtlinien verdecken, die Arcade frei hat); B-02 echte Sichtlinienprüfung bis 600 m (1109→38 Paare, ≥6 px 195→5); B-03 Tore mit Fachwerk/Flutlicht/weißen Stützen (Tag+Nacht klar besser), Grenzblende nachts heller; B-04 Literale + Mutationen. Gates grün (Arcade 20/20+17/17, Render 21/21, sight/path --full).
- NACH-R6 neu (niedrig): N-01 Endstützen-Entscheid hängt vom Startpunkt ab (fair); N-02 Sichtlinienprüfung im Hauptthread collect() 1,1–6,7 ms/Chunk; N-03 Blende verdeckt Abspannung nah (Seite wirkt stützenlos); N-04 3 Notfall-Endstützen verdecken spielrelevante Tafel (schlimmster Fall Kurvenwarnung 89 % bei 210 m).
- LEITUNG:
  * Abgespannte Grenzdächer (5/48) akzeptiert. Mit der neuen Korridor-Hülle (B-01-Entscheidung, R7) prüft R7, ob Arcades vorderer Pfeiler wieder frei steht; dann Pfeiler statt Mast.
  * N-04 in RINT-M2 beheben: eine Endstütze darf nie eine spielrelevante Tafel (Kurve, Tempo, Ausfahrt, Tankstelle) ≥ 6 px verdecken; an den 3 Notfall-Dächern stattdessen abhängen wie die Grenze.
  * N-02: PERF/Streamer – Sichtlinienprüfung in prepare() oder auf Worker verlegen; Budget für collect() im Vertrag nachtragen (Deck: Hauptthread ≤ 2 ms je Bild).
  * Nachtbild Tankstelle: Modellpaket (A-16) – Shop-Fenster und Lichtband ins Nachtlicht-Atlas.
  * Hinweise an R4 aus FIX-R6 (lights.gd Energie je Lampe, flares.gd role 'on'/energy 0, Doku-Satz) → in RINT-M2.
  * modern_slice.{md5,env}: in RINT-M2 einmal modern-make auf dem gemergten Baum (nach Ansehen).
- R6-Worktrees -1..-4 entfernt.

## 16.11. ~03:00 UTC – RINT-M2 vorbereitet (Start, sobald R4/R5-Workflow wf_fd1de4ee-28b fertig)
- Probe-Merge (trial_rint.sh, merge-tree-Kette auf 515dd51: fix-r4 b156763, fix-r5 80b8141 WIP, fix-r6 2b7dcc0, as5ar1 7153381):
  Code konfliktfrei; Konflikte nur tests/golden/modern_slice.{md5,env} und docs/renderer-modern.md (R5).
- Vertrag §11.3 Entwurf: m1/lead/contract_11_3.md (A-17 Korridor-Hülle, A-18 Bauten/collect()-Budget/Eigentum,
  A-19 Instanz-Uniforms + Modell-Tönung, A-20 Nachtlicht, A-21 Plan inkl. Flacker-Pause, A-22 Stadtgebäude/Flanken).
  RINT-M2 committet ihn wörtlich als ersten Schritt nach den Merges.
- Skript: wf_m4_rint.js = m4_meta.js + c1_head.js + m4_body.js (Trockenlauf dryrun7 ok, beide Modi, keine ${}/undefined).
  Args: {base: 515dd51…, r4: <FIX-R4/NACH-R4-Kopf>, r5: <FIX-R5-Kopf>, r6: 2b7dcc0…, as5a: 7153381…, r4open, r5open}.
  Ablauf: RINT-M2 → QA-RINT-BILD ∥ QA-RINT-SYSTEM → FIX-RINT → NACH-RINT. Branches wip/v080-rint-m2, wip/v080-fix-rint.
- AS5aR1-Vertragsfrage (Flankenöffnungen aus Generator-Mitteln) → genehmigt in A-22. Gebäude-Überblendung + max_dist_m → R7.
- Danach: R7 (A-17 Korridor, Wahrzeichen/Skyline/Fern-LOD, Gebäude-Überblendung, AS5a2-Merge, N1/N2/N3, B2,
  Fernstreifen) → QA-mid → ZS2.

## 16.11. ~03:30 UTC – Welle 3 komplett, RINT-M2 GESTARTET
- R4/R5-Workflow fertig: FIX-R4 b156763 (NACH-R4: tragfähig; offen GT silber nachts/Regen, Laternen-Profil je Bild, Laternen-Spiegelung ohne Prüfung),
  FIX-R5 80b8141 (NACH-R5: tragfähig; QR5-02/03/04/08 liegen in R4-Dateien → RINT-M2 Punkt 11).
- Vertrag §11.3 A-18 ergänzt: Brückengeländer je Typ = Eigentümer roadside.gd; Tunnellicht über tunnel_state.light/exit_z.
- RINT-M2: Workflow wp48kf273, Lauf wf_9927a373-337, Skript wf_m4_rint.js, args = args_m4.json.
  Resume: Workflow({scriptPath: wf_m4_rint.js, resumeFromRunId: 'wf_9927a373-337', args: <args_m4.json>}).
- Worktrees wf_fd1de4ee-28b-1..8 entfernt (alles auf origin). AS5a2 läuft weiter (wf_db8ba6cd-508), danach KRITIK-5a2 → AS5aR2.
