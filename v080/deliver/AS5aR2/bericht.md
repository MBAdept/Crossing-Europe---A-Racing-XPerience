# AS5aR2 – Nacharbeit der Stadthäuser nach der Kunstkritik KRITIK-5a2

- Zweig `worktree-wf_db8ba6cd-508-6`, gesichert als `origin/wip/v080-as5ar2`, Endstand **216ac5c**.
  Basis 3c5e37a (AS5a2, ff-only), Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-6`.
- Gegenstand: die Befunde K1–K10 der unabhängigen Kunstkritik von AS5a2 (zwölf Häuser `dutch`, `belgian`,
  `french`, `paris`, `swiss`) – jeder selbst nachgeprüft, die bestätigten hohen und mittleren behoben, die billigen
  niedrigen auch. Weil zwei Korrekturen in Formeln liegen, die beide Chargen teilen (Ladenlicht, Fernfenster), sind
  alle **23** Stadthäuser neu exportiert (Charge 1: `german`, `german_old`, `hanse`).
- Ablauf: der erste Lauf baute, exportierte und prüfte alles bis 047e10f (16.11.); nach einem Neustart der Maschine
  hat ein Nachfolger-Lauf (22.11.) die zwei Modern-Bilder angesehen, `modern-make` übernommen (89ccc33), die Ursache
  von K2 gemessen (Abschnitt 4, Doku 216ac5c) und diesen Bericht abgeschlossen.
- **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, Renn-Licht bzw. das Rennen selbst);
  **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte Grafikkarte, Steam Deck, Wirkung auf
  einen Menschen) oder gerechnet.

## 1. Ergebnis in Kürze

- **K1 (hoch) behoben:** Die Läden leuchten nachts so wie in Arcade. Am Pariser Eckhaus sind es 22,7 % warme Pixel im
  Erdgeschoss (Arcade 28,2 %, vorher 10,9 %), Farbe (233,193,135) gegen Arcade (250,215,157). Hinter dem Glas stehen
  Regale, Waren und Theken. Die Formel teilen beide Chargen, deshalb leuchten auch die Läden in Hamburg (Charge 1)
  doppelt so stark wie vorher. Bei Tag ändert sich nichts.
- **K3 (Gartenbaum) behoben:** Südhaus (588 Platzierungen) und Loire-Haus (209) haben eine Blattkrone aus Karten mit
  den AS3-Blattbüscheln. Die Karten liegen im Ausschneide-Atlas des Hauses, deshalb bleibt es bei zwei
  Zeichenaufrufen. lod1 zeigt dieselben Karten. Der Stufenwechsel ändert beim Südhaus 8,2 % der Pixel (vorher 16,4 %).
- **K4 teilweise:** lod1 der sechs Häuser mit Geländern zeichnet ohne Alpha-Test. Bei 100 m flimmert Haussmann mit
  0,3 % (vorher 1,0 %, Sprite 0,3 %). „Band zu dunkel“ ist abgelehnt (gegen die Füllfarbe ±4 Stufen).
- **K7 verbessert:** Die Geranien sind jetzt Polster.
- **K3 (Gartenmauer 15 px/m) abgelehnt:** Gemessen sind 32,1 px/m. Die Kritik hatte die Kronen gemessen.
- **K2 Ursache gefunden, im Modell nicht behebbar:** Die Fernfassaden bleiben blass. Der dunklere Innenring der
  Fernstufe änderte nichts (p10 bei 250 m −2…+1 Stufen). Die Diagnose zeigt: ohne Sonnenschatten bleiben die Modelle
  über 60–250 m gleich hell (−4…+3 %, Sprite −2…−5 %), mit den Schatten des Rennens werden sie +4…+29 % heller. Ursache
  ist das Ende der Echtzeitschatten, nicht die Mip-Kette – das gehört zum Renderer (R4/R7).
- **Neu und schlechter:** Die Blattkarten flimmern bei 100–150 m stärker als die alte Kugelkrone (Südhaus 1,0 / 1,5 %
  gegen 0,6 / 0,8 %).
- Alle 23 Stadthäuser sind neu exportiert. Fünf fremde Modelle kamen byte-gleich heraus, die Sprites sind
  unverändert (86/86).

## 2. Die Befunde der Kritik – selbst geprüft

| Befund | eigene Prüfung | Urteil |
|---|---|---|
| **K1** Schaufenster nachts dunkler (hoch) | Nachtatlas Haussmann: Ladenpixel R-Median 128–145 gegen 221 bei Wohnfenstern (8 bit, gemessen); Formel `_display_mat`: Licht im Mittel ≈ 0,25 × Lichtfarbe gegen 0,83 × bei Wohnfenstern (gerechnet); A/B Paris 22 Uhr nachgestellt (10,9 % gegen 28,2 % Fläche) | **bestätigt – behoben** |
| **K2** Fernfassaden blass, Fenster rosa-lila (mittel) | lodcol der Kritik nachgemessen (dieselbe Prüfszene); erster Verdacht (Innenring der Fernstufe) umgesetzt und widerlegt (p10 bei 250 m −2…+1 Stufen, ohne Nebel gleich); dann dieselbe Szene mit Schatten wie im Rennen / Reichweite 1 000 m / ohne Sonnenschatten: **ohne Schatten bleibt jedes Modell über 60–250 m gleich hell (−4…+3 %), p10 +1…+9 wie beim Sprite (+3…+11)** | **Erscheinung bestätigt, Zuordnung „Mip-Kette“ abgelehnt:** Ursache ist das Ende (Hoch 170–200 m, Mittel 102–120 m) und die grobe Auflösung der Echtzeitschatten – Renderer (R4/R7), im Modell nicht behebbar (Abschnitt 4) |
| **K3** Gartenbaum als Klumpen (mittel–hoch) | Nahansicht angesehen: facettierte Kugelkrone | **bestätigt – behoben** (Blattkarten) |
| **K3** Gartenmauer 14–16 px/m | Export-Bericht AS5a2: `ppm_road_min` 32,53 = 0,6 × 54,21 – die Mauer ist die einzige Straßenwand mit Gewicht < 1; GLB-Dreiecke der Probe: Mauer außen 0,60 × Packdichte, innen 0,18 ×, Abdeckung 0,30 ×; `texel_k5` misst mit `K5_OUTER` 4,5 m ab der Kronenkante (aabb x −12,8) alles links von x = −8,3 – die Mauer steht bei x = −7,5, gemessen wurden Krone, Stamm und Oleander (Gewicht 0,3 × 54 = 16) | **abgelehnt**: Mauer 32,1 px/m (Südhaus) / 29,9 (Loire-Haus), ≥ 26 |
| **K4** Geländer schließen sich in kleinen Mips, Bänder dunkler (mittel) | Deckung 1,16 / 1,55 / 1,96 / 2,74 (Haussmann) nachgemessen – das ist die Absicht von A-22 (`cut_fill`): die Lücken tragen die Farbe hinter dem Geländer, mit der Füllfarbe als Hintergrund bleibt die Bandhelligkeit in Mip 1–4 in ±4 Stufen (`mipband.py`, vier Modelle). Die −53 Stufen der Kritik rechnen mit hellem Stein hinter dem Balkon. Ausprobiert (nur am Atlas, nicht ausgeliefert): eine Lückenalpha je Geländerkarte, die die Deckung hält (Haussmann Mip 4 0,92 statt 2,74) – sie verliert die Dunkelheit des Bandes, weil die durchgelassenen Texel die Mischfarbe tragen. Flimmern bestätigt | **teilweise**: Flimmern in lod1 **behoben**; „Band zu dunkel / Deckung" **abgelehnt** |
| **K5** Stufenwechsel ohne Überblenden (mittel) | nachgemessen 9–18 % | Überblenden ist R7 (A-22); lod1-Helligkeit nachts unverändert gelassen |
| **K6** Sprossen/Rahmen flimmern (mittel) | Grachtenhäuser B nachgemessen 0,5–0,9 % | **teilweise**: gemalte Sprossen der Fernstufe dunkler; lod0-Sprossen sind Geometrie (Renderer: TAA/Mip-Bias) |
| **K7** Geranien als Perlenkette (niedrig) | angesehen | **bestätigt – verbessert** |
| **K8** Rückseiten Eckhaus blank (niedrig) | angesehen | nicht behoben (8 Platzierungen, nur in Kurven) |
| **K9** keine Wandleuchten (niedrig) | Arcade zeigt dort auch keine | nicht behoben |
| **K10** lod1 spart wenig (Südhaus 69 %) | – | **nicht verbessert**: Südhaus lod1 jetzt 67 % von lod0 – die Blattkarten liegen in beiden Stufen (sonst springt die Krone beim Wechsel); Tönung bleibt R7 (A-19) |

## 3. Was geändert ist (Code und Katalog)

| Datei | Änderung | Zweck |
|---|---|---|
| `tools/blender/ce3d/cities3d.py` | `_display_mat`: Lichtschicht = Lichtfarbe × Stärke × `PANE_LIGHT_K` × `SHOP_GLOW` 1,6 (war 1,25) × (0,3 + 0,75 × √Innenfarbe) (war 0,2 + 0,8 × Innenfarbe), dazu ein Deckenlicht-Band im oberen Viertel (+0,35) | K1: Läden nachts so hell wie Arcade, Auslage bleibt lesbar (nie eine flache weiße Fläche) |
| `tools/blender/ce3d/cities3d.py` | `_log_walls` reicht `inner_k` (`INNER_K` 0,75) und `bars_k` (`BARS_K` 0,35) an `wallmat` weiter | K2/K6: Innenring und gemalte Sprossen der Fernstufe zum Glas hin |
| `tools/blender/ce3d/cities3d.py` | `lod1_opaque`: lod1 zeichnet die Ausschneide-Teile als `baked` (Alpha-Test aus, Rückseiten-Culling) | K4: kein Flimmern der Schwelle in lod1, Geländer als Band |
| `tools/blender/ce3d/cities3d.py` | Blattkarten (lod0 und, mit `n1`, lod1): `_crown_logger`, `_leaf_cards`, `_leaf_setup`, `_leaf_reserve`, `_leaf_paste`, `_leaf_uv`, `_leaf_sheet`, `_scale_about`; `bake_city(leaf_px)` reserviert das Feld; `_finish_city(leaf)` klebt die Blattbüschel in den Atlas und legt die Karten in lod0 | K3: Gartenbaum als Blattkrone statt Steintraube |
| `tools/blender/ce3d/cities3d.py` | `_flower_shape` | K7: Geranien als Polster |
| `tools/blender/cesprites/props_cities.py` | `wallmat(..., inner_k=0.0, bars_k=0.0)` + `_toward` – nur wirksam mit `inner_frame` (nur der 3D-Bau setzt ihn) | Hook K2; Sprites unverändert (k = 0 gibt denselben Knotengraphen) |
| `tools/blender/ce3d/catalog3d.py` (Block `# --- AS5a ---`) | `lod1_opaque=True` für Mietshaus, Gründerzeit, Lyoner Haus, Haussmann, Eckhaus, Chalet; `leaf_cards` Südhaus und Loire-Haus mit denselben Karten in lod1 (`n1`, `half1`; Loire-Haus dafür `single_cutout`); `flower_shape` Chalet; kleinere `lod1_decimate` der Gartenkronen | Katalog |
| `assets/models/props/city_*/**` (23) | neu exportiert | |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) | |
| `docs/modelle.md` | Abschnitt 22, Stand-Zeile | Doku |

