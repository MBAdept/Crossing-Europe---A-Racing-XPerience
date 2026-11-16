# QA-R5 – Unabhängige Prüfung des Pakets R5 (Tunnel, Brücken, Wasser und Ufer)

Prüfling: `origin/wip/v080-r5` = `5558bdc485f9df938c349e8e0ecb2f869c2335a9`, Basis `6e484056ec87e2fa614061000a362feb2b5a6db8`
(`origin/wip/v080-m2int`). Rolle: Prüfung, keine Commits, kein Push. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4` (per `git merge --ff-only` auf
5558bdc, nichts geändert); Basisbaum als `git archive` in `m1/QA-R5/base`, eine Kopie des Prüflings für Mutationen und
eigene Prüfskripte in `m1/QA-R5/mut` (beide nach der Prüfung gelöscht). „gemessen“ = auf dieser VM (Mesa llvmpipe unter
Xvfb bzw. headless, 4 geteilte Kerne, Last 10–15 durch die Nachbarpakete); alles über Steam Deck und echte Grafikkarten
ist **abgeleitet**. Schwere Läufe einer nach dem anderen mit `nice -n 10` (`QA_M2_FERTIG` lag vor).

**Kurz (Urteil):** R5 ist **solide und mergebar – kein Blocker.** Eigentum eingehalten (bis auf eine Golden-Zeile),
Arcade bitgleich (20/20, 17/17), alle 122 Brücken und 28 Tunnel (inkl. Testetappe) bauen headless und haben **genau
Arcades Teile** (Pylone, Flugfeuer, Seile, Fachwerkportale, Brückenlampen, Ufer an beiden Enden, Nischen, Kappe);
nichts von R5 steht über den Spuren, kein Seil näher als 2,15 m an einer Spur, kein Portalhügel im Sichtkorridor;
`modern_sight`/`modern_path_check --full` grün; Render-Prüfungen des Pakets und die ZS1-Wächter (K1 0,000 %) grün.
R5s Bilder sind echt: meine Renderings sind mit seinen bitgleich. **Bei Tag** ist Modern an Tunneln und Brücken klar
besser als Arcade und als die Basis (Röhren mit Paneelen/Gehwegen/Nischen, Wasser mit Ufern statt „See bis zum
Horizont“, dünne Seile statt Stäbe, Fachwerk mit Schatten). **Schlechter als Arcade** bleiben: Tunnelportale **nachts**
(vom Abblendlicht bis oben angestrahlt, am Gotthard durch R5s Rahmen/Hügel noch etwas heller als die Basis – QR5-01,
hoch), die Fahrbahn in der Röhre von außen (R4), die Ausfahrt ohne Überstrahlung (R4) und die Steinbrüstung (R4).
Die neuen Tests fangen 18 von 22 eingebauten Fehlern; drei Regeln sind ungeschützt (QR5-05).

## 1. Eigentum und Arcade-Identität

`git diff 6e48405..5558bdc --stat` (gemessen): 16 Dateien, +4112/−169.

| Datei | Eigentum laut Auftrag | Urteil |
|---|---|---|
| `scripts/race3d/builders/bridge.gd` (neu, 1150 Z.), `builders/tunnel.gd` | R5 | in Ordnung |
| `assets/shaders/modern/{tunnel,water}.gdshader` | R5 | in Ordnung |
| `scripts/race3d/layers/far_ground.gd` | R5 (Entscheidung 1 der Leitung) | in Ordnung |
| `tests/unit/race3d/{test_bridge,test_tunnel}.gd`, `tests/race3d/render/check_tunnel_bridge.gd` | R5 | in Ordnung |
| `docs/renderer-modern.md` (+31, §15) | Auftrag: `set_zone`-Aufrufe dort dokumentieren | in Ordnung (Kollisionsgefahr §15 mit R4/R6, R5 meldet es selbst) |
| `docs/renderer-modern-tunnel-bruecken.md` (neu) | nicht genannt; Muster wie `renderer-modern-gelaende.md` | in Ordnung |
| `tests/golden/modern_slice.md5` (Zeile `modern_s4_mittel`) | **nicht R5**: §5 Spalte W3 „–“, A-8: Integration/QA | Abweichung (Befund QR5-07) |
| `.uid`-Dateien | zu den neuen Dateien | in Ordnung |

Keine eingefrorene Arcade-Datei, keine Datei von R4/R6 (auch `props.gd`, `environment_rig.gd`, `far_ground.gdshader`
unverändert). Arcade bitgleich: `tools/golden.sh check` → **„GOLDEN arcade: 20 von 20 identisch“**, **„GOLDEN arcade-ui: 17 von 17 identisch“** (gemessen).

## 2. Funktion – Datenabtastung des ganzen Netzes (gemessen)

Eigenes Prüfskript `tests/qa_r5/qa_scan.gd` (nur in der Scratch-Kopie, nicht eingecheckt): baut **jede Brücke und
jeden Tunnel jeder Richtung jeder Etappe** und zusätzlich beide Richtungen der `dev_testetappe` headless mit
`builders/bridge.gd` / `builders/tunnel.gd` (wie der Streamer: `RoadPath3D`, `TerrainProfile`, `ChunkContext.capture`)
und vergleicht **mit Arcades Ereignissen derselben Strecke** (`Track._build_bridge`: Pylone, Fachwerkportale,
Brückenlampen; Arcades Tunnelregeln: Nischenschild alle 150 m, Leuchten alle 12 m, Kappe bei `peek_m`):

- **122 Brücken** (cable_stayed 12, canal 10, causeway 2, river 60, stone_arch 35, truss_arch 3) und **28 Tunnel**
  (26 im Netz + 2 der Testetappe), **0 Befunde**, 177 s, keine Skriptfehler.
- Je Brücke exakt so viele Pylone, Flugfeuer (je Pylon eins, mit `blink`), 14 Seile je Pylon, Fachwerkportale und
  Brückenlampen wie Arcade Ereignisse hat (z. B. Köhlbrandbrücke 4/4 Pylone, 56 Seile; Elbbrücken 5/5 Portale;
  Ponte della Libertà 20/20 Lampen; Severinsbrücke 2/2 Pylone); Wasser überall; **Ufer an beiden Enden** jeder Brücke
  (Eckpunkte der Ufermaterialien vor und hinter der Brückenmitte > 0).
- **Nichts vom Tragwerk, der Röhre oder dem Portal über den Spuren zwischen 0,3 m und 4,5 m** (Dreiecke abgetastet,
  Kappe ausgenommen); **jedes Seil ≥ 2,15 m neben der Spur** (alle 12 Schrägseilbrücken-Richtungen, kleinster Wert
  Köhlbrandbrücke Hamburg–Bremen 2,15 m).
- **Portalhügel nie über der Anfahrt im Sichtkorridor** (Punkte des Hügels, die einer Zeile vor dem Portal zugeordnet
  sind, höher als 0,5 m über der Fahrbahn innerhalb Spur + Bankett + 5,5 m: 0 in 28 Tunneln) – F7.
- Tunnel: je 1 Portal, 1 Ausfahrtsrahmen, Kappe genau dort, wo Arcade sie hat (Valík 39/42 m: keine), Nischen wie
  Arcades grüne Schilder (z. B. Gotthard 11/11, Somport 6/6), Leuchten 2–11 mehr als Arcades Reihe (Nischenleuchten).
- R5s eigener Netzlauf `check_tunnel_bridge.gd -- --full`: OK, 122 Brücken, 26 Tunnel, 0 Mängel, 52 s (gemessen).
  Er prüft aber nur grob (Pylone ≥ 2, Portale > 2, Brückenlampen gar nicht) – Befund QR5-06.

Daten: Galerien gibt es nicht; kurze Altstadttunnel Valík (39/42 m), Radejčín (60 m), Dölzschen (108 m) bauen.

## 3. Fairness (F1–F7) – gemessen

| Prüfung | Ergebnis |
|---|---|
| `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (Prüfling) | alle OK: F1 0 Fälle bis 270 m in 99 424 500 Stichproben (128 Etappenrichtungen, erster Fall 280 m); F1 Außenspuren 0 bis 260 m in 326 680 500; F2 ≤ 0,593 / 0,596 / 0,555 (≤ 0,60); F3 0 von 5923 Zielen; F7 0 von 2 011 532 Querschnittsseiten; Modell 0 abweichend (144 s) |
| `… -s res://tests/sim/modern_path_check.gd -- --full` | OK: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2064 m (≥ 2000) (57 s) |
| Brief Punkt 5 – Bauten von R5 (nicht Teil von `modern_sight`, das nur Kamera und Gelände kennt): eigener Netzlauf Abschnitt 2 | 0 Punkte von Tragwerk/Röhre/Portal über den Spuren zwischen 0,3 und 4,5 m in 122 Brücken + 28 Tunneln; Seile ≥ 2,15 m neben der Spur; Portalhügel nie über der Anfahrt im Sichtkorridor (F7) |
| Kappe und Tunnelwände (F1 „später sichtbar“) | Kappe bei `peek_m` 45 m nur für eine Kamera außerhalb (Shader `cam_tunnel_z`), wie Arcades `closed_from` – gleich wie Arcade, nicht später; Wände an der Bankettkante wie Arcades. In Kurven verdecken Arcades nähere Wandsegmente ferne Fahrzeuge genauso (Malerreihenfolge) – kein Nachteil gegen Arcade (abgeleitet aus dem Code, nicht gemessen). |
| Quaimauer-Abdeckung | Abdecksteine 0,16 m über Geländehöhe am Ufer, beginnend an der Bankettkante – formal über der Fahrbahnhöhe im 8-m-Korridor, aber 0,16 m können kein Fahrzeug (0,75 m) und kein Schild verdecken (abgeleitet). |

