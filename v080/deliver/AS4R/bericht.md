# AS4R – Nacharbeit der Gebäude, Brückenteile und Schiffe nach der Kunstkritik (Bericht)

Paket **AS4R** von v0.8.0 „Modern“ (Vorstart M2). Zweig `worktree-wf_aad8d49e-fb4-6`, gesichert als
`origin/wip/v080-as4r`; Basis `9eef9a8` (AS4), Endstand `09f679b`. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-6`.
Zahlen sind mit **(gemessen)** oder **(gefolgert)** markiert; ohne Zusatz in den Tabellen gilt „gemessen“.
Gemessen heißt: auf dieser VM, Software-OpenGL (llvmpipe) unter Xvfb, Renn-Look der Prüfszene von AS3 bzw.
`tools/ab_shot.sh`. Alles über echte Grafikkarten, das Steam Deck oder die Wirkung auf einen Menschen ist gefolgert.

## Kurzfassung

- **Der hohe Fehler ist behoben.** Die Seile des Pylons endeten 0,4 m **in** der Fahrbahn; jetzt enden sie
  außerhalb der Geländerlinie (Seilende quer 3,35 → 6,40 m bei Fahrbahnkante 3,75 m und Geländer 6,25 m), der
  Fächer ist ±36 statt ±82,7 m lang (passt auf alle fünf Schrägseilbrücken), das Bein steht senkrecht, und es gibt
  nur noch eine Stufe (der Stufenwechsel änderte 58 % der Pixel). Im Rennbild der Köhlbrandbrücke kreuzt kein Seil
  mehr die Spuren.
- **Fenster bei Tag und Nacht.** Die Scheiben waren `vpbr`-Lampen und zeigten bei Tag die halbe Leuchtfarbe
  (braun neben blau). Jetzt ist die Scheibe der zurückgesetzte Lochfüller: bei Tag das gemalte Glas des Sprites
  (Braunanteil der dunklen Pixel z. B. Block A 23,6 → 4,1 %, Laden 8,3 → 0,0 %), nachts das Licht des Sprites für
  genau dieses Fenster – es leuchten dieselben Fenster wie in Arcade, fast so hell (Spitze 165 → 216, Arcade 225).
- **Kleinere Befunde:** Shed-Glas der Fabrik ohne weiße Dreiecke (weiße Dachpixel nachts 12 690 → 0), Büroturm ohne
  Spalten und ohne weißes Foyer, Ladenschild mit Zeichen, Kirche im Rennen so hell wie Arcade (Wand 204 → 181,
  Arcade 173), Fachwerkportal bei 100 m mit dem Kontrast des Sprites (95 → 108, Sprite 109).
- **Abgelehnt:** M7 (Mühlenflügel „2–3× Flimmern“: Messartefakt; mit bewegter Kamera 1,3–1,7×, ein Umbau der
  Flügel änderte nichts) und die Texeldichte der Fabrik-Seitenwand (29,3 statt 18,7 px/m).
- **Nicht im Modell lösbar:** Schiffe auf der Wiese (Modern hat kein Wasser – R2) und die Pylonhöhe je Brücke
  (neues Set `props/bridge_pylon_bare` für R2/R5).
- Gates auf dem Endstand: Prüfer OK, Geometrie-Gate 86 von 86 identisch, Schlüssel OK, zweiter erzwungener Export byte-identisch,
  A/B-Bilder ohne Skriptfehler, `run_tests.sh` grün (692 Tests, 0 fehlgeschlagen), Golden 20 von 20 identisch
  (alles gemessen).

## Die Befunde der Kritik: geprüft, behoben oder abgelehnt

Jeder Befund wurde zuerst nachgeprüft (Code, Netzdaten, eigene Bilder). „vorher“ = AS4 (`9eef9a8`), „nachher“ =
Endstand.

| Befund (Schwere) | Prüfung | Ergebnis | vorher → nachher (gemessen) |
|---|---|---|---|
| **M1** Pylon-Seile in den Fahrspuren (hoch) | Netz + Zählung aller Schrägseilbrücken (`pylon_census.gd`) | **bestätigt**: Deckanker x −4,2 m → bei Aufstellung 7,55 m Welt-x 3,35 m, Fahrbahnkante 3,75 m – 0,4 m **in** der Fahrbahn, 0,6 m hoch; Fächer ±82,7 m bei 40,5–70,5 m Platz bis zum Brückenende | Seilende Welt-x 3,35 → 6,40 m (außerhalb der Geländerlinie 6,25 m), Fächer ±82,7 → ±36 m, Bein senkrecht, Sockel endet an der Deckkante; Rennbild: kein Seil mehr über den Spuren |
| **M2** Schiffe auf der Wiese (hoch) | Rennbild | **bestätigt**, aber **nicht im Modell lösbar**: Modern hat kein Wasser | unverändert; Bedarf an R2/R5 |
| **M3** Scheiben bei Tag braun/blau (mittel) | `vpbr.gdshader` gelesen: Kanal 12 unbeleuchtet = Leuchtfarbe × `lamp_off_props` 0,5 | **bestätigt** | Braunanteil unter den dunklen, farbigen Pixeln der Nahansichten: Laden 8,3 → 0,0 %, Altstadt 21,4 → 3,3 %, Block A 23,6 → 4,1 %, Block B 16,4 → 2,8 %, Haus 10,6 → 5,2 % |
| **M4** Fabrik: weiße Dreiecke nachts (niedrig–mittel) | Normalen der Sheds (`probe_saw.py`), Emissionsatlas je Dreieck (`emit_probe.gd`) | **Mangel bestätigt, Ursache anders**: keine verdrehten Flächen – es leuchten die senkrechten Glasbänder (#cfe0ff × 0,9 → reinweiß), über der Schräge des nächsten Sheds als Dreieck sichtbar | weiße Pixel (alle Kanäle > 200) über den Wänden, acht Drehungen bei 70 m: 12 690 → 0; hellster Wert 255 → 163 |
| **M5** Pylon-Stufenwechsel 58 % (mittel) | – | **bestätigt** | eine Stufe: kein Wechsel mehr |
| **M6** Nachtfenster matter als Arcade (mittel) | Rennbild Paris–Tours km 131,3, 23 Uhr, hoch; derselbe Ausschnitt wie die Kritik | **bestätigt** | Spitze 165 → 216 (Arcade 225), Pixel > 150: 143 → 379 (543), > 200: 0 → 163 (388); Farbe der 50 hellsten (208,160,87) → (255,212,120), Arcade (255,226,131); es leuchten jetzt dieselben Fenster wie in Arcade |
| **M7** Mühlenflügel flimmern 2–3× (mittel) | Messung wiederholt; Rotor-Code in `vpbr.gdshader` gelesen | **abgelehnt in der Höhe** (Messartefakt): die Messung verschiebt das Modell, die Rotorphase hängt an der Weltposition (0,37 rad/m) – bei 120 m dreht sich der Flügel um 1,1 px je Viertelpixel-Schritt. Mit bewegter Kamera 4,2 / 3,3 / 5,6 / 7,5 % gegen Sprite 2,9 / 2,5 / 4,4 / 4,3 % (60 / 120 / 250 / 400 m) = 1,3–1,7× | Flügel unverändert: 7 statt 13 Sprossen (0,13 m) ergaben 3,7 / 3,3 / 5,7 / 7,5 % – keine Besserung, verworfen |
| **M8** Büroturm: Foyer weiß, Fenster in Spalten (niedrig) | Nachtbild, Code (crc32 ähnlicher Texte) | **bestätigt** | Foyer 100 → 20 % Licht, mit Pfosten und Kämpfer; Auswahl der hellen Scheiben per SHA-1 (293 von 840): keine Spalten (Bild) |
| **M9** Ladenschild leer, nachts weißer Kasten (niedrig) | Nachtbild | **bestätigt** | Zeichen (Einkaufstasche zwischen zwei Balken, spiegelsymmetrisch, 22 Dreiecke, nachts beleuchtet), Schildlicht 100 → 25 %; Schaufenster unverändert |
| **M10** Fachwerkportal blass bei 400 m (niedrig) | Bild, Kontrast zum Himmel | **bestätigt** | Kontrast 100 / 250 / 400 m: 95 / 100 / 82 → 108 / 106 / 94 (Sprite 109 / 131 / 138) |
| **M10** Kirche kalkweiß im Rennen (niedrig) | Rennbild Paris–Tours 12 Uhr | **bestätigt** | Wand Mittel / p95: 204 / 229 → 181 / 200 (Arcade 173 / 194) |
| **M10** Fabrik-Straßenseite 18,7 px/m (niedrig) | Texeldichte nur der Wandebene x = −17 m (`texel_wall.gd`) | **abgelehnt**: 29,3 px/m. Das Richtungsfach der Kritik enthielt die verdeckten Shed-Glasbänder (5 × 62 m² mit Gewicht 0,03) | – |
| **M10** Hausboot-Rückseite, Kirche Rückgiebel, Fähre aus der Nähe (niedrig) | – | bestätigt | **nicht behoben** (selten zu sehen; die Wände des Hausboots kommen aus `props_cities.py`, das nicht AS4R gehört) |

## Was geändert ist

**Pylon** (`ce3d/bridges3d.py`: `_upright`, `fan_cables`; Katalog `props/bridge_pylon`)
- Das Bein des Generators neigt sich um 3,5° zur Straße (Kopf 5 m über der Fahrbahnkante). `_upright` stellt es
  senkrecht (Scherung bis 82 m, darüber der Versatz des Kopfes), rückt es 0,9 m nach außen und kappt den Sockel an
  der Deckkante: Fuß und Sockel enden bei Modell-x −1,3 m (= Geländerlinie bei 7,55 m Aufstellung).
- `fan_cables` ersetzt die zehn Seile je Seite des Generators durch sieben: Kopfanker 55–79 m auf der Straßenseite
  des Beins, Deckanker bei x −1,15 m (Seilachse; mit 0,32 m Stärke enden die Seile außerhalb der Geländerlinie), 1,1 m
  hoch wie in Arcade, 8–36 m vor und hinter dem Pylon, als Halbfächer ohne Kreuzung (der höchste Anker läuft am
  weitesten – Generator und Arcade kreuzen ihre Seile).
- 36 m: die Zählung aller Schrägseilbrücken des Netzes (`pylon_census.gd`, 5 Brücken, 44 Pylone) ergibt als
  kleinsten Platz vom Pylon zum nächsten Brückenende 40,5 m (Elisabeth- und Vanšu-Brücke, je 150 m); Arcade zeichnet
  `cables` = min(64 m, 0,24 × Länge) = 33,8–62,6 m. Engster Bogen an einem Pylon R 449 m: das gerade Seil endet dort bis
  1,4 m neben der Deckkante – auf dem Seitenstreifen (2,5 m), nicht in der Fahrbahn (gerechnet).
- Eine Stufe (232 Dreiecke, vorher 520 / 520 in zwei Stufen), die Ankerplatten (`bpy_anch`) entfallen.
- `extent_m` = Wert des Sprites aus dem Generatornetz (`extent_source`): der kürzere Fächer hätte die Ausdehnung
  in der Sprite-Ansicht verändert; der Pylon wird nicht kantenbündig gestellt (kein `align`).
- Neu **`props/bridge_pylon_bare`** (`bare`, Set `modern_only`): derselbe Pylon ohne Seile (120 Dreiecke) für R2/R5.

**Fensterscheiben** (`ce3d/buildings3d.py`: `_filler_mat`, `_settle_fillers`, `_pane_mask`, `Patches`)
- Die Lochfüller (Kopie des Fassadenmaterials, schließt jedes Loch für den Farb-Bake) behalten bei Fenstern das
  Licht des Sprites × `PANE_LIGHT_K` 0,55 und werden nach Farb- und Licht-Bake um die Laibungstiefe zurückgesetzt –
  sie **sind** die Scheiben. Bei Tag: das gemalte Glas, 8 % zum Himmel getönt (`PANE_TINT`), ohne
  Umgebungsverdeckung. Nachts: das Licht des Sprites für genau dieses Fenster aus dem Nachtlicht-Atlas.
- Füller von Türen und Schallluken werden wie bisher gelöscht.
- Vorhangfassade und Mühlenfenster (kein gemaltes Fenster dahinter): `Patches` – je Material ein kleines Quadrat
  unter dem Modell wird mitgebacken, alle Scheiben lesen dessen Atlasfeld.
- `PANE_LIGHT_K` 0,55: so liegt die Spitze der Fenster im Rennen bei 216 (Arcade 225) und die Farbe nahe am
  Sprite (geprüft mit 0,4: orange und dunkler).

**Fabrik** (`_skylight`): die fünf Shed-Glasbänder bekommen ein eigenes Material – Glas des Sprites mit Sprossen alle
1,4 m, Kämpfer und Randrahmen; Licht #cfe0ff × 0,9 × 0,3, nach oben auf die Hälfte abklingend, nur in den Scheiben.

**Büroturm** (`_curtain`): Scheiben als Atlasfelder im Glasverlauf des Sprites (#2c4256 unten → #6f8ea8 oben, sechs
Stufen); 35 % (293 von 840) leuchten in drei Stärken, ausgewählt per SHA-1 je Seite, Geschoss, Achse; Foyer: `light_scale`
`tower_lobby` 0,2, davor 13 Pfosten (vpbr) und ein Kämpfer.

**Ladenhaus** (`_bag_logo`, `_sign` mit `panel=None`): Einkaufstasche mit Henkel zwischen zwei Balken auf dem Schild
des Generators (22 Dreiecke, Kanal 14), Schildlicht `light_scale` 0,25.

**Kirche**: Hook `plaster` in `props_buildings.church` (Voreinstellung = Sprite), Katalog `#ccc6b7`.