Geteilte Pipeline-Dateien (`core`, `glb`, `roles`, `bake`, `lod`, `manifest`, `export`, `export_models.py`,
`validate_models.py`, `tools/models/**`, `model_db.gd`) und `buildings3d.py` sind **nicht** geändert – die acht
AS4-Hausmodelle haben ihren Schlüssel behalten (byte-gleich ohne Neu-Export). Der Renderer ist nicht berührt.

## 4. Vorher / nachher je Befund (gemessen, wenn nicht anders gesagt)

### K1 – Schaufenster nachts (hoch): behoben

| Messung (`py/litpx.py`: warme Pixel r > 170, r ≥ g ≥ b, r − b > 50) | Arcade | vorher (AS5a2) | nachher |
|---|---|---|---|
| Paris km 387,9, 22 Uhr, Hoch, +2 s: Erdgeschoss Eckhaus (Kasten 740–1075 × 300–400) – Anteil | 28,2 % | 10,9 % | **22,7 %** (0,80 × Arcade) |
| dasselbe – mittlere Farbe (Luma) | (250,215,157) – 218 | (192,150,105) – 159 | **(233,193,135) – 197** |
| dasselbe, Wohnfenster darüber (740–1100 × 60–300) | 4,56 % | 3,86 % | 3,86 % (unverändert, wie gewollt) |
| +4 s, Ladenflanke rechts (880–1280 × 100–470) – Anteil | 24,2 % | 4,8 % | **9,4 %** |
| Charge 1, Gründerzeithaus 30 m, 22 Uhr (Prüfszene, Erdgeschoss) | – | 16,7 %, (186,143,96) | **31,7 %, (234,190,129)** |
| Charge 1, Kontorhaus 100 m / 250 m | – | 5,6 % / 3,0 % | **10,1 % / 9,0 %** |

