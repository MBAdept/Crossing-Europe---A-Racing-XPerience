Alle Läufe nacheinander, `nice -n 10`, absolutes `XDG_DATA_HOME`/`TMPDIR` unter `m1/NACH-R4/`; Logs `m1/NACH-R4/gates/`
und `m1/NACH-R4/rc/`. Worktree vor und nach den Toren unverändert (`git status` leer).

| Tor | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0 |
| Arcade-Gleichheit | `tools/golden.sh check` (einmal) | **GOLDEN arcade: 20 von 20 identisch** (202 s), **GOLDEN arcade-ui: 17 von 17 identisch** (262 s) |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` (KEEP) | **GOLDEN modern: 6 von 6 identisch** (1.032 s) – FIX-R4s neuer Hash für `modern_s1_nacht` ist nachvollziehbar, die fünf Tagesbilder unverändert; **modern-gles OK** (max. 2/255, PSNR 73,2 dB); `modern_s1_nacht` angesehen (Limousine marineblau, lesbar) |
| Skripte + Einheits- und Kopfprüfungen | `tools/run_tests.sh` (Vollauf, einmal) | **319 Skripte, 0 fehlerhaft; 765 Einheitstests, 0 fehlgeschlagen; 149 CHECK-OK-Zeilen, 0 FEHLER; „Tests bestanden (950 s)“** – darin `test_far_ground_water` (4/4), `test_props`, `modern_sight` (F1 0 Fälle bis 270 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 874, F7 0, Modell 0 abweichend), `modern_path_check` (267,6 m, Schleifen ab 2.064 m) |
| Render: Nacht | `tools/run_render_checks.sh modern check_night` | `check_night.gd` **4/4 OK** (Fahrbahn N1 +4,9 %; Spielerauto: Kompakt 1,05 × / 1,23 ×, GT 0,92 × / 0,77 ×, S1-Limousine 0,88 × / 0,95 ×, DEV-Limousine 0,87 × / 1,00 ×; Verdeckung 0 Pixel; Blaulicht), `check_night_nass.gd` **2/2 OK** (nass_kegel 0,88 × / Randlinie 1,19 ×; spiegelung 0 Pixel über dem Dach, 15 darunter) |
| Render: Wetter | `… modern check_weather` | `check_weather.gd` **5/5 OK** (teilchen, gischt, nass, tunnel, schneewall ≤ 0,35 m im Netz), `check_weather_tabelle.gd` OK (Regen 22 Uhr 0,89 × / Kontrast 0,84 ×), `check_weather_tabelle_schnee.gd` OK |
| Render: geschützte Korrekturen des ersten Testbuilds | `… check_start_km0`, `check_terrain_cover`, `check_light_base` | **3/3 OK** (Kamera ≤ 1,14 px, Auto, Boden), **7/7 OK inkl. K1** (0 % Magenta), **2/2 OK** (Tageslicht, Schatten) |
| Render: Fahrzeuglichter | `… check_vehicle_lights` | **4/4 OK** (Blinker, Rücklicht N1, Bremslicht, Sichtgrenze) |
| Prüfungen gegen R4s Code | `check_night_nass.gd` (Kopf-Prüfdateien) auf der Kopie `7f0eae2` | **2/2 FEHLER** wie gewollt (1,73 × / 0,42 ×; 1.328 Pixel über dem Dach) |
| Mutationen | `m1/NACH-R4/sh/mut.py` (Kopf-Kopie) | U5, U8, R3, Profil aus, Wächter aus → jeweils rot; ohne Mutation grün |

Nicht gelaufen: `run_render_checks.sh all` (nur die Dateien der geänderten Ebenen und die geschützten Korrekturen),
`modern_sight --full` (keine Platzierung geändert – Kamera, Weg, Gelände, Verkehr unberührt; der Standardlauf in
`run_tests.sh` ist grün), keine Ganz-Etappen-Leistungsmessung (QA-M2-BILD misst die Leistung; Einzelmessung unten).
