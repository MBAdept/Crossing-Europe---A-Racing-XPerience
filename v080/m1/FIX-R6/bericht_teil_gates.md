## 2. Gates (gemessen)

Zwei Gate-Läufe: Lauf 1 auf `b185bb8` (Logs `m1/FIX-R6/gates/run1/`), danach habe ich die Hauptthread-Kosten der
Tankstelle gesenkt (`2c75af0`, gleiche Entscheidungen) und alles Nötige auf `2c75af0` wiederholt (Lauf 2, `gates/`).
Alle Läufe einzeln, `nice -n 10`, eigenes absolutes `XDG_DATA_HOME`, Last 9–17.

| Lauf (Befehl) | Stand | Ergebnis |
|---|---|---|
| `godot --headless --path . --import` | `2c75af0` | Exit 0, keine Fehlerzeile |
| `godot --headless --path . -s res://tests/check_scripts.gd` | `2c75af0` | 316 Skripte geprüft, 0 fehlerhaft |
| `tools/run_tests.sh` (ganzer Lauf 1 von 2) | `b185bb8` | **761 Tests, 0 fehlgeschlagen**, „Tests bestanden“ (944 s) – darunter `test_structures` 12/12, `test_props`, `test_far_ground_water`, `check_minimal_structures` (station, tore), Attract „idle“ OK, die Echtzeit-Audioprüfungen grün |
| `tools/run_tests.sh` (ganzer Lauf 2 von 2) | `2c75af0` | **761 Tests, 1 fehlgeschlagen**: `test_music_checks :: test_music_in_a_running_game` (Echtzeit-Musik nach „LOS!“, startet das Spiel mit `--graphics=arcade` – lädt keine Zeile von `scripts/race3d`); alles andere grün (959 s). In Lauf 1 grün; dieselbe Prüfung ist bei R6 und QA-R6 lastabhängig rot (B-06). Allein wiederholt: MUSICALONE |
| `tools/run_tests.sh test_structures` (Filter, nach jeder Code-Änderung) | `2c75af0` | 12 Tests, 0 fehlgeschlagen |
| `tools/golden.sh check` | `b185bb8` und `2c75af0` | beide Male **GOLDEN arcade: 20 von 20 identisch**, **GOLDEN arcade-ui: 17 von 17 identisch** |
| `tools/golden.sh modern-check` (Bilder behalten) | `2c75af0` | **GOLDEN modern: 5 von 6 identisch** – `modern_start_mittel` anders, gewollt (Starttor mit Fachwerk, weißen Stützen und Flutlichtern; Bild angesehen); `modern_s2_mittel` (Tankstelle km 14,8) unverändert; **modern-gles** OK (max. 2/255, PSNR 73,2 dB) |
| `tools/golden.sh modern-make` | `2c75af0` | MODERNMAKE |
| `tests/sim/modern_sight.gd -- --full` | `b185bb8` (Builder nicht beteiligt) | Exit 0: f1 0 Fälle bis 270 m (99 424 500 Stichproben), f1_lanes OK, f2 ≤ 0,596, f3 0 von 5923, f7 0 von 2 011 532, model OK |
| `tests/sim/modern_path_check.gd -- --full` | `b185bb8` | Exit 0: kleinster Abstand 267,6 m, Schleifen frühestens nach 2064 m |
| `tools/run_render_checks.sh arcade` + `modern` je Datei (`RENDER_CHECK_TIMEOUT=2400`) | `2c75af0` | **21 von 21 Dateien OK** (2 Arcade, 19 Modern), darunter `structures` (countdown [1,1,0]/[2,2,2]/[0,0,0], zieltor rot 50 % weiß 6 % schwarz 4 %, grenze weiß 63 % blau 20 % / Lichtband 1,00, blitz +0,44), `structures_licht` (tankstelle: Tankspur nachts 0,414 gegen Arcade 0,459 = 0,90 ×, stadt 0,490 gegen 0,501, schatten 4/4 bzw. 0/4), **`start_km0`** (Kamera ≤ 1,14 px, Auto 193×193 bei (544, 470) gegen 192×192 bei (544, 471)), **`light_base`**, **`terrain_cover`** (T1–T4, S1, C1, **K1** je 0,000 % Magenta) |
| Netz-Scans von QA-R6 (`scan_all.gd`, `scan_f1.gd`, headless) | `2c75af0` | 0 Skriptfehler; alle Zählungen (Inseln, Dächer, Blenden, Schriften, Preissäulen, Grenzen, Tore, Blitzer, Laternen) 0 Abweichungen; 0 schwebende Grenzdächer (10 Masten), 0 Dächer ohne Stütze; `station_end` 38 Paare (5 ≥ 6 px) |
| Mutationen M03/M06/M08 (`bin/mutate.sh`) | `ffca594` | alle drei rot |
| Ganzer Modern-Autopilot-Lauf DEV 21 Uhr, Xvfb, `deck` (Abschnitt 3) | `2c75af0` | 130 km, 0 Kollisionen, 0 Skriptfehler, `ERGEBNIS` gleich der Basis |

Dateibesitz: nur R6s Dateien (`builders/{border,station,gantry}.gd`, `tests/unit/race3d/test_structures.gd`,
`docs/renderer-modern-bauten.md`) und die Modern-Änderungsmelder `tests/golden/modern_slice.{md5,env}` (wie R6 –
gewollt geändert, B-07). Keine eingefrorene Datei, nichts von R4/R5 (`git diff --stat c8b18d1..HEAD`).

## 3. Leistung (gemessen auf dieser VM; Steam Deck und echte GPUs nicht gemessen)

### 3.1 Ganzer Lauf unter Xvfb, `deck`, 1280 × 800 (`run_stage.gd` DEV 21 Uhr, Saat 7, Zeitraffer 40), Kopf gegen Basis `c8b18d1`

PERFTABLE

### 3.2 Hauptthread-Kosten von `collect()` (QAs `collect_time.gd`, Pfad 36 Stücke voraus wie im Spiel)

| `collect()` je Stück, Maximum | Kiel – Hamburg | Prag – Nürnberg | DEV |
|---|---|---|---|
| Tankstelle, Basis `c8b18d1` (zwei Läufe) | 0,17 / 0,14 ms | 0,22 / 0,19 ms | 0,34 / 0,60 ms |
| Tankstelle, erste Fassung `b185bb8` (alle Dächer einer Station in einem Stück) | 5,5 ms | 6,7 ms | 12,8 ms |
| Tankstelle, Kopf `2c75af0` (ein Dach voraus, nur nötige Kameras), drei Läufe | 1,2 / 1,2 / 1,1 ms | 3,9 / 3,3 / 4,3 ms | 3,1 / 3,9 / 6,7 ms |
| Grenze, Kopf `2c75af0` (Pfeiler für das ganze Dach) / Basis | 0,03 / 0,13 ms | 0,47 / 0,24 ms | 0,45 / 0,41 ms |

Lesart: die Sichtlinienprüfung der Endstützen kostet einmal je Dach 1–4 ms auf dem Hauptthread (Last 12); verteilt über
die Stücke vor der Station liegt das Maximum je Stück bei 1,1–6,7 ms (Last 10–12, stark streuend) gegen 0,1–0,6 ms der Basis. Gefolgert: auf dem Deck
ohne fremde Last kleiner; falls dort doch eine Spitze sichtbar wird, gehört die Prüfung in `prepare()` bzw. über mehrere
Bilder (Vertragsfrage 5.2 Nr. 2).
