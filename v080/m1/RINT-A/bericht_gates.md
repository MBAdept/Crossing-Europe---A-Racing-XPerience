## 0. Gates auf dem Endstand fd27c16

fd27c16 ändert gegenüber 9b4be1c nur eine Prüfung (`kern_zeit`), ein Testdouble und die Doku; Render, Kaltstart
und ganze Etappe liefen auf 9b4be1c (gleicher Spielcode), Import und `check_modern_stage.gd` auf fd27c16.

Alle auf dieser VM (llvmpipe, Xvfb 1280 × 720, `nice -n 10`, eigener `XDG_DATA_HOME` unter dem Scratch-Ordner,
`--graphics=` immer ausdrücklich). Logs: `m1/RINT-A/gates/` (erster Lauf, bd30c5c), `m1/RINT-A/gates2/` (Endstand) und `m1/RINT-A/logs/`.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | rc 0, 0 Fehler (auf 9b4be1c und fd27c16) |
| Unit-Tests | `tools/run_tests.sh` | 2. (letzter erlaubter) Lauf auf 9b4be1c: **673 Unit-Tests, 0 fehlgeschlagen; 137 Prüfungen OK, 1 FEHLER**: `check_modern_stage` → `kern_zeit` 0,618 ms (Grenze 0,6; im 1. Lauf 0,499 ms OK). Die Prüfung soll den Renderer-Kern messen („ohne Fahrzeug-, Requisiten- und Gelände-Ebene“), maß seit der Zusammenführung aber alles, was `render()` jetzt aktualisiert – ihr Umfang ist auf den Kern zurückgeführt (Testdouble `tests/race3d/fixtures/core_renderer.gd`, Kern allein 0,194 ms – R1 hatte 0,208 ms gemessen); danach `check_modern_stage.gd` einzeln: **7 von 7 OK** (`kern_zeit` 0,251 ms, `ergebnis` gleich in beiden Modi). 1. Lauf auf bd30c5c: nur `check_vehicles` → `lampen_fest` rot (behoben, 412a756) |
| Golden | `tools/golden.sh check` | **GOLDEN arcade: 20 von 20 identisch** (225 s, einmal, auf bd30c5c; seither geändert nur `flare.gdshader`, `scripts/race3d/builders/props.gd` – beide lädt nur Modern –, vier Prüfungen, ein Testdouble und die Doku: `git diff --name-only bd30c5c HEAD`) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **13 von 13 Dateien in Ordnung**, 39 `RENDER-CHECK … OK`, 0 FEHLER (u. a. `bremslicht` 150 m +0,16, `lkw` 0 Pixel, `klassen` Fenster 1.064 px, `pause` 0 Bildpunkte, `rueckfall`, `freigabe`, `rotor`). Erster Lauf auf bd30c5c: 10 von 13 (`klassen`, `lkw`, `bremslicht` – Abschnitt 2.7/2.8) |
| Sicht | `tests/sim/modern_sight.gd -- --full` | 6 OK, 0 FEHLER: F1 0 Fälle bis 270 m in 99.424.500 Stichproben (128 Etappenrichtungen), Außenspuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 5923, F7 0 von 2.011.532 Querschnittsseiten, Modell 0 abweichend (139 s) |
| Weg | `tests/sim/modern_path_check.gd -- --full` | 2 OK, 0 FEHLER: kleinster Abstand 267,6 m (≥ 250 m), Schleifen frühestens nach 2064 m Weg (≥ 2000 m) (56 s) |
| Modelle | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (28 Modelle, LOD- und Schattenbudgets) |
| ERGEBNIS | `tests/race/run_stage.gd -- --stage=kiel_hamburg --from=kiel --graphics=arcade\|modern --seed=11 --timescale=40` | 28 Schlüssel, verschieden nur `gfx` (Seed 11, 8 Uhr: 95 km, 1 Tankstopp, 41,92 l, `time_s` 360,95 in beiden) |
| Ganze Etappe | `run_stage.gd` unter Xvfb, `--graphics=modern --gfx-preset=medium --vehicle=limousine --hour=12 --timescale=4` | rc 0, `aborted` false, 95 km, 1 Tankstopp, 0 Kollisionen, 1526 s Wanduhr (auf 9b4be1c; ebenso auf bd30c5c, 1183 s); im Log **keine** Warnung oder Fehlermeldung je Bild – die einzige Zeile ist die V-Sync-Warnung des Treibers vor dem Start; ERGEBNIS in beiden Läufen gleich |
| Kaltstart | `tests/race3d/render/warmup_cold.gd -- --graphics=modern` mit leerem Nutzer- und Mesa-Cache | **0 Varianten während der Fahrt** (389 im Cache vor dem Start; Kiel – Hamburg km 2, „Mittel“, 12 Uhr, 39 Bilder in 30 s, Median 766 ms, längstes 1.078 ms, Grenze 2.299 ms). Erster Lauf auf bd30c5c: FEHLER – 2 Varianten nach 3,0 s (Abschnitt 2.8) |

**perf_stats der ganzen Etappe** (Kiel – Hamburg, Modern „Mittel“, 12 Uhr, llvmpipe unter Xvfb, Zeitraffer 4 –
gemessen auf einer geteilten VM, Werte einer Software-Grafik, keine Aussage über eine echte Karte):

| Größe | 9b4be1c (Last 8,3) | bd30c5c (Last 5,3) |
|---|---|---|
| `render_ms_avg` / `render_ms_max` (GDScript-Zeit von `render()`) | 2,01 ms / 29,9 ms | 1,73 ms / 12,5 ms |
| `chunk_commit_ms_max` (Streamer, ganze Fahrt) / Einhängen in der Vorbereitung | 1,75 ms / 10,6 ms | 1,53 ms / 9,67 ms |
| `chunk_build_ms_avg` / `_max` (Arbeiter-Thread, 95 Stücke) | 5,57 ms / 25,4 ms | 4,75 ms / 18,6 ms |
| `draw_calls` / `primitives` (letztes Bild, im Ziel; Schatten) | 95 / 74.412 (0 / 2.526) | 95 / 74.412 (0 / 2.526) |
| Bildzeit Median / p95 (llvmpipe, 1280 × 720) | 659 ms / 909 ms (2.398 Bilder) | 395 ms / 502 ms |
| Vorbereitung / Aufwärmen (Aufwärm-Knoten) | 13,7 s / 12,6 s (48) | 8,5 s / 7,2 s (17) |
| erste Bilder nach dem Ladebild: Median / längstes | 405 / 633 ms (73 Bilder) | 935 / 1.252 ms (34 Bilder) |
| `vehicle_us_avg` / `_max`, `flare_us_avg` / `_max` | 796 µs / 16,8 ms, 113 µs / 13,5 ms | 723 µs / 5,2 ms, 87 µs / 1,4 ms |
| `tex_mem_mb`, `fallback_sets`, `signs_missing`, `quality_lowered`, `watchdog` | 123 MB, 35, 0, „“, „“ | dieselben |

Der Kaltstart mit leerem Cache (`warmup_cold.gd`) auf 9b4be1c: `render()` im Mittel 2,54 ms, Einhängen höchstens
1,51 ms, 138 Zeichenaufrufe, 100.953 Dreiecke in der Startansicht. Die Maxima schwanken mit der Last der Maschine
(andere Aufträge liefen mit); das längere Aufwärmen ist der Preis von 2.8 (Übersetzungen, die sonst unterwegs kämen).
