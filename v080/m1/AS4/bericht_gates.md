Alle schweren Läufe mit `nice -n 19`, ein Arbeitsprozess, nacheinander; jedes Spiel/Werkzeug mit eigenem absolutem
`XDG_DATA_HOME` unter dem Scratch-Ordner. Protokolle: `scratchpad/v080/m1/AS4/gates/`.

1. **Validator** – `nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/validate_models.py --report`
   ```
   validate_models: 41 Modelle, 182 Sets (53 mit Modell, 129 Platzhalter)
     Netze 4.94 MB von 40 MB, Texturen 26.85 MB im Grafikspeicher von 240 MB, Quellen 14.57 MB von 60 MB
   Modell                 Kategorie Dreiecke je Stufe                  Aufrufe        Netze B  Textur B Export s  Bake s
   props/bridge_lamp      furniture lod0 882                           1                12092         0     0.13    0.01
   props/bridge_pylon     pylon     lod0 520 lod1 520                  1/1              18457    237381     45.8    0.03
   props/bridge_truss_arch furniture lod0 1100                          1                12862     78332      1.1    0.02
   props/building_block_a city      lod0 4596 lod1 3156                2/2              82248    108170    140.1    0.03
   props/building_block_b city      lod0 5180 lod1 3476                2/2              89254    820666    144.3    0.03
   props/building_oldtown city      lod0 2326 lod1 1574                2/2              46576    504293     99.8    0.02
   props/building_shop    city      lod0 1085 lod1 757                 2/2              23690    299586     75.5    0.01
   props/building_tall    city      lod0 2485 lod1 2485                2/2              51836     92417    106.9    0.01
   props/church           rural     lod0 1731 lod1 1275                2/2              40609    551181    123.8    0.01
   props/factory          rural     lod0 1624 lod1 1108                2/2              34039    658810    116.9    0.01
   props/ferry_ship       rural     lod0 1449                          2                24361    458078     84.4    0.01
   props/house_med        rural     lod0 1343 lod1 761                 2/2              27798    484050     79.4    0.01
   props/houseboat        rural     lod0 1054                          2                19902    211040     54.3    0.00
   props/windmill         rural     lod0 1928                          2                29716    814119     51.6    0.01
   CHECK models OK
   ```
   Budget-Tabelle je Modell: oben unter „Modelle und Budgets“.
2. **Sprite-Geometrie** – `nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1`
   ```
   86 Sprite-Sets gebaut in 266 s: 86 identisch (davon 0 mit anderer Flächenreihenfolge), 0 nur Fließkomma-Rauschen, 0 verändert, 0 fehlen
   CHECK sprite_geometry OK
   ```
   kein „ANDERS“ (auch nach jedem früheren Hook-Stand: `geom1.log` 86/86).
3. **Cache-Schlüssel** – `nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys`
   ```
   CHECK cache_keys OK      41 Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung im Sprite-Katalog ergibt für genau die betroffenen Modelle einen neuen Schlüssel
   ```
4. **Zweiter, erzwungener Bake byte-gleich** – `det_mine.sh` = für jedes der 14 Modelle
   `export_models.py --only=<id> --jobs=1 --force`, danach `bake_models.gd`, `--import`, `--manifest-only`, dann `git status`:
   ```
   === vorher: 0 geänderte Dateien
   …
   Export gesamt: 1136 s
   bake_models: 14 Modelle in 0.2 s, 0 Fehler
   geschrieben: assets/models/manifest.json (41 Modelle, 182 Sets: 53 mit Modell, 129 Platzhalter)
   === git status (leer = byte-identisch)
   === Ende
   ```
   Zusätzlich (gemessen): Der Export nach der letzten Bauer-Änderung (alle 14 Schlüssel neu) lieferte für die 13
   nicht betroffenen Modelle byte-gleiche Dateien.
5. **Rennen in Modern ohne Skriptfehler** – `GFX_ARGS="--gfx-preset=high|medium" nice -n 19 tools/ab_shot.sh …` an
   drei Stellen × zwei Voreinstellungen × 12 Uhr / 19:30: 12 Läufe, 24 Bilder, 0 Treffer für
   `SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed` (Renn-Look oben).
6. **Tests** – `XDG_DATA_HOME=<scratch>/xdg_tests nice -n 19 tools/run_tests.sh` (einmal, am Ende)
   ```
   298 Skripte geprüft, 0 fehlerhaft
   692 Tests, 0 fehlgeschlagen
   CHECKS OK  (… 15 Blöcke, 141 Zeilen CHECK … OK, 0 FEHLER – u. a. modern_sight_*, terrain_plan_*, Fahrzeuge, Lampen)
   ==> Tests bestanden (841 s)
   ```
7. **Arcade-Gleichheit** – `TMPDIR=<scratch>/tmp nice -n 19 tools/golden.sh check` (einmal, am Ende)
   ```
   GOLDEN arcade: 20 von 20 identisch (160 s)
   ```
