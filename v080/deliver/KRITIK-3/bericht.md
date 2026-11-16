# KRITIK-3 – Unabhängige Kunstkritik von AS3 (Vegetation und Natur)

- Gegenstand: Zweig `worktree-wf_aad8d49e-fb4-1`, Stand **be866d2** (nur gelesen). Gerendert und gemessen in einer
  Kopie im Arbeitsordner (`m1/KRITIK-3/tree`: der Arbeitsbaum samt eigenem Import-Cache, ohne `build/`, `_cache3d`,
  `.git`). Keine Commits, kein Zweig, keine Datei des Arbeitsbaums geändert.
- Modelle: 18 Bäume (Eiche, Birke, Buche, Pappel, Olive, Kiefer, Fichte, Zypresse, Palme, je mit `_b`), `bush_round`
  / `_b`, `bush_low`, `heather`, `rock_a`, `rock_b`, `cliff`; `cover_bush` / `cover_grass` nur nebenbei.
- **gemessen** = auf dieser VM gemessen (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader `leaves`,
  `billboard`, `vpbr`, `baked` über `ModelFactory`/`PropLibrary`, das Renn-Licht des `EnvironmentRig`);
  **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte GPU, Steam Deck, Wirkung auf einen
  Menschen) oder aus Code und Maßen abgeleitet.
- Licht der Prüfbilder: `prop_scene --look=race` von AS3 (Palette der Stunde, Nebel, Schatten, Voreinstellung
  „Mittel“). Geprüft, dass es das Rennen zeigt (die Falle der Fahrzeug-Kritik): das Rennen setzt auf `leaves` keine
  Klassen-Parameter, das Fernbild nutzt in beiden die Standardwerte von `billboard.gdshader`, die Stand-in-Sprites
  dieselben `STANDIN_*`-Werte, und den `vpbr`-Look der Fahrzeug-Ebene setzt `prop_scene` erst, nachdem das Material
  existiert (Code gelesen). Dazu neun Rennbilder mit `tools/ab_shot.sh` (Abschnitt 4): Farben und Formen stimmen mit
  den Prüfbildern überein (angesehen). Nachtbilder der Prüfszene sind **ohne** Scheinwerfer, das Rennbild bei Nacht mit.

## 1. Die Antwort für den Nutzer

**Frage: Sind die Modelle sichtbar feiner als die Arcade-Sprites und gut genug, um stundenlang daran vorbeizufahren?**

- **Ja für die meisten Bäume.** Im Rennen (Kiel–Hamburg, Hamburg-Innenstadt, Pappelallee in der Lombardei,
  Sauerland-Wald an der Stelle des Leistungstests, Mittelmeer; Bilder 01, 15, 18) sind Eiche, Buche, Pappel, Fichte,
  Kiefer und Olive deutlich feiner als ihre Sprites: laubige Kronen mit Sonnen- und Schattenseite, Nadelzweige,
  echte Schlagschatten, und sie stehen, wo Arcade sie zeigt.
  - Umriss lod0 in der Sprite-Kamera 0,8–9 % außerhalb des Sprites (gemessen, Bild 04).
  - Kein Glitzern bei 120 km/h: Viertel-Pixel-Test 0,75–1,65× so viel wie das Sprite (gemessen), Film angesehen.
  - Ruhige Kronen aus der Nähe, keine Kartenkanten aus keiner von 8 Drehungen (angesehen).
  - Ferne Bäume verblassen im Nebel genau wie die Sprites (angesehen, Bild 17).
  - Nachts im Rennen gleich hell wie Arcade (Ausschnittsmittel innerhalb von 2 Grauwerten, gemessen).
  - Die Mängel von AS1b (Kartenstreifen, unruhige Krone, helle Aststummel, blasse Fernbilder) sind behoben.
- **Drei Dinge sind gröber als das Sprite** und gehören vor die Spieler repariert:
  1. **Birkenstamm** (M1): bis etwa 40 m ein Schachbrett aus schwarzen und weißen Dreiecken. 88 Birken stehen in den
     ersten 75 km Kiel–Hamburg neben der Fahrbahn. Eine Stunde Arbeit in `_bark_colour`.
  2. **Palme** (M8): dünne, stehende Wedel, ein gestreifter heller Pfahl. Umriss 20 % (`_b` 57 %) außerhalb des
     Sprites (gemessen).
  3. **Klippe** (M2): Der Props-Bauer dreht sie zufällig. Von hinten sieht man zerrissene Lappen, von der Seite ein
     dünnes Horn (Rennbild von AS3, Lyon–Bern km 148,7).
- **Mittlere Mängel:**
  - Nahe Kronen unter 25 m (Stadtbäume, Steam Deck) enden in geraden Vieleck-Kanten (M3).
  - Büsche sind unter 40 m facettierte Brocken (M4).
  - Fernbilder verlieren 30–80 % Kontrast und 5–19 % Sättigung gegen lod1 (gemessen, M5).
  - Ganze 96-m-Abschnitte wechseln die Stufe auf einmal (M6).
  - Flache Pflanzen und Felsen schweben am Hang (M7, Props-Bauer).
  - Die Vegetation belegt schon 35,6 der 60 MB Archiv-Texturbudget, 15,8 MB davon doppelt (M9).
- **Empfehlung:**
  - Eiche, Buche, Pappel, Fichte, Kiefer, Olive, Zypresse, Büsche, Heide und Felsen können in den Testbuild.
  - Den Birkenstamm vor dem Kiel–Hamburg-Build reparieren (AS1b hatte denselben Stamm; AS3 ist also nicht
    schlechter, nur nicht besser).
  - Palme und Klippe in die Nacharbeit (M2) – Süden und Berge sind nicht im ersten Testbuild.

