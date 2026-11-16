## 1. Befunde (nach Schwere)

### B-01 (mittel) – Fünf Grenzdächer schweben auf einer Seite
- **Wo:** `scripts/race3d/builders/border.gd` `build()` Zeile 420 (`if str(p[2]) != "front" and ctx.in_bend_corridor(zp, px): continue`)
  zusammen mit `pillar_plan()`.
- **Was:** Steht rechts ein Schild unter dem Dach, rückt Arcades vorderer Pfeiler als `front_out` nach außen – und fällt dann wie
  jeder Nicht-Arcade-Pfeiler weg, wenn er im Kurvenkorridor steht; der Endpfeiler ebenso. Ergebnis: **5 von 48 Grenzdächern
  ohne einen einzigen Pfeiler rechts**, wo Arcade zwei vordere Pfeiler zeichnet: `belgrad_sofia__belgrad` km 339,99,
  `belgrad_sofia__sofia` km 54,99, `wien_prag__prag` km 270,0, `bialystok_kaunas__kaunas` km 90,0, Testetappe km 64,98
  (gemessen, `scan/all.log`, Zeilen „border roof one-sided“). Das Dach hängt rechts frei in der Luft (Bilder 06
  und 30: Arcade zeichnet dort seinen weißen Pfeiler, Modern nichts). R6 meldet „4 von 48“ – es sind 5.
- **Nachstellen:** `godot --headless --path . -s <scan_all.gd>` bzw. Bild `tools/ab_shot.sh … --stage=dev_testetappe
  --from=dev_start --start-km=64.3 --start-speed=100 --shot-times=0.8,1.4,2.0 --hour=12`.
- **Lösung (Leitung, Vertragsfrage):** (a) `front_out` wie `front` von der Korridor-Regel ausnehmen – er ersetzt Arcades
  eigenen vorderen Pfeiler dieser Seite, den Arcade im Korridor ebenso zeichnet (eine Zeile:
  `if str(p[2]) != "front" and str(p[2]) != "front_out" and ctx.in_bend_corridor(zp, px):`); die F1-Prüfung oben zeigt, dass
  die äußeren Pfeiler fast nie ein Schild verdecken (2 Fälle ≥ 475 m). (b) Bleibt F7 streng: ein sichtbarer Kragträger
  (Fachwerk auf dem Dach von der getragenen Seite), damit das Dach nicht schwebt.

### B-02 (niedrig bis mittel) – Stützen am Dachende verdecken in Kurven Teile ferner Schilder (F1)
- **Wo:** `station.gd` `column_plan()` / `SIGN_SCAN_M := 120.0`; die Stütze `end` auf der Insel (nicht in Arcade).
- **Was:** Die Regel „ein Schild mehr als 120 m hinter der Stütze kann nur verdeckt werden, solange es über ~350 m entfernt
  ist“ gilt nur auf gerader Straße. In Kurven verdeckt die Endstütze netzweit in **1109 Stütze-Schild-Paaren** Teile einer
  Tafel, in **≈ 195 davon bei 6–14 px Tafelbreite**, bis 56 % aus 250–300 m (gemessen, `scan/f1_all.log`; z. B.
  `fulda_kassel__kassel` Dach km 77,34 → Entfernungstafel km 80,0; `prag_leipzig__prag` km 75,3–76,2 → Tunneltafel km 77,4).
  Arcades eigene vordere Pfeiler verdecken dieselben Tafeln zu anderen Zeitpunkten ebenso (Malreihenfolge) – Modern verdeckt
  also nicht neuartig, aber etwa doppelt so oft wie Arcade. Spieltechnisch klein (ferne Tafeln, Sekundenbruchteile).
- **Lösung:** in `columns_in_chunk()` (Hauptthread, `ctx.path` vorhanden) eine Sichtlinienprüfung wie `bin/scan_f1.gd`:
  von den Fahrspurmitten 55–400 m vor jeder Tafel bis 400 m hinter dem Dach; trifft eine Linie die Endstütze, wird sie
  `end_out`. Einfacher: `SIGN_SCAN_M` für die Endstütze auf 400 m.

### B-03 (mittel, Look) – Bei Nacht und an Start/Ziel/Blitzer kein Gewinn gegen Arcade
- **Wo:** Tankstelle nachts (Shop-Schein), `gantry.gd` (Stützen `STEEL`, Banner-Nachtbild `NIGHT_GLOW` 0,6), Blitzer-Stelle.
- **Was (angesehen, Abschnitt 5):** Tankstelle nachts gleichwertig, nicht besser (Arcades großer warmer Shop-Schein fehlt,
  Bilder 02/05); Ziel nachts leicht schlechter (dunkleres Rot, dunkle Stützen verschwinden, Bild 14); Start und Ziel bei Tag
  gleich (13–15); Blitzer nur leicht besser (Schein am Kopf sichtbar, 09b). Das Ziel „klar besser als Arcade“ ist hier nicht
  erreicht.
