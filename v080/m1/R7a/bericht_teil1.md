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
  mindestens eine Kamera) bis zwei Stücke über das fernste ladbare hinaus; Zeiten in `stats()`
  (`corridor_warm_ms_avg/_max`).
- `chunk_context.gd`: nur Kommentare (Schnittstelle unverändert – Requisiten, Stadt, Tankstelle folgen über
  `in_bend_corridor()` / `corridor_width()` von selbst).
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
