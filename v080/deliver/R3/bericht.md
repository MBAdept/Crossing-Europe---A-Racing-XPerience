# Bericht R3 – Fahrzeuge und Schilder (v0.8.0, Abschnitt 1)

- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-1`
- Branch: `worktree-wf_2e14ac26-9d4-1`, Sicherung `origin wip/v080-r3` (nach jedem Commit gepusht, nie erzwungen)
- Basis: `d025d1d` (R1a `65c7560` + AS1 `53bcc1b`); Kopf: siehe Abschnitt 3
- 20 Dateien (+ 16 `.uid`): 16 neu, 4 geändert (`vpbr.gdshader`, `glass.gdshader` – nur der markierte R3-Teil –,
  `model_factory.gd`, `docs/renderer-modern.md` §10). Keine eingefrorene Arcade-Datei, keine Datei eines anderen
  Pakets. Kein Code nennt eine Klasse eines anderen Pakets dieses Push; Ebenen und Builder werden über
  `renderer.layer(id)` und `has_method` erreicht.

**Wie die Angaben zu lesen sind.** „gemessen“ heißt: auf dieser VM gelaufen (headless bzw. Mesa llvmpipe unter
Xvfb), mit dem Stand, der dabeisteht. „gefolgert“ heißt: aus dem Code oder aus Bildern geschlossen, nicht gemessen.
Über echte Grafikkarten und das Steam Deck sagt dieser Bericht nichts.

## 1. Was geliefert ist

| Teil | Dateien | Stand |
|---|---|---|
| Fahrzeug-Ebene | `scripts/race3d/layers/vehicles.gd`, `scripts/race3d/vehicle_pose3d.gd` (rein, getestet) | fertig |
| Modelle aus dem Manifest, Gelenke, Kasten-Stellvertreter | `scripts/race3d/model_factory.gd` (`build(…, articulated)`, `groups`, `build_box`, `box_lights`) | fertig |
| Lichtpunkte | `scripts/race3d/layers/flares.gd`, `assets/shaders/modern/flare.gdshader` | fertig |
| Lack, Glas, Kontaktschatten | `vpbr.gdshader`, `glass.gdshader` (R3-Teil), `contact_shadow.gdshader` | fertig, Abweichung Himmel (5.2) |
| Schilder | `scripts/race3d/sign_atlas.gd`, `sign_canvas.gd`, `builders/signs.gd`, `sign.gdshader` | fertig |
| Prüfungen | 3 Unit-Testdateien (18 Tests), `tests/race3d/check_vehicles.gd`, 2 Render-Prüfungen, Prüf-Renderer | grün (Abschnitt 3) |
| Doku | `docs/renderer-modern.md` §10 | fertig |
| Bilder | 14 A/B-Bilder in diesem Ordner | Abschnitt 4 |

## 2. Abnahme Punkt für Punkt

| Nr. | Punkt | Ergebnis | Beleg |
|---|---|---|---|
| 1 | Fahrzeuge datengetrieben aus dem Manifest; neues Modell ohne Codeänderung | erfüllt | Ebene fragt `ModelDB` je Set, baut jede Stufe über `ModelFactory.build`; Stufen, Grenzen, Gelenke (`groups`), Räder, Lampen und Maße kommen aus dem Manifest, kein Set-Name steht im Code der Ebene oder der Fabrik (die Kastenform folgt den Maßen). Gemessen: `check_vehicles lampen` findet Modell bzw. Kasten jedes Autos. Eine Probe mit einem neuen Modell gab es nicht (gefolgert). |
| 2 | Set ohne Modell = Kasten in Größe und Lack, mit Lampen und Schatten, nie ein fehlendes Auto | erfüllt | `check_vehicles kasten` (traffic/sports_red, police/at als Kasten mit Lampen; fehlendes Modell → `build_box`); Unit-Test `test_box_stand_in`; Bild 01 (gelber Sportwagen) |
| 3 | Pose aus zwei Pfadpunkten (Gier und Nick folgen der Straße); Grundfläche = Kollisionsquader ± 0,3 m | erfüllt | Unit-Test `test_footprint_matches_collision_box`: 20 Posen (Gerade, R 400/136/120 m, beide Richtungen, Steigung, Sattelzug starr und mit Gelenk), alle Ecken ≤ 0,3 m (gemessen); `test_pose_conventions` |
| 4 | Eigene Richtung aus der Quergeschwindigkeit; Spielerterme Lenken × 3°, Untersteuern × 6°, Wanken ≤ 2,5°, Blinken über `visible` | erfüllt | `test_player_terms` (3°, ±6°, Spurwechsel atan(v/s), Wanken −2,5°); Blinken: Spieler wird bei `visible = false` nicht gezeichnet, Pose läuft weiter (Code) |
| 5 | Räder drehen und lenken (linke Räder: Vorzeichen gedreht) | erfüllt | `test_wheel_spin_and_steering` |
| 6 | Detailstufen 40 m / 120 m nach Wegstrecke, `IMPOSTOR` möglich | erfüllt mit Abweichung | Grenzen aus dem Manifest (Pkw 40/120 m, Sattelzug 60/180 m), skaliert mit `vehicle_lod0_m`/`vehicle_lod1_m` der Qualitätsstufe; `test_lod_with_hysteresis` (40/120, Qualitätsfaktoren, 5 % Hysterese, `lod_for` antwortet `ModelDB.IMPOSTOR` bei Modellen mit Fernbild). Kein Fahrzeug hat ein Fernbild; die Ebene behält jenseits der letzten Stufe die letzte (5.3) |
| 7 | Lampen über `lamp_a`/`lamp_b`: Rücklicht nachts oder im Tunnel, Bremse, Blinker 0,72 s, Blaulicht | erfüllt | `check_vehicles lampen` (gemessen: Tag und Nacht mit Verkehr, 180 Autos der Ansicht mit Set, Modell und Lampen = Ansicht; Zustände ohne Rücklicht, Bremse, Blinker, Rücklicht), `test_lamps_follow_view_flags` (auch Tunnel und Blaulicht), `test_indicator_constants_equal_arcade`. Phase aus `blink_t` der Ansicht (5.1) |
| 8 | Sonnenmaske | erfüllt | Instanz-Uniform `sun` = 0 im Tunnel (Code, `snapshot().sun`); Tunnelbild nicht gemacht |
| 9 | Ausblendung = Arcades `_item_alpha` (F5) | erfüllt | `test_fade_equals_arcade_item_alpha`: 80 Stellen offen und im Tunnel gleich `RoadRenderer._item_alpha` (gemessen); Schilder-Shader dasselbe Gesetz (`test_sign_shader_uses_the_same_law`) |
| 10 | Schattenwerfer oder Fleck je Voreinstellung; weicher Kontaktschatten unter jedem Auto in jeder Voreinstellung | erfüllt | `check_vehicles schatten` (gemessen, `4d02ada`): je Voreinstellung eine Etappe – deck, low, medium, high: Kontaktschatten unter 15 von 15 Autos in Sicht (Modelle, Kästen, Spielerauto); Werfer an / aus / an / an, genau wenn `shadow_casters ≥ 1` (Schattenhülle des Modells bzw. der Kasten selbst); ohne Werfer ist der Kontaktschatten kräftiger (0,72 statt 0,55). Bilder 01 (Mittel) und 05 (Hoch) |
| 11 | Sattelzug (und Busse) aus Teilen mit Gelenk | erfüllt für den Sattelzug | `test_articulated_semitrailer_follows_the_bend`, `check_vehicles kasten` (2 Einheiten bei lod0), Bild 06. Busse: es gibt noch kein Busmodell; sobald eines `groups` hat, gilt derselbe Weg (gefolgert) |
| 12 | Lichtpunkte nie kleiner als in Arcade (F6), entlang `lights[].dir` versetzt | erfüllt | `test_flares_keep_arcade_sizes` (Radien und Mindestgrößen = Arcades Konstanten); `check_vehicle_lights` (gemessen): Blinker bei 300 m Kern 3 × 2 px (Tag) / 2 × 2 px (Nacht) ≥ `INDICATOR_MIN_PX`, Schein bis 4,2 / 5,4 px; Rücklicht an N1 (Sicht 338 m, Auto bei 283 m) +0,304 Leuchtdichte; Bremslicht bei Tag 50 / 150 / 300 m Rot +0,74 / +0,73 / +0,11. Versatz 6 cm entlang `dir` (Code, `FLARE_OFFSET_M`) |
| 13 | `add_static(parent, lamps)` mit Fernschein | erfüllt | `check_vehicles lampen_fest` (gemessen): bei Tag aus; nachts nah 0,35, fern 0,87 (Fernschein trägt die Lampe); folgt dem Elternknoten; vergessen, wenn er geht |
| 14 | Verdeckung über den Tiefenpuffer: hinter Kuppe oder Lkw 0 px | erfüllt | `check_occlusion` (gemessen): Kassel – Würzburg km 61,6 (T2), Auto hinter der Kuppe bei 346 m: 0 von 921.600 Pixeln geändert um 12 und 22 Uhr (Gegenprobe bei 20 m: 4545 / 5623 px); hinter dem Sattelzug bei Nacht 0 Pixel (ohne Lkw 853 px) |
| 15 | Lack mit Klarlack, der den Himmel spiegelt; Flakes, Chrom, Gummi, Glas mit Spiegelung | erfüllt mit Abweichung | Analytischer Himmel statt `Sky` der Umgebung (5.2); Bilder 01–05; `check_models` grün mit neutralen Vorgaben |
| 16 | Lampen leuchten ohne Ausbrennen zu Weiß (A-4) | erfüllt | `check_models lampen` (gemessen, mit dem ausgelieferten `vpbr`): Bremslicht ff4641, Rücklicht 9e0b00 (Bremse 2,63 × Rücklicht), Blinker ffa433 (33°), Blaulicht 4676ff – keine Lampe weiß. `lamp_energy`/`lamp_gain` von AS1 unverändert; Bilder 02, 08 (Rücklichter rot mit Schein) |
| 17 | Schilder in `prepare()` mit `SignPainter` vorgezeichnet, Mipmaps, headless Platzhalter, `prepare_pending()` | erfüllt | `test_stage_catalogue` (Platzhalter, nichts offen), Render-Bilder 09–14 (echter Atlas) |
| 18 | Keine SubViewport, keine Textur während der Fahrt (Zähler) | erfüllt | `check_vehicles schilder` (gemessen): 338 Schilder kamen in Sicht (fuel, limit, distance, crest, curve, chevron, unlimited, fuel_lane), Atlas in `prepare()` mit 17 Zellen, während der Fahrt 0 SubViewports und 0 Texturen (`SignAtlas`-Zähler), jedes Schild mit Zelle |
| 19 | Tafeln mit echten Pfosten im Querschnitt, Wandvarianten, Rückstrahlung | erfüllt | `test_every_kind_has_board_and_posts` (jede Art: Tafel, Höhe, Pfosten; Wand ohne Pfosten), `test_builder_mesh`; Rückstrahlung im Shader, Bild 14 (Kamera als Ersatz-Scheinwerfer, 5.4) |
| 20 | Jede Schildart, die `Track` setzen kann, wird gezeichnet | erfüllt | alle Arten aus `SignPainter.HALF_WIDTH_M` (≥ 15) im Unit-Test; Katalog einer Etappe enthält limit, radar, fuel, town, town_ahead, distance, curve, crest, chevron |
| 21 | ≤ 40 µs je Auto und Bild bei 23 Autos | erfüllt (Median) | `check_vehicles leistung` (gemessen headless, 23 gestellte Autos + Verkehr = 34 in Sicht, 120 Bilder): Median 31,3 … 36,4 µs je Auto und Bild in 6 Läufen. Das 90. Perzentil lag bei 35,2 … 47,9 µs – die VM war geteilt und belastet (Last bis 5,5 auf 4 Kernen, `nice 10`); die Prüfung misst den Median |
| 22 | Keine Allokationen je Bild im heißen Pfad | erfüllt (Knoten gemessen, Rest gefolgert) | `leistung`: 0 Knotenbauten in 120 Bildern; Puffer (`PackedFloat32Array`) werden wiederverwendet, Uniforms nur bei Änderung (Code). GDScript-interne Temporärwerte nicht gemessen |
| 23 | Keine Klasse eines anderen Pakets genannt | erfüllt | Code durchgesehen; nur Arcade-Klassen (lesend), `ModelDB`, `ModelFactory`, `ModernMaterials`, `ChunkBuilder` |
| 24 | A/B-Bilder | geliefert | Abschnitt 4 |

## 3. Prüfungen – was auf welchem Stand lief

Kopf: **`4d02ada`** = `origin wip/v080-r3` (gleicher Hash, mit `git ls-remote` nachgesehen), Arbeitsbaum sauber.
Commits seit der Basis: `f57f9dc`, `041586b`, `dbbdd37`, `3e8f408`, `6e95512`, `e5882f3`, `37cd54d`, `1ca9f7b`,
`3655c19`, `4d02ada`.

| Lauf | Stand | Ergebnis (gemessen) |
|---|---|---|
| `tools/run_tests.sh`, vollständig (einmal) | `3655c19` | **bestanden**: 241 Skripte ohne Fehler, 594 Unit-Tests 0 fehlgeschlagen, 78 `CHECK`-Zeilen 0 `FEHLER`; 566 s |
| `tools/run_tests.sh vehicles` (Filter) | `4d02ada` (vor dem Commit, gleicher Inhalt) | bestanden: 241 Skripte, `test_vehicles` 11 Tests, `check_vehicles` 6 von 6 OK (mit der neuen Prüfung `schatten`) |
| `tools/run_render_checks.sh modern` | `4d02ada` | **5 von 5 Dateien in Ordnung**: `check_facade_render` 5, `check_models` 6, `check_occlusion` 2, `check_seam_render` 6, `check_vehicle_lights` 3 |
| `tools/golden.sh check` (einmal, am Ende) | `4d02ada`, sauberer Baum | **GOLDEN arcade: 20 von 20 identisch** (174 s) |
| `check_vehicles --only=leistung`, dreimal | `4d02ada` | Median 36,4 / 31,6 / 32,0 µs, p90 47,9 / 46,5 / 35,5 µs |

Zwischen dem vollständigen Lauf (`3655c19`) und dem Kopf liegt nur `4d02ada`: zwei Felder mehr in
`vehicles.snapshot()`/`perf()` (`cast`, `caster`, `contact_shadows`), die Prüfung `schatten` und Doku. Darauf liefen
die Skriptprüfung aller 241 Skripte, die Fahrzeug-Tests, alle Modern-Render-Prüfungen und `golden.sh` – die
übrigen Unit-Tests und Prüfungen des vollständigen Laufs nicht noch einmal.

`run_tests.sh` wurde einmal vollständig gestartet; die Arcade-Render-Prüfungen (`run_render_checks.sh arcade`)
liefen in R3 nicht (R3 ändert keine Arcade-Datei; `golden.sh` ist grün).

## 4. Bilder

Alle Bilder: links Arcade, rechts Modern, 1280 × 720 je Hälfte, Mesa llvmpipe unter Xvfb. Die Straße in Modern ist
die Debug-Straße des Gerüsts (R1a: ohne Markierung, ohne Leitplanke, ohne Bäume) – das gehört nicht zu R3. Die
Bilder 01–05 sind echte Spielstände (`tools/ab_shot.sh`, Stand `1ca9f7b`, Code wie Kopf); 06–14 sind gestellte
Szenen derselben Etappe (Autos bzw. nichts an festen Stellen, Weltuhr angehalten). 06–08: Fahrzeugcode wie Kopf
(Stand `e5882f3`); 09–14: Arbeitsstand von `37cd54d` (Schilder mit Fülllicht – aus den Dateizeiten gefolgert).

| Datei | Inhalt |
|---|---|
| `01_s1_tag_spieler.jpg` | Spielerauto von hinten, S1 Kiel – Hamburg km 3,6, 12 Uhr, „Mittel“; daneben ein Sportwagen als Kasten |
| `02_s1_nacht_spieler.jpg` | dieselbe Stelle um 22 Uhr: Rücklichter mit Schein, Verkehr weit vorn nur als Rücklichter |
| `03_dichter_verkehr.jpg` | Dortmund – Frankfurt km 199,9, 17:30 Uhr: Verkehr bis zum Horizont, Entfernungstafel, Tempo 100, Ortstafel |
| `04_s3_tag.jpg` | S3 Kiel – Hamburg km 60,7, 12 Uhr |
| `05_s1_tag_hoch.jpg` | wie 01, Voreinstellung „Hoch“ (Fahrzeuge werfen Schatten) |
| `06_lkw_ueberholt_lkw.jpg` | roter Sattelzug (Blinker rechts) überholt weißen Sattelzug, dahinter bremsender Pkw, 15 Uhr |
| `07_blinker_bremse_tag.jpg` | Bremslicht und Blinker bei 50 m (links), 150 m (rechts), 300 m (Mitte), 12 Uhr |
| `08_blinker_bremse_nacht.jpg` | dasselbe um 22 Uhr |
| `09_schild_s1.jpg` … `13_schild_s5.jpg` | Schilder an S1 (Entfernungstafel Hamburg 94 km, dahinter ein Warnzeichen), S2 (Tankspur), S3 (Tempo 120), S4 (Ortstafeln Hamburg auf beiden Seiten, km 75), S5 (Vorankündigung Hamburg 4 km) |
| `14_schild_nacht.jpg` | Ortstafel Hamburg um 22 Uhr |

**Urteil (ehrlich, am Bild gegen Arcade).**

- *Besser:* Das Spielerauto ist ein echtes Modell: Heckscheibe und Lack spiegeln den Himmel, die Leuchten haben
  Tiefe, das Auto steht mit weichem Kontaktschatten auf der Straße und dreht sich mit der Kurve. Der Sattelzug
  ist von hinten sofort lesbar, der Blinker am Überholer gut zu sehen. Die Schilder tragen Arcades Schrift
  gestochen scharf, stehen auf echten Pfosten und an denselben Stellen wie in Arcade. Hinter einer Kuppe oder
  einem Lkw leuchtet nichts durch (0 Pixel, gemessen).
- *Gleich:* Rücklichter und Bremslichter bei Nacht (Farbe, Schein, Größe) entsprechen Arcade; Schilder bei Tag
  und Nacht etwa so hell wie in Arcade.
- *Schlechter:* Alle Sets ohne Modell (Sportwagen, Lieferwagen, Busse, SUV, Polizei, drei Spielerautos) fahren als
  Kasten – deutlich schlechter als Arcades Sprites (Bild 01: gelber Kasten neben Arcades Sportwagen). Das
  Spielerauto liegt mittags im eigenen Schatten (die Sonne steht in Fahrtrichtung); das Fülllicht hält es lesbar,
  aber es wirkt etwas flacher als Arcades Sprite. Nachts fehlt der Scheinwerferkegel auf der Straße (Ebene
  `lights`, nicht R3), dadurch ist das Bild dunkler als Arcade.
- *Fehlt (nicht R3):* Straßenmarkierung, Leitplanken, Bäume, Tankstelle, Häuser – das macht das Modern-Bild noch
  viel leerer als Arcade.

## 5. Abweichungen

1. **Blinkerphase aus `blink_t`** (dem Blinkertakt der Ansicht je Auto, wie Arcade) statt aus `view.time`. Periode
   0,72 s wie verlangt; so blinkt jedes Auto im selben Takt wie in Arcade.
2. **Himmel analytisch.** Der Klarlack spiegelt eine aus der Palette gerechnete Umgebung (Zenit, Horizont mit
   Landschaftsband, Boden; im Tunnel die Röhre) statt der `Sky`-Spiegelquelle der Umgebung: der Stand hat keine
   `Sky` (eingebaute Umgebung von R1a), und so gilt die Spiegelung in jeder Voreinstellung gleich. Bekommt die
   Umgebung (R1) einen `Sky` mit Spiegelung, muss `env_energy` (Ebene `vehicles`, `LOOK`) gesenkt werden, sonst
   spiegelt der Lack doppelt.
3. **Keine Fernbilder für Fahrzeuge.** `lod_for` antwortet `ModelDB.IMPOSTOR`, wenn ein Modell eines hat; kein
   Fahrzeug im Manifest hat eines, die Ebene behält jenseits der letzten Stufe die letzte (lod2).
4. **Rückstrahlung ohne eigene Scheinwerfer:** solange niemand `ce_headlight_*` setzt (Ebene `lights`), steht nachts
   die Kamera für die Scheinwerfer ein (Reichweite `render.headlight_range_m`).
5. **Kontaktschatten als eigener Shader** `contact_shadow.gdshader` (im Vertrag nicht aufgeführt).
6. **Fülllicht am Spielerauto** (`fill` = 0,7 × `ce_ambient`) – nicht im Vertrag; Arcade hellt sein Spieler-Sprite
   ebenso auf. Ohne es lag das Heck mittags deutlich dunkler als Arcades Sprite.

## 6. Vertragsfragen

1. `ModelDB.lod_for_distance(model, dist, dist_scale)` hat nur einen Faktor; Fahrzeuge brauchen zwei
   (`vehicle_lod0_m / 40`, `vehicle_lod1_m / 120`) und Hysterese – deshalb `VehiclePose3D.lod_for`. Gleiches
   Ergebnis ohne Qualitätsfaktoren.
2. `glass.gdshader` gehört zwei Paketen (AS1 Aussehen, R3 Instanz-Uniforms und Ausblendung); R3 hat die
   Spiegelung als markierten Block dazugeschrieben – wer das Aussehen weiter abstimmt, muss ihn stehen lassen.
3. Die Sonne steht mittags in Fahrtrichtung (R1a-Umgebung): jedes Heck liegt im Eigenschatten. Das ist eine
   Frage der Umgebung (R1), nicht der Fahrzeuge.
4. `ce_headlight_*` (Ebene `lights`) ist im Stand nicht gesetzt; Schilder und Lack lesen es, sobald es da ist.
5. Der Vertrag nennt keine Konfigurationsschlüssel für die R3-Konstanten (Lichtpunkt-Versatz, Kontaktschatten,
   `LOOK`, Fülllicht); sie stehen im Code (`layers/vehicles.gd`, `layers/flares.gd`).

## 7. Hinweise für die Nächsten

1. AS2a/AS2b: neue Modelle erscheinen ohne Codeänderung; Gelenkbusse brauchen nur `groups` mit Drehpunkten wie
   der Sattelzug. Ein Fernbild (`impostor`) für Fahrzeuge würde zurzeit nicht gezeichnet (5.3).
2. R1 (Umgebung): Sonne nicht in Fahrtrichtung stellen; bei einem `Sky` mit Spiegelung `env_energy` senken (5.2).
3. R1/R4 (`lights`): `ce_headlight_pos/dir` und `ce_headlight` (Reichweite, Stärke) setzen – dann nutzen Schilder
   die echten Scheinwerfer statt der Kamera.
4. R6 (Brücken/Portale): Start- und Zielbrücke (`side` 0) baut der Builder `gantry`, nicht `signs`.
5. Wer `renderer.add_lamps()` nutzt: die Lampen verschwinden mit ihrem Elternknoten; nachts leuchten Rollen
   `lights`/`street`/…, `on` immer (Prüfung `lampen_fest`).
6. `check_facade.gd` (Prüfung von R1a) fiel während R3 einmal von vier Läufen bei „fassade“; im vollständigen
   Lauf grün. Ursache nicht untersucht – beobachten.
7. Leistung: gemessen headless auf dieser VM; auf dem Deck nachmessen (`perf().vehicle_us_avg`).

## 8. Nicht gelaufen / nicht gezeigt

- Kein Bild im Tunnel (Sonnenmaske, Rücklicht im Tunnel nur im Code und in `test_lamps_follow_view_flags`).
- Kein Bild mit Polizei-Blaulicht (Kasten mit Blaulicht A/B, im Unit-Test und in `check_vehicles kasten`).
- Keine Messung auf echter Grafikkarte; alle Zeiten von dieser VM.
