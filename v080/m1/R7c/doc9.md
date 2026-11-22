
## 9. Fern-LOD der Bauten und Pflanzen (Bauabschnitt R7c, Nachträge A-16, A-19, A-22)

Gemessen heißt hier: auf dieser VM (Mesa llvmpipe unter Xvfb); was eine echte Grafikkarte oder das Steam Deck daraus
macht, ist gefolgert.

### 9.1 Detailstufe je Instanz mit Überblenden

Bis RINT-M2 galt eine Stufe für ein ganzes 96-m-Stück und wechselte hart: beim Wechsel bei 60 m änderten sich an
einem Stadthaus 8–32 % seiner Pixel in einem Bild (AS5aR1, AS5aR2). Jetzt:

- **Ein Material je Netz.** `ModernMaterials.material(klasse, modell, netzpfad)` gibt jedem Netz eines statischen
  Modells (alles außer `kind` vehicle/heavy) für die Klassen `vpbr_static`, `baked`, `baked_cutout`, `leaves` ein
  eigenes Material; `ModelFactory.surfaced_mesh()` reicht den Pfad durch. Der Schlüssel beginnt wie der der Klasse,
  `set_class_parameter()` und `apply_look()` erreichen sie wie bisher. Fahrzeuge teilen ihre Materialien weiter.
- **Band je Stufe.** `builders/props.gd` setzt auf jedes Material einer Stufe `lod_band` = (Einblenden von, bis,
  Ausblenden von, bis) in Metern Abstand des Instanz-Ursprungs zur Hauptkamera
  (`inc/lod_band.gdshaderinc`). Nachbarstufen teilen sich das Band in umgekehrter Richtung und dasselbe geordnete
  Raster (wie das F5-Ausblenden): kein Loch, kein Pixel doppelt. Eine Instanz außerhalb ihres Bandes fällt im
  Vertex-Shader auf einen Punkt zusammen (keine Fragmente). Im Schattendurchgang (Kamera ≠ Hauptkamera,
  `MAIN_CAM_INV_VIEW_MATRIX` gibt es nur in `vertex()`) entscheidet die Mitte des Bandes ohne Raster, so wirft genau
  eine Stufe.
- **Entfernungen.** Stufe 0 eines Modells gilt bis `prop_lod0_m` („Details“: 40 / 60 / 120 m) × `max_dist_m` der
  Stufe 0 aus `model.json` / `lod_ref_m` (60 = der Standard des Exporters, also die Entfernung bei „Mittel“);
  Stufe 1 entsprechend mit `prop_lod1_m` und `lod1_ref_m` (200). `graphics.modern.props.lod0_m` ersetzt den Wert
  je Modell oder je Tag (`tag:city`), solange `model.json` ihn nicht selbst trägt: Stadthäuser 35 m, Fachwerk und
  Pariser Häuser 30 m (gegen ihr Flimmern, 9.3). Bandbreite: ±12 % der Entfernung, mindestens 4 m, höchstens 25 m
  (`lod_fade`) – bei 50 km/h dauert ein Wechsel bei 35 m etwa 0,6 s, bei 130 km/h ein Baumwechsel bei 60 m etwa
  0,4 s (wie das `xfade` der Fahrzeuge).
- **Stücke.** `update()` rechnet alle 2 m Fahrt die Spanne der Abstände aus dem Kasten der Instanz-Ursprünge des
  Stücks (gerade Linie, wie der Shader) und schaltet einen Stufenknoten nur ab, wenn keine Instanz in sein Band fällt.
  Während Instanzen eines Stücks ein Band kreuzen, zeichnet ein Set zwei Stufen (Zeichenaufrufe je Stufe ≤ 2).
- `quality_lowered(levels)` (Wächter) setzt die Bänder sofort neu.

### 9.2 Fernlicht

Jenseits der Reichweite der Echtzeitschatten (Hoch 200 m, Mittel 120 m; Ausblenden ab 85 %) fiel die Sonne voll auf
Laibungen, Arkaden und Traufen: Fernfassaden wurden 4–29 % heller (AS5aR2 K2). Jetzt nimmt ein Modell, das bei der
Schattenstufe selbst wirft, dort seinen mittleren beschatteten Sonnenanteil `far_sun` (`graphics.modern.props.far_sun`:
Gebäude 0,78, Bäume 0,8, Chalet 0,35, Fachwerk 0,85), eingeblendet mit dem Ausblenden der Engine
(`shadow_far`, Ansichtstiefe). Der `baked`-Shader hat dafür ein `light()` mit dem Beleuchtungsmodell der Engine
(Lambert + Schlick-GGX, f0 = 0,16 × 0,35²) – in der Nähe gleich (bei 60 m dieselben Werte wie vorher, gemessen),
`vpbr_static` und `leaves` nehmen dieselbe Abschwächung.

### 9.3 Flimmern

- Der Alphatest von `baked_cutout` liest die Deckung aus einer zwei Stufen gröberen Mip (`cutout_bias` 2; der Bake
  hält die Deckung jeder Mip-Stufe, A-22), die Schwelle bleibt 0,5.
- Die Farbe der Atlanten bekommt ab 30 m einen wachsenden Mip-Bias (bis 1,25 bei 120 m, `albedo_bias`,
  `albedo_bias_m`) – in der Nähe bleibt sie so scharf wie vorher.
- lod0 der Stadthäuser endet bei „Mittel“ bei 35 m, die der Fachwerk- und Pariser Häuser bei 30 m (9.1): ihre Stufe 1
  flimmert wie das Sprite.

### 9.4 Fenster in der Dämmerung

Ein leuchtendes Pixel des Nachtatlas ersetzt mit der Nacht die beleuchtete Fassadenfarbe (Arcade legt die Lichtebene
über das Sprite) und erreicht sein volles Licht bei `ce_night` = `window_ramp` (0,6; Arcade: Palette „lights“ 0,65 um
19:30, 1 ab 21 Uhr). Nicht, wo der Nachtatlas aus ist (`emit_energy` 0: Pylone der Schrägseilbrücken).

### 9.5 Fernbilder

Das Fernbild eines Kartenbaums (`billboard.gdshader`) blendet über `lod_band` ein und verliert nachts das Relief des
Sprite-Lichts (`relief_night` 0,75 × `ce_night` in Richtung der Mittelfarbe des Bildes – kleinste Mip-Stufe).

### 9.6 Anbauten, Tags, Phase

- **Anbauten** (Leitentscheid zu A-22): `model.json` darf `"attach": [{"prop": "props/tree_beech", "offset": [x, y, z],
  "scale": s}]` nennen; `props.gd` stellt sie als gewöhnliche Instanzen ihrer Sets dazu (eigene Detailstufen, eigene
  Auslassungen, links gespiegelt). Kein ausgeliefertes Modell nutzt es bisher (geprüft mit einem Test-Manifest).
- **Tags** (A-16): `ground_align` neigt Pflanzen und Bodendecker zur Geländenormalen (höchstens 30°), `ground_sink`
  setzt Felsen und Klippen auf den tiefsten Punkt ihrer Grundfläche, `face_road` dreht höchstens ±20° aus der
  Straßenrichtung.
- **Phase**: Die Custom-Daten einer Modellinstanz tragen a = 1 + Phase (halbe Gleitkommazahlen: 1/1024): Rotoren
  (Windrad, Mühle) und Wiegen der Bäume springen nicht mehr bei jedem Verschieben des Ursprungs (alle 2 km).
  `ModernMaterials.static_code()` setzt das (und Band und Fernlicht) in die statische Variante von `vpbr.gdshader`
  ein; `test_props` prüft, dass jeder Einschub ankommt.
