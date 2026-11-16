# AS3 – Vegetation und Natur (Bericht)

- Branch `worktree-wf_aad8d49e-fb4-1`, Sicherung `origin/wip/v080-as3` (nach jedem Commit gepusht), Basis 8f58b2d
  (ff-merge), Endstand **be866d2**.
- **gemessen** = ein Befehl hat die Zahl ausgegeben (Werkzeug genannt); **abgeleitet** = aus dem Aufbau des Codes;
  **angesehen** = Urteil nach Bildern. Jede Angabe ist so markiert.

## 1. Kurzfassung

- **18 Bäume**: sieben neue Arten mit je zwei Saat-Varianten (Buche, Pappel, Olive, Kiefer, Fichte, Zypresse,
  Palme; Katalog `variant_of`) und Eiche/Birke (je 2) über den gemeinsamen Bauer neu. **Heide, Felsen a/b,
  Klippe** neu; Büsche (`bush_round`/`_b`, `bush_low`, `cover_bush`) und Bodengras über den gemeinsamen Bauer
  überarbeitet. 27 Modelle, alle im Budget (Abschnitt 3).
- Neue Kronen-Methode **„Laubkuppeln“** statt flacher Tangentialkarten (die AS1b-Mängel: Tupfen, dunkle Löcher,
  Kantenstreifen von der Seite). Fichte, Zypresse und Palme haben eigene Kronen (`veg3d_shapes.py`).
- Gates auf dem Endstand (Abschnitt 5): Prüfer, Budget, Sprite-Geometrie 86/86, Cache-Schlüssel, Determinismus,
  Rennen an vier Stellen und Arcade-Bilder 20/20 grün; `run_tests.sh` rot: zwei Tests des Props-Bauers nehmen die
  Buche als Set ohne Modell (geprüfter Vorschlag für R2 liegt bei), ein Klang-Test scheitert nur unter Last. Runden bauen → rendern → ansehen → beheben: d4f0d83 (Kuppeln
  statt Karten), f67ade1 (sieben Arten), accba59 (Farbabgleich, Heide/Felsen/Klippe), 8c48f77 (Bodengras),
  791853f (Fichte: Stufenwechsel), dazwischen viele Prüfbilder je Art.
- **Schwächster Punkt:** der Stufenwechsel ist nicht unsichtbar. Helligkeit, Farbton und Umriss bleiben beim
  Wechsel lod0 → lod1 (60 m) fast überall innerhalb ±5 % / ±5° (gemessen), aber 34–76 % der Pixel der Krone
  ändern sich um mehr als ≈ 5 Grauwerte je Kanal: das Blattmuster innerhalb der Krone springt (abgeleitet: lod1 hat
  weniger Ringe je Kuppel und lässt kleine Ballen weg – Textur und Eckhelligkeit liegen anders auf der Kuppel).
  Beim Wechsel zum Fernbild (200 m) sind es 59–99 %. Danach: Fichten-Fernbild mittags 8–11 % dunkler als lod1,
  Palmen-Fernbild im Farbton 16° wärmer.

## 2. Aufbau

### 2.1 Laubkuppeln (Laubbäume, Kiefer, Büsche, Heide) – abgeleitet
- Quelle sind die Kronen-Ballen, die `cesprites/props_nature.py` für das Sprite baut (`CROWN_LOG`; Kiefer jetzt mit
  ihren Polstern, Heide über `SHAPE_LOG`): die Krone liegt dort, wo sie im Sprite liegt (Umriss, 4.2).
- Je Ballen eine gewölbte Karte über seinen freien Teil (48 Richtungen gegen die anderen Ellipsoide abgetastet,
  +14° Rand), Ringe nach Wichtigkeit (freie Fläche × r² × AO) innerhalb des Dreiecksbudgets verfeinert; Rand
  ausgefranst (Atlas „Laubball“ mit gezacktem Rand), Ecken leicht verwackelt. Jeder Ballen hat einen eigenen
  Zufallsstrom: Zelle, Drehung und Windphase sind in lod0 und lod1 gleich.
- Helligkeit je Ecke (COLOR.a) = Verdeckung gegen die anderen Ballen × Himmelsanteil (Unterseiten bis 0.6): die
  Krone ist auf der Sonnenseite hell, innen und unten dunkler. Ein dunkler Kern (Hülle 0.8) schließt die Lücken.
- Schattenwerfer: Kronenhülle + Stamm (nur Schatten, 128–282 Dreiecke).

### 2.2 Sonderkronen (`tools/blender/ce3d/veg3d_shapes.py`, neu) – abgeleitet
- **Fichte**: die Etagen des Sprite-Generators (`SHAPE_LOG["tiers"]`); je Etage innere Kegel (Nadelmasse, Unterseite
  dunkel) und 9 bzw. 6 Astkarten-Sektoren (lod0 zwei Lagen, lod1 eine), Atlas „Zweig“; Spitze aus dem Kern.
- **Zypresse**: Drehkörper aus dem Sprite-Profil (20 × 30 bzw. 10 × 14), Rauschen im Radius, Kernzellen-Textur.
- **Palme**: Stamm mit Ringen alle 0.24 m (Farbbänder, Wulst), Kronenschaft, Nüsse, Wedel als Streifen mit 52
  Fiedern je Seite (8 bzw. 4 Abschnitte); kein Schattenwerfer (Wedel zu dünn).

### 2.3 Wind (COLOR für leaves.gdshader) – abgeleitet
- COLOR.r Ausschlag nach Höhe (0 bis 30 % der Baumhöhe, dann bis 1 an der Spitze), .g Phase je Ballen bzw. Wedel,
  .b Steifigkeit: Laubbäume und Kiefer 0.55, Pappel 0.35, **Palme 0.15 (lebhafter)**, Fichte 0.7, Zypresse 0.75;
  Büsche Ausschlag × 0.45, Heide × 0.25. **Stämme starr** (Klasse `vpbr`, kein Wind), **Fernbild ohne Wind**
  (billboard.gdshader). Ruhe der Krone bis 25 m: im Clip angesehen (4.5).

### 2.4 Normalen für Schnee und Regen – abgeleitet
- Kronen: geglättete Kuppel-Normalen (Ellipsoid, 22 % Kronenrundung, leicht nach oben gekippt) – die Oberseiten der
  Ballen zeigen nach oben, ein Schnee-Shader kann `NORMAL.y` als Auflage nehmen; Fichten-Astkarten: Kegel-Normale
  (oben + außen); Stämme: Zylindernormalen; Felsen/Klippe: geglättete Normalen der dezimierten Form. Geliefert sind
  nur die Normalen – keine Schnee-Maske, keine Nass-Variante (Shader-Sache, R4).

