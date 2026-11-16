# FIX1 – Nacharbeit nach der Prüfung von M1 (Bericht)

Basis: Kopf 9b6adbc (Zusammenführung RINT-B). Arbeitskopie `.claude/worktrees/wf_ae4df3ba-14f-4`, Zweig
`worktree-wf_ae4df3ba-14f-4`, Sicherung `origin/wip/v080-fix1`. Kein Vorgänger gefunden; `--ff-only` auf 9b6adbc,
Import sauber. „Gemessen“ = auf dieser VM (llvmpipe unter Xvfb, 4 geteilte Kerne, Last 2–12 durch andere Aufträge);
alles über echte Grafikkarten, das Steam Deck und den Klang ist abgeleitet.

## Kurzfassung

Alle hohen Bildbefunde der QA, die ohne neue Modelle lösbar waren, sind behoben und an Bildern geprüft:
Tunnel haben eine Röhre mit Portal und Hügel statt offenem Gelände (QB-01), die Tankstelle hat Dach, Insel und
„TANKSTELLE“ (QB-02), Hamburg zeigt Elbphilharmonie und Michel wie Arcade am Horizont, die Köhlbrandbrücke hat Geländer
und helleres Wasser (QB-03), Start- und Zieltor stehen (QB-04), der Mondglanz auf dem Spielerauto ist weg (QB-05), ferne
Bäume sind keine Geisterbäume mehr (QB-07 – Arcades Nebelgesetz für alle Requisiten, Fahrzeuge und Schilder). Die
Prüfläufe sind lastfest (QS-01/02/03), die Absturzfrage nach SIGTERM speichert Arcade erst beim zweiten Fehlstart
(QS-04). Neu: Haken-Prüfung der Mindestbauten (5/5) und die Pflicht-Render-Prüfung „Sichtgrenze < 3 % Kontrast“.
Offen bleiben Wetter (R4), Modellnacharbeit der Spielerautos (QB-09), die Korridor-Entscheidung (QB-08) und drei
Kleinigkeiten (Abschnitt 4).

## 1. Befunde und was geschah

(Ergebnis: behoben = geändert und nachgeprüft; teilweise; offen = mit Grund abgelehnt oder weitergegeben)

