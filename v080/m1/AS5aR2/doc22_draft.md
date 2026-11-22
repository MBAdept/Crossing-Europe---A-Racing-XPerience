## 22. Nacharbeit der Stadthäuser nach der Kunstkritik (AS5aR2)

Die unabhängige Kunstkritik von Abschnitt 21 (KRITIK-5a2) fand die zwölf Häuser bei Tag klar feiner als die
Arcade-Bilder, nachts in den Ladenstraßen aber dunkler und leerer, die Fassaden ab 100 m blass mit rosa-lila
Fenstern, den Gartenbaum des häufigsten Hauses als Klumpen und die Geländer flimmernd. Die Nacharbeit ändert den
Bauer `city` und baut alle 23 Stadthäuser (Abschnitte 20 und 21) neu; die Sprites sind unverändert.

### Was geändert ist

- **Schaufenster nachts (`cities3d._display_mat`, alle Läden beider Chargen).** Die Lichtschicht der Auslage war
  0,2 + 0,8 × Innenfarbe × Lichtfarbe × 1,25 × Stärke × `PANE_LIGHT_K` – im Mittel ein Viertel der Lichtfarbe, ein
  Drittel eines Wohnfensters. Jetzt: 0,3 + 0,75 × √Innenfarbe (Rückwand und Waren im Licht, Möbel bleiben lesbar),
  ein Band Deckenlicht im oberen Viertel (+0,35) und `SHOP_GLOW` 1,6 statt 1,25. Bei Tag unverändert (die Auslage
  hinter dem dunklen Glas).
- **Fernfenster (`wallmat`-Hooks `inner_k`, `bars_k`).** Der Innenrahmen-Ring von AS5aR1 (6 cm Rahmenfarbe innen im
  gemalten Fenster, damit die flache lod1 dieselbe Glas- und Lichtfläche zeigt wie die geschnittenen Fenster von lod0)
  verdoppelte das Weiß jedes Fensters der Fernstufe gegenüber dem Sprite (Weißanteil einer Fensterzelle 36 statt
  23 %): ab 100 m wurden die Fassaden blasser, die Fenster rosa-lila. Ring und gemalte Sprossen liegen jetzt
  `INNER_K` 0,75 bzw. `BARS_K` 0,35 des Weges von der Rahmen- zur Glasfarbe – der Rahmen im Schatten der Laibung.
  lod0 zeigt beide nie: sein geometrischer Rahmen und seine Sprossen liegen 1,5 cm davor.
- **lod1 ohne Alpha-Test (`lod1_opaque`).** Sechs Häuser mit Ausschneide-Klasse (Mietshaus, Gründerzeit, Lyoner
  Haus, Haussmann, Eckhaus, Chalet) zeichnen lod1 als `baked` mit Rückseiten-Culling: ein
  Geländer ist dort das Band aus seinen Stäben und der `cut_fill`-Farbe – was das Auge ab 60 m mittelt –, ohne das
  Kippen des Alpha-Tests. lod0 bleibt `baked_cutout` (A-22: `cut_fill`, Schwelle 0,5).
- **Blattkarten für Gartenbäume (`leaf_cards`).** Die dezimierte Kugelkrone des Generators war aus 10–15 m eine Traube
  facettierter Steine. Jetzt liegen Blattkarten auf den Blobs der Krone (`props_nature.CROWN_LOG`, dieselben Blobs, auf
  denen die AS3-Kartenbäume wachsen), ihre Textur – vier Blattbüschel von `leafatlas.cluster` in den zwei
  Blattfarben des Generators, mit Halo und Farbauslauf für die Schwelle 0,5 – liegt in einem reservierten Feld des
  Hausatlas (ein Hilfsviereck `ce_leafres` 60 m unter dem Modell bekommt beim Packen `leaf_px` Texel und wird nicht
  gezeichnet). Jede Ecke hat die Normale ihres Blobs (mit 22 % der Kronenrundung): ein Blob ist auf der Sonnenseite
  hell wie die Kugeln des Sprites. Die dezimierte Krone schrumpft um `core` (0,9) und bleibt als Blattmasse innen;
  lod1 zeigt dieselben Karten (`n1` = `n`, `half1` = `half`) und behält dafür die Ausschneide-Klasse – mit dem Kern
  allein tauschte der Stufenwechsel bei 60 m beim Südhaus 34,8 % der Pixel, mit weniger, größeren Karten 27,5 %
  (gemessen; vorher 16,4 %). Weil die
  Karten Alpha brauchen und ein Stadthaus zwei Zeichenaufrufe hat, gibt es sie nur bei Häusern mit Ausschneide-Klasse
  (`single_cutout`): Südhaus und Loire-Haus (dieses ist dafür jetzt `single_cutout`).
- **Geranien (`flower_shape`).** Die Blumenkugeln des Chalets werden je Kugel flacher,
  längs des Kastens gestreckt (1,2 / 0,8 / 0,6) und um bis zu 4 cm versetzt: niedrige, ineinanderlaufende Polster
  statt einer Perlenkette.

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

`lod1_opaque` (bool), `leaf_cards` {Kronen-Präfix: dict(n, half, out, el, crown_w, down, core, atlas, n1, half1)}, `leaf_px`
(256), `flower_shape` {Präfix: (x, y, z, Versatz)}, `inner_k` / `bars_k` (Voreinstellung `INNER_K` 0,75 / `BARS_K` 0,35).

### Budgets nach dem Neu-Export (gemessen: Export-Bericht, Packdichte, Archivanteil wie `tools/pck_report.py`)

| Set | Dreiecke lod0 / lod1 | Klassen lod0 / lod1 | Atlas | px/m Straße min / Packdichte | Archiv Netze / Texturen | Export |
|---|---|---|---|---|---|---|
| `city_french_sud` | 5 820 / 3 456 | baked_cutout / baked | 1024×1024 | 32,1 / 53,5 | 130 / 418 kB | 169 s |
| `city_belgian_terrace` | 2 586 / 1 162 | baked / baked | 2048×1024 | 51,0 / 63,7 | 46 / 546 kB | 371 s |
| `city_french_maison` | 4 250 / 1 760 | baked_cutout / baked | 1024×1024 | 29,9 / 49,8 | 99 / 365 kB | 187 s |
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

Charge 2: Netze 0,95 MB, Texturen 5,91 MB; Charge 1: Netze 0,82 MB, Texturen 5,35 MB (Archiv, deflate -9)

Alle 23 unter 10 000 Dreiecken in lod0 und zwei Zeichenaufrufen je Stufe. Die Blattkarten kosten das Südhaus
460 und das Loire-Haus 340 Dreiecke in lod0 und 4–6 % des Atlas (Blattfeld 246 bzw. 248 Texel); die Wanddichte sank
dadurch um 1–2,5 %. „px/m Straße min“ ist die kleinste Dichte der Straßenwände (bei Südhaus und Loire-Haus die
Gartenmauer mit 0,6 der Dichte), „Export“ die Zeit mit Bake (`nice -n 19`, geteilte Maschine).

MESSUNGEN_R2
