## 6. Gates (Befehle und Ausgaben; alle mit absolutem `XDG_DATA_HOME` unter Scratch, `nice -n 10`)

Endstand `509bb16`. Die vollen Läufe (Render-Prüfungen, Goldens, `modern_sight --full`, `modern_path_check --full`) liefen
auf `e81886a`, der zweite `run_tests.sh` auf `b3f1b67`; danach kamen `7d8bbb6` (Vorrechnen bis hinter die
Wahrzeichen, Zähler – ändert nur, *wann* die Hülle gerechnet wird; sie ist reihenfolgeunabhängig, Einheitstest
`test_order_independent`) und `509bb16` (Doku). Auf dem Endstand nachgefahren: `--filter=race3d` 182 Tests / 0,
`check_scripts` 332 / 0, die sechs Streamer-Prüfungen headless, vier streamende Render-Prüfungen und zwei
Modern-Goldens **pixelgleich** zu `e81886a` (letzte Zeilen der Tabelle).

| Gate | Befehl | Ausgabe (gekürzt) | Ergebnis |
|---|---|---|---|
| Import | `godot --headless --path . --import` (auf `b3f1b67` und `509bb16`) | Exit 0, 0 Zeilen mit „error“/„warning“ | sauber |
| Skripte | `tests/check_scripts.gd` (Schritt 1 von `run_tests.sh`) | `332 Skripte geprüft, 0 fehlerhaft` | grün |
| Tests Lauf 1 | `tools/run_tests.sh` (auf `e81886a`, 1.470 s) | `811 Tests, 3 fehlgeschlagen` (test_engine3_checks, test_modern_checks, test_music_checks – Klang im laufenden Spiel); alle `CHECKS OK`, `modern_sight_f1…f7, model OK`, `modern_path_loops OK` | 3 nur unter Last: allein nachgefahren `engine3` grün, `modern`/`music` rot – **auf der Basis unter gleicher Last genauso rot** (`rerun_audio.log`, Last 14,9–16,1) → A-11 |
| Tests Lauf 2 | `tools/run_tests.sh` (auf `b3f1b67`, 1.132 s, parallel zu Render-Prüfungen) | `811 Tests, 2 fehlgeschlagen` (test_engine3_checks: „6 Hänger des Hauptthreads à 400 ms“; test_music_checks: Musik im Rennen) – alle übrigen Schritte `CHECKS OK` | dieselbe Familie, nur Last (keine Klangdatei berührt) |
| Goldens Arcade | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (329 s)`, `GOLDEN arcade-ui: 17 von 17 identisch (413 s)` | grün |
| Goldens Modern | `tools/golden.sh modern-check` | `GOLDEN modern: 2 von 6 identisch (1030 s)` – anders: `modern_start_mittel`, `modern_s3_hoch`, `modern_s4_mittel`, `modern_s1_nacht`; `GOLDEN modern-gles: … OK max. Abweichung 2/255, PSNR 73.2 dB` | gewollt, angesehen (`vergleich/goldens/`, mit `KEEP=` neu gerendert; die Basis gibt 6 von 6 identisch): `start_mittel` die Starteiche links zurück (wie Arcade), `s1_nacht` ein Busch links am Mittelstreifen, `s3_hoch` zwei ferne Bäume links, `s4_mittel` ein Baum links vor der Stadt (34.660 / 659 / 275 / 406 Pixel); **kein `modern-make`** (A-18: `modern_slice.*` gehört der Montage) |
| Render-Prüfungen | `tools/run_render_checks.sh modern <datei>` je Datei + `tools/run_render_checks.sh arcade` | alle 26 Modern-Dateien `OK` (terrain_cover T1–T4/S1/C1/K1 0,000 % Magenta, start_km0, light_base, props_render, structures, structures_licht, facade_render, instance_budget ×3, models, modern_render, night, night_nass, occlusion, quit_sound, road_parity, seam_render, session_modern, showroom_render, tunnel_bridge, vehicle_lights, vehicle_standin, weather ×3); Arcade `check_glow_occlusion OK`, `check_sprite_flip OK` | grün |
| Sicht voll | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (280 s) | `f1 OK 0 Fälle bis 270 m (99.424.500 Stichproben, 128 Richtungen)`, `f1_lanes OK`, `f2 OK 0.593 / 0.596 / 0.555`, `f3 OK 0 von 5923`, `f7 OK 0 von 2.011.532 Seiten mit Gelände über der Fahrbahn; Hülle: 0 von 388.907 Seiten nicht abgedeckt, 0 nicht als Kurvenkorridor gezählt`, `model OK` | grün |
| Pfad voll | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` (66 s) | `modern_path_clearance OK kleinster Abstand 267.6 m`, `modern_path_loops OK … nach 2064 m Weg` | grün |
| Gelände-Löcher/Nähte | `check_terrain_cover` T1–T4, S1, C1, K1 | 0,000 % Magenta an allen sieben | grün |
| Leistung | `tests/race/run_stage.gd` Kiel – Hamburg, Modern „Mittel“, Zeitraffer 40, dieser Stand und Basis | Tabelle §5: ×40 Sammeln +1,3–1,5 ms, Hook-Spitzen bis 13–14 ms (Zeitraffer: 12 Reihen je Bild); ×4 im Mittel gleich, nach dem Laden kein Nachrechnen; Draw Calls/Primitive gleich | ×4 gleichwertig; ×40-Spitzen sind der Zeitraffer (§5) |
| Endstand: Einheitstests | `godot --headless --path . -s res://tests/run_tests.gd -- --filter=race3d` (auf `7d8bbb6`) | `182 Tests, 0 fehlgeschlagen` | grün |
| Endstand: Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | `332 Skripte geprüft, 0 fehlerhaft` | grün |
| Endstand: Streamer headless | `tests/race3d/check_{facade,modern_stage,seam,terrain_plan,attract_modern,benchmark}.gd` | 8 / 8 / 10 / 3 / 4 / 8 `CHECK … OK`, 0 FEHLER | grün |
| Endstand: Render | `tools/run_render_checks.sh modern terrain_cover|seam_render|session_modern|start_km0` (auf `509bb16`) | alle vier `OK` | grün |
| Endstand: Goldens | `KEEP=… GLES_ID= tools/golden.sh modern-check modern_start_mittel` / `modern_s4_mittel` | Bild byte-gleich zu dem von `e81886a` | gleich |
| Endstand: Import | `godot --headless --path . --import` (auf `509bb16`) | Exit 0, 0 Zeilen mit „error“/„warning“ | sauber |
