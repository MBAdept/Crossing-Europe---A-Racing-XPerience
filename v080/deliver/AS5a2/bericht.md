# AS5a2 – Stadthäuser Teil 1, Charge 2: dutch, belgian, french, paris, swiss

Zweig `worktree-wf_db8ba6cd-508-4` (gesichert als `origin/wip/v080-as5a2`), Basis 7153381 (AS5aR1), Endstand
**3c5e37a**. Messgrundlage: **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, Spiel-Shader,
Renn-Licht); **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte Grafikkarte, Steam Deck,
Wirkung auf einen Menschen) oder abgeleitet.

## 1. Ergebnis in Kürze

Alle zwölf Sets der Charge 2 (`city_dutch_canal`, `city_dutch_canal_b`, `city_dutch_terrace`, `city_belgian_terrace`,
`city_belgian_stone`, `city_french_maison`, `city_french_sud`, `city_french_immeuble`, `city_paris_haussmann`,
`city_paris_corner`, `city_swiss_chalet`, `city_swiss_laube`) haben echte Echtzeit-Modelle aus dem Bauer `city`,
gebaut aus denselben Generatoren wie die Sprites. Front, Umriss, Dach und Farben sind das Sprite (IoU 0,945–0,999);
dazu echte Tiefe (Laibungen, Rahmen, Sprossen, Läden mit Auslage, Fensterläden, Haussmann-Balkone, Fenstergitter,
Arkaden) und Straßenflanken mit Fenstern und Türen statt blinder Flächen (Hooks `close3d`, Sprites unverändert:
86 von 86 identisch). Nachts leuchten dieselben Fenster wie im Sprite. Budgets eingehalten: höchstens 6 518 Dreiecke
in lod0, zwei Zeichenaufrufe je Stufe, Archiv 0,93 MB Netze / 5,79 MB Texturen (Grenze 3 / 7 MB), Erdgeschoss
≥ 40 px/m bis auf die Lauben beim größten Maßstab (39,8).

Im Rennen (A/B an fünf Ankünften, 13 Läufe, alle ohne Fehler) ist Modern dort, wo Arcade eine flache Hausflanke zeigt,
deutlich feiner. **Schwächster Punkt:** Die Schaufenster sind nachts dunkler als in Arcade (Ladenpixel 124 gegen 207,
gemessen) – gemeinsame Formel mit Charge 1, nicht behoben, weil ein Fix alle 23 Stadthäuser neu exportiert
(Abschnitt 8). Weitere Mängel: blanke Rückseiten des Eckhauses, lod1 bei 250 m heller als das Sprite, Modelle
flimmern 2–5-mal so stark wie die Sprites.

Neu im Bauer (rückwärtskompatibel, Charge 1 + Brücken + Hausboot byte-gleich): Geländer als Modul (`rail_module`),
`weights.solid`, `openings.cover_skip`, `openings.chamfer`, `smooth`.

## 2. Was gebaut wurde

Zwölf Sets, Reihenfolge nach Häufigkeit im ganzen Netz (Zählung `census_all.gd` von AS5a1/AS4R: alle Requisiten aller
Etappen, mit Wiederholungen):

| Set | Platzierungen | Städte (Ankünfte) | Zone |
|---|---|---|---|
| `city_french_sud` | 588 | Toulouse, Montpellier, Lyon, Bordeaux, Pau, Bern-Abfahrt … (Mischstil french_south) | Vorort |
| `city_belgian_terrace` | 315 | Brüssel, Lüttich, Calais, Amsterdam-Abfahrt | Innenstadt |
| `city_french_maison` | 209 | Paris, Tours, Pau, Lüttich-Abfahrt | Vorort |
| `city_french_immeuble` | 202 | Toulouse, Lyon, Montpellier, Bordeaux, Paris … | Innenstadt |
| `city_dutch_terrace` | 130 (50 getönt `#ead6cc`) | Amsterdam, Dortmund (ruhr) | Vorort |
| `city_belgian_stone` | 96 | Brüssel, Lüttich, Calais | Innenstadt |
| `city_paris_haussmann` | 55 | Paris | Innenstadt |
| `city_swiss_chalet` | 54 | Bern | Vorort |
| `city_dutch_canal` | 51 | Amsterdam | Innenstadt |
| `city_swiss_laube` | 46 | Bern | Innenstadt |
| `city_dutch_canal_b` | 22 | Amsterdam | Innenstadt |
| `city_paris_corner` | 8 | Paris | Innenstadt |

