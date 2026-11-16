# AS4R – Nacharbeit der Gebäude, Brückenteile und Schiffe nach der Kunstkritik (Bericht)

Paket **AS4R** von v0.8.0 „Modern“ (Vorstart M2). Zweig `worktree-wf_aad8d49e-fb4-6`, gesichert als
`origin/wip/v080-as4r`; Basis `9eef9a8` (AS4), Endstand `COMMIT_TODO`. Worktree
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
- Gates auf dem Endstand: GATES_KURZ_TODO

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

TEIL_AENDERUNGEN

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
| Fachwerkportal, Flimmern | 12 Uhr, mittel, 50 / 100 / 250 / 400 m | 1,1 / 2,5 / 8,1 / 6,7 % | PORTAL_FLIMMERN_TODO | 2,7 / 4,8 / 10,3 / 13,7 % |
| Stufenwechsel bei 60 m, mittel | Haus / Kirche / Fabrik / Laden / Altstadt / Block A / Block B | 11,3 / 3,4 / 6,5 / 4,2 / 8,1 / 8,3 / 8,9 % | 11,2 / 3,0 / 7,0 / 5,4 / 8,4 / 8,2 / 9,4 % | – |
| Stufenwechsel nachts bei 60 m | Laden / Block B / Haus / Kirche | – | 5,1 / 8,3 / 8,5 / 1,7 % | – |

Zur Messweise: Die Befunde M3, M6 und Kirche sind mit denselben Ausschnitten auch auf den Bildern der Kritik
gemessen (die AS4-Werte stimmen mit ihren Angaben überein: Spitze 165, Kirchenwand p95 229). Die Flimmerwerte der
Brücke sind mit denen der Kritik nicht vergleichbar: die Prüfszene richtet die Kamera auf die Mitte des Modells aus,
und die hat sich mit dem kürzeren Fächer verschoben.

## Modelle und Budgets (gemessen: `validate_models.py --report`, Export-Bericht)

TEIL_BUDGETS

## Gates (auf dem Endstand)

GATES_TODO

TEIL_REST

## Ehrliche Einordnung

EINORDNUNG_TODO

## Bilder (dieser Ordner)

BILDER_TODO
