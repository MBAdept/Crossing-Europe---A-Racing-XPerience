# Renn-Modul – Strecke, Pseudo-3D-Renderer, Rennsitzung

Technische Dokumentation des Renn-Moduls (Eigentum: `scripts/race/*`, `scenes/race/*`, `data/scenery.json`,
`tests/unit/race/*`, `tests/race/*`, Konfigurationsabschnitte `road`, `render`, `debug`).
Verträge stehen in [ARCHITECTURE.md](../ARCHITECTURE.md) §5, §6, §8; hier steht, wie es funktioniert und woran man dreht.

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
| `scripts/race/palette.gd` | `Palette` | Farben nach Tageszeit, Wetter, Tunnel |
| `scripts/race/race_session.gd` | (Szene `scenes/race/race.tscn`) | Rennsitzung: Countdown, Simulation, HUD/Audio/Renderer füttern, Meldungen, Pause, Ziel |
| `scripts/race/autopilot.gd` | `Autopilot` | Testfahrer (Spur halten, überholen, bremsen, tanken, Radar beachten) |
| `data/scenery.json` | – | 22 Landschaften: Grasfarben, Hintergrund, Klima, Requisiten-Regeln |
| `tests/race/run_stage.gd` | – | ganze Etappe headless mit Autopilot fahren, Ergebnis + Frame-Zeiten |
| `tests/race/bench_render.gd` | – | Render-Benchmark an festen Streckenpositionen |
| `tests/unit/race/*` | – | Unit-Tests (Track, Projektion, Palette, Hilfsklassen) |

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
| `camera_height_m` | 2.55 | Kamerahöhe über der Straße am Fahrzeug |
| `camera_distance_m` | 7.6 | Abstand hinter der Wagenmitte |
| `horizon_y_frac` | 0.45 | Horizont bei y = 324 |
| `camera_follow`, `camera_lag_max_m` | 7 /s, 1.1 m | seitliches Nachziehen der Kamera (Wagen wandert beim Spurwechsel leicht aus der Mitte) |

Das Wagenheck steht damit bei y ≈ 668 (unten Mitte, ganz sichtbar), der Wagen ist ~250 px breit. Die Kombination
erfüllt auch den Kern-Test der Ein-Drittel-Regel (1/3 eines 1,5 m hohen Autos sichtbar bei dz ≈ 2,8 m).
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
  (gelb, Zielname) beidseitig + Stadtlimit; Entfernungsschilder („Hamburg 50 km“, blau auf der Autobahn, gelb sonst);
  Start-Portal mit Ampel (Countdown) und Ziel-Portal. Um Schilder, Portale und Bauwerke bleiben Landschaftsrequisiten weg.
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
  Landschaftswechsel, Polizeilackierung über `GameData.police_set_for(Land)`.
- **City Limits**: Ortsschild, Bordsteine (mit Kantenflächen), Gehwege, Straßenlaternen (mit Lichtkegeln nachts),
  Straßenbäume, Gebäude, Zebrastreifen, Skyline mit Fensterlichtern, Ziel-Portal + karierte Ziellinie.

## 7. Licht, Tageszeit, Wetter

`Palette.compute` interpoliert vier Schlüsselbilder (Nacht, Morgen, Tag, Abend) mit den Stunden aus `daytime`.
Nacht: dunkles Umgebungslicht, Sterne, Mond; der Boden wird pro Ecke beleuchtet (Scheinwerferkegel des Spielers,
Scheinwerfer der Autos vor ihm, Straßenlaternen, Tankstellendächer, Grenzstation), Fahrbahnmarkierungen, Schilder und
Leitpfosten reflektieren stärker; Rücklichter, Laternen, Fenster und Lampen leuchten (Ebenen `tail`, `lights`, Glow).
Regen: grauer bedeckter Himmel, nasse dunkle Fahrbahn mit Himmelsspiegelung in der Ferne, Gischt hinter Autos,
Spiegelungen der Rücklichter nachts, Regenschlieren. Schnee: grauer Himmel, weißer Boden, Schnee an den Fahrbahnrändern,
Flocken. Sichtweite kommt aus `EnvironmentModel.visibility_factor` (Nebel ab `render.fog_start_frac` der Sichtweite).

## 8. Fahrzeuge