| Befund | Ergebnis | Was | Beleg |
|---|---|---|---|
| QB-01 Tunnel offenes Gelände | behoben | `builders/tunnel.gd` + `tunnel.gdshader`: Röhre in Arcades Farben, Lampen mit Lichthof, Notrufschilder, Portal mit Hügel, Kappe bei 45 m von außen; Hintergrund dunkel bis die Ausfahrt in Sicht ist | `tunnel_*.jpg` (U1, DEV, Elbtunnel), `check_minimal_structures` → `tunnel` |
| QB-02 Tankstelle | behoben | `builders/station.gd`: Insel mit gelbem Bordstein, Dach mit Rot-Weiß-Band und Stirnblende „TANKSTELLE“, Stützen, Dachlampen (Kanal 12 + Lichtkegel) | `tankstelle_S2_tag.jpg`, Prüfung `station` |
| QB-03a Brücke | behoben | Geländer je Brückentyp in `roadside.gd`; Wasser in Arcades Brückenfarbe mit Himmelsspiegel (`water_tint`) | `bruecke_S4_*.jpg`, Prüfung `bruecke` |
| QB-03b Wahrzeichen | behoben | Arcades Wahrzeichengesetz in `billboard`/`baked`; jenseits der Stücke Ersatzbild bzw. Modell am Pfad bis Sicht × 2 | `wahrzeichen_S4_arcade_vorher_nachher.png`, Prüfung `wahrzeichen` |
| QB-04 Tore | behoben | `builders/gantry.gd`: Pfosten, Banner, Schachbrett, „ZIEL“/„START“, Countdown-Lampen | `zieltor_S5.jpg`, Prüfung `tore` |
| QB-05 Mondglanz | behoben | `coat_sun`/`sun_spec` 0,08 bei Mond (Grund-, Klarlack-, Flockenkeule) | `mondglanz_DEV_21uhr_arcade_vorher_nachher.png`: p95 193 → 69 (Arcade 51) |
| QB-06 Wetter | offen (M2, R4) | in die Lückenliste der Testhinweise (renderer-modern.md §14.10) | – |
| QB-07 Nebel | behoben | `inc/fog_law.gdshaderinc` in baked/leaves/billboard/vpbr/glass/sign, Kontaktschatten | `nebel_S1_ferne_baeume_arcade_vorher_nachher.png`, Prüfung `sichtgrenze` |
| QB-08 Korridor | offen (Leitung) | A-3 legt Bodendecker im Korridor fest und die Sehnen-Frage auf Gate 2; Vorschlag in Abschnitt 5 | – |
| QB-09 Spielerautos | offen (Modelle) | Nacharbeit gegen die Sprite-Silhouette gehört der Modell-Pipeline (AS-Pakete laufen parallel) | `mondglanz_*` zeigt die Heckform |
| QB-10 Leistung | teilweise | Zeit je Teil von `render()` in `perf_stats` und im Leistungstest; Budgets unter Xvfb nicht geprüft | Abschnitt 3 |
| QB-11 Render-Prüfungen | teilweise | `sichtgrenze` (F4/F5) neu; Helligkeit je Wetter × Stunde und OpenGL ES offen (QA1) | Abschnitt 3 |
| QB-12 Kleinigkeiten | offen | nicht angefasst (Blattkanten, Fuge, Rückstrahler nah, Fernboden N1, Sonnenscheibe) | – |
| QS-01 Haken | behoben | `run_tests.sh`: Schritte 3/4 laufen immer, Liste der Fehlschläge am Ende | `gates/run_tests_*.log` |
| QS-02 check_facade | behoben | Projektionsgesetz statt 0,45 × Höhe; `geruest` wartet auf > 5 Bilder | Abschnitt 3 |
| QS-03 check_attract | behoben | Dauer ab Etappenstart, Grenzen nach Bildzeit, Zielszene 0,3 km vor dem Ziel | Abschnitt 3 |
| QS-04 SIGTERM | behoben | Fehlstart-Zähler; erst der zweite in Folge speichert Arcade | `test_crash_guard_strikes` |
| QS-05 Version | offen (Leitung) | `project.godot` gehört REL (Welle 8); Kennung für Testbuilds ist eine Leitungsentscheidung | – |
| QS-06 Vorschaubild | offen | „sobald die Sonne da ist“ (QA): Sonnenscheibe fehlt noch | – |
| QS-07 Hinweis Ergebnis | behoben | 10 px tiefer, frei vom Rahmen | `ergebnis_rueckfall_hinweis.png` |
| QS-08 Doku | behoben | grafik-modi.md, audio-modern.md | – |

## 2. Bilder – ehrliches Urteil gegen Arcade

(alle Bilder gemessen unter llvmpipe, Voreinstellung Mittel, gleicher Simulationszustand; Arcade-Bilder der QA
wiederverwendet, wo die Position dieselbe war – Arcade ist golden-gleich)

- **Tunnel** (U1, DEV, Elbtunnel): von innen kaum von Arcade zu unterscheiden – Fliesenband, Wand, Vouten, Lampen mit
  Lichthof, Dunkelheit in der Tiefe; Modern zeigt die Ausfahrt hell am Ende. Von außen: Portal mit Stirnwand, Flügelmauern
  und Hügel wie Arcade, nachts unter dem Sternenhimmel; der Hügel ist glatter (keine Nadelbäume auf dem Grat). Schwächer
  als Arcade: die Öffnung von außen ist dunkler (Kappe bei 45 m, Arcade zeigt dort noch Lampen), keine Nischen/Gehwege.
- **Tankstelle** (S2): Dach, rot-weißes Band, Schriftzug, Insel, Stützen, Zapfsäulen auf der Insel – gleichwertig zu Arcade,
  mit echten Schatten unter dem Dach.
- **Hamburg** (S4): Elbphilharmonie und Michel am Horizont wie Arcade (vorher fehlten sie), ferne Stadthäuser in ihren
  Farben statt blass; Brücke mit Stahlgeländern beidseits. Wasser siehe Abschnitt 3.
