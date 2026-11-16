# Bericht R6 – Tankstelle, Grenze, Stadt, Start/Ziel, Blitzer (v0.8.0 „Modern“, Welle 3)

- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1`
- Branch: `worktree-wf_3b3101bc-877-1`, Sicherung `origin wip/v080-r6` (nach jedem Commit gepusht, nie erzwungen)
- Basis: `6e48405` (M2ZS1); Code-Kopf `bb38876`, Gate-Kopf `c8b18d1` (nur die Modern-Änderungsmelder kamen dazu)
- Entstanden in vier Läufen (drei Neustarts von Container bzw. Nutzungsgrenze); der Code ist seit `bb38876` eingefroren,
  der letzte Lauf hat Änderungsmelder, Gates, Clips, Leistungsmessung und diesen Bericht fertig gemacht.

**Wie die Angaben zu lesen sind.** „gemessen“: auf dieser VM gelaufen (headless bzw. Mesa llvmpipe unter Xvfb, Last
der Maschine 15–26, alle schweren Läufe einzeln mit `nice -n 19`, ab 10:12 am 15.11. – `QA_M2_FERTIG` lag – mit
`nice -n 10`), mit dem Stand, der dabeisteht. „gefolgert“: aus Code, Daten oder Bildern geschlossen, nicht gemessen. Über echte Grafikkarten und das
Steam Deck sagt der Bericht nichts (die Deck-Bilder sind die Voreinstellung „deck“ auf llvmpipe).

## 0. Kurzfassung

Modern hat jetzt alle Bauten, die Arcade an der Strecke zeigt: echte Tankstelle (Insel, Dächer mit Blende, Stützen,
Preissäule, AS1b-Zapfsäulen und -Gebäude), Grenzstation (Dach, Blende mit Landesnamen, Pfeiler, Häuschen), Stadt
(Laternen alle 33 m im Wechsel mit Lichtkegeln, Zäune/Hecken/Mauern, Zebrastreifen-Daten), Start- und Zieltor mit
Countdown-Lampen und Banner, Blitzer mit Blitz. Jede Schrift ist eine vorgezeichnete Tafel, kein `Label3D`. Alle Gates auf
`c8b18d1` grün bis auf drei Echtzeit-Audioprüfungen, die bei dieser Last auf der unveränderten Basis genauso rot sind;
Arcade bildgleich (20/20, 17/17). Urteil: bei Tag klar besser (Tankstelle, Grenze, Stadt), bei Nacht gleich bis
besser – außer der Tankstelle bei Nacht (anders, nicht besser); Start/Ziel und Blitzer gleichwertig, kein sichtbarer
Gewinn. Das Grenzdach auf DEV steht rechts ohne Pfeiler (F1/F7, Vertragsfrage 6.2 Nr. 1).

## 1. Was geliefert ist

| Teil | Datei | Stand |
|---|---|---|
| Tankstelle: Insel mit gelbem Bordstein, Vorplatz, Dach mit Blendenbändern (Fuge, Abdeckung), Unterseite mit Randstreifen, Stützen mit Sockel (nie vor einem Schild), Aufbauleuchten, Stirnblende „TANKSTELLE“ als Schrifttafel, Preissäule (Fundament, Mast, Tafel mit Piktogramm und Preisen), bei Nacht Arcades warmer Schein vor dem Gebäude; Zapfsäulen und Shop sind AS1b-Modelle des Props-Builders | `scripts/race3d/builders/station.gd` (neu geschrieben) | fertig |
| Gemeinsame Hilfsklassen der fünf Builder: `Kit` (vpbr-Ecken), `PanelBuf`, `PanelAtlas`/`PanelCanvas` (vorgezeichnete Schrifttafeln mit Arcades `SignPainter`, Tag- und Nachtbild) | `station.gd` (innere Klassen, per `preload`) | fertig |
| Grenze: Dach über die ganze Straße, Stirnblende mit Europaflagge und Landesname (Schrifttafel), Pfeiler nach `pillar_plan` (F1/F7), Aufbauleuchten, Lichtkegel wie Arcade | `scripts/race3d/builders/border.gd` (neu) | fertig |
| Stadt: Straßenlaternen alle 33 m im Seitenwechsel als Modell `props/streetlight` (MultiMesh, links gespiegelt) mit Lichtkegeln über `renderer.add_lamps()`, Zäune/Hecken/Mauern/Gitter aus den Szenerie-Regeln (nicht in Sichtschneisen, F7), Zebrastreifen-Daten | `scripts/race3d/builders/city.gd` (neu) | fertig |
| Start- und Zieltor: Stützen, Bannertafel wie Arcades `SignPainter._gantry` (Schrifttafel, nie Label3D, bei Nacht leuchtend wie Arcades), Countdown-Lampen in Gehäusen nach Arcades Regel | `scripts/race3d/builders/gantry.gd` (neu geschrieben) | fertig |
| Blitzer: Blitz am Kamerakopf über die Ebene `flares` (Rolle „on“, folgt `view.radar_flash01`); Pfosten und Kamera sind das AS1b-Modell `props/radar_camera` | `scripts/race3d/builders/radar.gd` (neu) | fertig |
| Unit-Tests (10) | `tests/unit/race3d/test_structures.gd` | grün auf `c8b18d1` (10 von 10) |
| Render-Prüfung (7 Prüfungen) | `tests/race3d/render/check_structures.gd` | grün auf `c8b18d1` (countdown, zieltor, grenze, blitz, tankstelle, stadt, schatten; Abschnitt 3) |
| Doku | `docs/renderer-modern-bauten.md` (neu) | fertig |
| Fremde Datei (Abweichung 6.1) | `tests/race3d/check_minimal_structures.gd`: Schriftzüge über die Debug-Liste `letterings` statt Label3D | geändert, 2 Stellen |

Keine eingefrorene Arcade-Datei geändert. Kein Code nennt eine Klasse eines anderen Pakets dieses Push; Ebenen
werden über die Fassade (`renderer.add_lamps`, `ctx.services`, `has_method`) erreicht. `props.gd` brauchte keine
Änderung: es lässt die „object“-Einträge (Laternen) schon selbst aus, sobald ein Builder „city“ registriert ist.

## 2. Abnahme Punkt für Punkt

### 2.1 Vertrag §6 R6

| Nr. | Punkt | Ergebnis | Beleg |
|---|---|---|---|
| V1 | Ausgaben nach Inventar B/C: Tankstelle, Grenze, Stadt (Laternen, Zäune, Zebrastreifen-Daten), Start/Ziel, Blitzer | erfüllt | Abschnitt 1; Unit-Tests je Builder; Bilder Abschnitt 4 |
| V2 | Schrift über vorgezeichnete Tafeln (SignAtlas-Art) | erfüllt | `PanelAtlas` zeichnet „TANKSTELLE“, die Preistafel, die Grenzblenden und die Torbanner einmal in `prepare()` mit Arcades `SignPainter` (Tag- und Nachtbild); kein `Label3D` im ganzen R6-Code (`grep`), Render-Prüfung `tankstelle` zählt 0 Label3D im Baum (gemessen); `test_panel_atlas_layout` |
| V3 | A/B-Bögen jedes Elements auf DEV | erfüllt | fünf Bögen (Tankstelle, Grenze, Stadt, Start/Ziel, Blitzer), je Tag und 21 Uhr, Arcade links, Modern „Hoch“ rechts, gleicher Simulationszustand (`tools/ab_shot.sh`, gemessen); dazu Einzelbilder 01–22 mit Deck-Voreinstellung (Abschnitt 4); alle angesehen, Urteil Abschnitt 5 |
| V4 | Tanken, Polizeistopp, Blitz, Countdown-Lampen, Zielbanner im Clip | erfüllt | vier A/B-Clips mit 60 Bildern/s (Abschnitt 4): `clip_countdown_los.mp4`, `clip_tanken_km15.mp4`, `clip_blitz_polizei.mp4` (Blitz und Polizeistopp), `clip_ziel.mp4`; alle angesehen (Bildauszüge), 0 Skriptfehler |
| V5 | Geometrie der Tankspur = `Track.fuel_lane_*` | erfüllt | `test_station_on_the_fuel_lane_of_the_slice_stage` (gemessen, Kiel – Hamburg km 13,5–15): jedes Inselsegment nur neben der ganz offenen Spur (`fuel_lane_factor` = 1), Kante = `road_edges_at().y` auf 1 mm, Spurmitte = `fuel_lane_x()` + halbe Spur auf 1 mm, `fuel_lane_at()` wahr, Bordstein-Ecke bei Kante + 0,35 m im Netz gefunden |
| V6 | Laternen alle 33 m im Seitenwechsel mit Lichtkegeln | erfüllt | `test_city_lights_every_33_m_alternating_with_pools` (gemessen, DEV-Stadt): Abstände 33 m, Seiten wechseln, jede Laterne mit Lampe (Rolle „street“, Reichweite 9 m, Stärke 1,0 = Arcades 0,55 × `lights` in der Mitte); Render-Prüfung `stadt` (Abschnitt 3) |

### 2.2 Entscheidungen der Leitung

| Nr. | Entscheidung | Ergebnis | Beleg |
|---|---|---|---|
| L1 | Echte Tankstelle (Shop, Preissäule, Dachdetails, AS1b-Zapfsäulen und -Shop); Tankspur = `Track.fuel_lane_*`; Tanken bei Kiel – Hamburg km 15 im Clip; nichts verdeckt die Einfahrt (F1) | erfüllt | Abschnitt 1; V5; `clip_tanken_km15.mp4` (Tutorial-Stopp: Halt in der Spur, 18 L, Ausfahrt durch die Station, gleich wie Arcade); Einfahrt frei: Stützen nie vor einem Schild (`test_station_columns_never_in_front_of_a_sign`), Render-Prüfung `tankstelle` (Blende 44 m voraus sichtbar); Bilder 03–07, 20; bei Nacht nicht besser als Arcade (Abschnitt 5) |
| L2 | Grenze: Dach, Blende mit Landesnamen, Häuschen (AS1b), Schranke/Haltelinie nur wo Arcade sie hat; Polizeistopp im Clip | erfüllt, mit Vertragsfrage | Dach, Blende (Europaflagge + Landesname als Tafel), Pfeiler, Häuschen `props/customs_booth`; Arcade hat weder Schranke noch Haltelinie – Modern auch nicht; `test_border_station_of_the_test_stage`, Render-Prüfung `grenze`; Bilder 08–10, 21; Polizeistopp in `clip_blitz_polizei.mp4` (er folgt im Spiel auf den Blitz, nicht auf die Grenze, 6.2 Nr. 5); DEV-Dach rechts ohne Pfeiler (6.2 Nr. 1) |
| L3 | Stadt: Laternen alle 33 m im Wechsel mit Kegeln über `renderer.add_lamps()` (`layers/lights.gd` unberührt), Zäune/Hecken/Mauern, Zebrastreifen-Daten; Gebäude gehören AS5a | erfüllt | V6; `lights.gd` nicht geändert (`git diff 6e48405 --stat`); Zäune: `test_city_fences_stay_out_of_bend_corridors` (gemessen: in einer engen Stadtkurve fallen ≥ 60 von 320 Stücken in der Sichtschneise weg, der Rest steht); Zebrastreifen-Daten nach der Regel von `road.gd` (Unit-Test); keine Gebäude in `city.gd` |
| L4 | Start/Ziel: Countdown-Lampen und Zielbanner im Clip; `check_start_km0` und `check_light_base` bleiben grün; das Auto steht wo in Arcade | erfüllt | `clip_countdown_los.mp4`, `clip_ziel.mp4`; `check_start_km0` OK (Auto 193×193 bei (544, 470) gegen Arcade 192×192 bei (544, 471)), `check_light_base` OK, Render-Prüfungen `countdown` und `zieltor` OK (alle auf `c8b18d1`, gemessen) |
| L5 | Blitzer: Pfosten und Kamerablitz, Blitz im Clip sichtbar | erfüllt | Pfosten und Kamera = AS1b `props/radar_camera`, Blitz über die Ebene `flares` am Kamerakopf; Render-Prüfung `blitz` OK (am Kopf 10 % weiß, Leuchtdichte 0,88 gegen 0,44 davor); `clip_blitz_polizei.mp4` bei 0:00,37–0:00,6 |
| L6 | Schrift über vorgezeichnete Tafeln, nie Label3D (auch „TANKSTELLE“) | erfüllt | V2 |
| L7 | F1 (nichts zeigt ein Auto oder Schild später oder kleiner als Arcade) und F7 (nichts in der Sichtschneise einer Kurve) | erfüllt, mit Folge (6.2) | Dächer: über Fahrbahn und Spur nichts unter Arcades Dachhöhe (Unit-Tests über alle Ecken: Tankstelle 5,6 m, Grenze 6,0 m, nur die Leuchtenkästen 6 bzw. 10 cm darunter). Pfeiler und Stützen: `pillar_plan`/`column_plan` – keiner kann ein Schild verdecken (Unit-Tests auf DEV und Hamburg – Hannover, gemessen: jede Tafel hinter einem Pfeiler endet innerhalb seiner Innenseite), außer Arcades vorderen nie in einer Sichtschneise; Zäune nicht in Sichtschneisen. Gefunden im eigenen Bild `v2_border_day`: der rechte Grenzpfeiler verdeckte auf DEV halb das Schild „Tankstelle 15 km“ – behoben (`2d80276`, `3e286d3`, `a625d93`) |

## 3. Prüfungen – was auf welchem Stand lief

Kopf: `c8b18d1` (Code `bb38876` + Modern-Änderungsmelder), Worktree sauber. Alle Läufe einzeln, `nice -n 19` (bzw. 10, sobald `QA_M2_FERTIG` lag), eigenes absolutes
`XDG_DATA_HOME` je Lauf, Mesa llvmpipe unter Xvfb, Last der Maschine 18–26 (gemessen mit `uptime`).

| Lauf (Befehl) | Stand | Ergebnis (gemessen) |
|---|---|---|
| `godot --headless --path . --import` | `c8b18d1` | Exit 0, 15 s, 0 Fehlerzeilen |
| `godot --headless --path . -s res://tests/check_scripts.gd` | `c8b18d1` | 316 Skripte geprüft, 0 fehlerhaft (20 s) |
| `tools/run_tests.sh` (ganzer Lauf 1 von höchstens 2) | `c8b18d1` | 1689 s, Last 25; **759 Tests, 3 fehlgeschlagen** – nur die drei Echtzeit-Audioprüfungen „im laufenden Spiel“ (`test_engine3_checks :: test_engine_thread_in_a_running_game`, `test_modern_checks :: test_profiles_in_a_running_game_with_playback`, `test_music_checks :: test_music_in_a_running_game`); alle übrigen Schritte grün, darunter `test_structures.gd` 10/10, `test_props.gd` 12/12, `test_far_ground_water.gd` 4/4, `check_minimal_structures` (`CHECK station OK`, `CHECK tore OK`), `modern_sight` (Standard) OK |
| `tools/run_tests.sh <datei>` je Audioprüfung, Kopf **und** Basis-Kopie `6e48405`, je allein (Last 18–19, `nice 19`) | `c8b18d1` / `6e48405` | Kopf: engine3 2/2 OK, modern_checks 1 FAIL, music_checks 1 FAIL; **Basis: engine3 2/2 OK, modern_checks 2 FAIL, music_checks 1 FAIL** – gleiche Prüfungen rot ohne eine Zeile R6-Code, bei wechselnden Teilgründen (Ducking-Pegel, Musik-Fader, Sitzungsbilder): lastabhängig, nicht R6 (gemessen) |
| `tools/golden.sh check` | `c8b18d1` | Exit 0, 898 s: **GOLDEN arcade: 20 von 20 identisch**, **GOLDEN arcade-ui: 17 von 17 identisch** |
| `tools/golden.sh modern-check` (Bilder behalten) | `c8b18d1` | Exit 0, 1868 s: **GOLDEN modern: 6 von 6 identisch**; **modern-gles** `modern_s3_hoch` OpenGL ES gegen OpenGL OK (max. 2/255, PSNR 73,2 dB) |
| `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | `c8b18d1` | Exit 0, 155 s: f1 0 Fälle bis 270 m (128 Etappenrichtungen, 99 424 500 Stichproben), f1_lanes OK, f2 ≤ 0,596, f3 0 von 5923 Zielen später als Arcade, f7 0 von 2 011 532 Querschnittsseiten, model 0 abweichend |
| `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | `c8b18d1` | Exit 0, 61 s: clearance kleinster Abstand 267,6 m (≥ 250), loops frühestens nach 2064 m (≥ 2000) |
| `tools/run_render_checks.sh all` – je Datei-Gruppe ein Aufruf (`arcade`, dann `modern <filter>`), damit kein Hintergrundjob (2 h) mitten in einer Datei abbricht; `RENDER_CHECK_TIMEOUT=2400` | `c8b18d1` | **21 von 21 Dateien OK**: Arcade `check_glow_occlusion` (105 s), `check_sprite_flip`; Modern `facade_render`, `instance_budget` (302 s), `instance_budget_wald` (2310 s), `light_base` (223 s), `models`, `modern_render` (688 s), `occlusion`, `props_render`, `quit_sound`, `road_parity`, `seam_render` (422 s), `session_modern`, `showroom_render`, `start_km0` (428 s), **`structures` (675 s) und `structures_licht` (269 s)**, `terrain_cover` (139 s, T1–T4, S1, C1, **K1** 0,000 % Magenta), `vehicle_lights`, `vehicle_standin` |

