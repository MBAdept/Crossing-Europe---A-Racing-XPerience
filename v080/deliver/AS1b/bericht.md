# AS1b – Umgebung für den Schnitt (Bericht)

Paket AS1b von v0.8.0 „Modern“, Welle 2. Zweig `worktree-wf_2e14ac26-9d4-2`, gesichert als
`origin/wip/v080-as1b`; Basis `d025d1d`. Worktree:
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-2`.
Zahlen sind mit **(gemessen)** oder **(gefolgert)** markiert.

## 1. Ergebnis in Kürze

- Jedes Requisiten-Set, das Kiel–Hamburg in den ersten 75 km zeigt, hat ein Echtzeit-Modell. Im A/B-Bogen S1–S3
  steht kein Sprite-Platzhalter mehr (gemessen: Bogen `ab_S1_S2_S3.jpg`).
- 20 Modelle neu oder neu gebaut, dazu die Laterne nachgebessert: Eiche und Birke (je zwei Samen-Varianten),
  runder Busch (zwei Varianten), niedriger Busch, zwei Bodendecker, Bauernhaus, Scheune, Heuballen, Windrad,
  Windmühle, Strommast, Leitpfosten, Tankstelle, Zapfsäule, Blitzer, Zollhäuschen.
- Vier neue Baumeister im Exporter: `bush`, `grass`, `building` (Gebäude mit echten Öffnungen, Rinnen,
  Umgebungsverdeckung) und `lattice` (Fachwerk im Ausschneide-Atlas, erster Lauf der Klasse `baked_cutout`).
- Prüfer grün, Budgets eingehalten, Sprite-Geometrie unverändert (86 von 86 Sets identisch).
- Neues Prüfwerkzeug `tools/models/prop_scene.sh`: Modelle durch die Spielkamera nach Entfernung und Stufe, mit
  gemessenen Farb- und Pixelwerten an den Umschaltentfernungen.

## 2. Was die Strecke zeigt

Gezählt mit dem `Track`-Generator der Etappe (Skript im Scratch `stage_sets.gd`, alle Segmente bis km 75 ab Kiel)
(gemessen): Eiche 147, Birke 88, runder Busch 76, Heuballen 48, Windrad 28, Zapfsäule 9, Bauernhaus 7, Blitzer 2,
Tankstelle 1, und die Preissäule `object:fuel_pylon` (kein Sprite-Set, prozedural: Paket R6). Niedriger Busch,
Scheune, Windmühle, Strommast, Laterne, Leitpfosten und Zollhäuschen kommen in diesem Stück nicht vor; sie sind
trotzdem gebaut (Paketliste §5).

## 3. Modelle (alle Werte gemessen, `validate_models.py --report`)

| Modell | Kategorie | Dreiecke je Stufe | Aufrufe | Netz B | Textur B (VRAM) | Export s |
|---|---|---|---|---|---|---|
| props/tree_oak | Baum | lod0 1 490 · lod1 679 · Schatten 179 · Fernbild | 2/2/1 | 66 237 | 1 572 315 | 4,9 |
| props/tree_oak_b | Baum | lod0 1 520 · lod1 755 · Schatten 235 · Fernbild | 2/2/1 | 68 268 | 1 570 228 | 5,5 |
| props/tree_birch | Baum | lod0 1 880 · lod1 591 · Schatten 154 · Fernbild | 2/2/1 | 70 113 | 1 378 381 | 6,3 |
| props/tree_birch_b | Baum | lod0 1 910 · lod1 644 · Schatten 177 · Fernbild | 2/2/1 | 71 372 | 1 374 564 | 6,5 |
| props/bush_round / _b | Pflanze | lod0 372 · lod1 88 | 1/1 | 17 550 / 17 484 | 335 267 | 0,7 |
| props/bush_low | Pflanze | lod0 384 · lod1 104 | 1/1 | 18 611 | 339 881 | 0,8 |
| props/cover_bush | Pflanze | lod0 182 · lod1 54 | 1/1 | 9 341 | 339 192 | 0,8 |
| props/cover_grass | Pflanze | lod0 42 · lod1 12 | 1/1 | 2 559 | 254 707 | 0,7 |
| props/farmhouse | Landgebäude | lod0 1 107 | 2 | 15 352 | 856 146 | 92,5 |
| props/barn | Landgebäude | lod0 290 | 2 | 5 652 | 431 474 | 80,9 |
| props/windmill | Landgebäude | lod0 1 640 | 2 | 23 796 | 829 567 | 73,8 |
| props/fuel_station | Landgebäude | lod0 1 480 | 2 | 23 467 | 244 163 | 133,4 |
| props/customs_booth | Landgebäude | lod0 206 | 2 | 3 783 | 66 565 | 23,5 |
| props/haybale | Möbel | lod0 672 | 1 | 7 575 | 195 357 | 27,6 |
| props/fuel_pump | Möbel | lod0 384 | 1 | 7 259 | 105 771 | 37,5 |
| props/radar_camera | Möbel | lod0 328 | 1 | 5 428 | 19 436 | 8,2 |
| props/delineator | Möbel | lod0 12 | 1 | 691 | 2 746 | 2,7 |
| props/wind_turbine | Möbel | lod0 744 | 1 | 9 716 | – | 0,2 |
| props/power_pylon | Mast | lod0 220 | 1 | 3 638 | 165 059 | 2,2 |
| props/streetlight | Möbel | lod0 274 | 1 | 4 104 | – | 0,1 |

Budgets §4.6.9 (gemessen gegen die Tabelle): Bäume ≤ 2 500 / 900 Dreiecke, ≤ 450 Karten (Eiche genau 450, Birke
442), Büsche ≤ 400 / 120, Landgebäude ≤ 2 000 und ≤ 2 Aufrufe, Straßenmöbel ≤ 1 500 und 1 Aufruf, Mast ≤ 5 000.
Ganzer Bestand nach diesem Paket (gemessen): Netze 4,56 MB von 40 MB, Texturen 15,94 MB von 240 MB im
Grafikspeicher, Quellen 10,29 MB von 60 MB; davon die 21 Requisiten-Modelle: Netze 0,45 MB, Texturen 10,4 MB.

Texeldichte der Gebäude (gemessen, Bake-Statistik): Bauernhaus 35 px/m, Windmühle 32, Scheune 46,
Tankstelle 48, Zollhäuschen 59 – alle über den geforderten 26 px/m. Umgebungsverdeckung im Mittel 0,84
(Bauernhaus) bis 0,96 (Tankstelle).

## 4. Vegetation

- **Kartenbäume** (`ce3d/veg3d.py`, `ce3d/leafatlas.py`, neu geschrieben): die Kugeln der Sprite-Krone sind die
  Form; darauf viele kleine flache Laubkarten nach außen (Eiche 450, Birke 442), deren Helligkeit die Verdeckung
  durch die übrigen Kugeln ist (14 Strahlen); Normalen zu 55 % aus der eigenen Kugel (gebogene Normalen: jeder
  Klumpen hat Licht- und Schattenseite). Stamm und Hauptäste aus dem Generator plus ein Ast je Laubklumpen
  (k-Means 9 / 7); Astenden außerhalb der Krone fallen weg. Birkenstamm alle 25 cm neu beringt, schwarze Marken je
  Dreieck. Ein geschlossener dunkler Kern (ein deckendes Atlasfeld) verhindert, dass man durch die Krone den Himmel
  sieht. Wind über `ce_wind` im `leaves.gdshader` (Ausschlag nach Höhe, Phase und Steifheit je Karte).
- Verworfene Varianten (gemessen an Bildern): Zeltkarten kräuseln sich an der Silhouette, gekreuzte Kartenpaare
  ziehen Schlieren; waagerechte Karten oben sahen aus wie Striche (darum gestauchte Neigung).
- **Halo-Alpha**: durchsichtige Texel bis 2 Texel neben einem Blatt bekommen Alpha 0,28 (unter der Schwelle 0,42 auch
  nach BC3-Quantisierung, die einen Wert von 0,36 als 0,43 lieferte (gemessen)). Deckung über der Schwelle je
  Mipmap-Stufe (gemessen, Eichenatlas): 0,443 · 0,460 · 0,478 · 0,489 · 0,535 – die Krone wird mit der Entfernung
  nicht licht.
- **Stufen ohne Sprung** (gemessen mit `prop_scene.sh --mode=lods`, mittlere Farbe / Pixel des Baums):

  | Modell | lod0 @ 60 m | lod1 @ 60 m | lod1 @ 200 m | Fernbild @ 200 m |
  |---|---|---|---|---|
  | tree_oak | (60,103,32) 11 980 px | (59,103,31) 12 314 px | (67,111,37) 1 093 px | (63,107,35) 1 018 px |
  | tree_oak_b | (60,102,32) 11 100 px | (59,101,30) 11 163 px | (65,107,35) 978 px | (62,105,34) 922 px |
  | tree_birch | (103,144,56) 4 088 px | (106,148,56) 3 950 px | (112,154,64) 342 px | (111,154,67) 367 px |
  | tree_birch_b | (111,154,60) 3 827 px | (113,156,61) 3 808 px | (119,161,71) 334 px | (114,159,68) 346 px |

  Größte Abweichung: 4 Farbstufen und 7 % Pixel (Eiche lod1/Fernbild). Mittel dafür: `LOD1_LIFT` 1,06,
  Fernbild-Faktor 1,27 und Blauanteil +25 % (`IMPOSTOR_TINT`), Fernbild 256 px (höchstens 512).
- **Varianten**: `tree_oak_b`, `tree_birch_b`, `bush_round_b` (Katalog `variant_of`, eigener Samen); das Set der Art
  nennt sie in `variants`, der Requisiten-Builder (R2) wählt je Stück.
- **Büsche**: nur Klasse `leaves` (1 Aufruf), Karten auf den Generator-Kugeln, kleiner Kern.
- **Bodendecker** (A-3, höchstens 0,5 m): Sets **`props/cover_bush`** (Strauchpolster 1,5 × 1,2 × 0,45 m) und
  **`props/cover_grass`** (Grasbüschel 1,0 × 0,9 × 0,42 m). Im Manifest `"modern_only": true` (es gibt kein Sprite);
  Prüfer und `test_model_db.gd` kennen das.

## 5. Gebäude (Baumeister `building`, `ce3d/props3d.py`)

- Fenster und Türen werden aus den Rastern des Generators (`props_buildings.WINDOW_LOG`) in die Wand geschnitten
  (Delaunay mit Zwangskanten): Laibung 12 cm (gebacken, mit Verdeckung), Rahmen mit Sprosse und Kämpfer,
  Sohlbank, Scheibe (`vpbr`). Bauernhaus: 25 Öffnungen, Fenster auf allen Seiten (`allround`), Tür, Dachüberstand
  aus dem Generator, Schornstein mit Abdeckplatte, Rinnen und Fallrohre an beiden Traufen (gemessen: 25 / 4 / 1).
- Nachts leuchten die Scheiben über Lampenkanal 12 (`ce_night`): dunkel-warme Leuchtfarbe `#7a5e3a`, Gewicht
  0,55–0,9, welches Fenster leuchtet, folgt dem Anteil `lit` des Sprites. Bei Tag: dunkles Glas (eine helle
  Leuchtfarbe machte die Fenster tagsüber gelb, weil eine unbeleuchtete `vpbr`-Lampe die halbe Leuchtfarbe zeigt).
