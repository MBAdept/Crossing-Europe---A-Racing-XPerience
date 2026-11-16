# AS4 – Landgebäude, Brückenteile und Schiffe für „Modern“ (Bericht)

Paket **AS4** von v0.8.0 „Modern“. Zweig `worktree-wf_aad8d49e-fb4-2` (gesichert als `origin/wip/v080-as4`), Basis
`8f58b2d`, Stand `9eef9a8`. Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2`.
Zahlen sind mit **(gemessen)** oder **(gefolgert)** markiert. Alle Bilder: Software-OpenGL (llvmpipe) unter Xvfb –
Aussagen über echte Grafikkarten und das Steam Deck sind gefolgert.

## Kurzfassung

Vierzehn Echtzeit-Modelle für den Modus „Modern“, alle aus den Sprite-Generatoren (die Sprites sind der Look):
Haus (`house_med`), Kirche, Fabrik, Ladenhaus, Altstadthaus mit Treppengiebel, Wohnblock A und B, Büroturm,
Hausboot, Fähre, Brückenlaterne, Pylon der Schrägseilbrücke, Fachwerkportal – und die Windmühle von AS1b mit echten
Fensteröffnungen statt gemalter Fenster (der einzige Mangel, den AS1b dort nennt). Weitere Land- oder Straßen-Sets ohne
Modell gibt es nicht (Zählung über das ganze Netz, `census_all`).

Neu: der Gebäudebauer `house` (`ce3d/buildings3d.py`) mit geschnittenen Öffnungen (Laibung, Rahmen, Sprossen,
Sohlbank, Scheibe), Türen mit Stufen, Läden, Schallluken, Uhren, Rinnen und Fallrohren, Werkszeichen, Vorhangfassade,
Lochfüller-Bake und Flutlicht; die Brückenbauer `pylon`, `truss`, `lantern` (`ce3d/bridges3d.py`). Alle Budgets
eingehalten (gemessen, Tabelle). Drei Runden; die dritte (voller Export, Renn-Look, Spielkamera, Messung) behob den
Farbsprung beim Stufenwechsel, den Lisenen-Sprung des Büroturms, die zu geringe Dichte am Pylonfuß, grüne Lichtflecken
der Fähre und die Spiegelschrift der Fabrik am linken Fahrbahnrand.

**Alle Gates grün** auf `9eef9a8` (gemessen): Validator OK, Sprite-Geometrie 86 von 86 identisch, `--check-keys`
OK, zweiter erzwungener Export aller 14 Modelle byte-gleich, 12 Modern-Rennläufe ohne Skriptfehler,
`run_tests.sh` bestanden (692 Tests, 141 Checks, 0 Fehler), `golden.sh check` 20 von 20 identisch.
**Schwächstes Modell: die Fähre** (gemalte Kabinenfenster, flache Aufbauten).

## Modelle und Budgets (gemessen: `validate_models.py --report`, `model.json`, Export-Bericht)

| Modell | Kategorie (Budget Dreiecke / Aufrufe) | Dreiecke je Stufe | Aufrufe | Netze | Texturen | Atlas | px/m* | Export**** |
|---|---|---|---|---|---|---|---|---|
| `house_med` | Land (2 000 / 2) | lod0 1 343 · lod1 761 | 2/2 | 27,8 kB | albedo 484 kB | 1024² | 59,9 | 79 s |
| `church` | Land (2 000 / 2) | lod0 1 731 · lod1 1 275 | 2/2 | 40,6 kB | albedo + emit 551 kB | 1024² | 30,0 | 124 s |
| `factory` | Land (2 000 / 2) | lod0 1 624 · lod1 1 108 | 2/2 | 34,0 kB | albedo + emit 659 kB | 1024² | 29,5 | 117 s |
| `windmill` (AS1b, Fenster) | Land (2 000 / 2) | lod0 1 928 | 2 | 29,7 kB | albedo 814 kB | 1024² | 31,2 | 52 s |
| `houseboat` | Land (2 000 / 2) | lod0 1 054 | 2 | 19,9 kB | albedo 211 kB | 1024×512 | 37,3 | 54 s |
| `ferry_ship` | Land (2 000 / 2) | lod0 1 449 | 2 | 24,4 kB | albedo + emit 458 kB | 1024² | 12,2** | 84 s |
| `building_shop` | Stadt (10 000 / 2) | lod0 1 085 · lod1 757 | 2/2 | 23,7 kB | albedo + emit 300 kB | 1024² | 44,2 | 76 s |
| `building_oldtown` | Stadt (10 000 / 2) | lod0 2 326 · lod1 1 574 | 2/2 | 46,6 kB | albedo + emit 504 kB | 1024² | 40,7 | 100 s |
| `building_block_a` | Stadt (10 000 / 2) | lod0 4 596 · lod1 3 156 | 2/2 | 82,2 kB | albedo 108 kB | 2048×1024 | 49,0 | 140 s |
| `building_block_b` | Stadt (10 000 / 2) | lod0 5 180 · lod1 3 476 | 2/2 | 89,3 kB | albedo 821 kB | 2048×1024 | 44,0 | 144 s |
| `building_tall` | Stadt (10 000 / 2) | lod0 2 485 · lod1 2 485 | 2/2 | 51,8 kB | albedo + emit 92 kB | 2048×1024 | 29,8 | 107 s |
| `bridge_lamp` | Möbel (1 500 / 1) | lod0 882 | 1 | 12,1 kB | – (vpbr) | – | – | 0,1 s |
| `bridge_pylon` | Mast (5 000 / 1) | lod0 520 · lod1 520 | 1/1 | 18,5 kB | albedo + emit 237 kB | 1024² | 29,9*** | 46 s |
| `bridge_truss_arch` | Möbel (1 500 / 1) | lod0 1 100 | 1 | 12,9 kB | albedo + emit 78 kB | 1024×512 | 28 (Bild) | 1,1 s |

\* Texeldichte der Wände zur Straße (Gewicht 1; Rückseiten und Dächer mit den Gewichten des Katalogs weniger).
\*\* Modellmaß: die Fähre steht im Spiel mit Maßstab 0,33–0,45 → 27–37 px je Bildschirm-Meter (gefolgert).
\*\*\* am Fuß (0–30,75 m), Mitte 17,9, Kopf 13,4 px/m.
\*\*\*\* Blender-Export mit Bake (Cycles, 2× Überabtastung, 16 Proben, Verdeckung 24 Proben) im erzwungenen zweiten
Lauf, `nice -n 19`, ein Prozess, zwei Render-Threads; der Godot-Bake braucht je Modell ≤ 0,05 s.
Netze 0,49 MB, Texturquellen 5,07 MB für alle 14 Modelle; Texturen im Rahmen: Land/Möbel/Mast ≤ 1024, Stadt ≤ 2048.
Emission jeweils halbe Größe des Albedo. Summe AS4: Netze 0,49 MB, Texturquellen 5,07 MB (gemessen); alle Modelle
des Manifests zusammen innerhalb der Gesamtgrenzen (Validator: `CHECK models OK`).


## Runden (bauen → Tag/Nacht ansehen → Mängel → beheben)

**Runde 1 – Gebäudebauer, acht Gebäude (Vorschau-Bake, halbe Auflösung).**
- Heller Saum um jedes Fenster ab etwa 60 m (gemessen im Bogen: die Dilatation füllte die Löcher des Atlas mit der
  Rahmenfarbe, die Mipmaps mischten sie in die Wand) → **Lochfüller-Bake**: jedes Loch wird für den Farb-Bake mit dem
  gemalten Fenster des Sprites geschlossen, vor der Verdeckung wieder entfernt.
- Licht-Krümel nachts neben Rundbogenfenstern (Sehnen des Bogenpolygons ließen gemaltes Fenster stehen) → das
  Polygon **umschreibt** den Kreis; gemalte Splitter (15 cm eines fünften Fensters am Kirchenschiff, angeschnittene
  oberste Reihe von Block B) über Hooks entfernt.
- Öffnungen im Kirchturm übersprungen (Hüllquader-Test von AS1b: der Turm „steckt“ im Schiff) → Strahl entlang der
  Wandnormale je Öffnung (`Cover`).
- 55 Lichtanker an der Fabrik (Oberlichter als Lampen) → `baked_lamps` (Licht im Nachtlicht-Atlas, kein Anker).
- Kirche ohne Fallrohre (Wanderkennung des alten Bauers) → eigene Rinnen/Fallrohre an benannte Wände.

**Runde 2 – Brückenteile, Schiffe, Mühle.**
- Hausboot: Exporter brach ab (`props_cities.lace_mat` ohne `ce_role`) → Ausschneide-Materialien ohne Rolle werden
  `proc`; 2 914 Dreiecke (Budget 2 000) → Topfpflanzen dezimiert, Ausschneide-Geländer als Pfosten und Holme: 1 054.
- Pylon und Fähre mit 12 bzw. 5,6 px/m (eine 82-m- bzw. 182-m-Karte bestimmt die Atlasdichte) → Höhenbänder bzw.
  Schnittebenen: Pylon 21,8, Fähre 12,2 px/m (Modellmaß; im Spiel mit Maßstab 0,33–0,45 → 27–37 px/m auf dem
  Bildschirm, gefolgert).
- Mühle 2 072 Dreiecke → Öffnungen nur in vier Flächen des Achtecks: 1 928.
- Laternenglas bei Tag hellbraun (vpbr-Lampe zeigt unbeleuchtet die halbe Leuchtfarbe) → Seiten als angestrahlte
  Fläche (Kanal 14), nur die Unterseiten Lampen mit Ankern.
- Validator: „Stufe lod1 ist für die Kategorie … nicht vorgesehen“ (9 Fehler) → `lod1`-Budget in `validate_models.py`.

**Runde 3 – voller Export, Renn-Look, Spielkamera, Messung.**
- Renn-Look (A/B Kiel–Hamburg km 75,8, hoch, 12 Uhr): Pylone, Fähren, Altstadt, Haus erscheinen wie im Sprite,
  keine Skriptfehler.
- Pylon am Fuß neben der Fahrbahn nur 21,8 px/m → Texeldichte folgt der Höhe (`band_w` 1 / 0,6 / 0,45): **29,9 px/m**
  am Fuß, 17,9 px/m Mitte, 13,4 px/m Kopf (gemessen, Bake-Statistik).
- Fähre: drei grüne Lichtflecken nachts, zwei davon an weißen Lichtern (`roles.lights()` gibt allen Ankern einer Rolle
  die Farbe der ersten Lampe) → Positionslichter ohne Anker (ein Signallicht beleuchtet kein Deck).
- Stufensprung gemessen (`prop_scene --mode=lods`, eigenes Maß `pop.py`): Wohnblöcke in lod1 um 8/255 dunkler (Rahmen
  und Sprossen fehlten ersatzlos), Büroturm 18 % der Pixel geändert (Lisenenseiten nur in lod0), Pylon 7 % (Seile
  0,24 → 0,4 m) → lod1 bekommt einen **Rahmenring mit der Fläche von Rahmen + Sprossen** (`_far_inset`),
  Lisenenseiten bleiben in lod1, Seile 0,28 / 0,34 m. Werte danach siehe Messungen.
- Renn-Look Bremen–Dortmund (A/B, km 2,9): der Schriftzug „WERK 2“ der Fabrik stand am linken Fahrbahnrand in
  **Spiegelschrift** (das Set trägt `mirror_left`, der Requisiten-Builder spiegelt es dort, D24) → Werkszeichen ohne
  Schrift: Zahnrad zwischen Balken, spiegelsymmetrisch (`_gear_logo`); lod0 1 840 → 1 624 Dreiecke.


## Messungen

**Stufensprung** (gemessen, `prop_scene --mode=lods`, Spielkamera, gleicher Ausschnitt bei der Umschaltentfernung
60 m = Detailstufe „mittel“; `pop.py`: Anteil der Pixel, die sich um mehr als 24/255 ändern, und mittlere Farbe):

| Modell | vorher (Runde 2) | nachher | mittlere Farbe lod0 → lod1 nachher |
|---|---|---|---|
| `house_med` | 1,05 % | 0,91 % | (194,174,133) → (196,176,133) |
| `church` | 0,41 % | 0,36 % | (198,201,201) → (200,202,202) |
| `factory` | 0,00 % | 0,00 % | (153,154,155) → (153,154,155) |
| `building_shop` | 0,97 % | 0,68 % | (184,185,186) → (183,184,185) |
| `building_oldtown` | 1,84 % | 1,53 % | (216,168,144) → (217,168,143) |
| `building_block_a` | 5,72 % (8/255 dunkler) | 4,51 % | (185,181,158) → (184,180,157) |
| `building_block_b` | 6,36 % (8/255 dunkler) | 5,24 % | (158,127,117) → (157,126,116) |
| `building_tall` | 18,15 % | 0,00 % | (117,137,160) → gleich |
| `bridge_pylon` | 7,41 % (+22 % Fläche) | 3,16 % (+9 %) | (240,243,246) → (242,244,247) |

Die mittlere Farbe springt nirgends mehr um mehr als 2/255; was bei den Wohnblöcken bleibt, sind die Sprossenkreuze
(4,5 cm, bei 60 m 0,5 px), die in lod1 fehlen. Bei „hoch“ schaltet der Requisiten-Builder erst bei 120 m um (Sprosse
0,27 px), bei „niedrig“ bei 40 m (gefolgert aus `prop_lod0_m`). Jenseits von 200 m bleibt lod1 (keine Impostoren für
Gebäude – wie bei AS1b), also kein zweiter Sprung.

**Gitter und Seile** (gemessen in den Spielkamera-Bildern, gefolgert für Bewegung): das Fachwerk ist ein
mipmap-festes Ausschneidebild (Streben ≥ 2,5 Texel) und bleibt bis 400 m als Fachwerk lesbar; die Seile (Prismen,
0,28/0,34 m) sind bei 400 m 0,6 px breit – mit MSAA (mittel 2×, hoch 4×) eine durchgehende schwache Linie, bei
„niedrig“ (ohne MSAA) können sie flimmern (nicht gemessen: Software-Renderer, Standbilder).

**Nacht** (Kontaktbögen, Spielkamera): Fenster leuchten unregelmäßig nach dem Anteil `lit` des Sprite-Rasters
(Büroturm 300 von 840 Scheiben, gemessen); Kirchturm mit Flutlicht und beleuchteten Uhren (3); Fabrik mit kaltweißem
Hallenlicht, Oberlichtern und beleuchtetem Werkszeichen (Zahnrad, spiegelsymmetrisch); Fähre mit Kabinenfenstern, Bullaugen, Decklampen und
Positionslichtern; Laterne (3 Anker), Fachwerkportal (2 Anker), Pylon (Flugbefeuerung). Bei Tag leuchtet nichts
(Emission × `ce_night`; unbeleuchtete Lampen zeigen nur ihre halbe Leuchtfarbe als Glasfarbe).


## Brückenteile: Maße und Anschlusspunkte (für R5)

**Gemessen** am Generatornetz (`cesprites/props_cities.py`, unverändert) und an `model.json` der Modelle. Angaben im
Modellraum des Manifests (Godot: +X quer, +Y oben, −Z = Blender +Y entlang der Fahrbahn); Ursprung = Fußpunkt.

**`props/bridge_pylon`** – ein Bein (die Brücke stellt zwei; Arcade bei x = ±7,5 m von der Fahrbahnmitte)
- Fuß auf Fahrbahnhöhe (Requisiten-Builder: Teile mit „bridge“ bei h = 0 = Deck). AABB x −6,62…3,00, y 0…88,75,
  z ±82,69 m.
- Bein: 4,4 × 6,0 m am Fuß → 2,7 × 3,6 m bei 82 m, 3,5° zur Fahrbahn geneigt (Kopf bei x ≈ −5,0 m). Kopf bis
  83,2 m, Kappe bis 88,0 m. Flugbefeuerung: Anker (−5,47 | 88,30 | 0), Richtung (−1, 0, 0), rot, ohne Lichtfleck
  (`BEACON_MIN_H_M` 25).
- Seile: 10 je Seite. Kopfanker y = 79,0 − 2,6·k m (k = 0…9), x ≈ −5,1…−4,4 m, ±0,6 m entlang der Fahrbahn;
  Deckanker x = −4,2 m, y = 0,6 m, entlang der Fahrbahn ±(16,0 + 7,4·k) m = ±16,0…±82,6 m. Seilstärke lod0 0,28 m,
  lod1 0,34 m (vierseitige Prismen).
- Feste Höhe (Sprite). Arcade zeichnet den Pylon prozedural mit `height_m` der Brücke (50–120 m); der
  Requisiten-Builder skaliert Modelle nicht nach `height_m` → Vertragsfrage. Zieht R5 die Seile selbst (bis zum
  echten Deckrand), braucht es einen Pylon ohne Seile: eine Katalogzeile mit `cables` auf ein leeres Präfix.

**`props/bridge_truss_arch`** – Portal über der Fahrbahn
- Objekt 32,4 × 15,6 × 1,8 m; AABB x ±16,5, y −0,1…15,9, z −2,25…0,45 m. Zwei Fachwerkebenen 1,8 m hintereinander
  (z = 0 und z = −1,8 m).
- Pfosten innen x = ±14,7 m, außen ±15,9 m → lichte Weite 29,4 m; Untergurt im Scheitel 13,2 m, Obergurt 15,3 m.
- Der Requisiten-Builder skaliert gleichmäßig mit `fit_w / 32,4` (Fahrbahnbreite) – alle Maße skalieren mit.
- Hängelampen: Anker (±5,0 | 10,79 | −0,9), Richtung nach unten, Lichtfleck auf der Fahrbahn.

**`props/bridge_lamp`** – Laterne am Geländer
- AABB x ±1,18, y 0…4,83, z ±0,36 m; Säule 3,82 m.
- Drei Laternen: Anker (±0,92 | 4,12 | 0) und (0 | 3,96 | 0), Richtung nach unten, Farbe #ffd890.


## Gates (auf dem Endstand `9eef9a8`)

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


## Geänderte gemeinsame Dateien (alle rückwärtskompatibel, additiv)

| Datei | Änderung |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | ein Block `# --- AS4 ---`: `BUILDER_CODE` für `house`, `pylon`, `truss`, `lantern`; `AO_TOWN`; die 14 Katalogzeilen (die Mühle als Ersatz der AS1b-Zeile). Ein einziger Diff-Abschnitt, nichts Bestehendes geändert. |
| `tools/blender/export_models.py` | `BUILDERS`/`COST` um die vier Bauer ergänzt (Block `# --- AS4 ---`). |
| `tools/blender/validate_models.py` | `lod1`-Budget = `lod0`-Budget für `rural`, `city`, `pylon` (explizite Detailstufe statt „auto“, siehe Abweichungen). Bewusst nicht in `ce3d/manifest.py` (Teil jedes Cache-Schlüssels). |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`). |
| `docs/modelle.md` | Abschnitt 15 (neu). |

Eigene Dateien: `tools/blender/ce3d/buildings3d.py`, `tools/blender/ce3d/bridges3d.py` (neu), Hooks in
`cesprites/props_buildings.py` und `cesprites/props_road.py` (Voreinstellung = Sprite, kein Sprite-Vertex bewegt:
Geometrie-Gate), `assets/models/props/<14 Modelle>/`. Nicht angefasst: `props3d.py` (Schlüssel von AS1b/AS3), Renderer,
Shader, Fahrzeuge, AS3-Dateien, `city_*`, Wahrzeichen, eingefrorene Arcade-Dateien.

## Renn-Look (A/B Arcade | Modern, `tools/ab_shot.sh`)

Drei Stellen, gefunden mit der Zählung über das ganze Netz (`census_all`) und der Lage je Etappe (`positions.gd`);
je Stelle „hoch“ und „mittel“, 12 Uhr und 19:30 (Dämmerung), je zwei Bilder (gemessen, Software-OpenGL):

| Stelle | Etappe, Start | sichtbar (AS4) | Modern-Lauf hoch / mittel |
|---|---|---|---|
| P1 | Kiel–Hamburg ab Kiel, km 75,8, 50 km/h, Bilder bei 1 s und 6 s | Haus, Altstadthäuser, Pylone der Köhlbrandbrücke, zwei Fähren | 506 / 514 s (12 Uhr), 483 / 360 s (19:30) |
| P2 | Kiel–Hamburg ab Kiel, km 82,9, Bilder bei 1 s und 5 s | Fachwerkportale der Elbbrücken (mit Lampen), Ladenhäuser | 360 / 373 s, 380 / 264 s |
| P3 | Bremen–Dortmund ab Dortmund, km 1,9, 100 km/h, Bilder bei 1 s und 3 s | Fabrik (links, gespiegelt), Wohnblöcke B | 281 / 176 s, 248 / 132 s |

Alle 12 Modern-Läufe (24 Bilder) ohne `SCRIPT ERROR`, `Parse Error` oder `SHADER ERROR` (gemessen, `ab_shot.sh`
prüft das Protokoll; `XDG_DATA_HOME` je Lauf unter dem Scratch-Ordner). P1 und P2 „hoch, 12 Uhr“ entstanden vor dem
Werkszeichen-Commit – die dort sichtbaren Modelle sind im Endstand byte-gleich. Befund: Die Modelle stehen dort, wo
Arcade seine Sprites zeichnet, in Größe und Farbe wie das Sprite; bei Dämmerung leuchten die Fenster der
Altstadthäuser und die Lampen der Portale. Gefunden und behoben: der gespiegelte Schriftzug der Fabrik (P3, siehe
Runde 3). Was sonst auffällt, gehört nicht zu AS4: Arcade zeichnet die seitlichen Fachwerkträger der Elbbrücken
(Brückenbauer R5) und die Hamburger Wahrzeichen im Hintergrund anders (Wahrzeichen-Pakete).

## Abweichungen

- **lod1 der Gebäude und des Pylons explizit statt „auto“:** Der Vertrag nennt für Land-/Stadtgebäude und Masten eine
  automatische zweite Stufe, Nachtrag A-4 verbietet automatische Stufen auf Netzen mit Lampenkanälen – jedes Gebäude
  hat leuchtende Scheiben. lod1 ist deshalb die Detailstufe des Generators (D21: ohne Sprossen, Sohlbänke, Rinnen,
  Lamellen; mit Rahmenring gleicher Fläche), Budget = lod0-Budget (`validate_models.py`).
- **Fähre unter „Landgebäude“** (2 000 Dreiecke, Atlas 1024): Kabinenfenster bleiben gemalt (siehe Einordnung).
- **Keine Vordächer über Türen, keine Schornsteine am Haus:** Die Sprite-Entwürfe haben keine (Haus ohne Kamin, Tür
  nur hinten); die Sprites sind der Look. Türen haben Stufen, das Ladenhaus seine Markise, die Fabrik ihren Schlot.
- **Windmühle:** Die vier Fenster sitzen in der Mitte von vier Achteckflächen statt im gemalten Raster (das über
  einer Ecke lag); Hook `win3d` nimmt die gemalten Fenster nur im 3D-Bau heraus.
- **Positionslichter der Fähre ohne Lichtanker** (leuchten nur): siehe Vertragsfragen (`roles.lights()`).

## Vertragsfragen

- **Dateihoheit Brückenteile/Hausboot:** `bridge_lamp`, `bridge_pylon`, `bridge_truss_arch` und `houseboat` werden in
  `cesprites/props_cities.py` erzeugt (Datei der Stadtpakete). Ohne Eingriff gelöst: die Bauer lesen das Generatornetz
  zurück (`bridges3d.boxes()`), `props_cities.wallmat` wird während des Baus von außen umhüllt. Der Schlüssel dieser
  Modelle hängt an der ganzen Datei – jede Änderung der Stadtpakete exportiert sie neu (deterministisch, kostet Zeit).
- **`props_cities.lace_mat` ohne `ce_role`:** der Exporter brach ab; `buildings3d._route` setzt für Materialien mit
  Ausschneidemaske `proc`. Besser im Generator (Hook der Stadtpakete).
- **`roles.lights()` (Kern, nicht meine Datei):** alle Anker einer Rolle bekommen die Farbe der ersten Lampe dieser
  Rolle – an der Fähre warfen die weißen Toplichter grüne Lichtflecken. Gruppierung nach (Rolle, Farbe) würde es
  lösen; ändert den Schlüssel aller Modelle, darum hier nur umgangen.
- **Kein Budget „Schiff“:** eine 182-m-Fähre als `building` ohne `city` = Landgebäude (2 000 Dreiecke, 1024er Atlas).
- **Lampenkanal 12 bei Tag:** eine unbeleuchtete Lampe zeigt die halbe Leuchtfarbe (Milchglas hellbraun). Hier über
  Kanal 14 gelöst; eine Rolle „Glas“ (Tag eigene Farbe, Nacht leuchtend + Anker) wäre sauberer.
- **Pylonhöhe:** Arcade zeichnet den Pylon prozedural mit `height_m` der Brücke (50–120 m), das Modell hat die feste
  Höhe des Sprites (88,8 m); der Requisiten-Builder skaliert Modelle nicht nach `height_m`.

## Bedarf bei anderen Paketen

- **R5 (Brücken):** Maße und Anker oben. Wasser fehlt noch: Hausboot und Fähre stehen auf Wasserhöhe über dem
  Gelände. Zieht R5 die Seile selbst, eine Katalogzeile für einen Pylon ohne Seile.
- **R2/R7 (Requisiten-Builder):** `height_m` des Pylons auswerten (Skalierung in der Höhe); Fähre nie spiegeln (Bug
  nach +X).
- **R4 (Nacht):** Scheibenlicht ist auf `lamp_off_props` 0,5 und `lights_energy` 4 abgestimmt (Leuchtfarbe = Licht des
  Sprites × 0,47); Kirchturm-Flutlicht, Fenster der Fähre und Oberlichter der Fabrik leben im Nachtlicht-Atlas
  (`emit_energy` 1,6).
- **Kern (`roles.py`):** Ankerfarbe je Lampengruppe statt je Rolle.
- **AS5a/AS5b (Stadt):** `buildings3d` schneidet auch Wände aus `props_cities` (Fensterlog von außen, Raster als
  Rechtecke, Türen aus Rastern der Art `door`), mit Lochfüller-Bake und lod1-Rahmenring – direkt für die Stadthäuser
  nutzbar.

## Ehrliche Einordnung

**Gut**
- Haus, Kirche, Fabrik, Altstadthaus, Ladenhaus und die Wohnblöcke sehen aus wie ihre Sprites (Farben, Proportionen,
  Fensterraster, Markise, Treppengiebel, Sägezahndach, Schlot) und haben echte Tiefe: Laibungen 12–30 cm, Rahmen,
  Sprossen, Sohlbänke, Türen mit Füllungen und Stufen, Fensterläden, Rinnen und Fallrohre, Schallluken, Uhren.
- Nachts leuchten die Fenster unregelmäßig nach dem Anteil des Sprite-Rasters; Kirchturm (Flutlicht, Uhren), Fabrik
  (Hallenlicht, Oberlichter, Werkszeichen), Fähre (Kabinen, Bullaugen, Decklampen), Laterne und Portal (Lichtanker mit
  Lichtfleck). Bei Tag leuchtet nichts.
- Budgets mit Abstand eingehalten (Land höchstens 1 928 von 2 000, Stadt höchstens 5 180 von 10 000, Möbel 1 100 von
  1 500, Mast 520 von 5 000; zwei bzw. ein Aufruf). Stufenwechsel ohne Farbsprung (≤ 2/255, gemessen).
- Der Bauer `house` ist allgemein: AS5a/AS5b können ihn für die Stadthäuser nutzen (Wände aus `props_cities`).

**Noch nicht gut**
- **Fähre – das schwächste Modell.** Kabinenfenster und Bullaugen sind gemalt (12,2 px/m im Modellmaß, im Spiel durch
  den Maßstab 0,33–0,45 gut 27 px/m), die Aufbauten sind flache Kästen; das Budget „Landgebäude“ (2 000 Dreiecke)
  reicht für ein 182-m-Schiff nicht zu mehr. Im Rennen steht sie 60–100 m entfernt und wirkt dort wie das Sprite.
- **Pylon:** feste Höhe des Sprites (Arcade passt die Höhe der Brücke an); Kopf 13,4 px/m; die Seile (0,34 m) sind
  jenseits von etwa 240 m dünner als ein Pixel (bei „niedrig“ mit 75 % Auflösung ab 180 m, gefolgert aus 711 px
  Brennweite) – mit MSAA bleiben sie eine schwache Linie, bei „niedrig“ (ohne MSAA) können sie flimmern.
- **Sprossenkreuze** verschwinden beim Stufenwechsel (Wohnblöcke 4,5–5,2 % der Pixel bei 60 m); bei „hoch“ erst bei
  120 m, wo sie 0,27 px breit sind.
- Rückseiten haben ein Viertel der Dichte – das gemalte Fenster im Rückgiebel der Kirche ist unscharf, wenn man
  zurückschaut.
- In den Prüfbildern (Kontaktbogen, `prop_scene`) überstrahlen helle Putzwände (Kirche #e8e1d0 erscheint 255/255/255,
  das Sprite bei etwa 203) – im Renn-Bild (A/B) nicht; Licht der Prüfwerkzeuge, nicht der Albedo (gefolgert).

**Fehlt**
- Wasser unter Hausboot und Fähre (R5); Vordächer und Schornsteine, wo die Sprite-Entwürfe keine haben.
- Messungen auf echter Grafikkarte und auf dem Steam Deck (alles hier: Software-OpenGL; Leistung gefolgert).
- Bewegtbilder zum Flimmern (nur Standbilder ausgewertet).

## Lieferbilder (in diesem Ordner)

- `kontaktbogen_<gruppe>_tag.png` / `_nacht.png` – jedes Modell, jede Stufe (lod0, lod1), Anfahrt und Rückseite;
  Gruppen: `haus`, `kirche`, `fabrik`, `stadt` (Laden, Altstadt, Block A/B, Turm), `bruecke` (Laterne, Pylon,
  Fachwerkportal), `muehle`, `hausboot`, `faehre`. Nacht = `ce_night` 1 (Lichtanker als Lichtflecken).
- `spielkamera_<gruppe>_tag.png` / `_nacht.png` – Spielkamera (3,4 m, 711 px Brennweite), Modelle neben der Straße
  bei 25, 59, 61, 150, 199, 201 und 400 m (Umschaltentfernungen der Detailstufe „mittel“: 60 m und 200 m), Pixel für
  Pixel bzw. ganzzahlig vergrößert; `…_neben_sprite.png` dasselbe mit dem Arcade-Sprite daneben in der Größe, die die
  Spielkamera ihm dort gibt. Gruppen: `land` (Haus, Kirche, Fabrik, Mühle), `stadt`, `bruecke` (Laterne, Pylon),
  `schiffe` (Hausboot, Fähre).
- `stufenvergleich_<gruppe>.png` – lod0 | lod1 bei 60 m und lod1 bei 200 m im selben Ausschnitt (Messung oben).
- `ab_<stelle>_<hoch|mittel>_<mittag|daemmerung>_<00|01>.jpg` – Arcade | Modern im Rennen an den drei Stellen.

