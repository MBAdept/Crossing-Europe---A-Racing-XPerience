# Renn-Modul – Strecke, Pseudo-3D-Renderer, Rennsitzung

Technische Dokumentation des Renn-Moduls (Eigentum: `scripts/race/*`, `scenes/race/*`, `data/scenery.json`,
`tests/unit/race/*`, `tests/race/*`, `tests/fixtures/*`, Konfigurationsabschnitte `road`, `render`, `debug`).
Verträge stehen in [ARCHITECTURE.md](../ARCHITECTURE.md) §5, §6, §8 und für die Fahrzeuge in
[fahrzeug-darstellung.md](fahrzeug-darstellung.md); hier steht, wie es funktioniert und woran man dreht.

## 1. Dateien und Klassen

| Datei | Klasse | Aufgabe |
|---|---|---|
| `scripts/race/track.gd` | `Track` | Strecke einer Etappe als 3-m-Segmente, deterministischer Kurven-/Hügelgenerator, Spuren, Tankspur, Schilder, Bauwerke |
| `scripts/race/track_segment.gd` | `TrackSegment` | ein Segment (Kurve, Höhe, Spuren, Straßentyp, Tunnel, Requisiten …) |
| `scripts/race/projection.gd` | `RoadProjection` | Kameramathematik, Ein-Drittel-Regel (`visible_fraction`) |
| `scripts/race/road_renderer.gd` | `RoadRenderer` | Pseudo-3D-Renderer (Node2D, `_draw`) |
| `scripts/race/backdrop.gd` | `RaceBackdrop` | Himmel (Verlauf, Sonne, Mond, Sterne, Wolken) und Hintergrund-Silhouetten je Landschaftsstil |
| `scripts/race/sign_painter.gd` | `SignPainter` | prozedurale Schilder mit Text (Tempo, Radar, Tankstelle, Ortsschild und sein Vorschild, EU-Grenze, Tunnel, Autobahn, Start/Ziel) |
| `scripts/race/geo_batch.gd` | `GeoBatch` | sammelt farbige Vierecke und schickt sie als ein Dreiecks-Array an den RenderingServer |
| `scripts/race/vehicle_pose.gd` | `VehiclePose` | Fahrzeugdarstellung v2, reine Mathematik: Darstellungswinkel mit Fahrzeuglänge, kritisch gedämpfte Glättung, Zellwahl mit Hysterese, Gierwinkel und Neigung des Spielerautos |
| `scripts/race/box_vehicle.gd` | `BoxVehicle` | Lkw/Busse als texturierte Quader: sichtbare Flächen, Abschnitte entlang der Straße, nahe Ebene, Texturkoordinaten |
| `scripts/race/palette.gd` | `Palette` | Farben nach Tageszeit, Wetter, Tunnel |
| `scripts/race/race_session.gd` | (Szene `scenes/race/race.tscn`) | Rennsitzung: Countdown, Simulation, HUD/Audio/Renderer füttern, Meldungen, Pause, Ziel |
| `scripts/race/session_rules.gd` | `SessionRules` | reine Regeln der Rennsitzung (Kollisionen in geskripteten Phasen, HUD-Tankstelle, Ausrollen in die Tankspur, Überholweg der Polizei, Kurvengrenze der Polizei) – testbar ohne Szene |
| `scripts/race/tutorial_coach.gd` | `TutorialCoach` | Tutorial-Hinweise der Etappe Kiel – Hamburg (Warteschlange, Texte mit Konfigurationswerten) |
| `scripts/race/autopilot.gd` | `Autopilot` | Testfahrer (Spur halten, überholen, bremsen, tanken, Radar beachten) |
| `data/scenery.json` | – | 22 Landschaften + 32 Stadt-Landschaften (16 Baustile × Stadtrand/Zentrum): Grasfarben, Hintergrund, Klima, Requisiten-Regeln, Zäune, Wasserfarbe |
| `data/cities.json`, `scripts/data/city_data.gd` | `CityData` | individuelle Städte: Baustil, Wahrzeichen, Skyline, Brücken je Stadt (Daten-Modul; Vertrag und Umsetzung: [staedte.md](staedte.md)) |
| `tests/race/run_stage.gd` | – | ganze Etappe headless mit Autopilot fahren, Ergebnis + Frame-Zeiten |
| `tests/race/run_race.gd` | – | ganzes Rennen durch den echten Menüablauf (Autopilot) |
| `tests/race/check_session.gd` | – | Szenario-Prüfungen in der echten Rennszene (Kollisionsrichtung, Ausrollen, Abschleppen, Polizei beim Tanken, HUD-Werte, Tutorial) |
| `tests/race/check_sprite_flip.gd` | – | Render-Prüfung (Xvfb): gespiegelte Sprites liegen an Ort und Stelle |
| `tests/race/bench_render.gd` | – | Render-Benchmark an festen Streckenpositionen |
| `tests/race/shoot_vehicles.gd` | – | Fahrzeug-Szenarien als Bildfolgen (Xvfb, feste Bildrate): Kurven, Überholen eines Lkw, Spurwechsel, Polizei, Tunnel |
| `tests/fixtures/make_fixtures.py` | – | erzeugt die Testdaten `tests/fixtures/sprites/*` (17-Winkel-Pkw, Polizei, 21-Winkel-Spielerauto perspektivisch, Lkw als Quader) |
| `tests/unit/race/*` | – | Unit-Tests (Track, Projektion, Palette, Schilder, Sitzungsregeln, Tutorial, Hilfsklassen, Fahrzeugdarstellung, SpriteDB) |

## 2. Ein Frame des Renderers

1. **Projektion** (`_project`): ab der Kamera wird für jeden Segmentanfang ein Punkt projiziert (bis zur Sichtweite,
   ~300 Punkte). Kurven entstehen durch aufsummierten Seitenversatz (`x += dx; dx += curve * seg_len² / road.curve_radius_at_1_m`,
   also die Kreisbogen-Näherung z²/2R), Hügel durch die Segmenthöhe (`render.hill_height_scale` überhöht nur optisch).
   Pro Punkt: Bildschirm-x/-y, Maßstab (px/m), Nebelanteil, laufende „Kuppenlinie“ (höchster Boden davor).
2. **Unsichtbarer Boden**: Segmente, die vom Betrachter wegkippen (hinter einer Kuppe) oder ganz unter der Kuppenlinie
   liegen, werden zu einer Scheibe zusammengefasst; ihr Boden wird nicht gezeichnet, nur ihre Sprites (Bäume können
   über die Kuppe ragen – die nähere Kuppe übermalt den Rest).
3. **LOD**: ferne Segmente, deren Bildhöhe zusammen unter `render.lod_merge_px` liegt, werden zu einer Scheibe
   verschmolzen (mit gemittelten Farben statt flimmernder Subpixel-Streifen = Kantenglättung). Strichlinien werden
   jenseits `render.lod_detail_m` weggelassen, dünne Linien unter 1 px werden 1 px breit und entsprechend transparent.
4. **Himmel und Hintergrund** (`RaceBackdrop`). Der Hintergrund steht auf der höchsten sichtbaren Bodenlinie
   (Horizont oder Kuppe), damit Berge auch bergauf sichtbar bleiben.
5. **Maleralgorithmus**: Scheiben von hinten nach vorn – Boden (Grasbänder, Bankett/Standstreifen/Gehweg, Asphalt,
   Markierungen), Bauwerke (Leitplanken, Leitpfosten, Tunnelwände/-decke/-lampen, Tankstellendächer, Grenzstation),
   dann die Sprites der Scheibe nach Tiefe sortiert (Requisiten, Schilder, Fahrzeuge), danach ggf. das Tunnelportal.
   Lkw/Busse als Quader werden an den Scheibengrenzen geteilt: jede Scheibe zeichnet den Teil des Quaders, der in ihr
   liegt (§8) – so verdecken Kuppen auch Lkw richtig, und ein Lkw neben dem Spieler steht in der richtigen Reihenfolge.
   Dadurch verdecken Kuppen Straße und Verkehr, Tunnelwände in Kurven die Autos dahinter usw.
6. **Wetterpartikel** (Regen als Schlieren, Schnee als Flocken, im Kameraraum simuliert), Verfolgungs-Blaulicht,
   **additive Leuchtebene** (eigenes CanvasItem mit Additiv-Material: Rück-/Bremslichter, Blaulicht, Laternen,
   Tunnellampen, Reflektoren, Blitzer).

Farbige Geometrie läuft durch `GeoBatch` (vier Ecken + Indexmuster pro Viereck) und wird erst vor einem Sprite oder Text
als ein Befehl abgeschickt – typisch 3–40 Befehle und 2 500–4 000 Dreiecke pro Bild.

## 3. Kamera und Tempogefühl

| Schlüssel (`render`) | Wert | Wirkung |
|---|---|---|
| `fov_deg` | 84 | horizontaler Bildwinkel → Brennweite 711 px |
| `camera_height_m` | 3.4 | Kamerahöhe über der Straße am Fahrzeug |
| `camera_distance_m` | 9.0 | Abstand hinter der Wagenmitte |
| `horizon_y_frac` | 0.45 | Horizont bei y = 324 |
| `camera_follow`, `camera_lag_max_m` | 7 /s, 1.1 m | seitliches Nachziehen der Kamera (Wagen wandert beim Spurwechsel leicht aus der Mitte) |

Das Heck der 4,85 m langen Limousine steht damit bei y ≈ 692 (Heckkante 6,6 m vor der Kamera, unten Mitte, ganz
sichtbar), der Wagen ist ~200 px breit (Kompakt: y ≈ 672, ~180 px; Gran Turismo: y ≈ 694, ~210 px). Ein-Drittel-Regel:
1/3 eines 1,5 m hohen Autos ist sichtbar, sobald seine Heckkante ≈ 4,3 m vor der Kamera liegt (`visible_fraction`) –
ein von hinten überholendes Auto kollidiert also erst, wenn seine Heckkante höchstens ≈ 2,3 m hinter dem Heck des
Spielers liegt. Die Standardwerte in `projection.gd` entsprechen der Konfiguration.
Tempogefühl: echte Abstände – Leitlinien 6 m Strich/12 m Lücke (Stadt 3/6 m), Leitpfosten alle 50 m (an Leitplanken
Reflektoren auf den Pfosten), Leitplankenpfosten alle 6 m, Grasbänder alle 12 m, Fahrbahn leicht abwechselnd schattiert,
in der Stadt Bordsteinfugen, Gehwegplatten und Zebrastreifen. Die sichtbare Straße scrollt mit Tachotempo.
Kurven drehen den Hintergrund physikalisch richtig (`bg_offset` = Kurswinkel in Radiant, Faktor `render.background_parallax`),
nähere Hintergrundebenen drehen sich etwas schneller (Parallaxe).

## 4. Strecke (`Track`)

- **Generator**: abwechselnd gerade Stücke und Kurven (Länge, Stärke bis `road.curviness_max_curve[Kurvigkeit]`,
  weich ein-/ausgeblendet), Steigungsstücke mit weichen Übergängen (bis `road.hills_max_grade[Hügel]`, meist abwechselnd
  bergauf/bergab → echte Kuppen und Senken). Ein Zufallsgenerator mit dem Etappen-Seed, strikt sequenziell erzeugt →
  dieselbe Etappe sieht immer gleich aus. An Abschnittsgrenzen und 60 m vor Tunneln wird die laufende Kurve
  ausgeblendet und neu gewürfelt (die Grenzen des neuen Abschnitts gelten sofort). Start und Ziel sind gerade und eben;
  hinter dem Ziel folgen `road.runout_m` gerade Auslaufstrecke.
