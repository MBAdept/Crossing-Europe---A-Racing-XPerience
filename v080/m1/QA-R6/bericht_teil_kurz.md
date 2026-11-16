## 0. Kurzfassung

**Nichts ist kaputt, die Fairness hält, Arcade ist bildgleich – aber der Look-Gewinn ist schmal und fünf Grenzdächer schweben.**

- Gates (gemessen auf `c8b18d1`): `golden.sh check` 20/20 und 17/17 identisch; `modern_sight --full` und
  `modern_path_check --full` OK; Render-Prüfungen `structures` (7/7), `start_km0`, `light_base`, `terrain_cover` (inkl. K1)
  OK; `run_tests.sh` 759 Tests, 2 rot (Echtzeit-Audio mit Wiedergabe) plus Attract-„idle“ – lastabhängig und nicht von R6
  (Attract allein 6/6 grün auf Kopf und Basis; kein Audio-Code im Diff). Regel 3 über die ganze Testetappe gleich.
- Funktion netzweit (130 Richtungen, 5366 Stücke): jede Tankstelle, Grenze, jedes Tor, jeder Blitzer und jede Laterne steht
  dort, wo Arcade sie hat – 0 Abweichungen, 0 Skriptfehler. Dateibesitz: nur R6-Dateien plus zwei gemeldete fremde
  (`check_minimal_structures.gd`, `tests/golden/modern_slice.*`), keine eingefrorene Datei.
- Befunde: **B-01 (mittel)** 5 von 48 Grenzdächern haben rechts keinen Pfeiler (R6 meldet 4) – das Dach schwebt sichtbar;
  **B-02 (niedrig–mittel)** die Stützen am Dachende verdecken in Kurven Teile ferner Schilder (F1, ≈ 195 Fälle mit
  6–14 px Tafel); **B-03 (mittel, Look)** bei Nacht ist nichts deutlich besser als Arcade, Start/Ziel ohne Gewinn, Blitzer nur
  leicht besser, Zieltor nachts leicht schlechter; B-04 drei Test-Wächter prüfen gegen die eigene Konstante; B-05 36 % der
  Stadtzäune fallen im Kurvenkorridor weg; B-06 lastabhängige Prüfungen; B-07 fremde Dateien; B-08 Einhängen 4,5 ms im
  Zeitraffer-Lauf.
- Leistung: `render()` GDScript bei normalem Tempo an den R6-Stellen 1,1–1,3 ms (Kopf) gegen 1,0–1,4 ms (Basis), Unterschied
  im Rauschen (±0,15 ms), Mittel bis auf einen Ausreißer unter dem Deck-Budget 1,5 ms.
- Gegen die Basis `6e48405` sieht nichts schlechter aus (Tankstelle nachts weiße statt oranger Lampen = Arcades Farbe,
  Zielbanner nachts heller, Blitz am Kopf neu).
- Für Testbuild 2: kein Blocker. B-01 sollte vorher entschieden werden (eine Zeile oder ein Kragträger).