### 3.1 Leistung: ganzer Modern-Lauf mit allen R6-Bauten, Kopf gegen Basis

Ganzer Autopilot-Lauf DEV (`tests/race/run_stage.gd -- --stage=dev_testetappe --from=dev_start --hour=21 --weather=normal
--vehicle=limousine --seed=7 --timescale=40 --graphics=modern`), unter Xvfb mit Mesa llvmpipe (`bin/perf.sh`), Kopf
`c8b18d1` gegen Basis-Kopie `6e48405`, je Voreinstellung direkt nacheinander, Last 15–20, `nice 10` (gemessen). Alle vier
Läufe: 130 km ins Ziel, 0 Kollisionen, 0 Skriptfehler. Die Etappe hat alle R6-Bauten (Start, zwei Tankstellen, Blitzer,
Tunnel, Grenze NL, City Limits mit Laternen, Ziel), 21 Uhr = Nachtlicht.

| Wert (`perf_stats`) | Kopf „Mittel“ | Basis „Mittel“ | Kopf „deck“ | Basis „deck“ |
|---|---|---|---|---|
| `render()` ms Mittel | 8,14 | 7,68 | 8,58 | 8,22 |
| `render()` ms max | 146,0 | 131,8 | 347,2 | 145,3 |
| Chunk-Commit ms max (Hauptthread) | 5,9 | 26,9 | 5,6 | 95,5 |
| Chunk-Bau ms Mittel / max (Worker-Thread) | 12,1 / 235,0 | 8,5 / 97,6 | 10,1 / 231,6 | 7,8 / 124,8 |
| Draw Calls (letztes Bild, Ziel) | 89 | 82 | 83 | 77 |
| Primitive (letztes Bild) | 75 885 | 75 885 | 75 885 | 75 885 |
| Schatten-Primitive (letztes Bild) | 13 752 | 7 998 | 8 316 | 3 384 |
| Bildzeit Median / p95 ms (llvmpipe, Zeitraffer 40) | 1239 / 2324 | 1189 / 2053 | 1165 / 2080 | 1137 / 1979 |
| Instanzen mit Instanz-Uniforms | 63 | 102 | 63 | 102 |
| Hooks `gantry` / `radar` ms Mittel | 0,012 / 0,011 | 0,024 / – | 0,010 / 0,006 | 0,009 / – |

