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
