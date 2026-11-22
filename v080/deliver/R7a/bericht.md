# R7a – Sichtkorridor der Kurven aus der wirklichen Geometrie (A-17, A-18)

- **Arbeitsbaum:** `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1`, Branch
  `worktree-wf_ba4424b4-294-1`, Sicherung `origin/wip/v080-r7a` (jeder Commit gepusht). Basis `9b02f05` (RINT-M2,
  Fast-Forward), kein Vorgänger dieses Laufs (kein `STAND.md`, keine Branch).
- **Endstand:** `509bb16` (§9).
- **Maschine:** 4 Kerne, Software-OpenGL (llvmpipe) unter Xvfb, Dummy-Audio, Last 13–16 (bis zu sechs Pakete).
  „gemessen“ = hier an Zahl/Bild/Log festgestellt; „abgeleitet“ = gerechnet, nicht gemessen. Steam Deck, echte GPU und
  Wirkung auf Menschen sind immer abgeleitet.
- **Werkzeuge** (Scratch `m1/R7a/`, nichts davon committet): `probe/props_back.gd` (Requisiten und Stadtzäune alt/neu auf
  denselben Strecken, netzweit und je Stelle), `probe/border_roofs.gd`, `probe/roof_detail.gd` (Grenzdächer),
  `probe/startdep.gd` (L je Stelle, Startabhängigkeit), `probe/steps.gd` (Abtastfehler gegen die Referenz),
  `probe/cost.gd` (Kosten je Reihe), `sh/shots.sh`, `sh/occl.sh` (Verdeckungssonde von QA-M2-BILD/FIX-M2),
  `sh/rerun_audio.sh`; Basis-Kopie `m1/R7a/base` für Gegenläufe (am Ende gelöscht, ebenso Shader-Caches, XDG-Ordner und die Rohbilder der Verdeckungssonde; deren Auswertung steht in `m1/R7a/occl_eval.log`).

## Kurzfassung

- **Gebaut (A-17):** der Sichtkorridor der Kurven ist die Hülle aller Sichtlinien der Länge L entlang des wirklichen
  Pfads, Kamera in jeder Spur und auf jeder Reihe, L = min(300 m, F2-Bedarf / 0,6 + 9 m) aus der schnellsten fahrbaren
  Geschwindigkeit (`scripts/race3d/sight_corridor.gd`, einmal je Etappe, vorgerechnet im Streamer). Gelände, Requisiten,
  Stadtzäune und Grenzpfeiler lesen dieselbe Hülle; F7 prüft sie gegen eine unabhängige Referenz (0 von 388.907
  Querschnittsseiten nicht abgedeckt, ganzes Netz).
- **Was zurückkommt (gemessen, 128 Richtungen):** 23.026 Requisiten (16.947 Bäume, 1.878 Stadthäuser …), keines fällt neu
  weg; Stadtzäune 75,3 % statt 64,3 % von Arcade; Grenzdach Belgrad – Sofia km 340 steht wieder auf vier Pfeilern.
  Im Bild: T2-Baumgruppe, Starteiche, Häuserzeilen in München, Belgrad, Hannover – Kompositionen wie Arcade.
- **F2 gehalten:** `modern_sight --full` 0,593 / 0,596 / 0,555; Verdeckungssonde an T1–T4, S0, S4 überall sichtbar bis L;
  C1 bei 270 m schon in der Basis verdeckt.
- **Offen (gemessen):** der Requisiten-Builder (R7c) prüft nur den Fuß – 5.832 Requisiten ragen mit Vorderkante oder Krone
  in die Hülle (Basis 1.124). Die Prüfung mit Reichweite ist in `ChunkContext.in_bend_corridor()` gebaut; der Aufruf
  fehlt (§2, `notes_for_next`).
- **Gates:** Import sauber, Skripte 332/0, Tests 811 mit 2–3 Klang-Lastfehlern (auch auf der Basis), Arcade-Goldens 20/20
  und 17/17, Modern 2/6 (gewollt, angesehen), alle 28 Render-Prüfungen grün, Sicht und Pfad voll grün.

## 1. Was gebaut ist

**Kern (eigene Dateien):**

- `scripts/race3d/sight_corridor.gd` (neu, `SightCorridor`): die Hülle aller Sichtlinien je Reihe und Seite. Kamera auf
  **jeder** Reihe, auf der äußersten Spurmitte links und rechts (Tankspur: ihre Mitte, sobald sie öffnet –
  `Track.fuel_lane_x()`); Ziele sind die äußersten Spurmitten jeder Reihe bis L und das genaue Ende;
  L(Kamerareihe) = min(300 m, F2-Bedarf am Wagen / 0,6 + 9 m), der Bedarf wie `fairness.speed_profile()` (schnellste
  fahrbare Geschwindigkeit aller Autos, Kurven 5 % über der Grenze, Bremshüllkurve rückwärts, 1 s Reaktion), der
  größte von trocken/Regen/Schnee – der Korridor hängt also nicht vom Wetter des Rennens ab. Vom fernen Ende zur Kamera
  zurück die äußerste Sichtlinie nach rechts/links (Kreuzprodukt statt Winkel) und ihr Schnittpunkt mit dem Querschnitt
  jeder Reihe. Dreht die Straße bis L weniger als 1,2 rad: je Seite ein Kamera- und ein Zielpunkt; sonst beide Linien
  auf beiden Seiten (jenseits einer Vierteldrehung kehrt sich die Reihenfolge der Schnittpunkte um). Mittelachse
  (`clearance()`) erst beim Lesen, damit das Rechnen der Fächer den Pfad nie weiter vorausziehen muss als der Streamer.
  Bremsumhüllende schrittweise (ein Fenster `vtop² / 2a` voraus genügt, Ergebnis gleich der Rechnung über die ganze
  Etappe, Unit-Test). Faul (`ensure()`) und schrittweise (`warm()`), jede Kamera einmal je Etappe.
- `terrain_profile.gd`: `corridor_width()` = Hülle, wo eine Sichtlinie die Straße verlässt (mindestens schlichter
  Streifen + 0,55 m, damit `in_bend_corridor()` und `Station.bend_corridor_at()` ihn als Kurvenkorridor zählen), sonst
  der schlichte Streifen (8 m ab Fahrbahnrand). Ring-Abstände (das Band) **unverändert** – keine neuen Löcher oder Nähte
  möglich; nur die Relief-Erlaubnis folgt dem neuen Korridor. `warm(k, deadline)`.