Lesart: `render()` im Mittel +0,4 ms (+5–6 %), die Commits im Hauptthread bleiben klein (max 5,9 ms gegen 26,9 bzw. 95,5 ms
der Basis – Rauschen der Last, nicht besser durch R6); der Chunk-Bau im Worker-Thread wird im Mittel 2,3–3,5 ms teurer
(Inseln, Dächer, Laternen, Zäune werden gebaut) und hatte je einen Ausreißer um 230 ms – er läuft neben dem Bild, nicht
in ihm. Das eine `render()`-Maximum 347 ms (Kopf, deck) steht einzeln bei einer Last von 19; mit nur einem Lauf je Stand
lässt es sich weder R6 zuschreiben noch ausschließen. Die Dächer und Tore werfen auf „Mittel“ Schatten: +5 754
Schatten-Primitive im letzten Bild (Zieltor). Auf echter Hardware (Steam Deck, Windows-GPU) ist nichts davon gemessen –
gefolgert: +7 Draw Calls und ~6 000 Schatten-Dreiecke sind dort vernachlässigbar, der teurere Chunk-Bau trifft nur den
Worker-Thread.

### 3.2 Render-Prüfung der Bauten während der Arbeit

(gemessen, `bin/rc_structures.sh`, `nice 19`, Last ~21; der Endstand steht oben in der Gate-Tabelle):