Die Läden des Eckhauses erreichen 80 % der Arcade-Fläche und 90 % ihrer Helligkeit (Ziel der Kritik: Anteil ≥ 0,7 ×
Arcade, Ladenpixel 190–210 – erfüllt). An der Ladenflanke bei 4 s bleibt Modern bei 0,39 × Arcade: dort zeigt Arcade
die beleuchtete Flanke als große, zur Kamera gedrehte Bildfläche, Modern sieht die 35 cm tief liegenden Auslagen unter
spitzem Winkel hinter Laibung und Sprossen (Geometrie, nicht Helligkeit; angesehen). Bei Tag unverändert: die Auslage
bleibt hinter dem dunklen Glas (Nahansichten 12 Uhr angesehen, Nachtatlas wirkt nur über `ce_night`).

### K2 – Fernfassaden blass, Fenster rosa-lila (mittel): Ursache gefunden – Renderer, nicht Modell

**Erster Versuch (im Modell, ausgeliefert, wirkungslos gegen K2):** Innenring der Fernstufe 0,75 des Weges zum Glas,
gemalte Sprossen 0,35 (Atlas angesehen: Ring grau statt weiß). Dieselbe Prüfszene wie die Kritik
(`k6_scene --mode=lodcol`, Hoch, 12 Uhr): am dunklen Zehntel bei 250 m fast nichts.

| Modell | p10 lod0 60 m → lod1 250 m vorher | nachher | Sprite |
|---|---|---|---|
| Haussmann | 55 → 78 (+23) | 54 → 77 (+23) | 42 → 53 (+11) |
| Lauben | 56 → 81 (+25) | 54 → 80 (+26) | 56 → 58 (+2) |
| Maashaus | 61 → 83 (+22) | 59 → 81 (+22) | 64 → 70 (+6) |
| Südhaus | 65 → 83 (+18) | 66 → 81 (+15) | 59 → 63 (+4) |
| niederl. Reihenhäuser | 45 → 66 (+21) | 45 → 64 (+19) | 43 → 54 (+11) |
| Eckhaus | 66 → 84 (+18) | 65 → 82 (+17) | 44 → 59 (+15) |

**Diagnose (Nachfolger-Lauf, `k2diag.sh`, gemessen):** Die Modelle werden mit der Entfernung *heller* – das kann eine
Mip-Kette nicht (sie erhält den Mittelwert). Dieselbe Szene dreimal (Schatten-Reichweite über `--shadow_m`, nur im
Prüfwerkzeug), mittlere Helligkeit lod0 bei 60 → 250 m und dunkles Zehntel p10:

| Modell | Schatten wie im Rennen (200 m) | Reichweite 1 000 m | ohne Sonnenschatten | Sprite |
|---|---|---|---|---|
| Haussmann | 134 → 147 (+10 %), p10 +22 | 136 → 142 (+5 %), p10 +16 | 106 → 106 (−1 %), p10 +9 | 112 → 110, p10 +11 |
| Chalet | 75 → 96 (+29 %), p10 +23 | 76 → 83 (+8 %), p10 +10 | 71 → 70 (−1 %), p10 +4 | 74 → 70, p10 +3 |
| Lauben | 105 → 110 (+5 %), p10 +24 | 106 → 104 (−2 %), p10 +14 | 83 → 79 (−4 %), p10 +7 | 92 → 89, p10 +4 |
| Südhaus | 116 → 127 (+10 %), p10 +8 | 117 → 119 (+2 %), p10 +1 | 94 → 93 (−1 %), p10 +1 | 101 → 98, p10 +5 |
| Maashaus | 107 → 111 (+4 %), p10 +22 | 107 → 110 (+3 %), p10 +21 | 78 → 80 (+3 %), p10 +15 | 91 → 89, p10 +7 |