(Die Etiketten der Zählung nennen die Etappe und die Startstadt; die Häuser stehen an der Ankunft der Gegenstadt.)

## 3. Wie gebaut wurde – Bauer `city`, Hooks, geänderte Dateien

Alle zwölf Modelle kommen aus dem Bauer `city` von AS5a1/AS5aR1 (`tools/blender/ce3d/cities3d.py`): Öffnungen mit
Laibung, Rahmen, Sprossen, Sohlbank und versenkter Scheibe (Tag: das gemalte Glas des Sprites, Nacht: sein Licht aus
dem Lichtatlas, `emit_energy` 1,6 wie AS4R), Läden mit Auslage, Türen mit Stufen, Fensterläden als Geometrie,
Rückwände auf den Texeln der Straßenwand, flache lod1 ab 60 m, Ausschneide-Geländer mit `cut_fill`. Neu in diesem
Paket (alles rückwärtskompatibel, Voreinstellung = altes Verhalten; Beweis: die elf Modelle von Charge 1, die
Brückenteile und das Hausboot kommen byte-gleich heraus, Abschnitt 6):

| Option (Katalog) | Wozu |
|---|---|
| `rail_module` {Objekt-Präfix: L} | Geländer als wiederholtes Modul: Jedes Geländerobjekt wird bei u = k·L geschnitten (L = Vielfaches des Rasters des Generators), eine Fläche über ein ganzes Modul wird gebacken, alle anderen bekommen (u − k·L, z) dieses Moduls; Ober-, Unter- und Stirnflächen die Farbe des Handlaufs; schräge Platten (Eckhaus) lesen u = x. Vorher hätte ein durchgehender Haussmann-Balkon von 22 m bei 150 Texeln je Meter mehr Fläche gebraucht als der ganze 2048×1024-Atlas; die Fenstergitter des Lyoner Hauses kosteten in der ersten Probe die Hälfte des Atlas. |
| `weights.solid` {Präfix: Gewicht} | Baumkronen, Hortensien, Oleander, Hecken: Gewicht unabhängig von der Blickrichtung, nie „verdeckt“ – die Unterseiten der dezimierten Kronen bekamen weniger als einen Texel und zeigten hellgraue Flecken (Runde 0, Bild `r0sud`). |
| `openings.cover_skip` (Präfixe) | Objekte, die kein Fenster verdecken: Fenstergitter 10–16 cm vor dem Glas (Lyon, Paris), Geranien und Blumenkästen (Bern), Traufen knapp über den obersten Fenstern (Reihenhäuser, Lauben). Vorher blieben 8–33 Fenster je Modell gemalt. |
| `openings.chamfer` | Fenster und Laden der 45°-Ecke des Haussmann-Eckhauses werden geschnitten. Nebenbei behoben: Die Raster der Ecke wurden vorher in die Rückwand geschnitten (`_grid_faces`). |
| `smooth` (Präfixe) | Blumenkugeln glatt schattiert (vorher facettierte „Plastiksteine“). |

Hooks im Generator `props_cities.py` (Voreinstellung = Sprite; `check_sprite_geometry.py --only props --jobs 1`:
86 von 86 identisch): `close3d` für `dutch_canal` (über `_canal_house(side=…, close3d=…)`), `dutch_canal_b`,
`dutch_terrace`, `belgian_terrace`, `belgian_stone`, `french_immeuble`, `swiss_laube` – Tabelle in
`docs/modelle.md` Abschnitt 21. `french_sud`, `french_maison`, `swiss_chalet` und die Haussmann-Blöcke haben im
Generator schon Fenster an der Straßenflanke.

Geänderte geteilte Dateien (je ein Satz Zweck):

| Datei | Zweck |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | zwölf Einträge im Block `# --- AS5a ---` (zweites `MODELS.update`, „AS5a2“) |
| `tools/blender/ce3d/cities3d.py` | die fünf Optionen oben (rückwärtskompatibel) und ihre Doku im Modultext |
| `tools/blender/cesprites/props_cities.py` | Hooks `close3d` (additiv, Sprite unverändert) |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) |
| `docs/modelle.md` | Kopfzeile und Abschnitt 21 |