### 2.5 Boden und Hang – gemessen (Manifest `aabb`)
- Stämme reichen 0.55–0.70 m unter 0 (Fuß aufgeweitet × 1.12): Bäume y min −0.55 … −0.70 m; Büsche −0.18 … −0.41,
  Heide −0.17, Felsen −0.26 / −0.51, Klippe −1.19 (Füße 0.9 m versenkt). Bei 0.35 m Stammradius steht ein Baum
  damit auch an einem 1:1-Hang ohne Luft unter dem Fuß (abgeleitet). Bodengras 0.00 (AS1b-Form, nur Dichte/Farbe).

### 2.6 Nichts leuchtet – gemessen
- Klassen aller 27 AS3-Modelle: `leaves`, `vpbr`, `baked`; Texturen `leaves`, `albedo` (+ Fernbild). Keine
  Emission, keine Lampen.

### 2.7 Varianten und Landschaft
- `_b` = andere Saat desselben Generators, für Fichte/Zypresse/Palme zusätzlich Form-Parameter (12 statt 15 Etagen;
  Bauch 1.45, Breite 1.12; Stammbiegung 0.4) – im Umriss deutlich anders (4.2, gemessen) und in den Kontaktbögen.
- Landschaften (Zensus `stage_sets.gd`, gemessen): Heide (Hamburg–Hannover km 46–50): Birke, Kiefer, Heide,
  `bush_low`; Mittelmeer (Barcelona–Montpellier km 41–45): Olive, Zypresse, Palme, `bush_round`; Pyrenäen
  (Saragossa–Pau km 151–155): Kiefer, Felsen; Alpen (Lyon–Bern km 148–152): Fichte, Felsen, Klippe.

## 3. Budget (§4.6.9) – gemessen

`python3 budget_table.py` (scratch; Manifest und Dateien); Budget je Kategorie in der letzten Spalte.

| Modell | Art | Dreiecke lod0 / lod1 | Kuppeln bzw. Karten lod0 / lod1 | Aufrufe lod0 / lod1 / Fernbild | Schatten | Netze B | Texturen B (Quelle) | Budget |
|---|---|---|---|---|---|---|---|---|
| bush_low | plant | 395 / 115 | 25 / 23 | 1 / 1 | – | 12 387 | 445 810 | 400 / 120, 1 |
| bush_round | plant | 396 / 111 | 20 / 20 | 1 / 1 | – | 12 029 | 445 311 | 400 / 120, 1 |
| bush_round_b | plant | 396 / 117 | 19 / 19 | 1 / 1 | – | 12 047 | 445 311 | 400 / 120, 1 |
| cliff | rock | 4341 | – | 1 | – | 89 818 | 886 805 | 6 000 / auto, 1 |
| cover_bush | plant | 236 / 111 | 9 / 9 | 1 / 1 | – | 8 154 | 444 811 | 400 / 120, 1 |
| cover_grass | plant | 84 / 28 | 42 / 14 | 1 / 1 | – | 4 366 | 299 568 | 400 / 120, 1 |
| heather | plant | 390 / 118 | 30 / 30 | 1 / 1 | – | 12 806 | 455 522 | 400 / 120, 1 |
| rock_a | rock | 640 | – | 1 | – | 11 361 | 143 951 | 1 500 / auto, 1 |
| rock_b | rock | 960 | – | 1 | – | 17 391 | 168 180 | 1 500 / auto, 1 |
| tree_beech | tree | 2471 / 888 | 62 / 62 | 2 / 2 / 1 | 186 | 65 841 | 1 985 628 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_beech_b | tree | 2462 / 889 | 62 / 62 | 2 / 2 / 1 | 177 | 65 670 | 1 997 383 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_birch | tree | 2304 / 673 | 33 / 33 | 2 / 2 / 1 | 225 | 55 201 | 2 006 629 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_birch_b | tree | 2400 / 723 | 34 / 34 | 2 / 2 / 1 | 259 | 57 055 | 2 008 565 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_cypress | tree | 1236 / 316 | 0 / 0 | 2 / 2 / 1 | 128 | 40 996 | 1 744 815 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_cypress_b | tree | 1236 / 316 | 0 / 0 | 2 / 2 / 1 | 128 | 40 478 | 1 735 127 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_oak | tree | 2465 / 887 | 67 / 67 | 2 / 2 / 1 | 175 | 66 629 | 1 952 241 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_oak_b | tree | 2475 / 885 | 67 / 67 | 2 / 2 / 1 | 203 | 67 944 | 1 951 209 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_olive | tree | 2295 / 828 | 40 / 40 | 2 / 2 / 1 | 248 | 60 151 | 2 116 376 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_olive_b | tree | 2190 / 791 | 39 / 39 | 2 / 2 / 1 | 227 | 57 511 | 2 113 610 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_palm | tree | 1184 / 714 | 208 / 104 | 2 / 2 / 1 | – | 26 806 | 721 718 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_palm_b | tree | 1184 / 714 | 208 / 104 | 2 / 2 / 1 | – | 26 809 | 721 231 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_pine | tree | 1693 / 592 | 30 / 30 | 2 / 2 / 1 | 192 | 41 726 | 2 152 984 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_pine_b | tree | 1970 / 688 | 36 / 36 | 2 / 2 / 1 | 192 | 48 439 | 2 155 833 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_poplar | tree | 2470 / 888 | 82 / 82 | 2 / 2 / 1 | 136 | 69 481 | 1 956 912 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_poplar_b | tree | 2470 / 886 | 80 / 80 | 2 / 2 / 1 | 136 | 68 427 | 1 958 255 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_spruce | tree | 1062 / 462 | 270 / 90 | 2 / 2 / 1 | 282 | 58 016 | 1 302 739 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_spruce_b | tree | 858 / 378 | 216 / 72 | 2 / 2 / 1 | 234 | 47 278 | 1 296 953 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |

Summe der 27 Modelle: Netze 1.14 MB, Texturquellen 35.61 MB

`validate_models.py --report`: ganzer Satz Netze 5.23 MB von 40 MB, Texturen 37.37 MB im Grafikspeicher von 240 MB,
Quellen 37.10 MB von 60 MB – **davon AS3 35.6 MB**, und 15.8 MB davon sind byte-gleiche Atlanten (jede `_b`-Variante
und `bush_round_b` tragen den Atlas der Grundart noch einmal; Hinweis in Abschnitt 8).

