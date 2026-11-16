# Bericht FIX-R6 – Nacharbeit nach der Prüfung QA-R6 (Tankstelle, Grenze, Stadt, Start/Ziel, Blitzer)

- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-3`
- Branch: `worktree-wf_3b3101bc-877-3`, Sicherung `origin wip/v080-fix-r6` (nach jedem Commit gepusht, nie erzwungen)
- Basis: `c8b18d1` (Kopf von R6, `origin/wip/v080-r6`) per `git merge --ff-only`; kein Vorgänger dieses Laufs (weder
  `STAND.md` noch `wip/v080-fix-r6`)
- Code-Kopf `2c75af0`, Gate-Kopf `2b7dcc0` (dazu nur die Modern-Änderungsmelder)
- „gemessen“ = auf dieser VM gelaufen (headless bzw. Mesa llvmpipe unter Xvfb, `nice -n 10` – `QA_M2_FERTIG` lag –,
  eigenes absolutes `XDG_DATA_HOME` je Lauf, Last der Maschine 9–16); „gefolgert“ = aus Code, Daten oder Bildern
  geschlossen. Über echte Grafikkarten und das Steam Deck ist nichts gemessen; die Deck-Bilder sind die Voreinstellung
  `deck` auf llvmpipe.

## 0. Kurzfassung

**Alle Befunde von QA-R6 nachgestellt; B-01, B-02, B-04 behoben, B-03 an Start/Ziel und Grenze behoben, an der Tankstelle
bei Nacht nur teilweise (Modell-Frage), B-05–B-08 begründet nicht geändert bzw. gemessen.**

- **B-01 (mittel):** die 5 schwebenden Grenzdächer (QA hatte recht: 5, nicht 4) hängen jetzt an je zwei **Masten mit
  Zugstangen** über der Platte; nichts Neues in der Sichtschneise. QAs Ein-Zeilen-Vorschlag (äußerer Pfeiler in der
  Sichtschneise) habe ich gemessen und verworfen: er verdeckt an 3 der 5 Dächer 36–174 Sichtlinien zu Autos, die Arcades
  Pfeiler nicht verdeckt. Netzweit 0 schwebende Dächer.
- **B-02 (niedrig):** die Endstütze der Tankstellendächer wird gegen echte Sichtlinien (beide Seiten, 600 m, Kurven)
  geprüft: Verdeckungen ferner Tafeln netzweit **1109 → 38** Paare, mit Tafeln ≥ 6 px **195 → 5** (nur noch an 3
  Dächern, die sonst ohne Stütze wären). Hauptthread-Kosten verteilt (höchstens 1,1–6,7 ms je Stück, Basis 0,1–0,6 ms; gemessen unter Last).
- **B-03 (mittel, Look):** Start- und Zieltor mit weißen Stützen, **Fachwerkträger und drei Flutlichtern** (nachts
  Lichtkegel vor der Linie, Banner so rot wie Arcade) – bei Tag und vor allem bei Nacht **klar besser** als Arcade
  (vorher: kein Gewinn, nachts leicht schlechter). Grenzblende nachts heller. Tankstelle nachts: warmes Vorplatzlicht am
  Shop, aber weiter **nur gleichwertig** – Arcades leuchtende Gebäudefront braucht das Nachtbild des AS1b-Modells.
- **B-04:** die drei Test-Wächter prüfen gegen Arcades Literale; die Mutationen M03, M06, M08 sind jetzt rot.
- Gates siehe Abschnitt 2: Arcade bildgleich, Fairness-Gates grün, Render-Prüfungen 21 von 21 OK, `run_tests.sh`
  761 Tests grün bis auf die bekannte lastabhängige Echtzeit-Musikprüfung im zweiten Lauf (startet in Arcade; allein 2/2 grün).

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

## 2. Gates (gemessen)

Zwei Gate-Läufe: Lauf 1 auf `b185bb8` (Logs `m1/FIX-R6/gates/run1/`), danach habe ich die Hauptthread-Kosten der
Tankstelle gesenkt (`2c75af0`, gleiche Entscheidungen) und alles Nötige auf `2c75af0` wiederholt (Lauf 2, `gates/`).
Alle Läufe einzeln, `nice -n 10`, eigenes absolutes `XDG_DATA_HOME`, Last 9–17.

| Lauf (Befehl) | Stand | Ergebnis |
|---|---|---|
| `godot --headless --path . --import` | `2c75af0` | Exit 0, keine Fehlerzeile |
| `godot --headless --path . -s res://tests/check_scripts.gd` | `2c75af0` | 316 Skripte geprüft, 0 fehlerhaft |
| `tools/run_tests.sh` (ganzer Lauf 1 von 2) | `b185bb8` | **761 Tests, 0 fehlgeschlagen**, „Tests bestanden“ (944 s) – darunter `test_structures` 12/12, `test_props`, `test_far_ground_water`, `check_minimal_structures` (station, tore), Attract „idle“ OK, die Echtzeit-Audioprüfungen grün |
| `tools/run_tests.sh` (ganzer Lauf 2 von 2) | `2c75af0` | **761 Tests, 1 fehlgeschlagen**: `test_music_checks :: test_music_in_a_running_game` (Echtzeit-Musik nach „LOS!“, startet das Spiel mit `--graphics=arcade` – lädt keine Zeile von `scripts/race3d`); alles andere grün (959 s). In Lauf 1 grün; dieselbe Prüfung ist bei R6 und QA-R6 lastabhängig rot (B-06). Allein wiederholt: `tools/run_tests.sh test_music_checks` (Last 16) **2 von 2 OK**, „Tests bestanden“ |
| `tools/run_tests.sh test_structures` (Filter, nach jeder Code-Änderung) | `2c75af0` | 12 Tests, 0 fehlgeschlagen |
| `tools/golden.sh check` | `b185bb8` und `2c75af0` | beide Male **GOLDEN arcade: 20 von 20 identisch**, **GOLDEN arcade-ui: 17 von 17 identisch** |
| `tools/golden.sh modern-check` (Bilder behalten) | `2c75af0` | **GOLDEN modern: 5 von 6 identisch** – `modern_start_mittel` anders, gewollt (Starttor mit Fachwerk, weißen Stützen und Flutlichtern; Bild angesehen); `modern_s2_mittel` (Tankstelle km 14,8) unverändert; **modern-gles** OK (max. 2/255, PSNR 73,2 dB) |
| `tools/golden.sh modern-make` | `2c75af0` | Exit 0, 6 Hashes neu; nur `modern_start_mittel` geändert (derselbe Hash wie das behaltene Bild der Prüfung), Commit `2b7dcc0` |
| `tests/sim/modern_sight.gd -- --full` | `b185bb8` (Builder nicht beteiligt) | Exit 0: f1 0 Fälle bis 270 m (99 424 500 Stichproben), f1_lanes OK, f2 ≤ 0,596, f3 0 von 5923, f7 0 von 2 011 532, model OK |
| `tests/sim/modern_path_check.gd -- --full` | `b185bb8` | Exit 0: kleinster Abstand 267,6 m, Schleifen frühestens nach 2064 m |
| `tools/run_render_checks.sh arcade` + `modern` je Datei (`RENDER_CHECK_TIMEOUT=2400`) | `2c75af0` | **21 von 21 Dateien OK** (2 Arcade, 19 Modern), darunter `structures` (countdown [1,1,0]/[2,2,2]/[0,0,0], zieltor rot 50 % weiß 6 % schwarz 4 %, grenze weiß 63 % blau 20 % / Lichtband 1,00, blitz +0,44), `structures_licht` (tankstelle: Tankspur nachts 0,414 gegen Arcade 0,459 = 0,90 ×, stadt 0,490 gegen 0,501, schatten 4/4 bzw. 0/4), **`start_km0`** (Kamera ≤ 1,14 px, Auto 193×193 bei (544, 470) gegen 192×192 bei (544, 471)), **`light_base`**, **`terrain_cover`** (T1–T4, S1, C1, **K1** je 0,000 % Magenta) |
| Netz-Scans von QA-R6 (`scan_all.gd`, `scan_f1.gd`, headless) | `2c75af0` | 0 Skriptfehler; alle Zählungen (Inseln, Dächer, Blenden, Schriften, Preissäulen, Grenzen, Tore, Blitzer, Laternen) 0 Abweichungen; 0 schwebende Grenzdächer (10 Masten), 0 Dächer ohne Stütze; `station_end` 38 Paare (5 ≥ 6 px) |
| Mutationen M03/M06/M08 (`bin/mutate.sh`) | `ffca594` | alle drei rot |
| Ganzer Modern-Autopilot-Lauf DEV 21 Uhr, Xvfb, `deck` (Abschnitt 3) | `2c75af0` | 130 km, 0 Kollisionen, 0 Skriptfehler, `ERGEBNIS` gleich der Basis |