Nicht geändert: `buildings3d.py` (die acht AS4-Häuser behalten ihren Schlüssel), `bake.py`, `export_models.py`,
`validate_models.py`, `model_db.gd`, Renderer, Shader, Sprites.

## 4. Runden (bauen, ansehen, Mängel, beheben)

Proben mit halbem Atlas und einem Bake-Sample (`probe.py`, Schlüssel „debug“, nie committet), angesehen in der
Spielkamera mit Renn-Licht (`k5_scene --mode=close|dist2|lods`, „Hoch“, 12 und 22 Uhr). Danach Code eingefroren
(93e5031) und alle zwölf echt exportiert, Runde 4 auf den echten Exporten.

| Runde | Modelle | gefunden (angesehen/gemessen) | behoben mit |
|---|---|---|---|
| 0 | Südhaus | Unterseiten der dezimierten Platanenkrone als hellgraue Flecken (weniger als ein Texel: Gewicht `under` 0,05 × 0,3); das Balkongeländer belegte 40 % des (halben) Atlas | `weights.solid`; `rail_module` |
| 1 | Südhaus, belgische Reihe, Loire, Lyon | Krone sauber; die Flanken mit Fenstern lesen wie Fassaden; Lyon: 16 Fenster hinter den Fenstergittern blieben gemalt (Gitter 10–16 cm vor dem Glas gelten als Verdeckung); lod1 bei 250 m heller als das Sprite | `openings.cover_skip`; Helligkeit: im Rennen zu beurteilen (Prüfszene-Platzhalter 11–23 % zu dunkel, KRITIK-5a1) |
| 2 | übrige acht | Lauben: 33 Fenster gemalt (Geranien vor den Fenstern, Traufe über der obersten Reihe), Chalet 4 (Geranien), niederländische Reihe 8 (Traufe); Eckhaus: die schrägen Geländer der Ecke kosteten 39 % des Atlas (Dichte Obergeschosse 21 px/m), die Fenster der Ecke gemalt und ihre Raster in die Rückwand geschnitten; Chalet-Geranien facettiert | `cover_skip`; schräge Platten ins Modul; `openings.chamfer` + `_grid_faces`; `smooth`; Maashaus-Atlas 1024 × 1024 (77 px/m waren mehr als nötig); Haussmann-Gewichte Dach 0,35 / abgewandt 0,25 |
| 3 | Eckhaus, Lauben, Chalet, Reihe, Maashaus | Eckhaus 0 verdeckte Fenster, Dichte 40 px/m; Lauben noch 8 (Traufe) | `cover_skip` Dach/Untersicht der Lauben |
| 4 | alle zwölf, echte Exporte (Code 93e5031) | Prüfer rot: Grachtenhaus B `extent_m.left` 14,36 gegen Sprite 13,96 (das Kranzgesims der Flanke ragte hinten 0,4 m heraus); Eckhaus: Auslage der Ecke mit diagonalen Streifen; Maashaus: Kreuzstock dünner als im Sprite (4,5 statt 14 cm); im Rennen (Paris, A/B) Modern deutlich feiner, keine Blässe | Gesims endet 1 m vor der Rückwand; `_display_mat` liest auf der Ecke u = (x − y)/√2; `bar_w` 0,11 |
| 5 | alle 12 + Charge 1 + Brücken + Hausboot neu (Code 771b079) | Prüfer grün; Grachtenhaus B, Eckhaus, Maashaus geändert, alle übrigen byte-gleich | – |

## 5. Budget und Messungen

### 5.1 Budgettabelle (gemessen: Export-Bericht, `validate_models.py --report`, Archivschätzung wie `tools/pck_report.py`)