## 4. Messungen

### 4.1 Farbe bei Tag gegen das Arcade-Sprite – gemessen
`tools/models/prop_scene.sh <out> --mode=lods --look=race --hour=12 --sprite --models=…` (Renn-Licht, Voreinstellung
medium): lod0 in 60 m gegen das Sprite in 200 m (das Sprite als Stellvertreter im selben Licht), Mittel aller
Modellpixel. Varianten gegen das Sprite ihrer Grundart. Bei Grau (Felsen, Sättigung < 0.1) sagt der Farbton nichts.

| Modell | lod0 RGB | Sprite RGB | Helligkeit lod0 / Sprite | Farbton-Abstand |
|---|---|---|---|---|
| tree_oak | (57, 82, 47) | (57, 82, 48) | -0.1 % | -1° |
| tree_birch | (89, 111, 64) | (85, 111, 61) | +1.0 % | -3° |
| tree_beech | (61, 87, 46) | (59, 86, 48) | +1.3 % | -5° |
| tree_poplar | (59, 88, 48) | (59, 86, 50) | +1.7 % | -2° |
| tree_olive | (90, 100, 78) | (89, 100, 78) | +0.2 % | -3° |
| tree_pine | (55, 65, 49) | (58, 67, 51) | -3.5 % | +4° |
| tree_spruce | (41, 60, 48) | (42, 59, 48) | +0.9 % | +1° |
| tree_cypress | (50, 65, 53) | (47, 60, 49) | +8.0 % | +3° |
| tree_palm | (76, 90, 63) | (72, 86, 59) | +4.9 % | +0° |
| tree_oak_b | (58, 83, 48) | (57, 82, 48) | +1.2 % | -1° |
| tree_birch_b | (91, 114, 66) | (85, 111, 61) | +3.7 % | -2° |
| tree_beech_b | (65, 92, 49) | (59, 86, 48) | +7.3 % | -5° |
| tree_poplar_b | (60, 89, 49) | (59, 86, 50) | +2.9 % | -2° |
| tree_olive_b | (87, 96, 75) | (89, 100, 78) | -3.6 % | -4° |
| tree_pine_b | (50, 61, 46) | (58, 67, 51) | -9.9 % | +10° |
| tree_spruce_b | (41, 60, 48) | (42, 59, 48) | +0.9 % | +1° |
| tree_cypress_b | (50, 66, 54) | (47, 60, 49) | +9.4 % | +6° |
| tree_palm_b | (74, 89, 63) | (72, 86, 59) | +3.5 % | +4° |
| bush_round | (66, 88, 58) | (62, 88, 54) | +1.4 % | -2° |
| bush_round_b | (63, 85, 56) | (62, 88, 54) | -2.2 % | -0° |
| bush_low | (68, 89, 59) | (65, 90, 55) | +0.3 % | -1° |
| heather | (97, 81, 92) | (96, 78, 96) | +2.5 % | +19° |
| rock_a | (95, 97, 85) | (92, 97, 88) | +0.4 % | -23° |
| rock_b | (104, 102, 94) | (100, 100, 97) | +2.1 % | -12° |
| cliff | (101, 97, 90) | (97, 96, 90) | +1.6 % | -13° |

### 4.2 Umriss gegen das Sprite – gemessen
Fernbild (orthografisch, Blick von der Straße = Blick des Sprites) über dem Sprite-Umriss, 24 px/m, an Anker und
Boden ausgerichtet (scratch `outline.py`; Bild `umrisse_gegen_sprite.png`). Die `_b`-Varianten sollen abweichen.

| Modell | Modell außerhalb des Sprite-Umrisses | Sprite vom Modell gedeckt |
|---|---|---|
| tree_oak | 4.9 % | 98.8 % |
| tree_oak_b | 10.2 % | 83.2 % |
| tree_birch | 8.3 % | 97.1 % |
| tree_birch_b | 21.9 % | 80.5 % |
| tree_beech | 2.7 % | 98.5 % |
| tree_beech_b | 8.7 % | 91.9 % |
| tree_poplar | 8.7 % | 99.1 % |
| tree_poplar_b | 16.7 % | 87.5 % |
| tree_olive | 5.3 % | 97.7 % |
| tree_olive_b | 10.4 % | 86.7 % |
| tree_pine | 11.7 % | 94.6 % |
| tree_pine_b | 24.2 % | 84.6 % |
| tree_spruce | 10.6 % | 91.1 % |
| tree_spruce_b | 10.7 % | 79.4 % |
| tree_cypress | 5.2 % | 97.8 % |
| tree_cypress_b | 2.5 % | 76.4 % |
| tree_palm | 33.3 % | 67.5 % |
| tree_palm_b | 69.3 % | 32.7 % |

### 4.3 Stufenwechsel – gemessen
`prop_scene --mode=lods` bei 12 / 19:30 / 23 Uhr, Wechsel an der Umschaltentfernung von „medium“ (60 / 200 m), an
derselben Stelle: Anteil der Modellpixel, die sich um Σ|ΔRGB| > 0.06 ändern (≈ 5 Grauwerte je Kanal), und der
Sprung von Helligkeit und Farbton der Innenpixel (3×3-Nachbarschaft ganz im Modell). Letzte Spalte: Fernbild gegen
das Arcade-Sprite in 200 m. Büsche und Heide haben kein Fernbild – sie bleiben lod1 (Spalte „lod1→Fernbild“ = 0);
Felsen und Klippe haben eine Stufe mit automatischen Netz-Stufen (immer 0, nicht aufgeführt). Bei Nacht liegt die
Krone bei 10–31 von 255 (gemessen, lod0): ±20 % sind dort 2–6 Grauwerte.

