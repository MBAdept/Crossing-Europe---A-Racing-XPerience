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
| `scripts/race/sign_painter.gd` | `SignPainter` | prozedurale Schilder mit Text (Tempo, Radar, Tankstelle, Ortsschild, EU-Grenze, Tunnel, Autobahn, Start/Ziel) |
| `scripts/race/geo_batch.gd` | `GeoBatch` | sammelt farbige Vierecke und schickt sie als ein Dreiecks-Array an den RenderingServer |
| `scripts/race/vehicle_pose.gd` | `VehiclePose` | Fahrzeugdarstellung v2, reine Mathematik: Darstellungswinkel mit Fahrzeuglänge, kritisch gedämpfte Glättung, Zellwahl mit Hysterese, Gierwinkel und Neigung des Spielerautos |
| `scripts/race/box_vehicle.gd` | `BoxVehicle` | Lkw/Busse als texturierte Quader: sichtbare Flächen, Abschnitte entlang der Straße, nahe Ebene, Texturkoordinaten |
| `scripts/race/palette.gd` | `Palette` | Farben nach Tageszeit, Wetter, Tunnel |
| `scripts/race/race_session.gd` | (Szene `scenes/race/race.tscn`) | Rennsitzung: Countdown, Simulation, HUD/Audio/Renderer füttern, Meldungen, Pause, Ziel |
| `scripts/race/session_rules.gd` | `SessionRules` | reine Regeln der Rennsitzung (Kollisionen in geskripteten Phasen, HUD-Tankstelle, Ausrollen in die Tankspur, Überholweg der Polizei) – testbar ohne Szene |
| `scripts/race/tutorial_coach.gd` | `TutorialCoach` | Tutorial-Hinweise der Etappe Kiel – Hamburg (Warteschlange, Texte mit Konfigurationswerten) |
| `scripts/race/autopilot.gd` | `Autopilot` | Testfahrer (Spur halten, überholen, bremsen, tanken, Radar beachten) |
| `data/scenery.json` | – | 22 Landschaften: Grasfarben, Hintergrund, Klima, Requisiten-Regeln |
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
- **Fenster**: `update_window(camera_z, ahead)` erzeugt bis `ahead` voraus und verwirft Segmente hinter der Kamera
  (`keep_behind` = 64).
- **Spuren**: Autobahn 3, Landstraße 2, Stadt 2 (`road.lanes`). Wechsel über `road.lane_transition_m` weich
  (`lanes_at` gebrochen); `lane_count_at` meldet dem Verkehr schon vor und während des Übergangs die kleinere Zahl.
- **Tankspur**: `fuel_lane_factor` 0..1 mit `road.fuel_lane_taper_m` Ein-/Ausfädelung; `fuel_lane_at` nur bei ganz offener
  Spur im StagePlan-Bereich. Zapfsäuleninseln, Dächer und der Tankstellen-Shop sind Bauwerke/Objekte entlang der Spur.
- **Ereignisse** (`_build_events`): Tankstellenschilder 30/15/5 km, Spur-Hinweis, Preis-Pylon; Radarwarnung 10 km vorher
  (mit Limit), Tempo-Schilder beidseitig am Radarfeld + Wiederholung, Blitzer, Aufhebung am Ende; Tempolimits und
  Autobahn-Beginn/-Ende an Abschnittsgrenzen; Tunnelschild (Name + Länge); EU-Grenzschilder (Landesname in Landessprache,
  auch kyrillisch), Grenzstation (Dach über der Fahrbahn mit Landesnamen, Zollhäuschen), neues Tempolimit; Ortsschild
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
Fehlt ein Sprite-Set (noch nicht gerendert), nimmt der Renderer den `fallback` oder überspringt die Regel.
Hintergrundstile wechseln weich (alte Silhouetten sinken, neue steigen, `render.background_blend_s`).

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
  + karierte Ziellinie.

**Schilder je Land** (Design: „Grenzübergänge: Wechsel von Schildern, Landschaft und Polizeifahrzeugen“): `SignPainter`
nimmt die Farben aus `GameData.countries[Land].signs` (`data/countries.json`, Daten-Modul): `motorway` für
Wegweiser, Autobahnschild und Tankstellen-Ankündigungen auf der Autobahn (DE/NL/FR … blau, CH/IT/SI/HR/CZ … grün),
`town_bg`/`town_fg`/`town_border` für das Ortsschild (DE gelb/schwarz, NL und CH blau/weiß, FR/BE/ES/AT weiß mit
breitem rotem Rand, IT … weiß/schwarz). Wegweiser abseits der Autobahn: `signs.road`/`road_fg`, falls in den Daten
vorhanden, sonst blau/weiß in Ländern mit grünen Autobahnschildern und sonst die Ortsschildfarben (DE gelb, NL blau,
FR weiß). Unbekanntes Land → deutscher Stil. Tempo-, Radar-, Tunnel- und EU-Grenzschilder sind europaweit gleich.

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
- **Polizeiwagen**: gezeichnet bei `police.police_car_offset_m()` (Animation im Gameplay-Modul). Seitlich fährt er
  eine Spur neben dem Spieler, solange er hinter oder neben ihm ist (links, wenn dort eine Spur ist, sonst rechts;
  gewählt, solange er noch außer Sicht hinter der Kamera ist), und zieht vor dem Spieler ein, sobald sein Heck frei
  ist (Haltepunkt `police.pull_over_offset_m` vor dem Spieler, `SessionRules.police_car_x`) – er fährt nie durch den
  Wagen des Spielers.