| Set | Platzierungen (Netz) | Maßstab im Spiel | Dreiecke lod0 / lod1 | Atlas | px/m EG + 1. OG / darüber (Modellmaß) | Archiv Netze / Texturen | Export |
|---|---|---|---|---|---|---|---|
| `city_french_sud` | 588 | 0,80–1,10 | 5 359 / 3 716 | 1024×1024 | 54 / 54 | 119 / 394 kB | 312 s |
| `city_belgian_terrace` | 315 | 0,90–1,15 | 2 586 / 1 162 | 2048×1024 | 64 / 51 | 46 / 550 kB | 474 s |
| `city_french_maison` | 209 | 0,90–1,10 | 3 910 / 1 874 | 1024×1024 | 51 / 51 | 90 / 311 kB | 280 s |
| `city_french_immeuble` | 202 | 0,95–1,14 | 4 020 / 2 486 | 2048×1024 | 65 / 52 | 75 / 566 kB | 755 s |
| `city_dutch_terrace` | 130 | 0,90–1,10 | 3 346 / 1 060 | 1024×1024 | 46 / 46 | 73 / 287 kB | 227 s |
| `city_belgian_stone` | 96 | 0,91–1,15 | 1 336 / 278 | 1024×1024 | 55 / 44 | 21 / 267 kB | 177 s |
| `city_paris_haussmann` | 55 | 0,95–1,10 | 6 518 / 3 714 | 2048×1024 | 50 / 38 | 125 / 601 kB | 651 s |
| `city_swiss_chalet` | 54 | 0,90–1,10 | 3 128 / 1 280 | 1024×1024 | 53 / 53 | 56 / 282 kB | 166 s |
| `city_dutch_canal` | 51 | 0,95–1,10 | 3 734 / 1 802 | 2048×1024 | 50 / 40 | 77 / 631 kB | 483 s |
| `city_swiss_laube` | 46 | 0,95–1,10 | 4 865 / 942 | 2048×1024 | 44 / 35 | 70 / 569 kB | 308 s |
| `city_dutch_canal_b` | 22 | 0,95–1,10 | 3 623 / 1 543 | 2048×1024 | 47 / 38 | 69 / 683 kB | 461 s |
| `city_paris_corner` | 8 | 1,00–1,09 | 5 675 / 3 418 | 2048×1024 | 47 / 35 | 112 / 653 kB | 800 s |

Summe (deflate -9 je Datei): Netze 0,93 MB, Texturen 5,79 MB. „Export“ = Zeit des letzten echten Exports mit Bake.

Grenzen (§4.6.9, Auftrag): Stadthaus lod0 ≤ 10 000 Dreiecke (größtes: Haussmann 6 518), ≤ 2 Zeichenaufrufe je Stufe
(alle 2/2), Texturen in der Stufe (2048×1024 Innenstadt, 1024×1024 Vorort/Einzelhaus), Archivanteil der Charge
≤ 3 MB Netze und ≤ 7 MB Texturen (gemessen: 0,93 MB / 5,79 MB). Texeldichte im Spiel = Modellmaß / Maßstab: das
Erdgeschoss liegt bei ≥ 40 px/m außer bei den Lauben im größten Maßstab 1,10 (39,8), alle Straßenwände ≥ 26 px/m.
Backzeit = Export mit Cycles-Bake und AO, `nice -n 19`, eine Instanz, CE_THREADS 3, auf der geteilten Maschine
(gemessen; beim zweiten Export der Runde 5 waren es 98–504 s).

### 5.2 Stufenwechsel, Flimmern, Geländer (llvmpipe, Prüfszene im Renn-Look, gemessen)