| Modell | Stunde | lod0→lod1: Pixel / Helligkeit / Farbton | lod1→Fernbild: Pixel / Helligkeit / Farbton | Fernbild→Sprite: Helligkeit |
|---|---|---|---|---|
| tree_oak | Mittag | 68 % / +0.1 % / +0° | 77 % / -3.0 % / +3° | +0.0 % |
| tree_oak | Dämmerung | 64 % / +2.8 % / -0° | 68 % / -3.4 % / +2° | -11.3 % |
| tree_oak | Nacht | 37 % / +2.8 % / -1° | 38 % / -1.2 % / +14° | +10.2 % |
| tree_birch | Mittag | 68 % / +1.5 % / +0° | 97 % / +3.7 % / +2° | -8.7 % |
| tree_birch | Dämmerung | 58 % / +3.1 % / -0° | 81 % / +4.4 % / +0° | -21.7 % |
| tree_birch | Nacht | 34 % / +3.3 % / -0° | 59 % / +8.7 % / +19° | -10.1 % |
| tree_beech | Mittag | 59 % / -2.9 % / +0° | 80 % / +3.7 % / +2° | -5.0 % |
| tree_beech | Dämmerung | 52 % / -1.4 % / +0° | 62 % / +2.9 % / +2° | -16.4 % |
| tree_beech | Nacht | 32 % / -1.9 % / -0° | 37 % / +6.4 % / +11° | +2.3 % |
| tree_poplar | Mittag | 76 % / +0.3 % / +0° | 81 % / -2.6 % / +2° | -1.9 % |
| tree_poplar | Dämmerung | 69 % / +3.2 % / +0° | 74 % / -4.4 % / +3° | -13.2 % |
| tree_poplar | Nacht | 38 % / +4.3 % / -1° | 41 % / -1.7 % / +12° | +7.7 % |
| tree_olive | Mittag | 62 % / -3.1 % / -0° | 85 % / +2.2 % / +5° | -0.4 % |
| tree_olive | Dämmerung | 57 % / -2.0 % / -0° | 68 % / +3.8 % / -1° | -13.7 % |
| tree_olive | Nacht | 32 % / -2.4 % / -0° | 44 % / +3.5 % / +15° | +0.9 % |
| tree_pine | Mittag | 43 % / +2.0 % / -2° | 85 % / +1.1 % / -1° | +7.9 % |
| tree_pine | Dämmerung | 32 % / +2.1 % / -2° | 72 % / +1.2 % / +11° | -2.2 % |
| tree_pine | Nacht | 20 % / +2.1 % / -1° | 53 % / +8.3 % / +2° | +27.9 % |
| tree_spruce | Mittag | 61 % / +1.8 % / -0° | 68 % / -8.2 % / -2° | -5.7 % |
| tree_spruce | Dämmerung | 42 % / +4.3 % / +0° | 64 % / +6.1 % / -0° | -12.4 % |
| tree_spruce | Nacht | 27 % / +5.9 % / +0° | 53 % / +25.7 % / +14° | +15.0 % |
| tree_cypress | Mittag | 36 % / -1.9 % / +1° | 59 % / -2.0 % / +8° | +1.1 % |
| tree_cypress | Dämmerung | 20 % / -2.6 % / -0° | 35 % / +3.9 % / -1° | -5.7 % |
| tree_cypress | Nacht | 12 % / -3.4 % / +1° | 34 % / +19.4 % / +10° | +26.0 % |
| tree_palm | Mittag | 34 % / -0.1 % / -1° | 99 % / -4.0 % / -16° | +17.9 % |
| tree_palm | Dämmerung | 30 % / -0.9 % / +1° | 93 % / -0.2 % / +9° | +2.9 % |
| tree_palm | Nacht | 17 % / -0.0 % / +1° | 81 % / +10.0 % / -17° | +26.2 % |
| tree_oak_b | Mittag | 67 % / +4.2 % / -0° | 77 % / -5.4 % / +4° | -1.1 % |
| tree_oak_b | Dämmerung | 60 % / +6.3 % / +0° | 63 % / -5.6 % / +4° | -12.4 % |
| tree_oak_b | Nacht | 34 % / +7.9 % / -1° | 33 % / -3.5 % / +13° | +8.6 % |
| tree_birch_b | Mittag | 66 % / -0.6 % / -0° | 96 % / +3.5 % / +2° | -9.6 % |
| tree_birch_b | Dämmerung | 58 % / +0.1 % / -0° | 87 % / +3.5 % / +2° | -22.5 % |
| tree_birch_b | Nacht | 35 % / +0.4 % / -0° | 63 % / +7.9 % / +18° | -11.2 % |
| tree_beech_b | Mittag | 59 % / -1.6 % / +0° | 79 % / +2.0 % / +2° | -8.8 % |
| tree_beech_b | Dämmerung | 51 % / -0.6 % / -0° | 63 % / +3.4 % / +1° | -20.0 % |
| tree_beech_b | Nacht | 29 % / -0.9 % / +0° | 35 % / +6.4 % / +10° | -3.3 % |
| tree_poplar_b | Mittag | 74 % / +3.6 % / +0° | 82 % / -5.2 % / +4° | -2.3 % |
| tree_poplar_b | Dämmerung | 66 % / +4.8 % / +0° | 74 % / -5.1 % / +4° | -13.6 % |
| tree_poplar_b | Nacht | 36 % / +7.0 % / -1° | 39 % / -3.7 % / +14° | +7.0 % |
| tree_olive_b | Mittag | 62 % / -1.8 % / +0° | 85 % / +1.1 % / +2° | +3.4 % |
| tree_olive_b | Dämmerung | 57 % / -0.7 % / -0° | 63 % / +0.1 % / -0° | -10.2 % |
| tree_olive_b | Nacht | 33 % / -1.1 % / +0° | 44 % / +1.4 % / +13° | +6.1 % |
| tree_pine_b | Mittag | 44 % / +0.9 % / -1° | 86 % / +1.0 % / -3° | +11.7 % |
| tree_pine_b | Dämmerung | 34 % / +1.2 % / -1° | 68 % / +0.4 % / +15° | +1.8 % |
| tree_pine_b | Nacht | 21 % / +1.0 % / +0° | 50 % / +10.2 % / -1° | +34.2 % |
| tree_spruce_b | Mittag | 63 % / +3.1 % / -1° | 71 % / -10.8 % / -0° | -4.2 % |
| tree_spruce_b | Dämmerung | 46 % / +5.8 % / -0° | 64 % / +2.0 % / +4° | -10.8 % |
| tree_spruce_b | Nacht | 29 % / +8.1 % / -0° | 49 % / +20.5 % / +15° | +18.2 % |
| tree_cypress_b | Mittag | 36 % / -1.8 % / +1° | 63 % / -2.6 % / +9° | +1.5 % |
| tree_cypress_b | Dämmerung | 21 % / -2.7 % / -0° | 39 % / +3.3 % / -4° | -5.2 % |
| tree_cypress_b | Nacht | 12 % / -3.7 % / +1° | 43 % / +18.5 % / +10° | +27.0 % |
| tree_palm_b | Mittag | 34 % / +0.5 % / +2° | 98 % / +1.3 % / -7° | +16.9 % |
| tree_palm_b | Dämmerung | 30 % / -0.8 % / +2° | 97 % / +7.7 % / +14° | +1.9 % |
| tree_palm_b | Nacht | 18 % / -0.8 % / +2° | 71 % / +14.7 % / +0° | +24.9 % |
| bush_round | Mittag | 70 % / +0.1 % / +1° | 0 % / +0.0 % / +0° | -4.0 % |
| bush_round | Dämmerung | 59 % / +4.6 % / +1° | 0 % / +0.0 % / +0° | -13.7 % |
| bush_round | Nacht | 40 % / +6.8 % / -3° | 0 % / +0.0 % / +0° | +9.8 % |
| bush_round_b | Mittag | 67 % / -0.7 % / +1° | 0 % / +0.0 % / +0° | +1.5 % |
| bush_round_b | Dämmerung | 55 % / +4.4 % / -1° | 0 % / +0.0 % / +0° | -15.3 % |
| bush_round_b | Nacht | 36 % / +8.6 % / -2° | 0 % / +0.0 % / +0° | +5.3 % |
| bush_low | Mittag | 64 % / +1.9 % / -1° | 0 % / +0.0 % / +0° | +3.9 % |
| bush_low | Dämmerung | 49 % / +6.7 % / -1° | 0 % / +0.0 % / +0° | -8.5 % |
| bush_low | Nacht | 37 % / +11.3 % / -4° | 0 % / +0.0 % / +0° | +9.2 % |
| heather | Mittag | 78 % / -1.2 % / -7° | 0 % / +0.0 % / +0° | -0.9 % |
| heather | Dämmerung | 65 % / -1.6 % / -3° | 0 % / +0.0 % / +0° | -8.7 % |
| heather | Nacht | 50 % / -0.4 % / -0° | 0 % / +0.0 % / +0° | +3.6 % |