Meldungen (HUD `show_message`): Tankstelle 30/15/5 km, Tanken, vollgetankt/abgebrochen, Reserve, Tank leer,
Abschleppstrafe, Radarwarnung, Radarfeld Anfang/Ende, geblitzt, Verfolgung, entkommen, „Führerschein, bitte!“,
„Gute Fahrt!“, Grenze (Land + Name in Landessprache), City Limits, Tunnelname, LOS, ZIEL, Tutorial-Hinweise (§9a).
Audio: Motor, Wind, Sirene (mit Abstand), Regen, Rutschen, Einzeltöne (beep je Countdown-Sekunde, go, crash, flash,
fuel_start/fuel_done, finish). Pause: Baum pausiert, Ton stumm, Fokusverlust pausiert (nicht im Autopilot).
Ziel: Zeit wird eingefroren, „ZIEL!“-Meldung, Wagen rollt aus (`render.finish_decel_kmh_s`), der Spieler lenkt weiter,
Verkehr kollidiert weiter (zählt aber nicht mehr zu `collisions` der Etappe); Ergebnis nach dem Stillstand
oder spätestens `render.finish_hold_s`. Ergebnis-Wörterbuch unverändert (ARCHITECTURE.md §8).

## 9a. Tutorial (Kiel – Hamburg)

Design: „Kiel – Hamburg: alternativlose Startetappe, gleichzeitig Tutorial.“ Die Etappe trägt in den Daten
`tutorial: true` und `start_fuel_fraction: 0.35` (Start mit gut einem Drittel Tank – 95 km reichen damit nicht, der
Tankstopp gehört dazu; `StagePlan.tutorial`, `FuelSystem`). Auf dieser Etappe (oder mit `--tutorial`) erzeugt die
Sitzung einen `TutorialCoach`, der jedes Thema einmal als kurzen „Tipp: …“ (HUD-Meldung, `render.tutorial_hint_s`
= 6 s) zeigt, nacheinander mit 0,6 s Pause; dringende Themen kommen sofort, weil die Situation gerade eintritt:

| Auslöser | Hinweis (Zahlen aus der Konfiguration) |
|---|---|
| LOS (+1,2 s) | Lenken (Pfeiltasten, A/D), Gas/Bremse (Pfeil hoch/runter, W/S), Gamepad (Stick, Trigger) |
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

Die Etappenbeschreibung (`StagePlan.description`) zeigt der Etappenbildschirm (UI-Modul).

## 10. Autopilot

Hält eine Spur, wählt die Nachbarspur mit dem besten erreichbaren Tempo (nächstes Auto darin und dessen Abstand,
Hysterese, nur wenn die Spur frei ist), folgt sonst mit Sicherheitsabstand; bremst vorausschauend für Kurven
(Bremskurve über 220 m mit `safe_curve_speed`), für Radarfelder (Limit + 6 %) und für Autos im Fahrweg; verlässt
endende Spuren rechtzeitig. Tanken: entscheidet 14 km vor jeder Tankstelle (`auto`: wenn der Sprit nicht bis zur
übernächsten Tankstelle/zum Ziel reicht; `always`/`never` per `--autopilot-refuel`), fädelt in die Tankspur ein und
fährt unter 60 km/h; während des Tankens gibt er kein Gas (sonst bricht das Tanken ab).

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
| `--perf` | am Ziel Frame-Zeiten ausgeben (`PERF {...}`) |
| `--trace[=<km>]` | Fahrprotokoll alle n km (Tempo, Zieltempo, Grund, Kurve, Steigung, Tank) |
| `--tutorial` | Tutorial-Hinweise auch auf anderen Etappen |
| `--sprite-manifest=<pfad>` | weiteres Sprite-Manifest über das echte legen (`SpriteDB`, Dateipfade relativ zu ihm, `aliases` zeigen echte Sets auf andere); z. B. die Testdaten `res://tests/fixtures/sprites/manifest.json` (§8) |

`--timescale=<f>` setzt `Engine.time_scale` und die Physiktakte auf 60·f, damit jeder Schritt 1/60 s bleibt.
Setup-Schlüssel für Tests: `no_countdown`, `autopilot_speeding`, `autopilot_refuel`, `traffic_warmup`, `tutorial`.

## 12. Tests und Werkzeuge