- Umgebungsverdeckung mit Cycles im Atlas (Atlasgröße, 24 Proben; Bauernhaus-Export von 335 s auf 92 s).
- Wandlampen verlieren die Seite zur Wand: der Lichtanker liegt vorn auf der Lampe und hat eine Richtung.
- Kein `auto_lod` (Lampenkanäle), zwei Flächen (`baked` + `vpbr`).
- Tankstelle: Ladenfenster rundum, vier Lampenfelder unter dem Dach mit Ankern nach unten (Lichtpfützen),
  Lichtschleier des Sprites ausgelassen. Scheune: Torrahmen und Streben als Bretter vor der Wand. Zollhäuschen:
  Fenster rundum, Lampe mit Anker.
- Straßenmöbel mit einem Atlas (Heuballen, Zapfsäule, Blitzer, Leitpfosten): ein Aufruf, Lampen im
  Nachtlicht-Atlas.

## 6. Technische Objekte

- **Windrad / Windmühle**: Rotorteile tragen den `vpbr`-Lackcode 0,875 und in `UV2.y` die Nabenhöhe / 128 m
  (89,6 m bzw. 19,8 m). Der heutige `vpbr.gdshader` zeichnet sie als feste Farbe (stehender Rotor). Die Drehung
  um die Modell-Z-Achse durch die Nabe mit `ce_time` ist auf einem Wegwerfzweig erprobt (10 Zeilen in `vertex()`,
  Bild `rotor_probe_t0_0.4_0.8.png`: drei Zeitpunkte, der Rotor dreht sich um die Nabe) – die Änderung selbst gehört
  R3 (siehe 11.). Flugbefeuerung des Windrads: Kanal 12 mit zwei Ankern (rot).
