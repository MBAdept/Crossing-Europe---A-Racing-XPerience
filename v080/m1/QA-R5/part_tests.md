## 4. Tests – Gates und Wächterwirkung

### 4.1 Gates (gemessen, Prüfling 5558bdc, nice 10, Last 10–15)

__GATES__

### 4.2 Schützen die neuen Tests ihre Regel? (Mutationen, gemessen)

Je eine Zeile in einer Kopie des Prüflings (`m1/QA-R5/mut`) gebrochen, nur die zuständige Testdatei laufen lassen
(`godot --headless -s res://tests/run_tests.gd -- --filter=<datei>`), danach zurückgesetzt (`tools/mutate.py`,
`mutations/results.json`). Grundlauf: `test_bridge` 10/10, `test_tunnel` 8/8, `test_far_ground_water` 4/4 grün.

| Mutation (Datei: Änderung) | Regel | Ergebnis |
|---|---|---|
| B1 bridge.gd: Wasser 0,5 m höher | Wasser auf den Wasserzeilen | gefangen (`test_water_lies_on…`) |
| B2 bridge.gd: Wasser nur bis Ring 3 | Wasser bis zum letzten Ring | gefangen |
| B3 bridge.gd: Uferregel umgedreht | Ufer nach Arcades Regel | gefangen (2 Tests) |
| B4 bridge.gd: ferne Kaimauer zeigt nach vorn | ferne Kaimauer zur Kamera | gefangen |
| B5 bridge.gd: Pylon nicht skaliert | `height_m`/88,8 (A-16) | gefangen |
| B6 bridge.gd: Flugfeuer 8 m unter der Spitze | Feuer auf `height_m` + 1,6 m | gefangen |
| B7 bridge.gd: Seilende 4,5 m statt 1,4 m innen | kein Seil über einer Spur | gefangen (2 Tests) |
| B8 bridge.gd: Fachwerk 3 m nach innen | Tragwerk aus den Spuren | gefangen |
| B9 bridge.gd: Randbalken 5 m nach innen | Tragwerk aus den Spuren | gefangen |
| B10 bridge.gd: `night_albedo` nicht gesetzt | Pylon nachts dunkel | **nur über `SCRIPT ERROR`** (`float(null)` im Test bricht ab; `run_tests.sh` wertet Skriptfehler als Fehlschlag) |
| B11 bridge.gd: Blinkphase je Seite 0 | Arcades Takt | gefangen |
| B12 bridge.gd: 5 statt 7 Seile je Seite | Arcades 7 Seile | **nicht gefangen** (Test rechnet mit der eigenen Konstante) |
| B13 bridge.gd: Fachwerkportale nicht gebaut | Portale | gefangen (`test_every_bridge_type_builds`) |
| B14 bridge.gd: Brückenlampen nicht gebaut | Lampen an Stein-/Dammbrücken | **nicht gefangen** (kein Test; auch R5s Netzlauf zählt sie nicht) |
| T1 tunnel.gd: keine Nischen | SOS-Nischen | gefangen |
| T2 tunnel.gd: Lüfter auf 3,6 m | nichts unter 5,2 m über der Fahrbahn | gefangen |
| T3 tunnel.gd: Kappe auch innen | Kappe nur von außen | gefangen |
| T4 tunnel.gd: `has_method("set_zone")` entfernt | `set_zone` duck-typed | **nicht gefangen** (kein Fall „Rig ohne `set_zone`“) |
| T5 tunnel.gd: keine Kappe | Kappe bei `peek_m` | gefangen |
| T6 tunnel.gd: kein Portal | Portal + Hügel | gefangen (3 Tests) |
| F1 far_ground.gd: ZS1-Regel entfernt | Fernboden ≤ tiefstes Wasser − 0,3 m | gefangen (3 Tests in `test_far_ground_water`) |
| F2 far_ground.gd: Kaifarbe der Kopie verändert | gepinnte Kopie = Arcade | gefangen |

18 von 22 Regeln sind von benannten Tests geschützt, eine nur über den Skriptfehler-Filter, drei gar nicht
(Befund QR5-05). Die Wächter der ZS1-Korrekturen halten (`test_far_ground_water` 4/4; K1 siehe Gates).
