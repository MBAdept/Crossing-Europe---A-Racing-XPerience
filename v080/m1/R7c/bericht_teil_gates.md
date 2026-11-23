## 5. Gates (Befehle und Ausgaben; Logs in `m1/R7c/gates/`)

Alle Läufe mit absolutem `XDG_DATA_HOME` unter `m1/R7c/`, `nice -n 10`, Speicherwächter.

| Gate | Befehl | Stand | Ergebnis |
|---|---|---|---|
| Import | `godot --headless --path . --import` | @@HEAD@@ | @@IMPORT@@ |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | @@HEAD@@ | @@SCRIPTS@@ |
| Tests (1. voller Lauf) | `tools/run_tests.sh` | `965b8a9` | Exit 0 – 808 Tests, 0 fehlgeschlagen – 150 CHECK OK, 0 CHECK FEHLER (968 s) |
| Tests (2. voller Lauf) | `tools/run_tests.sh` | @@HEAD@@ | @@TESTS@@ |
| Arcade-Goldens | `tools/golden.sh check` | `965b8a9` | `GOLDEN arcade: 20 von 20 identisch`, `GOLDEN arcade-ui: 17 von 17 identisch` (einmal, wie verlangt; danach nur Modern-Dateien geändert: `baked.gdshader`, `props.gd`, Tests, Doku) |
| Modern-Goldens vorher | `KEEP=… tools/golden.sh modern-check` | `965b8a9` | `GOLDEN modern: 0 von 6 identisch` (erwartet), `GOLDEN modern-gles: … OK max. Abweichung 2/255, PSNR 73.2 dB` |
| Modern-Goldens neu | `KEEP=… tools/golden.sh modern-make` | @@HEAD@@ | @@MMAKE@@ |
| Modern-Goldens danach | `tools/golden.sh modern-check` | @@MHEAD@@ | @@MCHECK@@ |
| Render-Prüfungen | `tools/run_render_checks.sh all` | @@HEAD@@ | @@RENDER@@ |
| Sicht | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | `138c90f` | Exit 0 – 6 CHECK OK, 0 FEHLER (F1, F1 Spuren, F2, F3, F7, Modell) |
| Wege | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | `138c90f` | Exit 0 – 2 CHECK OK (Abstand ≥ 250 m, Schleifen) |
| Etappe mit Autopilot | `stage.sh` (Abschnitt 6) | `138c90f` / Basis | 4 Läufe Exit 0, 0 Fehlerzeilen, gleich schnell |
| Stufenband | `check_lod_band.gd` (in den Render-Prüfungen) | @@HEAD@@ | Barockhaus 0,6 % gegen hart 7,1 %, Eiche 1,1 % gegen 36,6 %, keine Löcher |
| Instanzbudget (A-19) | `check_instance_budget*.gd` (in den Render-Prüfungen) | @@HEAD@@ | @@BUDGET@@ |

Zwischenstand, der zur letzten Änderung führte: der erste Lauf der Render-Prüfungen (auf `965b8a9`) war in zwei
Dateien rot – `check_structures` (`zieltor`: das Schachbrett des Zielbanners verwaschen, weiß 3 % statt 6 %, durch den
Farb-Bias, der auch die Tafeln traf) und `check_props_render` (die Spiegelprobe suchte das Chalet als Sprite, das seit
AS5a2 ein Modell ist). Beides behoben in `08630e4` und einzeln nachgeprüft (`zieltor` weiß 6 %, `props_spiegel` OK),
dann der ganze Lauf auf dem Endstand.

**Modern-Goldens angesehen** (`modern_goldens_basis_r7c_differenz.jpg`: Basis | R7c | Differenz × 4): @@MLOOK@@