Ohne Sonnenschatten erfüllen vier von fünf Modellen das Abnahmekriterium der Kritik (Luma ±3 %, p10 ≤ +8 – Haussmann
+9 knapp, Maashaus +15 nicht). Die Fernblässe kommt also vom **Ende der Echtzeitschatten** (Hoch: Reichweite 200 m,
ausgeblendet ab 170 m; Mittel: 120 m, ab 102 m – daher „ab 100 m“ der Kritik) und von der **groben Auflösung der
letzten Schattenstufe** (mit 1 000 m Reichweite bleibt p10 +10…+21): jenseits davon fällt die Sonne voll auf
Laibungen, Arkaden, Balkon- und Traufschatten. Das Sprite hat seine Schatten eingebacken. Die „rosa-lila“ Fenster der
Lauben bei 250 m sind im Bild mit Rennschatten zu sehen, ohne Schatten sind sie grau (angesehen,
`k2_ursache_schattenreichweite.jpg`). Ohne Schatten ist das ganze Bild dunkler (vermutlich rechnet der
Kompatibilitäts-Renderer das Sonnenlicht dann in einem anderen Durchgang); verglichen wird nur der Verlauf über die
Entfernung. Im Modell ist das nicht zu beheben (stärkeres eingebackenes AO würde die Nahansicht doppelt abdunkeln);
Abhilfe im Renderer (notes_for_next). Bleibender Modellanteil: Maashaus p10 +15 gegen +7 ohne Schatten.

### K3 – Gartenbaum als Klumpen (mittel–hoch): behoben

Blattkarten statt facettierter Kugelkrone (Nahansicht angesehen, Lieferbild `gartenbaum_vorher_nachher.jpg`).
Kosten: Südhaus lod0 5 359 → 5 820 Dreiecke, lod1 3 716 → 3 916; Loire-Haus lod0 3 910 → 4 250, lod1 1 874 → 2 100;
Texturen im Archiv +24 bzw. +53 kB (Alpha-Kanal). Stufenwechsel bei 60 m (Mittel, 12 / 22 Uhr): Südhaus
8,2 / 4,3 % (vorher 16,4 / 7,8 %), Loire-Haus 8,6 / 6,0 % (11,9 / 7,8 %). Flimmern (Viertelpixel-Schritte, 40 / 60 / 100 /
150 m): Südhaus 0,9 / 0,9 / 1,0 / 1,5 % (vorher 0,4 / 0,4 / 0,6 / 0,8 %; Sprite 0,2 / 0,3 / 0,4 / 0,6), Loire-Haus 0,5 / 0,7 / 1,3 / 1,6 % (vorher
0,4 / 0,5 / 1,0 / 1,4 %) – die Blattkarten flimmern wie jede ausgeschnittene Laubkarte etwas mehr als die Kugelkrone.

### K4 – Geländer (mittel): Flimmern in lod1 behoben; „Band zu dunkel“ abgelehnt

| Flimmern (Anteil kippender Pixel) 40 / 60 / 100 / 150 m | vorher | nachher | Sprite |
|---|---|---|---|
| Haussmann | 1,0 / 1,2 / **1,0 / 0,6** % | 0,9 / 1,1 / **0,3 / 0,5** % | 0,0 / 0,2 / 0,3 / 0,4 % |
| Eckhaus | 1,1 / 1,2 / **1,0 / 0,7** % | 1,1 / 1,1 / **0,2 / 0,4** % | 0,1 / 0,2 / 0,2 / 0,3 % |
| Grachtenhäuser B | 0,7 / 1,0 / 0,6 / 0,9 % | 0,5 / 0,8 / 0,5 / 0,9 % | 0,1 / 0,2 / 0,2 / 0,4 % |
| Lauben | 0,3 / 0,4 / 0,3 / 0,5 % | 0,2 / 0,3 / 0,3 / 0,5 % | 0,1 / 0,1 / 0,2 / 0,3 % |

Ab der Stufe lod1 (60 m „Mittel“, 120 m „Hoch“) flimmern Haussmann und Eckhaus jetzt wie ihr Sprite. lod0 bei
40–60 m bleibt 5–10 × Sprite: Alpha-Test der Gitter in lod0 (A-22) und die geometrischen Rahmen und Sprossen (vpbr)
– das braucht TAA/Mip-Bias oder ein kürzeres lod0 im Renderer (R7, A-22 nennt `max_dist_m`).
Bandhelligkeit gegen die Füllfarbe (`mipband.py`, Mip 1–4): Haussmann +1,0 / +1,0 / +1,8 / −0,5, Lyon +1,2 / +0,9 /
+3,6 / +0,3, Südhaus +0,2 / −0,2 / −1,3 / −3,0, Chalet +0,1 / −0,5 / −0,6 / −3,0 Stufen.

### K5 – Stufenwechsel (R7) und K6 – Sprossen

Stufenwechsel bei 60 m „Mittel“, 12 Uhr (Anteil geänderter Pixel, Helligkeit), vorher → nachher: Haussmann
14,2 % / +0,1 → 16,5 % / −0,6; Eckhaus 13,3 / +0,3 → 15,2 / −0,4; Grachtenhäuser 18,3 / −0,3 → 17,7 / −2,6;
Grachtenhäuser B 17,5 / −0,5 → 17,0 / −1,9; Maashaus 16,2 / −0,1 → 15,9 / −1,6; niederl. Reihe 14,4 / +0,6 → 14,2 /
−0,4; Lyon 14,6 / +0,3 → 14,4 / −0,3; belg. Reihe 16,4 / +0,4 → 16,2 / −0,9; Chalet 14,9 / +0,6 → 13,0 / −0,3; Lauben
9,1 / +0,4 → 8,7 / −0,4. Nachts (22 Uhr): Haussmann +2,5 %, Eckhaus +2,6 %, Lauben +5,3 %, Lyon +4,6 % (vorher +3,0 /
+3,5 / +4,9 / +4,0). Der dunklere Innenring macht lod1 bei Tag 0,3–2,6 % dunkler als lod0; das Überblenden bleibt R7.

