
### Was neu ist

Am Generator nichts (`check_sprite_geometry` hat nichts zu prüfen – die Sprites sind dieselben). Der Bauer
`prop_baked` hat drei neue Katalog-Optionen, dazu zwei Regeln für alle Wahrzeichen:

- **Atlas nach Größe.** Nach L1 lagen die Texturquellen bei 50,4 von 60 MB; 23 weitere Atlanten mit 2048² hätten
  die Grenze um etwa 10 MB überschritten. Darum je Wahrzeichen: groß und reich verziert 2048×2048 (Dome, Türme,
  Paläste), mittel 2048×1024, schlanke Türme und das Denkmal 1024×1024 (Campanile, Belfried, Freiheitsdenkmal).
  Die höchste Packdichte (`ppm_max`) folgt der Größe des Bauwerks: 32 px/m für die kleineren (Kaiserburg, Fulda,
  beide Frauenkirchen, St. Petri, Riesenrad, Passau, Belfried, Campanile, Freiheitsdenkmal, Newski, Sibiu,
  Timișoara), 24 für die meisten Dome, 20 für Fernsehturm und Sagrada Família, 16 für die Riesen (Frankfurt,
  Eiffelturm, Parlament Budapest, Kulturpalast, Parlamentspalast). Wie dicht der Atlas tatsächlich belegt ist, steht
  in der Tabelle.
- **Wahrzeichen-Atlas immer als WebP.** Bisher wurde ein Atlas bis 1024 px als PNG geschrieben – bei Wahrzeichen
  waren das 590–610 kB je Atlas, mehr als ein 2048×1024-WebP. Mit WebP für alle (`kind="landmark"`) liegen die
  Texturquellen wieder unter 60 MB.
- **`drop_caps`** (Liste von Objektnamen): Bei jedem Kastenträger aus 8 Ecken und 6 Vierecken fallen die zwei
  Stirnflächen an den Enden weg, die immer in Gurt, Knoten oder Plattform stecken. Beim Eiffelturm
  (`eif_lattice`) war das ein Drittel der Gitter-Dreiecke: 25 152 → 17 072, unter der Grenze von 25 000; aus
  80–1 200 m ist kein Loch zu sehen. Der Bauer bricht ab, wenn die Option nichts entfernt.
- **`vpbr` + `overrides`** (Präfixe von Materialnamen): Diese Materialien werden nicht in den Atlas gebacken, sondern
  bleiben Vertex-PBR (Klasse `vpbr`, `landmark.gdshader` CE_VCOL) mit Farbe, Rauheit und Metall aus `overrides`.
  Gebacken verliert Metall seinen Glanz: Die Stahlkugeln des Atomiums waren matt grau, die Goldkuppeln der
  Newski-Kathedrale und der Kathedrale der Erlösung matt senfgelb – die Sprites zeigen Chrom und Gold mit
  Glanzlicht. Jetzt Stahl mit Metall 1 und Rauheit 0,22 / 0,3, Gold mit Rauheit 0,28 / 0,3. Die Goldkuppeln sind
  nachts angestrahlt wie im Generator (Lampenkanal 14, `lamp="flood:0.75"` bzw. `0.7`). Der Bauer bricht ab, wenn
  kein flaches Material passt.
- **Keine automatischen Stufen bei Lampenkanälen auf `vpbr`** (Vertrag A-4, wie beim Bauer `prop_vpbr`): Bei Newski
  und Erlösung behielten die dezimierten Stufen nur 25–69 % der angestrahlten Goldfläche (Grenze 80 %,
  `validate_models` LAMP_KEEP). Beide haben `auto_lod=False` und tragen etwa 5 000 Dreiecke.

- **Splitter unter 0,1 mm fallen weg** (`finish(min_height=1e-4)`, wie bei Stadthäusern und Brücken): n-Eck-Deckel mit
  Ecken auf einer Geraden (Fuß und Dach eines Frankfurter Turms, Belfried) zerfallen in Dreiecke ohne Höhe; die
  16-Bit-Positionen eines 300 m hohen Modells (5 mm Raster) drehen einige davon um – `validate_models` zählte beim
  Frankfurter Ensemble 11 verkehrt gewickelte Dreiecke. Unsichtbar, aber gezählt; die anderen 31 Wahrzeichen hatten
  keine solchen Splitter.

Alle Wahrzeichen außer Newski und Erlösung haben eine Stufe lod0 und die automatischen Stufen von Godot (`auto_lod`); der Prüfer
verlangt, dass auch diese Stufen die Lampenflächen behalten.

### Hook im Generator

Keiner.

### Tönung

Die Kaiserburg steht außer in Nürnberg auch in Würzburg (`#efe6d6`) und Pau (`#e6dccb`) als getönte Burg; der
Renderer legt die Tönung auf die Modell-Instanz (R7). Die anderen 31 Wahrzeichen sind nirgends getönt.