**Fachwerkportal** (nur Katalog): Streben im Ausschneidebild 1,2× breiter und 15 % dunkler (`web_k`, `web_dark`),
Stahl `#49585a` statt `STEEL_GREEN` `#56676a` des Sprites (`steel`): Sonne und Himmelslicht machen das Modell heller
und blauer als das vorbeleuchtete Sprite. Die Streben allein brachten bei 400 m nur +4 Kontrast (82 → 86), der Stahl
weitere +8 (→ 94); bei 100 m gleicht das Portal jetzt dem Sprite.

**Werkzeuge** (nur Scratch, nicht eingecheckt): `pylon_census.gd`, `emit_probe.gd`, `probe_saw.py`,
`texel_wall.gd`, `my_scene.gd` (`--mode=sparkcam`: Flimmern mit bewegter Kamera, Kontrast zum Hintergrund),
`lum.py` (Fensterlicht im A/B-Ausschnitt).

## Messungen vorher / nachher

Alle Werte gemessen (Software-OpenGL). Die Werkzeuge liegen im Scratch (`hue_tiles.py`, `lum.py`, `wall.py`,
`truss_contrast.py`, `my_scene.gd`), nicht im Repo.

| Messung | Szene / Methode | AS4 | AS4R | Arcade / Sprite |
|---|---|---|---|---|
| Pylon: Seilende quer | Netz, Aufstellung 7,55 m | 3,35 m (in der Fahrbahn) | 6,40 m | 6,15 m |
| Pylon: Fächer längs | Netz | ±82,7 m | ±36 m | 33,8–62,6 m je Brücke |
| Pylon: Stufenwechsel | Prüfszene | 58 % der Pixel | eine Stufe | – |
| M3: Braun unter den dunklen, farbigen Pixeln (max < 95, max − min > 8; Farbton 15–55°) | Nahansichten 12 Uhr, hoch, vorne / schräg / Straße / hinten | Laden 8,3 · Altstadt 21,4 · Block A 23,6 · Block B 16,4 · Haus 10,6 · Turm 1,0 % | 0,0 · 3,3 · 4,1 · 2,8 · 5,2 · 0,0 % | – |
| M3: Blau (180–250°) ebenda | dto. | 11,7 · 34,7 · 49,7 · 34,1 · 10,1 · 97,7 % | 38,3 · 58,1 · 75,8 · 52,7 · 17,4 · 98,7 % | – |
| M6: Fensterlicht Spitze / Pixel > 150 / > 200 | Paris–Tours km 131,3, 23 Uhr, hoch, Ausschnitt (880,260)–(1060,400) | 165 / 143 / 0 | 216 / 379 / 163 | 225 / 543 / 388 |
| M6: Farbe der 50 hellsten Pixel | dto. | (208,160,87) | (255,212,120) | (255,226,131) |
| M4: weiße Pixel über den Wänden / hellster Wert | Fabrik 23 Uhr, 70 m, acht Drehungen | 12 690 / 255 | 0 / 163 | – |
| M10: Kirchenwand Mittel / p95 | Paris–Tours km 130,5, 12 Uhr, hoch | 204 / 229 | 181 / 200 | 173 / 194 |
| M10: Fachwerkportal, Kontrast zum Himmel | 12 Uhr, mittel, 100 / 250 / 400 m | 95 / 100 / 82 | 108 / 106 / 94 | 109 / 131 / 138 |
| M10: Fachwerkportal, Pixel bei 400 m | dto. | 346 | 353 | 310 |
| M7: Mühle, Flimmern mit bewegter Kamera | 12 Uhr, mittel, 60 / 120 / 250 / 400 m | 4,2 / 3,3 / 5,5 / 7,5 % | 4,2 / 3,3 / 5,6 / 7,5 % (unverändert) | 2,9 / 2,5 / 4,4 / 4,3 % |
| M7: Mühle, Flimmern wie die Kritik (Modell verschoben) | dto. | 9,3 / 9,9 / 9,2 / 9,3 % | 9,3 / 10,0 / 9,2 / 9,3 % | 2,9 / 2,5 / 4,4 / 4,3 % |
| Nebenwirkung: Block B, Flimmern | dto. | 0,1 / 0,1 / 0,7 / 0,9 % | 0,2 / 1,0 / 0,8 / 0,6 % | 0,1 / 0,2 / 0,5 / 0,4 % |
| Nebenwirkung: Fabrik, Turm, Flimmern | dto. | 0,0–0,1 % | 0,0–0,1 % | 0,1–1,7 % |
| Fachwerkportal, Flimmern | 12 Uhr, mittel, 50 / 100 / 250 / 400 m | 1,1 / 2,5 / 8,1 / 6,7 % | 1,0 / 2,4 / 7,7 / 8,5 % | 2,7 / 4,8 / 10,3 / 13,7 % |
| Stufenwechsel bei 60 m, mittel | Haus / Kirche / Fabrik / Laden / Altstadt / Block A / Block B | 11,3 / 3,4 / 6,5 / 4,2 / 8,1 / 8,3 / 8,9 % | 11,2 / 3,0 / 7,0 / 5,4 / 8,4 / 8,2 / 9,4 % | – |
| Stufenwechsel nachts bei 60 m | Laden / Block B / Haus / Kirche | – | 5,1 / 8,3 / 8,5 / 1,7 % | – |