- `chunk_streamer.gd`: `_warm_corridor()` – in Bildern ohne Sammeln und ohne Festschreiben höchstens 0,25 ms (und
  mindestens eine Kamera) bis zwei Stücke über `landmark_path_m` hinaus (die fernen Wahrzeichen lesen das Gelände ihrer
  Reihe so weit voraus); beim Laden diese Strecke auf einmal; liegt der Korridor hinter dem nächsten Sammeln, bis 2 ms
  je Bild (`7d8bbb6`, nach dem Leistungslauf, §5). Zeiten in `stats()` (`corridor_warm_ms_avg/_max`), Nachrechnen im
  Hauptthread (`corridor_sync_ms_max/_sum`, `corridor_sync_calls`).
- `chunk_context.gd`: Kommentare; `in_bend_corridor(z, x, reach = 0, half_len = 0)` – zwei optionale Argumente für
  den Fußabdruck eines Objekts (§2), ohne sie unverändert. Requisiten, Stadt, Tankstelle folgen über
  `in_bend_corridor()` / `corridor_width()` von selbst.
- Tests: `tests/unit/race3d/test_sight_corridor.gd` (neu, 8 Tests: vollständige Referenz – jede Kamerareihe, jede
  Spurmitte, jede Zielreihe, jeder Schnittpunkt jeder Sichtlinie mit jedem Querschnitt – an langem Bogen, kurzem Bogen,
  Gerade vor der Kurve, S-Kurve, Kehre, drei Spuren mit Tankspur; Bedarf = `speed_profile()`; Reihenfolge/trim egal),
  `test_terrain_profile.gd` (Korridor nach A-17), `test_chunk_streamer.gd` (Kurvenkorridor-Stelle nach der Hülle),
  `tests/race3d/fairness.gd` (`sight_envelope()`, unabhängige Referenz in doppelter Genauigkeit, jede Spurmitte;
  `scan_corridor()` prüft die Hülle), `tests/sim/modern_sight.gd` (F7 meldet und prüft die Hülle).
- Doku: `docs/renderer-modern.md` 5.3 (neu geschrieben), Datei-Tabelle, 5.4, 7.1, 8, 12.6, 14/17.

**Folgen (Ausnahmen der Leitung):**

- `builders/city.gd`: ein Zaun-/Hecken-/Mauerstück fällt, sobald seine Mitte **oder eines seiner Enden** im
  Kurvenkorridor liegt (der Korridor läuft jetzt an den Kurvenenden aus; nur die Mitte zu prüfen ließ Enden hineinragen
  – `test_city_fences_stay_out_of_bend_corridors` fand es).
- `builders/border.gd`: `pillar_in_sight()` – ein Pfeiler (außer Arcades vorderen) fällt nur, wenn seine Fläche zur
  Straße in der **genauen** Hülle steht (nicht im aufgerundeten Korridor, der am Kurvenende bis Streifen + 0,55 m
  reicht). Dann hängt das Dach wie bisher an Masten.
- `tests/unit/race3d/test_structures.gd` (Grenze der Testetappe gegen dieselbe Hülle; Kommentar Stadtzaun).
- **Außerhalb meiner Dateien:** `tests/unit/race3d/test_props.gd` – die Vorlage von `test_bend_corridor_and_density`
  steht jetzt in Stück 13 (die ersten 100 m des Bogens R = 200 m) statt in Stück 16 (Bogenmitte): in der Bogenmitte
  ist die Hülle nur noch 10 m breit, die Birken der Vorlage stehen 12–19 m daneben und blieben stehen. Prüfinhalt
  unverändert (gleiche Zahlen, gleiche Aussagen). Sonst rot; als Abweichung gemeldet.

## 2. Wie breit der Korridor jetzt ist (gemessen)

Bremsverzögerung der Hüllkurve (beste aller Autos): trocken 19,4, Regen 15,1, Schnee 9,7 m/s²; Endgeschwindigkeit 270 /
263 / 238 km/h. L an den Bildstellen (`probe/startdep.gd`):

| Stelle | L an der Kamera | Bedarf am Wagen | Bemerkung |
|---|---|---|---|
| T3, T4 Saragossa – Pau km 172,8 / 198,8 | 119 / 118 m | 66 / 65 m | langsame Bergkurven (FIX-M2: 107–119 m) |
| T1 Kassel – Würzburg km 46,5 | 263 m | 152 m | |
| T2, C1, S0, S4, alle Stadtstellen | 300 m | 207–290 m | schnellste fahrbare Geschwindigkeit kennt kein Tempolimit |

Synthetische Fälle (Unit-Test und Sonden): Autobahnbogen R = 200 m – Bogenmitte 10,2 m jenseits des Banketts, die ersten
100 m 37–43 m (die Sichtlinien der schnellen Anfahrt), altes Band überall 55 m; R = 140/300/400/600/1200 m: Mitte
8,1/13,3/16,3/14,2/6,1 m gegen alt 81/36/26/16/7 m. Kurzer Bogen (60 m, R = 150 m) nach langer Gerade: Scheitel 22,5 m
(der Bogen allein −1,4 m, altes Band 74 m). Kehre R = 90 m zwischen zwei Bergkurven: L 80–140 m, Scheitel ≈ Pfeilhöhe
von L.

**Genauigkeit:** gegen die vollständige Referenz 0 cm Fehlbetrag in allen sechs Fällen (`probe/steps.gd`); gröbere
Schritte (Kamera jede 2./4. Reihe, Querschnitt jede 2.) verfehlen Knicke der Hülle (Tankspurende, Kurvenbeginn, Kehre)
um bis zu 1,0 / 2,5 / 3,2 m – deshalb jede Reihe. Zuschlag nur 0,05 m (Rundung). In Kehren steht der Korridor bis
2,4 m weiter als nötig (beide Linien auf beiden Seiten). Die unabhängige Referenz in `modern_sight` (jede 7.
Kamerareihe, jede Spurmitte, doppelt genau): 0 von 55.135 Seiten nicht abgedeckt, 0 nicht als Kurvenkorridor gezählt,
im Mittel 1,36 m breiter als die Stichprobe (die übrigen sechs Kameras, Zuschlag, Aufrundung am Kurvenende).

**Startabhängigkeit** (Start mitten in der Etappe kennt die Kameras vor dem ersten Pfadpunkt nicht, der Pfad beginnt
163–194 m hinter der Kamera): an 11 der 13 Bildstellen sind alle 1.066 Reihenseiten ab der Kamera bis 1,6 km voraus
gleich der Fahrt von km 0; Lyon 8, Hannover 4 Seiten weichen direkt an der Kamera (−1/−2 m) um ≤ 0,56 m ab
(gemessen). Im Spiel beginnt jede Etappe bei km 0 (Vorlauf mit Kameras davor).