- **Strommast** (Baumeister `lattice`): Fachwerk jeder Turmseite, der Ausleger und der Spitze als Flächen mit in
  einen RGBA-Atlas gezeichneten Streben (Klasse `baked_cutout`, Schwelle 0,5), Isolatoren als Sechseckprismen; 220
  Dreiecke, ein Aufruf, wirft Schatten (Bild 40 m). Mipmap-fest: Streben ≥ 2,5 Texel, Halo 3 Texel mit Alpha 0,33.
  Gemessen (Anteil deckender Texel je Stufe relativ zu Stufe 0 = 7,3 %): ohne Halo Stufe 4 55 % / Stufe 5 3 %;
  2 Texel 74 / 17 %; **3 Texel 84 / 26 %**; 4 Texel 106 / 40 % (aber Stufe 3 143 %, zu fett). Bei 250 m liest sich
  das Gitter noch (Bild `strommast_abstaende.png`); bei 500 m löst es sich im Nebel auf.
- **Laterne**: Die Linse hängt zur Hälfte im Leuchtenkopf; geschlossen hoben sich ihre Normalen auf, und die Regel für geschlossene Fahrzeuglampen gab dem Lichtanker die Richtung (−0,965; 0,261; 0) – zur Seite und leicht nach oben (Flare und Pfütze neben der Lampe). Neue Option `hidden_tops` des Bauers `prop_vpbr`: die nach oben schauenden Flächen der Linse (nie sichtbar) fallen weg. Jetzt (gemessen): Anker auf der Unterseite der Linse bei 9,17 m, `dir` (0,007; −1; 0), 274 statt 312 Dreiecke, Bild bei Tag und Nacht unverändert.
- **Leitpfosten**: 12 Dreiecke, Atlas 128², Reflektor im Nachtlicht-Atlas (nachts hell).
- **Blitzer, Zapfsäule**: ein Atlas mit Verdeckung; Anzeige der Zapfsäule und Lampe im Nachtlicht.