| Modell | gegen das Sprite | im Rennen bereit | was es trägt | was es kostet |
|---|---|---|---|---|
| Eiche (+ `_b`) | **feiner** | ja | Blattwerk, Licht/Schatten je Kuppel, Äste, Schlagschatten; Umriss 2 % außen | Kuppel-Unterkanten < 25 m, kleine Himmelslöcher, `_b` zwei Zweige oben (M3) |
| Birke (+ `_b`) | Krone feiner, **Stamm gröber** | **nein** (Stamm) | lichte Krone, weißer Stamm aus der Ferne | Schachbrett-Stamm (M1); Fernbild blass, Sättigung −19 % (M5) |
| Buche (+ `_b`) | **feiner** | ja | breite, dichte Krone, glatter grauer Stamm | als Stadtbaum in 6–10 m die Kuppelkanten (M3) |
| Pappel (+ `_b`) | **feiner** | ja | Laubsäule, die Allee liest sich | Fernbild flach, Kontrast −48 % (M5) |
| Olive (+ `_b`) | **feiner** ab 40 m | ja | silbergrau, knorrig, im Rennen schöner als das Sprite | unter 20 m Tarnmuster (M10) |
| Kiefer (+ `_b`) | **feiner** | ja | Waldkiefer wie das Sprite: hoher oranger Stamm, flache Polster | flimmert in 80–150 m 1,4–1,7× so viel wie das Sprite (M11) |
| Fichte (+ `_b`) | **feiner** | ja | Nadelzweige, Etagen, dunkler Kegel; im Leistungstest-Bild klar besser | Fernbild ohne Etagen, Kontrast −65 %, nachts +26 % (M5) |
| Zypresse (+ `_b`) | gleich | ja | glatte dunkle Flamme wie das Sprite | eine Windphase für die ganze Krone (M11) |
| Palme (+ `_b`) | **gröber** | **nein** | Fiedern, Ringstamm aus der Nähe | dünne, stehende Wedel, gestreifter heller Pfahl, Umriss 20 / 57 % außen (M8) |
| Busch rund (+ `_b`), niedrig | gleich | ja | im Rennen dunkle, laubige Klumpen | unter 40 m facettierte Brocken, blasser (M4); schwebt am Hang (M7) |
| Heide | gleich | ja | lila Flecken mit Blütentextur | schwebt am Hang (M7) |
| Fels a / b | gleich | ja | echte Facetten, Moos, Risse | schwebt am Hang (M7) |
| Klippe | von vorn gleich, gedreht **gröber** | **nein** | Schichten und Sträucher wie das Sprite | Rückseite zerrissen, von der Seite ein Horn, Zacken am Grat (M2) |

## 2. Wie geprüft wurde

- **Werkzeuge**: nur in der Kopie, nie eingecheckt; aufbewahrt unter `m1/KRITIK-3/tools_kritik/` (in eine Kopie des Baums nach `tools/kritik/` legen; erbt von `tools/models/prop_scene.gd`) und `m1/KRITIK-3/py/`.
  - `prop_scene.sh` von AS3: Spielkamera (D12: 3,4 m, Brennweite 711 px, 1280 × 720, MSAA wie „Mittel“) in 15 / 40 /
    100 / 250 m, das Arcade-Sprite als Stand-in am selben Ort, um 12, 19:30 und 23 Uhr (18 Bögen). Dazu
    `--mode=lods` (Stufenwechsel) und `--mode=clip` (2 s, 120 km/h, 120 Bilder).
  - `kritik_scene.gd`, eigener Zusatz, der von `prop_scene.gd` erbt. Modi:
    - `turn`: das Modell in 8 Drehungen (Kartenkanten, Rückseiten).
    - `slope`: Boden 30° geneigt, der Fuß 4× vergrößert.
    - `sparkle`: Viertel-Pixel-Schritte; gemessen wird der Anteil kippender Pixel, Modell gegen Sprite.
    - `outline`: orthografische Sprite-Kamera mit 6° wie `cesprites/props.py`; Umriss von lod0, lod1 und Fernbild
      gegen den Alpha-Umriss des Sprites, ohne dessen eingebackenen Bodenschatten.
    - `under`: Nahsicht wie bei Stadtbäumen 3,5 m neben der Fahrbahn.
    - `levels`: alle Stufen an den Umschaltentfernungen mit Helligkeit, **Sättigung** und **Kontrast** (Streuung der
      Helligkeit über die inneren Pixel).
  - `vertex_data.gd`: Winddaten, Normalen und Fußtiefe aus den gebackenen Netzen.
  - Zensus der Strecken mit `stage_sets.gd` von AS1b, um eine Liste je Set erweitert.
- **Rennbilder** mit `tools/ab_shot.sh` (Arcade | Modern aus demselben Simulationszustand) an neun Stellen
  (Abschnitt 4). Dazu die zehn Rennbilder von AS3 angesehen.
- **Prüfer** gelaufen (`validate_models.py --report`, Abschnitt 5.1).
- **Rahmen der Läufe:** alles mit `nice -n 19`, immer nur ein schwerer Lauf, `XDG_DATA_HOME` absolut im Arbeitsordner.
  Etwa 45 min Render-Zeit bei einer Maschinenlast von 7–12 (gemessen).

## 3. Mängelliste – sortiert nach dem, was der Spieler am meisten sieht

Zuständig: **AS3-N** = Nacharbeit der Modelle (`ce3d/veg3d.py`, `veg3d_shapes.py`, `rock3d.py`, `leafatlas.py`,
Katalog), **R2/R7** = Props-Bauer (`builders/props.gd`, `prop_library.gd`) und die Shader `leaves` / `billboard`.
Bilder in diesem Ordner.

### M1 – hoch – Birkenstamm als Schachbrett (AS3-N) – Bild `06_M1_birkenstamm_schachbrett.jpg`
- **Wo:** jede Birke (`tree_birch`, `_b`), lod0 und lod1, sichtbar bis etwa 40 m. Kiel–Hamburg setzt 88 Birken in
  den ersten 75 km 5–22 m neben die Fahrbahn (Zensus AS1b); dazu Heide, Küste, Ostsee, Osteuropa, Stadtränder.
- **Was:** schwarze und weiße **Dreiecke** im Wechsel – eine Farbe je Dreieck (`_bark_colour(birch=True)` färbt nach
  dem Mittelpunkt jedes Dreiecks, Ringe alle 0,25 m, 6 Segmente aus `_birch_trunk`). Aus 12–15 m ein
  Schachbrett-Pfahl, im Fuß 4× sind es Dreiecke (angesehen). Das Sprite zeigt weiße Rinde mit feinen grauen
  Querstrichen. AS1b hatte dieselbe Bauweise („schwarze Marken je Dreieck“) – AS3 hat sie nicht verbessert.
