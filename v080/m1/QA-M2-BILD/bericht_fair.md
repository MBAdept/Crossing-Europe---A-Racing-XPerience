## Fairness

### Geometrische Prüfungen über das ganze Netz (gemessen, 15:09–15:12 UTC)

`godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full --verbose` (144 s) und
`… modern_path_check.gd -- --full` (58 s) auf `6e48405`, Logs `fair/modern_sight_full_m2.log`, `fair/modern_path_full_m2.log`:

| Prüfung | Vertrag | Ergebnis |
|---|---|---|
| F1 Mitte | 0 Fälle bis 270 m | **0** in 99 424 500 Stichproben, 128 Richtungen (erster Fall bei 280 m) |
| F1 Außenspuren (A-3) | 0 bis 260 m | **0** in 326 680 500 Stichproben (erster bei 270 m) |
| F2 | Anhalteweg ≤ 0,6 × Sichtweite | **0,593** trocken / **0,596** Regen / **0,555** Schnee |
| F3 Kuppen | 0 später und im Anhalteweg | **0 von 5 923** Fahrzeugzielen, 0 Schilder |
| F7 Gelände im Korridor | 0 | **0 von 2 011 532** Querschnittsseiten |
| Kameramodell | 0 Abweichungen | 0 (größte 0,0002 px) |
| Pfad | ≥ 250 m, Schleifen ≥ 2 000 m | 267,6 m (Bukarest–Sibiu km 57,8), Schleifen frühestens nach 2 064 m |

Alle Zahlen gleich denen von M2ZS1. **Grenze dieser Prüfungen:** sie rechnen mit Kamera, Fahrbahn und Gelände – Bäume,
Felsen und Gebäude kommen darin nicht vor. Deshalb zusätzlich im Bild:

### Verdeckung durch Modelle an Kurven (neu, gemessen)

`probe/qa_occl.gd`: eingefrorene Etappe ohne Verkehr, ein rotes Testauto (`traffic/hatch_red`) nacheinander 25 … 270 m
vor der Kamera in drei Spuren (eigene, links daneben, rechts daneben), jedes Bild gegen dasselbe Bild ohne Auto;
sichtbar = Pixel, die sich um mehr als 24/255 ändern. Dieselbe Ansicht und dieselben Autos in Arcade und in Modern
„Hoch" (Dichte 1,3 – die meisten Bäume). 4 Stellen × 10 Abstände × 3 Spuren = 120 Fälle (`sh/occl_count.py`):

| Stelle | Modern / Arcade (sichtbare Pixel) | Befund |
|---|---|---|
| T4 Saragossa–Pau km 198,8 (R ≈ 136 m) | 0,89–1,07 bis 55 m; **55–220 m nur Modern** | Arcade verdeckt das Auto ab 55 m hinter dem Fels-Sprite; Modern zeigt es bis 220 m (Fels und Fichten der Innenseite fehlen – Korridorregel) |
| T3 Saragossa–Pau km 172,8 | 0,99–2,6 | nirgends kleiner |
| T1 Kassel–Würzburg km 46,5 | 0,69–1,01 (25–170 m), 0,88–2,1 (220/270 m) | Auto in beiden ganz sichtbar (Ausschnitt `occl/T1_d100_zoom.jpg`); der kleinere Wert kommt vom eingebackenen Schatten und weichen Rand des Arcade-Sprites |
| W1 Dortmund–Frankfurt km 121,4 (Wald) | 0,70–1,09 | nirgends verdeckt |

**Ergebnis:** In keinem der 120 Fälle zeigt Modern ein Auto später oder deutlich kleiner als Arcade (kleinstes
Verhältnis 0,69 ohne Verdeckung). Die höheren und tieferen 3D-Bäume verdecken an diesen Kurven nichts – aber nur, weil
die Korridorregel sie auf der Kurveninnenseite gar nicht erst aufstellt (nächster Abschnitt). Bilder:
`occl/T4_d100_sheet.jpg`, `occl/T3_d130_sheet.jpg`, `occl/T1_d100_zoom.jpg`.

### Was die Korridorregel kostet (gemessen)

`probe/qa_props.gd` vergleicht die Requisiten, die Arcade zeichnet (`TrackSegment.sprites`), mit der Liste, die der
Props-Bauer von Modern wirklich aufstellt (`debug_snapshot()`), in den 150 m vor der Kamera (Liste je Stelle in
`fair/props_*.txt`). Ausgelassen wird fast nur aus einem Grund: `corridor` (F7, `builders/props.gd drop_reason()`):

| Stelle | ausgelassen / Arcade | was |
|---|---|---|
| Start km 0 | die große Eiche links (Segment 9, x −17,1 m, 9 m hinter dem Bankett) | in ZS1 genauso – das erste Bild jeder Kiel–Hamburg-Fahrt |
| T4 km 199,7 | **9 von 12** | alle Fichten der Innenseite bis 30 m hinter dem Bankett, ein Fels; Korridorbreite hier ≈ 80 m (Sehne 300 m, R 136 m), Band 102 m |
| T3 km 173,5 | 4 von 8 | Kiefern, Felsen |
| T1 km 47,5 | 5 von 13 | Fichten der Innenseite bis 25 m hinter dem Bankett |
| S4 km 80,4 (Hamburg) | 3 von 12 | zwei Birken, ein Busch |
| C1 km 221,8 (Frankfurt) | 4 von 16 | drei Straßenbäume (Ereignis-Einträge) **und ein Stadthaus** `city_german_gruenderzeit` (x +6,9 m) |

Der Vertrag (D14 F7) verlangt: „no decorative **vegetation** inside that corridor on the inside of bends". Der Bauer
lässt laut Code und `docs/renderer-modern-gelaende.md` „schmückende Requisiten einer Landschaftsregel **und** jede
Vegetation" weg – also auch Häuser der Stadtregel, Felsen, Strohballen. Die Korridorbreite ist die Pfeilhöhe einer
300-m-Sehne (d²/8R) – an T4 rund 80 m (abzüglich Bankett). Was F2 an dieser Kurve verlangt (abgeleitet aus `fairness.gd`: Anhalteweg =
1 s Reaktion + Vollbremsung; bei etwa 85 km/h trocken ≈ 58 m, sichtbar ab 58/0,6 ≈ 97 m, mit 9 m Kamera ≈ 106 m
Sehne): Pfeilhöhe ≈ 10 m plus Kronenradius. Die meisten der 9 Fichten (15–36 m hinter dem Bankett) stünden dann.
Bildbeleg: T4 `occl/T4_d100_sheet.jpg` (Modern-Innenseite eine kahle Wiese, Arcade Fels und Fichten), W1/T1
`occl/W1_none_sheet.jpg`, `occl/T1_none_sheet.jpg`, C1 und Start in den A/B-Bögen.