## 7. Abnahme

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Prüfer grün | bestanden | `validate_models.py`: „CHECK models OK“ (28 Modelle, 182 Sets: 40 mit Modell); nach der Laterne erneut OK |
| Kontaktbogen Tag | bestanden | `kontaktbogen_tag.png` (alle Modelle, Anfahrt und Rückseite, alle Stufen) |
| Kontaktbogen Nacht | bestanden | `kontaktbogen_nacht.png` (Fenster, Lampen, Lichtpfützen, Flugbefeuerung) |
| Kartenbäume im Budget mit Fernbildern | bestanden | Tabelle 3 und 4; `stufen_baeume.png`, `abstaende_vegetation.png` |
| A/B S1–S3 ohne Sprite-Platzhalter | bestanden | `ab_S1_S2_S3.jpg` (R2-Stand + dieses Paket im Wegwerf-Worktree) |
| Sprite-Geometrie unverändert | bestanden | `check_sprite_geometry.py --only props/`: 86 von 86 identisch, 118 s |
| Cache-Schlüssel | bestanden | `export_models.py --check-keys`: „CHECK cache_keys OK 28 Modelle“ |
| Export-Determinismus | bestanden | alle 21 Requisiten mit `--force` neu exportiert (2 Prozesse, 369 s), gebacken, importiert, Manifest neu: `git status` leer (gemessen); die geänderte Laterne zweimal gebaut: gleiche Prüfsummen |
| `tools/run_tests.sh` | bestanden | 576 Unit-Tests, 0 fehlgeschlagen; alle CHECK-Gruppen OK (darunter `CHECK models`: 28 Modelle, 182 Sets); „Tests bestanden (569 s)“, Exit 0 (gemessen, ein Lauf) |
| `tools/golden.sh check` | bestanden | „GOLDEN arcade: 20 von 20 identisch (159 s)“, Exit 0 (gemessen, ein Lauf) |