| Lauf | Stand | Ergebnis |
|---|---|---|
| 1 – alle sieben in einer Datei | `8ddbeca`/`2d80276`-Arbeitsstand | 1205 s; `countdown` OK (Schritt 70: [rot, rot, aus], 205: [grün ×3], 330: [aus ×3]), `zieltor` OK (rot 50 %, weiß 7 %, schwarz 4 %), `grenze` OK (12 Uhr weiß 63 %, blau 20 %; 21 Uhr hellster Bildpunkt der Lichtbänder 1,00), `stadt` OK (Kegel Modern 0,490, Arcade 0,501), `schatten` OK („Mittel“ 4 von 4 Bau-Knoten werfen, „Aus“ 0 von 4); **`tankstelle` FEHLER** (die Blende des zweiten Dachs lag hinter dem ersten: weiß 15 %) und **`blitz` FEHLER** (am Kopf nur +0,17 Leuchtdichte) |
| 2 – `blitz` | `a625d93` (Blitz ausgeglichen) | +0,44 Leuchtdichte, 10 % weiß – Schwelle danach auf Arcades weichen Schein gesetzt (`5dc28f2`) |
| 2 – `tankstelle` | `a625d93` (40 m vor dem ersten Dach) | OK: 12 Uhr Blende 44 m voraus, weiß 33 %, blau 5,9 %; 21 Uhr Blende 0,55, Tankspur Modern 0,414 gegen Arcade 0,459 (0,90 ×) |