| Messung | Ergebnis |
|---|---|
| Stufenwechsel lod0 → lod1 bei 60 m, „Mittel“, 12 Uhr | 9,1 % (Lauben) … 18,3 % (Grachtenhäuser) der Pixel, Helligkeit −0,5 … +0,6 %; Charge 1 nach der Nacharbeit: 13–27 % |
| dasselbe, 22 Uhr | 7,8 … 14,5 % der Pixel, Helligkeit +0,6 … +4,9 % (Chalet, Lauben am höchsten) |
| Flimmern (Pixel, die je Viertelpixel-Kameraschritt kippen, 40 / 60 / 100 / 150 m; Sprite in Klammern) | Haussmann 1,0 / 1,2 / 1,0 / 0,6 % (0,0 / 0,2 / 0,3 / 0,4); Grachtenhäuser 0,8 / 1,1 / 0,8 / 1,1 % (0,1 / 0,2 / 0,3 / 0,4); belgische Reihe 0,4 / 0,6 / 0,4 / 0,4 % (0,1 / 0,1 / 0,2 / 0,3); Lyon 0,8 / 0,6 / 0,3 / 0,5 % (0,2 / 0,2 / 0,3 / 0,5); Chalet 0,5 / 0,9 / 1,0 / 1,3 % (0,2 / 0,2 / 0,4 / 0,5) |
| Geländer in den Mip-Stufen 1–4 (`mipband.py`: Deckung gegen Mip 0, Helligkeit des Bandes in 8-Bit-Luma) | Haussmann Deckung 1,16 / 1,55 / 1,96 / 2,74, Helligkeit +1,0 / +1,0 / +1,8 / −0,5; Eckhaus −2,1 … +0,3; Lyon +0,3 … +3,6; Südhaus −3,0 … +0,2; Chalet −3,0 … +0,1 – das Geländer wird zum Band mit seiner mittleren Helligkeit, verschwindet nicht (Charge 1 vor `cut_fill`: −13,6 … +18,0) |
| Umriss gegen das Sprite (Sprite-Kamera, IoU) | IoU 0,945 (Chalet) … 0,999 (Grachtenhäuser), lod0 = lod1 bis auf 0,003; 0,0–2,5 % der Modellfläche außerhalb des Sprites (Südhaus und Loire-Haus: Baumkronen), Sprite zu 95,5–100 % gedeckt (Chalet: linke Traufe und Giebelwand wenige Pixel innen); zehn von zwölf ≥ 0,996 (gemessen, `umrisse_sprite_gegen_modell.jpg`) |
| Tönung `#ead6cc` (Reihenhäuser Ruhrgebiet) | Albedo × Tönung entspricht dem getönten Sprite (angesehen, `toenung_reihenhaeuser_ruhr.jpg`) |

Die Prüfszene vergleicht die Helligkeit bei 200 m gegen den Arcade-Platzhalter der Szene; der ist dort 11–23 % zu
dunkel (Werkzeugvorbehalt der Kritik von Charge 1) – Helligkeit nur im Rennen beurteilt (Abschnitt 7).

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

## 7. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Seed 11, Limousine, Autopilot, fliegender Start mit 50 km/h, Bilder 2 s und 4 s nach dem Start; Positionen aus der
Zählung (`census_all.log`, erste Kilometer der Innenstadt-Sets): Paris (Lüttich–Paris km 387,5: Haussmann, Eckhaus,
Loire-Haus, Lyoner Haus), Amsterdam (Bremen–Amsterdam km 357,3: Grachtenhäuser A und B, Reihenhäuser), Brüssel
(Köln–Brüssel km 195,5: belgische Reihe, Maashaus), Toulouse (Pau–Toulouse km 192,5: Lyoner Haus, Südhaus), Bern
(Lyon–Bern km 302,4: Lauben, Chalet). Je Stadt „Hoch“ 12 und 22 Uhr und „Mittel“ 19:30, Bern nur „Hoch“ 12 Uhr.

| Stadt | Voreinstellung | Uhrzeit | Exit | Fehlerzeilen (SCRIPT ERROR, Parse Error, ERROR:) in beiden Logs | Bild |
|---|---|---|---|---|---|
| Paris | hoch | 12 Uhr | 0 | 0 | `rennen_paris_hoch_mittag_00/01.jpg` |
| Paris | hoch | 22 Uhr | 0 | 0 | `rennen_paris_hoch_nacht_00/01.jpg` |
| Paris | mittel | 19:30 | 0 | 0 | `rennen_paris_mittel_daemmerung_00/01.jpg` |
| Amsterdam | hoch | 12 Uhr | 0 | 0 | `rennen_amsterdam_hoch_mittag_00/01.jpg` |
| Amsterdam | hoch | 22 Uhr | 0 | 0 | `rennen_amsterdam_hoch_nacht_00/01.jpg` |
| Amsterdam | mittel | 19:30 | 0 | 0 | `rennen_amsterdam_mittel_daemmerung_00/01.jpg` |
| Brüssel | hoch | 12 Uhr | 0 | 0 | `rennen_bruessel_hoch_mittag_00/01.jpg` |
| Brüssel | hoch | 22 Uhr | 0 | 0 | `rennen_bruessel_hoch_nacht_00/01.jpg` |
| Brüssel | mittel | 19:30 | 0 | 0 | `rennen_bruessel_mittel_daemmerung_00/01.jpg` |
| Toulouse | hoch | 12 Uhr | 0 | 0 | `rennen_toulouse_hoch_mittag_00/01.jpg` |
| Toulouse | hoch | 22 Uhr | 0 | 0 | `rennen_toulouse_hoch_nacht_00/01.jpg` |
| Toulouse | mittel | 19:30 | 0 | 0 | `rennen_toulouse_mittel_daemmerung_00/01.jpg` |
| Bern | hoch | 12 Uhr | 0 | 0 | `rennen_bern_hoch_mittag_00/01.jpg` |