Zur Messweise: Die Befunde M3, M6 und Kirche sind mit denselben Ausschnitten auch auf den Bildern der Kritik
gemessen (die AS4-Werte stimmen mit ihren Angaben überein: Spitze 165, Kirchenwand p95 229). Die Flimmerwerte der
Brücke sind mit denen der Kritik nicht vergleichbar: die Prüfszene richtet die Kamera auf die Mitte des Modells aus,
und die hat sich mit dem kürzeren Fächer verschoben.

## Modelle und Budgets (gemessen: `validate_models.py --report`, Export-Bericht)

| Modell | Kategorie (Budget Dr. / Aufrufe) | Dreiecke je Stufe | Aufrufe | Netze B | Texturen (Quelle B) | Atlas | px/m | Export s | Bake s |
|---|---|---|---|---|---|---|---|---|---|
| `props/house_med` | rural (2 000 / 2) | lod0 1343 · lod1 761 | 2/2 | 26952 | albedo.png, emit.png (480449) | 1024x1024 | 59.85 | 83.99 | 0.03 |
| `props/church` | rural (2 000 / 2) | lod0 1740 · lod1 1284 | 2/2 | 42540 | albedo.png, emit.png (531725) | 1024x1024 | 29.95 | 206.77 | 0.01 |
| `props/factory` | rural (2 000 / 2) | lod0 1624 · lod1 1108 | 2/2 | 33022 | albedo.png, emit.png (665268) | 1024x1024 | 29.46 | 142.39 | 0.02 |
| `props/building_shop` | city (10 000 / 2) | lod0 1107 · lod1 779 | 2/2 | 23333 | albedo.png, emit.png (296335) | 1024x1024 | 44.23 | 85.49 | 0.01 |
| `props/building_oldtown` | city (10 000 / 2) | lod0 2328 · lod1 1576 | 2/2 | 45398 | albedo.png, emit.png (501390) | 1024x1024 | 40.71 | 128.2 | 0.02 |
| `props/building_block_a` | city (10 000 / 2) | lod0 4596 · lod1 3156 | 2/2 | 79864 | albedo.webp, emit.png (110904) | 2048x1024 | 49.0 | 194.33 | 0.02 |
| `props/building_block_b` | city (10 000 / 2) | lod0 5180 · lod1 3476 | 2/2 | 87381 | albedo.webp, emit.png (822785) | 2048x1024 | 44.0 | 258.47 | 0.02 |
| `props/building_tall` | city (10 000 / 2) | lod0 2565 · lod1 2513 | 2/2 | 51920 | albedo.webp, emit.png (92197) | 2048x1024 | 29.82 | 549.54 | 0.01 |
| `props/windmill` | rural (2 000 / 2) | lod0 1928 | 2 | 29639 | albedo.png, emit.png (815954) | 1024x1024 | 31.24 | 76.4 | 0.02 |
| `props/houseboat` | rural (2 000 / 2) | lod0 1054 | 2 | 19841 | albedo.png, emit.png (210570) | 1024x512 | 37.28 | 71.4 | 0.03 |
| `props/ferry_ship` | rural (2 000 / 2) | lod0 1449 | 2 | 24361 | albedo.png, emit.png (458078) | 1024x1024 | 12.19 | 105.15 | 0.02 |
| `props/bridge_lamp` | furniture (1 500 / 1) | lod0 882 | 1 | 12092 | - (0) | - | - | 0.15 | 0.01 |
| `props/bridge_pylon` | pylon (5 000 / 1) | lod0 232 | 1 | 4699 | albedo.png, emit.png (218711) | 1024x1024 | 31.67 | 56.15 | 0.02 |
| `props/bridge_pylon_bare` | pylon (5 000 / 1) | lod0 120 | 1 | 2642 | albedo.png, emit.png (218605) | 1024x1024 | 31.67 | 48.39 | 0.01 |
| `props/bridge_truss_arch` | furniture (1 500 / 1) | lod0 1100 | 1 | 12862 | albedo.png, emit.png (76712) | - | - | 1.22 | 0.01 |