## 8. Geänderte Dateien

Eigene (Paketliste §5): `tools/blender/ce3d/{veg3d,leafatlas,props3d}.py`, `assets/models/props/{tree_oak,
tree_birch, bush_round, bush_low, farmhouse, barn, haybale, wind_turbine, windmill, power_pylon, streetlight,
delineator, fuel_station, fuel_pump, radar_camera, customs_booth}/**`; Hooks in
`tools/blender/cesprites/{props_buildings,props_road}.py`.

Neue Ordner, die der Auftrag verlangt, die aber nicht in der Liste §5 stehen: `assets/models/props/{tree_oak_b,
tree_birch_b, bush_round_b}` (zwei Samen je Art, §4.6.9), `assets/models/props/{cover_bush, cover_grass}`
(Bodendecker A-3).

**Gemeinsame Dateien (Spalte W2 von §5 gehört AS1b; alle Änderungen additiv):**

| Datei | Änderung |
|---|---|
| `tools/blender/ce3d/catalog3d.py` | eigener Block nach `MODELS`: `BUILDER_CODE` für bush/grass/building/lattice, Einträge aller Modelle (überschreiben tree_oak, farmhouse, streetlight der Welle 0); `key_data` verträgt `source=None` (Bodendecker) |
| `tools/blender/ce3d/bake.py` | `Baker.ambient_occlusion()`, `bake_atlas(…, ao=…)` (Verdeckung zuletzt gebacken); ohne `ao` unverändert |
| `tools/blender/export_models.py` | `BUILDERS` und `COST` um bush/grass/building/lattice ergänzt |
| `tools/blender/validate_models.py` | Lackcode 0,875 (Rotor) zulässig; Sets mit `modern_only` ohne Sprite-Set zulässig (nur mit Modell) |
| `tests/unit/core/test_model_db.gd` | zählt `modern_only`-Sets getrennt |
| `tools/models/prop_scene.gd`, `prop_scene.sh` | neu (Prüfszene) |
| `assets/models/manifest.json` | neu erzeugt (`--manifest-only`) |
| `docs/modelle.md` | Abschnitt 14 angehängt |
| `cesprites/props_buildings.py` | `WINDOW_LOG` (Voreinstellung `None`), `boards3d` in `barn()` |
| `cesprites/props_road.py` | `hub_subdiv`, `lights3d`, `allround` (Tankstelle), Knoten `none` für `fs_haze`, `PYLON_LOG` |