### K7 – Geranien (niedrig): verbessert

Kugeln längs des Kastens gestreckt und flach (angesehen, Lieferbild `geranien_vorher_nachher.jpg`): aus 10 m ein
niedriges, rot-grünes Polster statt einer Kette großer Kugeln; aus nächster Nähe noch als einzelne Tupfen lesbar.

### K10 – lod1-Ersparnis

Südhaus lod1/lod0: vorher 69 %, nachher 67 % – die Blattkarten liegen in beiden Stufen (mit weniger Karten in lod1 sprang die Krone beim Wechsel: 27,5 % bzw. 34,8 % der Pixel).

### Budgettabelle (alle 23 Stadthäuser, Endstand, gemessen; Export-Zeit auf dieser VM)

| Set | Dreiecke lod0 / lod1 | Klassen lod0 / lod1 | Atlas | px/m Straße min / Packdichte | Archiv Netze / Texturen | Export |
|---|---|---|---|---|---|---|
| `city_french_sud` | 5 820 / 3 916 | baked_cutout / baked_cutout | 1024×1024 | 32,1 / 53,5 | 145 / 418 kB | 169 s |
| `city_belgian_terrace` | 2 586 / 1 162 | baked / baked | 2048×1024 | 51,0 / 63,7 | 46 / 546 kB | 371 s |
| `city_french_maison` | 4 250 / 2 100 | baked_cutout / baked_cutout | 1024×1024 | 29,9 / 49,8 | 111 / 365 kB | 196 s |
| `city_french_immeuble` | 4 020 / 2 486 | baked_cutout / baked | 2048×1024 | 51,9 / 64,8 | 75 / 562 kB | 470 s |
| `city_dutch_terrace` | 3 346 / 1 060 | baked / baked | 1024×1024 | 46,3 / 46,3 | 73 / 286 kB | 158 s |
| `city_belgian_stone` | 1 336 / 278 | baked / baked | 1024×1024 | 43,7 / 54,6 | 21 / 268 kB | 114 s |
| `city_paris_haussmann` | 6 518 / 3 714 | baked_cutout / baked | 2048×1024 | 37,6 / 50,1 | 125 / 619 kB | 483 s |
| `city_swiss_chalet` | 3 109 / 1 280 | baked_cutout / baked | 1024×1024 | 53,4 / 53,4 | 56 / 282 kB | 126 s |
| `city_dutch_canal` | 3 734 / 1 802 | baked / baked | 2048×1024 | 40,0 / 50,0 | 77 / 628 kB | 328 s |
| `city_swiss_laube` | 4 865 / 942 | baked / baked | 2048×1024 | 35,0 / 43,8 | 70 / 567 kB | 253 s |
| `city_dutch_canal_b` | 3 625 / 1 545 | baked / baked | 2048×1024 | 37,9 / 47,4 | 69 / 691 kB | 311 s |
| `city_paris_corner` | 5 675 / 3 418 | baked_cutout / baked | 2048×1024 | 35,2 / 47,0 | 112 / 678 kB | 490 s |
| `city_german_house` | 2 962 / 1 406 | baked / baked | 1024×1024 | 60,0 / 60,0 | 80 / 254 kB | 142 s |
| `city_german_mietshaus` | 2 176 / 506 | baked_cutout / baked | 2048×1024 | 52,9 / 52,9 | 34 / 484 kB | 353 s |
| `city_german_gruenderzeit` | 4 410 / 2 394 | baked_cutout / baked | 2048×1024 | 40,8 / 54,4 | 76 / 560 kB | 315 s |
| `city_german_office` | 427 / 203 | baked / baked | 2048×1024 | 15,9 / 21,2 | 11 / 360 kB | 95 s |
| `city_german_old_fachwerk` | 7 084 / 1 050 | baked / baked | 2048×1024 | 34,1 / 42,7 | 102 / 524 kB | 692 s |
| `city_german_old_fachwerk_b` | 5 319 / 990 | baked / baked | 2048×1024 | 41,7 / 52,1 | 78 / 437 kB | 553 s |
| `city_german_old_barock` | 4 938 / 2 401 | baked / baked | 2048×1024 | 37,8 / 47,2 | 95 / 467 kB | 345 s |
| `city_hanse_gabled` | 4 882 / 1 240 | baked / baked | 2048×1024 | 33,5 / 41,9 | 80 / 671 kB | 324 s |
| `city_hanse_kontor` | 9 865 / 749 | baked / baked | 2048×1024 | 28,8 / 41,2 | 109 / 731 kB | 206 s |
| `city_hanse_speicher` | 8 950 / 1 283 | baked / baked | 2048×1024 | 29,8 / 42,6 | 114 / 744 kB | 344 s |
| `city_hanse_crane` | 1 260 / 1 052 | baked / baked | 1024×1024 | 90,0 / 90,0 | 39 / 116 kB | 46 s |

Charge 2: Netze 0,98 MB, Texturen 5,91 MB; Charge 1: Netze 0,82 MB, Texturen 5,35 MB (Archiv, deflate -9)

## 5. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Seed 11, Limousine, Autopilot, Verkehr eingeschwungen, fliegender Start mit 50 km/h, Bilder 2 s und 4 s nach dem Start.
Neun Läufe, alle Exit 0, 0 Zeilen `SCRIPT ERROR` / `Parse Error` / `ERROR:` in den Protokollen (gemessen).