Zusammengefasst (gemessen): lod0 → lod1 Helligkeit innerhalb ±5 % bei allen Bäumen mittags und abends außer
`oak_b` (+6.3 %) und `spruce_b` (+5.8 %) abends; Pixelzahl −2 … −7 %. lod1 → Fernbild innerhalb ±5 % bei Tag und
Dämmerung außer Fichte (−8.2 % / −10.8 % mittags, +6.1 % abends), `oak_b`/`poplar_b` (−5.1 … −5.6 %), `palm_b`
(+7.7 % abends); Farbton ≤ 5° außer Palme (−16° / −7° mittags, +9° / +14° abends), Zypresse (+8° / +9° mittags) und
Kiefer (+11° / +15° abends).

### 4.4 Alpha-Test-Überzeichnung in 20 m – gemessen
Summe der Bildfläche aller Laub-Dreiecke von lod0 für die Spielkamera (jedes Dreieck einmal, Modell 9 m neben der
Straße, 20 m voraus; scratch `overdraw.gd --dist=20`) geteilt durch die vom Modell gedeckten Pixel im Bild
(`prop_scene --mode=lods --d0=20`) = mittlere Zahl der Laub-Fragmente (mit Alpha-Test) je gedecktem Pixel.

| Modell | Kuppeln/Karten lod0 | Laub-Dreiecke lod0 | Laubfläche (px, Summe) | gedeckte Pixel | Überzeichnung |
|---|---|---|---|---|---|
| tree_oak | 67 | 2060 | 644 178 | 120 755 | 5.3× |
| tree_birch | 33 | 1584 | 123 626 | 40 024 | 3.1× |
| tree_beech | 62 | 2084 | 633 160 | 94 596 | 6.7× |
| tree_poplar | 82 | 2228 | 463 627 | 48 021 | 9.7× |
| tree_olive | 40 | 1940 | 182 153 | 38 138 | 4.8× |
| tree_pine | 30 | 1440 | 130 783 | 18 440 | 7.1× |
| tree_spruce | 270 | 1026 | 579 787 | 66 867 | 8.7× |
| tree_cypress | 0 | 1200 | 43 829 | 23 310 | 1.9× |
| tree_palm | 208 | 416 | 28 184 | 18 450 | 1.5× |
| tree_oak_b | 67 | 2132 | 669 866 | 115 864 | 5.8× |
| tree_birch_b | 34 | 1632 | 128 676 | 38 774 | 3.3× |
| tree_beech_b | 62 | 2084 | 635 219 | 98 207 | 6.5× |
| tree_poplar_b | 80 | 2204 | 425 781 | 46 431 | 9.2× |
| tree_olive_b | 39 | 1892 | 180 658 | 35 868 | 5.0× |
| tree_pine_b | 36 | 1728 | 155 566 | 18 324 | 8.5× |
| tree_spruce_b | 216 | 822 | 455 347 | 61 907 | 7.4× |
| tree_cypress_b | 0 | 1200 | 33 153 | 17 952 | 1.8× |
| tree_palm_b | 208 | 416 | 27 903 | 18 049 | 1.5× |
| bush_round | 20 | 396 | 45 150 | 10 466 | 4.3× |
| bush_round_b | 19 | 396 | 48 786 | 9 979 | 4.9× |
| bush_low | 25 | 395 | 38 887 | 10 531 | 3.7× |
| cover_bush | 9 | 236 | 3 796 | 888 | 4.3× |
| heather | 30 | 390 | 16 985 | 5 055 | 3.4× |

### 4.5 Flimmern bei 120 km/h – angesehen
`prop_scene --mode=clip --look=race --hour=12` (2 s, 60 Bilder/s, Baumreihen beidseits alle 30 m, Eiche, Birke,
Buche, Pappel, Fichte, Kiefer; Film `clip_baumreihe_120kmh.mp4`, vier Folgebilder `clip_folgebilder.png`):
Bild für Bild kein Glitzern und kein Kriechen der Blattränder in 40–300 m, die Kronen bewegen sich ruhig. Aus der
Nähe (< 20 m, von unten) sieht man die unteren Kuppelränder als ausgefranste „Schirmkante“.

### 4.6 Nebel – angesehen
Fernbild gegen das Arcade-Sprite als Modern-Stellvertreter in 300 / 500 / 700 / 850 m (`--mode=dist --sprite`,
Bild `fernbild_im_nebel_gegen_sprite.png`): beide verblassen gleich in den Nebel, das Fernbild wird nicht blass.