- **Fix:** Farbe je **Viereck** (beide Dreiecke eines Ringsegments gleich) und Marken als **dünne Querbänder**: je
  Marke einen Zusatzring 4–7 cm über dem Ring einziehen und nur dieses schmale Band über 1–3 Segmente schwarz färben
  (Anteil ≈ 10–12 %), unten mehr und breiter (die Fußschwärzung bleibt). Kostet nur an den Marken Dreiecke (≈ 100–150).

### M2 – hoch (Alpen, Pyrenäen) – Klippe von hinten zerrissen, von der Seite ein Horn (R2/R7 + AS3-N) – Bild `05_M2_klippe_drehung_rueckseite.jpg`
- **Wo:** `props/cliff` in `alps` (alle 120 m, Chance 0,4) und `pyrenees` (160 m, 0,4), 8–30 m neben der Fahrbahn.
- **Was:** Der Props-Bauer dreht jedes Set der Klasse `rock` zufällig (`props.gd _place`: `yaw = hash01(…) * TAU`;
  die Klippe hat `kind: rock`). Das Modell ist eine verschobene, verdickte Wand: aus 6 von 8 Drehungen sieht man die
  dünne Rückseite, die oben in Fetzen ausläuft, oder ein schmales „Horn“ (angesehen, 8 Drehungen in 45°-Schritten). Im
  Rennbild von AS3 (Lyon–Bern km 148,7) steht dieses Horn dort, wo Arcade die Klippenwand zeigt. Eine quer gestellte
  Klippe (26 m lang) reicht bis 13 m näher an die Fahrbahn als ihr Anker – bei Ankern ab 16 m neben der Fahrbahn bis
  auf etwa 3 m (gefolgert aus Zensus und Maßen; nicht im Rennen gesehen).
- **Fix:** (a) R2/R7, sofort: ein Kennzeichen im Manifest (Tag `face_road`), solche Modelle nur um ±20° drehen –
  das Gesicht zur Straße wie das Sprite; (b) AS3-N: den Grat schließen (Kamm ≥ 1,5 m dick) und die Rückseite als
  geschlossene, schräge Felsflanke bis zum Boden bauen (gleicher Atlas, Moos oben), damit eine Klippe in einer Kehre
  auch von hinten Fels zeigt; vor der Dezimierung glätten (die dunklen Zacken am Grat, Bild 11).

### M3 – mittel – nahe Kronen: gerade Kuppel-Unterkanten, Himmelslöcher (AS3-N) – Bilder `09_M3_kuppelraender_nah.jpg`, `01_rennen_kiel_hamburg_eiche_busch.jpg`, `15_rennen_stadt_pappel_fichte.jpg`
- **Wo:** alle Laubbäume unter etwa 25 m: die Eichen am Rand von Kiel–Hamburg (147 in 75 km), die Stadtbuchen 1,2–1,8 m
  hinter dem Bordstein in jeder Innenstadt (Maßstab 0,5–0,65), Bäume an Kurven-Innenseiten.
- **Was:** Oben ist die Krone feiner als das Sprite (Blattwerk statt glatter Kugeln, angesehen). Die unteren und
  seitlichen Kuppeln enden aber in geraden 6- bis 12-eckigen Kanten („Lampenschirm“); im Rennbild auf dem Steam Deck
  (Kiel–Hamburg km 54,9, ohne Baumschatten) ist die nahe Eiche ein Haufen facettierter Kuppeln. Dazu kleine helle
  Himmelslöcher zwischen zwei Kuppeln (Eiche 40 m, Stadtbuchen im Rennen) und zwei dünne Zweige, die oben aus der
  Krone von `tree_oak_b` stehen (angesehen).
- **Fix:** die Verfeinerung in `_dome_plan` nach **Sichtbarkeit von der Straße** gewichten (Kuppeln mit nach unten
  oder seitlich zeigender Achse zuerst auf (1, 6, 12, 12) bzw. einen Ring mehr), den äußeren Ring stärker zerfransen
  (Winkel ±0,35 Schritt, Radius ±12 %, jede zweite Randecke 5–10 % nach unten: hängendes Laub statt Kante), den Kern
  bis an die Kuppelränder ziehen (Löcher), Astteile außerhalb der Kuppelhülle (0,9) kappen.

### M4 – mittel – Büsche unter 40 m: facettierte „grüne Felsbrocken“ (AS3-N) – Bild `08_M4_buesche_facetten.jpg`
- **Wo:** `bush_round` / `_b`, `bush_low` in 15–40 m; `bush_round` steht auf Kiel–Hamburg 76-mal in 75 km, 2–12 m neben
  der Fahrbahn; Loire, Mittelmeer, alle Stadtränder.
- **Was:** 19–25 Kuppeln in 396 Dreiecken = Fächer aus 5–6 Ecken: Umriss aus geraden Kanten, darauf ein Muster mit
  hellen Einzelblättern (Tarnmuster), blasser als das Sprite (Sättigung 0,34 gegen 0,42 in 200 m, gemessen). lod1 in
  100 m zeigt ein dunkles Loch. **Im Rennen** (Kiel–Hamburg km 54,9, Hoch und Deck) wirkt der Busch dagegen als
  dunkler, laubiger Klumpen und stört nicht (angesehen).
- **Fix:** die kleinsten Ballen des Generators zusammenfassen (≤ 12 Kuppeln), dafür Ringe (1, 8) und für die
  größten (1, 8, 16); Atlas `sat` 0,58 → ≈ 0,72 und weniger helle Einzelblätter; lod1-Kern größer.

### M5 – mittel – Fernbild flach und blass (AS3-N, Schalter bei R2/R7) – Bild `12_M5_stufen_fernbild_flach.jpg`
- **Wo:** jeder Baum jenseits 200 m (Mittel/Deck) bzw. 350 m (Hoch) – in der Norddeutschen Tiefebene die meisten
  sichtbaren Bäume; Fichtenwälder.
- **Was (gemessen, innere Pixel, lod1 → Fernbild in 200 m, Mittag):** Kontrast **−30 … −80 %**, Sättigung −5 … −19 %
  (Birke −19 %, Fichte −18 %, Olive −15 %); Dämmerung bis −37 % Sättigung; nachts Helligkeit bis +26 % (Fichte) und
  Farbton +10 … +19°. Das Arcade-Sprite am selben Ort hat bei jeder Art mehr Kontrast als das Fernbild (+14 … +290 %). Angesehen: die Birke
  wird ein blasser graugrüner Fleck, die Fichte ein Kegel ohne Etagen. Ursache: das Fernbild trägt nur Albedo ×
  Eckhelligkeit; `billboard.gdshader` gibt der ganzen Fläche ein einziges Sonnenmaß. Im fernen Nebel verblasst es
  dagegen genau wie das Sprite (gemessen/angesehen 300–850 m, Bild `17_fernbild_im_nebel.jpg`) – der Mangel von AS1b
  („blasse graue Flecken“) ist behoben.
