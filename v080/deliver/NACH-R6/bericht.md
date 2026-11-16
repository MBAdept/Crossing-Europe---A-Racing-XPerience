# Bericht NACH-R6 – Nachprüfung der Nacharbeit FIX-R6 (Kopf `2b7dcc0`)

- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4` (per `git merge --ff-only
  2b7dcc0`, **keine Commits, kein Push, kein eigener Branch für andere**); Arbeitsbaum am Ende sauber (`git status` leer).
- Basis zum Vergleich: `c8b18d1` (Kopf von R6). Für die Basis-Bilder habe ich nur die drei Builder-Dateien von `c8b18d1`
  vorübergehend in den Arbeitsbaum gelegt (`git diff --stat c8b18d1..2b7dcc0`: sonst ändert sich zwischen beiden nichts,
  was das Spiel lädt) und danach den Kopf wiederhergestellt.
- „gemessen“ = auf dieser VM gelaufen (Mesa llvmpipe unter Xvfb bzw. headless, `nice -n 10`, `QA_M2_FERTIG` lag, Last
  11–15, eigenes absolutes `XDG_DATA_HOME` je Lauf); „gefolgert“ = aus Code, Daten oder Bildern geschlossen. Über echte
  Grafikkarten und das Steam Deck ist nichts gemessen.
- Werkzeuge und Rohdaten: `…/scratchpad/v080/m1/NACH-R6/` (`bin/`, `logs/`, `shots/`); Bilder hier im Ordner.

## 0. Kurzfassung

| Befund | Urteil | Kern |
|---|---|---|
| **B-01** Grenzdach schwebt (mittel) | **behoben** (Look-Rest) | Netz-Scan: 0 Dächer ohne Halt, die 5 Dächer hängen an je 2 Masten; Arcades Werte unverändert. Aus 50–600 m liest sich das Dach klar als abgespannt; aus den letzten ~40 m verdeckt die Blende die Zugstangen, rechts steht dann sichtbar nichts (Arcade: ein Pfeiler). |
| **B-03** Look gegen Arcade (mittel) | **teilweise** | Start- und Zieltor bei Tag und Nacht **klar besser** als Arcade (bestätigt). Grenze nachts gleich bis besser, Blende weiter dunkler als Arcades. **Tankstelle nachts nicht besser** als Arcade (Shop-Bereich gemessen gleich hell wie die Basis; Arcades leuchtender Shop fehlt). Blitzer unverändert. |
| B-02 Endstützen (von FIX-R6 mit erledigt) | **behoben** (Rest offen gelegt) | `scan_f1`: `station_end` 38 Paare, 5 mit Tafeln ≥ 6 px an 3 Notfall-Dächern – genau wie gemeldet. |
| B-04 Test-Wächter (von FIX-R6 mit erledigt) | **behoben** | Mutationen M03, M06, M08 je rot (1 von 12, der richtige Test), danach sauber. |

Neue Befunde (Abschnitt 3): N-01 Stützen-Entscheidung hängt vom Startpunkt ab (43 von 1909 Dächern bei spätem Start,
nur Optik); N-02 Hauptthread-Kosten in `collect()` (gemessen bis 3,2 ms je Stück, Vertrag: „cheap extra snapshot“);
N-03 Look-Rest der Grenze aus der Nähe; N-04 Notfall-Endstütze verdeckt eine Kurventafel zu 89 % aus 210 m.
Kein Befund gegen Fairness-Gates, Arcade-Identität oder Dateibesitz.

Gates: alle grün (Abschnitt 4) – Arcade 20/20 und 17/17 identisch, Render-Prüfungen der geänderten Dateien und der Fixes des ersten Testbuilds OK, Unit-Tests grün.

## 1. Diff `c8b18d1..2b7dcc0` – Dateien, Besitz, Nebenwirkungen

| Datei | Besitz (W3, A-8) | Bemerkung |
|---|---|---|
| `scripts/race3d/builders/border.gd` | R6 | `supports_in_chunk()` / `support_plan()` (Masten, Zugstangen, Randträger), Sichtschneise jetzt in `collect()`; Nachtblende 0,36 → 0,5 |
| `scripts/race3d/builders/station.gd` | R6 | `canopy_columns()`, `signs_behind()`, `end_column_hides()`, `bend_corridor_at()`, `paved_edge_at()`, Cache `_plans`, Shop-Vorplatzlicht |
| `scripts/race3d/builders/gantry.gd` | R6 | weiße Stützen bis 7,9 m (0,6 m tief), Fachwerk, 3 Flutlichter je Tor über `add_lamps`, Nachtbild 0,8 |
| `tests/unit/race3d/test_structures.gd` | R6 | Arcade-Literale, neue Tests `test_station_end_column_lines_of_sight`, `test_border_support_plan` |
| `docs/renderer-modern-bauten.md` | R6 | Doku der Änderungen |
| `tests/golden/modern_slice.{md5,env}` | geteilt (W3 „–“) | nur `modern_start_mittel` neu (gewollt: Starttor). R4/R5 ändern dieselbe Datei → RINT-M2: `modern-make` auf dem Gesamtstand |

- **Keine eingefrorene Arcade-Datei**, nichts von R4/R5, kein Kernel, keine Shader (gemessen: `git diff --stat`).
- **Sichtschneise in `collect()` statt `build()`** (gelesen): `Station.bend_corridor_at()` rechnet mit denselben Größen
  wie `ChunkContext.in_bend_corridor()` (`rows_edge` aus `s.lanes`/`s.fuel_lane`, `TerrainProfile.corridor_width()` =
  die `corridor`-Spalte, die `ChunkContext.capture()` aus `TerrainProfile.rows()` kopiert, `corridor_min_m − shoulder_w`);
  der Unit-Test vergleicht beide an den DEV-Pfeilern ±0,3/1,5/4 m – grün. `RoadPath3D.clearance()` erweitert den Pfad
  selbst (`ensure`), die Korridorbreite hängt also nicht davon ab, wann entschieden wird.
- **Pfadfenster** (gelesen, `chunk_streamer.gd`): der Pfad reicht im Spiel bis Kamera + 3,5 km (`_ahead_m()`); ein Dach
  wird höchstens `load_path_m` + 96 + 600 m voraus entschieden, die Tafeln bis 600 m dahinter liegen also immer im Pfad.
  **Hinter** dem Startpunkt fehlen dagegen Kameras (Pfad ab Start − `keep_behind_m` 150 m) → Befund N-01.
- **Neue Lampen**: 3 Flutlichter je Tor (Rolle `lights`, Reichweite 12 m, Stärke 0,8) und ein Vorplatzlicht je Shop
  (11 m, 1,1). Die Kegel der Ebene `lights` skalieren mit `palette.lights` (gelesen: `lights.gd` `_update_pools`) – bei
  Tag aus. Der Tankstellen-Kegel-Test (`structures_licht`) bleibt beim Wert der Basis (Abschnitt 4).
- **Starttor**: 1 162 statt 374 Dreiecke (Angabe FIX-R6), Stützen jetzt 0,6 statt 0,3 m tief. Für F1 gefolgert
  unerheblich (Stützen außerhalb der Bankette wie Arcades Balken; aus 100 m Abstand und 5 m Seitenversatz wächst die
  Ansichtsbreite um ~3 cm); `scan_f1` erfasst Tore nicht – nicht gemessen.
- Kleinigkeit: Kommentar in `station.gd` („2–4.5 ms per canopy“) und Doku („1–4 ms je Dach“) nennen verschiedene Spannen.

## 2. Befunde von QA-R6 – nachgestellt auf `2b7dcc0`

### B-01 (mittel) – Grenzdach schwebt auf einer Seite → **behoben**, Look-Rest aus der Nähe

- **Netz (gemessen, `scan_all.gd` von QA-R6 in der Fassung von FIX-R6, headless, 75 s):** 48 Grenzen, alle Zählungen
  (Dach, Blende, Schrift, Pfeiler vorn, Inseln, Dächer, Laternen, Tore, Blitzer) **0 Abweichungen**; `roofs_no_pillar` 0,
  `roofs_no_left` 0, `roofs_no_right` 5 – genau die 5 Dächer des Befunds, jedes mit **2 Masten** auf der linken Seite
  (`masts` 10): belgrad_sofia__belgrad km 339,99, belgrad_sofia__sofia km 54,99, wien_prag__prag km 270,0,
  bialystok_kaunas__kaunas km 90,0, DEV km 64,98. Pfeiler je Dach {2: 5, 3: 17, 4: 26} wie gemeldet.
- **Regeln (gelesen):** `support_plan()` lässt Arcades `front` immer stehen, jeden anderen Pfeiler nur außerhalb der
  Sichtschneise; bleibt eine Seite leer, werden die Pfeiler der anderen Seite zu Masten (bis 13 m), Zugstangen und
  Randträger liegen über der Platte (6,8 m). Unit-Test `test_border_support_plan` und DEV-Test (rechts frei, links
  2 Masten, in der Sichtschneise unter 6 m nur Arcades vordere Pfeiler) grün. F7 bleibt streng – gegen QAs Option (a)
  hat FIX-R6 gemessen argumentiert (36–174 verdeckte Sichtlinien zu Autos); das habe ich nicht nachgemessen, die
  Entscheidung ist vertragskonform (A-10 strenge Lesart).
- **Bilder (angesehen, gegen Arcade und Basis):** `01`, `03`, `05`, `07`: aus 600–50 m steht links der Mast über dem Dach,
  zwei Zugstangen laufen sichtbar zur rechten Kante – das Dach liest sich als abgespannt, nicht mehr als schwebend
  (Basis `03` Mitte: rechts nichts, schwebt). `02`, `04`, `08` (letzte ~40 m): die Blende (6,0–7,6 m) verdeckt Zugstangen
  und Randträger, rechts unter dem Dach steht sichtbar **nichts**, wo Arcade seinen weißen Pfeiler zeigt (DEV: hinter dem
  Schild „Tankstelle 15 km“; Prag: rechts außen). Am rechten oberen Ende der Blende ist das Ende einer Zugstange als
  kleiner gestreifter Fleck zu sehen (`04`, gefolgert: die Stange sinkt dort unter die Blendenoberkante). → Befund N-03.

### B-03 (mittel) – „klar besser als Arcade“ nur bei Tag → **teilweise**

Alle Bilder mit `tools/ab_shot.sh` (Arcade | Modern „Hoch“), Dreierbilder Arcade | Modern Basis `c8b18d1` | Modern Kopf
`2b7dcc0` (gleiche Argumente, gleicher Simulationszustand), 1280 × 720, angesehen:

| Ort | Bild | Urteil (Kopf gegen Arcade; gegen Basis) |
|---|---|---|
| Zieltor DEV km 129,4, 12 Uhr | `09` | **klar besser**: weiße Stützen wie Arcade, Fachwerkträger mit Flutlichtgehäusen über dem Banner, Banner wie Arcade |
| Zieltor DEV, 21 Uhr | `10` | **klar besser** (Basis: leicht schlechter als Arcade – graue Stützen verschwinden): Banner so rot wie Arcade, Stützen und Träger hell angestrahlt, Ziellinie im Licht |
| Starttor DEV km 0, 21 Uhr, Countdown „3“ und „LOS!“ | `11`, `12` | **klar besser**: Tor im Flutlicht, Startlinie und Fahrbahn davor beleuchtet, „START“ leuchtet, Lampen rot → grün wie Arcade, Auto wie Arcade |
| Grenze DEV, 21 Uhr | `06` | **gleich bis besser**: Masten und Zugstangen gegen den Himmel, Häuschen mit warmen Fenstern, Lichtbänder; die Blende ist heller als in der Basis, aber weiter deutlich dunkler/gelblicher als Arcades weiße Blende |
| Tankstelle DEV km 18,5–19,4, 21 Uhr | `13`, `14`, `15` | **gleichwertig, nicht besser**: Dächer, Leuchtkästen, Zapfsäulen, Shopfenster hell; Arcades großer warmer Schein des Shops fehlt. Der neue warme Vorplatzfleck ist im Bild kaum zu sehen: Shop-Bereich (Bild 01, x 720–1280, y 200–400) Leuchtdichte Mittel/p95 **Kopf 0,263 / 0,749, Basis 0,266 / 0,741, Arcade 0,296 / 0,957** (gemessen) |
| Blitzer | – | nicht neu gerendert: `radar.gd` ist unverändert (Diff), Urteil von QA-R6 („leicht besser“) gilt weiter |

Damit gilt „klar besser“ jetzt für Start und Ziel (Tag und Nacht), die Grenze bei Tag und die Stadt (unverändert, QA-R6);
**nicht** für die Tankstelle bei Nacht und nicht für den Blitzer. Der Hebel für die Tankstelle liegt im Modell
(`props/fuel_station` Nachtlicht-Atlas, A-16), nicht in R6s Dateien – Hinweis von FIX-R6 bestätigt.

### B-02 (niedrig, von FIX-R6 mit erledigt) – Endstützen in Kurven → **behoben**, Rest offen gelegt

- `scan_f1.gd` (QA-R6, unverändert, headless 78 s, gemessen): `station_end` **38** Paare, davon **5 mit Tafeln ≥ 6 px**
  – alle an den 3 Notfall-Dächern (prag_leipzig__prag km 148,2: „curve“ zu **89 %** aus 210 m, 6 px;
  sibiu_timisoara__timisoara km 149,1: 44 % aus 195 m, 7 px; prag_nuernberg__prag km 233,3: drei Leitpfeile links,
  33–56 % aus 215–240 m, 6 px); `station_end_out` 0. Das deckt sich Zahl für Zahl mit FIX-R6 (vorher 1109 / 195).
- `scan_all`: `canopies_no_column` 0, `canopies_one_column` 527 (Arcade hat je Dach genau eine).
- Unit-Test `test_station_end_column_lines_of_sight` grün (gerade/rechts/links, kein Dach ohne Stütze, keine Endstütze
  von Kiel – Hamburg und DEV verdeckt eine Tafel – Notfall-Dächer ausgenommen).

### B-04 (niedrig, von FIX-R6 mit erledigt) – Test-Wächter → **behoben**

`bin/mutate.py` (gemessen, je Mutation `tools/run_tests.sh test_structures`, danach `git checkout` der Datei):
M03 `CANOPY_H` 5,6 → 5,4: rot in `test_station_on_the_fuel_lane_of_the_slice_stage`; M06 `ROOF_H` 6,0 → 5,8: rot in
`test_border_station_of_the_test_stage`; M08 `LAMP_ENERGY` 1,0 → 0,55: rot in
`test_city_lights_every_33_m_alternating_with_pools` – je 1 von 12; Arbeitsbaum danach sauber.

## 3. Neue Befunde

**N-01 (niedrig) – Die Stützen eines Tankstellendachs hängen vom Startpunkt des Rennens ab.**
`end_column_hides()` überspringt Kameras, die der `RoadPath3D` nicht hält; im Spiel beginnt der Pfad bei
Start − 150 m (`ChunkStreamer._restart`). Eigene Sonde `bin/startdep.gd` (headless, alle 130 Richtungen, gemessen): bei
einem Start 100 / 300 / 500 m vor dem Dach entscheidet `canopy_columns()` an **40 / 3 / 0 von 1909 Dächern** anders als
bei einem Rennen ab km 0 – immer eine zusätzliche Endstütze (`end` oder `end_out`), die ab km 0 wegen einer Sichtlinie
weggefallen wäre. Fairness: gefolgert unberührt (die fehlenden Kameras liegen vor dem Startpunkt, dort fährt der Spieler
nie). Folge: dieselbe Station sieht je nach Startpunkt anders aus – das trifft A/B-Bilder, Goldens und Prüfbilder, die
kurz vor einer Station starten. Abhilfe: Kameras vor `p.first` als „verdeckt“ werten (konservativ) oder die Entscheidung
aus einem eigenen, vom Fenster unabhängigen Pfad rechnen.

**N-02 (niedrig, Vertragsfrage) – Sichtlinienprüfung auf dem Hauptthread.** Der Vertrag (§4.5.5, `ChunkBuilder.collect`)
sieht „main thread: cheap extra snapshot“ vor. QAs `collect_time.gd` (gemessen, DEV, Pfad 36 Stücke voraus, Last ~12):
Tankstelle **max 3,22 ms** je Stück (km 12,48: ein Dach voraus entschieden), Mittel 0,14 ms; Grenze max 0,48 ms
(FIX-R6 auf der Basis: 0,34/0,60 ms, Kopf 3,1–6,7 ms). Gefolgert: auf dem Deck ohne Fremdlast kleiner, aber dieselbe
Größenordnung wie das Einhäng-Budget (3 ms). Bitte Leitung: Budget für `collect()` festlegen oder die Prüfung über Bilder
verteilen bzw. in `prepare()` vorziehen (braucht einen Streamer-Hook, R4).

**N-03 (niedrig, Look) – Abgespanntes Grenzdach aus der Nähe.** Aus den letzten ~40 m vor dem Dach (`02`, `04`, `08`)
ist rechts keine Stütze zu sehen; die Zugstangen verschwinden hinter der Blende. Ein kurzer Stahlträger unter der freien
Dachkante bzw. ein sichtbarer Randträger an der Blendenoberkante (über 7,6 m) würde den Halt auch aus der Nähe zeigen –
alles über der Platte, F7 unberührt.

**N-04 (niedrig, F1-Rest, offen gelegt von FIX-R6) – Notfall-Endstütze verdeckt eine Kurventafel.** An
prag_leipzig__prag km 148,2 verdeckt die Notfall-Endstütze (Arcade hat dort keine) eine „curve“-Tafel aus 210 m zu
89 % (6 px; `scan_f1` meldet je Paar die schlimmste Kamera – 210 m). Alternative für diese
3 Dächer: unter den Kandidaten den mit der kleinsten Verdeckung wählen statt fest der Insel.

## 4. Gates (gemessen, auf `2b7dcc0`, Arbeitsbaum sauber)

| Lauf | Ergebnis |
|---|---|
| `godot --headless --path . --import` | Exit 0 |
| `godot --headless --path . -s res://tests/check_scripts.gd` | 316 Skripte geprüft, 0 fehlerhaft |
| `tools/run_tests.sh test_structures` | 12 Tests, 0 fehlgeschlagen |
| `tools/run_tests.sh test_props` | 12 Tests, 0 fehlgeschlagen (Fix des ersten Testbuilds) |
| `tools/run_tests.sh test_far_ground_water` | 4 Tests, 0 fehlgeschlagen (Fix des ersten Testbuilds) |
| `tools/run_tests.sh check_minimal_structures` | CHECKS OK: tunnel, station (34 Insel-, 23 Dachsegmente, 5 Blenden, 33 Lampen), tore, wahrzeichen, bruecke |
| Mutationen M03/M06/M08 | alle drei rot, danach sauber |
| `scan_f1.gd`, `scan_all.gd` (QA-R6), `startdep.gd`, `collect_time.gd` (headless) | 0 Skriptfehler; Zahlen in Abschnitt 2/3 |
| `tools/run_render_checks.sh modern check_structures.gd` | OK (513 s): countdown [1,1,0]/[2,2,2]/[0,0,0], zieltor rot 50 % weiß 6 % schwarz 4 %, grenze weiß 63 % blau 20 % / Lichtband 1,00, blitz 10 % weiß, 0,88 gegen 0,44 |
| `tools/run_render_checks.sh modern check_structures_licht.gd` | OK (207 s): tankstelle 12 Uhr Blende 44 m voraus weiß 33 % blau 5,9 %; 21 Uhr Blende 0,55, **Tankspur Modern 0,414 gegen Arcade 0,459** (0,90 ×, gleich der Basis R6/QA-R6 – die neuen Lampen nehmen den Dächern keine Kegelplätze weg); stadt 0,490 gegen 0,501; schatten 4/4 bzw. 0/4 |
| `… modern check_start_km0` (Fix des ersten Testbuilds) | OK (273 s): Kamera ≤ 1,14 px neben Arcade; Auto 193×193 bzw. 194×194 gegen Arcade 192×192 bei (544, 470/471); Boden 0,032 je Kanal – das Flutlicht des Starttors stört nicht |
| `… modern check_terrain_cover` (inkl. K1) | OK (92 s): T1–T4, S1, C1, **K1** je 0,000 % Magenta |
| `… modern check_light_base` | OK (178 s): Tageslicht Asphalt −6,6 %, Gras −1,8 %, Himmel −4,8 % gegen Arcade; Schatten beleuchtete Flächen −0,10 % |
| `tools/golden.sh check` (einmal, am Ende) | **GOLDEN arcade: 20 von 20 identisch**, **GOLDEN arcade-ui: 17 von 17 identisch** (657 s) |
| `tools/golden.sh modern-check start` | GOLDEN modern: 1 von 1 identisch – der von FIX-R6 erneuerte Hash von `modern_start_mittel` passt zum Kopf |
| `tests/sim/modern_sight.gd -- --full` | **nicht gelaufen**, mit Grund: keine Datei seiner Abhängigkeiten (Kernel, `fairness.gd`, Kamera) ist geändert; die geänderten Plätze von Pfeilern und Stützen prüfen `scan_f1`/`scan_all` und die Unit-Tests |
| `tools/run_tests.sh` (ganz) | nicht gelaufen (FIX-R6: zwei ganze Läufe; hier die Filter der geänderten Dateien) |