## 4. Bilder und Clips

Alle Bilder: links Arcade, rechts Modern („Hoch“, die Deck-Bilder „deck“ bei 1280 × 800), 1280 × 720 je Hälfte, Mesa
llvmpipe unter Xvfb, `tools/ab_shot.sh` mit gleichem Startpunkt, Saat und Verkehr (gemessen). Stand je Bild in der
Tabelle. Die Bögen zeigen je Element auf DEV Tag und 21 Uhr untereinander.

| Datei | Inhalt | Stand | Urteil |
|---|---|---|---|
| `01_kh_start_tag_los.jpg` | Kiel – Hamburg km 0, 12 Uhr, 0,6 s nach „LOS!“: Starttor mit drei grünen Lampen | Arbeitsstand 15:40 (vor `953f1bc`: Lampenschein seitdem Arcades 1,4 m; der Clip zeigt den Kopf) | gleich: Banner = Arcades Tafel, Stützen echt; Auto steht wie in Arcade |
| `02_kh_ziel_tag.jpg` | Kiel – Hamburg km 94,3, 12 Uhr: Zieltor „ZIEL“ in der Ferne | Arbeitsstand 16:10 (bei Tag wie Kopf) | gleich |
| `03_kh_tankstelle_km15_tag.jpg` | Kiel – Hamburg km 13,5, 12 Uhr: Preissäule und Tankstelle vor der Einfahrt | Kopf-Code | gleich bis besser (Säule mit Mast und Fundament, Dächer echt); „LOS!“ des HUD liegt in der Mitte |
| `04_kh_tankstelle_km15_nacht.jpg` | dieselbe Stelle um 21 Uhr: Preistafel leuchtet, die Station dahinter hell | Kopf-Code | gleich; „LOS!“ des HUD liegt über der Station |
| `05_kh_tankstelle_unter_dem_dach_nacht.jpg` | Kiel – Hamburg km 14,8, 21 Uhr, an der Tankstelle vorbei: beleuchtete Unterseiten, Leuchtfelder, Gebäude mit grünem Band | Kopf-Code | gleich bis besser (Tiefe); Arcades warmer Schein des Gebäudes ist in Modern schwächer |
| `06_dev_tankstelle_tag.jpg` | DEV km 19,6, 12 Uhr: Dächer mit Blende, Stützen mit Sockel, Zapfsäulen und Gebäude (AS1b), Preissäule | Kopf-Code | besser: Tiefe, Stützen, Modelle |
| `07_dev_tankstelle_nacht.jpg` | DEV km 19,6, 21 Uhr: Dächer mit beleuchteter Unterseite und Leuchtfeldern, Stirnblende hinterleuchtet, Gebäude rechts | Kopf-Code | anders, nicht besser: Arcades Station strahlt als Ganzes warm (Schein des Gebäude-Sprites); in Modern liegt das Gebäude-Modell (AS1b) weiter rechts und weniger hell |
| `08_dev_grenze_tag.jpg` | DEV km 64,9, 12 Uhr: Grenze NL, „Tankstelle 15 km“ unter dem Dach jetzt frei (vorher halb vom Pfeiler verdeckt) | Kopf-Code | besser in der Tiefe, aber rechts ohne Pfeiler (Rechtskurve: Sichtschneise, F7) – das Dach wirkt dort ungestützt |
| `09_dev_grenze_nacht.jpg` | dieselbe Stelle um 21 Uhr: Lichtbänder, Blende hinterleuchtet, Häuschen mit warmen Fenstern | Kopf-Code | gleich bis besser |
| `10_prag_nuernberg_grenze.jpg` | Prag – Nürnberg km 160 (nächste Grenze zu Kiel – Nürnberg, dessen Strecke ganz in Deutschland liegt), 15 Uhr: „DEUTSCHLAND“, vier Pfeiler (rechts hinten außen, hinter ihm steht „Tempolimit aufgehoben“), Lichtbänder, Häuschen | Kopf-Code | besser: echtes Dach mit Unterseite und Pfeilern, Schild frei |
| `11_dev_blitzer_tag_blitz.jpg` | DEV km 12,0, 12 Uhr, im Blitz (HUD-Weiß in beiden Modi): weißer Schein am Kamerakopf rechts | Kopf-Code | gleich |
| `12_dev_blitzer_nacht_blitz.jpg` | DEV km 12,0, 21 Uhr, im Blitz (HUD-Weiß über dem ganzen Bild in beiden Modi): Kamerakopf leuchtet weiß | Kopf-Code | gleich |
| `13_dev_stadt_tag.jpg` | DEV km 111,5, 12 Uhr: Laternen mit Mast und Ausleger im Wechsel, Hecken entlang der Gehwege | Kopf-Code | besser (Tiefe, Hecken als Körper) |
| `14_dev_stadt_nacht.jpg` | DEV km 111,6, 21 Uhr: Laternen mit Ausleger, warmer Schein am Kopf, Kegel auf Straße und Gehweg | Stand 16:06 (`city.gd` seitdem unverändert) | besser (Render-Prüfung `stadt`: Kegel 0,490 gegen Arcade 0,501) |
| `15_kh_stadt_nacht.jpg` | Kiel – Hamburg km 76,6, 21 Uhr: Ankunft in Hamburg, Laternen, Hecken, Elbphilharmonie in der Ferne | Kopf-Code | gleich bis besser |
| `16_dev_start_tag_countdown.jpg` | DEV km 0, 12 Uhr, Countdown „3“: erste Lampe rot | Kopf-Code | gleich (Banner = Arcades Tafel); Auto wie in Arcade |
| `17_dev_start_nacht_countdown.jpg` | DEV km 0, 21 Uhr, Countdown „3“: „START“ und Streifen leuchten, erste Lampe rot | Kopf-Code | gleich (Schrift heller als Arcades) |
| `18_dev_ziel_tag.jpg` | DEV km 129,6, 12 Uhr: Zieltor in der Stadt | Kopf-Code | gleich |
| `19_dev_ziel_nacht.jpg` | DEV km 129,9, 21 Uhr: Zielbanner leuchtet (Nachtbild der Tafel; vorher fast schwarz) | Kopf-Code | gleich; das Rot etwas dunkler, die Stützen dunkler als Arcades weiße |
| `20_deck_tankstelle_nacht.jpg` | „deck“, 1280 × 800 (Modern füllt 16:10, Arcade mit Balken): DEV-Tankstelle 21 Uhr | Kopf-Code | gleich bis besser |
| `21_deck_grenze_tag.jpg` | „deck“: DEV-Grenze von weitem, 12 Uhr | Kopf-Code | gleich; rechts kein Pfeiler (Sichtschneise) |
| `22_deck_stadt_nacht.jpg` | „deck“: DEV City Limits 21 Uhr – Laternen mit Kegeln auf Straße und Gehweg | Kopf-Code | besser |