### 4.7 Rennen Arcade | Modern – gemessen
Positionen aus dem Zensus (`stage_sets.gd`, Sets der Strecke in den nächsten 4 km), je Lauf
`GFX_ARGS="--gfx-preset=<p>" tools/ab_shot.sh <out> --stage=… --from=… --start-km=… --hour=… --weather=normal
--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120
--shot-times=2` (Arcade und Modern, Bild bei 2 s). „Fehler“ = Zeilen mit `ERROR`/`SCRIPT ERROR` im Log.

| Stelle | Start | AS3-Sets dort (Zensus) | Läufe | Ergebnis |
|---|---|---|---|---|
| Heide | Hamburg–Hannover ab Hamburg km 47 | Heide 32, Birke 11, Kiefer 11, `bush_low` 11 | hoch 12 Uhr (Endstand); hoch 19:30, mittel 12 Uhr (8c48f77) | exit 0, 0 Fehler |
| Mittelmeer | Barcelona–Montpellier ab Barcelona km 42 | Olive 13, `bush_round` 9, Zypresse 8, Palme 3 | hoch 12 Uhr (Endstand); hoch 12, mittel 19:30 (8c48f77) | exit 0, 0 Fehler |
| Pyrenäen | Saragossa–Pau ab Saragossa km 152 (und km 149.5) | Kiefer 19, `rock_a` 7, `rock_b` 2 (Klippe km 150.4) | hoch 12 Uhr (Endstand); hoch 12, mittel 19:30, Klippe hoch 12 (8c48f77) | exit 0, 0 Fehler |
| Alpen | Lyon–Bern ab Lyon km 148 | Fichte 34, `rock_a` 2, Klippe 2 | hoch 12 Uhr, mittel 19:30 (Endstand) | exit 0, 0 Fehler |

„Endstand“-Läufe auf 6222b66 (danach nur noch `tools/models/contact_sheet.gd` geändert, kein Spielcode); die Läufe
auf 8c48f77 zeigen dieselben Modell-Bytes (seither nur Fichte geändert, die an diesen drei Stellen nicht steht).
Angesehen: Modern zeichnet die AS3-Modelle dort, wo Arcade die Sprites zeigt – gleiche Art, ähnliche Größe und
Farbe, bei Tag und in der Dämmerung. Unterschied: in Kurven lässt der Props-Bauer dekorative Szenerie im
Sichtkorridor weg (F7) – die nahen Fichten rechts bei Lyon–Bern km 148.9–149.2 werden Bodendecker (35 von 102
Fichten km 147–163 im Korridor, gemessen mit `drops.gd`), die Felsen bei Saragossa–Pau km 152.4–152.8 und die
Klippe km 150.4 fehlen ganz (Bild `ab_pyrenaeen_klippe_fehlt_in_modern.jpg`; Abschnitt 8, Punkt 1).

## 5. Gates auf dem Endstand be866d2

Alle Läufe mit `nice -n 19`, ein Prozess, `XDG_DATA_HOME` absolut im Scratch.

| Gate | Befehl | Ausgabe | Ergebnis |
|---|---|---|---|
| Prüfer | `python3 tools/blender/validate_models.py --report` | `validate_models: 46 Modelle, 182 Sets (51 mit Modell, 131 Platzhalter)` · `Netze 5.23 MB von 40 MB, Texturen 37.37 MB im Grafikspeicher von 240 MB, Quellen 37.10 MB von 60 MB` · `CHECK models OK`, exit 0 | grün |
| Budget | Tabelle Abschnitt 3 | alle 27 AS3-Modelle im Budget (Bäume ≤ 2 475 / 889 Dreiecke, ≤ 270 Karten; Büsche/Heide ≤ 396 / 118; Felsen 640 / 960; Klippe 4 341) | grün |
| Sprite-Geometrie | `/home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1` | `86 Sprite-Sets gebaut in 279 s: 86 identisch (davon 0 mit anderer Flächenreihenfolge), 0 nur Fließkomma-Rauschen, 0 verändert, 0 fehlen` · `CHECK sprite_geometry OK` · 0 × „ANDERS“ (auch direkt nach der letzten cesprites-Änderung f67ade1: 86/86, 273 s) | grün |
| Cache-Schlüssel | `… export_models.py --check-keys` | `CHECK cache_keys OK 46 Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung im Sprite-Katalog ergibt für genau die betroffenen Modelle einen neuen Schlüssel` | grün |
| Determinismus | erzwungener zweiter Export aller 27 AS3-Modelle: `export_models.py --only=<glob> --force --jobs=1` für `props/tree_*`, `props/bush_*`, `props/cover_*`, `props/heather`, `props/rock_*`, `props/cliff` (381 s), `bake_models.gd --only=<glob>` (12 s, 0 Fehler), `godot --import`, `--manifest-only`, dann `git status --porcelain` | leer – alle Dateien byte-gleich zu 791853f (seither keine Modell- oder Pipeline-Änderung) | grün |
| Rennen Modern | `tools/ab_shot.sh` an vier Zensus-Stellen (4.7) | alle exit 0, 0 Zeilen `ERROR`/`SCRIPT ERROR` in Arcade- und Modern-Log | grün |
| Tests (einmal) | `tools/run_tests.sh` | `298 Skripte geprüft, 0 fehlerhaft` … `692 Tests, 3 fehlgeschlagen` · `Tests FEHLGESCHLAGEN (300 s)` | **rot** – siehe unten |
| Arcade-Bilder (einmal) | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (229 s)` | grün |

**Die drei roten Tests:**
1. `tests/unit/race3d/test_props.gd :: test_library_resolves_every_prop_set` („Buche: noch eine Vertretung: erwartet
   2, ist 1“) und `:: test_placement_drops_and_lamps` (`SCRIPT ERROR: Invalid access to property or key
   's|props/tree_beech|1'`): der Test des Props-Bauers (R2) nimmt die Buche als Beispiel eines Sets **ohne** Modell
   – AS3 liefert genau dieses Modell. Die Datei gehört nicht zu AS3, ich habe sie nicht geändert. Geprüfter
   Vorschlag für R2: `vorschlag_test_props_fuer_R2.diff` (die Kirche statt der Buche als Vertretung; lokal
   angewendet: `tools/run_tests.sh test_props` → `7 Tests, 0 fehlgeschlagen`, danach zurückgesetzt).
2. `tests/unit/audio_modern/test_modern_checks.gd :: test_profiles_in_a_running_game_with_playback`
   (`CHECK race FEHLER`, Klang, läuft mit `--graphics=arcade` – lädt keine Modelle): hängt an der Last der Maschine.
   Einzeln gestartet (`godot --headless … -s res://tests/unit/audio_modern/check_modern_audio.gd -- --graphics=arcade
   --live`) meldet derselbe Check `CHECK race OK … Sitzung in 211 von 212 Bildern da`; im Testlauf unter Last 101
   von 113 bzw. 102 von 106 Bildern. Nicht von AS3 verursacht (kein AS3-Code im Arcade-Lauf).

## 6. Geänderte gemeinsame Dateien (rückwärtsverträglich, additiv)

| Datei | Änderung |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | ein Block `# --- AS3 ---`: Baum-Einträge (`_as3_tree`, `variant_of`), Heide, Felsen, Klippe, `BUILDER_CODE["rock"]`, Bodengras-Dichte |
| `tools/blender/export_models.py` | +3 Zeilen: Bauer `rock` (`ce3d.rock3d.build_rock`), Kosten 60 s |
| `tools/models/prop_scene.gd`, `prop_scene.sh` | neue Optionen `--look=race`, `--sprite`, `--mode=clip`, `--d0/--d1`, Messzeilen STUFEN/UMSCHALT; `--mode=lods` zeigt je Spalte die Darstellung des Props-Bauers (vorher leere Kacheln bei Büschen/Felsen) |
| `tools/models/contact_sheet.gd` | Modelle ohne eigenes Set (Saat-Varianten) bekommen im Prozess ein Set ihrer Id (Manifest-Datei unberührt) – vorher blieben ihre Kacheln leer; für Modelle mit Set unverändert |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) |
| `docs/modelle.md` | Abschnitt 15 angehängt (und nachgezogen: Fichten-Fernbild, `--mode=lods`-Spalten) |
| neu: `tools/blender/ce3d/veg3d_shapes.py`, `tools/blender/ce3d/rock3d.py` | nur von den AS3-Bauern benutzt |