- **Fix:** das Fernbild **wie das Sprite backen** (Cycles mit Sonne und Himmel des Sprite-Rigs `cesprites/rig.py`,
  `SUN_DIR`) und mit dem Gesetz der Stand-ins zeigen (`baked_light` 1, `STANDIN_SUN`): Kennzeichen im Manifest
  (`impostor.baked_light: true`), R2/R7 setzt es. Fichte: die Etagen nicht weichzeichnen; Palme 512 px.

### M6 – mittel – Stufenwechsel: Blattmuster springt, eine ganze Reihe auf einmal (R2/R7 + AS3-N)
- **Wo:** jeder Baum an der Umschaltentfernung (Mittel/Deck 60 m, Hoch 120 m) und am Übergang zum Fernbild.
- **Was:** bestätigt: lod0 → lod1 ändert 68 % (Eiche, Birke), 61 % (Fichte), 35 % (Palme) der Baumpixel um mehr als
  ≈ 5 Grauwerte, lod1 → Fernbild 68–99 % (gemessen, `prop_scene --mode=lods`, wie AS3). Helligkeit bleibt (±5 %).
  Nicht im Bericht von AS3: der Props-Bauer wählt die Stufe **je Chunk** (96 m; `_apply_lod` nach der nächsten Reihe
  des Chunks) – alle Bäume eines Chunks wechseln im selben Bild, auch die 150 m entfernten, rund alle 3 s bei 120 km/h
  (gefolgert aus dem Code).
- **Fix:** R2/R7: beim Wechsel 0,3–0,5 s mit komplementärem Dither überblenden wie die Fahrzeugstufen von RINT-B
  (`XFADE_S`; `leaves` und `billboard` bräuchten eine `fade`-Instanzvariable wie `vpbr`). AS3-N: lod1 behält den
  äußeren Ring jeder Kuppel aus lod0 (gleiche Eckenzahl und Zufallsverschiebung – heute zieht `rng` je Stufe andere
  Werte) und vergröbert nur das Innere.

### M7 – mittel (Hänge) – Heide, Büsche und Felsen schweben an der Talseite (R2/R7, Kennzeichen von AS3-N) – Bild `07_M7_hang_30grad.jpg`
- **Wo:** flache, breite Pflanzen und Felsen am Hang: `heather` (5,6 m breit, Fuß −0,17 m), `bush_low` (5 m),
  `bush_round`, `rock_a` / `rock_b`; `cover_grass` steht auf 0,00 m.
- **Was:** Auf 30° Hang stehen alle Bäume sauber (Stammfuß 0,55–0,70 m im Boden, gemessen; reicht bis etwa 57°,
  gefolgert). Die Talseite der Heide liegt aber rund 1,4 m über dem Boden (gefolgert aus Breite und Neigung,
  angesehen), Busch und Felsen zeigen eine Lücke mit Schatten darunter. Der Props-Bauer stellt jedes Modell aufrecht
  auf die Bodenhöhe des Ankers.
- **Fix:** R2/R7: Pflanzen der Klasse `plant` an die Bodennormale kippen (wie der Kontaktschatten, `SLOPE_PROBE_M`),
  Felsen auf die tiefste Bodenhöhe unter ihrer Grundfläche setzen; AS3-N: Manifest-Kennzeichen (`ground: "align"` /
  `"sink"`), Heide und Büsche mit einer Randschürze bis −0,4 m, `cover_grass` −0,1 m.

### M8 – mittel (Süden) – Palme gröber als das Sprite (AS3-N) – Bild `10_M8_palme.jpg`, `00_alle_arten_40m_gegen_sprite.jpg`
- **Wo:** Mittelmeer (alle 70 m, 4–15 m neben der Fahrbahn), spanische Stadtränder und Innenstädte (1,2–1,8 m hinter
  dem Bordstein).
- **Was (gemessen):** Umriss lod0 20 % außerhalb des Sprites, Sprite nur zu 69 % gedeckt; `palm_b` 57 % außerhalb,
  Überdeckung mit der Grundart 0,31 (ihr Stamm ist gerade, das Sprite krumm). Laub nur zwischen 8,4 und 10,8 m Höhe:
  die Wedel stehen und hängen kaum, im Sprite breite, hängende Wedel. Fernbild Farbton −16° gegen lod1, das Sprite am
  selben Ort +18 % heller. Angesehen: dünne Wedel, der Stamm ein regelmäßig gestreifter, heller und warmer Pfahl
  (zwei Farben im Wechsel je 0,24 m); nachts im Fernbild ein heller Strich.