- **Fenster**: `update_window(camera_z, ahead)` erzeugt bis `ahead` + `generation_lead_m()` (Warnschild-Abstand + längste
  Einlaufphase einer Kurve, 366 m; seit den Kuppenschildern 600 m: Prüfweite + Schildabstand + Sichtweite + 20 m) voraus
  und verwirft Segmente hinter der Kamera (`keep_behind` = 64).
- **Kurvenschilder** (seit dem Untersteuern zählt das Kurventempo, gameplay.md (i)): Ein Kurvenstück mit Betrag ≥
  `road.curve_warning_min_curve` (0,25 = 480 m Radius) ist *scharf*: Gefahrzeichen „Kurve“ (rot umrandetes Dreieck,
  Pfeil in Kurvenrichtung) `road.curve_warning_m` (200 m) vor seinem Anfang rechts und alle `road.chevron_every_m`
  (30 m) eine rot-weiße Richtungstafel (drei Pfeile in die Kurve) außen am Bankettrand, solange die Kurve ≥ 60 % ihrer
  Stärke hat. Ein Kurvenstück ab `road.curve_warning_blind_min_curve` (0,12) ist *blind*, wenn ein Punkt seiner
  Einlaufphase (erste 30 %) von `road.curve_warning_sight_m` (150 m) davor wegen einer Kuppe nicht zu sehen ist
  (Sichtlinie aus der Kamerahöhe über die bereits erzeugten Höhen) – auch dann steht das Warnschild. Entschieden wird am
  Ende der Einlaufphase, das Schild wird in das schon erzeugte Segment 200 m vor dem Kurvenanfang eingefügt (im Tunnel
  an der Wand); weil die Erzeugung `generation_lead_m()` vorausläuft, ist es da, bevor das Segment in Sichtweite kommt
  (Test: Streamen = Gesamterzeugung). Schneidet ein Abschnitts- oder Tunnelwechsel das Kurvenstück schon in der
  Einlaufphase ab, entscheidet die erreichte Stärke (Beginn der 60-m-Ausblendung) sofort, und die Richtungstafeln laufen
  in der Ausblendung weiter (vorher fiel das Schild weg; `curve_signs_cut` zählt solche Schilder, im Netz 9). In City
  Limits steht das Warnschild ebenfalls – dort gibt es kein Radar, man kommt mit vollem Tempo –, Richtungstafeln nicht.
  Keine Kurvenschilder in Tunneln (dort höchstens 0,25) und in den ruhigen Zonen an Start und Ziel. Ergebnis im ganzen
  Netz: alle 691 scharfen Kurvenstücke (55 davon in City Limits) haben ihr Warnschild (Test
  `test_every_sharp_curve_has_a_warning_sign`). Sichtprüfung über alle Etappen: gameplay.md (i5).
- **Kuppenschilder** (Review v0.5.0, QA: im Schnee tauchte langsamer Verkehr hinter Kuppen näher auf als der
  Anhalteweg – in den City Limits von Burgos war eine Kolonne auf beiden Spuren unvermeidbar): Ist von einem Punkt bis
  `road.crest_warning_check_m` (250 m) vor einer Kuppe ein Fahrzeug (`road.crest_target_height_m` 0,75 m hoch, halbe
  Wagenhöhe) irgendwo innerhalb `road.crest_warning_sight_m` (180 m ≈ Anhalteweg im Schnee aus rund 200 km/h
  Annäherung) dahinter verdeckt (Sichtlinie aus der Kamera wie bei den Kurven, `_sees(z_car, z_p, target_h)`), steht
  `road.crest_warning_m` (150 m) vor diesem Punkt rechts das Gefahrzeichen „Kuppe“ (rotes Dreieck mit schwarzem Hügel,
  Schildart `crest`; im Tunnel an der Wand), höchstens eines je 180 m, nicht in den ruhigen Zonen an Start und Ziel.
  Entschieden wird, wenn die Straße 180 m hinter der Kuppe erzeugt ist; die Schilder verbrauchen keine Zufallszahlen –
  die Straße bleibt gleich (Test `test_blind_crests_have_a_warning_sign`: gleiche Höhen und Kurven mit und ohne, beim
  Streamen schon in Sichtweite vorhanden, je ein Schild vor den QA-Stellen San Sebastián – Burgos km 208,5 und
  Saragossa – Pau km 147,1 / 75,8). Im ganzen Netz (beide Richtungen) 1 295 Schilder auf 24 160 km = 5,4 je 100 km,
  höchstens 11 (Kassel – Würzburg ab Würzburg), flache Etappen keine.
- **Spuren**: Autobahn 3, Landstraße 2, Stadt 2 (`road.lanes`). Wechsel über `road.lane_transition_m` weich
  (`lanes_at` gebrochen); `lane_count_at` meldet dem Verkehr schon vor und während des Übergangs die kleinere Zahl.
- **Tankspur**: `fuel_lane_factor` 0..1 mit `road.fuel_lane_taper_m` Ein-/Ausfädelung; `fuel_lane_at` nur bei ganz offener
  Spur im StagePlan-Bereich. Zapfsäuleninseln, Dächer und der Tankstellen-Shop sind Bauwerke/Objekte entlang der Spur.
- **Ereignisse** (`_build_events`): Tankstellenschilder 30/15/5 km, Spur-Hinweis, Preis-Pylon; Radarwarnung 10 km vorher
  (mit Limit), Tempo-Schilder beidseitig am Radarfeld + Wiederholung, Blitzer, Aufhebung am Ende; Tempolimits und
  Autobahn-Beginn/-Ende an Abschnittsgrenzen; Tunnelschild (Name + Länge); EU-Grenzschilder (Landesname in Landessprache,
  auch kyrillisch), Grenzstation (Dach über der Fahrbahn mit Landesnamen, Zollhäuschen), neues Tempolimit; Vorschild der
  City Limits `city_limits.announce_km` (4 km = 333 m) vorher rechts (`town_ahead`: Ortsschild, darunter weiße Tafel
  „in 4 km“ mit dem Stadtlimit als kleiner Scheibe; Review v0.5.0 – im Schnee steht hinter dem Ortsschild oft eine
  langsame Kolonne; 5 km fiele auf das Entfernungsschild „25 km“), Ortsschild
  (Zielname, im Stil des Ziellandes) beidseitig + Stadtlimit; Entfernungsschilder („Hamburg 50 km“, Farben des Landes);
  Start-Portal mit Ampel (Countdown) und Ziel-Portal. Um Schilder, Portale und Bauwerke bleiben Landschaftsrequisiten weg.
  Jedes Schild trägt `country` (Land am Standort; Grenzschilder: das neue Land) und `road` (Straßentyp) für seinen Stil.
- **Schilder im Tunnel**: im Tunnel gibt es keinen Straßenrand – Schilder, deren km im Tunnel liegt (z. B. die
  30/15/5-km-Ankündigungen im Gotthard, Entfernungsschilder, Tempolimits an Abschnittsgrenzen, Grenzschilder im
  Somport), hängen an der Tunnelwand (`wall: true`, ohne Pfosten): die Tafel liegt ganz in der Röhre (Abstand
  `WALL_SIGN_GAP_M` zur Wand) und wird verkleinert, wenn sie sonst mehr als `WALL_SIGN_OVERHANG_M` (1 m) über die
  Fahrbahn reichte (Wegweiser ×0,71). Stehende Objekte (Zollhäuschen, Blitzer, Zapfsäulen) entfallen im Tunnel.
- **Requisiten** aus den Regeln der Landschaft (`data/scenery.json`), pro Segment mit eigenem Zufallsgenerator.

## 5. Landschaften (`data/scenery.json`)

Alle 22 Szenerie-IDs aus ARCHITECTURE.md §4.1. Pro Landschaft: `name`, `climate`, `grass` (zwei Farben),
`background` (`style`: plain, hills, forest, mountains, alps, city, coast, industrial; `colors` fern → nah;
optional `snow_caps`, `height`, `trees` = round|conifer, `features` = turbines|spires|pylons|chimneys, `sea`),
`props` (Regeln: `set`, `every_m`, `chance`, `side`, `x` = Meter hinter dem Bankett, `scale`, optional `count`,
`roads`, `phase_m`, `tint`, `fallback` + `fallback_scale`, `align: "edge"` = x ist die Vorderkante – für Gebäude,
damit sie nie auf die Straße ragen).
Fehlt ein Sprite-Set (noch nicht gerendert), nimmt der Renderer den `fallback` (getönt mit `fallback_tint`, nur für
das Ersatz-Set) oder überspringt die Regel.
Hintergrundstile wechseln weich (alte Silhouetten sinken, neue steigen, `render.background_blend_s`).

**Städte** ([staedte.md](staedte.md) §6–§8): In den City Limits gilt die Landschaft des Baustils der Zielstadt –
`city_<stil>_outskirts` bis `center_km` vor dem Ziel, danach `city_<stil>_center` (`StagePlan.scenery_for`; `city`
nur noch ohne Stil). Zusätzliche Schlüssel: `fence` (Lattenzaun, Hecke, Mauer oder Eisengitter hinter dem Gehweg,
prozedural, mit Lücken), `water` (Wasserfarbe unter Brücken); Hintergrundstil `suburb` (ferne Skyline, Bäume, kleine
Häuser), `roofs` (Dachformen der Skyline), Merkmale `cranes`, `domes`, `onion`, `slabs`, `towers` und `behind`
(Bergkette hinter der Stadt). `cities.json` kann je Stadt Schlüssel des Hintergrunds überschreiben.

**Spiegeln und Vorderkante**: Sets mit Tag `mirror_left` (Gebäude, Höfe, Kirche, Fabrik …, 3/4-Ansicht für die rechte
Straßenseite) und Regeln mit `mirror` werden links gespiegelt gezeichnet (`prop_flipped`). Godot spiegelt ein Rechteck
mit negativer Breite an Ort und Stelle (Position bleibt, nur die Textur wird gespiegelt – `flipped_draw_rect`,
geprüft von `tests/race/check_sprite_flip.gd`); der Anker wird dabei mitgespiegelt (`1 - anchor.x`, `sprite_dest`).
Bei `align: "edge"` rückt der Anker um die zur Straße zeigende Ausdehnung von der Straße weg (`edge_anchor_x`):
`extent_m = [links, rechts]` gilt für die ungespiegelte Zelle; rechts der Straße zeigt die linke Seite zur Straße
(`extent_m[0]`), links gespiegelt ebenfalls die (gespiegelte) linke Seite (`extent_m[0]`), nur ungespiegelt links die
rechte (`extent_m[1]`). So steht die Fassade auf beiden Seiten genau an der Regelposition hinter dem Gehweg
(Unit-Test `test_edge_aligned_props_keep_their_near_edge` mit dem echten Manifest).

## 6. Besondere Abschnitte

- **Tunnel**: Wände (unten Fliesen, oben Beton), abgeschrägte Ecken, Decke, zwei Lampenreihen (mit Leuchten), grüne
  Notrufnischen, dunkler Tunnelnebel (`render.tunnel.darkness_m`), warmes Kunstlicht. Von außen: bewachsener Hügel
  (Silhouette weicht nach hinten zurück, Nadelbäume auf dem Kamm) mit Betonportal, Stirnwand und Flügelmauern; nur die
  ersten `render.tunnel.peek_m` des Inneren werden gezeichnet und dann dunkel abgeschlossen. Von innen wirkt die
  Ausfahrt überbelichtet (Augen-Adaption). Kurven im Tunnel: die Röhre umschließt den Blick, Wände verdecken korrekt.