13 Läufe, alle Exit 0, 0 Fehlerzeilen (gemessen). Ein Modern-Lauf mit zwei Bildern brauchte 4–8 min.

Angesehen:
- **Tag:** Wo Arcade die Straßenflanke eines Hauses als flache Bildfläche zeigt (Haussmann-Bogenläden in Paris,
  blinde Backsteinflanke des Treppengiebelhauses in Amsterdam, Erdgeschoss des Maashauses in Brüssel, Lauben in Bern),
  zeigt Modern Fenster mit Laibung und Sprossen, Läden mit Auslage, Gitter, Balkone und Blumenkästen. Front und Dach
  wie im Sprite; die Häuser stehen an derselben Stelle. Modern ist hier deutlich feiner, nicht nur anders.
- **Dämmerung (19:30, „Mittel“):** dieselben Fenster leuchten wie in Arcade, dazu die neuen Flankenfenster.
- **Nacht (22 Uhr):** Fensterlicht unregelmäßig wie in Arcade. Schwächer als Arcade sind die Schaufenster: In Paris
  ist die Ladenzeile rechts in Arcade eine Reihe heller gelber Bögen, in Modern beleuchtete Auslagen mit Waren, aber
  dunkler (beleuchtete Ladenpixel im Mittel 124 gegen 207 in Arcade, ein beleuchtetes Fenster 210; gemessen in der
  Nahansicht bzw. dem A/B-Bild) – der schwächste Punkt dieser Charge, Abschnitt 8.
- **Nicht meine Modelle:** In Toulouse stehen neben Südhaus und Lyoner Haus die spanischen Häuser als
  Arcade-Platzhalter (AS5b); in Brüssel fehlen in Modern die niedrigen Backsteinmauern, die Arcade am Straßenrand
  zeigt (Requisiten-Bauer/andere Sets, nicht untersucht).

**Clip** (`tools/ab_clip.sh`, `CLIP_S=10 FPS=60 SIDE=960x540`, Modern „Hoch“): Lüttich–Paris ab km 387,6, 12 Uhr,
Limousine, Seed 11, Autopilot mit `--autopilot-target=50 --start-speed=50` – der Tacho zeigt in allen vier Standbildern (0,5 / 3,5 / 6,5 / 9,5 s) 50 km/h,
km 387,7 → 388,9 (gemessen: 1920×570, 60 fps, 600 Bilder, 5,9 MB; beide Läufe Exit 0, 0 Fehlerzeilen). Ein erster
Clip ohne `--autopilot-target` beschleunigte auf 68–136 km/h und wurde ersetzt. Angesehen: über die Pont Alexandre III
in die Haussmann-Zeile; Modern zeigt die Flanke mit durchgehenden Balkonen, Bogenläden mit Auslage und Markisen, wo
Arcade die Hauswand als Bildfläche vorbeischiebt. Angesehen habe ich vier Standbilder, nicht die Bewegung Bild für Bild; Flimmern siehe
Messwerte in Abschnitt 5.2. Standbilder: `fahrt_paris_50kmh_standbilder.jpg`.

## 8. Ehrliche Einordnung und schwächster Punkt

Gut (angesehen in Kontaktbögen, Nahansichten und Spielkamera; Rennen siehe Lieferordner): Umriss, Geschosse, Dächer,
Giebel und Farben wie das Sprite; Tiefe an Front und Straßenflanke – Laibungen, Rahmen, Sprossen, Sohlbänke,
Fensterläden als Geometrie (Südhaus, Loire-Haus, Lyon, Chalet, Grachtenhaus B), Haussmann-Balkone mit Konsolen und
durchgehendem Schmiedeeisen, französische Fenstergitter vor echten Fenstern, Läden mit Auslage (Lyon, Brüssel, Bern,
Paris), die Arkaden der Lauben als echte Öffnungen, Blausteinstürze, Gesimse, Treppen-, Glocken-, Hals-, Gesims- und
Volutengiebel. Die Straßenflanken, im Sprite blind, haben Fenster und Türen im Stil der Front. Nachts leuchten
dieselben Fenster wie im Sprite, die Auslagen mit Waren dahinter.

