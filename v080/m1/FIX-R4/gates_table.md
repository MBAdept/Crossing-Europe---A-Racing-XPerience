Endstand `b156763` (Code-Stand `3f00551`, danach nur die Hash-Zeile). Logs in `m1/FIX-R4/gates/`. Alle Läufe mit
absolutem `XDG_DATA_HOME`, `nice -n 10`, nacheinander (Skript `m1/FIX-R4/sh/gates.sh`; der erste Lauf der
Render-Prüfungen wurde nach drei Dateien vom Zeitlimit des Werkzeugs beendet, die übrigen 20 liefen einzeln mit
`m1/FIX-R4/sh/render_rest.sh` – dieselbe Datei-Liste, dieselben Einstellungen).

| Tor | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, ohne Fehler (`m1/FIX-R4/import.log`) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | **319 Skripte geprüft, 0 fehlerhaft** |
| Einheits- und Kopfprüfungen | `tools/run_tests.sh` (Vollauf 1 von 2) | **„Tests bestanden (1057 s)“: 765 Einheitstests, 0 fehlgeschlagen**; alle CHECK-Dateien grün (149 OK-Zeilen, 0 FEHLER), darunter `check_light_cap` „deckel“ (≤ 8 Punktlichter / 2 Spots / 18 Kegel), `kern_zeit` 0,284 ms, `renderer_zeit` 0,766 ms, `test_far_ground_water`, `test_props` |
| Arcade-Gleichheit | `tools/golden.sh check` (einmal, am Ende) | **GOLDEN arcade: 20 von 20 identisch**, **GOLDEN arcade-ui: 17 von 17 identisch** |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` | **5 von 6 identisch**, `modern_s1_nacht` ANDERS – gewollt (Nacht-Lack B3/B7); Bild angesehen (`gates/modern_keep/modern_s1_nacht_00.png`: Limousine marineblau, lesbar), Hash ersetzt (Commit `b156763`, gleich `modern-make`); **modern-gles OK** (max. 2/255, PSNR 73,2 dB) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **24 von 24 Dateien OK** (2 Arcade, 22 Modern), kein Shader-, Skript- oder Instanzfehler. Darunter: `check_night` 4/4 (Fahrbahn N1 +4,9 %, Spielerauto 4 Fälle, Verdeckung 0 Pixel, Blaulicht), **`check_night_nass` 2/2** (nass_kegel 0,88 × / 1,19 ×, spiegelung 0 Pixel über dem Dach), `check_weather` 5/5 (Schneewall im Netz ≤ 0,35 m), Tabellen (Regen 22 Uhr jetzt 0,89 × / Kontrast 0,84 ×, vorher 0,97 × / 1,17 × – B2 nimmt das falsche Licht aus dem Kegel; Grenzen 0,8 … 1,35 / ≥ 0,5), `check_start_km0` 3/3, `check_terrain_cover` 7/7 inkl. K1, `check_light_base` 2/2, `check_vehicle_lights` (F6 an N1), `check_occlusion`, `check_instance_budget_wald` (1.486 s, Grenze 2.700 s) |
| Fairness | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | **F1 0 Fälle bis 270 m** (99.424.500 Stichproben, 128 Etappenrichtungen), Außenspuren 0 bis 260 m, **F2 ≤ 0,593 / 0,596 / 0,555**, **F3 0 von 5.923**, **F7 0 von 2.011.532**, Modell 0 abweichend (150 s) |
| Weg | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | **kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000)** |
| Ganze Etappe | `tests/race/run_stage.gd` unter Xvfb, Kiel – Hamburg 21 Uhr Regen, Limousine, „Niedrig“, Zeitraffer 16 (`m1/FIX-R4/sh/stage.sh`, wie R4) | Kopf und Basis **ganz durchgefahren, 0 Skript-/Shaderfehler**, gleiches `ERGEBNIS` (95 km, Schnitt 123,4 km/h, 0 Zusammenstöße); Leistung unten |
| Geschützte Korrekturen des ersten Testbuilds | in den Läufen oben | `check_start_km0`, `check_terrain_cover` mit K1, `check_light_base`, `test_far_ground_water`, `test_props` grün |