Nicht angefasst: Shader (`baked`, `leaves`, `billboard` gehören R2; `vpbr`, `glass` R3), Arcade-Dateien, Sprites.

## 9. Abweichungen

- Variantenordner und Bodendecker liegen außerhalb der Ordnerliste von §5 (vom Auftrag verlangt, siehe 8.).
- Gebäude und Straßenmöbel haben nur `lod0` (Budget nennt „auto“ für lod1): Netze mit Lampenkanälen dürfen keine
  automatische Stufe haben (Auftrag; Nachtrag A-4 in §11); die Dreieckszahlen (≤ 1 640) machen eine Stufe unnötig
  (gefolgert).
- Die Windmühle behält gemalte Fenster am achteckigen Turm (der Schnitt kennt nur Wände entlang einer Achse);
  Scheune ohne Fenster (das Sprite hat keine).
- Das Fernbild der Varianten und die Varianten selbst zeigt der Kontaktbogen der Pipeline nicht (er geht über
  Sets; „fehlt“-Kacheln); gezeigt werden sie mit `tools/models/prop_scene.sh`.
- Das Prüfwerkzeug liegt in `tools/models/` (nicht neben `models_contact_sheet.sh` in `tools/`), damit es in der
  Dateihoheit bleibt.

## 10. Vertragsfragen

- **Rotor-Code**: Lackcode 0,875 + `UV2.y` = Nabenhöhe / 128 m ist eine Erweiterung von §4.6.4 (VPBR-L kennt nur
  0 / 0,25 / 0,5 / 1). Bitte als Nachtrag festhalten; die Drehung im `vpbr.gdshader` bei R3 bestellen.
- **`modern_only`-Sets** (Bodendecker) sind im Manifest-Schema §4.6.6 nicht vorgesehen; der Prüfer erlaubt sie
  jetzt (nur mit Modell).
- **Lampenkanal 12 bei Tag**: eine unbeleuchtete `vpbr`-Lampe zeigt 50 % (sRGB) ihrer Leuchtfarbe. Für
  Fensterscheiben ist das zu hell; ein Gewicht ohne Tagesanteil (oder eine Lampenrolle „Fenster“) wäre sauberer.
- **Straßenmöbel = 1 Aufruf** zwingt Lampen von Zapfsäule und Blitzer in den gebackenen Nachtlicht-Atlas (kein
  Kanal 12, keine Anker); für die Zapfsäule reicht das.
- **Leitungen zwischen Strommasten** kann kein Modell liefern (sie verbinden zwei Instanzen): Requisiten-Builder.
- Der Kontaktbogen (`contact_sheet.gd`) kann Varianten ohne eigenes Set nicht zeigen.
- **Tankstelle doppelt?** `props/fuel_station` und `props/fuel_pump` sind jetzt Sets mit Modell; der Bauplan gibt
  R6 (`station.gd`) Tankdächer, Säulen, Laden und Preissäule der Fahrspur. Zu klären, wer an der Tankstelle
  zeichnet: R6 nimmt diese Modelle als Bausteine, oder der Requisiten-Builder lässt die Sets dort aus.

## 11. Bedarf bei anderen Paketen

- **R3 (`vpbr.gdshader`)**: Rotordrehung (erprobter Code, siehe 6.: Winkel = `ce_time` · 1,35 rad/s + Phase aus der
  Instanzposition; Drehung von `VERTEX.xy` und `NORMAL.xy` um (0, Nabenhöhe)).
- **R2 (`leaves.gdshader`, `builders/props.gd`)**: Schnee (`ce_snow`: aufwärts gerichtete Karten weißen) und Nässe
  (`ce_wet`) für Laub; Varianten je Stück über `variants`; Bodendecker `props/cover_bush`, `props/cover_grass` in
  Kurven-Korridoren (`graphics.modern.props.bend_cover`) einsetzen; ferne Fernbilder wirken im Nebel als blasse
  graue Flecken, und in S1 standen helle Rauten am Horizont (vermutlich Kontaktschatten) – im R2-Stand prüfen.