Summe AS4R: Netze 496546 B (0.47 MB), Texturquellen 5499683 B (5.24 MB)

Exportzeiten aus dem zweiten, erzwungenen Export auf dem Endstand (eine Arbeitsinstanz, `CE_THREADS=2`, `nice -n 19`,
Software-Cycles auf dieser VM); Bake = `bake_models.gd` je Modell. Alle Modelle liegen weit unter ihren Budgets
(Dreiecke und Aufrufe); Gesamtstand laut Prüfer: Netze 4,92 MB von 40 MB, Texturen 28,77 MB im Grafikspeicher von
240 MB, Quellen 14,75 MB von 60 MB (42 Modelle, 183 Sets, 54 mit Modell).

## Gates (auf dem Endstand)

Alle Gates liefen auf dem Endstand `09f679b` (Modelle seit `8dd2fef` unverändert), eines nach dem anderen mit
`nice -n 19` und einer Arbeitsinstanz. Logs im Scratch unter `m1/AS4R/gates/`.

| Gate | Ergebnis (gemessen) |
|---|---|
| `validate_models.py --report` | **CHECK models OK** – 42 Modelle, 183 Sets (54 mit Modell); Netze 4,92 MB von 40 MB, Texturen 28,77 MB im Grafikspeicher von 240 MB, Quellen 14,75 MB von 60 MB |
| Budgettabelle | oben; alle 15 AS4R-Modelle unter Dreiecks- und Aufrufbudget |
| `check_sprite_geometry.py --only props --jobs 1` | **CHECK sprite_geometry OK** – 86 Sprite-Sets: 86 identisch, 0 verändert, 0 fehlen, kein „ANDERS“ (240 s) |
| `export_models.py --check-keys` | **CHECK cache_keys OK** (136 s) |
| zweiter, erzwungener Export aller 15 Modelle (`--force`, mit Bake, Import, Manifest) | Arbeitsbaum danach **unverändert** (`git status` leer) = byte-identisch (2 022 s) |
| `tools/ab_shot.sh` (Arcade gegen Modern) | sechs Läufe an fünf Stellen (Kiel–Hamburg km 77,4 und km 82,9 mit Deck, Paris–Tours km 129 mittags und nachts, Dortmund–Bremen km 1,9 nachts, Dresden–Leipzig km 111 nachmittags): **0 Skriptfehler** in jedem Modern-Protokoll |
| `tools/run_tests.sh` (einmal, `XDG_DATA_HOME` absolut im Scratch) | **Tests bestanden** – 692 Tests, 0 fehlgeschlagen; 156 CHECK-Zeilen OK, 0 FEHLER (833 s) |
| `tools/golden.sh check` (einmal, `TMPDIR` im Scratch) | **GOLDEN arcade: 20 von 20 identisch** (155 s) |