- **Tankstelle**: Tankspur rechts mit Schraffur am Anfang, durchgezogene breite Trennlinie, Inseln mit gelbem Bord,
  Dächer (Unterseite mit Leuchtfeldern, roter/weißer Rand, Schriftzug), Zapfsäulen, Shop am Ende, Preis-Pylon.
- **Radar**: Warnschild mit Kamera, Limit und Entfernung; Tempo-Schilder; Blitzer-Kamera (leuchtet bei `radar_flash01`);
  der Vollbild-Blitz kommt weiter vom HUD.
- **Grenze**: EU-Schild (Sternenkranz mit Länderkürzel, Name in Landessprache), Grenzstation, Zollhäuschen,
  Landschaftswechsel, Polizeilackierung über `GameData.police_set_for(Land)` und ab der Grenze die Schilder im Stil
  des neuen Landes (siehe unten).
- **City Limits**: Ortsschild, Bordsteine (mit Kantenflächen), Gehwege, Straßenlaternen (mit Lichtkegeln nachts),
  Straßenbäume, Gebäude auf beiden Seiten (links gespiegelt), Zebrastreifen, Skyline mit Fensterlichtern, Ziel-Portal
  + karierte Ziellinie. Je Zielstadt Baustil (Stadtrand mit Gärten und Zäunen, Zentrum dicht bebaut), Hintergrund
  und Bergkette je Stadt.
- **Brücken** ([staedte.md](staedte.md) §7): Wasser neben und unter dem Deck je Scheibe in Höhe des Bodens unter der
  Brücke (Kaimauer oder Böschung am Ufer, Himmelsspiegelung zur Ferne, Glitzern, nachts Lichter der Stadt), Geländer je
  Typ an der Deckkante (Stahl, Steinbalustrade, Eisengitter, Brüstung), Fachwerkbogen mit Seitenträgern und Portalen
  alle 40 m über der Fahrbahn (Requisiten in der normalen Malerreihenfolge), Pylone mit Seilfächern als 3D-Linien,
  Kandelaber, Hausboote und Schiffe auf dem Wasser; keine Landschaft auf dem Wasser, keine Zebrastreifen.
- **Wahrzeichen**: Ereignis-Requisiten mit freigehaltenem Platz; eigenes Dunstgesetz (`landmark_fade`): sichtbar bis
  Sichtweite × 2 (höchstens `render.landmark_far_m`), jenseits der projizierten Zeilen im Fern-Durchgang mit gerade
  verlängerter Straße gezeichnet – kein Aufpoppen. Prozedurale Ersatzformen, solange die Sprites fehlen; Lichter als
  weiche Punkte in der Malerreihenfolge. Skyline-Silhouetten im Panorama (`RaceBackdrop.landmarks`).

**Schilder je Land** (Design: „Grenzübergänge: Wechsel von Schildern, Landschaft und Polizeifahrzeugen“): `SignPainter`
nimmt die Farben aus `GameData.countries[Land].signs` (`data/countries.json`, Daten-Modul): `motorway` für
Wegweiser, Autobahnschild und Tankstellen-Ankündigungen auf der Autobahn (DE/NL/FR … blau, CH/IT/SI/HR/CZ … grün),
`town_bg`/`town_fg`/`town_border` für das Ortsschild (DE gelb/schwarz, NL und CH blau/weiß, FR/BE/ES/AT weiß mit
breitem rotem Rand, IT … weiß/schwarz). Wegweiser abseits der Autobahn: `signs.road`/`road_fg`, falls in den Daten
vorhanden, sonst blau/weiß in Ländern mit grünen Autobahnschildern und sonst die Ortsschildfarben (DE gelb, NL blau,
FR weiß). Unbekanntes Land → deutscher Stil. Tempo-, Radar-, Tunnel- und EU-Grenzschilder sind europaweit gleich,
ebenso das Kurven-Warnschild (`curve`), das Kuppen-Warnschild (`crest`, Review v0.5.0) und die Richtungstafel (`chevron`,
rot mit weißen Pfeilen, `value` = Richtung).

**Entscheidung: Schilder prozedural statt Blender-Sprites.** Das Design nennt Schilder bei den Blender-Sprites. Alle
Schilder tragen aber veränderliche Inhalte – Zielname und Entfernung, Limit, Tunnelname und -länge, Landesname in
Landessprache (auch kyrillisch), Countdown-Ampel – und ihr Stil wechselt je Land. Als Sprites bräuchte es je
Kombination ein Bild oder Text auf leeren Tafeln. Deshalb zeichnet `SignPainter` Tafel, Pfosten, Piktogramme und
Text als Vektorgrafik (gestochen scharf in jeder Entfernung, nachts rückstrahlend, im Nebel verblassend). Fahrzeuge,
Bäume, Gebäude, Tankstellen und Zapfsäulen sind Blender-Sprites wie im Design vorgesehen.

## 7. Licht, Tageszeit, Wetter

`Palette.compute` interpoliert vier Schlüsselbilder (Nacht, Morgen, Tag, Abend) mit den Stunden aus `daytime`.
Nacht: dunkles Umgebungslicht, Sterne, Mond; der Boden wird pro Ecke beleuchtet (Scheinwerferkegel des Spielers,
Scheinwerfer der Autos vor ihm, Straßenlaternen, Tankstellendächer, Grenzstation), Fahrbahnmarkierungen, Schilder und
Leitpfosten reflektieren stärker; Rücklichter, Laternen, Fenster und Lampen leuchten (Ebenen `tail`, `lights`, Glow).
Regen: grauer bedeckter Himmel, nasse dunkle Fahrbahn mit Himmelsspiegelung in der Ferne, Gischt hinter Autos,
Spiegelungen der Rücklichter nachts, Regenschlieren. Schnee: grauer Himmel, weißer Boden, Schnee an den Fahrbahnrändern,
Flocken. Sichtweite kommt aus `EnvironmentModel.visibility_factor` (Nebel ab `render.fog_start_frac` der Sichtweite).

## 8. Fahrzeuge (Darstellung v2)

Vertrag zwischen Sprite-Pipeline und Renderer: [fahrzeug-darstellung.md](fahrzeug-darstellung.md). Das Manifest legt pro
Set die Darstellungsart fest; `SpriteDB` liest die Erweiterungen (`grid_cols`, `yaw_deg`, `pivot`, `projection`,
`camera`, `supersample`, `render: box` mit `parts`/`faces`/`lights`) und bleibt mit dem alten Manifest (5 Winkel
`l2/l1/c/r1/r2`, eine Zeile je Ebene, `yaw_deg` als Wörterbuch) verträglich. Die Mathematik steht in `VehiclePose` und
`BoxVehicle` (rein, unit-getestet), der Renderer liefert die Straßengeometrie (`road_at(z)`: seitlicher Versatz der
Straßenmitte, Höhe, Tiefe – dieselbe Projektion wie für die Straße).

**Verkehr und Polizei – orthografische Sprites, Drehung um das Heck** (alte 5-Winkel-Sets und neue 17-Winkel-Sets):

- Der Anker (Heckmitte am Boden) sitzt auf dem projizierten Heckpunkt. Darstellungswinkel nach Vertrag:
  `sin ψ = (d_r · tan(h + ψ_c) − x_r) / (d_r + L)`, begrenzt auf ±`render.vehicle_yaw_max_deg` (30°). `d_r` = Tiefe des
  Hecks, `x_r` = sein seitlicher Abstand von der Kameraachse inklusive Straßenversatz, `h` = Straßenrichtung relativ
  zur Kamera als **Sehne vom Heck zur Front** (Straßenmitte an `z` und `z + L` – für eine Kurve konstanter Krümmung
  exakt), `L` = Fahrzeuglänge, `ψ_c = atan(v_quer / v_längs)` = Eigenrichtung. So liegt die Front des Sprites (im
  Maßstab des Hecks) dort, wo die echte Perspektive sie zeigt (Unit-Test: < 0,5 px über Kurven, Spuren und Längen; die
  alte Punktformel lag bis zu Hunderten Pixeln daneben). Beispiel aus dem Playtest: Lkw (16,5 m) in der Nachbarspur
  30 m voraus → −4,6° statt bisher der 12°-Zelle.
- `v_quer` misst der Renderer selbst: Änderung von `x` je Fahrzeug-`id` über die Simulationszeit (Spurwechsel,
  Spurgeometrie); die Sitzung gibt jedem Auto seine `id` mit (Polizei: −2) und der Polizei ihr wirkliches Tempo
  (Spielertempo + Änderung von `police_car_offset_m`).
- Pro `id` kritisch gedämpft geglättet (`render.vehicle_yaw_smooth_s` = 0,12 s, exakte Lösung, stabil bei jeder
  Bildrate, steht in der Pause), Zellwahl mit Hysterese: die Zelle wechselt erst, wenn eine andere um mehr als
  `render.vehicle_cell_hysteresis` (0,3) Schritte näher liegt – auf einer gleichmäßigen Kurve flackert nichts
  (Unit-Test mit Rauschen und schwankender Bildzeit; `shoot_vehicles.gd` zählt die Zellwechsel im echten Renderer).
  Rück-/Bremslicht- und Blaulicht-Ebenen nutzen dieselbe Zelle; die Leuchtpunkte rücken mit dem Winkel mit.
- Grenze der Darstellungsart: orthografische Sprites zeichnen die Front im Maßstab des Hecks. Ein Pkw dicht neben
  der Kamera (Überholen) wirkt dadurch zu groß, seine Front zu tief und zu weit außen – er scheint in die eigene Spur
  zu ziehen. Deshalb **perspektivische Flankenverzerrung** (`render.vehicle_warp`, ab Fahrzeuglänge / Hecktiefe
  ≥ `render.vehicle_warp_min_ratio` = 0,06, also bis rund 78 m): `VehiclePose.warp_columns` zerlegt die Zelle in
  senkrechte Streifen – Heckfläche (`t = 0`, `s = x / cos ψ`), sichtbare Flanke (`s = ±B/2`, `t = 0 … L` in bis zu 16
  Streifen) und den Rest hinter der vorderen Ecke (`t = L`) –, `VehiclePose.warp_screen` projiziert jede Spalte mit
  der Straßengeometrie an `z + t` (`road_at`) in ihrer eigenen Tiefe; die Pixelhöhe über dem lokalen Boden der Spalte
  im Sprite (`Δz · sin(elevation_deg)`) bleibt erhalten. Streifen mit ungleich hohen Kanten werden zusätzlich in Zeilen
  geteilt (sonst knicken die zwei affinen Dreiecke waagrechte Linien der Textur). Alle Ebenen eines Autos gehen als
  ein Dreiecks-Array an den RenderingServer. Ergebnis (Unit-Test und Vergleich mit einem echten 3D-Render derselben
  Szene in Blender): Flanke, vordere Ecke und Vorderrad liegen auf der echten Projektion; ohne Verzerrung stand die
  vordere Ecke eines Pkw 10 m vor der Kamera in der Nachbarspur 23 px zu weit außen und über 30 px zu tief. Lange alte
  Lkw-Sprites gibt es nicht mehr – Lkw und Busse sind Quader.

**Lkw und Busse – `render: "box"` (`BoxVehicle`)**:

