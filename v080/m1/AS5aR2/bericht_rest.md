## 5. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Seed 11, Limousine, Autopilot, Verkehr eingeschwungen, fliegender Start mit 50 km/h, Bilder 2 s und 4 s nach dem Start.
Neun Läufe, alle Exit 0, 0 Zeilen `SCRIPT ERROR` / `Parse Error` / `ERROR:` in den Protokollen (gemessen).

| Lauf | Ort | Was man sieht (angesehen; Zahlen gemessen) |
|---|---|---|
| `rennen_pa_high_h22` | Paris km 387,5, Hoch, 22 Uhr | Bogenläden des Eckhauses hell und warm mit Waren hinter dem Glas (22,7 % warme Pixel gegen Arcade 28,2 %, vorher 10,9 %); Wohnfenster wie Arcade |
| `rennen_pa_high_h12` | Paris, Hoch, 12 Uhr | Haussmann-Flanke mit Bogenläden, Balkonen, Gittern; bei Tag unverändert gegen AS5a2 |
| `rennen_pa_medium_h19.5` | Paris, Mittel, 19:30 | Dämmerung: Läden beginnen zu leuchten, Fassaden lesbar |
| `rennen_be_high_h22` | Bern km 302,3, Hoch, 22 Uhr | Läden unter den Lauben leuchten; warmes Licht im Bild 2,9 / 3,7 % (vorher 2,0 / 2,7 %, Arcade 5,2 / 5,0 %) |
| `rennen_am_high_h12` | Amsterdam km 357,3, Hoch, 12 Uhr | Grachtenhäuser wie vorher (bei Tag unverändert) |
| `rennen_ly_out_high_h12` | Lyon-Vorort km 285,6, Hoch, 12 Uhr | Südhäuser mit Blattkrone statt Kugeltraube |
| `rennen_hh_high_h22` | Hamburg km 88,2 (Kiel – Hamburg), Hoch, 22 Uhr | Charge 1: Giebelhäuser und Läden nachts; der weiße Laden in der Mitte ist AS4s `building_shop` (nicht diese Charge) |
| `rennen_br_medium_h19.5` | Brüssel km 195,5, Mittel, 19:30 | Lütticher Reihe und Maashaus in der Dämmerung, Café-Licht |
| Clip `fahrt_paris_50kmh.mp4` | Paris ab km 387,6, Hoch, 12 Uhr, 50 km/h, 10 s, 60 fps | Haussmann-Flanke zieht mit Läden und Balkonen vorbei; Arcade zeigt dort eine flache Fassade (Standbilder `fahrt_paris_50kmh_standbilder.jpg`) |

Nicht den Modellen anzulasten (unverändert gegen die Kritik): In den Vororten fehlen in Modern die niedrigen
Garten- und Backsteinmauern der Szenerie (`fence`, Bauer `city` von R6) und einzelne Bäume (Kurvenkorridor, FIX-M2
B-01) – beides ist im Zusammenbau RINT-M2.

## 6. Gates (Endstand HEADCOMMIT; Befehle und Ausgaben in `m1/AS5aR2/logs/`)

Die Gates liefen auf 047e10f (alle Modelle, Code und Katalog wie im Endstand). Danach kamen nur noch die neuen
Modern-Hashes (89ccc33, nach `modern-make`) und ein Doku-Absatz (216ac5c) dazu; beide liest kein Test (`grep` in
`tests/` und `tools/run_tests.sh`: `modelle.md` nur in Kommentaren, `modern_slice` nur in `tools/golden.sh`).

| Gate | Befehl | Ergebnis |
|---|---|---|
| Prüfer | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (Netze 19,81 MB von 40, Texturen 79,37 MB von 240 im Grafikspeicher) |
| Budgettabelle | `py/budget_r2.py` (Abschnitt 4 / docs Abschnitt 22) | alle 23 ≤ 10 000 Dreiecke lod0, 2 Aufrufe je Stufe |
| Sprite-Geometrie | `check_sprite_geometry.py --only props --jobs 1` | GEOMRESULT |
| Cache-Schlüssel | `export_models.py --check-keys` | KEYSRESULT |
| Determinismus | zweiter erzwungener Export + Bake von Südhaus (Blattkarten), Chalet (Geranien), Maashaus | alle drei **BYTEGLEICH** (Ordner- und GLB-Hash vorher = nachher; `git status` 0 Dateien) |
| fremde Modelle | Brückenlampe, Pylon, Pylon ohne Seile, Fachwerkbogen, Hausboot neu exportiert (Schlüssel enthält `props_cities.py`) | byte-gleich (`git status` 0 Dateien); AS4-Häuser: Schlüssel unberührt (kein geteilter Code geändert) |
| Rennen in Modern | `tools/ab_shot.sh` an fünf Ankünften (Paris, Bern, Amsterdam, Brüssel, Hamburg) + Lyon-Vorort, Hoch und Mittel, 12 / 19:30 / 22 Uhr | 9 Läufe Exit 0, 0 Fehlerzeilen |
| Tests | `tools/run_tests.sh` | TESTSRESULT |
| Arcade | `tools/golden.sh check` | GOLDENRESULT |
| Modern-Goldens | `tools/golden.sh modern-check` | MODERNRESULT |
| Archivanteil | Rechnung von `tools/pck_report.py` (deflate -9 je Datei, ohne Build: `py/share.py`) | Charge 2: 0,98 MB Netze, 5,91 MB Texturen (Grenze 3 / 7 MB); Charge 1: 0,82 / 5,35 MB |
