- Gemessen mit `ChunkStreamer.stats()` → `collect_by` (neu, `6347e41`): Hauptfadenzeit von `collect()` je Baustein,
  Testetappe ganz, „Steam Deck“, Zeitraffer 16, llvmpipe – auf dieser Maschine lief gleichzeitig ein anderes Paket
  (AS5a2, nice 19): Höchstwerte sind unruhig, die Mittel belastbar.

| Stand | Tankstelle `collect()` max / Mittel (Fahrt, 134 Aufrufe) | Ursache der Spitzen (Instrumentierung `STATDBG`) |
|---|---|---|
| Merge-Stand (`eb417a7`, Entscheid inline) | 3,41 / 0,20 ms | die Sichtlinien eines Dachs im Hauptfaden |
| `618561f` (Sichtlinien auf Arbeitsfaden) | **8,04** / 0,33 ms | Sammeln las Korridor-Merker 600 m voraus (Geländezeilen) |
| `c72d484` (Korridor erst in `finish()`, Sammeln in zwei Hälften) | 9,50 / 0,20 ms | bei sechs Dächern einer Station reichten 600 m Vorlauf nicht: die letzten drei Dächer inline (4–6 ms) |
| Zwischenstand mit 2000 m Vorlauf (verworfen, nicht eingecheckt) | 19,59 / 0,36 ms | der Vorlauf erzwang die Strecke weit voraus (rund 13 ms je km Erzeugung): eine Spitze von 18 ms |
| `b673df5` (Vorlauf 600 m mit Zeitbudget 0,5 ms, Spuren und Krümmung geteilt) | 2,86 / 0,16 ms | Schilder je Dach neu gelesen |
| `02051f7` (dazu Schilder je Segment geteilt) | **2,40 / 0,14 ms** | alle neun Dächer vor ihrem Stück gesammelt und auf dem Arbeitsfaden entschieden, keines inline; erstes Dach einer Station zwei Hälften zu 1,2–1,5 ms, jedes weitere 0,2–0,6 ms |

- Ergebnis: der Entscheid (Sichtlinien) läuft auf dem Arbeitsfaden (`WorkerThreadPool`), das Sammeln der Strecke bleibt
  im Hauptfaden (`Track` erzeugt sich beim Lesen, nicht fadensicher) und ist in Hälften unter einem Zeitbudget verteilt.
  Der Höchstwert 2,40 ms liegt **0,4 ms über dem Ziel von 2 ms** (eine Hälfte des ersten Dachs einer Station fällt in
  ein Bild, das selbst schon Arbeit hat); das Mittel 0,14 ms. Gemessen neben dem Paket AS5a2 auf derselben Maschine.
  Nächster Schritt, falls die Leitung 2 ms hart will: das erste Dach einer Station in drei Teile teilen oder die
  Spuren der Station in `prepare()` sammeln.

- Sonde ohne Spiel (`bin/canopytime.gd`, Kiel – Hamburg und Testetappe, 22 Dächer): Sammeln vorher am Stück bis 3,9 ms
  (davon Korridor-Merker bis 17 ms beim ersten Dach einer Station), jetzt je Hälfte höchstens 1,2 / 1,4 ms; Sichtlinien
  auf dem Arbeitsfaden 0,1–2,5 ms.
- Entscheide unverändert: `scan_f1` netzweit zeilengleich (3486 Stützen, 1648 Verdeckungszeilen), `startdep` 1909 Dächer
  0 abweichend, `test_structures` 13/13; Modern-Goldens vorher/nachher MD5-gleich.
- Die übrigen Bausteine während der Fahrt: Grenze ≤ 0,44 ms, Schilder ≤ 0,42, Gelände ≤ 1,07, Requisiten ≤ 0,12 (Mittel
  0,02–0,05 ms). In der Ladephase (vor dem Start) `city` bis 6,0 ms – nicht im Fahrbudget, aber notiert.