Dateibesitz: nur R6s Dateien (`builders/{border,station,gantry}.gd`, `tests/unit/race3d/test_structures.gd`,
`docs/renderer-modern-bauten.md`) und die Modern-Änderungsmelder `tests/golden/modern_slice.{md5,env}` (wie R6 –
gewollt geändert, B-07). Keine eingefrorene Datei, nichts von R4/R5 (`git diff --stat c8b18d1..HEAD`).

## 3. Leistung (gemessen auf dieser VM; Steam Deck und echte GPUs nicht gemessen)

### 3.1 Ganzer Lauf unter Xvfb, `deck`, 1280 × 800 (`run_stage.gd` DEV 21 Uhr, Saat 7, Zeitraffer 40), Kopf gegen Basis `c8b18d1`

| `perf_stats` | Kopf `2c75af0` Lauf 1 | Basis `c8b18d1` Lauf 1 | Kopf Lauf 2 | Basis Lauf 2 |
|---|---|---|---|---|
| Last der Maschine | 15–17 | 12–17 | 14–16 | 16 |
| `render()` ms Mittel / max | 7,10 / 138,7 | 5,93 / 66,1 | 6,23 / 258,1 | 5,76 / 78,8 |
| davon Hook `streamer` ms Mittel / max | 4,23 / 119,3 | 3,62 / 64,0 | 3,95 / 256,1 | 3,34 / 77,3 |
| Hooks `flares` / `lights` / `gantry` / `radar` ms Mittel | 0,59 / 0,27 / 0,007 / 0,017 | 0,16 / 0,28 / 0,009 / 0,010 | 0,17 / 0,25 / 0,008 / 0,008 | 0,14 / 0,26 / 0,009 / 0,004 |
| Chunk-Einhängen max (Hauptthread) | 6,61 ms | 6,67 ms | 8,96 ms | 44,28 ms |
| Chunk-Bau ms Mittel / max (Worker-Thread) | 9,0 / 197,6 | 6,1 / 50,1 | 10,5 / 211,5 | 10,4 / 260,9 |
| Draw Calls / Primitive / Schatten-Primitive (letztes Bild, Ziel) | 83 / 75 885 / 8 316 | 83 / 75 885 / 8 316 | 83 / 75 885 / 8 316 | 83 / 75 885 / 8 316 |
| Instanzen mit Instanz-Uniforms | 63 | 63 | 63 | 63 |
| Bildzeit Median / p95 ms (llvmpipe, Zeitraffer) | 991 / 1547 | 834 / 1447 | 923 / 1503 | 915 / 1525 |
| Ergebnis | 130 km, 0 Kollisionen, 0 Skriptfehler, `time_s` 376,85 | gleich | gleich | gleich |