| Lauf | Ort | Was man sieht (angesehen; Zahlen gemessen) |
|---|---|---|
| `rennen_pa_high_h22` | Paris km 387,5, Hoch, 22 Uhr | Bogenläden des Eckhauses hell und warm mit Waren hinter dem Glas (22,7 % warme Pixel gegen Arcade 28,2 %, vorher 10,9 %); Wohnfenster wie Arcade |
| `rennen_pa_high_h12` | Paris, Hoch, 12 Uhr | Haussmann-Flanke mit Bogenläden, Balkonen, Gittern; bei Tag unverändert gegen AS5a2 |
| `rennen_pa_medium_h19.5` | Paris, Mittel, 19:30 | Dämmerung: Läden beginnen zu leuchten, Fassaden lesbar |
| `rennen_be_high_h22` | Bern km 302,3, Hoch, 22 Uhr | Läden unter den Lauben leuchten; warmes Licht im Bild 2,9 / 3,7 % (vorher 2,0 / 2,7 %, Arcade 5,2 / 5,0 %) |
| `rennen_am_high_h12` | Amsterdam km 357,3, Hoch, 12 Uhr | Grachtenhäuser wie vorher (bei Tag unverändert) |
| `rennen_ly_out_high_h12` | Lyon-Vorort km 285,6, Hoch, 12 Uhr | Südhäuser mit Blattkrone statt Kugeltraube |
| `rennen_hh_high_h22` | Hamburg km 88,2 (Kiel – Hamburg), Hoch, 22 Uhr | Charge 1: Giebelhäuser und Läden nachts; der weiße Laden in der Mitte ist AS4s `building_shop` (nicht diese Charge) |
| `rennen_br_medium_h19.5` | Brüssel km 195,5, Mittel, 19:30 | Lütticher Reihe und Maashaus in der Dämmerung, Café-Licht |
| Clip `fahrt_paris_50kmh.mp4` | Paris ab km 387,6, Hoch, 12 Uhr, 50 km/h, 10 s, 60 fps | Haussmann-Flanke zieht mit Läden und Balkonen vorbei; Arcade zeigt dort eine flache Fassade (Standbilder `fahrt_paris_50kmh_standbilder.jpg`) |

Nicht den Modellen anzulasten (unverändert gegen die Kritik): In den Vororten fehlen in Modern die niedrigen
Garten- und Backsteinmauern der Szenerie (`fence`, Bauer `city` von R6) und einzelne Bäume (Kurvenkorridor, FIX-M2
B-01) – beides ist im Zusammenbau RINT-M2.

## 6. Gates (Endstand 216ac5c; Befehle und Ausgaben in `m1/AS5aR2/logs/`)

Die Gates liefen auf 047e10f (alle Modelle, Code und Katalog wie im Endstand). Danach kamen nur noch die neuen
Modern-Hashes (89ccc33, nach `modern-make`) und ein Doku-Absatz (216ac5c) dazu; beide liest kein Test (`grep` in
`tests/` und `tools/run_tests.sh`: `modelle.md` nur in Kommentaren, `modern_slice` nur in `tools/golden.sh`).

| Gate | Befehl | Ergebnis |
|---|---|---|
| Prüfer | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (Netze 19,81 MB von 40, Texturen 79,37 MB von 240 im Grafikspeicher) |
| Budgettabelle | `py/budget_r2.py` (Abschnitt 4 / docs Abschnitt 22) | alle 23 ≤ 10 000 Dreiecke lod0, 2 Aufrufe je Stufe |
| Sprite-Geometrie | `check_sprite_geometry.py --only props --jobs 1` | 86 von 86 identisch, `CHECK sprite_geometry OK` (kein „ANDERS“) |
| Cache-Schlüssel | `export_models.py --check-keys` | `CHECK cache_keys OK` (110 Modelle) |
| Determinismus | zweiter erzwungener Export + Bake von Südhaus (Blattkarten), Chalet (Geranien), Maashaus | alle drei **BYTEGLEICH** (Ordner- und GLB-Hash vorher = nachher; `git status` 0 Dateien) |
| fremde Modelle | Brückenlampe, Pylon, Pylon ohne Seile, Fachwerkbogen, Hausboot neu exportiert (Schlüssel enthält `props_cities.py`) | byte-gleich (`git status` 0 Dateien); AS4-Häuser: Schlüssel unberührt (kein geteilter Code geändert) |
| Rennen in Modern | `tools/ab_shot.sh` an fünf Ankünften (Paris, Bern, Amsterdam, Brüssel, Hamburg) + Lyon-Vorort, Hoch und Mittel, 12 / 19:30 / 22 Uhr | 9 Läufe Exit 0, 0 Fehlerzeilen |
| Tests | `tools/run_tests.sh` | 749 Tests, 0 fehlgeschlagen, alle Prüfsuiten `CHECK … OK`, `==> Tests bestanden` (894 s) |
| Arcade | `tools/golden.sh check` | 20 von 20 und 17 von 17 identisch (`arcade-ui`) |
| Modern-Goldens | `tools/golden.sh modern-check` | 4 von 6 identisch, GLES-Prüfung OK; `modern_s4_mittel` und `modern_s5_niedrig` (Kiel – Hamburg, Einfahrt Hamburg, 12 Uhr) wichen ab, weil dort Charge-1-Häuser stehen (Innenring der Fernstufe neu). Beide Bilder **angesehen** (Giebel-, Kontor- und Speicherhäuser bei Tag, keine Löcher, kein Flackern, HUD unverändert), dann `tools/golden.sh modern-make`, Commit 89ccc33 |
| Archivanteil | Rechnung von `tools/pck_report.py` (deflate -9 je Datei, ohne Build: `py/share.py`) | Charge 2: 0,98 MB Netze, 5,91 MB Texturen (Grenze 3 / 7 MB); Charge 1: 0,82 / 5,35 MB |