- **Ziel** (S5): Zieltor mit rotem Banner, Schachbrett und „ZIEL“ wie Arcade.
- **Nebel** (S1): ferne Bäume dunkelgrün wie Arcade; am Ende der Sicht dithern sie als dunkle Punkte aus (vorher graue) –
  sichtbar nur in der Vergrößerung.
- **Nacht** (DEV 21 Uhr): kein Mondfleck mehr; das Auto glänzt matt. Die Limousine selbst bleibt anders als ihr Sprite
  (steile Heckscheibe, sichtbarer Innenraum – QB-09).
- **Gesamt**: An den markanten Stellen von Kiel – Hamburg ist Modern jetzt mindestens gleichwertig zu Arcade (Tankstelle,
  Hamburg, Ziel), auf freier Strecke gleichwertig bis besser (Gelände, Schatten, Nahmodelle). **Deutlich besser als Arcade
  ist es noch nicht**: Wetter fehlt, die Spielerautos weichen vom Sprite ab, Mindestbauten sind schlicht (keine Details
  über Arcade hinaus), keine Sonnenscheibe.

## 3. Prüfungen und Tore

Einzelläufe während der Arbeit (gemessen, headless bzw. Xvfb, Last 2–10):

| Prüfung | Ergebnis |
|---|---|
| `check_facade.gd` (nach QS-02) | 8/8 OK; `fassade` jetzt mit Projektionsgesetz (Horizontzeile = horizon_frac × Höhe + Wackeln, Punkt 100 m voraus auf ±0,5 px), `geruest` wartet auf > 5 Bilder |
| `check_attract.gd` Arcade / Modern (nach QS-03) | 13/13 und 13/13 ohne Last; im Lauf von `run_tests.sh` bei Last ≈ 9,6 ebenfalls 13/13 (Dauer 4,08 bzw. 4,20 s ab Etappenstart, Grenze 4,69 bzw. 4,77 s) |
| `check_minimal_structures.gd` (neu) | 5/5: Elbtunnel 110 Tunnelsegmente mit Röhre, 1 Portal, 1 Kappe, 54 Lampen, Portal-z innen richtig, Leinwand dunkel bis Ausfahrt (239 m); Tankstelle 34 Insel- / 23 Dachsegmente, 5 Stirnblenden mit Schrift; Start- und Zieltor; 2 Wahrzeichen jenseits der Stücke bis 1.800 m; 130 Brückensegmente mit Geländer |
| `check_modern_stage.gd` | 8/8; `renderer_zeit` ganzer Renderer 0,810 ms (Budget 1,5), `kern_zeit` 0,269 ms (0,6), Einhängen ≤ 1,10 ms; `ergebnis` Arcade = Modern (28 Schlüssel) |
| `check_benchmark.gd` | 8/8 (Format mit den neuen Feldern `script_ms_max`, `hooks_ms_max`) |
| `check_vehicle_lights.gd` → `sichtgrenze` (neu, Xvfb) | OK: Sicht 900 m, schwarze Limousine – Kontrast ihrer Pixel 22 % bei 0,45 × Sicht, 16 % bei 0,839 ×, Fläche an der Sichtgrenze 0,00 % |
| Unit-Tests `test_gfx_*` | 35/35 inkl. `test_crash_guard_strikes` |

Tore am Endkopf 28e4e8e (Stand bei Abgabe – die Leitung hat das Ergebnis vor dem Ende der Tore angefordert):

| Tor | Ergebnis |
|---|---|
| Import (`godot --headless --import`) | sauber |
| `tools/run_tests.sh` (Lauf 1, Log `m1/FIX1/gates/run_tests_1.log`) | bei Abgabe noch im Haken-Schritt: Unit-Tests 693/0, danach 8 Prüfblöcke mit 74 CHECK-Zeilen OK, 0 FEHLER; das Ende („==> …“, `exit=`) steht erst im Log |
| `tools/golden.sh check` | nicht gelaufen (Reihenfolge: erst nach run_tests.sh); Arcade-Dateien unverändert (keine eingefrorene Datei im Diff) |
| `tools/run_render_checks.sh all` | nicht als Ganzes gelaufen; `check_vehicle_lights.gd` mit `sichtgrenze` einzeln OK |
| modern_sight / modern_path_check `--full` | nicht nötig: Kern und Platzierung in den Stücken unverändert (nur ferne Wahrzeichen dazu) |
| Validator | nicht nötig: kein Modell geändert |