Lesart (gemessen, ehrlich): Draw Calls, Primitive, Schatten-Primitive und Instanzen sind im letzten Bild gleich (gefolgert:
Fachwerk, Masten und Zugstangen gehören zum selben Netz ihres Builders – kein zusätzlicher Draw Call; im letzten Bild
steht das Zieltor schon hinter der Kamera). `render()` im Mittel +0,5 bzw.
+1,2 ms, fast ganz im Streamer (Zeitraffer 40: viele Stücke je Bild); das längste Bild war in beiden Paaren auf dem Kopf
länger (139 / 258 ms gegen 66 / 79 ms) – einzelne Spitzen unter Last 15–17 streuen stark (QA-R6 maß für `c8b18d1`
selbst 134 ms, R6 347 ms), eine Ursache in meinem Code habe ich nicht gefunden: die teuerste neue Arbeit auf dem
Hauptthread ist die Sichtlinienprüfung der Tankstelle mit höchstens 1–7 ms je Stück (3.2). Der `flares`-Hook war im
ersten Paar höher (0,59 ms), im zweiten gleich (0,17 gegen 0,14 ms) – Rauschen. Gefolgert: auf dem Deck und echten
GPUs mit dem Leistungstest nachmessen (Hinweis 5.3); das Starttor hat jetzt 1 162 statt 374 Dreiecke (gemessen, Kiel – Hamburg); sein Bau
und der der Masten laufen im Worker-Thread.