- **Lösung:** (a) Stützen der Tore hell lackiert (Arcade: weiß; z. B. `STEEL := Color("e6e8ea")`) oder beleuchtet, Banner
  nachts mit `NIGHT_GLOW` ≈ 0,8; ein Fachwerk-Riegel statt des Kastens würde Start/Ziel sichtbar aufwerten. (b) Tankstelle
  nachts: das Nachtbild des AS1b-Shops (Fenster und Leuchtband im Nachtlicht-Atlas, A-16) – Modell-Paket, nicht R6. (c) Blitzer:
  ein heller, kurzer Kegel des Blitzes auf die Fahrbahn (Ebene `lights` müsste Stärken je Bild lesen – R4).

### B-04 (niedrig) – Drei Regeln der neuen Unit-Tests prüfen gegen die eigene Konstante
- **Wo:** `tests/unit/race3d/test_structures.gd:144` (`StationB.CANOPY_H`), `:249` (`BorderB.ROOF_H`), `:358`
  (`CityB.LAMP_ENERGY`).
- **Was:** Mutation M03 (Dach 5,4 m), M06 (Grenzdach 5,8 m), M08 (Laterne 0,55) bleiben grün (gemessen). Die F1-Höhen sind
  heute richtig (5,6 / 6,0 m = Arcade), aber nicht bewacht.
- **Lösung:** Arcades Werte als Literale in den Test (5,6 m aus `RoadRenderer._fuel_structures`, 6,0 m aus `_border_cover`,
  Kegelmitte 0,55 × `lights` → `assert_near(CityB.LAMP_ENERGY * 0.55, 0.55, …)`).

### B-05 (niedrig, Leitungsfrage B-01 von FIX-M2) – 36 % der Stadtzäune fehlen
- **Wo:** `city.gd` `_fence()` (`if ctx.in_bend_corridor(zm, …): dropped`).
- **Was:** netzweit 28 937 von 80 942 Zaunstücken weggelassen (gemessen), Arcade zeichnet sie durchgehend. In der Stadt hat fast
  jede Kurve einen breiten Korridor. Fairness-seitig vertretbar (0,9–1,4 m hohe Mauern/Hecken können ein Auto aus 3,4 m
  Augenhöhe teilweise verdecken), aber sichtbar weniger als Arcade. Hängt an der offenen Leitungsfrage zum Korridor
  (FIX-M2 B-01); `city.gd` folgt einer Änderung von `in_bend_corridor()` automatisch.

### B-06 (niedrig) – Lastabhängige Zeitprüfungen im Gesamtlauf
- `check_attract.gd` „idle“ (0,93 s statt ≥ 1 s) und zwei Echtzeit-Audioprüfungen rot im Gesamtlauf, allein 6/6 grün auf Kopf
  und Basis (Attract). Nicht R6. Lösung (QA): Attract-„idle“ gegen die Spielzeit statt der Wanduhr messen (A-11).

### B-07 (niedrig, Zusammenführen) – Fremde Dateien
- `tests/golden/modern_slice.md5/.env` (Spalte W3 „–“; R4 und R5 ändern sie auch) und `tests/race3d/check_minimal_structures.gd`.
  Lösung: beim Zusammenführen (RINT-M2) `tools/golden.sh modern-make` einmal auf dem Gesamtstand; die zwei Zeilen in
  `check_minimal_structures.gd` übernehmen.

### B-08 (niedrig) – Einhängen über dem Deck-Budget, höhere Streamer-Spitzen im Zeitraffer
- `run_stage` DEV, `deck`, Zeitraffer 40 (gemessen): Chunk-Einhängen max 4,52 ms (Basis 2,39; Budget 3 ms), längstes
  `render()` 133,9 ms (Basis 52,7; R6 maß 347 gegen 145). Bei normalem Tempo kein messbarer Unterschied (Abschnitt 6.1).
- Lösung: auf dem Deck mit dem Leistungstest nachmessen; vorher die Einhängezeit je Builder messen (`ChunkStreamer._commit`
  zeitet heute nur das ganze Stück). Falls die Stadt-Stücke es sind: Latten/Pfosten/Stäbe der Zäune als ein MultiMesh je Art
  statt Einzelgeometrie (heute bis ~125 ms Bauzeit je Stadt-Stück im Werkzeug, gemessen).