Noch nicht gut:
- **Schwächster Punkt – Schaufenster nachts.** Die Auslagen leuchten, aber dunkler als die Schaufenster in Arcade
  (beleuchtete Ladenpixel im Mittel 124 gegen 207 in Arcade; ein beleuchtetes Wohnfenster 210, gemessen). Am
  deutlichsten in Paris (Haussmann-Bogenläden) und Lyon. Ursache: die gemeinsame Helligkeit der Auslage im Bauer
  `city` (`_display_mat`), die auch Charge 1 trägt; eine Anhebung (Vorschlag `shop_glow` ≈ 1,6) ändert den
  Cache-Schlüssel aller 23 Stadthäuser und braucht einen vollen Neu-Export – nicht mehr in diesem Paket.
- **Rückseiten:** Das Haussmann-Eckhaus hat hinten blanke Putzwände (für die abgeschrägte Grundfläche findet der Bauer
  keine gegenüberliegende Wand zum Wiederverwenden); die rechte Flanke des Halsgiebelhauses (Grachtenhäuser) ist
  blind. Beides sieht man nur, wenn die Straße das Haus umfährt (gefolgert: selten).
- **Fern (200–250 m, lod1):** Fensterreihen heller als im Sprite (Rahmen und Sprossen überwiegen das dunkle Glas). Im
  Rennen bei Paris nicht auffällig (angesehen), in der Prüfszene deutlich.
- **Bäume** von Südhaus und Loire-Haus sind dezimierte Kronen – aus der Nähe Klumpen, aus der Spielkamera ok.
- **Flimmern** 0,3–1,3 % der Pixel je Viertelpixel-Schritt gegen 0,0–0,5 % beim Sprite (gemessen): das Modell ist
  unruhiger als das vorgefilterte Sprite, vor allem Haussmann und Chalet (Geländer, Sprossen).
- **Stufenwechsel** lod0 → lod1 bei 60 m ändert 8–18 % der Pixel ohne Überblenden (R7).
- **Texeldichte Lauben:** beim größten Maßstab 1,10 liegt das Erdgeschoss mit 39,8 px/m knapp unter 40 (gemessen).
- **Erfundene Flankenfenster:** an Brandwänden (Grachten-, Reihenhäuser) – gewollt, aber nicht vorbildgetreu.
- **Keine Wandleuchten** an den Fassaden; das Nachtbild lebt allein von den Fenstern.

## 9. Was andere Pakete brauchen (nicht in meinen Dateien)

- **R7 – Tönung:** `city_dutch_terrace` steht an 50 von 130 Stellen (Vororte im Ruhrgebiet) getönt `#ead6cc`. Der
  Atlas trägt die ungetönten Farben; Albedo × Tönung = getöntes Sprite (Lieferbild `toenung_reihenhaeuser_ruhr.jpg`).
  Bis R7 die Tönung als Instanzfarbe auf `baked` legt, stehen diese Häuser etwas röter da als in Arcade.
- **R7 – Stufenwechsel:** lod0 → lod1 bei 60 m („Mittel“) ändert 9–18 % (Tag) bzw. 8–15 % (Nacht) der Pixel (Sprite-Tausch als Vergleich:
  siehe Abschnitt 5); ein Überblenden (A-16 nennt nur Bäume) sollte die Stadthäuser einschließen.
- **R7 – Fernbild:** Kein Modell hat ein Fernbild; lod1 trägt bis 100 000 m. Bei 250 m wirken die Fensterreihen in
  lod1 heller als im Sprite (weiße Rahmen, Rahmenring und Sprossen des Atlas überwiegen das dunkle Glas) – im Rennen
  bei Paris nicht auffällig (A/B), in der Prüfszene deutlich.
- **R4 – Licht:** helle Steinfassaden (Haussmann, Loire-Haus, Grachtenhaus B) in der Mittagssonne heller als Arcade
  (K8 der Kritik von Charge 1); ich habe die Albedo nicht abgedunkelt.