**Fußabdruck – die Lücke im strengen Lesen (gemessen, `probe/intrude.gd`, 128 Richtungen):** der Requisiten-Builder
(R7c, nicht meine Datei) prüft mit `in_bend_corridor(z, x)` nur den Fuß – bei `align: edge` den Anker = Vorderkante plus
Ausdehnung. Requisiten über 0,5 m, deren Fuß außerhalb der Hülle steht, deren Vorderkante oder Krone aber hineinreicht:

| | Gebäude | Stadthäuser | Bäume | Pflanzen | Felsen | Sonstige | Summe |
|---|---|---|---|---|---|---|---|
| Basis (altes Band entscheidet) | 77 | 723 | 191 | 2 | 13 | 118 | 1.124 |
| R7a (Hülle, Fuß-Test) | 81 | 1.496 | 3.654 | 305 | 156 | 140 | 5.832 |
| mit `in_bend_corridor(z, x, reach, half_len)` | 69 | 3 | 52 | 11 | 12 | 122 | 269 |

Tiefstes Hineinragen: Stadthaus 19 m, Baum 8 m (Kronenradius). Der Rest mit Reichweite sind nicht weglassbare Objekte
(von Ereignissen gesetzte Gebäude, Windräder – die der Builder nie weglässt). Mit Reichweite kämen 15.954 statt 22.432
Stücke zurück, und 1.223, die die Basis zeichnet, fielen weg. Die zwei optionalen Argumente sind in
`ChunkContext.in_bend_corridor()` gebaut und getestet (Commit 43cfd97, Standard unverändert); der Aufruf im
Requisiten-Builder ist eine Zeile (`notes_for_next`). An C1 ist genau das die Ursache der Verdeckung bei 270 m (§4).

## 3. Was zurückkommt (gemessen, gleiche Strecken alt/neu, `probe/props_back.gd`)

Alt = Korridor der Basis (Pfeilhöhe einer 300-m-Sehne mit der stärksten Krümmung ±150 m, nachgerechnet mit dem
unveränderten `_kappa()`); neu = A-17. Gezählt wie `drop_reason()` des Requisiten-Bauers (schmückend oder Pflanze, kein
Wahrzeichen, kein Bodendecker-Set, im Band).

**Ganzes Netz** (128 Etappenrichtungen): 203.367 Requisiten im Band; im Kurvenkorridor weggelassen alt **37.368
(18,4 %)**, neu **14.342 (7,1 %)** – **23.026 kommen zurück** (16.947 Bäume, 2.947 Pflanzen, 952 Felsen, 66 Häuser
auf dem Land, **1.878 Häuser in Städten**), **0 fallen neu weg**. Stadtzäune/Hecken/Mauern: Arcade zeichnet 79.662
Stücke, alt standen 51.246 (64,3 %), neu **59.949 (75,3 %)**.

**Je Stelle** (Requisiten 150 m vor der Kamera, wie die Sonde von FIX-M2):

| Stelle | im Band | weggelassen alt → neu | zurück |
|---|---|---|---|
| T4 Saragossa – Pau km 199,7 | 12 | 9 → 3 | 6 (5 Bäume, 1 Fels) |
| T3 km 173,5 | 8 | 4 → 2 | 2 Bäume |
| T1 Kassel – Würzburg km 47,5 | 13 | 5 → 1 | 4 Bäume |
| T2 km 61,9 | 17 | 8 → 0 | 8 Bäume |
| C1 Dortmund – Frankfurt km 221,8 | 16 | 6 → 5 | 1 Baum |
| S4 Kiel – Hamburg km 80,4 | 12 | 5 → 3 | 2 Stadthäuser |
| S0 Kiel – Hamburg km 0 (Starteiche) | 7 | 1 → 0 | die Eiche |
| Lyon km 297,4 (Montpellier – Lyon) | 15 | 7 → 3 | 4 Stadthäuser |
| Bern km 302,7 (Lyon – Bern) | 10 | 5 → 5 | 0 |
| München km 161,7 (Nürnberg – München) | 10 | 8 → 6 | 2 Stadthäuser |
| Nürnberg Altstadt km 102,7 (Würzburg – Nürnberg) | 15 | 7 → 7 | 0 |
| Belgrad km 187,4 (Slavonski Brod – Belgrad) | 20 | 10 → 6 | 3 Stadthäuser, 1 Baum |
| Hannover km 142,4 (Hamburg – Hannover) | 10 | 7 → 1 | 6 Stadthäuser |

Stadthäuser in Stadtkurven: zurück in Hannover (6 von 7), Lyon (4/7), Belgrad (3/10), München (2/8), S4 (2/5); nicht in
Bern (5) und Nürnberg (7): dort ist L = 300 m (F2-Bedarf 231–248 m – die schnellste fahrbare Geschwindigkeit kennt das
Tempolimit 50 nicht), und die Kurven sind eng genug, dass die Sichtlinien die Häuser schneiden. Nach A-17 richtig; ob
in Städten ein Tempolimit-Bedarf gelten soll, ist eine Frage an die Leitung (§8).

**Grenzdächer** (`probe/border_roofs.gd`, alle 48 Dächer): Basis 4 an Masten (Belgrad – Sofia ab Belgrad km 340, ab
Sofia km 55, Wien – Prag ab Prag km 270, Białystok – Kaunas ab Kaunas km 90), neu **3** – Belgrad – Sofia km 340
steht wieder auf vier Pfeilern: die Sichtlinien laufen dort 1,8–2,1 m jenseits des Banketts, die nach außen gerückten
Pfeiler (Mitte 2,47 m, Fläche 2,20 m) stehen daneben. An den drei anderen laufen sie 3,6–12,8 m weit – die Pfeiler
stehen darin, das Dach hängt weiter (`roof_detail.log`). Die Doku von FIX-R6 nannte 5 von 48; auf dieser Basis
gemessen waren es 4 (die Testetappe hat keine eigene Zählung in den 48; ihr Dach hängt rechts weiter).

## 4. Bilder (angesehen, ehrlich gegen Arcade und gegen die Basis)

Alle mit `tools/ab_shot.sh` / `tools/ab_sheet.sh` (gleicher Simulationsstand, links Arcade, rechts Modern), Tag.
Die Bögen T1–T4, C1, S4 sind mit genau den Befehlen der Bögen von RINT-M2 gemacht – deren Bilder
(`deliver/RINT-M2/ab_boegen/*`) sind die Basis. Dreierbilder Arcade | Modern Basis | Modern R7a in `vergleich/`.

