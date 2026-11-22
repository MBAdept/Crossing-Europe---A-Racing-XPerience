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
| `02051f7` (dazu Schilder je Segment geteilt) | 2,40 / 0,14 ms | alle neun Dächer vor ihrem Stück gesammelt und auf dem Arbeitsfaden entschieden, keines inline; erstes Dach einer Station zwei Hälften zu 1,2–1,5 ms (kalte Caches), jedes weitere 0,2–0,6 ms |
| Versuch `warm_step()` mit 0,7 ms Budget und 600 m Vorlauf (verworfen) | 8,71 / 0,26 ms | zu wenig Arbeit je Aufruf: ein Dach war nicht rechtzeitig fertig |
| **`b903797`** (`warm_step()`: Strecke in Stücken zu 6 Segmenten erzeugt, Caches der Schilder und Kamerastellen Stück für Stück bis 1,0 ms je Aufruf) | **2,08 / 0,12 ms** | die kalte Arbeit des ersten Dachs ist auf mehrere Aufrufe verteilt |
| **`9b02f05`** (dazu Vorlauf `WARM_AHEAD_M` 1200 statt 600 m – das Erzeugen geschieht jetzt in Stücken) | **1,36 / 0,11 ms** | alle neun Dächer beim Stück gesammelt und entschieden (Rest dort 0,02–0,18 ms, Kopie mit Ausgaben), keines inline; alle Bausteine in diesem Lauf ≤ 1,36 ms |

- Ergebnis: der Entscheid (Sichtlinien) läuft auf dem Arbeitsfaden (`WorkerThreadPool`), das Sammeln der Strecke bleibt
  im Hauptfaden (`Track` erzeugt sich beim Lesen, nicht fadensicher; Arcade-Datei, eingefroren) und ist mit
  `warm_step()` in kleine Stücke unter einem Zeitbudget verteilt. Mit 1200 m Vorlauf bleiben genug Aufrufe, bis das Stück eines Dachs gebraucht wird: **höchstens 1,36 ms, Mittel 0,11 ms** – unter dem Ziel von 2 ms. Entscheide gleich: Sonde `jobpath` 1909 Dächer, 0 verschieden (auch für 600 m und 0,7 ms); Unit-Test `test_station_warm_step_prepares_what_the_halves_read`; `test_structures` 14/14.
- **Messgüte:** ein Lauf, ein Höchstwert, auf einer VM mit zwei Paketen gleichzeitig. Die Höchstwerte der anderen
  Bausteine schwanken zwischen gleichen Läufen stark (Requisiten in vier Läufen 0,12 / 0,34 / 0,70 / **4,19 ms**,
  ohne Codeänderung dort) – Mittel sind belastbar, ein einzelner Höchstwert um 2 ms nicht. Für eine harte Aussage
  „≤ 2 ms auf dem Deck“ braucht es das Gerät oder mehrere Läufe auf einer ruhigen Maschine.

- Sonde ohne Spiel (`bin/canopytime.gd`, Kiel – Hamburg und Testetappe, 22 Dächer): Sammeln vorher am Stück bis 3,9 ms
  (davon Korridor-Merker bis 17 ms beim ersten Dach einer Station), jetzt je Hälfte höchstens 1,2 / 1,4 ms; Sichtlinien
  auf dem Arbeitsfaden 0,1–2,5 ms.
- Entscheide unverändert: `scan_f1` netzweit zeilengleich (3486 Stützen, 1648 Verdeckungszeilen), `startdep` 1909 Dächer
  0 abweichend, `test_structures` 13/13; Modern-Goldens vorher/nachher MD5-gleich.
- Die übrigen Bausteine während der Fahrt: Grenze ≤ 0,44 ms, Schilder ≤ 0,42, Gelände ≤ 1,07, Requisiten ≤ 0,12 (Mittel
  0,02–0,05 ms). In der Ladephase (vor dem Start) `city` bis 6,0 ms – nicht im Fahrbudget, aber notiert.