Das Kurvenkamera-Gesetz, die Steam-Deck-Stufe und der Musikpegel wurden nicht verändert und nicht bewertet (Vorgabe).

## 4. Tests – Gates und Wächterwirkung

### 4.1 Gates (gemessen, Prüfling 5558bdc, nice 10, Last 10–15)

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0 |
| Tests voll (1 Lauf) | `tools/run_tests.sh` (954 s) | 767 Einheitstests, **2 fehlgeschlagen** – beide Echtzeit-Klang: `test_engine3_checks` „thread“ (6 Aussetzer bei 6 Hauptthread-Hängern à 400 ms) und `test_music_checks` „race“; dazu **`check_attract.gd (Modern)`** „idle: Demo 0,90 s nach der letzten Eingabe (idle_s 1)“. Alle anderen Prüfungen und Szenarien OK, darunter `check_terrain_plan` (R5s behobener -s-Fehler) 3/3, `test_bridge` 10/10, `test_tunnel` 8/8, `test_far_ground_water` 4/4, `test_props` grün, `modern_sight`/`modern_path_check` (Normallauf) OK. Keine der drei berührt eine R5-Datei; Einzelläufe auf Prüfling und Basis: einzeln nachgeprüft (gemessen): `check_attract.gd -- --graphics=modern` Prüfling OK (Demo nach 1,01 s), Basis OK; `test_engine3_checks` Prüfling 2/2 grün, **Basis rot** („thread“). `test_music_checks` läuft mit `--graphics=arcade` – R5s Dateien werden dabei gar nicht geladen (Arcade-Start, `check_arcade_lean`); `check_music.gd --only=race` abwechselnd je dreimal: **Basis 3 von 3 rot, Prüfling 2 von 3 rot**, Ursache das Kriterium „längstes Bild < 0,35 s Spielzeit“ (0,38–0,54 s) bzw. der Einsatz nach „LOS!“ – Lastverhalten der Echtzeitprüfungen (A-11), keine R5-Wirkung. |
| Render-Prüfungen | `tools/run_render_checks.sh modern <filter>` für `tunnel_bridge`, `start_km0`, `terrain_cover`, `light_base` | **alle OK**: U1_portal 0,000 % Magenta, U1_innen 0,000 % / 612 Leuchtenpunkte / 0,322, U1_ausfahrt 0,226 (Röhre 0,449) / 0,0 % Weiß, Somport_portal 0,000 %, B1 0,000 % / 0,00 % Fernboden / 630 Wasserflächen, beacon 4 Feuer / 4 blinken; `check_start_km0` Kamera ≤ 1,14 px, Auto, Boden OK; `check_terrain_cover` T1–T4, S1, C1, **K1 0,000 %** (ZS1-Korrektur hält); `check_light_base` Tageslicht und Schatten OK. Die Waldprüfung (`check_instance_budget_wald`, bekannter Lastbefund M2S-01) habe ich nicht wiederholt. |
| Arcade-Identität | `tools/golden.sh check` | **„GOLDEN arcade: 20 von 20 identisch“**, **„GOLDEN arcade-ui: 17 von 17 identisch“** (gemessen, 227 s + 349 s) |
| Sicht/Weg voll | Abschnitt 3 | OK |
| Netzlauf R5 | `check_tunnel_bridge.gd -- --full` | OK (122 Brücken, 26 Tunnel, 0 Mängel, 52 s) |
| eigener Netzlauf | `qa_scan.gd` (Abschnitt 2) | 0 Befunde |