### 3.2 Hauptthread-Kosten von `collect()` (QAs `collect_time.gd`, Pfad 36 Stücke voraus wie im Spiel)

| `collect()` je Stück, Maximum | Kiel – Hamburg | Prag – Nürnberg | DEV |
|---|---|---|---|
| Tankstelle, Basis `c8b18d1` (zwei Läufe) | 0,17 / 0,14 ms | 0,22 / 0,19 ms | 0,34 / 0,60 ms |
| Tankstelle, erste Fassung `b185bb8` (alle Dächer einer Station in einem Stück) | 5,5 ms | 6,7 ms | 12,8 ms |
| Tankstelle, Kopf `2c75af0` (ein Dach voraus, nur nötige Kameras), drei Läufe | 1,2 / 1,2 / 1,1 ms | 3,9 / 3,3 / 4,3 ms | 3,1 / 3,9 / 6,7 ms |
| Grenze, Kopf `2c75af0` (Pfeiler für das ganze Dach) / Basis | 0,03 / 0,13 ms | 0,47 / 0,24 ms | 0,45 / 0,41 ms |

Lesart: die Sichtlinienprüfung der Endstützen kostet einmal je Dach 1–4 ms auf dem Hauptthread (Last 12); verteilt über
die Stücke vor der Station liegt das Maximum je Stück bei 1,1–6,7 ms (Last 10–12, stark streuend) gegen 0,1–0,6 ms der Basis. Gefolgert: auf dem Deck
ohne fremde Last kleiner; falls dort doch eine Spitze sichtbar wird, gehört die Prüfung in `prepare()` bzw. über mehrere
Bilder (Vertragsfrage 5.2 Nr. 2).

## 4. Bilder und Urteil gegen Arcade (eigene Bilder, gerendert und angesehen)

Alle mit `tools/ab_shot.sh` (gleicher Simulationszustand, links Arcade, rechts Modern), Modern „Hoch“ bei 1280 × 720,
die Deck-Bilder `--gfx-preset=deck` bei 1280 × 800; Mesa llvmpipe unter Xvfb, `nice -n 10` (gemessen). Die Argumente
stehen unter jedem Bildpaar; Basis-Argumente wie QA-R6 (`--weather=normal --vehicle=limousine --seed=11 --autopilot
--autopilot-refuel=never --traffic-warmup --no-countdown`). Dateien in `…/scratchpad/v080/deliver/FIX-R6/`.