| Bild | Was sich gegen die Basis ändert | gegen Arcade |
|---|---|---|
| `vergleich/T2_hoch_arcade_basis_r7a.jpg` | **die ganze linke Baumgruppe ist zurück** (Eichen, Fichten, Laubbäume an der Innenseite der Autobahnkurve); in der Basis standen dort nur Bodendecker-Büschel auf leerem Gras | jetzt dieselbe Komposition wie Arcade, mit echten, schattierten Modellen – **klar besser als Arcade** |
| `vergleich/T1_hoch_arcade_basis_r7a.jpg` | links zwei Fichten zurück (Arcade hat sie an derselben Stelle) | nahe große Fichte ganz links fehlt weiter (liegt außerhalb des Modern-Ausschnitts – der Blick in die Kurve, kein Korridor) |
| `vergleich/T4_hoch_arcade_basis_r7a.jpg` | rechts eine Felsgruppe und eine Fichtengruppe zurück | Innenseite der Kehre nah am Wagen weiter frei (dort laufen die Sichtlinien bis 118 m) |
| `vergleich/T3_hoch_arcade_basis_r7a.jpg` | links hinten eine Felsgruppe zurück | Arcades Felsen innen in der Kurve (links, 60–120 m) fehlen weiter – sie stehen in den Sichtlinien |
| `vergleich/C1_hoch_arcade_basis_r7a.jpg` | gleich | Arcades großer Parkbaum rechts fehlt weiter: in Städten ist L = 300 m, der Baum steht in den Sichtlinien der Rechtskurve |
| `vergleich/S4_hoch_arcade_basis_r7a.jpg` | in diesem Ausschnitt gleich (die 2 zurückgekehrten Häuser der Zählung stehen außerhalb des Bilds) | – |
| `vergleich/S0_start_kiel_high.jpg` | **die große Eiche links am Start ist zurück** (Basis: leer, nur das Windrad dahinter) | wie Arcade |
| `vergleich/Muenchen_high.jpg` | **die rosa Häuserzeile links ist zurück** (Basis: links leerer Platz bis zur Skyline) | dieselbe Straßenschlucht wie Arcade, Modern mit Licht/Schatten – besser als Arcade |
| `vergleich/Belgrad_km187_high.jpg` | **rechts die Häuserzeile und die Pappel vorn rechts sind zurück** (Basis: rechts leere Wiese) | Komposition wie Arcade; die Pappel rechts steht in beiden Modi |
| `vergleich/Hannover_km142_high.jpg` | **das große Eckhaus links ist zurück** (Basis: nur ein fernes Haus) | Komposition wie Arcade |
| `vergleich/Lyon_km297_high.jpg` | im Ausschnitt gleich (die 4 zurückgekehrten Stücke der Zählung stehen hinter der Kamera/außerhalb) | Komposition wie Arcade, Modern feiner |
| `bilder/Bern_high_ab_00.jpg`, `bilder/Nuernberg_high_ab_00.jpg` | keine Änderung zu erwarten (Zählung 5→5 und 7→7, gleicher Stand ⇒ gleiches Bild; Basis nicht neu gemacht) | Altstadtgassen wie Arcade, die engen Kurven bleiben in der Innenseite frei |
| `vergleich/R1_belgrad_sofia_km340_high.jpg` | **Grenzdach Belgrad → Sofia km 340 steht wieder auf vier Pfeilern** (Basis: Masten mit Abspannseilen); die Sichtlinien laufen 1,8–2,1 m innen, die Pfeilerfläche liegt bei 2,20 m | wie Arcade |
| `bilder/R2_high_ab_00.jpg` (Sofia → Belgrad km 55), `bilder/R3_high_ab_00.jpg` (Prag km 270), `bilder/R4_high_ab_00.jpg` (Kaunas km 90) | gleich: das Dach hängt weiter an Masten mit Seilen – der zweite Frontpfeiler stünde 3,6–12,8 m tief in den Sichtlinien | Abweichung von Arcade bleibt (A-18: dort hängt das Dach) |
| `bilder/R5_high_ab_00.jpg` (Testetappe km 64) | gleich: hängt an einem Mast mit Seilen | wie R2–R4 |

Die Pfeiler- und Mastlösung ist im Bild glaubhaft (keine schwebenden Teile); Arcade zeigt an R2–R5 Pfeiler, die in
Modern in den Sichtlinien der Kurve stünden.

**Alle Stellen (`props_back_pos.log`, 150 m voraus, alte → neue verdeckte Stücke):** T4 9 → 3 (von 12),
T3 4 → 2 (8), T1 5 → 1 (13), T2 8 → 0 (17), C1 6 → 5 (16), S4 5 → 3 (12), S0 1 → 0 (die Eiche), Lyon 7 → 3,
Bern 5 → 5, München 8 → 6, Nürnberg 7 → 7, Belgrad 10 → 6, Hannover 7 → 1.

**Verdeckungssonde (gemessen, `probe/qa_occl.gd` von FIX-M2, rotes Testauto in drei Spuren bei 25–270 m, „Hoch“,
Pixel, die sich gegen das Bild ohne Auto ändern; sichtbar ab 12 px; verlangt bis min(L, 270 m)):**

| Stelle | L | kleinste Pixelzahl bis zur verlangten Entfernung (R7a) | Basis | Ergebnis |
|---|---|---|---|---|
| T4 Saragossa – Pau km 198,8 | 118 m | 255 px bei 85 m (165 px bei 120 m) | gleich (alle Werte bis 150 m identisch) | gehalten; bei 200 m Spur +1 jetzt 54 px statt 127 px (zurückgekehrte Felsgruppe, jenseits von L) |
| T3 km 172,8 | 119 m | 267 px bei 85 m (161 px bei 120 m) | identisch in allen 21 Messungen | gehalten |
| T1 Kassel – Würzburg km 46,5 | 263 m | 27 px bei 200 m (14 px bei 270 m) | – | gehalten |
| T2 km 61,9 | 300 m | 22 px bei 270 m | – | gehalten |
| S0 Kiel km 0 | 300 m | 20 px bei 270 m | – | gehalten |
| S4 Kiel – Hamburg km 80 | 300 m | 18 px bei 270 m | – | gehalten |
| C1 Dortmund – Frankfurt km 221 | 300 m | 30 px bei 200 m; **bei 270 m 6/0/0 px** | **6/9/0 px** | bei 270 m schon in der Basis verdeckt (rechts ein Mietshaus an der Kurveninnenseite); R7a nimmt Spur 0 die letzten 9 px |