### 4.2 Schützen die neuen Tests ihre Regel? (Mutationen, gemessen)

Je eine Zeile in einer Kopie des Prüflings (`m1/QA-R5/mut`) gebrochen, nur die zuständige Testdatei laufen lassen
(`godot --headless -s res://tests/run_tests.gd -- --filter=<datei>`), danach zurückgesetzt (`tools/mutate.py`,
`mutations/results.json`). Grundlauf: `test_bridge` 10/10, `test_tunnel` 8/8, `test_far_ground_water` 4/4 grün.

| Mutation (Datei: Änderung) | Regel | Ergebnis |
|---|---|---|
| B1 bridge.gd: Wasser 0,5 m höher | Wasser auf den Wasserzeilen | gefangen (`test_water_lies_on…`) |
| B2 bridge.gd: Wasser nur bis Ring 3 | Wasser bis zum letzten Ring | gefangen |
| B3 bridge.gd: Uferregel umgedreht | Ufer nach Arcades Regel | gefangen (2 Tests) |
| B4 bridge.gd: ferne Kaimauer zeigt nach vorn | ferne Kaimauer zur Kamera | gefangen |
| B5 bridge.gd: Pylon nicht skaliert | `height_m`/88,8 (A-16) | gefangen |
| B6 bridge.gd: Flugfeuer 8 m unter der Spitze | Feuer auf `height_m` + 1,6 m | gefangen |
| B7 bridge.gd: Seilende 4,5 m statt 1,4 m innen | kein Seil über einer Spur | gefangen (2 Tests) |
| B8 bridge.gd: Fachwerk 3 m nach innen | Tragwerk aus den Spuren | gefangen |
| B9 bridge.gd: Randbalken 5 m nach innen | Tragwerk aus den Spuren | gefangen |
| B10 bridge.gd: `night_albedo` nicht gesetzt | Pylon nachts dunkel | **nur über `SCRIPT ERROR`** (`float(null)` im Test bricht ab; `run_tests.sh` wertet Skriptfehler als Fehlschlag) |
| B11 bridge.gd: Blinkphase je Seite 0 | Arcades Takt | gefangen |
| B12 bridge.gd: 5 statt 7 Seile je Seite | Arcades 7 Seile | **nicht gefangen** (Test rechnet mit der eigenen Konstante) |
| B13 bridge.gd: Fachwerkportale nicht gebaut | Portale | gefangen (`test_every_bridge_type_builds`) |
| B14 bridge.gd: Brückenlampen nicht gebaut | Lampen an Stein-/Dammbrücken | **nicht gefangen** (kein Test; auch R5s Netzlauf zählt sie nicht) |
| T1 tunnel.gd: keine Nischen | SOS-Nischen | gefangen |
| T2 tunnel.gd: Lüfter auf 3,6 m | nichts unter 5,2 m über der Fahrbahn | gefangen |
| T3 tunnel.gd: Kappe auch innen | Kappe nur von außen | gefangen |
| T4 tunnel.gd: `has_method("set_zone")` entfernt | `set_zone` duck-typed | **nicht gefangen** (kein Fall „Rig ohne `set_zone`“) |
| T5 tunnel.gd: keine Kappe | Kappe bei `peek_m` | gefangen |
| T6 tunnel.gd: kein Portal | Portal + Hügel | gefangen (3 Tests) |
| F1 far_ground.gd: ZS1-Regel entfernt | Fernboden ≤ tiefstes Wasser − 0,3 m | gefangen (3 Tests in `test_far_ground_water`) |
| F2 far_ground.gd: Kaifarbe der Kopie verändert | gepinnte Kopie = Arcade | gefangen |

18 von 22 Regeln sind von benannten Tests geschützt, eine nur über den Skriptfehler-Filter, drei gar nicht
(Befund QR5-05). Die Wächter der ZS1-Korrekturen halten (`test_far_ground_water` 4/4; K1 siehe Gates).

## 5. Bilder – angesehen, ehrlich gegen Arcade und gegen die Basis

`tools/ab_shot.sh` (Arcade | Modern desselben Simulationszustands), Modern „Hoch“, 1280 × 720; die Basis 6e48405 mit
denselben Argumenten. **Bestimmtheit geprüft:** meine Renderings des Prüflings sind an 12 Orten (24 Bilder)
**bitgleich** mit R5s gelieferten Bildern, meine Basisbilder (U1 innen, Köhlbrand Rampe) bitgleich mit R5s
Basisbildern – R5s Bilder zeigen den Endstand, seine Basisspalte ist echt (gemessen, max. Abweichung 0).
Bögen „Arcade | Modern Basis | Modern R5“: `bilder/<ort>_NN.jpg`; Ausschnitte `bilder/ausschnitt_*.jpg`.

