# Bericht R1 – Renderer-Kern: Straße, Umgebung, Licht, Qualität, Aufwärmen

Bauabschnitt R1 von v0.8.0 (Bauplan `docs/dev/v080_contract.md` §6 Welle 1 „R1“, Nachträge A-2…A-8).
Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-1`, Zweig
`worktree-wf_145e8e23-1e4-1`, Sicherung `origin wip/v080-r1`. „gemessen“ = auf dieser Maschine (Mesa llvmpipe unter
Xvfb bzw. headless, 4 geteilte Kerne, während der Läufe Last 7–19 durch andere Aufträge); „abgeleitet“ = gerechnet
oder geschlossen, nicht gemessen. Über eine echte Grafikkarte, das Steam Deck oder ANGLE sagt dieser Bericht nichts
Gemessenes.

## 1. Kurzfassung

Der Vorgänger wurde vom Nutzungslimit gestoppt; ich habe seinen Stand (Kopf a8ec8b8, den letzten Commit hatte der
Lead ungeprüft aus seinen offenen Dateien gemacht) übernommen, geprüft und fertiggestellt. Geliefert sind Fahrbahn
mit aller Markierung im Shader, Leitplanken und Leitpfosten, das Umgebungs-Rig, Hintergrund-, Lichter- und
Overlay-Ebene, Qualitätszustände, Wächter mit `quality_lowered` bis ins Ergebnis, Aufwärmen in vier Lichtsituationen,
`max_chunks` = 18 – und die Nachweise: zwei neue Render-Prüfungen (`check_road_parity`, `check_light_base`), die
Aufwärm-Prüfung mit kaltem Cache (`warmup_cold.gd`), `check_modern_stage` 7/7, Fairness `--full` grün.

Das Bild: die Straße selbst ist in Modern mindestens so gut wie in Arcade und in Dämmerung, Nacht und Regen
sichtbar besser (Licht der tiefen Sonne auf Asphalt und Planken, rückstrahlende Linien im Abblendlicht, nasse
Fahrbahn mit Himmelsglanz). **Als Ganzes ist das Modern-Bild dieses Bauabschnitts aber nicht besser als Arcade**:
ohne Gelände, Bäume, Gebäude, Fahrzeuge und Schilder (R2, R3, spätere Wellen) ist es leer. Ob Modern „deutlich
besser“ wird, entscheidet erst das zusammengeführte Bild (RINT).

## 2. Übernahme und Durchsicht von a8ec8b8

- `git merge --ff-only a8ec8b8` im frischen Arbeitsbaum, `.godot` kopiert, Import, STAND.md sofort umgeschrieben.
- a8ec8b8 (Overlay-Ebene, Licht-/Straßen-Shader mit `pool_ambient`, drei Unit-Testdateien, `check_modern_stage.gd`):
  241 Skripte übersetzen (`tests/check_scripts.gd`), die race3d-Unit-Tests laufen grün (61), die geänderten Shader
  übersetzen unter OpenGL (A/B-Bilder ohne SHADER ERROR, Render-Prüfungen grün). `check_modern_stage` war 6/7: die
  Prüfung „nacht“ wartete darauf, dass der Verkehr mit Seed 11 binnen 600 Bildern auf 140 m herankommt. Jetzt füttert
  sie die Lichter-Ebene mit einem Wagen 60 m voraus und prüft Art, Richtung, Lichtwert, Lage und Reichweite des
  Kegels sowie „kein Kegel jenseits von 140 m“ (Commit 8e468ba). Inhaltlich fand ich in a8ec8b8 keinen Fehler.

## 3. Abnahme (Bauplan §6 R1 und Auftrag)

| Punkt | Ergebnis | Beleg |
|---|---|---|
| Fahrbahn: Asphalt je Straßentyp, alle Markierung im Shader (Rand-, Leitlinien, Striche 6/12 m und 3/6 m, Tankspur-Keil und Trennlinie, Start/Ziel, Zebrastreifen), Seitenstreifen, Mittelstreifen, Bordsteine, Gehwege, Bruchteil-Spuren; Leitplanken mit Pfosten und Rückstrahlern, Leitpfosten | erfüllt | `test_road_builder.gd` (7 Tests), `check_modern_stage` „inhalt“ (Flags von Randlinien, Start, Leitplanken, Tankspur, City Limits mit Bordsteinen und Zebrastreifen), Bilder S1–S5 |
| `check_road_parity`: Linien ≤ 1 px auf der Geraden bei S1 | erfüllt (gemessen) | 0,23 px neben Arcades Reihenmodell, 54 von 54 Proben, 12–150 m |
| Kurven mit `look_gain` 0 (A-3): R ≈ 400 m ≤ 8 px bis 150 m, R ≈ 136 m ≤ 27 px bis 100 m | erfüllt (gemessen) | 7,11 px (Kiel – Hamburg km 7,98) und 13,27 px (Saragossa – Pau km 198,57, T4); die Farbe liegt überall ≤ 0,32 px neben dem eigenen Kameramodell |
| Tageslicht-Proben bei S1 höchstens 10 % neben Arcade (Gras, Asphalt, Himmel) | erfüllt (gemessen) | Asphalt −6,7 %, Gras +1,5 %, Himmel −4,8 % (`check_light_base` „tageslicht“) |
| „Schatten: Aus“ gegen „Mittel“ ± 2 % | erfüllt (gemessen) | −0,32 %, 6.296 Bildpunkte im Schatten, Schattenlicht in beiden Stufen an, mit „Aus“ wirft kein Knoten (`check_light_base` „schatten“) |
| Renderer-Kern ≤ 0,6 ms GDScript je Bild ohne Fahrzeug- und Requisiten-Ebene | erfüllt (gemessen, headless) | 0,208 ms (render() 0,117 ms + Hintergrund 0,494 ms × Anteil 0,19), 1.500 Bilder bei 150 km/h (`check_modern_stage` „kern_zeit“) |
| Einhängen eines Stücks ≤ 3 ms | erfüllt (gemessen, headless) | höchstens 0,41 ms; unter OpenGL siehe 5. |
| 1280 × 800 und 1680 × 720 ohne Lücke gefüllt | erfüllt (gemessen) | `check_road_parity` „fenster“ (Himmel über die ganze Breite, Boden bis in die unterste Zeile, Kamera = ChaseCamera3D) |
| Aufwärm-Prüfung mit kaltem Cache auf der Schnitt-Etappe | erfüllt bis auf Lastrauschen (gemessen) | 0 Shader-Varianten während der Fahrt in allen drei Läufen nach der HUD-Korrektur; Bildzeit-Kriterium (≤ 3 × Median) zweimal bestanden (497/179 ms, 362/189 ms), einmal bei Last 12,5 nicht (ein Bild 1.167 ms bei Median 353 ms, ohne Übersetzung) – Abschnitt 4 |
| `check_modern_stage`: `ERGEBNIS` = Arcade | erfüllt (gemessen) | Kiel – Hamburg mit dem Autopiloten, 28 Schlüssel gleich bis auf `gfx` |
| Umgebungs-Rig: ein Schattenlicht (D5), Umgebung, Nebel F4, Palette jeder Stunde und jedes Wetters, `ce_*`-Globals linear, Nachtboden (A-4), Spiegelhimmel (D7), Nachbearbeitung fest (D6) | erfüllt | `test_environment_rig.gd` (7), `check_modern_stage` „inhalt“, „tunnel“, „nacht“; Bilder |
| Hintergrund: RaceBackdrop bei jedem Seitenverhältnis auf Ebene −10, wahre Horizontzeile | erfüllt | `check_modern_stage` „inhalt“ (Horizont 45 %), `check_road_parity` „fenster“, `check_seam_render` „fenster_16_10“ |
| Lichter: Spots, Punktlicht-Pool, Lichtkegel (Spieler, Verkehr, feste Lampen über `add_static`) auf allen `pool_materials()` | erfüllt | `check_modern_stage` „nacht“, `check_facade` „lampen“ |
| Overlay-Ebene | erfüllt | `check_modern_stage` „nacht“ (Ebene 2, an/aus mit `chase01`) |
| Qualität (Schatten, Auflösung, MSAA, Details, Effekte; nichts Spielrelevantes) | erfüllt | `test_quality.gd` (6), „inhalt“ (MSAA 2×, 100 %, Atlas 2048 bei „Mittel“, nach der Etappe zurück) |
| Wächter im Countdown mit `Gfx.watchdog_verdict`, `quality_lowered` in der Sitzung | erfüllt | „waechter“ (Mittel → Niedrig, Viewport, Schattenwerfer aus, Schattenmodus bleibt, HUD-Meldung, Ergebnisfeld `gfx_lowered`) |
| `graphics.modern.max_chunks` = 18; `modern_sight --full`, `modern_path_check --full` | erfüllt (gemessen) | F1 0 Fälle bis 270 m in 99,4 Mio. Stichproben, F1 Spuren 0 bis 260 m, F2 0,593 / 0,596 / 0,555, F3 0 von 5.923, F7 0 von 2.011.532, Modell 0 abweichend; Abstand 267,6 m, Schleifen ab 2.064 m, 0 Positionen über 18 Stücken |
| Gates: `tools/run_tests.sh`, `tools/golden.sh check` (20 von 20), `tools/run_render_checks.sh` | erfüllt (gemessen auf 21bca09) | Tests bestanden (596 + 80 Prüfzeilen), 20 von 20 identisch, 7 von 7 Render-Prüfdateien (Abschnitt 6) |
| A/B-Bilder S1–S5 und Morgen, Abend, Nacht | geliefert | Abschnitt 7 |

## 4. Aufwärmen mit kaltem Cache

`tests/race3d/render/warmup_cold.gd` (kein `check_*`, weil es einen leeren Cache braucht; Aufruf im Kopf der Datei).
Das Kriterium des Bauplans (kein Bild > 3 × Median) ist auf dieser Maschine nur bedingt aussagekräftig: der Median
lag bei 179–460 ms je Bild, je nachdem, wie viele andere Aufträge liefen (Last 7–19 auf 4 Kernen); einzelne Bilder
von 1 s kamen auch mit **warmem** Cache vor. Deshalb zählt die Prüfung zusätzlich, was nicht von der Last abhängt:
jede übersetzte Shader-Variante legt im Mesa-Cache eine Datei an – eine Datei, die mehr als eine Sekunde nach dem
Ladebild erscheint, ist eine Übersetzung mitten in der Fahrt.

| Lauf (Kiel – Hamburg km 2, „Mittel“, kalter Cache) | Varianten während der Fahrt | Bilder | Median / längstes |
|---|---|---|---|
| 12 Uhr, vor der Korrektur | 5 (alle in der ersten Sekunde nach dem Ladebild) | 59 | 460 / 1.391 ms |
| 12 Uhr, vor der Korrektur, ohne HUD (`--no-hud`) | 0 | 99 | 297 / 505 ms |
| 12 Uhr, nach der Korrektur | **0** | 162 | 179 / 497 ms (Grenze 538) |
| 19:06 Uhr (Abblendlicht geht an), nach der Korrektur | **0** | 152 | 189 / 362 ms (Grenze 568) |
| 12 Uhr, Endstand, Last 12,5 | **0** | 81 | 353 / 1.167 ms (Grenze 1.057) – ein Ausreißer ohne Übersetzung |

Die fünf Varianten waren die Canvas-Shader des HUD: die Sitzung schickte ihm während der Vorbereitung keinen Zustand,
es zeichnete sein echtes Gesicht erst nach dem Ladebild. Jetzt setzt `race_session.gd` in `_begin_prepare()` den
Startzustand direkt (`hud.state`, nicht `update_state()` – das würde den Countdown-Piepton und die Audio-Hinweise
vor dem Start auslösen); das HUD zeichnet hinter dem deckenden Ladebild mit. Nur Modern betroffen.

## 5. Messwerte

| Messung | Wert | Art |
|---|---|---|
| `render()` GDScript, headless, 1.500 Bilder bei 150 km/h (Straße, Leitplanken, Rig, Hintergrund, Lichter, Overlay) | 0,104–0,117 ms im Mittel (höchstens 1,61–1,75 ms); mit Hintergrund-Zeichnen 0,192–0,208 ms (Grenze 0,6 ms) | gemessen, zwei Läufe |
| Einhängen eines Stücks | headless höchstens 0,41 ms; unter OpenGL höchstens 2,83 ms (Grenze 3 ms) | gemessen |
| unter OpenGL, „Mittel“, km 2, 12 Uhr | `render()` 1,14 ms Wanduhr bei Last 12,5 (die Kerne dreifach überbucht – nicht mit dem headless-Wert vergleichbar), Bauen 7,0 ms im Mittel (Arbeiter-Thread), 37 Zeichenaufrufe, 24.200 Dreiecke; Schattendurchgang meldet der Compatibility-Renderer mit 0 Zeichenaufrufen, obwohl Schatten zu sehen sind | gemessen |
| Vorbereitung unter Xvfb, erste Etappe, kalter Cache | 8,2–17,1 s (Selbsttest 2,7–5,4 s, Aufwärmen 5,2–11,3 s) je nach Last | gemessen |
| Linienlage / Tageslicht / Schatten / Aufwärmen / Fairness | siehe Abschnitt 3 und 4 | gemessen |
| Zeiten auf Steam Deck oder echter Grafikkarte | nicht messbar | – |

## 6. Gates

| Gate | Stand | Ergebnis (gemessen) |
|---|---|---|
| `tools/run_tests.sh` (voll), Lauf 1 | 46456fe | 596 Unit-Tests grün, 79 Prüfzeilen OK, 1 FEHLER: `check_seam` „ablauf“ (Prüfung verlangte leeren HUD-Zustand während der Vorbereitung) – in 21bca09 korrigiert, danach `check_seam` 9 von 9 (643 s) |
| `tools/run_tests.sh` (voll), Lauf 2 | 21bca09 | **Tests bestanden** (619 s): 596 Unit-Tests, 0 fehlgeschlagen, 80 Prüfzeilen OK, keine FEHLER-Zeile |
| `tools/run_render_checks.sh all` | 21bca09 | 7 von 7 Dateien in Ordnung (41 Prüfzeilen OK: Glanz-Verdeckung 16, Spiegelung, Fassade 5, Licht-Basis 2, Modelle 6, Straßen-Parität 4, Naht 6) |
| `tools/golden.sh check` | 21bca09 | **GOLDEN arcade: 20 von 20 identisch** (183 s) |
| `modern_sight.gd --full`, `modern_path_check.gd --full` | Inhalt von 91d2251 (danach keine Kernänderung) | grün, Zahlen in Abschnitt 3 |

## 7. Bilder und Urteil

Alle mit `tools/ab_shot.sh` (derselbe Simulationszustand), Modern mit `--gfx-preset=high`:

| Datei | Urteil gegen Arcade |
|---|---|
| `ab_S1_km2_mittag.jpg` | Straße gleichwertig bis besser (Fahrspuren, Körnung, echte Planken mit Pfosten und weichem Schatten); Bild als Ganzes leerer: keine Bäume, Windräder, kein Spielerwagen (R2, R3). Die Mittagssonne steht in Modern hinter dem Wagen – keine Sonnenscheibe am Himmel |
| `ab_S2_tankspur.jpg` | Tankspur mit breiter Trennlinie und Randlinie richtig, ohne Planke daneben; die Tankstelle selbst fehlt (Stations-Builder, spätere Welle) – deutlich leerer als Arcade |
| `ab_S3_km60.jpg` | wie S1 |
| `ab_S4_city_limits_bruecke.jpg` | Bordsteine, Gehwegplatten, Stadt-Striche 3/6 m richtig; Häuser, Kran, Geländer, Wasserfläche fehlen (blau ist die Wasserfarbe der Geländevertretung) |
| `ab_S5_ziel.jpg` | Ziellinie (Schachbrett) und Gehwege richtig; Zielportal und Häuser fehlen |
| `ab_S1_morgengrauen_0618.jpg` | Farben wie Arcade, Abblendlicht und rückstrahlende Linien geben mehr Tiefe |
| `ab_S1_abend_1924.jpg` | **besser als Arcade**: Gegenlicht der tiefen Sonne glänzt auf Asphalt, Planken und Randlinie |
| `ab_S1_nacht_2300.jpg` | Stimmung wie Arcade, die Planken im Abblendlicht und die rückstrahlenden Linien sind ein Gewinn |
| `ab_S3_regen.jpg` | nasse Fahrbahn mit Himmelsglanz zum Horizont überzeugt; Regenschlieren und Gischt fehlen noch (R4) |
| `fenster_16zu10_1280x800.png`, `fenster_21zu9_1680x720.png` | bis an jeden Rand gefüllt |
| `paritaet_kurve_R400_lookgain0.png`, `paritaet_kurve_R136_lookgain0.png` | die beiden Bilder der Kurvenprüfung (ohne HUD und Leitplanken) |
| `tageslicht_S1_ohne_HUD_arcade_modern.jpg` | das Bildpaar der Tageslicht-Proben |

## 8. Abweichungen vom Bauplan

1. `scripts/race/race_session.gd` setzt während der Vorbereitung den Startzustand des HUD direkt (`hud.state`), damit
   seine Canvas-Shader hinter dem Ladebild übersetzt werden; `tests/race3d/check_seam.gd` „ablauf“ prüft dafür jetzt
   „kein `update_state()` vor dem Start“ statt „leerer Zustand“. Nur Modern.
2. `builders/debug_road.gd` (Kern): das Geländeband der Vertretung trägt die Grasfarben der Landschaft im
   Vier-Segment-Rhythmus, ohne Abdunkeln nach außen (vorher 15 % dunkler als Arcade).
3. Die Aufwärm-Prüfung ist ein Werkzeug (`warmup_cold.gd`), keine Datei von `run_render_checks.sh` (braucht leeren
   Cache), und zählt zusätzlich die übersetzten Shader-Varianten im Mesa-Cache.
4. `check_road_parity` wertet Randlinien nur, solange sie ≥ 1,5 px breit sind, Leitlinien ab 0,6 px;
   `check_light_base` nur Probenpunkte, die in beiden Bildern das Material zeigen.
5. Mittags steht die Sonne in Modern hinter dem Wagen (Entscheidung des Vorgängers, beibehalten): keine
   Sonnenscheibe vorn am Himmel, dafür Licht auf allem, worauf die Kamera blickt.
6. `inc/pools.gdshaderinc` hat über A-7 hinaus `pool_dir` (Richtung der Verkehrskegel) und `pool_ambient`
   (Bezug der Anzeigewerte); neu ist `inc/headlight.gdshaderinc`. Beides additiv.
7. Über das Fein-Detail des Vorgängers hinaus habe ich am Bild nichts mehr verändert (Zeit für die Nachweise).

## 9. Probleme im Bauplan

1. §4.9.4 (kein Bild > 3 × Median) ist auf dieser Maschine lastabhängig: Median 179–460 ms je Bild bei Last 7–19,
   einzelne Bilder um 1 s auch mit warmem Cache. Belastbar ist die Zahl übersetzter Varianten (Mesa-Cache).
2. „Schatten: Aus gegen Mittel ± 2 %“ über das ganze Bild: mit Bäumen und Fahrzeugen liegt mehr Fläche im Schatten,
   das Mittel sinkt dann zu Recht um mehr als 2 %. D5 meint gleich helle beleuchtete Flächen – die Prüfung sollte
   nach der Zusammenführung unbeschattete Bereiche vergleichen.
3. A-3: R ≈ 400 m liegt mit 7,11 px knapp unter der Grenze von 8 px.
4. A-7 nennt für die Lichtkegel nur `pool_pos_r`, `pool_col`, `pool_count`; das Gelände (R2, parallel gebaut) kennt
   `pool_dir`, `pool_ambient` und das Abblendlicht-Include nicht – das muss die Zusammenführung verdrahten.
5. Der Compatibility-Renderer meldet für den Schattendurchgang 0 Zeichenaufrufe; `draw_calls_shadow` in
   `perf_stats()` (§4.4.5) und die Budgets „inkl. Schattendurchgang“ (§4.10) sind so nicht messbar.

## 10. Offene Punkte (für RINT, R2, R3, QA1)

- RINT/R2: Gelände-Mesh auf Render-Ebene 2, `inc/pools.gdshaderinc` + `inc/headlight.gdshaderinc` einbinden,
  Material mit `add_pool_material()` anmelden (docs/renderer-modern.md 10.12).
- RINT: `check_light_base` „schatten“ mit allen Schattenwerfern beobachten (Punkt 9.2); „tageslicht“ misst dann das
  echte Gelände.
- RINT/QA1: `warmup_cold.gd` mit allen Inhalten erneut (Fahrzeug- und Requisiten-Materialien über `warmup_nodes()`).
- Bild: Teernähte und kräftigere Körnung im Nahbereich, Asphalt etwas heller (−6,7 %), Entscheidung über eine
  Sonnenscheibe am Mittagshimmel; erst das zusammengeführte Bild zeigt, ob Modern „deutlich besser“ ist.
- UI1/UI2: das HUD muss ohne `update_state()` zeichenbar bleiben (`hud.state` wird vor dem Start direkt gesetzt).
- DOC (Welle 8): ARCHITECTURE.md §15 um `quality_lowered`, `gfx_lowered`, `RaceRenderers.leave_modern()` ergänzen.

## 11. Geänderte Dateien (seit dem Gerüst 65c7560, ohne .uid)

Neu: `assets/shaders/modern/{road, overlay, reflector}.gdshader`, `assets/shaders/modern/inc/headlight.gdshaderinc`,
`scripts/race3d/{environment_rig, quality, prewarm, perf_probe}.gd`, `scripts/race3d/builders/{road, roadside}.gd`,
`scripts/race3d/layers/{backdrop, lights, overlay}.gd`, `tests/race3d/check_modern_stage.gd`,
`tests/race3d/render/{check_road_parity, check_light_base, warmup_cold}.gd`,
`tests/unit/race3d/{test_road_builder, test_quality, test_environment_rig}.gd`.
Geändert: `assets/shaders/modern/inc/pools.gdshaderinc`, `config/game_config.json` (`graphics`: max_chunks 18,
prepare_timeout_s, _doc), `docs/renderer-modern.md`, `scripts/race/{race_session, race_renderers}.gd`,
`scripts/race3d/{modern_renderer, chunk_streamer, plain_environment}.gd`, `scripts/race3d/builders/debug_road.gd`,
`tests/race3d/{check_seam, fairness}.gd`, `tests/sim/modern_path_check.gd`, `tests/unit/race3d/test_chunk_streamer.gd`.