- **Leitung/R2 – Kurvenkorridor (K1 der Kritik von Charge 1):** gilt für alle Stadthäuser; nicht in meinen Dateien.
- **Leitung – Generator-Flanken:** Die Hooks `close3d` erfinden Fenster an Flanken, die im Sprite blind sind (Grachten-
  und Reihenhäuser sind in Wirklichkeit Brandwände). Ich habe das nach der Linie von AS5aR1 und dem Auftrag getan
  (blinde Flanken waren der wichtigste Mangel der Charge 1); die Frontansichten bleiben exakt das Sprite.

## 10. Lieferliste (`deliver/AS5a2/`)

| Datei | Inhalt |
|---|---|
| `bericht.md` | dieser Bericht |
| `kontaktbogen_tag.jpg`, `kontaktbogen_nacht.jpg` | alle zwölf Modelle, lod0 und lod1, Tag und Nacht (`tools/models_contact_sheet.sh`) |
| `spielkamera_<stil>_mittag/nacht.jpg` (french, belgian, dutch, swiss, paris) | Spielkamera neben der Straße bei 10 / 30 / 100 / 250 m, darunter das Arcade-Sprite |
| `nahansichten_<stil>_mittag/nacht.jpg` | Fassaden aus der Nähe: Straßenflanke, schräg, vorn (lod0, „Hoch“) |
| `spielkamera_runde5_*.jpg`, `nahansichten_runde5_*.jpg` | Grachtenhäuser B, Eckhaus und Maashaus nach der Korrektur der Runde 5 (ersetzen diese drei in den Stilbildern dutch, belgian, paris; die übrigen Häuser dort sind unverändert) |
| `stufen_G1..G3_mittag/nacht.jpg` | Stufenwechsel lod0 / lod1 bei 60 m, lod1 bei 200 m, Sprite („Mittel“) |
| `toenung_reihenhaeuser_ruhr.jpg` | Tönung `#ead6cc`: Modell, Modell × Tönung, getöntes Sprite, Sprite |
| `umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera, Deckung je Stufe (grün beide, blau nur Sprite, orange nur Modell) |
| `flimmern_messbild.jpg` | Flimmern bei Viertelpixel-Schritten, Modell und Sprite |
| `rennen_<stadt>_<voreinstellung>_<zeit>_00/01.jpg` (26) | A/B im Rennen: links Arcade, rechts Modern, 2 s und 4 s nach dem Start |
| `fahrt_paris_50kmh.mp4` (+ zwei Logs), `fahrt_paris_50kmh_standbilder.jpg` | 10-s-Clip A/B bei 50 km/h, 60 fps, Paris; vier Standbilder daraus |

## 11. Commits (alle auf `origin/wip/v080-as5a2` gesichert, kein Force-Push)

- `6abcb57` Katalog der zwölf Stadthäuser, Hooks close3d der Straßenflanken, Geländermodule (WIP)
- `93e5031` Bauer city – Fenstergitter ohne Verdeckung, abgeschrägte Ecke, Blumen glatt, schräge Geländer im Modul
- `abec2ad` Südhaus, Loire-Haus und Lyoner Stadthaus (french, french_south) als Echtzeit-Modelle
- `63ca0ef` Lütticher Reihenhäuser und Maashaus (belgian) als Echtzeit-Modelle
- `f435fd9` Reihenhäuser und Grachtenhäuser A und B (dutch) als Echtzeit-Modelle
- `60462fa` Chalet und Berner Lauben (swiss) als Echtzeit-Modelle
- `02d93cb` Haussmann-Block und -Eckhaus (paris) als Echtzeit-Modelle, Manifest neu erzeugt
- `771b079` Kranzgesims der Grachtenhaus-Flanke kürzer, Auslage der Eckhaus-Abschrägung, Kreuzstock des Maashauses
- `adef9df` Grachtenhäuser B, Haussmann-Eckhaus und Maashaus neu exportiert, Manifest neu erzeugt
- `3c5e37a` docs/modelle.md Abschnitt 21 – Stadthäuser dutch, belgian, french, paris und swiss

Die Stil-Commits `abec2ad` … `60462fa` tragen Modelle ohne neues Manifest (erst `02d93cb` erzeugt es für alle
zwölf); dazwischen ist das Manifest nicht auf dem Stand der Modellordner. Der Endstand ist konsistent (Prüfer grün).