- `tools/run_tests.sh race` – Unit-Tests: Track (Determinismus, Fenster, Spurübergänge, Tankspur, Ereignisse,
  Geometriegrenzen, Requisiten, vollständige `scenery.json`, Schilder im Tunnel an der Wand, Land/Straßentyp der
  Schilder), Projektion, Palette, GeoBatch, Autopilot-Bremskurve, Spiegeln und Vorderkante aller kantenbündigen
  Requisiten mit dem echten Manifest, Schilderstile je Land, Sitzungsregeln (Kollisionen in geskripteten Phasen,
  HUD-Tankstelle, Ausrollen in die Tankspur, Überholweg der Polizei), Tutorial-Warteschlange und -Texte;
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
- `godot --headless --path . -s res://tests/race/check_session.gd [-- --only=coll_right,tutorial]` – Szenarien in
  der echten Rennszene (≈ 30 s): Auffahrunfall genau von hinten in rechter/linker/mittlerer Spur → Seite mit mehr
  Platz bzw. links; Ausrollen mit leerem Tank in ein langsameres Auto → Kollision, Abschleppen erst nach dem
  Abschleppen gezählt; leer in die Tankspur gerollt → getankt, kein Abschleppen; Auslaufen nach dem Ziel →
  Kollision statt Durchfahren; Verfolgung bis in den Tankstopp → Polizei genau beim Tanken blockiert, HUD-Werte;
  Kiel – Hamburg zeigt alle Tutorial-Hinweise, andere Etappen keine. Ausgabe `CHECK <name> OK|FEHLER`, Exit-Code.
- `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s
  res://tests/race/check_sprite_flip.gd` – prüft mit echtem Renderer, dass Godot gespiegelte Rechtecke an Ort und
  Stelle zeichnet (Grundlage von `flipped_draw_rect`).
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
`crosswalk_every_m`.

`render`: `segment_length_m`, `draw_distance_m`, `fov_deg`, `camera_height_m`, `camera_distance_m`, `horizon_y_frac`,
`fog_start_frac`, `hill_height_scale`, `stripes` (`grass`, `road`, `dash` je Straßentyp in Segmenten),
`edge_line_m`, `lane_line_m`, `tunnel` (`wall_height_m`, `ceiling_m`, `light_every_m`, `haunch_m`, `darkness_m`,
`peek_m`), `background_parallax`, `near_m`, `lod_merge_px`, `lod_from_m`, `lod_max_segments`, `lod_detail_m`,
`headlight_range_m`, `headlight_intensity`, `background_blend_s`, `camera_follow`, `camera_lag_max_m`,
`finish_decel_kmh_s`, `finish_hold_s`, `procedural_props` (`auto` = Zapfsäulen/Shop/Zollhaus/Blitzer prozedural
zeichnen, solange das Sprite-Manifest nur Platzhalter enthält; `always`/`never`), `scripted_collision_min_kmh`
(30: darüber kollidiert der Wagen auch in geskripteten Phasen), `tutorial_hint_s` (6: Anzeigedauer eines
Tutorial-Hinweises). Fahrzeugdarstellung (§8): `vehicle_yaw_smooth_s` (0,12), `vehicle_cell_hysteresis` (0,3 Schritte),
`vehicle_yaw_max_deg` (30), `vehicle_warp` (an), `vehicle_warp_min_ratio` (0,06), `box_slice_m` (2), `box_slice_ratio` (0,12), `box_subdiv_px` (1,5),
`player_curve_lookahead_m` (10), `player_curve_gain` (1), `player_steer_deg` (3), `player_lateral_gain` (1),
`player_understeer_deg` (4), `player_view_gain` (1), `player_yaw_max_deg` (20), `player_yaw_smooth_s` (0,15),
`player_roll_deg_per_mps2` (0,22), `player_roll_max_deg` (2,5 – mehr lässt der Vertrag nicht zu),
`player_roll_smooth_s` (0,2).

`debug`: `autopilot_target_kmh`, `show_render_stats`.

## 15. API-Erweiterungen (zusätzlich zu ARCHITECTURE.md)

- `Track`: `zones`, `runout_m`, `hill_scale`, `window_size()`, `distance_to_fuel_lane(z)`, `events_for_segment(i)`,
  Konstanten `WALL_SIGN_GAP_M`, `WALL_SIGN_OVERHANG_M`; Schild-Requisiten zusätzlich `country`, `road`, im Tunnel
  `wall` (und `scale` < 1).
- `TrackSegment`: `runout`, `fuel_zone` (+ Konstanten `FUEL_*`), `cover`, `cover_front`, `country_to`.
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
  player_x, side, lane_w, pull_over_m, clear_m)`.
- `TutorialCoach`: `setup(cfg)`, `trigger(topic, args) → Anzahl`, `hold(s)`, `update(dt) → Text|""`, `pending()`,
  `hints_for(topic, args)`, `hint_s`, `gap_s`, `shown`; Themen `start, fuel_low, fuel_hud, fuel_announce, fuel_lane,
  refuel, radar, chase, unlimited, city, collision`.
- `Autopilot`: `refuel_mode`, `last_want`, `last_reason`.