Bögen (je Element auf DEV, Tag oben, 21 Uhr unten, jede Zeile ein A/B-Paar): `bogen_dev_tankstelle.jpg`,
`bogen_dev_grenze.jpg`, `bogen_dev_stadt.jpg`, `bogen_dev_start_ziel.jpg`, `bogen_dev_blitzer.jpg`.

„LOS!“ und Tipps des HUD liegen in einigen Bildern über der Mitte (Start ohne Countdown, Tutorial-Tipps auf
Kiel – Hamburg) – in beiden Modi gleich, nicht vom Renderer.

Clips (`tools/ab_clip.sh`, Movie Maker mit festen 60 Bildern/s, links Arcade, rechts Modern, ohne Ton):

| Datei | Inhalt (Argumente) | Stand | Was zu sehen ist (angesehen) |
|---|---|---|---|
| `clip_countdown_los.mp4` (8 s) | Kiel – Hamburg km 0, 12 Uhr, Countdown mit LOS („Mittel“) | `bb38876` | 3 → 2 → 1: erste, zweite, dritte Lampe rot, bei „LOS!“ alle drei grün – in beiden Modi im selben Bild; das Auto steht in Modern wo in Arcade (Render-Prüfung `start_km0`: ±2 px); nach LOS fährt es unter dem Banner „START“ durch |
| `clip_tanken_km15.mp4` (30 s) | Kiel – Hamburg ab km 13,62 mit 90 km/h, `--autopilot-refuel=always --fuel=0.7` (Tutorial-Stopp der Etappe, „Mittel“) | `c8b18d1` | Einfahrt in die Tankspur, Halt bei km 13,9, „Volltanken?“ mit Fortschritt, „Vollgetankt – 18 L“ bei 0:14,5, Ausfahrt an Inseln, Zapfsäulen, Dächern mit „TANKSTELLE“ und Gebäude vorbei; Ablauf in beiden Modi bildgenau gleich (gleiche Simulation), nichts verdeckt die Einfahrt |
| `clip_blitz_polizei.mp4` (32 s) | DEV ab km 11,85 mit 150 km/h, `--autopilot-speeding --autopilot-target=150` („Mittel“) | `c8b18d1` | Blitz bei 0:00,37 (Bild 23): HUD-Weiß in beiden Modi, danach in Modern ein weißer Schein am Kamerakopf rechts (bis ~0:00,6 zu sehen; in Arcade ist der Schein am fernen Pfosten kaum zu erkennen), „Geblitzt! Die Polizei ist hinter dir her!“; Verfolgung, bei 0:18,5 an der Tankstelle km 19,6 vorbei (Dächer, Säulen, Gebäude), Polizeiwagen überholt, „Polizei! Rechts ranfahren!“ bei 0:21, Halt, „Führerschein, bitte!“ ab 0:24 bis zum Ende – Ablauf in beiden Modi gleich |
| `clip_ziel.mp4` (8 s) | Kiel – Hamburg ab km 94,2 mit 100 km/h, 12 Uhr („Mittel“) | `c8b18d1` | Zieltor „ZIEL“ ab 0:01,5 in der Ferne zwischen den Hamburger Häusern, bei 0:02,45 unter dem Banner durch und über die Zielschachbrett-Linie, Zielanzeige des HUD, Ausrollen bis zum Stand am Zebrastreifen; Ablauf in beiden Modi gleich, Banner = Arcades Tafel |

Alle Clips ohne Skriptfehler in beiden Läufen (Logs `m1/R6/shots/clip_*_{arcade,modern}.log`). Standbilder aus jedem Clip (links Arcade, rechts Modern): `clipauszug_countdown_los.jpg` (1 Bild/s), `clipauszug_tanken_km15.jpg`, `clipauszug_blitz_moment.jpg` (Bilder 21, 22, 29, 36 um den Blitz), `clipauszug_blitz_polizei.jpg`, `clipauszug_ziel.jpg`. Der Ziel-Clip lief zweimal: der erste Versuch fiel mit dem 2-h-Limit eines Hintergrundjobs, der zweite (15:14) ist der gelieferte. Die Clips laufen auf „Mittel“ (der
Voreinstellung des Spiels), weil Movie Maker mit llvmpipe auf „Hoch“ für 8 s Countdown 1132 s brauchte (gemessen).