- **R6**: Preissäule (`object:fuel_pylon`) und Tankstellendach der Fahrspur; im A/B fehlt das Dach (R6 noch nicht da).

## 12. A/B-Beobachtungen (S1 km 4,6 · S2 km 14,3 · S3 km 60,7, Mittag, Voreinstellung mittel)

- Alle Requisiten sind Modelle: Eichen, Birken, Büsche, Heuballen, Windräder, Tankstelle mit Zapfsäulen und Laden,
  Bauernhäuser in der Ferne.
- Die Bäume sind dunkler und feiner als die Sprites; nahe Eichen (S3) wirken wie echte Laubbäume mit sichtbaren
  Ästen.
- Im Modern-Bild fehlen (anderer Pakete): Spielerauto und Verkehr (R3), Leitplanken und Mittelstreifen (R1),
  Tankstellendach (R6).

## 13. Ehrliche Einordnung

- **Gut:** Die Bäume sind deutlich feiner als die Sprites (einzelne Blätter, Äste, Stamm, Birkenrinde), in
  natürlicherer, dunklerer Farbe, und die Stufen wechseln ohne sichtbaren Sprung. Das Bauernhaus hat echte Tiefe
  (Fenster mit Laibung und Rahmen, Tür, Rinnen, Schornstein, Verdeckung in den Ecken) und leuchtet nachts warm aus
  einzelnen Fenstern. Der Strommast liest sich bis 250 m als Gitter statt zu flimmern. Tankstelle und Zollhäuschen
  sehen bei Nacht stimmig aus (Lichtpfützen, helle Scheiben).
- **Noch nicht gut:** Von nahem (unter 25 m) wirkt die Baumkrone unruhig; einzelne flach angeschnittene Karten
  stehen als dunkle Schlieren, bei der Birke sieht man bei 15 m helle Astreste in der Krone. Die Klumpen sind
  weicher als die scharf schattierten Cycles-Kugeln der Sprites – wer die Sprites gewohnt ist, sieht weniger
  „Plastik“, aber auch weniger Form. Die Fernbilder (256 px) wirken bei 250 m im Nebel blass; ihr Eichenstamm ist bei 200 m etwa ein
  Pixel breiter und brauner als der von `lod1` (gemessen am Bild `stufen_baeume.png`, fünffach vergrößert). Gras als
  Bodendecker ist bei 15 m nur ein hellgrüner Fleck. Bei Nacht ist das Laub fast schwarz (kein Licht in der Krone
  außer dem Mond).
- **Fehlt:** Die Rotoren stehen still, bis R3 den `vpbr.gdshader` erweitert. Scheune ohne Fenster und Windmühlen-
  turm mit gemalten Fenstern. Schnee und Nässe auf Laub (R2). Das ganze Bild im Rennen mit allen Paketen habe ich
  nicht gesehen: Der A/B-Bogen stammt aus dem R2-Stand plus diesem Paket (ohne Autos, Leitplanken, Tankdach).

## 14. Bilder (dieser Ordner)

- `ab_S1_S2_S3.jpg` – A/B Arcade | Modern an S1–S3
- `kontaktbogen_tag.png`, `kontaktbogen_nacht.png` – alle Requisiten-Modelle, Anfahrt und Rückseite, alle Stufen
- `abstaende_vegetation.png`, `abstaende_bauten.png` – Spielkamera bei 15 / 40 / 100 / 250 m
- `stufen_baeume.png` – Stufen an den Umschaltentfernungen (60 m, 200 m)
- `strommast_abstaende.png` – Fachwerk bei 40 / 100 / 250 / 500 m
- `rotor_probe_t0_0.4_0.8.png` – Rotordrehung mit dem erprobten Shader-Zusatz (Wegwerfzweig)
- `arcade_sprites_vergleich.png` – die Arcade-Sprites derselben Sets zum Vergleich