Verkehr wählt den Winkel `l2/l1/c/r1/r2` aus der scheinbaren Gierung (Straßenrichtung am Auto minus Sichtstrahl):
Grenzen 6,5° und 18,5° (Sprites bei 12° und 25°). Spieler: `l1/c/r1` nach Lenkung, Bremslichter, Blinken über
`visible`, Wackeln neben der Fahrbahn und bei Kollisionen. Polizei: Blaulichtphasen `beacon_a/b` + blaues Leuchten.

## 9. Rennsitzung (`race_session.gd`)

Simulation in `_physics_process` (feste Schritte), Darstellung in `_process`. Ablauf je Schritt: Eingabe (Spieler oder
Autopilot) → Steuerungsanfrage (`FuelSystem` vor `PoliceSystem`) → `VehicleModel.update` → Position → Fenster →
`TrafficSystem.update` → Kollision (`find_collision` mit `RoadProjection.visible_fraction` = Ein-Drittel-Regel,
dann `space_beside` mit den Straßenrändern für die Ausweichrichtung; keine Kollisionen während eines geskripteten
Halts) → Tank → Polizei → Strafzeit → Uhr → Zonenmeldungen → Ziel.
Meldungen (HUD `show_message`): Tankstelle 30/15/5 km, Tanken, vollgetankt/abgebrochen, Reserve, Tank leer,
Abschleppstrafe, Radarwarnung, Radarfeld Anfang/Ende, geblitzt, Verfolgung, entkommen, „Führerschein, bitte!“,
„Gute Fahrt!“, Grenze (Land + Name in Landessprache), City Limits, Tunnelname, LOS, ZIEL.
Audio: Motor, Wind, Sirene (mit Abstand), Regen, Rutschen, Einzeltöne (beep je Countdown-Sekunde, go, crash, flash,
fuel_start/fuel_done, finish). Pause: Baum pausiert, Ton stumm, Fokusverlust pausiert (nicht im Autopilot).
Ziel: Zeit wird eingefroren, „ZIEL!“-Meldung, Wagen rollt aus (`render.finish_decel_kmh_s`), Ergebnis nach dem Stillstand
oder spätestens `render.finish_hold_s`. Ergebnis-Wörterbuch unverändert (ARCHITECTURE.md §8).

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

`--timescale=<f>` setzt `Engine.time_scale` und die Physiktakte auf 60·f, damit jeder Schritt 1/60 s bleibt.
Setup-Schlüssel für Tests: `no_countdown`, `autopilot_speeding`, `autopilot_refuel`, `traffic_warmup`.

## 12. Tests und Werkzeuge

- `tools/run_tests.sh race` – Unit-Tests: Track (Determinismus, Fenster, Spurübergänge, Tankspur, Ereignisse,
  Geometriegrenzen, Requisiten, vollständige `scenery.json`), Projektion, Palette, GeoBatch, Autopilot-Bremskurve.
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
zeichnen, solange das Sprite-Manifest nur Platzhalter enthält; `always`/`never`).

`debug`: `autopilot_target_kmh`, `show_render_stats`.

## 15. API-Erweiterungen (zusätzlich zu ARCHITECTURE.md)

- `Track`: `zones`, `runout_m`, `hill_scale`, `window_size()`, `distance_to_fuel_lane(z)`, `events_for_segment(i)`.
- `TrackSegment`: `runout`, `fuel_zone` (+ Konstanten `FUEL_*`), `cover`, `cover_front`, `country_to`.
- `RoadProjection`: `scale_at(dz)`, `ground_row(dz)`, `depth_at_row(y)`, `view_angle(dx, dz)`, `near` aus `render.near_m`.
- `RoadRenderer`: `perf_stats()`, `show_stats`; View-Schlüssel zusätzlich `camera_in_tunnel`, `countdown`, `chase01`,
  `radar_flash01`, je Auto `length`, `speed`, `heavy`. `palette` ist immer die Außenpalette, die Tunnelvariante bildet
  der Renderer selbst. `bg_offset` ist der Kurswinkel in Radiant.
- `Palette`: Schlüssel `sky_mid`, `glow`, `cloud`, `cloud_dark`, `moon_visible`, `moon_pos`, `overcast`, `tunnel`;
  `tunnel(p)`, `luminance(c)`, `lit(p, extra)`.
- Rennsitzung: `perf_stats()`, `road_info(z)`, `last_input`, `traffic_enabled`, `cam_x`, Setup-Schlüssel siehe §11.
- `Autopilot`: `refuel_mode`, `last_want`, `last_reason`.