## 5. Hinweise für die Nächsten

1. **RINT-M2:** `tools/golden.sh modern-make` einmal auf dem Gesamtstand (R4, R5, FIX-R6 ändern `modern_slice.md5`).
2. **Modellpaket (A-16):** Nachtlicht-Atlas für Fenster und Leuchtband von `props/fuel_station` – der Hebel, damit die
   Tankstelle nachts klar besser als Arcade wird (bestätigt: R6s Vorplatzlicht ändert das Bild messbar kaum).
3. **R6/Folgepaket:** N-01 (Kameras vor `p.first` als verdeckt werten), N-03 (Halt aus der Nähe sichtbar), N-04
   (kleinste Verdeckung wählen); die Sichtlinienprüfung auch für die Grenz-Endpfeiler (`border_end` 8, `border_end_out` 15
   Paare, 1 mit ≥ 6 px).
4. **Leitung:** Budget für `collect()` (N-02); die einseitig abgespannten Grenzdächer (5 von 48) als gewollt bestätigen.
5. **R4 `layers/lights.gd`:** Stärke je Bild lesen, damit der Blitzer einen Lichtkegel bekommt (B-03 Rest, unverändert).

## 6. Bilder (in diesem Ordner, alle angesehen)

„A_M“ = `tools/ab_shot.sh` Arcade | Modern Kopf; „arcade_basis_kopf“ = Arcade | Modern `c8b18d1` | Modern `2b7dcc0`.
Grund-Argumente `--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup
--no-countdown` (Start ohne `--no-countdown`), Modern `--gfx-preset=high`, 1280 × 720.