| Ort (Bogen) | gegen Arcade | gegen die Basis | Beobachtung (angesehen; Messwerte 0–255, gemessen) |
|---|---|---|---|
| U1 Gotthard Anfahrt 12 Uhr (`u1_anfahrt_00/01`) | **besser** (Röhre), Fahrbahn in der Röhre schlechter | besser | Portalrahmen mit Laibung, Paneele mit Fugen schon am Eingang, Gehwege, Leuchtengehäuse, Kappe bei 45 m wie Arcade. Fahrbahn in der Röhre von außen kalt grau 48,50,57 gegen Arcades warmes Tunnellicht 42,33,24 (Basis gleich – R4). Arcades große Lichthöfe der Leuchten sind in Modern kleiner. |
| U1 innen (`u1_innen_00/01`) | **deutlich besser** | deutlich besser | Fliesenpaneele, Kabeltrasse, Gehwegkante, Notausgang mit grünem Schild, Leuchten mit Gehäuse und Lichthof; Licht und Farbe wie Arcade, kein Himmel. Basis: glatte Wände. |
| U1 Ausfahrt (`u1_ausfahrt_00–02`, `ausschnitt_u1_ausfahrt`) | **schlechter** (Öffnung) | gleich, Rahmen besser | Rahmen der Ausfahrt und Notausgang neu (gut). Draußen braun getönt und dunkler als die Röhre: Öffnung 90,86,48 gegen Röhrenwand 152,116,73; Arcade überstrahlt 171,201,155. Kein „Licht am Ende des Tunnels“ – R4 (Belichtungsrampe/Tunnelnebel), nicht R5; Basis identisch. |
| U1 22 Uhr (`u1_nacht_00/01`, `ausschnitt_u1_nacht_portal`) | **schlechter** | **etwas schlechter** | Stirnwand/Rahmen aus 60–70 m vom Abblendlicht bis oben hell: 65,66,67 gegen Arcade 29,38,47 und Basis 51,58,52; auf R5s Hügel über dem Portal ein heller Lichtstreifen (16,39,23 gegen Basis 14,34,19, Arcade 18,33,27). Fahrbahn in der Röhre nachts 66,65,67 gegen Arcade 103,87,70 (dunkles Loch statt warmem Tunnellicht, Basis gleich). Befund QR5-01/02. |
| Somport (`somport_00–02`) | **besser** | besser | SOS-Nische mit orangem Schild, Notausgang, Paneele, Rahmen; Arcades grünes Nischenlicht leuchtet stärker. Fahrbahn in der Röhre grau (R4). |
| Köhlbrandbrücke Rampe (`kb_rampe_00/01`, `ausschnitt_kb_seile_tag`, `ausschnitt_kb_fernufer`) | **besser** | **deutlich besser** | Basis: dicke weiße Seilstäbe des Modells, Wasser bis zum Horizont ohne Ufer. R5: Seile dünn (nah 3–6 px, Arcades Linien 1–2 px), Wasser mit Wellen in Arcades Farbe, ferne Steinböschung + Land wie Arcades Kai, Pylon mit Betonstruktur und Schatten auf dem Deck. Pylonbeine hell wie Arcade, Sonnenseite etwas heller (R5s Messung ±12 % plausibel, im Bild nicht störend). |
| Köhlbrandbrücke Ende (`kb_ende_00/01`) | **gleich bis besser** | deutlich besser | graue Natursteinböschung in Arcades Kaifarbe statt „Wasser ins Grün“; Seile des Pylons hinter der Kamera reichen korrekt über das Bild (Arcade zeichnet nur, was vor der Kamera steht). |
| Köhlbrandbrücke 22 Uhr (`kb_nacht_00–02`, `ausschnitt_kb_nacht_seile`) | **gleich** | gleich | Pylone dunkel, Lampenreihe der Brücke, Wasser ruhig dunkel. Seile nachts als graue Linien (3–4 px, ≈ 110) deutlicher als Arcades feine Linien – vertretbar. |
| Köhlbrand Pylonspitzen 22 Uhr (`kb_top_00–03`, `ausschnitt_kb_flugfeuer_22uhr`) | **gleich** | gleich | ab km 75,6 stehen die Spitzen zwischen Fortschrittsbalken und Tipp-Leiste im Bild (durch das halbdurchsichtige HUD-Feld); rotes Feuer in Bild 00 (2,0 s) an, in 01–03 (2,4/2,8/3,2 s) aus – **in Arcade genau dieselben Bilder** (gleicher Takt, gemessen an den roten Bildpunkten). |
| Holtenauer Hochbrücke (`holtenau_00/01`) | **gleich bis besser** | deutlich besser | Kanal zwischen grünen Böschungen mit Steinschüttung, Land dahinter – liest sich als Kanal, nicht als See. |
| B1 Severinsbrücke Köln (`b1_koeln_00/01`) | **gleich bis besser** | besser | Kaimauern/Pflaster in Arcades Kaifarbe, Rhein mit Wellen, fernes Ufer; nahe Seile als weiße Stäbe (physikalisch 7 cm auf 3–5 m), dicker als Arcades Linien. |
| Elbbrücken, Fachwerk (`elbbruecken_00/01`) | **besser** | deutlich besser | Arcades Fachwerkträger und Bogenportale, mit echten Schatten auf dem Deck. |
| Ludwigsbrücke Würzburg, Stein (`stein_00/01`, `ausschnitt_stein_bruestung`) | **gleich**, Brüstung **schlechter** | gleich | Brückenlampen als Modelle wie Arcade, Wasser besser; aber geschlossene graue Brüstung statt Arcades heller Docken (R4 `roadside.gd`). |
| DEV km 48, 21 Uhr (`dev_00–02`, `ausschnitt_dev_portal_21uhr`) | Portal **schlechter**, Röhre besser | Portal gleich, Röhre besser | Flügelmauer 48,52,49 gegen Arcade 24,40,35 (Basis gleich), Hügel über dem Portal angestrahlt 39,50,34 gegen 17,30,26. Innen Paneele/Gehwege besser als Arcade. |
| Steam Deck 1280 × 800 „deck“ | siehe Abschnitt 6.3 | | |