## 7. Ehrliche Einordnung

**Was der Spieler jetzt sieht (angesehen, Zahlen gemessen, Wirkung auf einem echten Bildschirm gefolgert):**

- **Nachts leben die Ladenstraßen.** In Paris leuchten die Bogenläden des Eckhauses auf 23 % der Erdgeschossfläche
  (Arcade 28 %, vorher 11 %), warm und hell (Luma 197 gegen Arcade 218, vorher 159), und hinter dem Glas stehen
  Regale mit Waren, Kleiderstangen und Theken – keine weiße Fläche. In Bern leuchten die Läden unter den Lauben, die
  Gasse hat 40–46 % mehr warmes Licht als vorher. Die Gründerzeit-Läden und das Kontorhaus in Hamburg (Charge 1)
  leuchten ebenso doppelt so viel wie vorher. Die Wohnfenster sind unverändert (wie Arcade).
- **Der häufigste Gartenbaum ist ein Baum.** Südhaus (588 Platzierungen) und Loire-Haus (209) haben statt der Traube
  facettierter Steine eine Blattkrone aus Karten mit AS3-Blattbüscheln in den Farben des Generators, im Sonnenlicht
  rund schattiert; lod1 zeigt dieselben Karten, deshalb springt die Krone beim Stufenwechsel nicht (Südhaus 8,2 % geänderte Pixel statt 16,4 %).
- **Pariser Schmiedeeisen ab 60 m ruhig.** In lod1 flimmern Haussmann und Eckhaus wie ihr Sprite (0,2–0,5 %), die
  Geländer sind dort ein gemaltes Band ohne Alpha-Test; die Fassade wird mit Rückseiten-Culling gezeichnet.
- **Geranien** als niedrige Polster statt Perlenkette.

**Was noch nicht gut ist:**

- **Fernfassaden bleiben blass (K2, im Modell nicht behebbar).** Ab der Schattenreichweite (Mittel 100–120 m, Hoch
  170–200 m) werden die Fassaden 4–29 % heller und die Fenster blass (dunkles Zehntel bei 250 m +8 bis +24 Stufen
  gegen +2 bis +15 beim Sprite). Gemessen ist jetzt die Ursache: das Ende und die grobe Auflösung der Echtzeitschatten
  (ohne Sonnenschatten bleiben die Modelle über 60–250 m gleich hell, die Fenster hellen wie beim Sprite nur um 1–9
  Stufen auf; Ausnahme Maashaus +15). Der Innenring-Eingriff war wirkungslos. Im Rennen bei Dunst und Gegenlicht
  schwächer (Kritik: Paris und Bern lesen sich fern gut); die Abhilfe gehört in den Renderer.
- **Flimmern in lod0 bei 40–60 m** bleibt 5–10 × Sprite bei Haussmann und Eckhaus (0,9–1,1 % gegen 0,0–0,2 %):
  Alpha-Test der Gitter (A-22) und geometrische Sprossen/Rahmen. Die Blattkarten flimmern beim Südhaus bei 40 / 60 /
  100 / 150 m mehr als die alte Kugelkrone (0,9 / 0,9 / 1,0 / 1,5 % gegen 0,4 / 0,4 / 0,6 / 0,8 %; Sprite 0,2–0,6 %),
  beim Loire-Haus 0,5 / 0,7 / 1,3 / 1,6 % (vorher 0,4 / 0,5 / 1,0 / 1,4 %) – der Preis der ausgeschnittenen Blätter, wie
  bei jedem AS3-Kartenbaum. Abhilfe ist Sache des Renderers (Alpha-to-Coverage/TAA, Mip-Bias) oder eines kürzeren lod0.
- **Stufenwechsel** tauschen weiter 9–17 % der Pixel (Südhaus jetzt 8,2 % statt 16,4 %); Überblenden bleibt R7.
- **Ladenflanken unter spitzem Winkel** (Paris +4 s): 9 % warme Pixel gegen 24 % in Arcade – die tief liegenden
  Auslagen verschwinden hinter Laibungen; Arcade zeigt die Flanke als zur Kamera gedrehte Bildfläche.
- Unverändert: Rückseiten des Eckhauses blank (K8, 8 Platzierungen), keine Wandleuchten (K9), Tönung der Reihenhäuser
  im Ruhrgebiet fehlt bis R7 (A-19 erlaubt sie jetzt über die MultiMesh-Farbe), die Gegenseiten der Grachtenhäuser
  grob (12–15 px/m, „reused walls on the far side“).

**Was fehlt:** Messungen auf echter Grafikkarte und auf dem Steam Deck (alles hier llvmpipe), der Blick eines Menschen
auf die Blattkarten in Bewegung.

## 8. Für die nächsten Pakete und die Leitung

1. **R4/R7 – Fernfassaden (K2).** Ursache gemessen (Abschnitt 4): das Ende der Echtzeitschatten (Hoch 170–200 m,
   Mittel 102–120 m) und die grobe letzte Schattenstufe, nicht die Mip-Kette. Vorschlag: jenseits der Reichweite den
   gerichteten Anteil auf Gebäuden um einen mittleren Schattenanteil senken (z. B. eine eingebackene
   Sonnen-Sichtbarkeit je Texel oder ein fester Faktor je Set) oder ab ≈ 200 m ein Fernbild mit eingebackenen Schatten
   (A-16). Nachweis mit `k6_scene --mode=lodcol` (liegt in `m1/AS5aR2/kt`, Schalter `--shadow_m`). Im Modell bleibt nur
   das Maashaus (p10 +15 gegen +7 ohne Schatten); ein dunkleres Glas im Atlas würde die Nahansicht mit abdunkeln.