Eigene Dateien: `veg3d.py`, `leafatlas.py` (`halo/bleed/coverage/png_bytes` unverändert – Strommast nutzt sie),
`cesprites/props_nature.py` (nur Hooks: `SHAPE_LOG`, `CROWN_LOG` der Kiefer, Knoten-Tag `crown`, Form-Parameter mit
dem Sprite-Wert als Standard – kein Sprite-Eckpunkt bewegt, 86/86 identisch), `assets/models/props/{tree_*, bush_*,
cover_*, heather, rock_*, cliff}`. Nicht angefasst: Renderer (`scripts/race3d/**`, `assets/shaders/modern/**`),
Fahrzeuge, AS4-Dateien, Gebäude, Wahrzeichen, eingefrorene Arcade-Dateien und Sprites.

## 7. Ehrliche Einschätzung

**Gut**
- Die Arten lesen sich wie ihr Sprite: Kronenhelligkeit bei Tag innerhalb ±5 % bei 8 von 9 Grundarten (Zypresse
  +8 %), Farbton innerhalb 5° (gemessen, 4.1); Umriss 2.7–11.7 % außerhalb des Sprite-Umrisses bei 8 von 9
  Grundarten (gemessen, 4.2). Birke weißstämmig, Kiefer orange oben/dunkel unten mit flachen Polstern, Olive
  graugrün und knorrig, Zypresse als Flamme, Pappel als Säule (angesehen, Kontaktbögen und A/B).
- Volumen ohne Aufkleber: Sonnenseite hell, innen und unten dunkler, von der Seite keine Kartenstreifen
  (angesehen). Kein Glitzern bei 120 km/h (angesehen, 4.5); im Nebel wie das Sprite (angesehen, 4.6).
- Rennen: an allen A/B-Stellen ohne Skriptfehler; die Bäume stehen, wo Arcade seine Sprites zeigt (gemessen/angesehen).
- Budgets eingehalten, Export deterministisch, Prüfer grün (gemessen).

**Noch nicht gut**
- Stufenwechsel (schwächster Punkt, oben): Muster springt, 34–76 % geänderte Pixel bei lod0 → lod1, 59–99 % bei
  lod1 → Fernbild (gemessen).
- Fichte: Fernbild mittags 8–11 % dunkler als lod1, abends 2–6 % heller – die Astkarten zeigen nach oben und
  bekommen im Spiel mittags mehr Sonne als das Billboard; eine feste Verstärkung kann nur mitteln (gemessen).
- Palme: Fernbild-Farbton 16° wärmer als lod1 (Stamm im Fernbild heller/brauner – im Nebel bleibt er deshalb in
  500 m sichtbar, wo der dunkle Sprite-Stamm schon verschwindet), die dünnen Wedel werden im 256-px-Fernbild
  kürzer; Umriss 33 % außerhalb des Sprites (gemessen/angesehen). Ein Versuch mit eigener Stamm-Verstärkung im
  Fernbild (0.85) machte den Stamm dunkel, aber die Innenpixel 20 % dunkler als lod1 – verworfen.
- Nacht: Fernbild bis +26 % (Fichte), +19 % (Zypresse) gegen lod1 – bei 10–14 von 255 Helligkeit 2–3 Grauwerte;
  nachts ist das Arcade-Sprite im selben Licht 25–34 % heller als das Fernbild von Kiefer, Zypresse und Palme, bei
  der Birke 10 % dunkler (gemessen; 2–4 Grauwerte).
- Dämmerung: das Fernbild passt zu lod1, aber das Arcade-Sprite ist am selben Ort 10–23 % dunkler (Eiche, Birke,
  Buche, Pappel, Olive, Fichte) – Modern-Bäume wirken abends etwas heller als in Arcade (gemessen).
- Aus der Nähe (< 20 m): die Kuppelkronen sind ruhig, aber eher „Blumenkohl“ als lockeres Laub, von unten sieht man
  die Kuppelränder; Heide aus < 10 m wie Kissen mit fleckiger Blütentextur (angesehen).
- Überzeichnung: Pappel 9.2–9.7×, Fichte 7.4–8.7×, Kiefer 7.1–8.5× Laub-Fragmente je gedecktem Pixel in 20 m
  (gemessen) – auf schwacher Hardware teuer, wenn viele Bäume nah stehen.

**Fehlt**
- Schnee-/Nass-Darstellung (nur Normalen geliefert; R4).
- Ein gemeinsamer Atlas für beide Varianten einer Art (15.8 MB doppelt, Abschnitt 3).
- Eigene Stufen/Fernbilder für Felsen und Klippe (nur automatische Netz-Stufen, Budget „auto“).
- Klippen und Felsen in Kurven-Sichtkorridoren zeichnet Modern nicht (Props-Bauer, F7; 4.7) – nicht in meinem Paket.