C1 genauer (`probe/c1_props.gd`): das Auto bei 270 m steht hinter zwei Häusern der Kurveninnenseite. Das vordere
(`city_german_mietshaus`, 219 m voraus) steht in Basis und R7a: sein Fuß liegt 18,0 m jenseits des Banketts, knapp
außerhalb des alten Bands (18,0 m), seine Vorderkante aber 2,6 m jenseits – 2,8 m tief in der Hülle. Das zweite
(`city_german_gruenderzeit`, 246 m) kommt mit R7a zurück: Fuß 16,6 m (Hülle 2,9 m), Vorderkante 1,2 m – 1,7 m tief in
der Hülle. Ursache: der Requisiten-Builder prüft nur den Fuß (siehe §2 „Fußabdruck“, `notes_for_next`).


**Clip** `clips/saragossa_pau_bergkurven_km197.mp4` (20 s, `tools/ab_clip.sh`, „Hoch“, Saragossa – Pau ab km 197,0,
links Arcade, rechts Modern; Standbilder bei 3/8/13/18 s angesehen): die Kurveninnenseiten bleiben frei, Felsgruppe und
Fichtengruppe stehen wie in Arcade (bei 13 s die Felsgruppe rechts sogar dichter), die Tankstelle am Ende gleich. Zwei
nahe Fichten, die Arcade bei 3 s und 8 s rechts an der Außenseite zeigt, fehlen in Modern – die Außenseite einer
Linkskurve liegt im S-Bogen in den Sichtlinien der vorigen Rechtskurve (nicht einzeln nachgemessen, abgeleitet).
Ob Requisiten ploppen, lässt sich aus vier Standbildern nicht sagen; der Korridor wird vor dem Sammeln eines Stücks vorgerechnet und ändert sich danach nicht (abgeleitet aus dem Code).

**Mittel:** `bilder/{S0,Muenchen,Belgrad,Hannover,R1}_medium_ab_00.jpg` zeigen dieselben Kompositionen wie „Hoch“.

**Goldens Modern** (§6): die vier geänderten Bilder angesehen (`vergleich/goldens/`) – nur zurückgekehrte Requisiten.

## 5. Kosten (llvmpipe-Maschine, gemessen; Steam Deck abgeleitet)

- **Je Reihe:** der Kern in `modern_sight` (12 härteste Etappenrichtungen, 103.583 Segmente) 8,4 s → **81 µs je Reihe**;
  Bergstrecken mit dem ersten Stand (vor dem „einfachen“ Fächer) 230–265 µs, Kiel – Hamburg 106–114 µs (`probe/cost.gd`).
  Der einfache Fächer (Straße dreht bis L < 1,2 rad) spart 35–45 % je Kamera (gemessen an den sechs Fällen).
- **Im Spiel** wird jede Reihe einmal gerechnet; bei 250 km/h rückt die Kamera 0,4 Reihen je Bild vor, also
  ~30–100 µs je Bild im Mittel. Damit das nicht in Spitzen beim Sammeln eines Stücks fällt (32 Reihen auf einmal:
  2,5–8 ms), rechnet der Streamer in Bildern ohne Sammeln/Festschreiben voraus (höchstens 0,25 ms und eine Kamera
  je Bild).
- **Vorbereitung (Ladebild):** seit `7d8bbb6` die ersten ~2,3 km einer Etappe (Vorlauf, Wahrzeichen-Strecke 1.900 m,
  zwei Stücke Reserve): ~770 Reihen × 81–250 µs = **60–190 ms** zusätzlich beim ersten `update()`, hinter dem Ladebild
  (abgeleitet; gemessen Kiel – Hamburg: Nachrechnen beim Sammeln 31 ms in 385 Aufrufen, `prepare_ms` im Rauschen der
  Shader, 15–20 s bei Basis und R7a).
- **Speicher:** je Reihe zwei Float (Hülle) + ein Float (Bedarf) + der Geometrieblock (12 Felder × ~134 Reihen) –
  unter 100 kB je Etappe (abgeleitet aus den Feldgrößen; das Fenster wird mit dem Pfad abgeschnitten).

**Ganze Etappe mit `perf_stats` (gemessen):** `tests/race/run_stage.gd` Kiel – Hamburg, Modern „Mittel“, Autopilot,
Seed 7, 12 Uhr, gleiche Maschine allein (Last 3–4, bei ×4 7–8 durch andere Pakete), warmer Shader-Cache (das erste
Paar lief mit kaltem Cache für R7a: `prepare_ms` 56 s statt 22 s war der Cache, nicht der Korridor – verworfen).
„×40“ = Zeitraffer 40 (ganze Etappe, 1,3 s Fahrt je Bild), „×4“ = Zeitraffer 4, 420 s Wandzeit (die ersten ~2 km, 0,13 s
Fahrt je Bild). `ERGEBNIS` von Basis und R7a identisch (MD5 der Zeile).

| Wert | Basis ×40 | R7a `e81886a` ×40 | R7a `7d8bbb6` ×40 | Basis ×4 | R7a `e81886a` ×4 | R7a `7d8bbb6` ×4 |
|---|---|---|---|---|---|---|
| render_ms_avg | 3.62 | 4.33 | 4.46 | 1.92 | 1.82 | 2.06 |
| render_ms_max | 10.30 | 21.32 | 24.16 | 30.59 | 26.02 | 21.84 |
| frame_ms_median | 639.15 | 614.37 | 774.41 | 757.92 | 740.16 | 714.15 |
| frame_ms_p95 | 865.39 | 903.49 | 1157.44 | 1045.72 | 1005.70 | 947.69 |
| frames | 263 | 263 | 263 | 547 | 622 | 538 |
| streamer.collect_ms_avg | 1.61 | 3.15 | 2.95 | 1.98 | 1.96 | 2.02 |
| streamer.collect_ms_max | 5.60 | 10.24 | 9.66 | 4.05 | 2.38 | 2.85 |
| streamer.commit_ms_max | 1.90 | 2.82 | 1.66 | 2.07 | 1.69 | 9.85 |
| load.collect_ms_avg | 2.72 | 5.33 | 5.83 | 2.84 | 5.73 | 5.60 |
| load.collect_ms_max | 7.17 | 12.87 | 12.93 | 7.18 | 14.04 | 14.36 |
| load.commit_ms_max | 12.84 | 6.89 | 8.89 | 9.38 | 8.23 | 64.52 |
| chunk_build_ms_avg | 4.67 | 5.34 | 5.55 | 5.40 | 6.47 | 7.84 |
| chunk_build_ms_max | 21.35 | 16.16 | 22.45 | 10.74 | 25.88 | 31.21 |
| streamer.corridor_warm_ms_avg | – | 0.12 | 0.24 | – | 0.06 | 0.09 |
| streamer.corridor_warm_ms_max | – | 0.63 | 2.15 | – | 1.77 | 8.23 |
| hooks_ms_avg.props | 0.09 | 0.15 | 0.15 | 0.05 | 0.05 | 0.06 |
| hooks_ms_max.props | 0.41 | 14.32 | 13.47 | 1.21 | 1.68 | 3.53 |
| hooks_ms_avg.streamer | 1.72 | 2.35 | 2.35 | 0.29 | 0.36 | 0.46 |
| hooks_ms_max.streamer | 7.66 | 10.99 | 12.63 | 4.28 | 6.77 | 19.72 |
| draw_calls | 156 | 156 | 156 | 137 | 137 | 131 |
| primitives | 181985 | 181985 | 181985 | 109974 | 142440 | 108995 |
| primitives_shadow | 70557 | 70557 | 70557 | 12190 | 12480 | 9310 |
| prepare_ms | 16271.00 | 15256.00 | 17692.00 | 20870.00 | 15622.00 | 19772.00 |
| prewarm_ms | 13661.81 | 12984.33 | 15025.23 | 18252.03 | 13109.22 | 16938.52 |
| wall_s | 175.10 | 177.72 | 211.37 | 420.18 | 420.86 | 420.18 |

