## 22. Nacharbeit der Stadthäuser nach der Kunstkritik (AS5aR2)

Die unabhängige Kunstkritik von Abschnitt 21 (KRITIK-5a2) fand die zwölf Häuser bei Tag klar feiner als die
Arcade-Bilder, nachts in den Ladenstraßen aber dunkler und leerer, die Fassaden ab 100 m blass mit rosa-lila
Fenstern, den Gartenbaum des häufigsten Hauses als Klumpen und die Geländer flimmernd. Die Nacharbeit ändert den
Bauer `city` und baut alle 23 Stadthäuser (Abschnitte 20 und 21) neu; die Sprites sind unverändert.

### Was geändert ist

- **Schaufenster nachts (`cities3d._display_mat`, alle Läden beider Chargen).** Die Lichtschicht der Auslage war
  0,2 + 0,8 × Innenfarbe × Lichtfarbe × 1,25 × Stärke × `PANE_LIGHT_K` – im Mittel ein Viertel der Lichtfarbe, ein
  Drittel eines Wohnfensters. Jetzt: 0,3 + 0,75 × √Innenfarbe (Rückwand und Waren im Licht, Möbel bleiben lesbar),
  ein Band Deckenlicht im oberen Viertel (+0,35) und `SHOP_GLOW` 1,4 statt 1,25. Bei Tag unverändert (die Auslage
  hinter dem dunklen Glas).
- **Fernfenster (`wallmat`-Hooks `inner_k`, `bars_k`).** Der Innenrahmen-Ring von AS5aR1 (6 cm Rahmenfarbe innen im
  gemalten Fenster, damit die flache lod1 dieselbe Glas- und Lichtfläche zeigt wie die geschnittenen Fenster von lod0)
  verdoppelte das Weiß jedes Fensters der Fernstufe gegenüber dem Sprite (Weißanteil einer Fensterzelle 36 statt
  23 %): ab 100 m wurden die Fassaden blasser, die Fenster rosa-lila. Ring und gemalte Sprossen liegen jetzt
  `INNER_K` 0,6 bzw. `BARS_K` 0,35 des Weges von der Rahmen- zur Glasfarbe – der Rahmen im Schatten der Laibung.
  lod0 zeigt beide nie: sein geometrischer Rahmen und seine Sprossen liegen 1,5 cm davor.
- **lod1 ohne Alpha-Test (`lod1_opaque`).** Die sieben Häuser mit Ausschneide-Klasse (Mietshaus, Gründerzeit,
  Südhaus, Loire-Haus, Lyoner Haus, Haussmann, Eckhaus, Chalet) zeichnen lod1 als `baked` mit Rückseiten-Culling: ein
  Geländer ist dort das Band aus seinen Stäben und der `cut_fill`-Farbe – was das Auge ab 60 m mittelt –, ohne das
  Kippen des Alpha-Tests. lod0 bleibt `baked_cutout` (A-22: `cut_fill`, Schwelle 0,5).
- **Blattkarten für Gartenbäume (`leaf_cards`).** Die dezimierte Kugelkrone des Generators war aus 10–15 m eine Traube
  facettierter Steine. Jetzt liegen Blattkarten auf den Blobs der Krone (`props_nature.CROWN_LOG`, dieselben Blobs, auf
  denen die AS3-Kartenbäume wachsen), ihre Textur – vier Blattbüschel von `leafatlas.cluster` in den zwei
  Blattfarben des Generators, mit Halo und Farbauslauf für die Schwelle 0,5 – liegt in einem reservierten Feld des
  Hausatlas (ein Hilfsviereck `ce_leafres` 60 m unter dem Modell bekommt beim Packen `leaf_px` Texel und wird nicht
  gezeichnet). Jede Ecke hat die Normale ihres Blobs (mit 22 % der Kronenrundung): ein Blob ist auf der Sonnenseite
  hell wie die Kugeln des Sprites. Die dezimierte Krone schrumpft um `core` (0,9) und bleibt als Blattmasse innen;
  lod1 zeigt nur diese Masse in Originalgröße. Weil die Karten Alpha brauchen und ein Stadthaus zwei Zeichenaufrufe
  hat, gibt es sie nur bei Häusern mit Ausschneide-Klasse (`single_cutout`): Südhaus und Loire-Haus (dieses ist dafür
  jetzt `single_cutout`).
- **Geranien (`flower_shape`).** Die Blumenkugeln des Chalets werden je Kugel flacher und kleiner (0,72 / 0,55) und
  um bis zu 7 cm versetzt: niedrige, ungleiche Polster statt einer Perlenkette.

### Nicht geändert (geprüft)

- **Gartenmauer von Südhaus und Loire-Haus:** 0,6 der Dichte = 32,5 px/m an der Straßenseite (Exportbericht
  `ppm_road_min`, GLB-Dreiecke gemessen). Die 15 px/m der Kritik waren die Kronen von Platane und Oleander (Gewicht 0,3).
- **Geländer in kleinen Mips:** Die Deckung wächst, wie A-22 es will (`cut_fill`); gegen die Füllfarbe bleibt die
  Helligkeit des Bandes in Mip 1–4 innerhalb ±4 Stufen. Eine „deckungserhaltende" Lücke würde die Dunkelheit
  verlieren (die durchgelassenen Texel tragen die Mischfarbe).

### Hooks im Generator (Voreinstellung = Sprite)

| Hook | Generator | im 3D-Bau |
|---|---|---|
| `inner_k`, `bars_k` (AS5aR2) | `props_cities.wallmat` (nur mit `inner_frame`) | Innenring und gemalte Sprossen der Fenster zum Glas hin |

### Katalog-Optionen des Bauers `city` (neu)

`lod1_opaque` (bool), `leaf_cards` {Kronen-Präfix: dict(n, half, out, el, crown_w, down, core, atlas)}, `leaf_px`
(256), `flower_shape` {Präfix: (xy, z, Versatz)}, `inner_k` / `bars_k` (Voreinstellung `INNER_K` 0,6 / `BARS_K` 0,35).

TABELLE_R2

MESSUNGEN_R2
