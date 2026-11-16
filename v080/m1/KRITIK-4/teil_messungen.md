## 6. Messungen (alle gemessen auf dieser VM, wenn nicht anders gesagt)

### 6.1 Umriss gegen das Sprite (Sprite-Kamera von `cesprites`: `view_yaw` des Sets, 6° bzw. 3,5° Höhe)
`k4_scene --mode=outline2`, Bild `20_umrisse_sprite_gegen_modell.jpg` (grün = beide, orange = nur Modell, blau = nur Sprite).

| Modell | lod0 außerhalb | Sprite gedeckt | IoU lod0 | IoU lod1 |
|---|---|---|---|---|
| house_med | 1,4 % | 100,0 % | 0,986 | 0,998 |
| church | 0,1 % | 99,9 % | 0,997 | 0,999 |
| factory | 0,0 % | 99,3 % | 0,993 | 0,993 |
| windmill | 9,4 % | 88,9 % | 0,814 | – (Flügelstellung: der Rotor dreht mit `ce_time`) |
| building_shop | 0,0 % | 99,8 % | 0,998 | 0,998 |
| building_oldtown | 0,3 % | 99,9 % | 0,996 | 0,999 |
| building_block_a | 0,0 % | 100,0 % | 1,000 | 1,000 |
| building_block_b | 0,0 % | 100,0 % | 1,000 | 1,000 |
| building_tall | 0,0 % | 99,9 % | 0,999 | 0,999 |
| houseboat | 1,7 % | 98,4 % | 0,968 | – |
| bridge_lamp | 1,8 % | 99,3 % | 0,975 | – |
| bridge_truss_arch | 1,9 % | 99,4 % | 0,976 | – |
| bridge_pylon | 5,1 % | 98,8 % | 0,938 | 0,882 (dickere Seile) |
| ferry_ship (Modell um −90° gedreht, Kamera ohne Drehung) | 0,1 % | 99,9 % | 0,999 | – |

Proportionen, Dachformen und Fensterraster stimmen – erwartet, weil die Modelle aus denselben Generatoren stammen.

### 6.2 Texeldichte je Flächenrichtung (`texel_probe.gd`, UV-Fläche × Atlasgröße gegen Weltfläche, lod0)

| Modell | Anfahrt (+Z) | Straßenseite (−X) | abgewandt (+X) | Rückseite (−Z) | Dach |
|---|---|---|---|---|---|
| house_med | 59,8 | 59,8 | 18,0 | 18,2 | 35,5 |
| church | 28,5 | 29,9 | 7,5 | 7,3 | 14,6 |
| factory | 29,2 | **18,7** | 7,3 | 7,3 | 11,8 |
| windmill | 30,5 | 30,0 | 30,0 | 30,5 | 28,9 |
| houseboat | 36,8 | 36,9 | 12,3 | 11,8 | 33,3 |
| ferry_ship (Modellmaß; ×2,5 im Spiel) | 12,1 | 11,9 | 3,6 | 3,6 | 3,7 |
| building_shop | 44,2 | 44,2 | 13,3 | 13,6 | 33,1 |
| building_oldtown | 40,3 | 40,7 | 12,2 | 12,2 | 24,2 |
| building_block_a | 48,9 | 49,0 | 24,5 | 24,6 | 15,1 |
| building_block_b | 43,9 | 44,0 | 22,0 | 22,0 | 13,1 |
| building_tall (÷2,15 im Spiel) | 29,8 | 29,8 | 8,9 | 8,9 | 23,9 |
| bridge_pylon (Mittel über die Höhe) | 18,2 | 15,7 | 15,7 | 18,2 | – |
| farmhouse (AS1b, Vergleich) | 35,1 | 35,1 | 10,5 | 10,6 | 32,3 |

Ziel ≥ 26 px/m an den Wänden zur Straße: erfüllt außer der Fabrik-Seitenwand (18,7) und dem Pylon (AS4: Fuß 29,9,
Kopf 13,4). Die großen Maßstäbe (Turm 2,15, Kirche bis 2,6) senken die Dichte im Spiel auf 11–14 px/m – bei ihrem
Abstand (≥ 68 m, dort 10 px/m Bildschirmauflösung) ausreichend (gerechnet).

### 6.3 Stufenwechsel (`prop_scene --mode=lods`, Renn-Licht 12 Uhr; Anteil der Pixel mit Summe |ΔRGB| > 0,06 und der 3×3-Blöcke)

| Modell | „Mittel“ bei 60 m | „Hoch“ bei 120 m | Helligkeit | nachts bei 60 m |
|---|---|---|---|---|
| house_med (x 34 m) | 11,3 % / 20,8 % | 14,9 % / 18,6 % | +0,9 % / −0,1 % | 8,3 % / 12,7 %, +0,7 % |
| church | 3,4 % / 5,6 % | 4,8 % / 8,3 % | +0,4 % / +0,5 % | 2,0 % / 3,4 %, +0,7 % |
| factory | 6,5 % / 10,9 % | 9,1 % / 6,5 % | −0,1 % | – |
| building_shop (x 18 m) | 4,2 % / 9,3 % | 4,8 % / 9,6 % | −0,3 % / −0,4 % | 5,2 % / 11,3 %, −0,4 % |
| building_oldtown | 8,1 % / 13,9 % | 9,5 % / 18,3 % | 0,0 % / −0,4 % | – |
| building_block_a | 8,3 % / 17,4 % | 10,8 % / 21,0 % | −0,7 % | – |
| building_block_b | 8,9 % / 17,0 % | 10,1 % / 19,4 % | −0,6 % / −1,1 % | 8,6 % / 15,9 %, −0,6 % |
| building_tall | 0,0 % (lod1 = lod0) | – | 0 | – |
| bridge_pylon (x 7,5 m) | **58,5 % / 66,9 %** | – | +1,5 % | – |