| Datei | Ort | Urteil gegen Arcade (angesehen) |
|---|---|---|
| `01_dev_grenze_tag_mittel_masten.jpg` | DEV km 64,3 + 1,4 s, 12 Uhr | **besser**: das Dach liest sich als abgespannt – Mast links über dem Dach, zwei Zugstangen nach rechts, der zweite Mast hinten; Unterseite, Häuschen als Modelle. Arcade: zwei weiße Pfeiler rechts |
| `02_dev_grenze_tag_nah.jpg` | dieselbe Stelle + 2,0 s | **gleich bis besser**: aus der Nähe verdeckt die Blende die Zugstangen; rechts kein Pfeiler (dort steht in Arcade seiner hinter dem Schild), links der Mast über dem Dach; das Schild „Tankstelle 15 km“ ganz frei |
| `03/04_dev_grenze_nacht_*.jpg` | 21 Uhr | **gleich bis besser**: Lichtbänder, Häuschen mit warmen Fenstern, Masten und Zugstangen gegen den Nachthimmel; die Blende jetzt hellgrau statt grau – Arcades Blende bleibt heller |
| `05_dev_ziel_tag.jpg` | DEV km 129,4 + 2,5 s, 12 Uhr | **klar besser**: weiße Stützen wie Arcade, Fachwerkträger über dem Banner mit drei Flutlichtern – ein echtes Zieltor statt Arcades Balken mit Tafel |
| `06_dev_ziel_nacht.jpg` | 21 Uhr | **klar besser** (vorher leicht schlechter): Banner so rot wie Arcades, Stützen und Träger hell angestrahlt, Flutlichter leuchten, die Ziellinie liegt im Licht |
| `07_dev_start_tag_los.jpg` | DEV km 0, 0,6 s nach „LOS!“ | **besser**: Träger und Flutlichter über dem Startbanner, Lampen grün wie Arcade, Auto wie Arcade |
| `08/09_dev_start_nacht_*.jpg` | 21 Uhr, Countdown „3“ und „LOS!“ | **klar besser**: das Tor steht hell im Flutlicht, Startlinie beleuchtet, „START“ leuchtet (heller als Arcades graue Schrift) |
| `10_kh_ziel_tag.jpg` | Kiel – Hamburg km 94,2 + 1,8 s | **besser** (wie DEV) |
| `11_dev_tankstelle_tag.jpg` | DEV km 18,5 + 2,6 s | **besser** (unverändert gegen R6 bis auf die Endstützen nach Sichtlinien) |
| `12/13_dev_tankstelle_nacht_*.jpg` | 21 Uhr | **gleichwertig, nicht besser**: Dächer, Leuchtkästen und Zapfsäulen hell, ein warmer Lichtfleck vor dem Shop (neu); Arcades ganze, hell leuchtende Gebäudefront fehlt weiter (Modell AS1b) |
| `14/15_kh_tankstelle_km15_*.jpg` | Kiel – Hamburg km 13,4 (Tutorial-Stopp), 12 und 21 Uhr | Tag gleich bis besser; Nacht gleichwertig (wie DEV) |
| `16_deck_grenze_tag.jpg` | Deck 1280 × 800 | wie „Hoch“: Masten und Zugstangen sichtbar |
| `17_deck_tankstelle_nacht.jpg` | Deck | wie „Hoch“ |
| `18_deck_ziel_nacht.jpg` | Deck | wie „Hoch“: Zieltor im Flutlicht |
| `19_ausschnitt_grenze_masten_vorher_gekreuzt.jpg` | erste Fassung | die Zugstangen kreuzten sich am Mast – behoben (`STAY_T` 1,0 / 0,55) |
| `20_ausschnitt_grenze_masten_tag_nacht.jpg` | Endstand | Mast, Zugstangen, Randträger; nachts hellere Blende |
| `21_ausschnitt_zieltor_fachwerk.jpg` | Endstand | Fachwerk, Flutlichtgehäuse |

**Gesamturteil Look (ehrlich):** Start und Ziel sind jetzt bei Tag und vor allem bei Nacht klar besser als Arcade (QA:
„kein Gewinn“, nachts „leicht schlechter“). Die Grenze schwebt nicht mehr und ist bei Tag besser, nachts gleich bis
besser. Die Tankstelle bei Nacht bleibt **gleichwertig, nicht besser** – der Hebel ist das Nachtbild des Shop-Modells
(A-16), nicht R6s Code. Der Blitzer ist unverändert „leicht besser“ (QA). Stadt nicht angefasst (B-05: Leitungsfrage).