- Jede Fläche eines Teils (`parts`: `z`/`x`/`y` relativ zur Fahrzeugmitte) wird als texturiertes Viereck projiziert;
  die Fahrzeugmitte steht auf (`z`-Mitte, `x`) des Verkehrsautos, die Aufstandsfläche ist damit genau die
  Kollisionsbox des `TrafficSystem` (Spurmitte, Länge, Breite; Unit-Tests mit den Ecken der gezeichneten Flächen und
  mit den Teilen aller Quader-Sets im Manifest).
- Sichtbar ist eine Fläche, wenn ihre Außenseite zur Kamera zeigt: Heck, wenn es vor der Kamera liegt; links/rechts je
  Abschnitt über die Lage der Kamera zur Flächenlinie (`x_a · z_b − x_b · z_a`, berücksichtigt die Kurve); Dach nur
  unter der Kamera (Senken). Keine Frontflächen (alle fahren in unsere Richtung).
- Seiten und Dach werden längs in Abschnitte geteilt: höchstens `render.box_slice_m` (2 m), näher an der Kamera
  höchstens `render.box_slice_ratio` (12 %) der Tiefe (Längen 2/1/0,5/0,25/0,125 m, Grenzen fest am Fahrzeug – die
  Textur schwimmt nicht). Jeder Abschnitt wird mit der Straßengeometrie seiner Enden projiziert, der Quader biegt sich
  mit der Kurve. Canvas-Dreiecke bilden Texturen affin ab; jeder Abschnitt wird deshalb zusätzlich in Streifen
  konstanter Tiefe geteilt, bis der Fehler unter `render.box_subdiv_px` (1,5 px) liegt.
- Teile hinter der nahen Ebene (`render.near_m`) werden abgeschnitten: Beim Überholen bleibt der Lkw neben dem
  Spieler sichtbar, bis seine Front an der Kamera vorbei ist. Abschnitte ganz außerhalb des Bildes entfallen.
- Reihenfolge: Teile nach ihrer Front von hinten nach vorn (Fahrerhaus vor Auflieger), je Teil die Abschnitte von
  vorn zur Kamera, dann seine Heckfläche. In der Szene steckt jedes Fahrzeug in jeder Scheibe, die es berührt (§2).
- Licht wie bei Sprites (Umgebungslicht, Scheinwerfer, Nebel, Tunnel, Ausblenden in der Ferne); Rück- und
  Bremslicht-Überlagerungen (`lights`) liegen mit derselben Geometrie über ihrer Fläche, dazu Leuchtpunkte und nasse
  Spiegelungen an der Fläche mit den Leuchten. Unter dem Quader liegt ein weicher Schatten auf der Straße.
- Texturen mit anisotroper Filterung (`CanvasTexture`), damit die schräg gesehenen Flanken scharf bleiben.
- Spurwechsel: der Quader bleibt straßenparallel (er gleitet seitlich), damit er immer genau die Kollisionsbox zeigt.

**Spielerauto – perspektivische Sprites (`projection: perspective`, `pivot: center`)**:

- Anker = projizierter Bodenpunkt der Wagenmitte (mit Straßenversatz und Kamera-Nachlauf), Maßstab
  `camera.distance_m / Tiefe / supersample` (`VehiclePose.perspective_scale`, bei der Standardkamera 1/supersample).
  Weicht die im Manifest dokumentierte Kamera von `render.*` ab, warnt der Renderer (Sprites neu rendern).
- Sichtbarer Gierwinkel (`VehiclePose.player_yaw_target`, gedämpft mit `render.player_yaw_smooth_s`, höchstens
  `render.player_yaw_max_deg`): Kurvenvorschau = Straßenrichtung `render.player_curve_lookahead_m` (10 m) vor der
  Wagenmitte relativ zur Kamera (× `player_curve_gain`) + Lenkeinschlag × `player_steer_deg` + Spurwechsel
  `atan(lat_speed / v)` × `player_lateral_gain` + Untersteuern × `player_understeer_deg` (Nase zur Kurveninnenseite,
  während der Wagen nach außen schiebt) − Blickwinkel `atan(Querabstand zur Kamera / Tiefe)` × `player_view_gain`.
  Der letzte Term ist Geometrie, kein Effekt: das Sprite ist gerade vor der Kamera gerendert, ein Auto neben der
  Kameraachse (Kamera-Nachlauf bis 1,1 m, Straßenversatz in Kurven) sieht man leicht von der Seite – mit ihm liegen
  Heck und Front an der wahren Position (Unit-Test, < 1,5 px). Zelle mit derselben Hysterese wie beim Verkehr.
  Werte im Spiel: Kurve 0,73 bei 140 km/h ≈ −4,6° (Zelle −4°), Spurwechsel bei 160 km/h ≈ ±7°.
- Neigung (Rotation um den Anker, höchstens ±`render.player_roll_max_deg` = 2,5°): Querbeschleunigung
  `v² · Krümmung + d(lat_speed)/dt` × `player_roll_deg_per_mps2`, gedämpft (`player_roll_smooth_s`); der Aufbau neigt
  sich aus der Kurve. Bremslichter, Rücklichter (nachts), Blinken (`visible`) und Wackeln (`shake`) wie bisher; die
  Leuchtpunkte folgen Gierwinkel und Neigung.
- Rückfall für alte orthografische Spieler-Sets (5 Winkel): Anker am Heck wie bisher, Zelle aus demselben sichtbaren
  Gierwinkel (mit Hysterese, also r1/l1 erst ab 7,8°), Neigung um den Anker. Ein explizites `angle` im Spieler-Eintrag
  (ohne `steer`) erzwingt weiterhin eine Zelle.

Polizei: Blaulichtphasen `beacon_a/b` + blaues Leuchten (mit dem Darstellungswinkel versetzt).

**Blinker des Verkehrs** (v0.5.0, gameplay.md „Verkehr als Hindernis“): Jeder Spurwechsel eines Verkehrsautos wird
1–1,5 s vorher angekündigt (`TrafficSystem.Car.signal_dir`, `signal_age`); die Sitzung gibt jedem Auto im View
`blink` (−1 links, +1 rechts, 0 aus) und `blink_t` (Sekunden seit dem Einschalten) mit. Der Renderer zeichnet an der
Heckecke dieser Seite eine kleine bernsteinfarbene Leuchte (mit dem Fahrzeug, im Maleralgorithmus) und darüber ein
additives Leuchten (`_indicator`), hell genug für den Tag, nachts kräftiger: bei Pkw/Polizei an der Ecke des
gedrehten Sprites (wie die Rücklicht-Leuchtpunkte), bei Lkw/Bussen an den unteren Ecken der Heckfläche
(`BoxVehicle.rear_rect`). Takt `INDICATOR_PERIOD_S` = 0,72 s, an in der ersten Hälfte (≈ 83 Mal je Minute, das erste Mal
sofort, `RoadRenderer.indicator_lit(blink_t)`). Der Blinker bleibt an, solange das Auto auf eine Lücke wartet und
während es hinüberzieht. Review: in 150–250 m, wo Autos im Schnee vor dem Spieler herausziehen, ist ein Auto nur 5–8 px
breit – Leuchte und Leuchten haben deshalb eine Mindestgröße auf dem Bildschirm (`INDICATOR_MIN_PX` 2,4 × 2 px,
`INDICATOR_MIN_GLOW_PX` 4,5 px Radius, nachts +1, `indicator_glow_px`), und der Blinker blendet wie Rück- und
Bremslichter mit dem Lichtalpha aus (nachts × 1,6), nicht mit dem Alpha der Karosserie – im Nebel verschwindet er nicht
mehr vor den Rücklichtern.

**Testdaten und Bildfolgen**: `tests/fixtures/make_fixtures.py` (Pillow + numpy, kleiner Z-Buffer-Rasterizer) erzeugt
nach Vertrag einen 17-Winkel-Pkw (`grid_cols` 9, Drehung um das Heck), eine Polizei mit Blaulicht-Ebenen, ein
21-Winkel-Spielerauto mit der Spielkamera (supersample 1,25) und einen Sattelzug als Quader (Metergitter mit Zahlen auf
den Flanken, damit Verzerrungen auffallen; cyanfarbener Umriss der Aufstandsfläche bei den Pkw). Mit
`--sprite-manifest=res://tests/fixtures/sprites/manifest.json` lädt `SpriteDB` sie zusätzlich; `aliases` zeigen
`traffic/sedan_*`, `traffic/hatch_*`, `traffic/truck_*`, `police/*` und `player/*` darauf (die Sets behalten ihre Tags).
`tests/race/shoot_vehicles.gd` fährt feste Szenarien (zufälliger Verkehr aus, Autos gesetzt und geführt) und speichert
Bildfolgen; Aufruf siehe §12.

## 9. Rennsitzung (`race_session.gd`)

Simulation in `_physics_process` (feste Schritte), Darstellung in `_process`. Ablauf je Schritt: Eingabe (Spieler oder
Autopilot) → Steuerungsanfrage (`FuelSystem` vor `PoliceSystem`) → `VehicleModel.update` → Position → Fenster →
`TrafficSystem.update` → Kollision → Tank → `police.set_blocked(fuel.state != NORMAL)` → Polizei → Strafzeit → Uhr →
Zonenmeldungen → Tutorial-Hinweise → Ziel.

- **Kollision** (`_check_collision`): `find_collision` mit `RoadProjection.visible_fraction` (Ein-Drittel-Regel), dann
  `space_beside(…, hit)` mit den Straßenrändern inkl. Bankett – **ohne das getroffene Auto**, sonst stünde es bei einem
  Treffer genau von hinten/vorn auf „seiner“ Seite und die Richtung hinge an Zentimetern; so gilt „auf die Seite mit
  mehr Platz, im Zweifel nach links“ (`VehicleModel.push_direction`). Geprüft wird nach `SessionRules.collisions_active`:
  nicht während der Unverwundbarkeit, nicht im Stillstand geskripteter Phasen (Tanken, Polizeikontrolle,
  Abschleppen), aber **immer beim Ausrollen mit leerem Tank** und in jeder geskripteten Phase über
  `render.scripted_collision_min_kmh` (30 km/h: Anhalten für Polizei oder Zapfsäule, Auslaufen nach dem Ziel) – der
  Wagen fährt nie durch Verkehr hindurch.
- **Tanken vor Polizei**: solange das `FuelSystem` den Wagen hält (Tanken, Abschleppen), blockiert die Sitzung die
  Polizeikontrolle (`PoliceSystem.set_blocked`); eine Festnahme während des Tankens wird danach abgesessen (Semantik
  im Gameplay-Modul).
- **Leerer Tank**: `ran_dry` meldet „Tank leer! Rechts in die Tankspur rollen lassen“, wenn der ausrollende Wagen
  (`fuel.dry_coast_decel_kmh_s`) eine Tankspur noch unter 60 km/h erreicht (`SessionRules.can_roll_into_lane`), sonst
  „Tank leer! Der Abschleppdienst kommt …“. Gezählt (`tow_events`) wird ein Abschleppen erst bei `tow_finished`, also
  nur wenn es wirklich stattfand.
- **HUD-Tank**: Reichweite beim aktuellen Tempo (`fuel.range_km(speed)`, im Stand 60 km/h); „Nächste Tankstelle“ = 0,
  solange der Wagen an der Tankstelle ist (im km-Bereich der Tankspur – die Zapfsäulen stehen entlang der ganzen Spur –
  oder beim Tanken), sonst die Entfernung (`SessionRules.next_station_km`).