- **Zeitraffer 40** fährt 12 Reihen je Bild; der Korridor kostet dann 1–3 ms je Bild, mehr als das Vorrechnen in freien
  Bildern schafft: Sammeln +1,3–1,5 ms im Mittel, und der Requisiten-Hook rechnete bis 14 ms nach (die fernen
  Wahrzeichen lesen das Gelände ihrer Reihe bis 1.900 m voraus, das Vorrechnen reichte nur bis load_path_m + 2 Stücke).
  `7d8bbb6` rechnet bis hinter `landmark_path_m` voraus (beim Laden auf einmal) und misst das Nachrechnen
  (`corridor_sync_*`): bei ×40 bleibt es (2.124 Aufrufe, 133 ms, höchstens 13 ms) – das ist der Zeitraffer.
- **Zeitraffer 4** (näher am Spiel): Sammeln im Mittel gleich (2,02 / 1,96 gegen 1,98 ms), Requisiten-Hook im Mittel
  gleich (0,06 / 0,05 gegen 0,05 ms), `render()` im Mittel 2,06 / 1,82 gegen 1,92 ms; **nach dem Laden kein
  Nachrechnen** (`corridor_sync`: alle 385 Aufrufe mit 31 ms im Laden). Die Maxima streuen unter der Last der anderen
  Pakete (die Basis hat selbst `render_ms_max` 30,6 ms); `load.commit_ms_max` 64,5 ms in einem Lauf ist ein
  Einzelwert beim Laden.
- **Laden:** `load.collect_ms_avg` 5,3–5,8 statt 2,7–2,8 ms, höchstens 14 ms (die Hülle der ersten Stücke, hinter dem
  Ladebild); `prepare_ms` gleich (15–20 s, die Shader überwiegen).
- **Draw Calls / Primitive** am Ziel gleich (156 / 181.985 / 70.557 im Schatten); bei ×4 enden die Läufe an
  verschiedenen Stellen (nicht vergleichbar).
- **Steam Deck (abgeleitet):** bei 60 fps und 250 km/h rückt die Kamera 0,4 Reihen je Bild vor; das Vorrechnen schafft
  in freien Bildern 1–3 Reihen – drei- bis achtfach genug. Ein Spieler sieht die ×40-Spitzen nicht; ein Rechner, der
  unter 15 fps fällt, käme in den Bereich von ×4.

## 6. Gates (Befehle und Ausgaben; alle mit absolutem `XDG_DATA_HOME` unter Scratch, `nice -n 10`)

Endstand `509bb16`. Die vollen Läufe (Render-Prüfungen, Goldens, `modern_sight --full`, `modern_path_check --full`) liefen
auf `e81886a`, der zweite `run_tests.sh` auf `b3f1b67`; danach kamen `7d8bbb6` (Vorrechnen bis hinter die
Wahrzeichen, Zähler – ändert nur, *wann* die Hülle gerechnet wird; sie ist reihenfolgeunabhängig, Einheitstest
`test_order_independent`) und `509bb16` (Doku). Auf dem Endstand nachgefahren: `--filter=race3d` 182 Tests / 0,
`check_scripts` 332 / 0, die sechs Streamer-Prüfungen headless, vier streamende Render-Prüfungen und zwei
Modern-Goldens **pixelgleich** zu `e81886a` (letzte Zeilen der Tabelle).

