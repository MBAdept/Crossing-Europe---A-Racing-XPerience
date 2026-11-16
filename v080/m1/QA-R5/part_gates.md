| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0 |
| Tests voll (1 Lauf) | `tools/run_tests.sh` (954 s) | 767 Einheitstests, **2 fehlgeschlagen** – beide Echtzeit-Klang: `test_engine3_checks` „thread“ (6 Aussetzer bei 6 Hauptthread-Hängern à 400 ms) und `test_music_checks` „race“; dazu **`check_attract.gd (Modern)`** „idle: Demo 0,90 s nach der letzten Eingabe (idle_s 1)“. Alle anderen Prüfungen und Szenarien OK, darunter `check_terrain_plan` (R5s behobener -s-Fehler) 3/3, `test_bridge` 10/10, `test_tunnel` 8/8, `test_far_ground_water` 4/4, `test_props` grün, `modern_sight`/`modern_path_check` (Normallauf) OK. Keine der drei berührt eine R5-Datei; Einzelläufe auf Prüfling und Basis: __RETEST__ |
| Render-Prüfungen | `tools/run_render_checks.sh modern <filter>` für `tunnel_bridge`, `start_km0`, `terrain_cover`, `light_base` | **alle OK**: U1_portal 0,000 % Magenta, U1_innen 0,000 % / 612 Leuchtenpunkte / 0,322, U1_ausfahrt 0,226 (Röhre 0,449) / 0,0 % Weiß, Somport_portal 0,000 %, B1 0,000 % / 0,00 % Fernboden / 630 Wasserflächen, beacon 4 Feuer / 4 blinken; `check_start_km0` Kamera ≤ 1,14 px, Auto, Boden OK; `check_terrain_cover` T1–T4, S1, C1, **K1 0,000 %** (ZS1-Korrektur hält); `check_light_base` Tageslicht und Schatten OK. Die Waldprüfung (`check_instance_budget_wald`, bekannter Lastbefund M2S-01) habe ich nicht wiederholt. |
| Arcade-Identität | `tools/golden.sh check` | __GOLDEN__ |
| Sicht/Weg voll | Abschnitt 3 | OK |
| Netzlauf R5 | `check_tunnel_bridge.gd -- --full` | OK (122 Brücken, 26 Tunnel, 0 Mängel, 52 s) |
| eigener Netzlauf | `qa_scan.gd` (Abschnitt 2) | 0 Befunde |
