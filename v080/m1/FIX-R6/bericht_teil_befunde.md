## 1. Befunde von QA-R6 – nachgestellt, entschieden, behoben

### B-01 (mittel) – Grenzdächer schweben auf einer Seite: **nachgestellt, behoben (Abspannung)**

- **Nachgestellt (gemessen):** eigene Sonde `m1/FIX-R6/bin/border_probe.gd` über alle 130 Richtungen: genau die 5 Dächer
  der Prüfung (`belgrad_sofia__belgrad` km 339,99, `belgrad_sofia__sofia` km 54,99, `wien_prag__prag` km 270,0,
  `bialystok_kaunas__kaunas` km 90,0, Testetappe km 64,98) stehen rechts auf keinem Pfeiler – QA hatte recht (5, nicht 4).
  Ursache wie beschrieben: unter dem Dach steht rechts ein Schild → Arcades vorderer Pfeiler rückt als `front_out` nach
  außen → in der Sichtschneise der Rechtskurve fällt er weg, der Endpfeiler ebenso.
- **Entscheidung (Vertrag, F1/F7 streng):** Leitungsentscheidung 7 des Briefs („… must not stand in a bend's sight
  corridor (F7)“), A-10 („F7 behält seine strenge Lesart“) und FIX-M2 B-01 (auch Felsen und Häuser im Korridor verdecken
  Autos) sprechen gegen QAs Option (a). Gemessen mit der Sonde (Kamera 5–300 m vor dem Pfeiler in jeder Spur, Auto
  bis 270 m voraus, Sichtlinie gegen den Pfeilerquerschnitt): ein `front_out` in der Sichtschneise verdeckt an 3 der 5
  Dächer **36, 167 und 174 Sichtlinien zu Autos, die Arcades eigener Pfeiler nicht verdeckt** (Arcades Pfeiler verdeckt
  dort 211, 203, 221 andere). Er ist also nicht „Arcades Pfeiler an anderer Stelle“, sondern eine neue Verdeckung –
  Option (a) verworfen. Gewählt: QAs Option (b) in der Form einer **Abspannung**.
- **Behoben:** `border.gd` entscheidet die Pfeiler eines Dachs jetzt einmal für das ganze Dach auf dem Hauptthread
  (`supports_in_chunk()` in `collect()`, `support_plan()` rein): Arcades vordere Pfeiler stehen immer, alle anderen nur
  außerhalb der Sichtschneise (`bend_corridor_at()` – derselbe Test wie `ChunkContext.in_bend_corridor()`, für jede
  Reihe; Unit-Test vergleicht beide). Bleibt eine Seite ohne Pfeiler, werden die Pfeiler der getragenen Seite zu **Masten
  bis 13 m**; von jedem Mastkopf laufen zwei Zugstangen über die Platte (die obere zur freien Kante, die untere auf 55 %
  des Weges – sie kreuzen sich nicht, eigener Bildbefund an der ersten Fassung), die äußere auf einen **Stahl-Randträger**
  auf der Platte entlang der freien Seite. Alles davon liegt **über der Platte (6,8 m)**: nichts Neues in der
  Sichtschneise; eine Sichtlinie aus 3,4 m Augenhöhe, die es erreichen könnte, müsste durch die Platte.
- **Nachweis (gemessen):** Netz-Scan von QA (`scan_all.gd`, meine Kopie zählt Masten): **0 schwebende Dächer**, die 5
  Dächer hängen an je 2 Masten (10 Masten); Pfeiler je Dach {2: 5, 3: 17, 4: 26}; alle Zählungen von Dach, Blende,
  Schrift unverändert 0 Abweichungen. Unit-Tests: `test_border_support_plan` (neu), `test_border_station_of_the_test_stage`
  (DEV: rechts frei, links 2 Masten; in der Sichtschneise unter 6 m nur Arcades vordere Pfeiler; `bend_corridor_at` =
  `in_bend_corridor`). Bilder 01–04, 16, 19, 20.
- **Look (angesehen):** aus 50–200 m liest sich das Dach klar als abgespannt (Mast links, Zugstangen über dem Dach,
  Bild 01/03/16); aus nächster Nähe (Bild 02) verdeckt die Blende die Zugstangen – dort sieht man links den Mast über dem
  Dach, rechts weiterhin keinen Pfeiler. Kein Schweben mehr ohne erkennbaren Grund, aber auch kein Pfeiler wie bei
  Arcade an dieser Stelle.

### B-02 (niedrig) – Endstützen der Tankstelle verdecken in Kurven ferne Tafeln: **nachgestellt, behoben**

- **Nachgestellt (gemessen):** QAs `scan_f1.gd` auf `c8b18d1`: `station_end` 1109 Paare, 195 davon mit Tafeln ≥ 6 px –
  wie gemeldet. Dazu ein eigener Fund in den ersten Läufen: auch Tafeln auf der **linken** Seite werden in S-Kurven
  verdeckt (`prag_nuernberg__prag` km 233,3 → Leitpfeile links).
- **Behoben:** `station.gd` `canopy_columns()` entscheidet die Stützen eines Dachs einmal auf dem Hauptthread (in
  `collect()`, je Etappe zwischengespeichert, `_plans`): die Endstütze (nicht in Arcade) wird gegen echte Sichtlinien
  geprüft (`end_column_hides()`: Spurmitten und offene Tankspur, Kameras alle 5 m 55–600 m vor jeder Tafel **beider
  Seiten** bis 600 m hinter dem Dach, Weltkoordinaten des `RoadPath3D`, Winkelvergleich gegen den Querschnitt + 0,1 m).
  Sie steht auf der Insel, wenn sie so keine Tafel verdeckt, sonst außen (`end_out`), sonst gar nicht. Ein Dach, das so
  ohne jede Stütze bliebe, behält seine Endstütze auf der Insel (lieber als zu schweben). Die Sichtschneise der äußeren
  Stützen wird ebenfalls dort entschieden (vorher in `build()`; so gibt es keine Dächer ohne Stütze mehr, die erste
  Fassung hatte 3).