Die mittlere Farbe springt nirgends (≤ 1,1 %, bestätigt AS4: ≤ 2/255); was wechselt, sind Sprossen, Rahmen, Uhrzeiger
– Teile von 0,3–0,7 Pixel Breite. Silhouette und Fensterrhythmus bleiben. Ausreißer ist der Pylon (M5).

### 6.4 Flimmern (Viertelpixel-Schritte seitlich, Anteil der Pixel, die je Schritt um > 0,2 kippen; Modell / Sprite)

| Modell | 50–60 m | 100–120 m | 250 m | 400 m |
|---|---|---|---|---|
| building_block_b | 0,1 / 0,1 % | 0,1 / 0,2 % | 0,7 / 0,5 % | 0,9 / 0,4 % |
| building_tall | 0,0 / 0,1 % | 0,0 / 0,1 % | 0,0 / 0,5 % | 0,0 / 0,7 % |
| factory | 0,0 / 0,2 % | 0,0 / 0,5 % | 0,1 / 1,1 % | 0,1 / 1,7 % |
| windmill | **9,3 / 2,9 %** | **9,9 / 2,5 %** | **9,2 / 4,4 %** | **9,3 / 4,3 %** |
| bridge_pylon | 3,0 / 3,0 % | 6,0 / 5,1 % | 0,8 / 6,4 % | 0,8 / 6,2 % |
| bridge_lamp | 7,8 / 5,2 % | 13,6 / 11,2 % | 27,7 / 38,4 % | 37,0 / 61,5 % (19 / 3 px) |
| bridge_truss_arch | 1,1 / 2,7 % | 2,5 / 4,8 % | 8,1 / 10,3 % | 6,7 / 13,7 % |

Gebäude flimmern nicht mehr als ihre Sprites (Block B bei 250–400 m knapp mehr: 0,7–0,9 gegen 0,4–0,5 %); Fachwerkportal und Pylon flimmern weniger als die Sprites; die Windmühle 2–3×
mehr (M7). Bewegtbilder (120 km/h, 30 Bilder/s): `30_film_pylon.mp4`, `31_film_portal.mp4`, `32_film_muehle.mp4`
(angesehen; llvmpipe, ohne echte GPU – gefolgert für das Steam Deck).

### 6.5 Fenster bei Tag und Nacht (Netzdaten mit `mesh_probe.gd`, Bildpixel)
- Leuchtfarben Kanal 12: Haus (120, 92, 50), Block B (120, 92, 51), Kirche (120, 98, 57), Turm (125, 103, 83);
  Gewichte 0,50–1,00. Glas ohne Lampe: Haus (38, 48, 59), Turm (57, 83, 103). Turm: 1 247 Lampen-Ecken, 1 512 Glas-Ecken.
- Bei Tag im Bild (Block B aus 7 m): Lampen-Scheiben (53, 45, 39) … (69, 62, 50), Glas (39, 52, 63) – gleich dunkel,
  entgegengesetzter Farbton (M3).
- Nachts im Rennen (Paris–Tours km 131,3, Haus 70 m voraus): Arcade-Fenster bis Leuchtdichte 225, Modern bis 165 (M6).

### 6.6 Prüfer, Budgets, Zeichenaufrufe, Bytes (auf der Kopie)
`validate_models.py --report`: **CHECK models OK**, 41 Modelle, 182 Sets (53 mit Modell); Netze 4,94 MB von 40 MB,
Texturen 26,85 MB Grafikspeicher von 240 MB, Quellen 14,57 MB von 60 MB – dieselben Zahlen wie bei AS4. Je Modell:
Land 1 054–1 928 Dreiecke (Budget 2 000), Stadt 1 085–5 180 (10 000), Laterne 882 und Portal 1 100 (1 500), Pylon 520
(5 000); Aufrufe 2/2 bzw. 1. AS4-Anteil: Netze 0,49 MB, Texturquellen 5,07 MB (AS4, Summen der Tabelle bestätigt).
Bake-Zeiten (AS4 gemessen, nicht wiederholt – Export ist schwer): 46–144 s je Gebäude, Godot-Bake ≤ 0,05 s.
Umschaltentfernungen: lod0 bis 40 / 60 / 120 m (niedrig / mittel / hoch, `prop_lod0_m`), danach lod1 ohne Fernbild.
Sprite-Geometrie, `--check-keys`, Determinismus, `run_tests.sh` und `golden.sh` habe ich nicht wiederholt (nur lesende
Rolle, keine Änderung; AS4 meldet alle grün auf `9eef9a8`).