**Gesamturteil Bild:** Wo R5 selbst baut und es Tag ist, ist Modern **klar besser als Arcade und als die Basis**
(Röhren, Wasser, Ufer, Fachwerk, Seile, Kaimauern). **Nicht besser oder schlechter** ist es an drei Stellen, die an
Nachbarn hängen (Fahrbahn in der Röhre, Ausfahrt ohne Überstrahlung, Steinbrüstung) und **nachts an Tunnelportalen**:
dort ist Modern sichtbar schlechter als Arcade – vom fehlenden Abblendkanten-Gesetz (R4), aber am Gotthard durch R5s
helleren Rahmen und den angestrahlten Hügel noch etwas heller als die Basis.

## 6. Leistung (gemessen auf dieser VM; Steam Deck und echte GPU abgeleitet)

### 6.1 Rechenzeit je Stück und beim Auftauchen eines Flusses (headless, Minimum aus 3 Läufen – lastfest nach A-11)

Eigenes Messskript `tests/qa_r5/bench_r5.gd` (Scratch-Kopie), Prüfling und Basis mit derselben Datei:

| Bau | Prüfling: collect / build (Worker) / commit (Hauptthread), Maximum je Stück | Basis |
|---|---|---|
| Gotthard, 6 Stücke ab dem Portal | 0,01 / **5,45** (Mittel 3,41) / **0,23** ms | 0,01 / 0,94 (0,62) / 0,11 ms |
| Somport | 0,01 / 4,47 (3,58) / 0,28 ms | 0,01 / 1,53 (0,94) / 0,15 ms |
| Köhlbrandbrücke | 0,18 / 4,78 / 0,49 ms | – (kein Brücken-Builder) |
| Elbbrücken (Fachwerk) | 0,06 / 6,11 / 0,59 ms | – |
| Ponte della Libertà (Damm, 20 Lampen) | 0,06 / **10,75** / 0,55 ms | – |
| Holtenau / Severin / Ludwigsbrücke / Ada | ≤ 0,15 / ≤ 3,95 / ≤ 0,44 ms | – |
| `far_ground.update_rivers()` im Bild, in dem der Fluss entsteht (Fluss, Fernufer, Fernland) | **0,77–1,62 ms** (7 Brücken) | – |

Lesart: der Hauptthread-Anteil (collect + commit) bleibt je Stück unter 0,8 ms – weit unter dem Budget „chunk commit
max 3 ms“ (deck/medium). Die Worker-Zeit steigt am Tunnel um den Faktor 5–6, an Brücken auf bis zu 10,8 ms; sie
verzögert nur das Eintreffen eines Stücks (3,4 km Vorlauf, abgeleitet unkritisch, auch mit den langsameren Kernen des
Steam Deck ≈ 1,5×). **R5s gemeldete Spitze „far_ground 69,9 ms“ ist als Rechenarbeit nicht nachstellbar** (höchstens
1,62 ms); sie war vermutlich Last der Nachbarn oder Knoten-/Material-Erstauftritt beim Zeichnen – auf echter Hardware
mit dem Leistungstest beobachten.

### 6.2 Etappenläufe im Steam-Deck-Profil (Xvfb 1280 × 800, `--gfx-preset=deck`, `tests/race/run_stage.gd`, Zeitraffer 4)

**Kiel – Hamburg ab km 76 (Köhlbrandbrücke, Elbbrücken), 12 Uhr, Seed 11**

| | Basis 6e48405 | R5 5558bdc |
|---|---|---|
| Strecke erreicht (km) | 94.0 (Zeitlimit) | 94.4 (Zeitlimit) |
| Bilder | 937 | 959 |
| `render()` Mittel / max (ms) | 2.40 / 68.9 | 2.43 / 105.8 |
| Bildzeit Median / p95 (ms, llvmpipe) | 1249 / 1811 | 1189 / 1717 |
| `sim_avg_ms` / max (Lastmaß, R5 berührt es nicht) | 1.57 / 376 | 1.37 / 65 |
| Haken `bridge` Mittel / max (ms) | – | 0.019 / 0.1 |
| Haken `tunnel` Mittel / max (ms) | 0.003 / 0.1 | 0.005 / 2.2 |
| Haken `far_ground` Mittel / max (ms) | 0.293 / 11.6 | 0.338 / 5.4 |
| Stück-Bau Worker Mittel / max (ms) | 4.9 / 19.1 | 5.0 / 20.5 |
| `chunk_commit_ms_max` (Budget deck 3 ms) | 1.08 | 1.98 |
| Zeichenaufrufe / Primitive (letztes Bild; Budget deck 650 / 450 000) | 133 / 138709 | 129 / 138299 |
| Schatten-Primitive (letztes Bild) | 4264 | 4404 |
| Texturspeicher (MB) | 119.7 | 120.5 |
| Vorbereitung `prepare_ms` | 29.2 s | 25.4 s |
| Wanduhr (s) | 1200 | 1201 |

**Bern – Mailand ab km 183 (Gotthard-Portal und Röhre), 12 Uhr, Seed 16**

| | Basis 6e48405 | R5 5558bdc |
|---|---|---|
| Strecke erreicht (km) | 222.4 (Zeitlimit) | 219.9 (Zeitlimit) |
| Bilder | 635 | 592 |
| `render()` Mittel / max (ms) | 3.57 / 329.1 | 2.93 / 134.9 |
| Bildzeit Median / p95 (ms, llvmpipe) | 1345 / 1825 | 1100 / 1689 |
| `sim_avg_ms` / max (Lastmaß, R5 berührt es nicht) | 1.08 / 77 | 1.27 / 592 |
| Haken `bridge` Mittel / max (ms) | – | 0.004 / 0.1 |
| Haken `tunnel` Mittel / max (ms) | 0.045 / 1.2 | 0.074 / 2.3 |
| Haken `far_ground` Mittel / max (ms) | 0.081 / 3.3 | 0.104 / 3.4 |
| Stück-Bau Worker Mittel / max (ms) | 9.4 / 83.7 | 17.4 / 109.6 |
| `chunk_commit_ms_max` (Budget deck 3 ms) | 1.97 | 6.88 |
| Zeichenaufrufe / Primitive (letztes Bild; Budget deck 650 / 450 000) | 141 / 142640 | 133 / 127223 |
| Schatten-Primitive (letztes Bild) | 9556 | 6736 |
| Texturspeicher (MB) | 117.3 | 114.6 |
| Vorbereitung `prepare_ms` | 19.3 s | 27.2 s |
| Wanduhr (s) | 601 | 600 |