Die Prüfwerkzeuge der Kritik (`tools/kritik/`, unversioniert) wurden vor `run_tests.sh` gelöscht; sie liegen mit den
eigenen Werkzeugen im Scratch (`m1/AS4R/install_tools.sh`).

## Geänderte gemeinsame Dateien (rückwärtskompatibel, additiv)

| Datei | Änderung |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | nur im Block `# --- AS4 ---`: Einträge von Pylon (aufrecht, `fan`, `extent_source`), Kirche (`plaster`), Fabrik (`skylight`), Büroturm (`light_scale`, Glasverlauf, Foyer), Laden (`sign` mit `logo="bag"`, `light_scale`), Fachwerkportal (`web_k`, `web_dark`, `steel`), Windmühle (nur Kommentar); neu `props/bridge_pylon_bare` (Set `modern_only`) |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`): 42 Modelle, 183 Sets (54 mit Modell) |
| `docs/modelle.md` | Abschnitt 15: Unterabschnitt „Nacharbeit nach der Kunstkritik (AS4R)“, Tabelle nachgezogen |

Keine Änderung an `core`, `glb`, `roles`, `bake`, `lod`, `manifest`, `export`, `export_models.py`,
`validate_models.py`, `tools/models/**`, `model_db.gd`. Eigene Dateien: `ce3d/buildings3d.py`, `ce3d/bridges3d.py`,
Hook `plaster` in `cesprites/props_buildings.py` (Voreinstellung = Sprite), `assets/models/props/<15 Modelle>`.
Nicht angefasst: `props3d.py`, Renderer, Shader, Fahrzeuge, AS3-Dateien, `city_*`, Wahrzeichen, eingefrorene Dateien.

Hinweis zur Zusammenführung: `cesprites/props_buildings.py` gehört zum Schlüssel des Bauers `building` (AS1b:
Bauernhaus, Scheune, Tankstelle, Zollhäuschen …) – deren Schlüssel ändern sich, ihre Dateien nicht (nur
`church()` hat einen Hook bekommen; Geometrie-Gate grün).

## Abweichungen

- **Fensterscheiben im Atlas statt `vpbr`-Lampen** (D20 nennt Nachtfenster Vertex-Codes): Kanal 12 zeigt
  unbeleuchtet die halbe Leuchtfarbe – braune Scheiben bei Tag. Die Scheibe ist der zurückgesetzte Lochfüller
  (Glas im Albedo, Licht im Nachtlicht-Atlas, `baked`-Klasse, wie es §4.6.4 für gebackene Modelle vorsieht).
- **Scheiben 8 % zum Himmel getönt und ohne Umgebungsverdeckung** (gegenüber dem Glas des Sprites rund 10 Stufen
  heller): sonst flimmerten die Rahmenkanten der Wohnblöcke stärker als bei AS4.
- **Pylon: Fächer 36 m statt „≤ 60 m“ der Kritik**: 60 m ragten bei drei der fünf Brücken über das Brückenende;
  Seilachse bei x −1,15 statt −1,4 m (die 0,32 m starken Seile enden so außerhalb der Geländerlinie).
- **Pylon: `extent_m` aus dem Generatornetz** (Wert des Sprites) statt aus dem Modell – der kürzere Fächer hätte die
  Ausdehnung in der Sprite-Ansicht verkleinert; der Pylon wird nicht kantenbündig gestellt.
- **Neues Set `props/bridge_pylon_bare`** (`modern_only`, von keiner Etappe gestellt) für R2/R5.
- **M7 in der Höhe abgelehnt** (Windmühle unverändert; echter Rest 1,3–1,7× das Sprite, ein Umbau der Flügel half
  nicht) und **M10 Fabrik-Seitenwand abgelehnt** – Belege in der Befundtabelle.
- **Nicht behoben (niedrig):** fensterlose Rückseite des Hausboots (Wände aus `props_cities.py`), unscharfes Fenster
  im Rückgiebel der Kirche, Fähre aus der Nähe, flache Schaufenster.

## Vertragsfragen

- **D20 / §4.6.4 – Nachtfenster:** Ein Nachtrag sollte Fensterscheiben von Gebäuden im Nachtlicht-Atlas der
  `baked`-Klasse festhalten (Kanal 12 nur für Lampen mit Lichtanker) oder `vpbr` eine Tagesfarbe für Kanal 12 geben
  (`lights_day_tint`, R4). Belege: Kritik M3, AS1b- und AS4-Bericht.
- **§4.6.6 / §4.6.8 – `extent_m` = Sprite:** Die Regel setzt gleiche Geometrie voraus. Für Requisiten, die nicht
  kantenbündig gestellt werden (Pylon), sollte der Prüfer die Abweichung erlauben oder `extent_m` aus dem Sprite
  übernehmen lassen (hier: `extent_source`).
- **Brückenpylon als Modell:** Arcade passt Höhe (`height_m` 50–120 m) und Fächer (`cables` 33,8–62,6 m) je Brücke an;
  ein Modell fester Form passt nie zu allen. Vorschlag: der Pylon ohne Seile (`props/bridge_pylon_bare`) als Teil,
  Seile vom Renderer (R2 jetzt, R5 später).

## Bedarf bei anderen Paketen

- **R2 (jetzt, Testbuild):** Requisiten mit `h` < 0 (Fähren, Hausboote) auslassen, solange kein Wasser-Bauer
  registriert ist – auf Kiel–Hamburg stehen bei km 78,9 / 79,1 / 84,6 Fähren auf der Wiese.
- **R2/R5:** `props/bridge_pylon_bare` + Seile je Brücke aus `height_m`, `cables` und der Deckkante (wie
  `RoadRenderer._pylon()`), Pylon nach `height_m` / 88,8 nur in der Höhe skaliert; Maße unten.
- **R3/R4 (`vpbr.gdshader`):** Die Rotorphase (`wp0.x × 0,37 + wp0.z × 0,23`) hängt an der ursprungsrelativen Position:
  bei jedem Versatz des Ursprungs (alle 2 km, `rebase_m`) springen alle Flügel. Eine Phase aus einem festen Wert
  (z. B. Instanzfarbe oder Strecken-z) würde es lösen.
- **R4 (Nacht):** Fensterlicht kommt jetzt aus dem Nachtlicht-Atlas (`emit_energy` 1,6), abgeglichen gegen Arcade
  (Spitze 216 gegen 225 bei 23 Uhr); wer `emit_energy` ändert, gleicht hier nach.
- **AS1b-Gebäude (Bauernhaus, Zollhäuschen, Tankstelle):** haben noch Kanal-12-Scheiben (dasselbe Braun-Blau bei Tag).
  Mit dem Bauer `house` (wie die Windmühle) wären sie behoben; `props3d.py` teilt seinen Schlüssel mit den Büschen
  von AS3, darum hier nicht angefasst.
- **Prüfwerkzeuge:** Flimmern drehender Modelle mit bewegter Kamera messen (`my_scene.gd --mode=sparkcam` im Scratch);
  Texeldichte je Wandebene statt je Richtungsfach.

## Maße für R5 (geändert gegenüber AS4)

**`props/bridge_pylon`** (Modellraum des Manifests: +X quer, +Y oben, −Z entlang der Fahrbahn; Ursprung = Fußpunkt
= Aufstellpunkt des Requisits, Deckhöhe y = 0)
- AABB x −1,575 … 3,949, y 0 … 88,75, z ±36,15 m. Bein senkrecht, Mitte bei x +0,9 m; Querschnitt 4,4 × 6,0 m am Fuß
  (x −1,3 … 3,1), 2,7 × 3,6 m bei 82 m; Kopf bis 83,2 m, Kappe bis 88,0 m; Sockel x −1,3 … 3,9, z ±4,0, 0,8 m hoch.
- Seile: 7 je Seite, 0,32 m stark. Kopfanker y 55 … 79 m (4 m Teilung), x = 0,9 − (2,2 − 0,85 y/82) + 0,05 m
  (Straßenseite des Beins), z ±0,6 m; Deckanker x −1,15 m, y 1,1 m, z ±(8,0 + 4,667 k) m, k = 0 … 6 (der höchste Anker
  zum weitesten Punkt, keine Kreuzung).
- Flugbefeuerung: Anker (0,45 | 88,3 | 0), Richtung (−1, 0, 0), rot.
- `props/bridge_pylon_bare`: dasselbe ohne Seile; AABB x −1,3 … 3,949, z ±4,0 m.
- Fachwerkportal und Laterne: unverändert (Maße im AS4-Bericht).

## Ehrliche Einordnung

**Was der Spieler jetzt sieht (gemessen in den Bildern dieses Ordners, Wirkung gefolgert):**

- **Pylon:** Die Spuren sind frei; die Seile laufen als Halbfächer vom Kopf zur Deckkante neben dem Geländer, das Bein
  steht senkrecht. Aus dem Fahrersitz sieht man den Fächer fast in Längsrichtung – er wirkt schmaler als das
  Arcade-Bild (dort zeigt das Billboard die Seitenansicht), ist aber räumlich richtig. Kein Stufenwechsel mehr.
- **Fenster:** Bei Tag sind alle Scheiben einer Fassade gleich (Glas des Sprites), nachts leuchten dieselben Fenster
  wie in Arcade und fast so hell, etwas oranger (hellste Pixel (255,212,120) gegen (255,226,131)).
- **Fabrik:** nachts keine reinweißen Dreiecke mehr, das Shed-Glas liest sich als Verglasung. **Büroturm:** Lichter
  verstreut statt in Spalten, das Foyer ist kein weißes Band mehr. **Laden:** Schild mit Zeichen. **Kirche:** im
  Rennen so hell wie in Arcade. **Fachwerkportal:** bei 30–100 m wie das Sprite.

**Was noch nicht gut ist:**

- Die Scheiben sind etwa 10 Stufen heller als das gemalte Glas des Sprites (Tönung zum Himmel); bei 250 m wirken
  die Fenster von Block B leicht grau-lila, und Block B flimmert bei 120 m mit 1,0 % statt 0,1 % (Sprite 0,2 %) –
  klein, aber gemessen.
- Schaufenster (Laden, Block B) leuchten nachts als weiße, flache Flächen – das Licht des Sprites, aber ohne Auslage.
- Die Mühle flimmert mit bewegter Kamera 1,3–1,7× so stark wie das Sprite (unverändert; ein Umbau der Flügel half
  nicht).
- Das Fachwerkportal bleibt bei 400 m blasser als das Sprite (Kontrast 94 gegen 138): dünne Streben verlieren im
  Alpha-Test der kleinen Mip-Stufen Deckung – das ist mit Farbe nicht weiter zu holen.
- Der Pylon hat eine feste Höhe (88,8 m) und gerade Seile: auf Brücken mit 50 oder 120 m Pylonhöhe passt er nicht
  zu Arcade, in engen Bögen (R 449 m) endet ein Seil bis 1,4 m neben der Deckkante (gerechnet; Seitenstreifen, nicht
  Fahrbahn). Die eigentliche Lösung ist `props/bridge_pylon_bare` mit Seilen vom Renderer.
- Fähren und Hausboote stehen weiter auf der Wiese, bis R2 sie auslässt oder R5 Wasser hat.
- Unverändert: Rückseite des Hausboots, Rückgiebel der Kirche, Fähre aus der Nähe.

**Was fehlt:** Messungen auf echter Grafikkarte und auf dem Steam Deck; Wasser; Seile vom Renderer.

## Bilder (dieser Ordner)

**Vorher / nachher** (vorher = Bilder der Kunstkritik mit AS4, nachher = Endstand, gleiche Szene und Zeit):

| Datei | Inhalt |
|---|---|
| `pylon_rennen_vorher_nachher_01.jpg` … `_03.jpg` | Kiel–Hamburg, Köhlbrandbrücke, 12 Uhr, hoch: vorher kreuzen Seile die Spuren, nachher enden sie neben dem Deck (M1) |
| `pylon_abstaende_vorher_nachher.jpg` | Pylon bei 30 / 100 / 250 / 400 m, je oben Modell, unten Sprite: Bein vorher geneigt, nachher senkrecht, eine Stufe (M1, M5) |
| `fenster_nacht_dorf_vorher_nachher.jpg` | Paris–Tours km 131,3, 23 Uhr: Haus vorher / nachher / Arcade (3× vergrößert) – dieselben Fenster wie Arcade, fast so hell (M6) |
| `kirche_tag_vorher_nachher.jpg` | Paris–Tours km 130,5, 12 Uhr: Kirche vorher / nachher / Arcade – nicht mehr kalkweiß (M10) |
| `scheiben_tag_stadt_vorher_nachher.jpg` | Nahansichten 12 Uhr: Laden, Block A, Block B, Büroturm – vorher braune neben blauen Scheiben, nachher einheitlich (M3) |
| `fenster_nacht_stadt_vorher_nachher.jpg` | Nahansichten 23 Uhr: Ladenschild mit Zeichen, Turm ohne Spalten und ohne weißes Foyer (M8, M9) |
| `fenster_nacht_land_vorher_nachher.jpg` | Nahansichten 23 Uhr: Haus, Kirche, Fabrik |
| `fabrik_shed_nacht_vorher_nachher.jpg` | Fabrik nachts, 70 m, acht Drehungen: vorher reinweiße Dreiecke, nachher verglaste Sheds (M4) |
| `fabrik_nacht_rennen_vorher_nachher.jpg` | Dortmund–Bremen km 2,2, 23 Uhr: Fabrik und Block B vorher / nachher / Arcade |
| `portal_vorher_nachher.jpg` | Fachwerkportal bei 30 / 100 / 250 / 400 m, je oben Modell, unten Sprite (M10) |

**Rennbilder Arcade | Modern** (`tools/ab_shot.sh`, Modern hoch bzw. Deck, alle mit 0 Skriptfehlern):

| Datei | Stelle |
|---|---|
| `ab_kiel_hamburg_km77_4_pylon_mittag_00.jpg` … `_03.jpg` | Kiel–Hamburg ab km 77,4, 12 Uhr – Köhlbrandbrücke |
| `ab_kiel_hamburg_km82_9_fachwerkportale_deck_00.jpg`, `_01.jpg` | Kiel–Hamburg ab km 82,9, 19:30 Uhr, Voreinstellung Deck – Fachwerkportale in der Ferne, rechts eine Fähre ohne Wasser (M2) |
| `ab_paris_tours_km129_dorf_mittag_00.jpg` … `_02.jpg` | Paris–Tours ab km 129, 12 Uhr – Haus und Kirche |
| `ab_paris_tours_km129_dorf_nacht_00.jpg` … `_02.jpg` | dieselbe Stelle um 23 Uhr – Fensterlicht |
| `ab_bremen_dortmund_km1_9_fabrik_nacht_00.jpg`, `_01.jpg` | Dortmund–Bremen ab km 1,9, 23 Uhr – Fabrik, Block B |
| `ab_dresden_leipzig_km111_turm_nachmittag_00.jpg`, `_01.jpg` | Dresden–Leipzig ab km 111, 15 Uhr – Büroturm, Laden |

**Abstände und Nahansichten des Endstands** (Prüfszene im Renn-Look, Modell gegen Arcade-Sprite):

| Datei | Inhalt |
|---|---|
| `abstaende_land_tag.jpg`, `_daemmerung.jpg`, `_nacht.jpg` | Haus, Kirche, Fabrik, Mühle bei 50–400 m; 12 / 19:30 / 23 Uhr |
| `abstaende_stadt_tag.jpg`, `_nacht.jpg` | Laden, Altstadthaus, Block A, Block B bei 30–400 m |
| `abstaende_turm_kirche_gross_tag.jpg`, `_nacht.jpg` | Büroturm (Maßstab 2,15) und Kirche (2,2) bei 100–600 m |
| `abstaende_bruecke_tag.jpg` | Pylon, Laterne, Fachwerkportal bei 30–400 m |
| `abstaende_schiffe_tag.jpg` | Hausboot und Fähre (Prüfszene mit Wasserfläche) |
| `nahansichten_land_tag.jpg`, `_nacht.jpg`, `nahansichten_stadt_tag.jpg`, `_nacht.jpg` | alle Gebäude vorne / schräg / Straße / hinten |