- **Kurvengrenze der Polizei**: Während einer Verfolgung (und solange ein Radar angekündigt ist) gibt die Sitzung
  `police.update` die Kurvengrenze des Polizeiwagens an der Position des Spielers mit
  (`SessionRules.police_curve_cap_kmh`: seine Kurvengeschwindigkeit – `PoliceSystem.curve_speed_mps`, Agilität 1 –
  an jedem Punkt der nächsten `police.curve_lookahead_m` (300 m, alle 10 m), erreichbar mit
  `police.curve_brake_mps2`; Haftung je Punkt aus `Track.grip_at`). Die Polizei bremst also wie der Spieler für
  Kurven, die Fluchtschwelle sinkt dort entsprechend (gameplay.md „Verfolgung“); das HUD zeigt sie
  („Flucht ab 187 km/h halten!“, HUD-Schlüssel `escape_kmh`).
- **Haftung**: `road_info` gibt im Tunnel Haftung 1,0 (trockene Fahrbahn unter dem Dach, `Track.grip_at`), sonst die
  Wetterhaftung – ebenso Autopilot, Tutorial-Kurvenhinweis, Polizei und Sichtprüfung. Seit v0.5.0 wirkt sie im
  Fahrmodell auf Kurvengrenze, Bremsen, Traktion und Lenken (gameplay.md „Wetter“).
- **Verkehr und Wetter** (v0.5.0): `traffic.update` bekommt im Kontext `weather` (Tempo, Abstände und Bremsen des
  Verkehrs) und `brake_mps2` = `vehicle.brake_decel_mps2(Wetterhaftung)` (`_player_brake_mps2`): kein Verkehrsauto zieht
  näher vor dem Spieler heraus, als er mit dieser Bremsleistung noch bremsen könnte (gameplay.md „Verkehr als
  Hindernis“). Review: die Wetterhaftung auch im Tunnel (vorher die Haftung unter dem Wagen – im Tunnel trocken: hinter
  der Ausfahrt hätte ein Auto mit der trockenen Untergrenze herausziehen können, die der Spieler draußen im Schnee nicht
  mehr schafft) und auch beim Aufbau des Verkehrs (`_warm_up_traffic`, Screenshots/Demos).
- **Wetterhinweis** (Review v0.5.0): bei Regen und Schnee zeigt das HUD beim Countdown (Countdown + 4 s), was das Wetter
  bewirkt – „Schnee: Bremsweg ×2, der Wagen rutscht nach dem Spurwechsel weiter – früh gegenlenken“, „Regen: Bremsweg
  ×1,3, die Lenkung reagiert träger – früher bremsen“ (`SessionRules.weather_hint`, Faktor = trockene / nasse
  Vollbremsung aus `driving.grip_effects`). Die Tutorial-Etappe fährt immer trocken (gameplay.md „Wetter im Rennen“).
  Die Countdown-Ziffer steht seit dem Review 42 px tiefer (`Hud.COUNTDOWN_Y` 292, Startampel darunter) – vorher
  überdeckte sie den unteren Rand des Hinweises.
- **City Limits ankündigen** (Review v0.5.0): am Vorschild (`city_limits.announce_km` vor den City Limits) die Meldung
  „City Limits Würzburg in 4 km – Tempo 50“ (`SessionRules.city_announce_due`/`city_announce_text`, einmal je Etappe, nie
  in den City Limits) – 333 m genügen, um selbst bei Schnee aus Höchsttempo auf das Stadttempo zu bremsen.
- **Leitplankentreffer** (`vehicle.rail_hit`): Kamerawackeln von `render.rail_shake_min_s` (0,15 s, Berühren) bis
  `render.rail_shake_max_s` (0,45 s wie ein Unfall) mit der Abdrift, die hineinrutscht (`vehicle.rail_impact` /
  `render.rail_shake_full_mps` 8 m/s), ab `render.rail_flash_min_mps` (2 m/s) zusätzlich ein kurzes orangefarbenes
  Aufblitzen (`hud.flash`) – ein Rutscher in die Leitplanke kostet bis zur Hälfte des Tempos und soll spürbar sein.
  Den Aufprallklang liefert das Audio-Modul (`rail_hit`/`rail_impact`, noch offen).
- **Polizeiwagen**: gezeichnet bei `police.police_car_offset_m()` (Animation im Gameplay-Modul). Seitlich fährt er
  eine Spur neben dem Spieler, solange er hinter oder neben ihm ist (links, wenn dort eine Spur ist, sonst rechts;
  gewählt, solange er noch außer Sicht hinter der Kamera ist), und zieht vor dem Spieler ein, sobald sein Heck frei
  ist (Haltepunkt `police.pull_over_offset_m` vor dem Spieler, `SessionRules.police_car_x`) – er fährt nie durch den
  Wagen des Spielers.

Meldungen (HUD `show_message`): Tankstelle 30/15/5 km, Tanken, vollgetankt/abgebrochen, Reserve, Tank leer,
Abschleppstrafe, Radarwarnung, Radarfeld Anfang/Ende, geblitzt, Verfolgung, entkommen, „Führerschein, bitte!“,
„Gute Fahrt!“, Grenze (Land + Name in Landessprache), City Limits (4 km vorher angekündigt), Tunnelname, LOS, ZIEL,
Wetterhinweis beim Countdown (Regen, Schnee), Tutorial-Hinweise (§9a).
Audio: Motor, Wind, Sirene (mit Abstand), Regen, Rutschen, Einzeltöne (beep je Countdown-Sekunde, go, crash, flash,
fuel_start/fuel_done, finish). Pause: Baum pausiert, Ton stumm, Fokusverlust pausiert (nicht im Autopilot).
Ziel: Zeit wird eingefroren, „ZIEL!“-Meldung, Wagen rollt aus (`render.finish_decel_kmh_s`), der Spieler lenkt weiter,
Verkehr kollidiert weiter (zählt aber nicht mehr zu `collisions` der Etappe); Ergebnis nach dem Stillstand
oder spätestens `render.finish_hold_s`. Ergebnis-Wörterbuch unverändert (ARCHITECTURE.md §8).

## 9a. Tutorial (Kiel – Hamburg)

Design: „Kiel – Hamburg: alternativlose Startetappe, gleichzeitig Tutorial.“ Die Etappe trägt in den Daten
`tutorial: true` und `start_fuel_fraction: 0.35` (Start mit gut einem Drittel Tank – 95 km reichen damit nicht, der
Tankstopp gehört dazu; `StagePlan.tutorial`, `FuelSystem`) – nur in Fahrtrichtung Kiel → Hamburg, die Rückrichtung
(Einzeletappe) ist seit dem Review v0.5.0 eine normale Etappe. Auf dieser Etappe (oder mit `--tutorial`) erzeugt die
Sitzung einen `TutorialCoach`, der jedes Thema einmal als kurzen „Tipp: …“ (HUD-Meldung, `render.tutorial_hint_s`
= 6 s) zeigt, nacheinander mit 0,6 s Pause; dringende Themen kommen sofort, weil die Situation gerade eintritt:

| Auslöser | Hinweis (Zahlen aus der Konfiguration) |
|---|---|
| LOS (+1,2 s) | Lenken (Pfeiltasten, A/D), Gas/Bremse (Pfeil hoch/runter, W/S), Gamepad (Stick, Trigger); ist beim Start ein Gamepad das aktive Eingabegerät (`InputMode`, z. B. Steam Deck), nur der Gamepad-Hinweis (`TutorialCoach.gamepad`) |
| Start mit < 60 % Tank | „Nur 35 % im Tank – unterwegs an der Tankstelle nachtanken!“ |
| Start | Tankanzeige unten links: Tankstand, Reichweite, nächste Tankstelle |
| erste Ankündigung 30/15 km | „Tankstellen werden 30, 15 und 5 km vorher angekündigt“ (`fuel.announce_km`) |
| 5-km-Ankündigung (dringend) | „Rechts in die Tankspur und unter 60 km/h rollen – dann wird getankt“ (`fuel.lane_trigger_speed_kmh`) |
| Tanken beginnt (dringend) | „Gas geben bricht das Tanken ab – warte, bis der Tank voll ist“ |
| Radarwarnung (dringend) | „Toleranz 15 % – bei Limit 120 blitzt das Radar erst ab 138 km/h“ (`radar.tolerance`) |
| Verfolgung (dringend) | Flucht mit im Schnitt 220 km/h über 12 s (`police.escape_*`), sonst 10 s Stillstand (`police.stop_duration_s`) |
| erster Abschnitt ohne Limit | „Kein Tempolimit – aber Vollgas kostet deutlich mehr Sprit“ |
| City Limits (dringend) | „City Limits – Tempo 50, dichter Verkehr, keine Tankstelle, kein Radar“ |
| erste Kollision | „Zusammenstoß – der Wagen wird auf 10 km/h abgebremst und abgedrängt“ (`collision.target_speed_kmh`) |
| Untersteuern (`understeer` > 0,3) oder eine Kurve in den nächsten 250 m verlangt > 5 % weniger als das aktuelle Tempo (dringend) | „Vor scharfen Kurven bremsen – sonst schiebt der Wagen nach außen“ |
| erstes Auto bis 200 m voraus mit Blinker (dringend, Review v0.5.0) | „Blinker heißt, der Wagen zieht gleich herüber – Gas weg!“ |
| erstes Elefantenrennen bis 200 m voraus (dringend, Review v0.5.0) | „Lkw überholt Lkw – zwei Spuren dicht, links bleibt frei“ |

Die Etappenbeschreibung (`StagePlan.description`) zeigt der Etappenbildschirm (UI-Modul).

## 10. Autopilot

Hält eine Spur, wählt die Nachbarspur mit dem besten erreichbaren Tempo (nächstes Auto darin und dessen Abstand,
Hysterese, nur wenn die Spur frei ist), folgt sonst mit Sicherheitsabstand; bremst vorausschauend für Radarfelder
(Limit + 6 %) und für Autos im Fahrweg; verlässt endende Spuren rechtzeitig. Tanken: entscheidet 14 km vor jeder
Tankstelle (`auto`: wenn der Sprit nicht bis zur übernächsten Tankstelle/zum Ziel reicht; `always`/`never` per
`--autopilot-refuel`), wechselt ab 700 m davor Spur für Spur nach rechts – jeweils nur in eine freie Lücke wie beim
Überholen, nie quer über alle Spuren (v0.5.0: im Schnee traf er so ein 95 km/h langsameres Auto in der Mittelspur) –,
fädelt aus der rechten Spur in die Tankspur ein und fährt unter 60 km/h (wer die rechte Spur nicht rechtzeitig
erreicht, tankt an der nächsten Tankstelle); während des Tankens gibt er kein Gas (sonst
bricht das Tanken ab). Rollt der Wagen mit leerem Tank aus (`fuel.rolling_out`), bremst er nur für Kurven – die Bremse
wirkt dabei (gameplay.md „Automatik“), und Bremsen für die Tankspur würde ihn vor ihr anhalten.