| Gate | Befehl | Ausgabe (gekürzt) | Ergebnis |
|---|---|---|---|
| Import | `godot --headless --path . --import` (auf `b3f1b67` und `509bb16`) | Exit 0, 0 Zeilen mit „error“/„warning“ | sauber |
| Skripte | `tests/check_scripts.gd` (Schritt 1 von `run_tests.sh`) | `332 Skripte geprüft, 0 fehlerhaft` | grün |
| Tests Lauf 1 | `tools/run_tests.sh` (auf `e81886a`, 1.470 s) | `811 Tests, 3 fehlgeschlagen` (test_engine3_checks, test_modern_checks, test_music_checks – Klang im laufenden Spiel); alle `CHECKS OK`, `modern_sight_f1…f7, model OK`, `modern_path_loops OK` | 3 nur unter Last: allein nachgefahren `engine3` grün, `modern`/`music` rot – **auf der Basis unter gleicher Last genauso rot** (`rerun_audio.log`, Last 14,9–16,1) → A-11 |
| Tests Lauf 2 | `tools/run_tests.sh` (auf `b3f1b67`, 1.132 s, parallel zu Render-Prüfungen) | `811 Tests, 2 fehlgeschlagen` (test_engine3_checks: „6 Hänger des Hauptthreads à 400 ms“; test_music_checks: Musik im Rennen) – alle übrigen Schritte `CHECKS OK` | dieselbe Familie, nur Last (keine Klangdatei berührt) |
| Goldens Arcade | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (329 s)`, `GOLDEN arcade-ui: 17 von 17 identisch (413 s)` | grün |
| Goldens Modern | `tools/golden.sh modern-check` | `GOLDEN modern: 2 von 6 identisch (1030 s)` – anders: `modern_start_mittel`, `modern_s3_hoch`, `modern_s4_mittel`, `modern_s1_nacht`; `GOLDEN modern-gles: … OK max. Abweichung 2/255, PSNR 73.2 dB` | gewollt, angesehen (`vergleich/goldens/`, mit `KEEP=` neu gerendert; die Basis gibt 6 von 6 identisch): `start_mittel` die Starteiche links zurück (wie Arcade), `s1_nacht` ein Busch links am Mittelstreifen, `s3_hoch` zwei ferne Bäume links, `s4_mittel` ein Baum links vor der Stadt (34.660 / 659 / 275 / 406 Pixel); **kein `modern-make`** (A-18: `modern_slice.*` gehört der Montage) |
| Render-Prüfungen | `tools/run_render_checks.sh modern <datei>` je Datei + `tools/run_render_checks.sh arcade` | alle 26 Modern-Dateien `OK` (terrain_cover T1–T4/S1/C1/K1 0,000 % Magenta, start_km0, light_base, props_render, structures, structures_licht, facade_render, instance_budget ×3, models, modern_render, night, night_nass, occlusion, quit_sound, road_parity, seam_render, session_modern, showroom_render, tunnel_bridge, vehicle_lights, vehicle_standin, weather ×3); Arcade `check_glow_occlusion OK`, `check_sprite_flip OK` | grün |
| Sicht voll | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (280 s) | `f1 OK 0 Fälle bis 270 m (99.424.500 Stichproben, 128 Richtungen)`, `f1_lanes OK`, `f2 OK 0.593 / 0.596 / 0.555`, `f3 OK 0 von 5923`, `f7 OK 0 von 2.011.532 Seiten mit Gelände über der Fahrbahn; Hülle: 0 von 388.907 Seiten nicht abgedeckt, 0 nicht als Kurvenkorridor gezählt`, `model OK` | grün |
| Pfad voll | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` (66 s) | `modern_path_clearance OK kleinster Abstand 267.6 m`, `modern_path_loops OK … nach 2064 m Weg` | grün |
| Gelände-Löcher/Nähte | `check_terrain_cover` T1–T4, S1, C1, K1 | 0,000 % Magenta an allen sieben | grün |
| Leistung | `tests/race/run_stage.gd` Kiel – Hamburg, Modern „Mittel“, Zeitraffer 40, dieser Stand und Basis | Tabelle §5: ×40 Sammeln +1,3–1,5 ms, Hook-Spitzen bis 13–14 ms (Zeitraffer: 12 Reihen je Bild); ×4 im Mittel gleich, nach dem Laden kein Nachrechnen; Draw Calls/Primitive gleich | ×4 gleichwertig; ×40-Spitzen sind der Zeitraffer (§5) |
| Endstand: Einheitstests | `godot --headless --path . -s res://tests/run_tests.gd -- --filter=race3d` (auf `7d8bbb6`) | `182 Tests, 0 fehlgeschlagen` | grün |
| Endstand: Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | `332 Skripte geprüft, 0 fehlerhaft` | grün |
| Endstand: Streamer headless | `tests/race3d/check_{facade,modern_stage,seam,terrain_plan,attract_modern,benchmark}.gd` | 8 / 8 / 10 / 3 / 4 / 8 `CHECK … OK`, 0 FEHLER | grün |
| Endstand: Render | `tools/run_render_checks.sh modern terrain_cover|seam_render|session_modern|start_km0` (auf `509bb16`) | alle vier `OK` | grün |
| Endstand: Goldens | `KEEP=… GLES_ID= tools/golden.sh modern-check modern_start_mittel` / `modern_s4_mittel` | Bild byte-gleich zu dem von `e81886a` | gleich |
| Endstand: Import | `godot --headless --path . --import` (auf `509bb16`) | Exit 0, 0 Zeilen mit „error“/„warning“ | sauber |

## 7. Abweichungen

- **`tests/unit/race3d/test_props.gd` angefasst** (nicht meine Datei, R7c): die Vorlage von
  `test_bend_corridor_and_density` von Stück 16 (Bogenmitte, Hülle 10 m) nach Stück 13 (Bogenbeginn, Hülle 37–43 m)
  verschoben – Zeilen 449–458, sonst rot. Prüfinhalt unverändert. Beim Zusammenführen mit R7c auf diese Hunk achten.
- **Aufrundung am Kurvenende:** wo eine Sichtlinie die Straße verlässt, ist der Korridor mindestens schlichter Streifen
  + 0,55 m (6,05 m jenseits des Banketts), auch wenn die Sichtlinien dort nur z. B. 1 m weit laufen. Grund: die
  Station (`station.gd`, nicht meine Datei) und `ChunkContext.in_bend_corridor()` zählen einen Korridor erst ab Streifen
  + 0,5 m als Kurvenkorridor; ohne Aufrundung stünde dort, wo die Sichtlinien knapp jenseits des Banketts laufen, ein
  Baum oder ein Pfeiler in ihnen. Nur der Grenz-Builder prüft gegen die genaue Hülle (A-18 verlangt es dort).
- **Kamera auf jeder Reihe** (statt jeder zweiten/vierten): gröbere Abtastung verfehlt Knicke der Hülle um bis zu 1–3 m
  (gemessen) – der Preis sind ~0,1–0,3 ms Rechenzeit je gefahrener Reihe (verteilt, §5).
- **`modern_sight` normal 39 s statt ~18 s** (unabhängige Referenz der Hülle + Rechnung des Kerns für 103.583
  Segmente unter Last 15); `--full` entsprechend länger (§6).
- **Bilder „Mittel“ nicht an jeder Stelle:** „Mittel“ an T1–T4, C1, S4 (Bögen), S0, München, Belgrad, Hannover und
  dem Grenzdach R1; Lyon, Bern, Nürnberg und R2–R5 nur „Hoch“ (jeder Lauf 3–8 min unter Last 13–16). Die Mittel-Bilder
  zeigen dieselben Kompositionen wie „Hoch“ (Starteiche, Häuserzeilen, Dach auf Pfeilern).
- **Gates auf drei Ständen:** die vollen Läufe auf `e81886a`, der zweite `run_tests.sh` auf `b3f1b67`, der Endstand
  `509bb16` mit gezielten Läufen (§6). Nach dem zweiten vollen `run_tests.sh` kam noch eine Code-Änderung (`7d8bbb6`,
  Vorrechnen bis hinter die Wahrzeichen – gefunden erst im Leistungslauf); ein dritter voller Lauf war nicht erlaubt.