- **Nachweis (gemessen, `scan_f1.gd` von QA unverändert):** `station_end` **1109 → 38** Paare, mit Tafeln ≥ 6 px
  **195 → 5**; `station_end_out` 55 → 0. Die 5 übrigen Paare liegen an genau 3 Dächern (`prag_leipzig__prag` km 148,08,
  `prag_nuernberg__prag` km 233,13, `sibiu_timisoara__timisoara` km 148,98) – den Notfall-Endstützen von Dächern, die
  sonst ohne Stütze wären (Tafeln 6–7 px aus 195–240 m). `scan_all`: 0 Dächer ohne Stütze; Dächer auf einer Stütze
  288 → 527 (Arcade hat je Dach genau eine). Unit-Test `test_station_end_column_lines_of_sight` (neu: gerade Strecke
  verdeckt nicht, Rechtskurve schon, Linkskurve nicht; keine Endstütze von Kiel – Hamburg und DEV verdeckt eine Tafel;
  kein Dach ohne Stütze).
- **Kosten:** `collect()` der Tankstelle auf dem Hauptthread – siehe Abschnitt 3 (Werkzeug `collect_time.gd` von QA).

### B-03 (mittel, Look) – Nachts und an Start/Ziel kein Gewinn: **teilweise behoben**

- **Start- und Zieltor (behoben):** Stützen weiß lackiert wie Arcades Balken (`STEEL` e9ebee), bis 7,9 m, 0,6 m tief;
  ein **Fachwerkträger** 7,0–7,9 m über dem Banner (vier Gurte, Pfosten und Diagonalen alle 1,5 m); drei **Flutlichter**
  auf der Vorderseite des Trägers – nachts leuchten die Gläser (Kanal 12), ihr Licht fällt über `renderer.add_lamps()`
  (Rolle `lights`, Reichweite 12 m, Stärke 0,8, nach vorn-unten gerichtet) als Kegel etwa 5 m vor die Linie; Stützen und
  Träger nachts leicht angestrahlt (Kanal 14, 0,3). Banner-Nachtbild 0,8 statt 0,6 (QA: Rot nachts dunkler als Arcade).
  Alles Neue liegt über Arcades Banner-Oberkante (7,0 m): was Arcade unter dem Banner zeigt, bleibt sichtbar (F1).
  Bilder 05–10, 18, 21.
- **Grenze nachts:** Blende der Grenze nachts heller (Weiß 0,5 statt 0,36 im Nachtbild) – näher an Arcades weißer Blende
  (Bild 03/04).
- **Tankstelle nachts (teilweise):** warmes Licht unter dem Vordach des Shops mit Lichtkegel 11 m (Rolle `lights`): ein
  warmer Fleck vor dem Shop (Bilder 12, 13, 15, 17). Arcades ganze hell leuchtende Gebäudefront fehlt weiter – sie hängt
  am Nachtbild des AS1b-Modells `props/fuel_station` (Fenster und Leuchtband im Nachtlicht-Atlas, A-16), nicht an R6s
  Dateien. **Offen.**
- **Blitzer (nicht geändert):** ein Lichtkegel des Blitzes auf der Fahrbahn bräuchte Stärken je Bild in der Ebene
  `lights` (R4). **Offen**, Hinweis an R4.

### B-04 (niedrig) – Test-Wächter gegen die eigene Konstante: **behoben**

`test_structures.gd` prüft gegen Arcades Literale: `ARCADE_CANOPY_H` 5,6 m (`RoadRenderer._fuel_structures`),
`ARCADE_ROOF_H` 6,0 m (`_border_cover`), Kegelmitte `energy × 0,55` (`layers/lights.gd` POOL_LEVEL) = 0,55 (Arcades
Straßenlaterne). Mutationen nachgestellt (gemessen, `m1/FIX-R6/bin/mutate.sh`): **M03 (Dach 5,4 m), M06 (Grenzdach
5,8 m), M08 (Laterne 0,55) – alle drei jetzt rot** (je 1 von 11 Tests), danach Arbeitsbaum zurückgesetzt.

### B-05 (niedrig) – 36 % der Stadtzäune fallen in Kurvenkorridoren weg: **nicht geändert (Leitungsfrage)**

Folgt der offenen Korridor-Entscheidung (FIX-M2 B-01, A-10: strenge Lesart bis Zwischenstand 2); `city.gd` übernimmt
eine Änderung von `in_bend_corridor()` von selbst. Nichts zu tun in R6s Dateien.

### B-06 (niedrig) – lastabhängige Zeitprüfungen: **nicht R6** – Ergebnis meines Gesamtlaufs in Abschnitt 2.

### B-07 (niedrig) – fremde Dateien: **bleibt ein Hinweis für RINT-M2**

`tests/golden/modern_slice.md5/.env` ändere ich erneut (gewollt, Abschnitt 2); R4 und R5 tun es auch → beim
Zusammenführen einmal `tools/golden.sh modern-make` auf dem Gesamtstand. `check_minimal_structures.gd` unverändert seit R6.

### B-08 (niedrig) – Einhängen über dem Deck-Budget im Zeitraffer: **gemessen, nicht geändert** – Abschnitt 3.