**Kurven** (`curve_speed_ahead`): Seit dem Untersteuern (gameplay.md „Untersteuern“) darf er nie über die Kurvengrenze.
Bremskurve über `curve_lookahead_m` (300 m, alle `curve_step_m` = 10 m): an jedem Punkt soll er
`curve_margin` (96 %) der sicheren Kurvengeschwindigkeit `curve_lead_m` (12 m) früher erreicht haben, geplant mit
`brake_decel_mps2` (15 m/s², unter den echten 70 km/h/s = 19,4 m/s²; Haftung je Punkt aus `Track.grip_at`, im
Tunnel trocken); dazu der Punkt unter dem Auto. Pedale
(`pedals`): Vollgas unter dem Ziel, über Ziel + 2 km/h fest bremsen (30 % bis voll bei 12 km/h darüber), dazwischen
60 % Gas. Ergebnis: auf allen gemessenen Etappen und beiden ganzen Rennen `understeer` = 0 und kein Bankett/keine
Leitplanke durch Kurven (gameplay.md (i4)). Debug: `--autopilot-target=<km/h>` (Wunschtempo statt
`debug.autopilot_target_kmh` 235, z. B. 300 = vmax), `--autopilot-no-curve-brake` (ignoriert Kurven – fährt zu schnell
hinein und untersteuert, für die Demo des Fahrmodells).

**Wetter und dichter Verkehr** (v0.5.0; der Autopilot fährt Tests, Demos und den Attract-Mode und muss jedes Rennen bei
jedem Wetter ohne Unfall und ohne Ausflug neben die Fahrbahn schaffen):

- Er plant mit `plan_decel(v, Haftung)` = `brake_decel_mps2` (15 m/s²), aber höchstens `brake_fraction` (75 %) der
  echten Vollbremsung auf dieser Fahrbahn (`VehicleModel.brake_decel_mps2`: Regen ≈ 11,4, Schnee ≈ 7,3 m/s²) – für
  Kurven, Radar und Verkehr.
- Langsamer Verkehr: folgt auf der relativen Bremskurve (`_follow_speed`: Tempo des Vordermanns
  + √(2 · Planverzögerung · (Abstand − Sicherheitsabstand)), Sicherheitsabstand 12 m + 0,9 s) statt linear – bei
  Annäherung mit 150 km/h Unterschied im Schnee beginnt er früh genug. Autos im Fahrweg prüft er so weit voraus, wie
  sein Bremsweg reicht (`_look_m`: 110–320 m).
- Blinker: ein Auto, das in eine Spur blinkt, zählt dort schon als Hindernis (`_in_lane`, `_car_in_path`) – er bremst
  oder weicht aus, bevor es herüberzieht.
- Eigene Spurwechsel nur, wenn die Lücke vorn den Spurwechsel (`_lc_time` = max(1,4; 0,6 + 2 · Ansprechzeit der Lenkung)
  bei der Annäherung) plus den relativen Bremsweg abdeckt, und erst wenn er wieder in seiner Spur ist.
- Lenken: PD-Regler auf Querabstand und Quergeschwindigkeit (`steer_to`), Verstärkung aus der Ansprechzeit τ der Lenkung
  auf dieser Fahrbahn (`VehicleModel.steer_response_s`) und der Quergeschwindigkeit bei vollem Einschlag V: geschlossener
  Kreis τ·x'' + (1 + V·kd)·x' + V·kp·x = 0 mit ω = min(7; 1,7/τ), Dämpfung 0,85. Trocken ist das die alte
  P-Lenkung (kp ≈ 0,7); im Schnee lenkt er früh gegen, statt zu pendeln (Test: Spurwechsel bei 200 km/h überschwingt
  < 0,4 m bei jedem Wetter).
- **Spurenden** (Review v0.5.0 – im Königsrennen überholte er vor den City Limits in der leeren rechten Spur, die 250 m
  später endete, und 90 m vor ihrem Ende schob ihn eine Spurwahl ohne Lückenprüfung in die stehende Einfädel-Kolonne
  der Mittelspur: 157 km/h auf ein stehendes Auto): `Track.lane_end_ahead(z, Spur, Weite)` sucht das Ende jeder Spur
  über den Spurhorizont `lane_horizon_m` = Bremsweg (`_look_m`) + `lane_change_s` (6 s) Fahrt – 235 km/h trocken ≈ 620 m,
  100 km/h ≈ 280 m; gemessen bis dorthin, wo der Verkehr sie verlässt (`road.lane_transition_m` vor der Verengung).
  Eine Spur, die innerhalb des Horizonts endet, ist kein Ziel zum Überholen, auch wenn sie leer ist; endet die eigene,
  wechselt er früh nach links, aber nur in eine freie Lücke – ohne Lücke hält er `lane_end_margin_m` (25 m) vor ihrem
  Ende an, statt sich hinüberzudrängen (Grund `lane end`).
- **Tankspur verlassen**: nach dem Tanken (oder in der Tankspur ohne Tankabsicht) zurück in die rechte Spur nur durch
  eine freie Lücke – auch nach hinten: `_lane_free` verlangt hinten 12 m + 0,5 s Annäherung + deren Bremsweg mit
  `behind_brake_mps2` (3 m/s²; mit 30 km/h vor einem Auto mit 100 km/h ≈ 85 m; vorher 2 s Annäherung = 51 m). Bis dahin
  fährt er in der Tankspur weiter und hält vor ihrem Ende (`Track.fuel_lane_end_ahead`, Grund `fuel exit`). Vorher zog
  er mit 31 km/h vor ein Auto mit 100 km/h (Kiel – Nürnberg, Sportwagen bei vmax).
- `weather_aware = false` (nur Messungen): plant Verkehr, Lücken und Lenken wie auf trockener Straße.
- Ergebnis: in den Messungen (gameplay.md (j)) und `tests/unit/race/test_autopilot_weather.gd` (dichter Berufsverkehr bei
  Schnee und Regen, Autobahn, kurvige Landstraße, Autobahn mit Limit) keine Kollision, nie neben der Fahrbahn, kein
  Untersteuern.

## 11. Debug-Kommandozeile

Zusätzlich zu ARCHITECTURE.md §13 (`--stage --from --vehicle --hour --weather --start-km --autopilot
--autopilot-speeding --no-countdown --seed --timescale --screenshot --shot-times --quit-at-finish`):

| Argument | Wirkung |
|---|---|
| `--start-speed=<km/h>` | Starttempo (für Screenshots in Fahrt) |
| `--lane=<n>`, `--x=<m>` | Startspur bzw. Querposition |
| `--fuel=<0..1>` | Tankfüllung beim Start |
| `--no-traffic` | ohne Verkehr |
| `--traffic-warmup` | Verkehr um die Startposition aufbauen (Screenshots) |
| `--scenery=<id>` | eine Landschaft für die ganze Etappe (Hintergründe prüfen) |
| `--autopilot-refuel=auto\|always\|never` | Tankverhalten des Autopiloten |
| `--autopilot-target=<km/h>` | Wunschtempo des Autopiloten (Standard `debug.autopilot_target_kmh` 235; 300 = immer vmax) |
| `--autopilot-no-curve-brake` | Autopilot bremst nicht für Kurven (untersteuert – Demo/Test des Fahrmodells) |
| `--perf` | am Ziel Frame-Zeiten ausgeben (`PERF {...}`, mit `drive`: Sekunden auf dem Bankett/an der harten Grenze, Leitplankentreffer, Sekunden mit Untersteuern und dessen Maximum) |
| `--trace[=<km>]` | Fahrprotokoll alle n km (Tempo, Zieltempo, Grund, Kurve, Steigung, Untersteuern, Tank) |
| `--tutorial` | Tutorial-Hinweise auch auf anderen Etappen |
| `--sprite-manifest=<pfad>` | weiteres Sprite-Manifest über das echte legen (`SpriteDB`, Dateipfade relativ zu ihm, `aliases` zeigen echte Sets auf andere); z. B. die Testdaten `res://tests/fixtures/sprites/manifest.json` (§8) |

`--timescale=<f>` setzt `Engine.time_scale` und die Physiktakte auf 60·f, damit jeder Schritt 1/60 s bleibt.
Setup-Schlüssel für Tests: `no_countdown`, `autopilot_speeding`, `autopilot_refuel`, `autopilot_target`,
`autopilot_no_curve_brake`, `traffic_warmup`, `tutorial`; Review v0.5.0: `start_speed_kmh` und `start_lane` (fliegender
Start der Attract-Demos – vor dem Aufbau des Verkehrs gesetzt, der den Start dafür freiräumt: ein Auto in der Startspur
näher als 12 m + 0,9 s Fahrt + Bremsweg auf sein Tempo mit halber Bremsleistung kommt hinter den Wagen,
`warm_up_clear_m`).

Demo des Fahrmodells als Video (Godot Movie Maker, unter Xvfb): zu schnell in die scharfe Linkskurve der Dev-Etappe bei
km 69 und dieselbe Kurve mit Bremsen:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
  --write-movie /tmp/zu_schnell.avi --fixed-fps 30 --quit-after 345 res://scenes/race/race.tscn -- \
  --stage=dev_testetappe --start-km=65 --start-speed=205 --lane=1 --no-traffic --no-countdown --hour=12 \
  --autopilot --autopilot-target=205 --autopilot-no-curve-brake      # ohne den letzten Schalter: bremst richtig
```

## 12. Tests und Werkzeuge

- Städte: `tests/unit/data/test_cities.gd` (alle Ankünfte ohne Warnung, Stile, Landschaften, Katalog, Pflicht-Wahrzeichen
  und -Brücken), `tests/unit/race/test_city_track.gd` (Stadtrand/Zentrum, Brücken-Zonen, Tragwerk, Boote, Wahrzeichen
  mit freiem Platz), `tests/unit/race/test_city_render.gd` (`landmark_fade` stetig, Wasser, Profile) –
  [staedte.md](staedte.md) §9.
- `tools/run_tests.sh race` – Unit-Tests: Track (Determinismus, Fenster, Spurübergänge, Tankspur, Ereignisse,
  Geometriegrenzen, Requisiten, vollständige `scenery.json`, Schilder im Tunnel an der Wand, Land/Straßentyp der
  Schilder, Kurvenschilder: Warnschild vor jeder scharfen Kurve und Richtungstafeln außen, gleiche Schilder beim
  Streamen und schon in Sichtweite vorhanden, Sichtprüfung der Teststrecke für den Gran Turismo bei Tag und bei
  Schnee in der Nacht – Kurven und, seit dem Review v0.5.0, der langsamste Verkehr aus dem Nebel bei Schnee/Regen/Nacht
  `test_traffic_is_seen_in_time`; Vorschild der City Limits), Projektion, Palette, GeoBatch, Autopilot-Bremskurve, Autopilot auf Bergstraße und kurviger
  Autobahn ohne Untersteuern (GT bei Schnee, Kompakt; ohne Kurvenbremsen untersteuert er), Spiegeln und Vorderkante aller kantenbündigen
  Requisiten mit dem echten Manifest, Schilderstile je Land, Sitzungsregeln (Kollisionen in geskripteten Phasen,
  HUD-Tankstelle, Ausrollen in die Tankspur, Überholweg der Polizei, Wetterhinweis und City-Limits-Ansage),
  Tutorial-Warteschlange und -Texte;
  Fahrzeugdarstellung v2: `test_vehicle_pose.gd` (Lkw 30 m voraus in der Nachbarspur ≈ 4,6° statt 12°, Front des
  Sprites an der wahren perspektivischen Position über Kurven/Spuren/Längen, Eigenrichtung beim Spurwechsel, kein
  Zellflackern auf gleichmäßiger Kurve trotz Rauschen und schwankender Bildzeit, Hysterese-Band, kritische Dämpfung,
  Gierwinkel-Anteile und Blickwinkel des Spielerautos, Neigung, perspektivischer Maßstab), `test_box_vehicle.gd`
  (gezeichnete Aufstandsfläche = Kollisionsbox, sichtbare Flächen, Lkw neben dem Spieler bleibt sichtbar, Abschnitte
  ≤ 2 m folgen der Kurve, feste Abschnittsgrenzen, von hinten nach vorn, Bildausrichtung der Flächen,
  Licht-Überlagerungen, Rücklichter des Sattelzugs), `test_sprite_db.gd` (altes Manifest-Format unverändert –
  `tests/fixtures/legacy/manifest.json`, damit der Test unabhängig vom jeweils gelieferten echten Manifest bleibt –,
  echtes Manifest in sich stimmig, Winkel aus Namen/Listen/Wörterbuch, Raster-Layout, Testdaten, Quader-Teile aller
  Quader-Sets = Objektmaße, Zusatz-Manifest und Aliase).
- `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30
  -s res://tests/race/shoot_vehicles.gd -- --scenario=<name> --out=<präfix> [--sprite-manifest=res://tests/fixtures/sprites/manifest.json]
  [--hour=22] [--verbose]` – Fahrzeug-Szenarien als Bildfolgen (`<präfix>_NN.png`, feste Bildrate = gleiche Spielzeit
  je Bild): `curve_left`, `curve_right`, `overtake`, `overtake_curve`, `lane_change`, `player_left`, `player_right`,
  `player_lanes`, `police`, `tunnel`. Am Ende je Auto die Zahl der Zellwechsel und der Bereich des
  Darstellungswinkels (Flacker-Prüfung im echten Renderer); `--no-shots --perf` läuft auch headless und gibt die
  `_draw`-Zeiten aus. `python3 tests/fixtures/make_fixtures.py` erzeugt die Testdaten neu.
- `godot --headless --path . --fixed-fps 60 -s res://tests/race/check_attract_scenes.gd [-- --only=wien,paris]` (Review
  v0.5.0, ~2 min, in `tools/run_tests.sh`): jede Attract-Szene 30 s durch das echte Spiel – endet nach Zeit (nicht im
  Ziel), ohne Kollision, Leitplanke und Ausflug neben die Fahrbahn, nie näher als 10 m hinter einem Auto (in den ersten
  3 s 15 m), Ø ≥ 70 km/h (docs/ui.md „Attract-Modus“).