Lesart (gemessen, unter Last 10–15; „max“ sind Einzelwerte und lastempfindlich): Auf der Brückenstrecke kosten R5s
Teile nichts Messbares – `render()` 2,43 gegen 2,40 ms im Mittel, `far_ground` +0,045 ms, `bridge` 0,019 ms,
Texturspeicher +0,8 MB, Commit-Maximum 1,98 ms (Budget deck 3 ms). Am Gotthard ist `render()` im Mittel sogar
niedriger (2,93 gegen 3,57 ms; Last), Commit im Mittel 1,09 gegen 0,85 ms, **ein Einzelwert 6,88 ms über dem
deck-Budget von 3 ms** (Basis 1,97 ms); in einem zweiten Lauf in der Röhre (km 188, 110 s) 0,51 / 0,59 ms (Basis
0,33 / 0,37), headless höchstens 0,28 ms je Röhrenstück – der Einzelwert ist nicht wiederholbar (Befund QR5-09,
niedrig). Zeichenaufrufe mit dem letzten Bild **auf dem Köhlbrand-Deck** („deck“, km 79,7 bzw. 80,3): R5 163 /
136 829 Primitive / 9592 Schatten-Primitive gegen Basis 148 / 145 951 / 6036; **in der Gotthard-Röhre** (km 194):
R5 43 / 81 312 / 9434 gegen 45 / 77 600 / 6832 – weit unter dem deck-Budget 650 / 450 000 (R5s eigene Messung an
seinen Stellen: +17 bis +22 Aufrufe, +10 bis +15 % Primitive bei „Mittel“ – plausibel). Das Steam Deck selbst ist
abgeleitet; es zählt der Leistungstest des Nutzers (A-15).

### 6.3 Steam Deck (Bilder, 1280 × 800, „deck“)

`deck_kb_rampe_00/01`, `deck_kb_nacht_00–02` (mit Basis), `deck_u1_innen_00/01`: Modern füllt das Bild, Arcade mit
Balken; Wasser mit Wellen, Seile, Pylonschatten auf dem Deck, Paneele und Gehwege in der Röhre sind auch in „deck“ da
(Regel 9: nichts Spielrelevantes wird ausgedünnt). Urteil wie in „Hoch“: Brücke gleich bis besser, Röhre besser.
Nachts am Köhlbrand gleich der Basis.

## 7. Befunde

Schwere: Blocker = darf nicht in Testbuild 2; hoch = fällt dem Nutzer sofort auf; mittel = merklich; niedrig = Feinschliff.
Eigentümer in Klammern: wo die Ursache in fremden Dateien liegt, steht die genaue Änderung für den Eigentümer dabei.

**Kein Blocker.** Kein Befund verletzt Fairness, Arcade-Identität oder das Eigentum so, dass Testbuild 2 gefährdet wäre.