## 5. Urteil: Modern gegen Arcade

Gegen das Arcade-Bild desselben Simulationszustands (Abschnitt 4), ehrlich:

- **Tankstelle bei Tag – klar besser.** Echte Dächer mit roten und weißen Blendenbändern (Fuge, Abdeckung),
  Stützen mit Sockel, Insel mit gelbem Bordstein, Zapfsäulen und Gebäude als Modelle, Preissäule mit Tafel,
  „TANKSTELLE“ in Arcades Schrift. Die Einfahrt ist frei.
- **Tankstelle bei Nacht – anders, nicht besser.** Leuchtfelder, beleuchtete Unterseiten, hinterleuchtete Blende und
  die Kegel auf der Spur sind da (Spur 0,90 × Arcade, gemessen). Arcades Station strahlt aber als Ganzes warm –
  das ist vor allem das Nachtbild des Gebäude-Sprites; das AS1b-Gebäude steht in Modern weiter rechts (Anker der
  Props) und leuchtet schwächer. Arcades Schein vor dem Gebäude habe ich nachgebaut; er ändert wenig.
- **Grenze bei Tag – besser in Tiefe und Detail** (Dach mit Unterseite und Leuchten, Häuschen als Modelle,
  Prag – Nürnberg mit vier Pfeilern klar besser). **Auf DEV fehlt rechts jeder Pfeiler**: Schilder unter dem Dach
  und die Sichtschneise der Rechtskurve lassen keinen zu (F1/F7) – das Dach wirkt dort ungestützt.
- **Grenze bei Nacht – gleich bis besser:** Lichtbänder wie Arcade, Blende hinterleuchtet, Häuschen mit warmen
  Fenstern; die Straße unter dem Dach ist heller als in Arcade (0,240 gegen 0,161, gemessen im Bild v2).
- **Stadt – besser:** Laternen mit Mast und Ausleger, Kegel so hell wie Arcade (0,490 gegen 0,501, gemessen),
  Hecken und Zäune als Körper.
- **Start und Ziel – gleichwertig, kein sichtbarer Gewinn:** die Banner sind Arcades Tafeln (gleiche Zeichnung),
  die Stützen Stahl statt weißer Balken; nachts leuchten die Banner jetzt wie Arcades (vorher war „ZIEL“ fast
  schwarz – eigener Bildbefund).
- **Blitzer – gleichwertig, im Clip etwas deutlicher:** Kamera als Modell (AS1b), Blitz als weicher weißer Schein wie
  Arcade; im Clip ist der Schein am Kamerakopf nach dem HUD-Weiß in Modern gut, in Arcade kaum zu sehen.
- **Abläufe in den Clips (Tanken, Polizeistopp, Countdown, Ziel) – gleich:** dieselbe Simulation, dieselben Meldungen,
  dasselbe Timing; Modern ändert nichts am Spiel, nur am Bild.

## 6. Abweichungen, Vertragsfragen, Hinweise

### 6.1 Abweichungen

1. **Fremde Datei geändert:** `tests/race3d/check_minimal_structures.gd` zählte die Schriftzüge „TANKSTELLE“ und „ZIEL“
   als `Label3D`-Knoten. Die Leitung verlangt „nie Label3D“ – die Prüfung hätte die verlangte Lösung rot gemeldet. Zwei
   Stellen zählen jetzt die Debug-Liste `letterings` der Builder (`git diff 6e48405 -- tests/race3d/check_minimal_structures.gd`).
   Gemessen: `CHECK station OK`, `CHECK tore OK`.
2. **Neue Doku-Datei** `docs/renderer-modern-bauten.md` statt eines Abschnitts in `docs/renderer-modern.md` (nicht R6s
   Datei); der Verweis dort fehlt (Hinweis 6.3).
3. **Zweite Render-Prüfdatei** `tests/race3d/render/check_structures_licht.gd` (erbt `check_structures.gd`): alle sieben
   Prüfungen in einer Datei brauchten 1205 s (gemessen, Last 21, `nice 19`) – mehr als `RENDER_CHECK_TIMEOUT` (900 s).
4. **Laternen-Stärke 1,0 statt 0,55:** die Ebene `lights` gibt je Stärkeeinheit 0,55 in der Mitte; Arcades Kegel hat
   0,55 × `lights`. Mit der Stärke 0,55 von `PropLibrary.LAMP_ENERGY` (bisher für die Laternen der Props) wären es
   0,30 gewesen. Render-Prüfung `stadt`: Modern 0,490 gegen Arcade 0,501 (gemessen).
5. **Pfeiler und Stützen nicht immer an Arcades Stelle** (F1, Abschnitt 6.2): wo ein Schild dahinter steht, rücken sie
   nach außen und tragen das Dach über einen Träger.
6. **Hellere Dachunterseiten:** Tankstelle `b4b6b5` statt `9a9c9b`, Grenze `aab0b6` statt `8e959c` – Arcade malt sie
   flach beleuchtet, in Modern bekommt die Unterseite nur das Himmelslicht.
7. **Modern-Änderungsmelder neu** (`tests/golden/modern_slice.md5`, `.env`, Commit `c8b18d1`): drei von sechs Bildern
   ändern sich gewollt (Start, Tankstelle km 14,8, Stadt km 80,6), alle neben dem Bild der Basis angesehen
   (`m1/R6/cmp/*_base_head.jpg`); `modern_s3_hoch`, `modern_s5_niedrig` (das Ziel liegt dort schon hinter der Kamera) und
   `modern_s1_nacht` sind bildgleich. R4 und R5 ändern dieselbe Liste – beim Zusammenführen einmal `modern-make` auf
   dem Gesamtstand.