- `godot --headless --path . -s res://tests/race/check_session.gd [-- --only=coll_right,tutorial]` – Szenarien in
  der echten Rennszene (≈ 30 s): Auffahrunfall genau von hinten in rechter/linker/mittlerer Spur → Seite mit mehr
  Platz bzw. links; Ausrollen mit leerem Tank in ein langsameres Auto → Kollision, Abschleppen erst nach dem
  Abschleppen gezählt; leer in die Tankspur gerollt → getankt, kein Abschleppen; Auslaufen nach dem Ziel →
  Kollision statt Durchfahren; Verfolgung bis in den Tankstopp → Polizei genau beim Tanken blockiert, HUD-Werte;
  Kiel – Hamburg zeigt alle Tutorial-Hinweise, andere Etappen keine; Untersteuer-Rutscher in die Leitplanke →
  Tempoverlust, Kamerawackeln, Aufblitzen. Ausgabe `CHECK <name> OK|FEHLER`, Exit-Code.
- `godot --headless --path . -s res://tests/sim/check_escapes.gd [-- --only=good]` – Polizeiflucht im ganzen Netz
  (≈ 60 s, läuft in `tools/run_tests.sh` nach den Szenarien): jedes Radarfeld × jedes Auto × trocken am Tag / Regen in
  der Nacht, Fahrer „ideal“ (an der eigenen Kurvengrenze, Bremsen mit 70 km/h/s) und „gut“ (97 %, Bremsen mit nur
  10 m/s²) – jede Verfolgung muss zu entkommen sein (gameplay.md (e3)). `tests/unit/race/test_police_curves.gd`: die
  kurvigsten Radar-Etappen im Unit-Test, Abtastung der Sitzung = exakte Bremskurve.
- `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s
  res://tests/race/check_sprite_flip.gd` – prüft mit echtem Renderer, dass Godot gespiegelte Rechtecke an Ort und
  Stelle zeichnet (Grundlage von `flipped_draw_rect`).
- `tests/unit/race/test_autopilot_weather.gd` (v0.5.0): PD-Lenkung des Autopiloten pendelt bei keinem Wetter
  (Spurwechsel bei 200 km/h < 0,4 m Überschwingen, nach < 2,5 s in der Spur), Planverzögerung nach Wetter, dichter
  Berufsverkehr bei Schnee (Gran Turismo, 110 km) und Regen (Kompakt, 80 km) ohne Kollision, Bankett und Untersteuern,
  zur Tankspur Spur für Spur nur in freie Lücken (`test_fuel_lane_approach_waits_for_a_gap`); Review v0.5.0: am Spurende
  3 → 2 mit stehender Kolonne in der Mittelspur hält er vor dem Ende, statt hineinzuziehen
  (`test_lane_end_stops_instead_of_forcing_into_a_jam`), überholt nie in einer endenden Spur
  (`test_does_not_overtake_in_an_ending_lane`) und verlässt die Tankspur erst, wenn das Auto mit 100 km/h von hinten
  vorbei ist (`test_fuel_lane_exit_waits_for_the_traffic_behind`).
- `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 --write-movie
  /tmp/schnee.avi --fixed-fps 30 --quit-after 1100 -s res://tests/race/movie_snow.gd -- --start-speed=120
  [--stage=hamburg_bremen --km=26 --hour=7.5 --weather=snow]` – Demofahrt als Video (v0.5.0: Berufsverkehr, fliegender
  Start mit 120 km/h): Schnee auf der Autobahn, langsamer Verkehr; der Autopilot
  wählt Tempo und Spur, gelenkt wird wie mit der Tastatur (voller Einschlag, loslassen wie auf trockener Straße) – der
  Wagen rutscht nach jedem Spurwechsel weiter und wird abgefangen (gameplay.md „Wetter“).
- `godot --headless --path . -s res://tests/race/run_stage.gd -- --stage=dev_testetappe [--hour=21 --weather=rain
  --timescale=40 --vehicle=… --from=… --autopilot-refuel=always]` – fährt die ganze Etappe so schnell wie möglich
  (~35× Echtzeit) und gibt `ERGEBNIS {…}`, `PERF {…}` und `RUN {…}` aus; Exit-Code 0 = im Ziel.
- `godot --headless --path . -s res://tests/race/bench_render.gd -- [--kms=5,30,50.5,79,112 --hour=22 --phases]` –
  friert die Szene an Positionen ein und misst `_draw` (Median/Min/p90).
- Hinweis: `-s`-Skripte werden vor den Autoloads kompiliert – darin keine statischen Typen von Klassen verwenden, die
  Autoloads benutzen (`RoadRenderer`, `race_session.gd`).

## 13. Performance

Gemessen headless (`bench_render.gd`, reine GDScript-CPU-Zeit von `_draw`, geteilte VM mit Last ~2–3 auf 4 Kernen):
Tag Median **≈ 5,5 ms** (Minimum 3,2–5,7 ms), Nacht **≈ 5,0 ms**, Regen nachts ≈ 6 ms; Simulation ≈ 0,3 ms je
Schritt. Aufteilung (Nacht): Boden ~2 ms, Bauwerke ~0,8 ms, Sprites ~0,7 ms, Hintergrund ~0,5 ms, Projektion ~0,4 ms,
Himmel ~0,3 ms. Auf einem normalen Desktop-Prozessor etwa die Hälfte. Maßnahmen: LOD-Verschmelzung (≈ 45 statt
300 Scheiben), unsichtbaren Boden überspringen, Vier-Ecken-Batching, Zeilen-Lichtlisten nachts, Sprite-Daten je
Requisit zwischengespeichert, früher Größen-/Bildschirm-Ausschnitt, Projektion in lokale Arrays.
`perf_stats()` von Renderer und Sitzung liefert die Zahlen; `debug.show_render_stats` blendet sie im Bild ein.

Fahrzeugdarstellung v2 (gemessen während parallel Blender renderte, Last ≈ 3,8 auf 4 Kernen – die Mediane schwanken
um ±1 ms, verglichen werden die Minima von `bench_render.gd` an denselben fünf Positionen): vorher 4,35 ms, mit den
heutigen Sprites 4,54 ms, mit den Testdaten (17-Winkel-Pkw, perspektivisches Spielerauto, Quader-Lkw) 4,80 ms; die
Mediane lagen bei 5,4–6,7 ms für alle drei. Ein Quader-Lkw kostet (Mikro-Benchmark, eine Scheibe je 3 m) 0,08 ms in
200 m, 0,15 ms in 20–60 m und 0,35 ms beim Überholen direkt daneben (≈ 150 Vierecke); je Sprite-Fahrzeug kommen
Winkelformel, Glättung und Zellwahl hinzu (wenige µs). Maßnahmen: Abschnittslängen nach Tiefe (fern 2 m, nah kürzer),
Abschnitte außerhalb des Bildes entfallen, Straßenproben an gemeinsamen Abschnittsgrenzen nur einmal, Teile-Reihenfolge
zwischengespeichert, Lichtüberlagerungen nur bei Licht, Zellsuche ab der aktuellen Zelle.

## 14. Stellschrauben (Konfiguration)

`road`: `lane_width_m`, `lanes`, `shoulder_width_m`, `guardrail`, `curve_radius_at_1_m`, `curviness_max_curve`,
`hills_max_grade`, `lane_transition_m`, `fuel_lane_taper_m`, `runout_m`, `delineator_every_m`, `streetlight_every_m`,
`crosswalk_every_m`, Kurvenschilder (§4): `curve_warning_min_curve` (0,25), `curve_warning_blind_min_curve` (0,12),
`curve_warning_sight_m` (150), `curve_warning_m` (200), `chevron_every_m` (30); Kuppenschilder (§4, Review v0.5.0):
`crest_warning_sight_m` (180; 0 = keine), `crest_warning_check_m` (250), `crest_warning_m` (150),
`crest_target_height_m` (0,75). `curviness_max_curve` [0; 0,30;
0,45; 0,9] (Kurvigkeit 1 seit dem Spieltest „Kurven immer mit Top Speed“ 0,30 statt 0,22: R ≥ 400 statt 545 m,
gameplay.md (i)).

`render`: `segment_length_m`, `draw_distance_m`, `fov_deg`, `camera_height_m`, `camera_distance_m`, `horizon_y_frac`,
`fog_start_frac`, `hill_height_scale`, `stripes` (`grass`, `road`, `dash` je Straßentyp in Segmenten),
`edge_line_m`, `lane_line_m`, `tunnel` (`wall_height_m`, `ceiling_m`, `light_every_m`, `haunch_m`, `darkness_m`,
`peek_m`), `background_parallax`, `near_m`, `lod_merge_px`, `lod_from_m`, `lod_max_segments`, `lod_detail_m`,
`headlight_range_m`, `headlight_intensity`, `background_blend_s`, `camera_follow`, `camera_lag_max_m`,
`finish_decel_kmh_s`, `finish_hold_s`, `procedural_props` (`auto` = Zapfsäulen/Shop/Zollhaus/Blitzer prozedural
zeichnen, solange das Sprite-Manifest nur Platzhalter enthält; `always`/`never`), `scripted_collision_min_kmh`
(30: darüber kollidiert der Wagen auch in geskripteten Phasen), `tutorial_hint_s` (6: Anzeigedauer eines
Tutorial-Hinweises), Leitplankentreffer (§9): `rail_shake_min_s` (0,15), `rail_shake_max_s` (0,45),
`rail_shake_full_mps` (8), `rail_flash_min_mps` (2). Fahrzeugdarstellung (§8): `vehicle_yaw_smooth_s` (0,12), `vehicle_cell_hysteresis` (0,3 Schritte),
`vehicle_yaw_max_deg` (30), `vehicle_warp` (an), `vehicle_warp_min_ratio` (0,06), `box_slice_m` (2), `box_slice_ratio` (0,12), `box_subdiv_px` (1,5),
`player_curve_lookahead_m` (10), `player_curve_gain` (1), `player_steer_deg` (3), `player_lateral_gain` (1),
`player_understeer_deg` (6), `player_view_gain` (1), `player_yaw_max_deg` (20), `player_yaw_smooth_s` (0,15),
`player_roll_deg_per_mps2` (0,22), `player_roll_max_deg` (2,5 – mehr lässt der Vertrag nicht zu),
`player_roll_smooth_s` (0,2).