- **Fußabdruck nicht im Requisiten-Builder behoben:** `builders/props.gd` gehört R7c; die Prüfung mit Reichweite ist
  gebaut und getestet, der Aufruf fehlt (§2). Bis dahin ragen 5.832 statt 1.124 Requisiten mit Vorderkante oder Krone in
  die Hülle (gemessen); die Verdeckungssonde hielt F2 an sechs von sieben Stellen, C1 bei 270 m war schon in der Basis
  verdeckt.

## 8. Vertragsfragen (mit Beleg)

1. **„a short bend gets the sagitta of its real arc“ (A-17)** stimmt mit der Hülle der Sichtlinien nicht: Sichtlinien
   der Länge L, die auf den Geraden davor beginnen, schneiden die Ecke. Kurzer Bogen 60 m, R = 150 m, L = 300 m: Hülle
   22,5 m jenseits des Banketts, eigene Pfeilhöhe des Bogens −1,4 m (er verlässt die Straße gar nicht), altes Band
   74 m. Gebaut ist die Hülle (der Hauptsatz von A-17); die Klammer-Erwartung ist so nicht haltbar.
2. **„a straight before a bend is free“** gilt nur jenseits der Sichtlinien, die in die Kurve laufen (bis L vor dem
   Kurvenbeginn). Wegen der Bremshüllkurve ist die Anfahrt schnell und L lang: am Kurvenbeginn ist der Korridor oft
   breiter als in der Kurvenmitte (Autobahnbogen R = 200 m: Beginn 37–43 m, Mitte 10 m).
3. **Stadtkurven:** der F2-Bedarf kennt kein Tempolimit (schnellste fahrbare Geschwindigkeit), L bleibt in Städten
   300 m. Bern und Nürnberg bekommen kein Haus zurück, München 2 von 8, S4 2 von 5. Soll in den City Limits ein
   Bedarf aus dem Tempolimit (mit Zuschlag) gelten, käme deutlich mehr zurück – Entscheidung der Leitung (die
   Fairness-Regel F2 ist dann aber nicht mehr „schnellste fahrbare Geschwindigkeit“).
4. **A-18 „5 of 48 roofs“:** auf dieser Basis hängen 4 der 48 Dächer der Rennetappen (gemessen, `border_roofs.log`)
   und das Dach der Testetappe (Bild R5) – zusammen 5, aber nicht „von 48“; neu 3 + Testetappe.
5. **A-18 „modern_slice.* gehört der Montage, Pakete erzeugen es nicht neu“** gegen den Auftrag „modern-make where a
   Modern golden changed on purpose“: nicht neu erzeugt (A-18 ist die jüngere, genauere Regel); geänderte Bilder in §6.
6. **„camera in every lane“** ist mit Spurmitten gebaut (wie `modern_sight` F1-lanes); ein Auto auf dem Bankett ist
   nicht abgedeckt (die schnellste Linie fährt nicht dort).
7. **A-17 (2) „nichts über 0,5 m in der Hülle“ braucht einen Fußabdruck**, die Schnittstelle ist ein Punkttest am
   Fuß, und der Builder, der ihn ruft, gehört einem anderen Paket (R7c). Gemessen: 5.832 Requisiten ragen mit Vorderkante
   oder Krone hinein (Basis 1.124, bis 19 m tief). Vorschlag: der Aufruf mit `reach`/`half_len` wird Pflicht für jeden
   Builder, der Objekte breiter als 1 m an den Kurvenkorridor stellt (Requisiten, Station).

## 9. Commits (Branch `worktree-wf_ba4424b4-294-1`, jeder auf `origin/wip/v080-r7a` gesichert)

| Commit | Inhalt |
|---|---|
| `011c612` | Sichtkorridor aus der wirklichen Geometrie (A-17): `sight_corridor.gd`, `terrain_profile.gd` |
| `26c9b48` | je Kamerareihe exakt, Vorrechnen im Streamer |
| `96e403d` | Folgen: Stadtzaun je Stück, Testvorlagen (`test_props.gd`-Hunk, siehe §7) |
| `a78737d` | F7 prüft die Hülle gegen eine unabhängige Referenz (`fairness.gd`, `modern_sight.gd`) |
| `052de62` | Grenzdach: Pfeiler gegen die genaue Hülle (A-18) |
| `613c0f0` | Doku `renderer-modern.md` 5.3 |
| `738e7fc` | UID des Einheitstests |
| `e81886a` | `ChunkContext`: Kommentar |
| `43cfd97` | `in_bend_corridor(z, x, reach, half_len)` – Fußabdruck-Test, Test |
| `b3f1b67` | Doku Fußabdruck |
| `7d8bbb6` | Vorrechnen bis hinter `landmark_path_m`, Messung `corridor_sync_*` |
| `509bb16` | Doku Vorrechnen (**Endstand**) |

Geänderte Dateien gegen `9b02f05`: `scripts/race3d/{sight_corridor.gd (neu), terrain_profile.gd, chunk_context.gd,
chunk_streamer.gd}`, `scripts/race3d/builders/{border.gd, city.gd}` (Ausnahmen der Leitung), `tests/race3d/fairness.gd`,
`tests/sim/modern_sight.gd`, `tests/unit/race3d/{test_sight_corridor.gd (neu), test_terrain_profile.gd,
test_chunk_streamer.gd, test_structures.gd, test_props.gd}`, `docs/renderer-modern.md`.

## 10. Für die Nächsten

- **R7c (`builders/props.gd`):** in `drop_reason()` und beim Bodendecker-Test den Fußabdruck prüfen:
  `ctx.in_bend_corridor(z, x, reach, half_len)` mit `reach = absf(x) - absf(x_vorderkante)` (bei `align: edge` die
  Ausdehnung × Maßstab, sonst halbe Breite × Maßstab = Kronenradius) und `half_len` = halbe Breite × Maßstab. Gemessen
  bliebe nichts Weglassbares in der Hülle (Rest 269, nicht weglassbar); zurück kämen 15.954 statt 22.432.
  Außerdem den `test_props.gd`-Hunk (Vorlage Stück 13) beim Zusammenführen beachten.
- **Station (`builders/station.gd`):** `bend_corridor_at()` könnte wie der Grenz-Builder die genaue Hülle lesen
  (`tp.sight.width_near(k, side)`) statt der aufgerundeten Kodierung.
- **Leitung:** Stadtkurven – soll in den City Limits der F2-Bedarf aus dem Tempolimit gelten (§8.3)?
- **Integration/QA:** `modern_slice.md5` nach dem Zusammenführen neu erzeugen (4 von 6 Bildern ändern sich gewollt).
- **Leistung:** `perf_stats()` → `streamer.corridor_sync_*` zeigt jedes Nachrechnen im Hauptthread; bei Zeitraffer 40
  ist es unvermeidlich (§5).

