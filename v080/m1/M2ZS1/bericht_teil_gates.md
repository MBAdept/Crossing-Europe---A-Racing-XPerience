## 6. Gates auf dem Endkopf `6e48405` (gemessen)

Alle nacheinander mit `m1/M2ZS1/sh/gates.sh` (`nice -n 10`, je Schritt ein eigenes absolutes `XDG_DATA_HOME`, eine
Mesa-Shader-Ablage, Export-Vorlagen in das `XDG_DATA_HOME` der Builds verlinkt), Logs `m1/M2ZS1/gates/<schritt>.log`,
Zeiten `gates/summary.txt` (14:00–15:01 UTC). Jeder Schritt Exit 0.

| Gate | Aufruf | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, 0 Fehlerzeilen (4 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | **310 Skripte geprüft, 0 fehlerhaft** |
| Kopflose Tests | `tools/run_tests.sh` (einmal voll) | **„Tests bestanden“, Exit 0, 881 s: 749 Unit-Tests, 0 fehlgeschlagen** (M2INT 735 + 6 Vorlauf + 4 Fernboden/Wasser + 2 von FIX-WASSER-R + 2 neue: Pylon-Modell, Blinktakt); 175 CHECK-Zeilen OK, 0 FEHLER; u. a. `wahrzeichen` (22 Uhr bis 1 900 m), `bruecke`, `tore`, `inhalt`, `renderer_zeit` 0,718 ms je Bild, `terrain_plan_*` (Draufsicht über `target_height()`) |
| Fairness im ganzen Netz | `godot … -s res://tests/sim/modern_sight.gd -- --full` | **6 von 6 OK** (141 s): F1 0 Fälle bis 270 m in 99 424 500 Stichproben (128 Richtungen), Außenspuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 5 923, F7 0 von 2 011 532, Kameramodell 0 Abweichungen |
| Pfad | `godot … -s res://tests/sim/modern_path_check.gd -- --full` | **2 von 2 OK** (57 s): kleinster Abstand 267,6 m, Schleifen frühestens nach 2 064 m |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **19 von 19 Dateien OK**, Exit 0 (1 384 s), 0 Shader-/Skriptfehler, kein Pufferüberlauf: `check_light_base` „schatten“ **grün** (−0,10 %; bei M2INT rot), `check_start_km0` (Kamera ≤ 1,14 px, Auto-Kanten ≤ 2 px, Boden 0,032), `check_terrain_cover` T1–T4, S1, C1 und **K1: 0,000 % Magenta, Fernboden 0,39 %** (Grenze 2 %; ZS1 0,38 %), `instanzen`, `instanzen_wald`, `check_modern_render`, `check_road_parity`, `check_occlusion`, `check_vehicle_lights`, `check_vehicle_standin`, `check_seam_render` |
| Arcade-Identität | `tools/golden.sh check` (einmal, am Schluss) | **GOLDEN arcade: 20 von 20 identisch** (139 s), **GOLDEN arcade-ui: 17 von 17 identisch** (127 s) |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` | **GOLDEN modern: 6 von 6 identisch** (369 s); **OpenGL ES** `modern_s3_hoch` gegen OpenGL: OK, max. 2/255, PSNR 73,2 dB |
| Linux-Build | `tools/build_linux.sh` (+ `pck_report.py`) | Exit 0; 496,5 MB roh, Archiv geschätzt **184,7 MB** (Warnung 300, Abbruch 330, hart 350); Modern: Modelle 18,73 / 40, Texturen 13,04 / 60, Klang 16,38 / 23, Musik 18,60 / 25 MB |
| Windows-Build | `tools/build_windows.sh` | Exit 0; Zip gemessen **194,5 MB** – wie M2INT (184,7 / 194,5 MB) |
| Rauchtest Linux | `tools/smoke_modern.sh build/CrossingEurope.x86_64 …` | **SMOKE linux: OK** – Arcade 17 s, Modern 31 s, Leistungstest „autobahn“ 9,5 Bilder/s (Software-Grafik, bedeutungslos für echte Grafik), Nutzerdaten im eigenen Ordner |
| Rauchtest OpenGL ES | `DRIVER=opengl3_es tools/smoke_modern.sh …` | **SMOKE linux_opengl3_es: OK** – OpenGL ES 3.2, Arcade 17 s, Modern 74 s, Leistungstest 9,9 Bilder/s |
| Rauchtest Windows unter Wine | `tools/smoke_modern.sh build/CrossingEurope.exe …` (wine64, eigenes Präfix, `TMPDIR` leer) | **SMOKE windows: OK** – wineboot 8 s, Arcade 20 s, Modern 34 s, Leistungstest 9,3 Bilder/s; Nutzerdaten im Präfix |