| ID | Schwere | Bereich / wo | Befund | Beleg (gemessen/abgeleitet) | Nachstellen | Behebung |
|---|---|---|---|---|---|---|
| QR5-01 | hoch | Nacht, Tunnelportale – `builders/tunnel.gd` `commit()` (Portal-Mesh `TunnelPortal`, vpbr, Standard-Renderlayer) und R4 `layers/lights.gd` (`SPOT_ANGLE_DEG` 30°, keine Abblendkante) | Nachts leuchten Stirnwand, Rahmen und Flügelmauern aus 60–70 m bis oben hell, auf R5s Hügel steht ein heller Lichtstreifen; das Portal liest sich wie bei Tag. Am Gotthard ist R5 heller als die Basis (Rahmen/Hügel neu), an der Testetappe gleich. | gemessen: U1 22 Uhr Stirnwand 65,66,67 (Basis 51,58,52, Arcade 29,38,47), Hügel über dem Portal 16,39,23 (Basis 14,34,19, Arcade 18,33,27); DEV 21 Uhr Flügelmauer 48,52,49 (Basis gleich, Arcade 24,40,35). Bilder `ausschnitt_u1_nacht_portal.jpg`, `ausschnitt_dev_portal_21uhr.jpg` | `tools/ab_shot.sh … --stage=bern_mailand --from=bern --start-km=183.6 --hour=22 --seed=16 --start-speed=120 --shot-times=2,3.5 …` (GFX_ARGS --gfx-preset=high) | R5 (eigene Datei, sofort): den Hügel als eigenes Mesh auf `GROUND_LAYERS` (Renderlayer 2, wie Gelände und Wasser) legen – die Spotlichter des Abblendlichts (`LIGHT_MASK` = alles außer Layer 2) lassen ihn dann aus wie das Gelände daneben; Stirnwand/Rahmen ebenso, bis R4 eine Abblendkante hat (Arcade beleuchtet die Stirnwand praktisch nicht). R4: Abblendkante (flacher zweiter Kegel oder Projektortextur am Spot). |
| QR5-02 | mittel | Fahrbahn in der Röhre – R4 `builders/road.gd` / `road.gdshader` | Von außen ist die Fahrbahn in der Röhre bei Tag kalt grau, nachts ein dunkles Loch; Arcade zeigt warmes Tunnellicht. Unverändert gegen die Basis. | gemessen: U1 Portal 12 Uhr 48,50,57 gegen Arcade 42,33,24; 22 Uhr 66,65,67 gegen 103,87,70 (`u1_anfahrt_01`, `u1_nacht_01`) | wie QR5-01, Bild 01 | R4: Tunnelsegmente (road.gd kennt sie) bekommen das Licht von `tunnel.gdshader` (Lampenfarbe, `TUNNEL_FOG`, `darkness_m`) unabhängig vom Ort der Kamera (R5s Hinweis, bestätigt). |
| QR5-03 | mittel | Tunnelausfahrt – R4 `environment_rig.gd` (`set_zone`/Belichtungsrampe) | Draußen ist durch die Ausfahrt braun getönt und dunkler als die Röhre; Arcades Überstrahlung („Licht am Ende des Tunnels“) fehlt. R5 liefert `tunnel_state.exit_m/exit_in_sight` und `set_zone`. Basis gleich. | gemessen: Öffnung 90,86,48, Röhrenwand 152,116,73, Arcade-Öffnung 171,201,155 (`ausschnitt_u1_ausfahrt.jpg`) | `--start-km=200.3 --hour=12 --seed=16 --shot-times=2,3.5,4.5` | R4: Rampe nach Arcade (`amb_out = min(2, amb·1,7+0,25)`, Nebel nach Weiß 0,55) für alles jenseits `exit_m`, ausgelöst über `set_zone("tunnel", amount)` / `tunnel_state`. |
| QR5-04 | mittel | Steinbrücken – R4 `builders/roadside.gd` `_railing` | Geschlossene graue Brüstung statt Arcades heller Docken (35 Steinbrücken im Netz). | Bild `ausschnitt_stein_bruestung.jpg` (gemessen: Ansicht) | `--stage=kassel_wuerzburg --from=kassel --start-km=205.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4` | R4: für `stone_arch` das Mittelband durch Docken ersetzen (R5s Vorschlag: alle 0,35 m, 0,14 m Kante); oder Geländer an Brücken R5 zuweisen (Vertragsfrage). |
| QR5-05 | mittel | Prüfungen – `tests/unit/race3d/test_bridge.gd`, `test_tunnel.gd` | Drei Regeln sind ungeschützt, eine nur über den Skriptfehler-Filter des Runners: Brückenlampen an Stein-/Dammbrücken (Mutation „keine Lampen bauen“ bleibt grün), Arcades 7 Seile je Seite (Test vergleicht mit der eigenen Konstante), `set_zone` nur bei vorhandener Methode (kein Test mit einem Rig ohne `set_zone`); `night_albedo` des Pylons fällt nur als `SCRIPT ERROR` (float(null)) auf. | gemessen: 22 Mutationen, 18 von benannten Tests gefangen, B10/B12/B14/T4 nicht (`mutations/results.json`) | `python3 m1/QA-R5/tools/mutate.py B12_cables_count` | R5: Lampen je Brücke mit Arcades `bridge_lamp`-Ereignissen vergleichen; `assert_eq(cables, 4*2*7)` als Zahl; Test mit `FakeEnv` ohne `set_zone` (kein Aufruf, kein Fehler); im Pylontest zuerst `m.get_shader_parameter("night_albedo") != null` prüfen. |
| QR5-06 | niedrig | `tests/race3d/render/check_tunnel_bridge.gd` `_full_scan` | Netzlauf prüft grob (Pylone ≥ 2, Portale > 2, Bögen > 3; Brückenlampen, Nischen, Kappe, Ausfahrt gar nicht) – ein Verlust einzelner Teile bliebe grün. | Code Z. 445–465; mein Netzlauf mit exakten Arcade-Zahlen: 0 Befunde | – | Exakt gegen `Track.events_for_segment` vergleichen (wie `qa_scan.gd`, Abschnitt 2). |
| QR5-07 | niedrig | `tests/golden/modern_slice.md5` | Außerhalb des Eigentums geändert (§5 W3 „–“, A-8: Integration/QA); kollidiert, sobald R4/R6 dieselbe Zeile ändern. Inhalt nachvollziehbar (gewollte Bildänderung). | `git diff 6e48405..5558bdc --stat` | – | Beim RINT-M2-Merge die Zeile von der Integration neu erzeugen lassen (`tools/golden.sh modern-make`), nicht von Hand mischen. |
| QR5-08 | niedrig | Schiffe – R4 `builders/props.gd` Z. 599 | Hausboote/Schiffe stehen auf den Wasserzeilen des Geländes, 0,15 m unter R5s Wasser (A-16 verlangt „auf der Wasseroberfläche“). Im Bild kaum sichtbar. | Code `WATER_LIFT` 0.15 (bridge.gd), props.gd `h = it["h"]` (abgeleitet) | – | R4: `h = float(it["h"]) + (0.15 if bool(inp.get("skip_bridge", false)) else 0.0)` (R5s Vorschlag, bestätigt). |
| QR5-09 | niedrig | Leistung – Stück-Commit am Tunnelportal (`builders/tunnel.gd` `commit()`: Röhren-/Portal-Mesh, `add_lamps`) | Im Gotthard-Lauf („deck“) ein Commit-Einzelwert 6,88 ms über dem deck-Budget 3 ms (Basis 1,97 ms); Mittel 1,09 gegen 0,85 ms. Nicht wiederholbar: zweiter Lauf 0,59 ms max, headless höchstens 0,28 ms. Worker-Bauzeit am Tunnel 5–6 × die der Basis (Mittel 3,4 gegen 0,6 ms), Brücken bis 10,8 ms – nur Eintreffzeit, nicht Bildzeit. | gemessen: `logs/perf_u1_r5.log` / `perf_u1_base.log` (streamer `commit_ms_max`), `perf_u1deck_*.log`, `bench_r5.log` | `run_stage.gd -- --stage=bern_mailand --from=bern --start-km=183 --timescale=4 --max-seconds=600 --graphics=modern --gfx-preset=deck` unter Xvfb 1280 × 800 | PERF: Commit-Maximum am Portal auf dem Deck im Leistungstest beobachten; falls bestätigt, die `add_lamps`-Liste der Röhre je Stück auf einen Aufruf je Lampenreihe bündeln oder das Portal-Mesh im Worker fertig bauen. |