- **Fix:** Wedel breiter (Halbbreite 0,55 → ≈ 0,8 m) und hängend (Absenkung −1,6 t² → ≈ −2,8 t², Anhebung kleiner),
  die Form aus `SHAPE_LOG["fronds"]` treuer übernehmen; Stamm dunkler (Paar ≈ #4e4234 / #5f5141), Ringe als ±8 %
  Helligkeit statt zweier Farben; `palm_b` mit der Krümmung des Sprites (nur andere Saat); Fernbild 512 px.

### M9 – mittel (Pipeline) – Texturbudget: Vegetation belegt 35,6 von 60 MB (AS3-N + PIPE)
- **Was (gemessen):** ganzer Satz 37,1 MB Texturquellen von 60 MB (`validate_models.py --report`), davon AS3 35,6 MB;
  15,8 MB sind byte-gleiche Atlanten der `_b`-Varianten (`cmp tree_oak/leaves.png tree_oak_b/leaves.png`: gleich).
  Gebäude, Städte und Wahrzeichen (AS4–AS6, Atlanten bis 2048 × 1024) kommen noch.
- **Fix:** Atlas der Grundart im `model.json` der Variante referenzieren (Bake + ModelDB) → −15,8 MB; Laubatlanten der
  selteneren Arten (Olive, Zypresse, Palme, Kiefer) 512² (ein Laubball von 128 px reicht ab 25 m).

### M10 – niedrig – Olive aus der Nähe als Tarnmuster (AS3-N) – Bild `11_kleinere_maengel.jpg`
- Unter 20 m stark kontrastierende helle Flecken (Blattunterseiten, `underside_share` 0,3); ab 40 m schön silbergrau.
  Fix: Anteil 0,15, Unterseitenfarbe näher an der Oberseite.

### M11 – niedrig – Kleinkram (AS3-N)
- Zypresse: eine einzige Windphase für die ganze Krone und keine nach oben zeigenden Normalen (gemessen:
  1 Phase, 0 %) – für Wind und einen Schnee-Term je Ring variieren bzw. nach oben kippen. (Die dünne Spitze über der
  Flamme hat das Sprite auch – kein Mangel.)
- Kiefer: Stamm oben kräftig orange, im Sprite dunkler orange-braun (angesehen, Bild 00); im Fernbild ab 80 m flimmert
  die Kiefer 1,4–1,7× so viel wie ihr Sprite (gemessen, Bild 13) – die dünnen Polster.
- Fernbild der Olive: Stamm in 1,5 m nur 0,67 m breit gegen 0,83 m (lod1) und 1,04 m (Sprite) (gemessen).
- `bush_round` lod1: dunkles Loch (Bild 08).

## 4. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern, gleicher Simulationszustand)

Alle neun Läufe: Exit 0, 0 Zeilen `ERROR`/`SCRIPT ERROR` im Modern-Log, 228–322 s je Lauf (gemessen).
Rohbilder in `m1/KRITIK-3/ab/`.

| Stelle | Voreinstellung, Stunde | Was dort steht | Urteil (angesehen) |
|---|---|---|---|
| Kiel–Hamburg km 53,9 → 54,9 | Hoch, 12 Uhr | Eiche in etwa 25 m, Busch, Birken, Windräder, Eichen bis 600 m | Modern feiner: Blattwerk, Tiefe, Schatten. Laub der nahen Eiche: Helligkeit 94,9 gegen 100,3, Sättigung 0,50 gegen 0,49 (gemessen, Ausschnitt) |
| dieselbe Stelle | Steam Deck, 1280 × 800 | ohne Baumschatten | Die nahe Eiche zeigt die Vieleck-Unterkanten ihrer Kuppeln (M3) – sichtbar, nicht störend |
| dieselbe Stelle | Mittel, 19:30 | Abendlicht | gleichwertig, Modern etwas satter grün |
| dieselbe Stelle | Mittel, 23 Uhr | Scheinwerfer | gleichwertig: Bäume dunkle Silhouetten wie in Arcade (Ausschnittsmittel 20,7/35,2/38,6 gegen 20,5/34,2/40,6, gemessen) |
| Kiel–Hamburg km 92,2 → 92,8 (City Limits Hamburg) | Hoch, 12 Uhr | Buchen am Straßenrand | Modern feiner; vereinzelt helle Himmelspunkte in den Kronen (M3) |
| Mailand–Venedig km 60 (Lombardei) | Hoch, 12 Uhr | Pappelallee, Zypresse | Modern feiner, die Säulen lesen sich als Pappeln |
| Dortmund–Frankfurt km 121 (Szene „Autobahn bei Tag“ des Leistungstests) | Hoch, 12 Uhr | Fichtenwald, Buchen | Fichten deutlich feiner (Nadelzweige statt glatter Etagen); innen in der Kurve fehlt der Waldrand (F7, Props-Bauer) |
| Lyon–Bern km 143,3 → 144,3 (Alpen) | Hoch, 12 Uhr | Fichten, Klippen km 144,0 / 145,2 | Fichten gut; beide Klippen fehlen in Modern, weil sie im Kurvenkorridor liegen (Props-Bauer, wie AS3 berichtet) |
| Barcelona–Montpellier km 42 → 43 (Mittelmeer) | Hoch, 12 Uhr | Olive in etwa 20 m, Palme in 60 m, Zypressen | Olive silbergrau und feiner als das Sprite; Palme dünner und heller, in 60 m noch tragbar; Zypressen gleich |

Dazu die Rennbilder von AS3 angesehen: Heide km 47 (Heide, Birke, Kiefer – gut), Pyrenäen km 152 (Kiefer, Felsen –
gut), Alpen km 148,7 (Klippe als Horn – M2).

## 5. Zahlen

### 5.1 Prüfer, Budget, Aufrufe, Bytes, Stufenentfernungen (gemessen)

`validate_models.py --report`: `46 Modelle, 182 Sets (51 mit Modell, 131 Platzhalter)`, `Netze 5.23 MB von 40 MB,
Texturen 37.37 MB im Grafikspeicher von 240 MB, Quellen 37.10 MB von 60 MB`, `CHECK models OK`.

| Modell | Dreiecke je Stufe (Manifest-Entfernung) | Aufrufe | Netze | Texturquellen |
|---|---|---|---|---|
| tree_oak / _b | 2465 / 887 · 2475 / 885 | 2 / 2 / 1 | 65 / 66 kB | 1906 / 1905 kB |
| tree_birch / _b | 2304 / 673 · 2400 / 723 | 2 / 2 / 1 | 54 / 56 kB | 1960 / 1961 kB |
| tree_beech / _b | 2471 / 888 · 2462 / 889 | 2 / 2 / 1 | 64 / 64 kB | 1939 / 1951 kB |
| tree_poplar / _b | 2470 / 888 · 2470 / 886 | 2 / 2 / 1 | 68 / 67 kB | 1911 / 1912 kB |
| tree_olive / _b | 2295 / 828 · 2190 / 791 | 2 / 2 / 1 | 59 / 56 kB | 2067 / 2064 kB |
| tree_pine / _b | 1693 / 592 · 1970 / 688 | 2 / 2 / 1 | 41 / 47 kB | 2103 / 2105 kB |
| tree_spruce / _b | 1062 / 462 · 858 / 378 | 2 / 2 / 1 | 57 / 46 kB | 1272 / 1267 kB |
| tree_cypress / _b | 1236 / 316 · 1236 / 316 | 2 / 2 / 1 | 40 / 40 kB | 1704 / 1694 kB |
| tree_palm / _b | 1184 / 714 · 1184 / 714 | 2 / 2 / 1 | 26 / 26 kB | 705 / 704 kB |
| bush_round / _b, bush_low | 396 / 111 · 396 / 117 · 395 / 115 | 1 / 1 | 12 kB | 435 kB je |
| heather | 390 / 118 | 1 / 1 | 13 kB | 445 kB |
| rock_a / rock_b / cliff | 640 / 960 / 4341 (auto) | 1 | 11 / 17 / 88 kB | 141 / 164 / 866 kB |

- Alle im Budget §4.6.9 (Baum ≤ 2 500 / 900, ≤ 450 Karten, 2/2/1; Busch/Heide ≤ 400 / 120, 1; Fels 1 500, Klippe
  6 000, 1). Fernbilder 92–256 × 180–512 px. Summe der 27 Modelle: Netze 1,14 MB, Texturquellen 35,6 MB (M9).
- Stufenentfernungen: im Manifest 60 / 200 m; der Props-Bauer nimmt die der Voreinstellung (Niedrig 40 / 120,
  Mittel und Steam Deck 60 / 200, Hoch 120 / 350 m) **je Chunk** (96 m) mit 6 m Hysterese (Code gelesen, M6).
- Zur Sprite-Kamera passen alle Größen (`object` = Sprite-Manifest, Prüfer).

### 5.2 Umriss gegen das Sprite (gemessen, orthografisch 6° wie die Sprite-Kamera, 24 px/m, ohne Boden)

| Art | lod0 außerhalb / Sprite gedeckt | lod1 | Fernbild | Variante `_b` | Überdeckung Grundart ↔ `_b` |
|---|---|---|---|---|---|
| Eiche | 2,0 % / 98,5 % | 0,9 / 94,0 | 3,5 / 98,2 | 9,1 / 83,5 | 0,77 |
| Birke | 3,9 / 96,3 | 1,6 / 90,2 | 4,4 / 96,4 | 18,8 / 79,8 | 0,68 |
| Buche | 0,8 / 98,3 | 0,3 / 93,4 | 0,9 / 97,4 | 7,7 / 92,0 | 0,85 |
| Pappel | 5,6 / 98,5 | 3,7 / 94,1 | 5,3 / 98,8 | 14,3 / 87,3 | 0,75 |
| Olive | 2,2 / 98,6 | 1,1 / 94,8 | 3,7 / 96,5 | 10,2 / 84,6 | 0,77 |
| Kiefer | 3,0 / 95,9 | 1,2 / 91,2 | 4,6 / 93,0 | 17,3 / 84,1 | 0,73 |
| Fichte | 9,0 / 88,9 | 5,8 / 86,9 | 7,9 / 87,3 | 10,0 / 77,4 | 0,74 |
| Zypresse | 0,8 / 96,5 | 0,8 / 94,6 | 0,9 / 96,4 | 0,9 / 73,7 | 0,75 |
| Palme | **20,0 / 69,3** | 18,4 / 65,4 | 20,1 / 65,9 | **57,1 / 38,5** | **0,31** |
| Busch rund / niedrig | 5,3 / 91,7 · 5,1 / 91,4 | 4,2 / 80,2 · 4,1 / 80,9 | – | 12,0 / 85,9 | 0,82 |
| Heide · Fels a · Fels b · Klippe | 0,4 / 87,2 · 0,5 / 90,2 · 0,0 / 94,0 · 1,0 / 99,5 | | | | |

Bild `04_umrisse_lod0_gegen_sprite.png`. Die Grundarten liegen im Sprite-Umriss (außer Palme); die Varianten sind
deutlich anders (Überdeckung 0,68–0,85, Buche am wenigsten), `palm_b` verlässt die Sprite-Form.

### 5.3 Stufen: Helligkeit, Sättigung, Kontrast (gemessen, `levels`, innere Pixel, Mittel)

Mittag, Sprung lod0 → lod1 in 60 m: Helligkeit −3,1 … +4,2 %, Sättigung ±3 %, Kontrast −8 … +20 % (Pappel +19,5 %).
lod1 → Fernbild in 200 m:

| Art | Mittag: Helligkeit / Sättigung / Kontrast | Dämmerung 19:30 | Nacht 23 Uhr (Helligkeit / Farbton) |
|---|---|---|---|
| Eiche | −3,0 / −8,8 / −32 % | −3,4 / −14,0 / −19 % | −1,2 % / +14° |
| Birke | +3,7 / **−19,2** / −38 % | +4,4 / −17,5 / −17 % | +8,7 % / +19° |
| Buche | +3,7 / −7,5 / −31 % | +2,9 / −11,4 / −12 % | +6,4 % / +11° |
| Pappel | −2,6 / −8,4 / −48 % | −4,4 / −13,9 / −36 % | −1,7 % / +12° |
| Olive | +2,2 / −14,9 / −44 % | +3,8 / −11,1 / −29 % | +3,5 % / +15° |
| Kiefer | +1,1 / −5,1 / −35 % | +1,2 / −7,1 / −20 % | +8,3 % / +2° |
| Fichte | **−8,2** / −17,7 / **−65 %** | +6,1 / **−33,6** / −66 % | **+25,7 %** / +14° |
| Zypresse | −2,0 / −5,2 / −48 % | +3,9 / −25,5 / +10 % | +19,4 % / +10° |
| Palme | −4,0 / +12,8 / −70 % (Farbton −16°) | −0,2 / −9,2 / −68 % | +10,0 % / −17° |

Arcade-Sprite gegen Fernbild am selben Ort, Mittag: Helligkeit −8,8 … +17,9 % (Palme: das Sprite ist heller), Kontrast
beim Sprite +14 … +290 % höher; Dämmerung: Sprite 10–22 % dunkler (Modern-Bäume abends heller, wie AS3 gemessen hat). Die
`_b`-Varianten liegen in denselben Bereichen (Rohdaten `logs/levels_h*.log`).

### 5.4 Flimmern (gemessen, `sparkle`: Anteil der Modellpixel, die bei ¼-Pixel-Verschiebung um > 20 % kippen)

| | 40 m | 80 m | 150 m |
|---|---|---|---|
| Eiche Modell / Sprite | 0,7 / 0,6 % | 1,6 / 1,1 | 2,8 / 2,0 |
| Birke | 1,2 / 1,6 | 3,1 / 3,1 | 6,0 / 5,4 |
| Pappel | 0,9 / 0,9 | 2,3 / 1,9 | 4,5 / 3,4 |
| Fichte | 1,8 / 1,1 | 2,9 / 2,1 | 5,0 / 3,8 |
| Kiefer | 1,9 / 1,9 | **6,1 / 3,7** | **10,5 / 7,5** |
| Palme | 4,1 / 5,5 | 10,5 / 8,4 | 13,9 / 12,4 |

Das Alpha-Laub kippt kaum mehr als das Sprite-Stand-in (Faktor 0,8–1,6); Kiefer und Fichte in 80–150 m am meisten.
Bewegt angesehen: siehe Abschnitt 4.

### 5.5 Was die Netze tragen (gemessen, `vertex_data.gd`)

- Wind `COLOR.r` steigt mit der Höhe (Eiche 0,17 → 0,86 in fünf Höhenbändern, Pappel 0 → 0,85); Palmwedel nach dem
  Abstand vom Ansatz (Spitzen 1,0); Steifheit Laub 0,55, Pappel 0,35, Fichte 0,70, Zypresse 0,75, Palme 0,15, Kern
  1,0; 45–51 Phasen je Laubbaum, Palme 12, **Zypresse 1**; Stämme `vpbr` ohne Wind; Fernbild ohne Wind (Shader).
- Normalen nach oben (y > 0,5): Laubbäume 28–38 %, Fichte 59–63 %, Palme 100 %, Heide 50–55 %, **Zypresse 0 %**.
- Stammfuß y −0,55 … −0,70 m, Fels a −0,51, Klippe −1,19, Büsche −0,09 … −0,31, Heide −0,17, `cover_grass` 0,00.
- Nichts leuchtet (Klassen `leaves`, `vpbr`, `baked`; keine Emission).

## 6. Was gut ist

- **Die Arten lesen sich als ihr Sprite:**
  - Waldkiefer mit orangem Stamm und flachen Polstern, wie ihr Sprite (keine Schirmkiefer).
  - Fichte als dunkler Kegel, Pappel als Säule, Zypresse als glatte Flamme.
  - Olive silbergrau und knorrig, Buche breit mit glattem grauem Stamm, Birke weißstämmig.
  - Heide als lila Flecken.
  - Umriss lod0 bei 8 von 9 Arten 0,8–9 % außerhalb des Sprites (gemessen).
- **Volumen ohne Aufkleber:**
  - Jede Kuppel hat eine Sonnen- und eine Schattenseite, das Innere und die Unterseite sind dunkler.
  - Aus keiner der 8 Drehungen ein Kartenstreifen, keine hellen Aststummel (angesehen).
  - Damit sind die Mängel von AS1b in der Krone behoben.
- **Ruhig in Bewegung:**
  - Kein Glitzern, Pixel kippen 0,75–1,65× so oft wie beim Sprite (gemessen).
  - Folgebilder bei 120 km/h ruhig: Durch die Fahrt selbst ändern sich im Fernbereich je Bild 3,0 % der Pixel um mehr
    als 50 Stufen, höchstens 4,9 % – kein Bild springt heraus (gemessen); kein Aufblitzen (angesehen, Bild 14).
- **Fernbild im Nebel** wie das Sprite, keine blassen Flecken mehr (Bild 17).
- **Am Hang:** Bäume stehen auf 30° Hang sauber, der Stammfuß reicht 0,55–0,70 m in den Boden (gemessen).
- **Varianten** sind im Umriss klar verschieden: Überdeckung Grundart zu `_b` 0,68–0,85 (gemessen).
- **Daten für Wind und Schnee sind brauchbar:**
  - Ausschlag nimmt mit der Höhe zu; Stämme starr; Palmwedel am lebhaftesten (Steifheit 0,15); Fernbild ohne Wind.
  - Normalen zeigen nach außen und oben (Laubbäume 28–38 % nach oben, Fichte 59–63 %).
  - Nichts leuchtet.
- **Pipeline:** Budgets, Aufrufe 2/2/1 und der Prüfer sind grün. Das Werkzeug `prop_scene --look=race` von AS3 zeigt
  wirklich das Renn-Licht; seine Bilder sind belastbar.

## 7. Bilder in diesem Ordner

| Datei | Inhalt |
|---|---|
| `00_alle_arten_40m_gegen_sprite.jpg` | alle 15 Arten in 40 m (Klippe 100 m) neben ihrem Sprite, Mittag – der schnellste Überblick |
| `01_rennen_kiel_hamburg_eiche_busch.jpg` | Rennen Kiel–Hamburg km 54,9: Hoch und Steam Deck, Eiche, Busch, Birke |
| `02_arten_mittag_1…6_*.jpg` | jede Art und Variante in 15 / 40 / 100 / 250 m, darunter das Sprite am selben Ort (Mittag) |
| `03_daemmerung_*.jpg`, `03_nacht_*.jpg` | dasselbe für Eiche/Birke und Palme/Busch um 19:30 und 23 Uhr |
| `04_umrisse_lod0_gegen_sprite.png` | Umriss lod0 in der Sprite-Kamera über dem Sprite-Umriss, alle 18 Bäume |
| `05_M2_klippe_drehung_rueckseite.jpg` | Klippe in 8 Drehungen und im Rennen (M2) |
| `06_M1_birkenstamm_schachbrett.jpg` | Birkenstamm aus 15 m, 12 m und im Fuß 4× (M1) |
| `07_M7_hang_30grad.jpg` | 10 Modelle auf 30° Hang, Fuß 4× (M7) |
| `08_M4_buesche_facetten.jpg` | Büsche aus 15 / 40 m gegen das Sprite, lod1-Loch (M4) |
| `09_M3_kuppelraender_nah.jpg` | Krone aus 15 m von unten (M3) |
| `10_M8_palme.jpg` | Palme in allen Entfernungen, Umrisse, Innenstadt-Nahsicht (M8) |
| `11_kleinere_maengel.jpg` | Olive nah (M10), Klippengrat (M2), Himmelsloch (M3) |
| `12_M5_stufen_fernbild_flach.jpg` | lod0 / lod1 in 60 m, lod1 / Fernbild / Sprite in 200 m (M5, M6) |
| `13_flimmern_subpixel.jpg` | Viertel-Pixel-Test Modell gegen Sprite, 40 / 80 / 150 m |
| `14_clip_baumreihe_120kmh.mp4`, `14_clip_folgebilder.jpg` | 2 s Fahrt mit 120 km/h an Baumreihen, vier Folgebilder |
| `15_rennen_stadt_pappel_fichte.jpg` | Rennen: Hamburger Stadtbuchen, Pappelallee, Fichtenwald |
| `16_rennen_kurvenkorridor_leer.jpg` | Rennen: in Kurven fehlen Waldrand und Klippen (Props-Bauer, F7) |
| `17_fernbild_im_nebel.jpg` | Fernbild und Sprite in 300–850 m im Renn-Nebel |
| `18_rennen_mittelmeer.jpg` | Rennen Barcelona–Montpellier km 43: Olive, Palme, Zypressen |

## 8. Hinweise an andere Pakete und an die Leitung

1. **R2/R7 – Felsen nicht frei drehen:** Die Klippe (und jede Wand mit Schauseite) braucht ein Manifest-Kennzeichen
   und höchstens ±20° Drehung (M2). Eine quer gestellte 26-m-Klippe kann außerdem bis etwa 3 m an die Fahrbahn reichen
   (gefolgert) – auch für F7 prüfen: der Korridor wird nur am Anker gefragt.
2. **R2/R7 – Stufenwechsel:**
   - Die Stufe wird je 96-m-Chunk gewählt; eine ganze Baumreihe springt im selben Bild.
   - `leaves` und `billboard` haben keine Überblendung wie `vpbr` (RINT-B `XFADE_S`).
   - Vorschlag: Dither-Überblendung über 0,3–0,5 s (M6).
3. **R2/R7 – Hang:** Pflanzen an die Bodennormale kippen, Felsen auf den tiefsten Bodenpunkt ihrer Grundfläche setzen
   (M7).
4. **R2/R7 – Fernbild mit eingebackenem Licht:** Ein vorgerendertes Fernbild (Sprite-Rig) mit `baked_light` wie die
   Stand-ins würde Kontrast und Sättigung des Sprites halten (M5). Das Kennzeichen liefert AS3-N.
5. **R2/R7 – Kurvenkorridor (F7, A-3):** Bergstrecken wirken leerer als in Arcade. Im Rennbild fehlen der innere
   Waldrand (Dortmund–Frankfurt km 122) und zwei Klippen (Lyon–Bern km 144,0 / 145,2) (Bild 16). Das hat AS3 schon
   gemeldet; ich bestätige es mit eigenen Bildern.
6. **PIPE/Leitung – Texturbudget:** 37,1 von 60 MB Texturquellen sind belegt, bevor Städte und Wahrzeichen kommen.
   Der gemeinsame Atlas der Varianten spart 15,8 MB sofort (M9).
7. **Prüfer (`validate_models.py`) könnte zusätzlich prüfen:**
   - Bodenkontakt für `tree` / `plant` / `rock`: der tiefste Punkt liegt mindestens 0,1 m unter 0
     (heute nur Räder; `cover_grass` hat 0,00).
   - Byte-gleiche Texturen zwischen Modellen.
8. **R4 – Nacht und Dämmerung:**
   - Nachts im Rennen gleich hell wie Arcade (gemessen); nichts zu tun.
   - In der Dämmerung sind Modern-Bäume 10–22 % heller als das Sprite (AS3 gemessen, hier bestätigt: Fernbild gegen
     Sprite in 200 m).
   - Der Schnee- und Nässe-Term im `leaves.gdshader` fehlt noch; die Normalen der Modelle sind dafür brauchbar,
     außer bei der Zypresse (M11).
9. **R2 – Testpatch:** `tests/unit/race3d/test_props.gd` nimmt `props/tree_beech` als Set ohne Modell (von AS3
   gemeldet, Vorschlag liegt bei AS3). Nicht von mir geprüft.

## 9. Abweichungen und Grenzen dieser Prüfung

- **Import-Cache:** Die Kopie trägt den Import-Cache des AS3-Arbeitsbaums statt eine Kopie aus dem Haupt-Checkout. Er
  ist für be866d2 schon importiert; `godot --import` lief danach in 5 s ohne Fehler.
- **Keine Gates:** `run_tests.sh` und `golden.sh check` habe ich nicht laufen lassen. Diese Prüfung ändert keinen Code;
  die Vorstart-Regel verlangt sparsame Last. Die Gate-Ergebnisse von AS3 sind nicht nachgeprüft, nur der Prüfer.
- **Licht der Prüfbilder:** Nachtbilder der Prüfszene haben keine Scheinwerfer. Das Urteil zur Nacht stützt sich auf
  das Rennbild.
- **Hang:** Der Test ist eine um die Straßenachse gekippte Ebene mit 30°, nicht das Gelände des Spiels.
- **Flimmern:** Der Viertel-Pixel-Test ist ein Ersatzmaß; dazu Film und Folgebilder angesehen.
- **Überzeichnung:** nicht neu gemessen. AS3 hat 1,5–9,7 Laub-Fragmente je gedecktem Pixel in 20 m gemessen
  (Pappel 9,7×, Fichte 8,7×). Was das auf einer echten Grafikkarte oder dem Steam Deck kostet, ist gefolgert, nicht
  gemessen.
- **Wirkung auf Spieler:** „stundenlang ansehbar“ ist ein Urteil nach Bildern und einem 2-s-Film, kein Spieltest.

## 10. Werkzeuge und Rohdaten (Arbeitsordner, nicht eingecheckt)

- `m1/KRITIK-3/tools_kritik/kritik_scene.gd`, `vertex_data.gd`, `stage_sets.gd` (mit `--list=<set,…>|all`) – Prüfmodi und Zensus (Abschnitt 2)
- `m1/KRITIK-3/run_dist.sh`, `kritik.sh`, `batch_*.sh` – die Läufe; `py/*.py` – Bögen
- `m1/KRITIK-3/logs/` – Messausgaben: `levels_h12/h19.5/h23.log` (PEGEL/SPRUNG), `sparkle.log` (FLIMMER),
  `umriss/u.log` (UMRISS), `lods_check.log` (UMSCHALT), `vertex_data.log` (DATEN), `validate.log`, `census_kh.txt`
- `m1/KRITIK-3/ab/` – Rohbilder der neun Rennläufe; `m1/KRITIK-3/shots/` – alle Prüfbögen (die Einzelbilder der Fahrt sind gelöscht; der Film liegt im Lieferordner)
