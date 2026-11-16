# QA-R6 – Unabhängige Prüfung von R6 (Tankstelle, Grenze, Stadt, Start/Ziel, Blitzer)

- Prüfstand: `c8b18d1` (origin/wip/v080-r6), Basis `6e48405` (origin/wip/v080-m2int)
- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-2` (ff auf `c8b18d1`, nichts
  committet); Basis-Kopie (git archive `6e48405`) und Mutations-Kopie (git archive `c8b18d1`) unter
  `…/scratchpad/v080/m1/QA-R6/{base,mut}` (nach den Läufen gelöscht)
- Kein Commit, kein Push, kein Branch. Alle schweren Läufe einzeln mit `nice -n 10` (`QA_M2_FERTIG` lag), eigenes absolutes
  `XDG_DATA_HOME` je Lauf, Mesa llvmpipe unter Xvfb, Last der Maschine 14–19 (gemessen mit `/proc/loadavg`).
- „gemessen“ = auf dieser VM gelaufen; „gefolgert“ = aus Code/Daten geschlossen. Über Steam Deck und echte GPUs ist nichts
  gemessen; die Deck-Bilder sind die Voreinstellung `deck` auf llvmpipe.


## 0. Kurzfassung

**Nichts ist kaputt, die Fairness hält, Arcade ist bildgleich – aber der Look-Gewinn ist schmal und fünf Grenzdächer schweben.**

- Gates (gemessen auf `c8b18d1`): `golden.sh check` 20/20 und 17/17 identisch; `modern_sight --full` und
  `modern_path_check --full` OK; Render-Prüfungen `structures` (7/7), `start_km0`, `light_base`, `terrain_cover` (inkl. K1)
  OK; `run_tests.sh` 759 Tests, 2 rot (Echtzeit-Audio mit Wiedergabe) plus Attract-„idle“ – lastabhängig und nicht von R6
  (Attract allein 6/6 grün auf Kopf und Basis; kein Audio-Code im Diff). Regel 3 über die ganze Testetappe gleich.
- Funktion netzweit (130 Richtungen, 5366 Stücke): jede Tankstelle, Grenze, jedes Tor, jeder Blitzer und jede Laterne steht
  dort, wo Arcade sie hat – 0 Abweichungen, 0 Skriptfehler. Dateibesitz: nur R6-Dateien plus zwei gemeldete fremde
  (`check_minimal_structures.gd`, `tests/golden/modern_slice.*`), keine eingefrorene Datei.
- Befunde: **B-01 (mittel)** 5 von 48 Grenzdächern haben rechts keinen Pfeiler (R6 meldet 4) – das Dach schwebt sichtbar;
  **B-02 (niedrig–mittel)** die Stützen am Dachende verdecken in Kurven Teile ferner Schilder (F1, ≈ 195 Fälle mit
  6–14 px Tafel); **B-03 (mittel, Look)** bei Nacht ist nichts deutlich besser als Arcade, Start/Ziel ohne Gewinn, Blitzer nur
  leicht besser, Zieltor nachts leicht schlechter; B-04 drei Test-Wächter prüfen gegen die eigene Konstante; B-05 36 % der
  Stadtzäune fallen im Kurvenkorridor weg; B-06 lastabhängige Prüfungen; B-07 fremde Dateien; B-08 Einhängen 4,5 ms im
  Zeitraffer-Lauf.
- Leistung: `render()` GDScript bei normalem Tempo an den R6-Stellen 1,1–1,3 ms (Kopf) gegen 1,0–1,4 ms (Basis), Unterschied
  im Rauschen (±0,15 ms), Mittel bis auf einen Ausreißer unter dem Deck-Budget 1,5 ms.
- Gegen die Basis `6e48405` sieht nichts schlechter aus (Tankstelle nachts weiße statt oranger Lampen = Arcades Farbe,
  Zielbanner nachts heller, Blitz am Kopf neu).
- Für Testbuild 2: kein Blocker. B-01 sollte vorher entschieden werden (eine Zeile oder ein Kragträger).

## 1. Befunde (nach Schwere)

### B-01 (mittel) – Fünf Grenzdächer schweben auf einer Seite
- **Wo:** `scripts/race3d/builders/border.gd` `build()` Zeile 420 (`if str(p[2]) != "front" and ctx.in_bend_corridor(zp, px): continue`)
  zusammen mit `pillar_plan()`.
- **Was:** Steht rechts ein Schild unter dem Dach, rückt Arcades vorderer Pfeiler als `front_out` nach außen – und fällt dann wie
  jeder Nicht-Arcade-Pfeiler weg, wenn er im Kurvenkorridor steht; der Endpfeiler ebenso. Ergebnis: **5 von 48 Grenzdächern
  ohne einen einzigen Pfeiler rechts**, wo Arcade zwei vordere Pfeiler zeichnet: `belgrad_sofia__belgrad` km 339,99,
  `belgrad_sofia__sofia` km 54,99, `wien_prag__prag` km 270,0, `bialystok_kaunas__kaunas` km 90,0, Testetappe km 64,98
  (gemessen, `scan/all.log`, Zeilen „border roof one-sided“). Das Dach hängt rechts frei in der Luft (Bilder 06
  und 30: Arcade zeichnet dort seinen weißen Pfeiler, Modern nichts). R6 meldet „4 von 48“ – es sind 5.
- **Nachstellen:** `godot --headless --path . -s <scan_all.gd>` bzw. Bild `tools/ab_shot.sh … --stage=dev_testetappe
  --from=dev_start --start-km=64.3 --start-speed=100 --shot-times=0.8,1.4,2.0 --hour=12`.
- **Lösung (Leitung, Vertragsfrage):** (a) `front_out` wie `front` von der Korridor-Regel ausnehmen – er ersetzt Arcades
  eigenen vorderen Pfeiler dieser Seite, den Arcade im Korridor ebenso zeichnet (eine Zeile:
  `if str(p[2]) != "front" and str(p[2]) != "front_out" and ctx.in_bend_corridor(zp, px):`); die F1-Prüfung oben zeigt, dass
  die äußeren Pfeiler fast nie ein Schild verdecken (2 Fälle ≥ 475 m). (b) Bleibt F7 streng: ein sichtbarer Kragträger
  (Fachwerk auf dem Dach von der getragenen Seite), damit das Dach nicht schwebt.

### B-02 (niedrig bis mittel) – Stützen am Dachende verdecken in Kurven Teile ferner Schilder (F1)
- **Wo:** `station.gd` `column_plan()` / `SIGN_SCAN_M := 120.0`; die Stütze `end` auf der Insel (nicht in Arcade).
- **Was:** Die Regel „ein Schild mehr als 120 m hinter der Stütze kann nur verdeckt werden, solange es über ~350 m entfernt
  ist“ gilt nur auf gerader Straße. In Kurven verdeckt die Endstütze netzweit in **1109 Stütze-Schild-Paaren** Teile einer
  Tafel, in **≈ 195 davon bei 6–14 px Tafelbreite**, bis 56 % aus 250–300 m (gemessen, `scan/f1_all.log`; z. B.
  `fulda_kassel__kassel` Dach km 77,34 → Entfernungstafel km 80,0; `prag_leipzig__prag` km 75,3–76,2 → Tunneltafel km 77,4).
  Arcades eigene vordere Pfeiler verdecken dieselben Tafeln zu anderen Zeitpunkten ebenso (Malreihenfolge) – Modern verdeckt
  also nicht neuartig, aber etwa doppelt so oft wie Arcade. Spieltechnisch klein (ferne Tafeln, Sekundenbruchteile).
- **Lösung:** in `columns_in_chunk()` (Hauptthread, `ctx.path` vorhanden) eine Sichtlinienprüfung wie `bin/scan_f1.gd`:
  von den Fahrspurmitten 55–400 m vor jeder Tafel bis 400 m hinter dem Dach; trifft eine Linie die Endstütze, wird sie
  `end_out`. Einfacher: `SIGN_SCAN_M` für die Endstütze auf 400 m.

### B-03 (mittel, Look) – Bei Nacht und an Start/Ziel/Blitzer kein Gewinn gegen Arcade
- **Wo:** Tankstelle nachts (Shop-Schein), `gantry.gd` (Stützen `STEEL`, Banner-Nachtbild `NIGHT_GLOW` 0,6), Blitzer-Stelle.
- **Was (angesehen, Abschnitt 5):** Tankstelle nachts gleichwertig, nicht besser (Arcades großer warmer Shop-Schein fehlt,
  Bilder 02/05); Ziel nachts leicht schlechter (dunkleres Rot, dunkle Stützen verschwinden, Bild 14); Start und Ziel bei Tag
  gleich (13–15); Blitzer nur leicht besser (Schein am Kopf sichtbar, 09b). Das Ziel „klar besser als Arcade“ ist hier nicht
  erreicht.
- **Lösung:** (a) Stützen der Tore hell lackiert (Arcade: weiß; z. B. `STEEL := Color("e6e8ea")`) oder beleuchtet, Banner
  nachts mit `NIGHT_GLOW` ≈ 0,8; ein Fachwerk-Riegel statt des Kastens würde Start/Ziel sichtbar aufwerten. (b) Tankstelle
  nachts: das Nachtbild des AS1b-Shops (Fenster und Leuchtband im Nachtlicht-Atlas, A-16) – Modell-Paket, nicht R6. (c) Blitzer:
  ein heller, kurzer Kegel des Blitzes auf die Fahrbahn (Ebene `lights` müsste Stärken je Bild lesen – R4).

### B-04 (niedrig) – Drei Regeln der neuen Unit-Tests prüfen gegen die eigene Konstante
- **Wo:** `tests/unit/race3d/test_structures.gd:144` (`StationB.CANOPY_H`), `:249` (`BorderB.ROOF_H`), `:358`
  (`CityB.LAMP_ENERGY`).
- **Was:** Mutation M03 (Dach 5,4 m), M06 (Grenzdach 5,8 m), M08 (Laterne 0,55) bleiben grün (gemessen). Die F1-Höhen sind
  heute richtig (5,6 / 6,0 m = Arcade), aber nicht bewacht.
- **Lösung:** Arcades Werte als Literale in den Test (5,6 m aus `RoadRenderer._fuel_structures`, 6,0 m aus `_border_cover`,
  Kegelmitte 0,55 × `lights` → `assert_near(CityB.LAMP_ENERGY * 0.55, 0.55, …)`).

### B-05 (niedrig, Leitungsfrage B-01 von FIX-M2) – 36 % der Stadtzäune fehlen
- **Wo:** `city.gd` `_fence()` (`if ctx.in_bend_corridor(zm, …): dropped`).
- **Was:** netzweit 28 937 von 80 942 Zaunstücken weggelassen (gemessen), Arcade zeichnet sie durchgehend. In der Stadt hat fast
  jede Kurve einen breiten Korridor. Fairness-seitig vertretbar (0,9–1,4 m hohe Mauern/Hecken können ein Auto aus 3,4 m
  Augenhöhe teilweise verdecken), aber sichtbar weniger als Arcade. Hängt an der offenen Leitungsfrage zum Korridor
  (FIX-M2 B-01); `city.gd` folgt einer Änderung von `in_bend_corridor()` automatisch.

### B-06 (niedrig) – Lastabhängige Zeitprüfungen im Gesamtlauf
- `check_attract.gd` „idle“ (0,93 s statt ≥ 1 s) und zwei Echtzeit-Audioprüfungen rot im Gesamtlauf, allein 6/6 grün auf Kopf
  und Basis (Attract). Nicht R6. Lösung (QA): Attract-„idle“ gegen die Spielzeit statt der Wanduhr messen (A-11).

### B-07 (niedrig, Zusammenführen) – Fremde Dateien
- `tests/golden/modern_slice.md5/.env` (Spalte W3 „–“; R4 und R5 ändern sie auch) und `tests/race3d/check_minimal_structures.gd`.
  Lösung: beim Zusammenführen (RINT-M2) `tools/golden.sh modern-make` einmal auf dem Gesamtstand; die zwei Zeilen in
  `check_minimal_structures.gd` übernehmen.

### B-08 (niedrig) – Einhängen über dem Deck-Budget, höhere Streamer-Spitzen im Zeitraffer
- `run_stage` DEV, `deck`, Zeitraffer 40 (gemessen): Chunk-Einhängen max 4,52 ms (Basis 2,39; Budget 3 ms), längstes
  `render()` 133,9 ms (Basis 52,7; R6 maß 347 gegen 145). Bei normalem Tempo kein messbarer Unterschied (Abschnitt 6.1).
- Lösung: auf dem Deck mit dem Leistungstest nachmessen; vorher die Einhängezeit je Builder messen (`ChunkStreamer._commit`
  zeitet heute nur das ganze Stück). Falls die Stadt-Stücke es sind: Latten/Pfosten/Stäbe der Zäune als ein MultiMesh je Art
  statt Einzelgeometrie (heute bis ~125 ms Bauzeit je Stadt-Stück im Werkzeug, gemessen).

## 2. Gates, Fairness, Funktion (alles gemessen auf `c8b18d1`, Basis wo genannt)

| Lauf (Befehl) | Ergebnis |
|---|---|
| `godot --headless --path . --import` (Kopf und Basis-Kopie) | Exit 0, keine Fehlerzeile |
| `XDG_DATA_HOME=… nice -n 10 tools/run_tests.sh` (ganzer Lauf, 1 von höchstens 2; 1480 s, Last 15–17) | 316 Skripte, 0 fehlerhaft; **759 Tests, 2 FAIL**: `test_modern_checks :: test_profiles_in_a_running_game_with_playback` („Sitzung in 33 von 55 Bildern da“) und `test_music_checks :: test_music_in_a_running_game` (Einsatz des Rennstücks nach „LOS!“) – beides Echtzeit-Audio mit Wiedergabe, kein R6-Code berührt Audio (`git diff --stat`). Dazu **`check_attract.gd (Arcade)` FEHLER** „Demo 0.93 s nach der letzten Eingabe (idle_s 1)“. Alle anderen Schritte grün, darunter `test_structures` 10/10, `test_props` 12/12, `test_far_ground_water` 4/4, `check_minimal_structures` (`CHECK station OK`, `CHECK tore OK`), `arcade_lean` OK, `check_session` 15/15 (inkl. `gfx_independent`) |
| `check_attract.gd -- --graphics=arcade` allein, je 3× Kopf und Basis abwechselnd (Last 16–17) | 6 von 6 OK (Demo 1.00–1.13 s nach der letzten Eingabe) → Zeitprüfung unter Last, nicht R6 (`gates/attract_rerun.txt`) |
| `modern_sight.gd -- --full` | Exit 0: f1 0 Fälle bis 270 m (128 Etappenrichtungen, 99 424 500 Stichproben), f1_lanes OK, f2 ≤ 0,596, f3 0 von 5923, f7 0 von 2 011 532, model 0 abweichend |
| `modern_path_check.gd -- --full` | Exit 0: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2064 m (≥ 2000) |
| `run_render_checks.sh modern structures` (beide Dateien, `RENDER_CHECK_TIMEOUT=2400`) | `check_structures.gd` OK (861 s): countdown [1,1,0]/[2,2,2]/[0,0,0], zieltor rot 50 %, grenze weiß 63 % blau 20 % / Lichtband 1,00, blitz +10 % weiß, Leuchtdichte 0,88 gegen 0,44; `check_structures_licht.gd` OK (284 s): tankstelle Blende 44 m voraus, Tankspur nachts Modern 0,414 gegen Arcade 0,459 (0,90 ×), stadt 0,490 gegen 0,501, schatten 4/4 bzw. 0/4 |
| `run_render_checks.sh modern start_km0` | OK (441 s): Kamera ≤ 1,14 px, Auto Modern 193×193 bei (544, 470) gegen Arcade 192×192 bei (544, 471) |
| `run_render_checks.sh modern light_base` | OK (241 s) |
| `run_render_checks.sh modern terrain_cover` | OK (128 s): T1–T4, S1, C1, **K1** je 0,000 % Magenta |
| `XDG_DATA_HOME=… nice -n 10 tools/golden.sh check` (einmal, 793 s) | **GOLDEN arcade: 20 von 20 identisch**, **GOLDEN arcade-ui: 17 von 17 identisch** |
| Regel 3 über die ganze Testetappe (eigene Variante von `check_session.gd :: gfx_independent` mit Start km 10 statt 108, in der Mutations-Kopie) | OK: Ergebnis gleich, Zeit 399,517 / 399,517 s, **Verkehrs-Hash in 400 von 400 Sekunden gleich** – also auch über Blitzer, beide Tankstellen, Grenze, Stadt und Ziel (die Builder `station`/`border` erzeugen in `collect()` Track-Segmente vorab; das ändert die Simulation nicht) |

Nicht gelaufen: die übrigen 17 Render-Prüfdateien (`run_render_checks.sh all` braucht hier rund 2 h; R6 hat sie auf demselben
Stand grün gemeldet, ich habe die vier gelaufen, die das Brief nennt) und `golden.sh modern-check` (R6: 6 von 6).

### 2.1 Netzweiter Funktionstest (eigenes Werkzeug `bin/scan_all.gd`, headless, gemessen)

Alle 128 Etappenrichtungen und die Testetappe (beide Richtungen): jedes Stück mit einer Tankstelle, einer Grenze, einem
Blitzer, Start und Ziel, dazu bis zu 40 Stadt-Stücke je Richtung, mit den fünf Buildern gebaut (`collect` + `build`) und mit
den Track-Daten verglichen, die Arcade zeichnet (Segment-Bits `fuel_zone`, `cover`, `cover_front`, Objekte `fuel_pylon` und
`streetlight`, Schilder mit Seite 0, Blitzer-Einträge):

| Element | gebaut | Abweichung von Arcades Daten |
|---|---|---|
| 5366 Stücke in 130 Richtungen | 0 Skriptfehler | – |
| Tankstellen: 413 Tankspuren, 1923 Dächer | Inseln, Dächer, Stirnblenden, Schriftzüge, Preissäulen | **0** |
| Stützen je Dach | 0 Dächer ohne Stütze; 84 Dächer auf einer Stütze (wie Arcade: Arcade hat je Dach genau eine) | – |
| Grenzen: 48 Dächer (+2 im Somport-Tunnel ohne Dach, wie Arcade) | Dach je Segment, Stirnblende, Landesname | **0**; Pfeiler: 26 Dächer auf 4, 17 auf 3, 5 auf 2 – **5 Dächer nur auf einer Seite** (Befund B-01) |
| Start- und Zieltor | in jeder Richtung beide, je mit Banner-Tafel | **0** |
| Blitzer | 564 Blitze an 564 Kameras | **0** |
| Stadt: 2970 Stücke | 16 620 Laternen, jede mit Lampe und Kegel | **0** Laternen weniger/mehr als Track-Objekte |
| Zäune der Stadtlandschaft | 52 005 Stücke gezeichnet, **28 937 weggelassen (36 %)** wegen des Kurvenkorridors (F7) | Befund B-05 |
| Bauzeit je Stück (alle fünf Builder, Hauptthread dieses Werkzeugs) | höchstens 125,5 ms (`luettich_paris__paris`, Stadt-Stück mit Gitterzaun) | im Spiel auf dem Worker-Thread |

### 2.2 Fairness der Bauten selbst (eigenes Werkzeug `bin/scan_f1.gd`, gemessen)

`modern_sight` kennt die Bauten nicht. Deshalb ein eigener Test: für jeden wirklich gebauten Pfeiler/jede Stütze (3929 im Netz)
und jedes Schild bis 600 m dahinter eine Sichtlinie in Weltkoordinaten (RoadPath3D, Kurven eingeschlossen) von jeder
Fahrspurmitte 55–600 m vor dem Schild zu 9 Punkten über die Tafelbreite; verdeckt, wenn die Linie den Pfeilerquerschnitt
schneidet (Höhen nicht modelliert – Pfeiler reichen über die Tafelhöhe).

| Art | Paare mit Verdeckung | davon Tafel ≥ 6 px |
|---|---|---|
| Arcades Stellen (`station_front`, `border_front`) | 1612 | – (Arcade malt seinen Pfeiler ebenso über ein späteres Schild) |
| nach außen gerückt (`*_out`) | 80 | **2** (beide ≥ 475 m, 6 px) – die Regel wirkt |
| **Stütze am Dachende auf der Insel (`station_end`, nicht in Arcade)** | **1109** | **≈ 195** (bis 56 % einer 12–14-px-Tafel aus 250–300 m) – Befund B-02 |
| Grenzpfeiler am Dachende (`border_end`) | 8 | 0 |

Beispiele: `fulda_kassel__kassel` Dach km 77,34 verdeckt 56 % der Entfernungstafel km 80,0 aus 295 m (12 px);
`prag_leipzig__prag` km 75,33–76,20 je 22–44 % der Tunneltafel km 77,4 aus 180–250 m (10–13 px).

### 2.3 Wächter der neuen Tests (Mutation, gemessen)

Je eine Zeile in einer Kopie gebrochen, `tests/run_tests.gd -- --filter=test_structures` (unverändert: 10/10 OK):

| Mutation | erkannt? |
|---|---|
| M01 Inselkante 0,2 m neben `Track.fuel_lane_*` | ja |
| M02 Stütze rückt nie vor einem Schild weg (F1) | ja |
| **M03 Dachunterseite 5,4 m statt Arcades 5,6 m (F1)** | **nein** |
| M04 Grenzpfeiler rückt nie vor einem Schild weg (F1) | ja |
| M05 Grenzpfeiler ignorieren den Kurvenkorridor (F7) | ja |
| **M06 Grenzdach 5,8 m statt 6,0 m (F1)** | **nein** |
| M07 nur rechte Laternen | ja |
| **M08 Laternenstärke 0,55 statt 1,0** | **nein** (nur die Render-Prüfung `stadt` würde es merken) |
| M09 Zäune ignorieren den Kurvenkorridor | ja |
| M10 Countdown eine Lampe zu spät | ja |
| M11 Blitz unter 0,05 | ja |
| M12 Bauten werfen bei „Schatten: Aus“ | ja |
| M13 dynamisches `vpbr` (Instanz-Uniforms) | ja |
| M14 keine Preissäule | ja |
| M15 keine Countdown-Lampen | ja |
| M16 Laternen ohne Lichtkegel | ja |
| M17 Landesname nicht groß | ja |
| M18 Dach auch auf Insel-Segmenten | ja |

15 von 18 erkannt. M03/M06/M08 prüfen gegen die eigene Konstante des Builders (Befund B-04).

## 3. Arcade-Identität und Dateibesitz

`git diff 6e48405..c8b18d1 --stat` (gemessen): 18 Dateien, +3366 / −331.

| Datei | im Brief von R6? | Bewertung |
|---|---|---|
| `scripts/race3d/builders/{station,border,city,gantry,radar}.gd` (+ `.uid`) | ja | in Ordnung |
| `tests/unit/race3d/test_structures.gd`, `tests/race3d/render/check_structures.gd` | ja | in Ordnung |
| `tests/race3d/render/check_structures_licht.gd` (neu, 12 Zeilen, erbt) | nein (neue Datei derselben Art) | in Ordnung, gemeldet (Laufzeit > 900 s) |
| `docs/renderer-modern-bauten.md` (neu) | nein | in Ordnung als neue Datei; Verweis in `docs/renderer-modern.md` fehlt (Datei von R4) |
| `tests/race3d/check_minimal_structures.gd` (2 Stellen) | **nein – fremde Datei** | sachlich nötig (die Prüfung zählte `Label3D`, das die Leitung verboten hat), gemeldet; Konfliktgefahr gering |
| `tests/golden/modern_slice.md5`, `.env` | **nein – Spalte W3 „–“** | Konflikt mit R4/R5 sicher; beim Zusammenführen `golden.sh modern-make` einmal auf dem Gesamtstand (Befund B-07) |
| `scripts/race3d/builders/props.gd` | Leitungsausnahme | **nicht geändert** – richtig: `props.gd:109` setzt `_skip_objects`, sobald `renderer.builder("city")` existiert, und `OBJECT_SETS` kennt nur `streetlight` (gelesen) |

Keine eingefrorene Arcade-Datei im Diff (Abgleich gegen die Liste von §2 Regel 1). `layers/lights.gd`, `layers/flares.gd`,
`modern_renderer.gd` unberührt. Kein Builder nennt eine `class_name` eines anderen Pakets dieser Welle; der Renderer wird nur
über `renderer.get("materials"|"track"|"cfg")`, `ctx.services["renderer"].call(&"add_lamps", …)` und `has_method`
angesprochen (gelesen). `Label3D`: kein Vorkommen im Code von R6 außer in Kommentaren (`grep`).

## 4. Code-Durchsicht (gelesen, gefolgert)

- Worker-Thread-Regel eingehalten: `build()` liest nur `ctx`-Schnappschüsse und die Tabellen aus `collect()`; Track-Zugriffe
  (`columns_in_chunk`, `pillars_in_chunk`) laufen in `collect()` auf dem Hauptthread.
- `collect()` von `station`/`border` erzeugt Track-Segmente bis 120 m + `generation_lead_m()` hinter einem Dach vorab. Die
  Simulation bleibt gleich (Regel-3-Lauf über die ganze Testetappe, Abschnitt 2).
- Schrifttafeln: `PanelAtlas` legt die Zellen sofort in `prepare()` an (die UVs stimmen schon, bevor das Bild gelesen ist);
  ein vor dem Lesen gebautes Material bekommt die Texturen in `prepare_pending()` nachgereicht. Headless: Platzhalter.
- Countdown-Lampen und Blitz ändern ihre `add_lamps()`-Einträge je Bild über `update()` der Builder; `flares.gd` liest
  Farbe, Stärke und Größe je Bild aus dem Eintrag (gelesen) – das funktioniert ohne Änderung an R4s Dateien.
  Kleinigkeit: Einträge mit Rolle `"on"` und Stärke 0 (jede Blitzerkamera ohne Blitz, Countdown-Lampen aus) erzeugen
  trotzdem je Bild eine unsichtbare Flare-Instanz (`flares.gd:205` prüft `on`, nicht `energy`).
- Die Lampen der Lichtkegel liegen im Dach-/Platten-Kasten; `flare.gdshader` prüft die Verdeckung mit fünf Tiefen-Taps an
  der Lampe, deshalb bleibt deren warmer Laternenschein unsichtbar (so beabsichtigt, Umweg für eine fehlende Option in
  `flares.gd`).
- `city.gd` holt `props/streetlight` in LOD0 – das Modell hat nur diese eine Stufe (274 Dreiecke, Manifest), also richtig.

## 5. Bilder und Urteil gegen Arcade (eigene Bilder, gerendert und angesehen)

Alle Bilder mit `tools/ab_shot.sh` (gleicher Simulationszustand, links Arcade, rechts Modern), Modern „Hoch“ bei 1280 × 720,
die Deck-Bilder `--gfx-preset=deck` bei 1280 × 800; die Argumente stehen unter jedem Bildpaar. Basis-Vergleiche: dieselben
Argumente mit der Basis-Kopie `6e48405` (Dreierbilder Arcade | Modern Basis | Modern R6). Dateien in
`…/scratchpad/v080/deliver/QA-R6/` (Nummern unten).

| Ort | Tag | Nacht | Basis → R6 |
|---|---|---|---|
| Tankstelle DEV km 18,5–19,6 (01, 02) | **besser, nicht überragend**: Preissäule mit Mast und Fundament, Dächer mit Blendenbändern, Stützen mit Sockel, Leuchtkästen, Insel mit gelbem Bordstein, AS1b-Zapfsäulen und -Shop. Farben und Formen sind Arcades – der Gewinn ist Körper und Tiefe, nicht Detail | **gleichwertig, anders**: Dächer, Leuchtkästen, „TANKSTELLE“ hinterleuchtet und lesbar, Zapfsäulen hell; Arcades großer warmer Schein des Shop-Sprites fehlt, das Gelände wirkt dunkler | Tag kaum Unterschied (FIX1 hatte schon Insel, Dach, Stützen); Nacht weiße Leuchtkästen mit Arcades weißem Schein statt der orangen Punktlampen der Basis – näher an Arcade, **nicht schlechter** (03, 03b) |
| Tankstelle Kiel – Hamburg km 13,4–14,2, Tutorial-Stopp (04, 05) | gleich bis besser (wie DEV) | gleichwertig | wie DEV (25) |
| Grenze DEV km 64,5–64,9 (06, 07, 30) | **besser in Tiefe und Detail** (Dachunterseite, Häuschen als Modelle) – **aber rechts schwebt das Dach ohne Pfeiler** (B-01), im Nahbild deutlich | **gleich bis besser**: Lichtbänder, Häuschen mit warmen Fenstern, Blende hinterleuchtet; rechts weiter kein Pfeiler | Basis: keine Grenze |
| Grenze Nürnberg → Prag km 129,3, „ČESKO“ (08) | **besser**: beidseitig getragen (rechts nach außen hinter das Warnschild gerückt), Unterseite, Häuschen; „Č“ richtig | – | Basis: keine Grenze |
| Blitzer DEV km 11,8, Blitz bei 0,53 s (09) und km 10,9, Blitz bei 2,50 s ohne HUD-Überdeckung (09b) | **leicht besser**: mit Start km 11,8 liegt der Kamerakopf hinter HUD-Ampel und „LOS!“ (beide Modi nur HUD-Weiß); ohne Überdeckung (09b) ist in Modern ein klarer weißer Schein am Kamerakopf zu sehen, in Arcade praktisch keiner. Pfosten = AS1b-Modell, wirkt wie Arcades Sprite | gleich (in Modern ein kleiner weißer Schein am Kopf) | Basis ohne Schein am Kopf, R6 mit – besser (26) |
| Stadt DEV km 111 (10, 11) | **besser**: Laternen mit Mast und Ausleger, Hecken als Körper, Gehwegpflaster | **gleich bis leicht besser**: Kegel auf Straße und Gehweg, echte Lampenköpfe; Arcades große warme Höfe um jede Laterne wirken stärker als Moderns kleine Scheine | praktisch gleich (die Basis zeichnete die Laternen über `props.gd`) (26) |
| Ankunft Hamburg km 76 (12) | – | gleich bis besser (Laternenreihe mit Scheinen, Hecken) | – |
| Start DEV und Kiel – Hamburg (13, 15) | **gleich**: Arcades Banner-Tafel, graue Stahlstützen statt weißer Balken, Lampen an Arcades Stellen, rot → grün wie Arcade, Auto wie Arcade | **gleich** („START“ hellgrau wie Arcade, roter Schein um die Lampe wie Arcade) | Basis: „START“ nachts reinweiß (heller als Arcade), R6 wie Arcade – gleichwertig (26, 27) |
| Ziel DEV und Kiel – Hamburg (14, 15) | **gleich** | **leicht schlechter**: Banner dunkleres Rot, die dunklen Stahlstützen verschwinden vor dem Nachthimmel, Arcades weiße Stützen stehen klar da | Basis: Banner nachts fast schwarzrot; R6 rot mit Schachbrett – besser als die Basis, dunkler als Arcade (26) |
| Deck 1280 × 800 (16) | Grenze wie „Hoch“ | Tankstelle und Stadt wie „Hoch“; Modern füllt 16:10 | – |

**Gesamturteil Look:** Bei Tag sind Tankstelle, Grenze (außer der schwebenden Rechtsseite) und Stadt besser als Arcade – durch
Körper, Schatten und Tiefe; Farben, Formen und Schrift sind bewusst Arcades. Deutlich besser ist es an der Grenze (Prag) und in
der Stadt, an der Tankstelle nur mäßig. Bei Nacht ist nichts deutlich besser: Tankstelle und Stadt verlieren Arcades große
warme Scheine, das Zieltor ist leicht schlechter. Start, Ziel und Blitzer bringen keinen sichtbaren Gewinn. „Modern sieht klar
besser aus“ gilt damit nur bei Tag und für drei der fünf Elemente (Befund B-03).

### 5.1 Clips von R6 (angesehen; Bildauszüge 20–24)

Die vier Clips (60 fps, Arcade | Modern) zeigen die verlangten Abläufe in beiden Modi im selben Takt: Countdown 3-2-1 mit
roten Lampen, alle grün bei „LOS!“ (20); Tanken bis „Vollgetankt – 18 L“ (21); Blitz bei 0:00,37 (22) und Polizeistopp
„Führerschein, bitte!“ ab 0:25 (23); Ziel mit „ZIEL“-Banner (24). Schwächen (in beiden Modi, nicht vom Renderer): im
Blitz-Clip liegen „LOS!“ und die HUD-Ampel genau über dem Kamerakopf, der Blitz am Pfosten ist kaum zu erkennen; im Ziel-Clip
verdecken die Tutorial-Tipps das Banner beim Durchfahren. Ein eigener Clip habe ich nicht aufgenommen (Movie Maker auf „Hoch“
≈ 140 s je Clip-Sekunde hier); ein Blitz-Clip ohne HUD-Überdeckung (Start km 11,2, Blitz nach ~2 s) wäre aussagekräftiger.

## 6. Leistung (gemessen auf dieser VM; über das Deck und echte GPUs nichts gemessen)

### 6.1 GDScript-Zeit des ganzen Renderers bei normalem Tempo (headless, Methode von `renderer_zeit`)

Eigene Variante `tests/race3d/check_qa_zeit.gd` (aus `check_modern_stage.gd`: `_drive_time()`, 600 Bilder bei 150 km/h mit dem
Verkehr der Sitzung, Zeit mit dem Referenztakt `perf_clock.gd` auf das Normaltempo der VM skaliert, je Ort das bessere von
zwei Durchgängen), je viermal Kopf (`c8b18d1`) und Basis (`6e48405`) abwechselnd, Last 14–19:

| Ort (DEV) | Kopf ms (4 Läufe) | Mittel | Basis ms (4 Läufe) | Mittel |
|---|---|---|---|---|
| Autobahn km 30 | 0,87 / 0,88 / 1,00 / 1,08 | 0,96 | 0,92 / 1,16 / 1,17 / 1,13 | 1,10 |
| Tankstelle km 18,4 | 0,99 / 1,04 / 1,18 / 1,27 | 1,12 | 0,80 / 1,08 / 1,10 / 1,32 | 1,08 |
| Grenze km 64,2 | 1,07 / 1,43 / 1,29 / 1,24 | 1,26 | 1,02 / 1,04 / 1,41 / 1,02 | 1,12 |
| Stadt km 109,6 | 1,23 / 1,20 / 1,31 / 1,31 | 1,26 | 1,16 / 1,38 / 1,32 / 1,29 | 1,29 |
| Start km 0 | 0,95 / 1,03 / 1,10 / 1,29 | 1,09 | 0,63 / 1,02 / 1,04 / 1,31 | 1,00 |
| Tankstelle 21 Uhr | 0,99 / 1,12 / 1,22 / 1,16 | 1,12 | 1,11 / 1,25 / 1,35 / 1,24 | 1,24 |
| Stadt 21 Uhr | 1,20 / 1,36 / 1,46 / 2,22* | 1,56 | 1,24 / 1,56 / 1,45 / 1,47 | 1,43 |

\* ein Lauf mit einem 193-ms-Bild (Last). Lesart: Unterschiede Kopf – Basis −0,14 … +0,14 ms, also im Rauschen (±0,15 ms);
alle Mittel bis auf den Ausreißer unter dem Deck-Budget 1,5 ms (§4.10). Längstes Bild je Lauf 6–193 ms in **beiden** Ständen;
Chunk-Einhängen im Hauptthread höchstens 4,9 ms (Kopf) bzw. 9,8 ms (Basis) – beide über dem 3-ms-Budget nur in einzelnen
Läufen, lastabhängig.

`collect()` der fünf Builder im Hauptthread (eigenes Werkzeug `bin/collect_time.gd`, Track wie im Spiel fortlaufend erzeugt,
Pfad 36 Stücke voraus; DEV, Kiel – Hamburg, Prag – Nürnberg): Tankstelle ≤ 0,39 ms, Grenze ≤ 0,27 ms, Tor ≤ 0,14 ms,
Blitzer ≤ 0,02 ms je Stück, Mittel ≤ 0,02 ms – vernachlässigbar.

### 6.2 Ganzer Lauf unter Xvfb, Voreinstellung `deck`, 1280 × 800 (`bin/perf.sh`: `run_stage.gd` DEV 21 Uhr, Zeitraffer 40)

| `perf_stats` | Kopf | Basis |
|---|---|---|
| `render()` ms Mittel / max | 6,75 / 133,9 | 5,42 / 52,7 |
| davon Hook `streamer` ms Mittel / max | 4,11 / 132,2 | 3,07 / 50,4 |
| Chunk-Einhängen max (Hauptthread) | 4,52 ms | 2,39 ms |
| Chunk-Bau ms Mittel / max (Worker-Thread) | 6,84 / 84,7 | 6,17 / 77,0 |
| Draw Calls / Primitive / Schatten-Primitive (letztes Bild, Ziel) | 83 / 75 885 / 8 316 | 77 / 75 885 / 3 384 |
| Instanzen mit Instanz-Uniforms | 63 | 102 |
| Hooks `gantry` / `radar` ms Mittel | 0,009 / 0,004 | 0,013 / – |
| Ergebnis | 130 km, 0 Kollisionen, 0 Skriptfehler, `time_s` 376,85 | gleich |

Lesart: Im Zeitraffer 40 baut und hängt der Streamer je Bild viele Stücke ein; dort kostet R6 im Mittel +1,0 ms im Streamer und
das längste Bild war höher (133,9 gegen 52,7 ms). R6 maß dasselbe Muster (347 gegen 145 ms) – zwei von zwei Läufen, also
wahrscheinlich echt, aber nur im Zeitraffer: bei normalem Tempo (6.1) ist kein Unterschied messbar. Das Einhängen eines Stücks
liegt mit 4,5 ms über dem Deck-Budget von 3 ms (Basis 2,4 ms; R6 maß 5,6 gegen 95,5 ms – sehr verrauscht). Gefolgert: Spitzen
kommen vom Einhängen großer Stadt-Stücke (Zäune als `ArrayMesh`, Laternen-MultiMeshes, `add_lamps`); auf dem Deck nachmessen
(Leistungstest). +6 Draw Calls und ≈ +4 900 Schatten-Dreiecke am Zieltor liegen weit unter dem Budget (650 / 450 000).

## 7. Geprüft und in Ordnung

- Arcade bildgleich (20/20, 17/17), keine eingefrorene Datei berührt, `arcade_lean` grün.
- Fairness-Gates `modern_sight --full` (F1, F1-Spuren, F2, F3, F7, Modell) und `modern_path_check --full` grün.
- Regel 3: gleiches `ERGEBNIS` und gleiche Verkehrs-Hashes in allen 400 Sekunden der Testetappe ab km 10 (Arcade gegen Modern).
- Jede Tankstelle, Grenze, jedes Tor, jeder Blitzer und jede Stadtlaterne des Netzes wird gebaut, wo Arcade sie zeichnet
  (0 Abweichungen in 5366 Stücken, 0 Skriptfehler).
- Tankspur-Geometrie = `Track.fuel_lane_*` (Unit-Test, durch Mutation M01 bewacht).
- Dachhöhen über Fahrbahn und Spur: nichts unter 5,6 m (Tankstelle) bzw. 6,0 m (Grenze) außer den Leuchtkästen (6 bzw. 10 cm),
  Unit-Test grün (Wächter siehe B-04).
- Nach außen gerückte Pfeiler/Stützen verdecken praktisch nie ein Schild (2 Paare netzweit, beide ≥ 475 m).
- Schrift nur als Tafel (`PanelAtlas`), kein `Label3D`; „ČESKO“ mit Diakritik richtig; „TANKSTELLE“ nachts lesbar.
- Countdown-Regel = Arcades `_start_light_glows` (Render-Prüfung und Unit-Test, Mutation M10 erkannt); Auto im Countdown an
  Arcades Stelle (`check_start_km0`: 193×193 bei (544, 470) gegen 192×192 bei (544, 471)).
- Laternen alle 33 m im Seitenwechsel mit Lichtkegel, Kegel 0,490 gegen Arcade 0,501 (Render-Prüfung `stadt`).
- Blitz folgt `view.radar_flash01`, unter 0,05 aus (Mutation M11 erkannt); sichtbar am Kopf (Render-Prüfung `blitz`).
- Fixes des ersten Testbuilds halten: `check_start_km0`, `check_light_base`, `check_terrain_cover` (K1 0,000 %),
  `test_far_ground_water` 4/4, `test_props` 12/12.
- `props.gd` braucht keine Ausnahme: es überlässt die Laternen dem Builder `city` bereits selbst (`_skip_objects`).
- Kein Builder spricht ein anderes Paket dieser Welle über eine `class_name` an; nur Fassade und `has_method`.
- Statisches `vpbr` ohne Instanz-Uniforms (63 statt 102 Instanzen mit Uniforms laut R6; Unit-Test, Mutation M13 erkannt);
  Bauten werfen bei „Schatten: Aus“ nichts (M12 erkannt, Render-Prüfung `schatten`).
- Gegen die Basis `6e48405` sieht nichts schlechter aus (Bilder 03, 03b, 25, 26, 27).

## 8. Für die Nächsten (genaue Änderungen)

1. **B-01** `scripts/race3d/builders/border.gd:420` – Leitungsentscheidung: `front_out` von der Korridor-Regel ausnehmen
   (`if str(p[2]) != "front" and str(p[2]) != "front_out" and ctx.in_bend_corridor(zp, px): continue`) oder Kragträger zeichnen.
   Danach `bin/scan_all.gd` erneut: erwartet 0 einseitige Dächer.
2. **B-02** `station.gd` `columns_in_chunk()`/`column_plan()`: Endstütze `end` nur, wenn keine Sichtlinie von einer
   Fahrspurmitte 55–400 m vor einem Schild bis 400 m hinter dem Dach sie schneidet (Vorlage `bin/scan_f1.gd`), sonst `end_out`.
3. **B-04** `tests/unit/race3d/test_structures.gd:144/249/358`: Arcades Literale 5.6, 6.0 und die Kegelmitte 0,55 statt der
   Builder-Konstanten.
4. **B-03** `gantry.gd`: helle Stützen (`STEEL` ≈ `e6e8ea`), `NIGHT_GLOW` ≈ 0,8; Shop-Nachtbild beim Modell-Paket (A-16).
5. RINT-M2: `tools/golden.sh modern-make` einmal auf dem Gesamtstand (R4, R5, R6 ändern `modern_slice.md5`).
6. `docs/renderer-modern.md` (R4): ein Verweis auf `docs/renderer-modern-bauten.md`.
7. `flares.gd` (R4): Einträge mit Rolle `"on"` und `energy` 0 überspringen (heute je Bild eine unsichtbare Instanz je
   Blitzerkamera und Countdown-Lampe); optionale Schlüssel `glow`/`halo`, wie R6 vorschlägt.
8. QA: `check_attract.gd` „idle“ gegen Spielzeit messen (lastfest, A-11).
9. B-05 folgt der offenen Korridor-Entscheidung (FIX-M2 B-01); danach `scan_all.gd` für die Zaun-Quote.

## 9. Werkzeuge und Rohdaten (Scratch, nicht committet)

`…/scratchpad/v080/m1/QA-R6/`: `bin/scan_all.gd` (Netz-Funktionstest), `bin/scan_f1.gd` (Sichtlinien Pfeiler/Stützen →
Schilder), `bin/info.gd` (Elementpositionen), `bin/mutate.py` (18 Mutationen), `bin/make_qa_zeit.py` + `bin/qa_zeit_rep.sh`
(Renderer-Zeit Kopf/Basis), `bin/perf.sh`, `bin/chain_a.sh`, `bin/chain_b.sh`; Logs in `gates/`, `scan/`, `perf/`, `mutlogs/` (die Kopien `base/` und `mut/` sind gelöscht; `check_qa_zeit.gd` und `check_session_qa.gd` liegen in `bin/`);
A/B-Einzelbilder als JPEG in `shots/` (PNG gelöscht).