| Datei | Ort und Zeit |
|---|---|
| `01`/`02` | DEV km 64,3, 12 Uhr, 100 km/h, Bild 1,4 s / 2,0 s (Grenze mittel / nah) |
| `03` | dasselbe, 1,4 s, mit Basis (Basis: Dach rechts schwebt) |
| `04`/`05` | Ausschnitte Kopf: nah rechts ohne Stütze, Stangenende an der Blende / fern Masten und Zugstangen |
| `06` | DEV Grenze 21 Uhr, 1,4 s, mit Basis |
| `07`/`08` | wien_prag ab Prag km 269,4, 12 Uhr, 1,4 s / 2,0 s (Grenze „ÖSTERREICH“) |
| `09` | DEV km 129,4, 12 Uhr, 50 km/h, 2,5 s (Zieltor) |
| `10` | dasselbe 21 Uhr, mit Basis |
| `11`/`12` | DEV km 0, 21 Uhr, Countdown 1,0 s („3“, mit Basis) / 3,6 s („LOS!“) |
| `13`/`14` | DEV km 18,5, 21 Uhr, 100 km/h, 1,2 s / 2,6 s (Tankstelle), mit Basis |
| `15` | Ausschnitt Shop bei Nacht: Arcade / Basis / Kopf (untereinander) |