Städte (optional, Standardwerte im Code): `landmark_far_m` (1900: Wahrzeichen höchstens so weit sichtbar, nachts ihre
Anstrahlung), `landmark_range_factor` (2,0 × Sichtweite), `skyline_distance_m` (1800: Größe der Panorama-Silhouetten).

`debug`: `autopilot_target_kmh`, `show_render_stats`.

## 15. API-Erweiterungen (zusätzlich zu ARCHITECTURE.md)

- `Track`: `zones`, `runout_m`, `hill_scale`, `window_size()`, `distance_to_fuel_lane(z)`, `events_for_segment(i)`,
  `generation_lead_m()` (Vorlauf der Erzeugung vor dem Fenster, Kurvenschilder §4), `grip_at(z, weather_grip)`
  (Haftung: im Tunnel 1,0), `curve_signs_cut` (Diagnose: Warnschilder abgeschnittener Kurvenstücke),
  Konstanten `WALL_SIGN_GAP_M`, `WALL_SIGN_OVERHANG_M`; Schild-Requisiten zusätzlich `country`, `road`, im Tunnel
  `wall` (und `scale` < 1); Schildarten `curve` (Warnschild), `crest` (Kuppe, Review v0.5.0; Zähler `crest_signs`) und
  `chevron` (Richtungstafel), `value` = Richtung;
  `town_ahead` (Vorschild der City Limits: `text` Ziel, `value` km, `limit` Stadtlimit), `city_announce_km()`
  (`city_limits.announce_km`, Review v0.5.0); `lane_end_ahead(z, lane, look_m)` (Meter bis dorthin, wo die Spur für
  den Verkehr endet, INF = geht weiter) und `fuel_lane_end_ahead(z)` (Meter bis zum Ende der Tankspur, in der z liegt)
  – Review v0.5.0 für den Autopiloten (§10).
- `Autopilot`: `curve_brake`, `curve_margin`, `curve_lookahead_m`, `curve_step_m`, `curve_lead_m`,
  `curve_speed_ahead(track, vehicle, z, grip)`, statisch `pedals(speed, want)` → `{throttle, brake}`; Review v0.5.0:
  `lane_end_margin_m`, `lane_change_s`, `behind_brake_mps2`, `lane_horizon_m(speed)`.
- Rennsitzung: `drive_stats` (`off_road_s`, `limit_s`, `rail_hits`, `understeer_s`, `understeer_max`), in
  `perf_stats()["drive"]`; Tutorial-Thema `curve` (`TutorialCoach.URGENT`).
- `TrackSegment`: `runout`, `fuel_zone` (+ Konstanten `FUEL_*`), `cover`, `cover_front`, `country_to`; Städte: `bridge`,
  `bridge_i`, `water`, `water_depth`, `water_level`, `bank`.
- `Track` (Städte): `bridges` (Zonen `{z0, z1, type, depth, slope, name, water, color, bank, km0, km1}`), `landmarks`
  (Fernliste mit `z`, `x`), `bridge_at(z)`, statisch `water_level_at(z, bridge)`, Konstanten `BRIDGE_PORTAL_EVERY_M`,
  `BRIDGE_LAMP_EVERY_M`, `BRIDGE_DECK_EXTRA_M`; Requisiten mit `h` (Höhe über/unter der Straße, Boote), `fit_w`
  (Breite eines Portals), `landmark`, `overhead`, `fallback_tint`.
- `RoadProjection`: `scale_at(dz)`, `ground_row(dz)`, `depth_at_row(y)`, `view_angle(dx, dz)`, `near` aus `render.near_m`.
- `RoadRenderer`: `perf_stats()`, `show_stats`; View-Schlüssel zusätzlich `camera_in_tunnel`, `countdown`, `chase01`,
  `radar_flash01`, je Auto `length`, `speed`, `heavy`. `palette` ist immer die Außenpalette, die Tunnelvariante bildet
  der Renderer selbst. `bg_offset` ist der Kurswinkel in Radiant. Statisch: `prop_flipped(side, rule_mirror,
  tag_mirror_left)`, `edge_anchor_x(x, side, flipped, extent, scale)`, `sprite_dest(p, w, h, anchor, flip)`,
  `flipped_draw_rect(dest)`. Schilder werden mit ihrem `scale` gezeichnet.
  Fahrzeugdarstellung v2: `road_at(z)` → `Vector3(Straßenmitte seitlich, Höhe relativ zur Kamera, Tiefe)`,
  `road_heading_at(z)`, `vehicle_yaw_deg(id)`, `vehicle_cell(id)`, `last_player_pose` (`yaw_deg`, `roll_deg`, `cell`,
  `anchor`, `scale`, `perspective`, `rect`), statisch `cell_src(info, angle_index, row)`. View-Schlüssel zusätzlich je
  Auto `id` (Glättung je Fahrzeug, Polizei −2), beim Spieler `steer`, `lat_speed`, `push_speed`, `understeer`, `width`;
  `angle` ist optional geworden (erzwingt eine Zelle, beim Spieler nur ohne `steer`) – die Sitzung schickt es nicht mehr.
- `RoadRenderer` (Städte, statisch): `landmark_fade(dz, vis, fog_start, range_k, far_m)` → `Vector2(Alpha, Dunst)`,
  `water_tint(base, ambient, sky, dz)`, `eiffel_half_width(h)`. `RaceBackdrop`: Stil `suburb`, `landmarks` (Silhouetten
  des Bildes), `sprite_cb` (zeichnet eine Silhouette), Hintergrund-Schlüssel `roofs`, `behind`, Merkmale `cranes`,
  `domes`, `onion`, `slabs`, `towers`.
- `VehiclePose` (statisch): `ortho_yaw(d_r, x_r, h, psi_c, length, limit_deg)`, `chord_heading(xr_road, xf_road,
  length)`, `point_yaw(d_r, x_r, h)` (alte Formel, Vergleich), `own_heading(lateral_mps, speed_mps)`,
  `ortho_front_x(sx_r, s_r, length, psi)`, `damp(value, velocity, target, dt, tau)` → `Vector2(Wert, Geschwindigkeit)`,
  `pick_cell(yaws, yaw_deg, current, hysteresis)`, `player_yaw_target(curve_heading, steer, lat_mps, speed_mps,
  understeer, curve_sign, view_angle, k)`, `roll_target_deg(a_lat, deg_per_mps2, max_deg)`,
  `perspective_scale(camera_distance_m, depth, supersample)`.
- `BoxVehicle`: `setup(proj, slice_m, ratio, err_px)`, `clear()`, `emit(parts, lights, zc, xc, z_lo, z_hi, cam_z, road:
  Callable, col, tail, brake)` → `pts`, `uvs`, `cols`, `idx`, `quads`, `rear_drawn`, `rear_rect`, `order`;
  `slice_bounds(z_a, z_b, z_part0, cam_z)`, statisch `side_visible(xa, za, xb, zb, left)`, `part_order(parts)`;
  `debug` + `faces_out` (Tests).
- `SpriteDB` (Kern-Datei, für die Fahrzeugdarstellung erweitert; alle bisherigen Funktionen unverändert, `region()`
  rechnet mit `grid_cols`, `resolve_angle()` übersetzt alte Namen in den nächsten Winkel neuer Sets):
  `load_manifest(path)`, `merge_manifest(path)` (mit `aliases`; `--sprite-manifest`), `overlay_paths`,
  `cell_region(id, angle_index, layer)`, `grid_cols(id)`, `yaw_list(id)`, `angle_count(id)`,
  `nearest_angle_index(id, yaw_deg)`, `projection(id)`, `pivot(id)`, `render_mode(id)`, `is_box(id)`, `camera(id)`,
  `supersample(id)`, `box_parts(id)` (Flächen als `Rect2`), `box_lights(id)` (Teil als Index); statisch
  `derive_meta(set)`, `parse_yaws(set)`, `name_yaw(name)`, `nearest_yaw_index(yaws, yaw)`, `cell_grid_pos(i, cols)`,
  `parse_parts(set)`, `parse_lights(set, parts)`. Sheets, die Godot nicht importiert hat (Testdaten außerhalb des
  Projekts), lädt `texture()` direkt aus der PNG-Datei.
- `SignPainter`: `countries` (vom Renderer aus `GameData.countries`), statisch `style_for(countries, code)` →
  `{motorway, motorway_fg, road, road_fg, town_bg, town_fg, town_border}`, `board_half_width(kind)`, `contrast(bg)`.
- `Palette`: Schlüssel `sky_mid`, `glow`, `cloud`, `cloud_dark`, `moon_visible`, `moon_pos`, `overcast`, `tunnel`;
  `tunnel(p)`, `luminance(c)`, `lit(p, extra)`.
- Rennsitzung: `perf_stats()`, `road_info(z)`, `last_input`, `traffic_enabled`, `cam_x`, `coach` (TutorialCoach oder
  null), Setup-Schlüssel siehe §11.
- `SessionRules` (statisch): `collisions_active(invulnerable, scripted, speed_kmh, rolling_out, min_scripted_kmh)`,
  `next_station_km(plan, km, refueling)`, `roll_distance_m(speed, target, decel)`, `can_roll_into_lane(z, speed,
  decel, trigger, lane_open_z, lane_z1)`, `police_pass_side(player_x, left_edge, lane_w)`, `police_car_x(offset,
  player_x, side, lane_w, pull_over_m, clear_m)`, `police_curve_cap_kmh(track, police, z, weather_grip)`
  (Kurvengrenze des Polizeiwagens für `PoliceSystem.update`); Review v0.5.0: `weather_hint(cfg, weather)` (Wetterhinweis
  beim Countdown, "" bei trocken), `city_announce_text(name, km, limit)`, `city_announce_due(km_before, km_now,
  city_limits_km, announce_km)`.
- `RoadRenderer` (Blinker, Review v0.5.0): Konstanten `INDICATOR_MIN_PX`, `INDICATOR_MIN_GLOW_PX`, statisch
  `indicator_glow_px(s, lights)`.
- HUD-Zustand zusätzlich `escape_kmh` (aktuelle Fluchtschwelle der Polizei, `PoliceSystem.escape_kmh`).
- `TutorialCoach`: `setup(cfg)`, `trigger(topic, args) → Anzahl`, `hold(s)`, `update(dt) → Text|""`, `pending()`,
  `hints_for(topic, args)`, `hint_s`, `gap_s`, `shown`; Themen `start, fuel_low, fuel_hud, fuel_announce, fuel_lane,
  refuel, radar, chase, unlimited, city, collision`.
- `Autopilot`: `refuel_mode`, `last_want`, `last_reason`.
