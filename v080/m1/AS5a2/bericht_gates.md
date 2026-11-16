## 6. Gates (auf dem Endstand, Befehle und Ausgabe; alle `nice -n 19`, eine Instanz)

| Gate | Befehl | Ergebnis |
|---|---|---|
| Prüfer | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (am Endstand 3c5e37a wiederholt, Exit 0) – 110 Modelle, 183 Sets (128 mit Modell, 55 Platzhalter); Netze 19,76 MB von 40 MB, Texturen 78,70 MB im Grafikspeicher von 240 MB, Quellen 36,27 MB von 60 MB (gemessen) |
| Sprite-Geometrie | `python3 tools/blender/check_sprite_geometry.py --only props --jobs 1` | `86 Sprite-Sets gebaut in 261 s: 86 identisch (davon 0 mit anderer Flächenreihenfolge), 0 nur Fließkomma-Rauschen, 0 verändert, 0 fehlen` – `CHECK sprite_geometry OK`, kein ANDERS |
| Schlüssel | `export_models.py --check-keys` | `CHECK cache_keys OK` – 110 Modelle, Exit 0 |
| Determinismus | zweiter erzwungener Export (`--force`) von Maashaus, Chalet, Südhaus | alle drei `BYTEGLEICH` (GLB und Modellordner: Maashaus 6d0ae262c586 / 32d0bedd255d, Chalet 66a192e94d8e / 248aada57c3e, Südhaus f3f4c9fc0d96 / b4ca7fcfa062; `git status assets/models` danach leer); außerdem kamen beim Export der Runde 5 neun eigene Modelle (ohne Inhaltsänderung) byte-gleich heraus |
| Charge 1, Brücken, Hausboot | beide Code-Stände (93e5031, 771b079) neu exportiert, `git status` | 0 geänderte Dateien (16 Modelle byte-gleich, zweimal) |
| AS4-Häuser | `git diff --stat 7153381..HEAD` über alle Schlüssel-Eingaben des Bauers `house` (`COMMON_CODE` + `buildings3d.py`, `props3d.py`, `bake.py`, `leafatlas.py`, `props.py`, `props_buildings.py`, `render_all.py`) und über die Modellordner seiner elf Modelle (AS4-Häuser, Fähre, Hausboot) | leer: Schlüssel und Dateien byte-gleich; `catalog3d.py` nur um Zeilen ergänzt (0 entfernte Zeilen) |
| Rennen | `tools/ab_shot.sh` an fünf Ankünften, 13 Läufe | 13 Läufe Exit 0, 0 Zeilen `SCRIPT ERROR`/`Parse Error`/`ERROR:` in 26 Logs (Abschnitt 7) |
| Tests | `tools/run_tests.sh` | `749 Tests, 0 fehlgeschlagen`, 16 Prüfsuiten `CHECKS OK`, `==> Tests bestanden (961 s)`, Exit 0 (einmal, am Ende) |
| Arcade-Identität | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (193 s)`, `GOLDEN arcade-ui: 17 von 17 identisch (242 s)`, Exit 0 |
| Modern-Goldens | `tools/golden.sh modern-check` | `GOLDEN modern: 6 von 6 identisch (742 s)`, `GOLDEN modern-gles: modern_s3_hoch … OK max. Abweichung 2/255, PSNR 73.2 dB`, Exit 0 – kein Modern-Golden geändert (Kiel–Hamburg zeigt keine Häuser dieser Charge), daher kein `modern-make` |
| Archivanteil | Schätzung wie `tools/pck_report.py` (deflate -9 je Datei, ohne Build) | Netze 0,93 MB, Texturen 5,79 MB (Grenze der Charge 3 / 7 MB) |