2. **R7 – Flimmern in lod0 (40–60 m):** Haussmann und Eckhaus flimmern 0,9–1,1 % gegen 0,0–0,2 % beim Sprite. Ursache
   sind der Alpha-Test der Gitter und die geometrischen Sprossen. Die Blattkarten von Südhaus und Loire-Haus flimmern
   1,0–1,6 % bei 100–150 m. Abhilfe: Alpha-to-Coverage oder TAA, Mip-Bias, oder ein kürzeres lod0 über `max_dist_m`
   (A-22).
3. **R7 – Überblenden** der Stufen auch für `city`. Bei 60 m ändern sich 8–17 % der Pixel. Dazu die Tönung der Instanzen
   (A-19): 50 niederländische Reihen im Ruhrgebiet mit `#ead6cc`, Kontaktbogen `toenung_reihenhaeuser_ruhr.jpg`.
4. **Vertragsfrage (offen seit KRITIK-5a2, Frage 1):** Ein Stadthaus darf zwei Zeichenaufrufe haben. Deshalb liegen die
   Blattkarten im Ausschneide-Atlas des Hauses, und das Loire-Haus wird jetzt ganz in `baked_cutout` gezeichnet (ohne
   Culling, mit `discard`; Kosten auf echter Grafikkarte gefolgert). Mit drei Oberflächen (`baked` + `baked_cutout` +
   `vpbr`) oder einem Anbau-Mechanismus für AS3-Bäume im Requisiten-Bauer wäre das sauberer. AS5b braucht die
   Entscheidung für die mediterranen Gärten.
5. **Ladenflanken unter spitzem Winkel:** Paris +4 s zeigt 9 % warme Pixel gegen 24 % in Arcade. Grund ist die
   Geometrie: die Auslage liegt 35 cm tief hinter der Laibung, Arcade zeigt dort eine zur Kamera gedrehte Fläche. Ein
   flacheres `shop_depth` an Flanken wäre möglich, ist aber eine Geschmacksfrage. Es ist nicht geändert.
6. **Niedrig, offen:** Rückseiten des Haussmann-Eckhauses (K8), Wandleuchten an Eingängen (K9). Das Bürohaus von
   Charge 1 hat an der Straßenwand nur 15,9 px/m (unverändert seit AS5a1, unter 26).
7. **Werkzeuge:** Die Prüfhilfen (`tools/kritik`, nie committet) liegen in `m1/AS5aR2/kt` und `py`. Neu sind
   `py/glbtex.py` (Texeldichte je Dreieck aus einer GLB), `py/lodcmp.py` (Fernbild vorher/nachher),
   `py/budget_r2.py` (Budgettabelle) sowie `py/pair.py` und `py/stack.py` (Vergleichsbilder).

## 9. Bilder und Film (dieser Ordner)

| Datei | Inhalt |
|---|---|
| `paris_nacht_vorher_nachher.jpg` | Paris 22 Uhr: Arcade, Modern vorher (AS5a2), Modern nachher – Läden des Eckhauses |
| `charge1_laeden_nacht.jpg` | Charge 1 (Gründerzeithaus, Kontorhaus) 22 Uhr, vorher / nachher, dieselbe Kamera |
| `gartenbaum_vorher_nachher.jpg` | Südhaus und Loire-Haus von der Straßenseite: Kugelkrone vorher, Blattkarten nachher |
| `geranien_vorher_nachher.jpg` | Chalet: Geranien vorher / nachher |
| `rennen_<ort>_<stufe>_h<uhr>_00/01.jpg` | A/B im Rennen (Abschnitt 5): Paris Hoch 12 / 22 Uhr und Mittel 19:30, Bern 22 Uhr, Amsterdam 12 Uhr, Lyon-Vorort 12 Uhr, Hamburg 22 Uhr, Brüssel Mittel 19:30 |
| `fahrt_paris_50kmh.mp4`, `fahrt_paris_50kmh_standbilder.jpg` | 10-s-Clip, 50 km/h, 60 fps, Paris, Hoch, 12 Uhr; Standbilder 1 / 3 / 5 / 8 s |
| `nahansichten_<stil>_mittag/nacht.jpg` | Straße / schräg / vorn, lod0, Hoch, 12 und 22 Uhr (französisch, belgisch, niederländisch, schweizerisch, Paris) |
| `spielkamera_<stil>_mittag/daemmerung/nacht.jpg` | Spielkamera 10 / 30 / 100 / 250 m, darunter das Arcade-Sprite |
| `spielkamera_charge1_nacht.jpg` | Gründerzeit, Mietshaus, Kontor bei 22 Uhr |
| `kontaktbogen_charge2_tag/nacht.jpg`, `kontaktbogen_charge1_tag/nacht.jpg` | alle 23 Modelle, lod0 und lod1 |
| `stufen_G1/G2/G3_mittag/nacht.jpg` | Stufenwechsel bei 60 m (Mittel), lod1 bei 200 m, Sprite |
| `flimmern_messbild.jpg` | Flimmermessung 40 / 60 / 100 / 150 m |
| `fernbild_250m.jpg` | Südhaus, Haussmann, Lauben bei 60 und 250 m (lod0 / lod1 / Sprite) – K2 nicht behoben |
| `k2_ursache_schattenreichweite.jpg` | K2-Diagnose: Haussmann, Chalet, Lauben bei 60 und 250 m mit den Schatten des Rennens, mit 1 000 m Reichweite, ohne Schatten, Sprite |
| `umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera (IoU 0,945–0,999) |
| `toenung_reihenhaeuser_ruhr.jpg` | Tönung `#ead6cc`: Modell, Modell × Tönung, Sprite getönt, Sprite |