## 8. Hinweise für R2 / R4 / R7 und Folgepakete

1. **Props-Bauer (R2/R7), Sichtkorridor F7:** Felsen und Klippen in Kurven-Sichtkorridoren fallen in Modern weg,
   Arcade zeigt sie, und anders als Pflanzen bekommen sie keinen Ersatz. Gezählt mit dem Bauer selbst (scratch
   `drops.gd`, gemessen): Saragossa–Pau km 75–185 zeichnet 16 von 22 Klippen (6 „corridor“), km 150–166 fallen
   11 von 15 `rock_a` und 3 von 10 `rock_b` weg. Vorschlag: Felsen bis 0.5 m als Bodendecker behalten (wie
   `bend_cover`), Klippen an den Korridorrand schieben statt weglassen.
2. **Fernbild-Licht (R4/Renderer):** `billboard.gdshader` reagiert anders auf die Tageszeit als `leaves.gdshader` auf
   die Kuppeln: Fichte −8 % mittags / +6 % abends mit derselben Verstärkung, Dämmerung 10–23 % heller als das
   Arcade-Sprite (gemessen). Ein Fernbild mit zwei Lichtanteilen (Oberseiten/Seiten) oder eine Verstärkung je
   Tageszeit würde das beheben – nicht in AS3 (Shader gehört dem Renderer).
3. **Pipeline – Atlas je Art teilen:** jede Saat-Variante speichert den byte-gleichen Laubatlas der Grundart noch
   einmal (15.8 MB der 35.6 MB AS3-Texturquellen; ganzer Satz 37.1 von 60 MB im Archiv). Ein Verweis im
   `model.json` auf den Atlas der Grundart (Bake + ModelDB) spart das und einen Grafikspeicher-Atlas je Art, wenn
   beide Varianten im Bild sind.
4. **Stufenwechsel:** lod1 hat weniger Ringe je Kuppel – das Blattmuster springt. Besser wäre lod1 als dieselben
   Kuppeln mit gröberer Teilung, aber gleicher UV-Abbildung je Ring (Textur bleibt stehen); oder ein kurzes
   Überblenden (Dither) beim Wechsel im Renderer.
5. **Palme:** das 256-px-Fernbild verliert die dünnen Fiedern – 512 px für hohe, schmale Bäume oder dickere
   Wedel nur im Fernbild.
6. **Kontaktbogen/Prüfszene:** `contact_sheet.gd` und `prop_scene.gd` legen für Varianten ohne Set ein Set im
   Prozess an (Manifest unberührt); `prop_scene --mode=lods` zeigt jetzt die Stufen des Props-Bauers.
7. **Test des Props-Bauers (R2):** `tests/unit/race3d/test_props.gd` nimmt `props/tree_beech` als Set ohne
   Modell; mit AS3 hat die Buche eines – zwei Tests rot. Geprüfter Vorschlag `vorschlag_test_props_fuer_R2.diff`
   (Kirche statt Buche). Da AS4 Gebäude baut, ist auch die Kirche nur eine Zwischenlösung: besser wäre ein Set,
   dem der Test selbst das Modell nimmt.
8. **Kleinigkeiten:** `cover_bush` lod1 hat von vorn einen schmalen Spalt (bei 0.45 m Höhe ab 60 m nur 1–2 px);
   Bodengras steht auf 0.00 (am Hang kann die Talseite 5–10 cm schweben – AS1b-Form, nur Farbe/Dichte geändert).

## 9. Bilder in diesem Ordner

| Datei | Inhalt |
|---|---|
| `stufen_baeume_{mittag,daemmerung,nacht}.png` | Spielkamera, Renn-Licht (medium): je Grundart lod0 und lod1 in 60 m, lod1 und Fernbild in 200 m, Arcade-Sprite in 200 m (Messung 4.1/4.3) |
| `stufen_varianten_b_{mittag,daemmerung,nacht}.png` | dasselbe für die neun `_b`-Varianten (Sprite = das der Grundart) |
| `stufen_buesche_heide_felsen_{mittag,daemmerung,nacht}.png` | Büsche, Bodendecker, Heide, Felsen, Klippe – je Spalte die Stufe des Props-Bauers |
| `stufen_in_20m_ueberzeichnung.png` | lod0 in 20 m (gedeckte Pixel für 4.4) |
| `kontaktbogen_baeume_{tag,nacht}.png` | alle 18 Bäume, jede Stufe von der Anfahrt und von hinten, dazu das Fernbild (Prüf-Rig des Kontaktbogens – Fernbild-Kacheln dort heller als im Renn-Licht) |
| `kontaktbogen_buesche_heide_felsen_klippe_{tag,nacht}.png` | Büsche, Bodendecker, Heide, Felsen, Klippe, jede Stufe |
| `umrisse_gegen_sprite.png` | Fernbild-Umriss (grün) über dem Sprite-Umriss (rot), je Art und Variante (4.2) |
| `fernbild_im_nebel_gegen_sprite.png` | Fernbild und Arcade-Sprite in 300/500/700/850 m im Renn-Nebel (4.6) |
| `clip_baumreihe_120kmh.mp4`, `clip_folgebilder.png` | 2 s bei 120 km/h, 60 Bilder/s; vier Folgebilder aus der Mitte (4.5) |
| `ab_{alpen,heide,mittelmeer,pyrenaeen}_hoch_mittag.jpg` | Arcade \| Modern, Voreinstellung hoch, 12 Uhr (Endstand) |
| `ab_alpen_mittel_daemmerung.jpg` | Alpen, mittel, 19:30 (Endstand) |
| `ab_heide_hoch_daemmerung.jpg`, `ab_heide_mittel_mittag.jpg`, `ab_mittelmeer_mittel_daemmerung.jpg`, `ab_pyrenaeen_mittel_daemmerung.jpg` | weitere A/B auf 8c48f77 (gleiche Modell-Bytes an diesen Stellen) |
| `ab_pyrenaeen_klippe_fehlt_in_modern.jpg` | Saragossa–Pau km 149.5: Arcade zeigt die Klippe km 150.4 links, Modern lässt sie im Kurvenkorridor weg (Abschnitt 8.1) |
| `vorschlag_test_props_fuer_R2.diff` | geprüfter Vorschlag für den Test des Props-Bauers (Abschnitt 5, 8.7) |