### 7.1 Vertragsfragen (mit Beleg)

1. **Geländer an Brücken fallen zwischen die Pakete.** Inventar B / §6 R5 nennt „railings per type“ als R5-Ausgabe,
   §5 Spalte W3 gibt `builders/roadside.gd` R4. Folge: die Steinbrüstung (QR5-04) hat in Welle 3 keinen Besitzer, der
   sie zu Arcades Docken bringen muss. Vorschlag: Geländer an Brückensegmenten in R5s Eigentum (Welle 4) oder als
   ausdrücklicher Auftrag an R4/FIX-M2.
2. **A-16 „R5 sets boats on the water surface“** ist ohne eine Zeile in R4s `props.gd` nicht erfüllbar (QR5-08).
3. **Modern-Änderungsmelder in Welle 3.** `tests/golden/**` hat in W3 keinen Besitzer („–“), aber jedes Paket, das ein
   Modern-Bild gewollt ändert, macht den Melder rot. R5 hat die Zeile selbst geändert (QR5-07). Vorschlag: der Merge
   (RINT-M2) erzeugt `modern_slice.md5` neu; Pakete melden die betroffenen Zeilen nur.
4. **F1/F7 für Bauten.** `modern_sight.gd` kennt nur Kamera und Gelände; ob Tunnelwände, Portale, Träger, Pylone und
   Kaimauern Spuren oder Sichtkorridore verdecken, prüft nur jedes Paket in seinen eigenen Unit-Tests (R5: drei Brücken,
   drei Tunnel). Vorschlag: ein gemeinsamer Netzlauf „nichts über den Spuren unter 4,5 m, nichts im Korridor“ über die
   Ausgaben aller Builder (wie `qa_scan.gd`), in `run_tests.sh` über den generischen Haken.
5. **Echtzeit-Klangprüfungen unter Last** (`test_engine3_checks` „thread“, `test_music_checks` „race“) fallen auf Prüfling
   **und** Basis abwechselnd; A-11 nennt eine nur unter Last fallende Prüfung „kaputt“ – sie sollten gegen eine im selben
   Lauf gemessene Referenz urteilen (Eigentümer Audio).

## 8. Geprüft und in Ordnung

- Eigentum: nur R5-Dateien, `far_ground.gd` (Leitungsentscheidung) und die Doku; keine Arcade-Datei, keine Datei von R4/R6;
  `props.gd` unverändert – sein `skip_bridge` (Z. 78, 111, 526, 719–720) greift, weil alle Builder vor dem ersten
  `setup()` existieren (`modern_renderer.gd` Z. 384–387: „every object exists before the first call“).
- Arcade bitgleich: `GOLDEN arcade: 20 von 20`, `GOLDEN arcade-ui: 17 von 17`.
- Builder-Regeln (A-3): `build()` von `bridge.gd`/`tunnel.gd` nutzt nur Snapshot-Daten und die Eingabe von
  `collect()`; Zustand nur auf dem Hauptthread (`collect`, `commit`, `update`); Seilenden aus dem Pfad in `collect()`.
- `set_zone` duck-typed (`has_method`), nur bei Änderung; ohne die Methode bleibt `tunnel01` (Code + Test).
- Wasser-Shader liest `ce_time`, nie `TIME` (Regel 10); Nebel nach Arcades Bodengesetz (höchstens 70 %, F4).
- Fernboden: ZS1-Regel bleibt (`target_height` = min(Straße − 4 m, Wasser − 0,3 m)), `test_far_ground_water` 4/4, K1 0,000 %;
  Floating-Origin: Flüsse/Land werden in `rebased()` mitverschoben, Höhen ändern sich beim Rebase nicht (road_path.gd Z. 245–254).
- Netz: alle 122 Brücken, 28 Tunnel bauen headless ohne Fehler; Teile = Arcades Ereignisse; Ufer an beiden Enden.
- Fairness: `modern_sight --full` und `modern_path_check --full` grün; nichts von R5 über den Spuren; Seile ≥ 2,15 m;
  Hügel nie im Sichtkorridor der Anfahrt.
- Köhlbrandbrücke: 4 Pylone, Höhe 95/88,8 = 1,07, 56 Seile, 4 Flugfeuer im Takt von Arcade (Bild: gleiche Phase in
  Arcade und Modern), Pylonfeld nachts unter Arcade (gemessen 44,0/45,1/52,3 gegen Arcade 46,4/49,9/55,2, Basis
  42,4/42,9/51,9 – Fenster x 500–780, y 150–350 von `kb_nacht_00–02`).
- Bestimmtheit: Prüflingsbilder = R5s Bilder bitgleich (24 Bilder), Basisbilder = R5s Basisbilder bitgleich.
- Render-Prüfungen des Pakets und die drei ZS1-Wächter (`check_start_km0`, `check_terrain_cover` K1, `check_light_base`) OK.
- R5s Clips (`deliver/R5/clips/`, je 30 s, 60 fps fest) angesehen (Kontaktbögen alle 3 s): keine Sprünge, Portal und
  Brücke an derselben Stelle wie Arcade; nicht neu gerendert.

## 9. Wo was liegt

- Bilder/Bögen: `deliver/QA-R5/bilder/`; Rohbilder `m1/QA-R5/shots/{new,base}/`; Ausschnitte `m1/QA-R5/crops/`.
- Protokolle: `m1/QA-R5/logs/` (qa_scan, r5_full_scan, mutate, modern_sight_full, modern_path_full, run_tests_full,
  render_*, golden_check, bench_*, perf_*), Mutationen `m1/QA-R5/mutations/` (results.json + je Mutation ein Log).
- Werkzeuge: `m1/QA-R5/tools/` (shots.sh, queue1–4.sh, mutate.py, crop.py, sheet.py, make_sheets.sh) und die
  Prüfskripte `qa_scan.gd`, `bench_r5.gd` (Kopie in `m1/QA-R5/tools/gd/`).
