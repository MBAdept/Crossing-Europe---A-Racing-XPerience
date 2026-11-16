## 7. Tore (am Kopf 9b6adbc)

| Tor | Ergebnis | Beleg |
|---|---|---|
| Arcade-Identität `tools/golden.sh check` (einmal, zum Schluss, 20:13) | **20 von 20 identisch** | `pruefungen/golden.log` |
| Fairness `modern_sight.gd -- --full`, `modern_path_check.gd -- --full` | alle CHECK OK (Abschnitt 3) | `pruefungen/sight_full.log`, `path_full.log` |
| `ERGEBNIS` Arcade gegen Modern, ganze Etappe Kiel–Hamburg unter Xvfb (Niedrig, Mittel) | 28 Schlüssel, nur `gfx` verschieden | `pruefungen/kh_*.log` |
| Render-Prüfungen der Bildlinse | alle OK: `check_terrain_cover` (T1–T4, S1, C1: 0,000 % Magenta), `check_road_parity` (Gerade 0,22 px, R 400 m 7,09 px, R 136 m 13,27 px, 16:10/21:9 gefüllt), `check_light_base` (Asphalt −6,6 %, Gras −1,8 %, Himmel −4,8 %; Schatten Aus/Mittel −0,10 %), `check_vehicle_lights` (Blinker 300 m Kern 4 × 4 / 3 × 2 px, Rücklicht N1 bei 283 m +0,137 Leuchtdichte, Bremse 50/150/300 m Rot +0,76/+0,16/+0,67), `check_occlusion` (Kuppe und Lkw 0 Pixel), `check_vehicle_standin` (alle Ersatzbilder 0–2 px und ±5 % gegen Arcade) | `pruefungen/render_*.log`, `pruefungen/*.save.log`, Bilder `pruefungen/save/` |
| `tools/run_tests.sh` | nicht selbst gelaufen (Zeit): QA-SYSTEM am selben Kopf – Einheitstests 692/0, aber der Haken der Modern-Prüfungen lief nicht, `check_facade` scheitert dort unter Last (QS-01/02) | `deliver/QA-SYSTEM/bericht.md` |
| Pflicht-Render-Prüfungen §4.9.2, die es noch nicht gibt | „Objekt an der Sichtgrenze < 3 % Kontrast“ (F4/F5), „mittlere Helligkeit / kein schwarzes Bild je Wetter × Stunde“, „OpenGL ES = OpenGL“ (hier von Hand: max 2/255, PSNR 71,8 dB – bestanden) | – |