8. **Clip-Argumente:** Tanken mit `--fuel=0.7` (sonst tankt der volle Tank nur ~3 L in 6 s), Polizeistopp mit
   `--autopilot-target=150` (der Autopilot fährt sonst 235 km/h und entkommt der Polizei, die 220 fährt – kein Stopp).

### 6.2 Vertragsfragen (mit Beleg)

1. **F1 gegen Arcades Malreihenfolge bei Pfeilern.** Arcade zeichnet Fahrbahn und Bauten eines Streifens vor dessen
   Schildern; ein Schild, das unter einem Dach steht, liegt im selben Streifen wie der vordere Pfeiler und wird **über**
   ihn gemalt (`RoadRenderer._draw_items`, `_can_merge` verbindet die Dachsegmente). In 3D verdeckt ein Pfeiler davor
   das Schild – Beleg: eigenes Bild `v2_border_day_ab_02.jpg` (DEV km 64,9: „Tankstelle 15 km“ zur Hälfte hinter dem
   rechten Pfeiler, in Arcade ganz zu sehen). Lösung: der Pfeiler rückt jenseits der Tafeln (6.1 Nr. 5). Folge mit F7:
   4 der 48 Grenzdächer stehen nur auf einer Seite (Grenze in einer Kurve, deren Innenseite Sichtschneise ist), darunter
   DEV; Auswertung `bin/border_pillars.gd` (gemessen). Bitte entscheiden, ob ein einseitig getragenes Dach so bleiben darf.
2. **Label3D in einer fremden Prüfung festgeschrieben** (`check_minimal_structures.gd`, 6.1 Nr. 1) – widersprach der
   Entscheidung „nie Label3D“.
3. **Ebene `flares` gibt jeder Lampe mit Kegel und Blick nach unten Arcades warmen Laternenschein** (dir.y < −0,5,
   range > 0). Für die Kegel der Dächer (Tankstelle, Grenze) gibt es keinen Schalter dagegen; Umweg: deren Lampen
   sitzen im Dachkasten, der Tiefentest verdeckt den Schein.
4. **`STATIC_HALO` der Ebene `flares`** gibt einer Lampe, die größer als 6 px ist, nur 35 % ihrer Stärke – richtig für
   Lampen mit leuchtender Geometrie, falsch für einen reinen Schein wie den Blitz (keine Geometrie). Umweg: Stärke / 0,35
   (Render-Prüfung `blitz`: vorher +0,17, danach +0,44 Leuchtdichte am Kopf, gemessen).
5. **Polizeistopp unter „Grenze“:** der Stopp folgt auf einen Blitz (Raser), nicht auf die Grenze; er ist im Clip des
   Blitzers geliefert. Arcade hat an der Grenze weder Schranke noch Haltelinie – Modern auch nicht.
6. **`RENDER_CHECK_TIMEOUT` 900 s** reicht auf dieser VM für Prüfdateien mit vielen Szenenstarts nicht (6.1 Nr. 3).

### 6.3 Hinweise für die Nächsten (genaue Änderungen in fremden Dateien)

1. `docs/renderer-modern.md` §14.4/§14.5: ein Satz mit Verweis auf `docs/renderer-modern-bauten.md` (Bauten an der
   Strecke, R6).
2. `scripts/race3d/layers/flares.gd` `add_static()`: zwei optionale Schlüssel je Lampe – `"glow": false` (kein
   Laternenschein für Kegel-Lampen von Dächern; dann können sie unter das Dach statt hinein) und `"halo": 1.0`
   (Nahanteil statt `STATIC_HALO` für reine Scheine wie den Blitz; dann fällt der Ausgleich in `radar.gd` weg).
3. `scripts/race3d/layers/lights.gd`: Stärken je Bild aus den Einträgen lesen (wie `flares`), damit ein Kegel pulsen
   kann. Heute braucht es niemand (Arcades Blitz hat keinen Kegel).
4. AS1b-Modelle `props/fuel_station` und `props/customs_booth`: die Fensterscheiben liegen in Lampenkanal 12 (bei Tag
   bräunlich); Umbau auf den Nachtlicht-Atlas wie beim Bauer „house“.
5. Ebene `lights` führt nur die 16 nächsten Kegel: an einer langen Tankstelle teilen sich Dächer und Laternen die
   Plätze (gefolgert aus dem Code, nicht als Fehler gesehen).
6. Einseitig getragene Grenzdächer (4 von 48, 6.2 Nr. 1): falls die Leitung das nicht will, wäre ein Fachwerkträger
   über dem Dach von der getragenen Seite aus die Lösung, die weder F1 noch F7 berührt.
7. Die drei Echtzeit-Audioprüfungen „im laufenden Spiel“ (`test_engine3_checks`, `test_modern_checks`,
   `test_music_checks`) sind bei Last ≥ 18 und `nice 19` rot – auf dem Kopf **und** auf der unveränderten Basis (Abschnitt 3,
   gemessen). Für das Zusammenführen: diese drei auf ruhiger Maschine (`nice 0`, Last < 4) wiederholen, bevor ein
   Rot einem Paket zugeschrieben wird.
8. Tankstelle bei Nacht ist in Modern „anders, nicht besser“ (Abschnitt 5): der größte Hebel wäre ein Nachtbild des
   AS1b-Gebäudes `props/fuel_station` mit hell leuchtender Front (Fenster und Leuchtband im Nachtlicht-Atlas, Hinweis 4),
   nicht mehr Licht von R6.