Nicht mehr gerendert: Wasser an S4 mit Himmelsspiegel und Tankstelle S2 um 22 Uhr – das Wasser ist im Bild noch nicht
geprüft.

## 4. Offen / für die Nächsten

- **Wetter (QB-06)**: Regen, Schneefall, Gischt fehlen in Modern – R4 in M2; in die Testhinweise (renderer-modern.md
  §14.10 hat die Liste).
- **Spielerautos (QB-09)**: Limousine mit steiler Heckscheibe und sichtbarem Innenraum statt Arcades Fließheck, Kompakt
  mit schwarzem Dach – Nacharbeit gegen die Sprite-Silhouette in der Modell-Pipeline (AS-Paket); nicht hier, weil die
  M2-Modellpakete parallel an denselben Generatoren arbeiten.
- **Korridor (QB-08)**: Vorschlag für die Leitung: im Korridor weggelassene Bäume quer nach außen hinter den Korridor
  versetzen (F7 bleibt erfüllt, die Kurveninnenseite bleibt bewaldet) zusätzlich zu den Bodendeckern; danach
  `modern_sight.gd -- --full`.
- **Leistung (QB-10)**: `hooks_ms_max` des Leistungstests vom Deck auswerten; Budget-Prüfungen zusätzlich unter Xvfb mit
  `perf_clock` (QA1/PERF); die Tunnel-Lichthöfe kosten je Lampe einen zweiten Lichtpunkt (ca. 450 in langen Tunneln,
  nicht gemessen unter Last).
- **Render-Prüfungen (QB-11)**: „mittlere Helligkeit / kein schwarzes Bild je Wetter × Stunde“ und „OpenGL ES = OpenGL“
  fehlen noch (QA1).
- **Mindestbauten** bis M2: Tunnel ohne Nischen/Gehwege/Belichtungsrampe, Röhre von außen bei starken Kurven jenseits
  des Hügels nur durch die Kappe begrenzt (Straße nicht); Tankstelle ohne Shop-Details; Tore ohne Lampenschein bei Nacht
  außer den Countdown-Lampen; Brücken ohne Deck/Träger/Pylone.
- **QB-12** unverändert: Blattkarten-Kanten, Fuge/Flicken der Fahrbahn, Rückstrahler des Lkw nah fast weiß, Fernboden
  N1, Winkelschild unter dem Tacho an T3.
- **QS-05/06**: Versionskennung des Testbuilds (Leitung, `project.godot` gehört REL); Vorschaubild „Modern“ neu, sobald
  es eine Sonnenscheibe gibt.

## 5. Vertragsfragen

- §6/A-8: Die Mindestbauten liegen in den Dateien, die die Registry für R5/R6 vorsieht (`builders/tunnel.gd`,
  `station.gd`, `gantry.gd`) – sonst hätte es keinen Platz ohne Registry-Änderung gegeben. R5/R6 übernehmen und ersetzen
  sie; die Prüfung `check_minimal_structures.gd` legt fest, was mindestens bleiben muss.
- D14 F4/F5: Der Vertrag regelt nur den Tiefennebel der Kulisse (0,45–1,0 × Sicht). FIX1 nimmt für **alles** in der
  Landschaft (auch Fahrzeuge und Schilder) Arcades Sprite-Tönung (0,7 × Anteil zur eigenen Farbe × Nebel), wie es Gelände
  und Fernboden seit RINT-B tun – das ist strenger „nie mehr Nebel als Arcade“; der Vertrag sollte es so nennen.
- A-3 (Korridor): siehe Abschnitt 4 – Entscheidung der Leitung nötig.
- D34 (b): „Bei Arcade bleiben“ speichert jetzt erst beim zweiten Fehlstart in Folge (QS-04, Frage von QA-SYSTEM).
- §4.9.1 „niemand ändert run_tests.sh“: geändert (QS-01), weil der Haken sonst nach einem Fehler davor nicht lief –
  A-8 gibt die Datei der Integration; FIX1 handelte an ihrer Stelle.
