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