## 5. Abweichungen, Vertragsfragen, Hinweise

### 5.1 Abweichungen

1. **B-01 nicht mit QAs Ein-Zeilen-Vorschlag (a), sondern mit Masten und Zugstangen (b).** Begründung mit Messung in
   Abschnitt 1: der äußere vordere Pfeiler in der Sichtschneise verdeckt an 3 der 5 Dächer 36–174 Sichtlinien zu Autos,
   die Arcades Pfeiler nicht verdeckt; Brief-Entscheidung 7 und A-10 verlangen die strenge Lesart.
2. **Die Pfeiler-/Stützen-Entscheidung liegt jetzt auf dem Hauptthread in `collect()`** (vorher Sichtschneisen-Test in
   `build()`): nur so bekommt ein Dach, das über zwei Stücke reicht, eine Entscheidung, und ein Dach ohne Stütze lässt
   sich erkennen. `bend_corridor_at()` rechnet denselben Test wie `ChunkContext.in_bend_corridor()` aus Track und
   TerrainProfile (Unit-Test vergleicht beide an den DEV-Pfeilern).
3. **Mehr Hauptthread-Arbeit an Tankstellen:** die Sichtlinienprüfung kostet 1–4 ms je Dach (gemessen, Last 12); sie
   wird ein Dach voraus verteilt (höchstens 1,1–6,7 ms je Stück statt 0,1–0,6 ms auf der Basis). Gefolgert: auf echter
   Hardware ohne fremde Last deutlich weniger; auf dem Deck nachmessen.
4. **Neue Lampen über `renderer.add_lamps()`:** drei Flutlichter je Tor (mit Kegel) und ein Shop-Vorplatzlicht je
   Tankstellengebäude (mit Kegel). Sie konkurrieren um die 16 nächsten Kegelplätze der Ebene `lights` (R4) – an der
   Tankstelle mit den Dächern (Render-Prüfung `tankstelle` siehe Abschnitt 2).
5. **Modern-Änderungsmelder erneut geändert** (`tests/golden/modern_slice.md5/.env`, Spalte W3 „–“): Starttor mit Fachwerk
   und weißen Stützen (gewollt); siehe Abschnitt 2. Beim Zusammenführen ohnehin `modern-make` auf dem Gesamtstand (B-07).
6. **Notfall-Endstütze:** ein Dach, das sonst ohne Stütze wäre, behält seine Endstütze auch wenn sie eine ferne Tafel
   teilweise verdeckt (3 Dächer im Netz, Tafeln 6–7 px aus 195–240 m) – lieber das als ein schwebendes Dach.

### 5.2 Vertragsfragen

1. **Strukturen im Kurvenkorridor (F7).** D14 F7 nennt nur Gelände und dekorative Vegetation; die Brief-Entscheidung 7
   schließt Pfeiler und Stützen ein, Arcades eigene Pfeiler sind ausgenommen. Ich habe Arcades Pfeiler an Arcades Stelle
   stehen lassen und jeden anderen aus dem Korridor genommen; die Abspannung liegt ganz über der Platte. Bitte bestätigen,
   dass eine einseitig abgespannte Grenzstation (5 von 48) so gewollt ist – die Alternative (QA a) verdeckt messbar Autos.
2. **Kosten auf dem Hauptthread in `collect()`** (Abweichung 3): der Vertrag hat ein Budget für `render()` und das
   Einhängen, keines für `collect()`. Falls das Deck dort Spitzen zeigt, kann die Sichtlinienprüfung in `prepare()` für
   die ersten Stationen und danach über mehrere Bilder laufen (braucht einen Hook im Streamer – R4).

### 5.3 Hinweise für die Nächsten (genaue Änderungen in fremden Dateien)

