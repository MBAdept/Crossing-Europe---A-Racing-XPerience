## 5. Gates auf dem Endstand `80b8141` (gemessen; Befehle und Ausgaben in `m1/FIX-R5/gates/`, `queue.log`)

Alle Läufe im Worktree, einer nach dem anderen, `nice -n 10`, `XDG_DATA_HOME` absolut unter `m1/FIX-R5/`.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, kein Fehler |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „314 Skripte geprüft, 0 fehlerhaft“ |
| Tests voll (1. und einziger Lauf) | `tools/run_tests.sh` | **„769 Tests, 0 fehlgeschlagen … ==> Tests bestanden (935 s)“** – darunter `test_bridge` 11/11, `test_tunnel` 9/9, `test_far_ground_water` 4/4, `test_props` grün, `check_terrain_plan`, `modern_sight`/`modern_path_check` (Normallauf) |
| Arcade-Identität | `tools/golden.sh check` | **„GOLDEN arcade: 20 von 20 identisch (247 s)“, „GOLDEN arcade-ui: 17 von 17 identisch (352 s)“** |
| Modern-Änderungsmelder | `KEEP=… tools/golden.sh modern-check` | **„GOLDEN modern: 6 von 6 identisch (970 s)“**; „GOLDEN modern-gles: modern_s3_hoch OpenGL ES gegen OpenGL: OK max. Abweichung 2/255, PSNR 73,2 dB“ – kein Modern-Golden geändert, darum kein `modern-make` |
| Render-Prüfungen | `tools/run_render_checks.sh all` | 19 von 20 Dateien OK; `check_tunnel_bridge` 6/6 (U1_portal 0,000 % Magenta, U1_innen 612 Leuchtenpunkte / 0,322, U1_ausfahrt 0,226 (Röhre 0,449) / 0,0 % Weiß, Somport_portal 0,000 %, B1 0,000 % / 0,00 % Fernboden / 630 Wasserflächen, beacon 4 Feuer / 4 blinken); ZS1-Wächter `check_terrain_cover` T1–T4, S1, C1, **K1 0,000 %**, `check_start_km0` OK, `check_light_base` Tageslicht/Schatten OK. **`check_instance_budget_wald`: Zeitlimit 900 s** – der bekannte Lastbefund M2S-01 der Basis (in FIX-M2s Zweig behoben, nicht in dieser Basis; R5 und QA-R5 sahen dasselbe); allein mit längerem Zeitlimit nachgeprüft: WALD_ERGEBNIS |
| Sicht voll | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | alle OK: F1 0 Fälle bis 270 m (erster bei 280 m) in 99 424 500 Stichproben, F1 Außenspuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 5923, F7 0 von 2 011 532, Modell 0 abweichend (143 s) |
| Weg voll | `… -s res://tests/sim/modern_path_check.gd -- --full` | OK: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2064 m (57 s) |
| Netzlauf genau | `… -s res://tests/race3d/render/check_tunnel_bridge.gd -- --full` | OK: 122 Brücken, 28 Tunnel, 0 Mängel (180 s) |
| ganze Etappe Modern | Abschnitt 6 | PERF_KURZ |