1. **AS-Modellpaket (A-16):** `props/fuel_station` (und `props/customs_booth`) – Fenster und Leuchtband in den
   Nachtlicht-Atlas der Klasse `baked`; das ist der eine Hebel, der die Tankstelle bei Nacht klar besser als Arcade macht
   (Arcades Gebäude leuchtet als Ganzes).
2. **R4 `layers/lights.gd`:** Stärke je Bild aus den Einträgen lesen (wie `flares`), dann bekommt der Blitzer einen
   kurzen Lichtkegel auf der Fahrbahn (B-03 Blitzer).
3. **R4 `layers/flares.gd`:** Einträge mit Rolle `"on"` und `energy` 0 überspringen (QA-R6); optionale Schlüssel `glow`
   und `halo` (R6).
4. **R4 `docs/renderer-modern.md` §14.4/§14.5:** ein Satz mit Verweis auf `docs/renderer-modern-bauten.md`.
5. **RINT-M2:** `tools/golden.sh modern-make` einmal auf dem Gesamtstand (R4, R5, R6/FIX-R6 ändern `modern_slice.md5`).
6. **Leitung, B-05:** Stadtzäune im Kurvenkorridor folgen der Korridor-Entscheidung (FIX-M2 B-01); `city.gd` übernimmt
   eine Änderung von `in_bend_corridor()` von selbst.
7. **QA / später:** die Grenzpfeiler am Dachende (nicht Arcades) verdecken in Kurven noch 8 + 15 Tafel-Paare
   (`border_end` 8, davon 0 mit ≥ 6 px; `border_end_out` 15, davon 1; `scan_f1`); dieselbe Sichtlinienprüfung wie an der
   Tankstelle ließe sich dort übernehmen.

## 6. Commits (alle auf `origin wip/v080-fix-r6`)

| Commit | Inhalt |
|---|---|
| `ffca594` | B-01 Abspannung (`support_plan`, `supports_in_chunk`, Masten, Zugstangen, Randträger), B-02 erste Sichtlinienprüfung, B-04 Arcades Literale in den Tests |
| `fc312bf` | Stützen je Dach einmal entschieden (Zwischenspeicher), Sichtlinien beidseitig bis 600 m, Notfall-Endstütze; Tore mit Fachwerk, Flutlicht, weißen Stützen, Nachtbild 0,8 |
| `d5c5b52` | Zugstangen kreuzungsfrei, Kameras alle 5 m, Shop-Vorplatzlicht, hellere Grenzblende nachts, Doku |
| `b185bb8` | Kommentar und Doku: Zahl der Notfall-Endstützen |
| `2c75af0` | Sichtlinienprüfung billiger (nur nötige Kameras, Sinus statt Winkel, ein Dach voraus), gleiche Entscheidungen |
| `2b7dcc0` | Modern-Änderungsmelder neu (nur `modern_start_mittel`, gewollt), Doku-Zahlen der Hauptthread-Kosten |

Geänderte Dateien (alle im Besitz von R6 bzw. Leitungsausnahmen von R6): `scripts/race3d/builders/{border,station,
gantry}.gd`, `tests/unit/race3d/test_structures.gd`, `docs/renderer-modern-bauten.md`, `tests/golden/modern_slice.{md5,env}`.
Keine eingefrorene Arcade-Datei, keine Datei von R4/R5.

## 7. Werkzeuge und Rohdaten (Scratch, nicht committet)

`…/scratchpad/v080/m1/FIX-R6/`: `bin/border_probe.gd` (Pfeiler und Sichtlinien zu Autos je Grenzdach), `bin/scan_all.gd`
und `bin/scan_f1.gd` (Kopien von QA-R6, `scan_all` zählt Masten), `bin/canopy_time.gd` und `bin/collect_time.gd`
(Hauptthread-Kosten), `bin/mutate.sh` (B-04), `bin/shots1.sh`, `bin/shots2.sh`, `bin/gates.sh` (Gate-Kette, neu startbar);
Logs in `logs/`, `gates/` (Lauf 1 auf `b185bb8` in `gates/run1/`), `perf/`; Einzelbilder in `shots/`.
