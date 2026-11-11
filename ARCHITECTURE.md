# Architektur – Crossing Europe

Technischer Bauplan zum [Design-Dokument](docs/Design-Dokument.md). Er beschreibt Module, Schnittstellen,
Datenformate und Konventionen. **Öffentliche APIs in diesem Dokument sind Verträge**: erweitern ist erlaubt,
Signaturen ändern oder entfernen nicht.

- Engine: **Godot 4.7.2**, GDScript, Renderer *GL Compatibility* (läuft auch auf schwacher Hardware).
- Zwei Grafikmodi in einem Build (seit v0.8.0, §15): **„Arcade“** = der Pseudo-3D-Renderer wie bis v0.7.0,
  bildgleich eingefroren; **„Modern“** = ein zweiter, echter 3D-Renderer. Simulation, Spielstände und Bestenlisten
  sind in beiden Modi dieselben. Ohne gespeicherte Wahl ist das Spiel Arcade.
- Auflösung: 1280×720 logisch, Stretch-Modus `canvas_items`; Seitenverhältnis `keep` im Rennen, `expand` in den
  Menüs (der Menühintergrund füllt z. B. 16:10 auf dem Steam Deck, siehe [docs/steam-deck.md](docs/steam-deck.md));
  im Modus „Modern“ füllt auch das Rennen das Fenster (`expand`).
- Zielplattformen: Linux x86_64 und Windows x86_64 (10/11), jeweils als einzelne ausführbare Datei (PCK
  eingebettet); Windows-Details in [docs/windows.md](docs/windows.md).

## 1. Verzeichnisse und Modul-Eigentümer

| Modul | Dateien (Eigentum) |
|---|---|
| Kern (Gerüst) | `project.godot`, `export_presets.cfg`, `scripts/core/*`, `tests/run_tests.gd`, `tests/test_case.gd`, `tests/check_scripts.gd`, `tools/*.sh` |
| Renn-Modul | `scripts/race/*`, `scenes/race/*`, `data/scenery.json`, `tests/unit/race/*` |
| Gameplay | `scripts/gameplay/*`, `tests/unit/gameplay/*`, `tests/sim/*` |
| Daten | `scripts/data/*`, `data/network.json`, `data/countries.json`, `data/map/*`, `tools/map/*`, `tests/unit/data/*` |
| UI und Audio | `scripts/ui/*`, `scripts/audio/*`, `scenes/main.tscn`, `scenes/ui/*`, `assets/fonts/*`, `assets/ui/*`, `tests/unit/ui/*` |
| Sprites | `tools/blender/*`, `assets/sprites/*` (inkl. `manifest.json`) |
| Grafikmodi (v0.8.0, §15) | Kern: `scripts/core/{gfx,gfx_self_test}.gd`, `scripts/race/race_renderers.gd`, `tests/unit/core/*`, `tests/race3d/check_seam.gd`, `tests/golden/*`, `tools/{golden,run_render_checks}.sh`, `tools/pck_report.py` · Renderer „Modern“: `scripts/race3d/*`, `assets/shaders/modern/*`, `tests/unit/race3d/*`, `tests/race3d/*` · Modelle: `assets/models/*`, `tools/blender/ce3d/*`, `tools/models/*` · Klang „Modern“: `scripts/audio/modern/*`, `assets/audio/modern/*`, `tools/audio/modern/*` |

Seit v0.8.0 **eingefroren** (der Modus „Arcade“ muss bildgleich mit v0.7.0 bleiben, `tools/golden.sh`):
`scripts/race/{road_renderer,backdrop,geo_batch,sign_painter,box_vehicle,vehicle_pose,palette,projection,track,
track_segment,session_rules,autopilot,tutorial_coach}.gd`, `scripts/gameplay/*`, `scripts/data/*`,
`scripts/audio/{engine_audio,engine_bank,engine_gearbox,room_audio,sfx_synth,traffic_audio}.gd`, `assets/sprites/*`,
`assets/audio/{engines,traffic,music}/*`, `tools/audio/{engine,traffic,music}_synth.py`, `data/*`. Neuer Code darf
sie benutzen (instanziieren, statische Helfer aufrufen, in einer neuen Datei ableiten), aber nicht ändern.

Abschnitte der zentralen Konfiguration `config/game_config.json`:
`time, daytime, vehicles, driving, collision, traffic, fuel, radar, police, city_limits, weather` → Gameplay ·
`road, render, debug` → Renn-Modul · `hud, audio, attract` → UI · `leaderboard, routing, stages` → Daten ·
`input` (Stick-Lenkkurve, Wiederholung gehaltener Gamepad-Richtungen, Vibration) → Kern ·
`graphics` (Grafikmodi, Qualität und Renderer „Modern“, §15) → Kern und Renderer „Modern“; Arcade liest nichts daraus.

## 2. Konventionen

**Einheiten und Zeitraffer** (`scripts/core/units.gd`):

- Geschwindigkeit in **km/h**.
- **km** = Kilometerzähler (Etappenkilometer). Alle Positionen in den Daten sind km.
- **m / z** = sichtbare Meter der Straße. `m = km * 1000 / time_scale` (`time.time_scale` = 10 seit v0.7.0:
  1 km = 100 m; bis v0.6.0 Faktor 12: 1 km = 83,3 m). Der Renderer scrollt mit Tachotempo, Kilometerzähler und Uhr
  laufen 10-mal schneller. Kurven, Hügel, Schilder und Sichtweiten sind in sichtbaren Metern festgelegt – ein anderer
  Faktor erzeugt jede Straße neu (andere Kurven, Kuppen, Schilder).
- **Spielzeit** = echte Sekunden; **Weltzeit** = Minuten (absolut, Tag 0 00:00 = 0), läuft 10-mal schneller.
  100 km bei 100 km/h = 360 s = 6:00. Durchschnittstempo = `Units.avg_speed_kmh(km, s, 10)`.
- Gespeicherte Zeiten (Bestenlisten, Rennstand) sind echte Sekunden bei einem Faktor und tragen ihn mit
  (`time_scale`); ändert er sich, werden sie beim Laden umgerechnet – gleicher Schnitt, Zeit × alter/neuer Faktor
  (§10).
- Lateral **x** in Metern, 0 = Straßenmitte, + = rechts. Spur 0 = ganz links.

**GDScript-Stil**:

- Statisch typisiert. Achtung: Godot 4.7 behandelt `var x := <Variant>` als **Fehler**. Für Werte aus Dictionaries,
  untypisierten Arrays oder generischen Funktionen (`abs`, `floor`, `min`, `max`, `clamp`, `lerp`) explizit typisieren
  (`var x: float = d["k"]`) oder typisierte Varianten nutzen (`absf`, `floorf`, `minf`, `maxf`, `clampf`, `lerpf`, `mini` …).
- Keine eingebauten Klassennamen als `class_name` (z. B. *nicht* `Projection`, `Environment`, `Path`).
  Statische Methoden nicht wie Methoden von `Resource`/`Object` benennen (`get_path`, `get_name`, …).
- Reine Spiellogik (Gameplay, Track, StagePlan) ist `RefCounted`, ohne Autoload-Zugriff: die Konfiguration kommt als
  Dictionary herein (`Config.data` bzw. in Tests `ConfigLoader.load_merged()`).
- Code-Kommentare englisch, **Texte für Spieler deutsch** und immer über `tr("Deutscher Text")` (Gettext-Stil:
  der deutsche Text ist der Schlüssel – spätere Übersetzungen kommen als `.po`-Dateien dazu).
- UI wird bevorzugt im Code aufgebaut; `.tscn`-Dateien bleiben minimal.

## 3. Autoloads

| Name | Datei | Aufgabe |
|---|---|---|
| `Config` | `scripts/core/config.gd` | zentrale Konfiguration (`data`, `value("a.b")`, `f()`, `i()`, `section()`) |
| `InputSetup` | `scripts/core/input_setup.gd` | registriert Aktionen `steer_left/right`, `accelerate`, `brake`, `pause` (Tastatur + Gamepad, alle Geräte; den linken Stick liest das Rennen direkt am zuletzt benutzten Pad, `InputMode.device`) und Gamepad A/B/LB/RB für `ui_accept/ui_cancel/ui_page_up/ui_page_down`; meldet das aktive Eingabegerät an `InputMode` (Tastenhinweise, Gerät für Lenkung und Vibration); wiederholt gehaltene Gamepad-Richtungen in Menüs (`PadRepeat`); meldet ein getrenntes Gamepad mit „war in Benutzung“ (`pad_disconnected`, das Rennen pausiert dann) |
| `Settings` | `scripts/core/settings.gd` | Nutzer-Einstellungen `user://settings.json` (`settings_version` 3 seit v0.8.0; Lautstärke, Vollbild – nur gespeichert, wenn gewählt; aus Dateien ohne Version zählt nur „An“, ab Version 2 der gespeicherte Wert –, Vibration, Name, Sprache, Bestenlisten-Filter; seit v0.8.0 Grafikmodus, Klangprofil, Qualität von „Modern“, Musik im Rennen – §15) |
| `GameData` | `scripts/data/game_data.gd` | Netz, Länder, Landschaften, Karte; liefert `StagePlan`s und Routenoptionen |
| `SpriteDB` | `scripts/core/sprite_db.gd` | Sprite-Manifest, Texturen, Zellen je Winkel/Ebene |
| `Leaderboards` | `scripts/data/leaderboards.gd` | Bestenlisten `user://leaderboards.json` |
| `SaveGame` | `scripts/data/save_game.gd` | Rennfortschritt `user://savegame.json` (nach jeder Etappe) |
| `AudioManager` | `scripts/audio/audio_manager.gd` | prozeduraler Sound |
| `GameFlow` | `scripts/ui/game_flow.gd` | Bildschirmablauf |

`ConfigLoader` (statisch) lädt `res://config/game_config.json` und überlagert optional `game_config.json` **neben der
ausführbaren Datei** und `user://game_config.json` – so lassen sich Werte ohne Neubau anpassen.

## 4. Daten

### 4.1 `data/network.json`

```json
{
  "cities":  [ { "id": "kiel", "name": "Kiel", "country": "DE", "latlon": [54.32, 10.12], "map_pos": [x, y] } ],
  "stages":  [ {
      "id": "kiel_hamburg", "from": "kiel", "to": "hamburg", "length_km": 95,
      "sections": [ { "length_km": 95, "road": "autobahn|landstrasse", "curviness": 0-3, "hills": 0-3,
                      "scenery": "<scenery-id>", "country": "DE", "speed_limit": null|<km/h>, "traffic": 1.0 } ],
      "fuel_stations_km": [40],
      "radars":  [ { "km": 30, "limit": 120 } ],
      "tunnels": [ { "km": 50, "length_km": 2.5, "name": "Elbtunnel" } ],
      "borders": [ { "km": 85, "to": "NL" } ],
      "weather": "optional: normal|rain|snow (für weather.race_mode = fixed)",
      "seed": 1234, "dev": false } ],
  "ferries": [ { "id": "riga_rostock", "from": "riga", "to": "rostock", "name": "Fähre Riga – Rostock",
                 "fixed_time_s": 240, "world_hours": 24 } ],
  "races":   [ { "id": "kiel_nuernberg", "name": "Kiel – Nürnberg", "start": "kiel", "finish": "nuernberg",
                 "waypoints": [], "description": "…" } ]
}
```

- `speed_limit`: `null` = ohne Limit, fehlt = Standardlimit des Landes für den Straßentyp (`countries.json`).
- `traffic`: Dichtefaktor des Abschnitts (z. B. Ruhrgebiet 1.5).
- Etappen sind **in beide Richtungen** fahrbar; in Gegenrichtung werden Abschnitte umgedreht und Positionen gespiegelt.
- Fehlt `fuel_stations_km`, werden Tankstellen automatisch alle 60–90 km gesetzt (deterministisch).
  Seit v0.7.0 ist ein Eintrag eine Zahl (beide Richtungen) oder `{"km": 12, "dir": "fwd"|"rev"}` (nur in dieser
  Fahrtrichtung, km ab `from` wie beim Radar); die erste Tankstelle jeder Richtung liegt
  `fuel.first_station_min_km`–`first_station_max_km` (5–20 km) nach dem Start (docs/daten.md).
- Grenzen ergeben sich zusätzlich automatisch aus Länderwechseln der Abschnitte.
- `dev: true` blendet Städte/Etappen/Rennen in Menüs aus (z. B. `dev_testetappe` mit allen Elementen).
- Szenerie-IDs (Inhalt in `data/scenery.json`): `north_plain, heath, forest_hills, rhine_main, industrial, polder,
  ardennes, farmland_fr, loire, pyrenees, meseta, mediterranean, alps, lombardy, karst, balkan_hills,
  pannonian_plain, bohemian, east_plain, baltic_forest, coast, city` (`city` gilt automatisch in den City Limits).
  Individuelle Städte ([docs/staedte.md](docs/staedte.md)): `data/cities.json` legt je Stadt Baustil, Wahrzeichen,
  Skyline und Brücken fest; in den City Limits gelten dann `city_<stil>_outskirts` / `city_<stil>_center` aus
  `data/scenery.json` (ohne Stil weiterhin `city`).

### 4.2 `data/countries.json`

`{ "countries": { "DE": { "name", "name_local", "limits": {"autobahn": null|int, "landstrasse": int, "city": int},
"climate": "north|continental|alpine|mediterranean|default", "police": "police/de", "colors": [...] } } }`

### 4.3 `StagePlan` (`scripts/data/stage_plan.gd`)

Eine Etappe aufgelöst für eine Fahrtrichtung (`GameData.get_stage_plan(stage_id, from_city_id)`). Felder:
`stage_id, reversed, board_key ("stage:<id>:fwd|rev"), from_id, to_id, from_name, to_name, display_name,
length_km, sections[{start_km,end_km,length_km,road,curviness,hills,scenery,country,speed_limit(0=frei),traffic}],
fuel_stations_km[], fuel_lanes[{station_km,start_km,end_km}], radars[{km,end_km,limit,warn_km}],
tunnels[{start_km,end_km,name}], borders[{km,from,to,name,name_local}], city_limits_km, city_speed_limit,
climate, countries_in_order, weather_hint, seed, warnings[]`.
Abfragen: `section_at, country_at, scenery_at, is_city, road_at, speed_limit_at, traffic_factor_at, tunnel_at,
in_tunnel, fuel_lane_at, next_station_km, next_radar, radar_zone_at, summary()`.
Städte (`StagePlan.build(…, city_db)`, `CityData`): Felder `city_style, city_scenery_outskirts, city_scenery_center,
city_center_km, city_background, landmarks[], bridges[], skyline[]`, Abfragen `scenery_for(km, scenery), in_city_center,
bridge_at, on_bridge` – Formate in [docs/staedte.md](docs/staedte.md) §6–§7.
Regeln werden beim Bauen erzwungen (Verstöße → `warnings`): letzte Tankstelle ≥ 25 km vor dem Ziel und nie in den
City Limits; kein Radarfeld in den 30 km vor den City Limits; Tankspur = die letzten 1–2 km vor der Tankstelle.
Tankstellen der anderen Fahrtrichtung (`dir`) werden vorher still übersprungen; die erste Tankstelle nach 5–20 km
prüft `RoadNetwork.validate()` (seit v0.7.0).

### 4.4 `GameData` (Autoload)

`cities, stages, ferries, races, race_order, countries, scenery, map_data, warnings` ·
`get_city(id)`, `city_name(id)`, `country_name(code)`, `police_set_for(code)`, `get_stage_plan(stage_id, from_city)`,
`stage_board_key(stage_id, from_city)`, `race_board_key(race_id)` (`"race:<id>"`), `connections_from(city)`
(`[{kind: "stage"|"ferry", id, from, to, length_km}]`), `next_options(race_id, current_city, waypoint_index, visited)`
(erlaubte nächste Etappen Richtung nächstem Pflichtziel; Umweg ≤ `routing.detour_tolerance`),
`visible_race_ids()`, `visible_stage_ids()`, `validate()`; Städte: `city_db` (`data/cities.json`), `city_style(id)`,
`validate_cities(sprite_sets)`.

### 4.5 Karte `data/map/europe_map.json`

`{ "size": [w, h], "projection": "…", "countries": [ { "code": "DE", "polygons": [[[x,y], …], …] } ] }`
– Koordinaten im selben Raum wie `cities[].map_pos`. Quelle: Natural Earth (gemeinfrei) über npm `world-atlas`.

### 4.6 Ergänzungen nach Review und Integration

- Etappe: `description`, `roads`, `tutorial` (Tutorial-Hinweise in der Rennsitzung, „So geht's“ im Etappenbildschirm),
  `start_fuel_fraction` (Tankfüllung beim Start, Kiel – Hamburg 0,35); Radar optional `dir: "fwd"|"rev"`.
- Rennen: `avoid_stages` (Etappen, die die Routensuche dieses Rennens meidet), `tour: true` (Königsrennen: lange
  Wege zwischen zwei Pflichtstationen werden in Etappen von 200–400 km geteilt, `stages.split_length_km`).
- Land: `colors` mit optionalem Flaggen-Layout vorn (`v`, `h121`, `h212`, `ch`, `cz`), `signs` = Farben für
  Autobahn-Wegweiser und Ortsschild (`motorway`, `town_bg`, `town_fg`, `town_border`).
- Jede Grenze wechselt die Landschaft und liegt mindestens `stages.border_min_before_city_km` vor den City Limits.
- `GameData.next_options()` liefert je Option zusätzlich `continuation` (Folge-Etappen bis zum nächsten Ziel),
  `route_km`, `route_cities`, `route_summary` (Summen wie `StagePlan.summary()` über die ganze Route) und
  `via_distinct`; Hilfen `legs_summary(legs)`, `target_segments()`, `race_routes()`, `race_choices()`,
  `race_summary()`, `race_targets()`, `next_target()`, `advance_waypoint_index()`, `is_race_finished()`.

## 5. Strecke (`Track`, `scripts/race/track.gd`)

Erzeugt Segmente (`TrackSegment`, `render.segment_length_m` sichtbare Meter) vor der Kamera und verwirft sie dahinter.
Kurven und Hügel: deterministischer Generator aus Kurvigkeit/Hügeln (0–3) der Abschnitte. Alles mit km-Position
(Spuren, Tankspur, Tunnel, City Limits, Schilder, Tankstellen, Radarpfosten, Grenzposten) ist deterministisch.
Kurvenwert 1.0 = Radius `road.curve_radius_at_1_m`.

Schnittstelle (auch für `TrafficSystem`, Duck-Typing): `length_z, length_km, seg_len, lane_w, shoulder_w,
km_to_z(km), z_to_km(z), segment_index_at(z), get_segment(i), segment_at(z), update_window(camera_z, ahead_m),
lanes_at(z) (float), lane_count_at(z) (int), lane_center_x(z, lane), road_edges_at(z) → Vector2(links, rechts inkl.
Tankspur), main_right_edge(z), fuel_lane_factor(z), fuel_lane_at(z), fuel_lane_x(z), road_type_at(z), is_city_at(z),
is_tunnel_at(z), traffic_factor_at(z), country_at(z), speed_limit_at(z), curve_at(z), height_at(z), grade_at(z)`.

Segment-Requisiten (`TrackSegment.sprites`): `{kind: "prop"|"sign", set, x, scale, side, sign, text, value}`.
Schilder werden prozedural gezeichnet (Text!): `fuel, limit, unlimited, radar, town, distance, border, tunnel, finish`.

## 6. Renderer (`RoadRenderer`, `scripts/race/road_renderer.gd`)

`setup(track, projection, cfg, scenery_db)`, pro Frame `render(view)`. Zeichnet hinten → vorn (Maleralgorithmus),
Straßengeometrie gebündelt als Dreiecks-Array. `RoadProjection` (`scripts/race/projection.gd`) enthält die Kameramathematik
und `visible_fraction(dz, height)` für die Ein-Drittel-Regel.

View-Dictionary: `camera_z, camera_x, camera_y (Welt), visibility_m, palette (Palette.compute), weather, time,
speed, cars[{kind:"car", id, set, z (Hinterkante), x, tail 0..1, brake 0..1, beacon "a"|"b"|"", angle?}],
player{… , player: true, steer, lat_speed, push_speed, understeer, width, visible}, bg_offset, scenery, shake (Vector2)`.
`id` je Fahrzeug (Polizei −2) für die Glättung des Darstellungswinkels; `angle` ist optional und wird von der
Sitzung nicht mehr gesendet – der Renderer berechnet den Winkel selbst (Fahrzeugdarstellung v2:
`VehiclePose` für Pkw/Polizei/Spieler, `BoxVehicle` für Lkw/Busse; Vertrag in
[docs/fahrzeug-darstellung.md](docs/fahrzeug-darstellung.md), Umsetzung in [docs/renn-modul.md](docs/renn-modul.md) §8).
Seit v0.5.0 optional je Verkehrsauto `blink` (−1 links, +1 rechts, 0 aus) und `blink_t` (Sekunden seit dem
Einschalten): der Renderer zeichnet den Blinker (renn-modul.md §8 „Blinker des Verkehrs“).
Seit v0.8.0 zusätzlich `hour` (Weltzeit, float), `dt` (Sekunden dieses Bildes) und `player.type` (Fahrzeugtyp-ID):
der Arcade-Renderer ignoriert sie, der Renderer des Modus „Modern“ liest sie. `RoadRenderer` ist seit v0.8.0
eingefroren; die Rennsitzung erzeugt ihren Renderer über `RaceRenderers.create(mode)` (§15.4). Kein Renderer darf
einen Schlüssel verlangen, den die Sitzung im anderen Modus nicht sendet.

## 7. Gameplay (`scripts/gameplay/*`, reine Logik)

| Klasse | Kern-API |
|---|---|
| `VehicleModel` | `setup(cfg, vehicle_id)`, `resolve_spec()` (statisch), `update(dt, input{steer,throttle,brake}, road{curve,grade,left_edge,right_edge,shoulder_m,guardrail,grip}, env{vmax_factor})`, `start_crash(other_x, space_left, space_right)`, `auto_control(target_kmh, rate_kmh_s, steer_x=NAN)`, `release_auto()`, `is_controllable()`, `safe_curve_speed(curve, grip)`, `max_speed(grade, factor)`; Felder `speed, x, state (DRIVING/CRASH/AUTO), invulnerable, blink_visible, steer_visual, braking, understeer, off_road, vmax_effective, length_m, width_m, spec`; Signale `crash_started(dir)`, `crash_finished` |
| `TrafficSystem` | `setup(cfg, track, car_set_ids, heavy_set_ids, seed)`, `update(dt, player{z,x,speed}, ctx{hour,chase,camera_z})`, `find_collision(player{z,x,length,width}, camera_z, visible_fraction: Callable) → Car`, `space_beside(z, x, half_len, left, right) → Vector2`, `density_factor(hour)`, `speed_factor(hour)`; `cars: Array[Car]` mit `z, x, lane, speed, cruise_speed, set_id, length, width, height, heavy, braking, in_fuel_lane` |
| `FuelSystem` | `setup(cfg, vehicle_spec, plan, start_fuel_l = -1)` (seit v0.7.0: übernommener Tank im Rennen), `update(dt, pos_km, delta_km, speed, in_fuel_lane, throttle)`, `control_request()`, `take_penalty()`, `consumption_per_100km(v)`, `base_consumption(cfg, v)` (statisch), `range_km(v)`, `distance_to_next_station(km)`; seit v0.7.0 `litres_for(km, v)`, statisch `start_fill_fraction(cfg, plan)`, `consumption_for(cfg, spec, v)`, `start_check(cfg, spec, plan, litres) → {first_km, lane_km, need_l, need_full_l, max_kmh, state: ok/tight/tow}`, Feld `announce_start`; Felder `tank_l, fuel_l, state (NORMAL/REFUELING/TOWING), refuel_progress, refuel_time_left, liters_added`; Signale `announced(km_before, station_km)`, `refuel_started`, `refuel_finished(liters, aborted)`, `ran_dry`, `tow_finished(penalty_s)` |
| `PoliceSystem` | `setup(cfg, plan)`, `update(dt, pos_km, speed)`, `chase_active()`, `traffic_factor()`, `control_request()`, `police_car_offset_m()`; Felder `state (IDLE/CHASE/STOPPING/STOPPED), chase_time, gap_m, escape_progress, avg_speed, stop_time_left, active_radar`; Signale `radar_warning(radar)`, `radar_zone(radar, entered)`, `flashed(radar, speed)`, `chase_started`, `escaped`, `caught`, `released` |
| `WorldClock` | `setup(cfg, start_world_minutes)`, `advance(real_dt)`, `hour()`, `day_index()`, `text()`, `daytime_category(hour, cfg)` (statisch: night/dawn/day/dusk) |
| `EnvironmentModel` | `setup(cfg)`, `night_amount(hour)`, `is_night(hour)`, `vmax_factor(hour, weather)`, `grip(weather)`, `visibility_factor(hour, weather, in_tunnel)`, `pick_weather(seed, climate)`, `next_stage_start(end_min, cfg)` (statisch) |

**Steuerungsanfragen**: `control_request()` liefert `{}` oder `{target_kmh, rate_kmh_s, steer_x?}`. Die Rennsitzung
übergibt die Anfrage an `VehicleModel.auto_control()` (Tanken vor Polizei) und gibt die Kontrolle mit `release_auto()` zurück.

Ergänzungen: `TrafficSystem.space_beside(…, exclude)` (getroffenes Auto zählt nicht; Gleichstand → links),
`set_dimensions(SpriteDB.sets)`; `PoliceSystem.set_blocked(bool)` (Polizei-Stopp wartet, solange getankt wird),
Signal `pull_over` (Polizei überholt und stoppt den Wagen; `caught` erst im Stand), `siren_level()`, `overtaking()`;
`FuelSystem` Signale `tow_started`, `reserve_reached`, `can_abort_refuel()`, `holds_car()`; `VehicleModel`
Steigungsabzug erst ab `driving.grade_free_percent`. Details: docs/gameplay.md.
v0.5.0 (Schwierigkeit, gameplay.md „Verkehr als Hindernis“, „Wetter“): `TrafficSystem.update` liest im `ctx` zusätzlich
`weather` (Tempo, Abstände und Bremsen des Verkehrs) und `brake_mps2` (Vollbremsung des Spielers mit der Haftung des
Wetters, auch im Tunnel – Untergrenze fürs Einscheren vor ihm), neu `cruise_speed_for(road, cls, frac, limit)`,
`slowest_speed_kmh(road, limit)`, `set_weather(w)`, `vehicle_class(car)`, `cut_in_floor_m(rel_mps, lead_s)`, Felder
`weather, player_brake_mps2, cut_ins, last_cut_in`; `Car` mit `bus, signal_dir, signal_lane, signal_t,
signal_age, signal_wait, signal_mandatory, elephant_t, elephant_cool`. `VehicleModel`: `curve_grip(g)`,
`brake_decel_mps2(g)`, `traction_mps2(g)`, `steer_response_s(g)`, `steer_speed_mps(g)`, `traction_crossover(vtop,
trac)`, `accelerate(v, vtop, t, trac_kmh_s = INF)` – die Haftung `road.grip` wirkt auf Kurvengrenze, Bremsen, Traktion
und Lenken. `PoliceSystem.curve_speed_mps` nutzt dieselbe Kurvenhaftung. `EnvironmentModel.night_visibility_factor(w)`:
`weather.night_visibility_factor` ist eine Zahl oder eine Zahl je Wetter (Schnee nachts 338 m Sicht); `race_weather`
gibt der Tutorial-Etappe `weather.tutorial_weather` (trocken).

## 8. Rennsitzung (`scripts/race/race_session.gd`, Szene `scenes/race/race.tscn`)

`setup` (vor dem Einhängen gesetzt; leer = Kommandozeile): `{mode: "race"|"single", race_id, stage_id, from_city,
vehicle, start_world_minutes, weather, start_km?, autopilot?, seed, start_fuel_l?, last_stage?}` – seit v0.7.0 im
Rennen `start_fuel_l` (Liter aus der letzten Etappe, −1 = eigene Startfüllung der Etappe) und `last_stage` (die
Etappe beendet das Rennen); seit v0.8.0 optional `gfx` (`"arcade"|"modern"`: Grafikmodus dieser Etappe für
Attract-Demos, Leistungstest und Tests – fehlt er, gilt `Settings.effective_graphics()`, §15).
Signale: `stage_finished(result)`, `stage_aborted(reason)`, `restart_requested`; seit v0.8.0 `stage_live` – die
Etappe beginnt zu laufen (vor dem ersten Simulationsschritt: in „Arcade“ sofort, in „Modern“ nach der Vorbereitung
des Renderers; `is_live()` fragt dasselbe ab). Wer Zeit ab dem Start der Etappe misst (Attract-Demo, Leistungstest),
zählt ab diesem Signal.

**Ergebnis** (`result`): `board_key, stage_id, from_city, to_city, stage_name, time_s (inkl. Strafen), penalty_s,
avg_speed_kmh, distance_km, vehicle, weather, start_world_minutes, end_world_minutes, start_hour, daytime,
collisions, refuels, liters_refueled, radar_flashes, police_stops, police_escapes, tow_events, aborted`; seit v0.7.0
`fuel_start_l` (Tank beim Start, vor einem Abschleppen), `fuel_end_l` (Tank an der Ziellinie), `tank_l`,
`start_towed` (Abschleppdienst vor dem Start: der übernommene Tank reichte nicht einmal mit 60 km/h bis zur ersten
Tankspur – 90 s Strafe, halber Tank, zählt in `tow_events`). Im Rennen wird `fuel_end_l` zu `RaceState.fuel_l`
(Rennstand-Feld `fuel_l`, Legs mit `fuel_start_l`/`fuel_end_l`) und damit zum `start_fuel_l` der nächsten Etappe.
Seit v0.8.0 `gfx` (Grafikmodus, in dem die Etappe gezeichnet wurde: `"arcade"|"modern"` – ein verstecktes Feld für
spätere Auswertung, nie angezeigt, nie ein Filter; Bestenlisten und Spielstände sind für beide Modi dieselben) und,
nur nach einem Rückfall von „Modern“ auf „Arcade“, `gfx_fallback` (der Grund, §15.5).

## 9. HUD (`Hud`, `scripts/ui/hud.gd`)

`setup_stage(plan, cfg)`, `update_state(state)` (jeden Frame), `show_message(text, kind="info"|"warn"|"alert", dauer)`,
`flash(color, dauer)`. **HUD-Zustand**: `speed_kmh, vmax_kmh, stage_km, stage_length_km, remaining_km, clock_text,
hour, stage_time_s, penalty_s, record_time_s (-1 = keiner), record_name, fuel_l, tank_l, range_km, next_station_km
(-1 = keine), speed_limit (0 = frei), radar_warning{distance_km, limit, in_zone} oder {}, police_state
("none"|"chase"|"stopping"|"stopped"), police_gap_m, escape01, refuel{active, progress01, liters, time_left_s} oder {},
tow{active} oder {}, weather, country, city_limits, in_tunnel, radar_flash01, countdown (-1 = keiner), stage_name,
finished, understeer, collision`.
`PauseMenu` (`scripts/ui/pause_menu.gd`): `open()`, `close()`, Signale `resume_requested`, `restart_requested`, `quit_requested`.

## 10. Ablauf (`GameFlow`)

`boot()` (vom Hauptszenen-Skript), `start_stage(setup)`. Bildschirme: Titel/Hauptmenü (Rennen, Fortsetzen, Einzelne
Etappe, Bestenlisten, Optionen, Beenden) → Rennen wählen → Fahrzeug wählen → Startuhrzeit → [Routenwahl] →
Etappenbildschirm (Karte, Wetter, Rekord-Laufschrift, Top 10) → Rennen → Ergebnis + Namenseingabe → nächste Etappe
(Start = Ende + `time.stage_pause_hours` = 8 h Weltzeit seit v0.7.0, vorher 12 h; Pause zählt nicht) / Fähre (Szene,
feste Zeit) → Rennergebnis + Rennbestenliste.
Nach jeder Etappe `SaveGame.save_race(state)`. Nach 60 s ohne Eingabe im Titel zeigt der Attract-Modus eine 30-s-Demo
in der echten Rennszene (Autopilot, Titelmusik, Effekte stumm, nichts wird gespeichert; docs/ui.md „Attract-Modus“).

**Rennstand** (`SaveGame`): `{race_id, vehicle, start_hour, current_city, waypoint_index, legs[{kind, id, from, to,
time_s, avg_kmh, weather, start_world_minutes, end_world_minutes, fuel_start_l, fuel_end_l}], total_time_s,
world_minutes, route[], seed, fuel_l, time_scale, legacy_legs}` (`RaceState.VERSION` 2, die drei Felder seit v0.7.0;
`legacy_legs` = Etappen eines Spielstands aus v0.6.0, das Rennen kommt nicht in die Rennliste). `fuel_l` = Tank
für die nächste Etappe (Tank im Ziel der letzten, über die Fähre unverändert; fehlt er, −1: die nächste Etappe startet
einmal voll). `time_scale` = Faktor der Zeiten; fehlt er (bis v0.6.0: Faktor 12), rechnet
`RaceState.from_dict(d, race, time_scale)` beim Fortsetzen um: Etappenzeiten und Strafen × alter/neuer Faktor (gleicher
Schnitt), Fähren fest, `world_minutes` bleibt (der nächste Start war schon angezeigt); das offene Etappenergebnis
(`pending_result`) ebenso (`GameFlow.restore_race`).

**Bestenlisten** (`Leaderboards`): `top(key, vehicle_filter="", count=10)`, `record(key, filter)`,
`would_rank(key, time_s, filter) → 1..10 | 0`, `submit(key, entry) → Rang`. Eintrag: `{name, time_s, avg_kmh,
vehicle, weather, start_hour, daytime, date, route?, ts}` (`ts` = Faktor der Zeit, seit v0.7.0). Datei
`{"version": 3, "time_scale": 10, "boards": {…}}`; Version 2 (ohne Faktor = 12) wird beim ersten Laden umgerechnet:
Etappeneinträge × 12/10 (gleicher Schnitt, neue Starteinträge), Renneinträge ohne `ts` archiviert, Sicherung
`leaderboards.json.v06` (docs/daten.md).

## 11. Audio (`AudioManager`)

`set_engine(speed_kmh, throttle, vmax_kmh, active)`, `set_wind(speed)`, `set_siren(on, distance01)`, `set_rain(x)`,
`set_skid(x)`, `play(name)` mit `crash, flash, go, beep, finish, fuel_start, fuel_done, ui_move, ui_ok, ui_back`, `stop_all()`.
Motor (Motorklang v2, [docs/motorsound.md](docs/motorsound.md)): `set_vehicle(id)` (Rennsitzung beim Aufbau: Zyklusbank
des Autos, ohne Bank der bisherige Klang), `engine_state()` → `{rpm, gear (0 = neutral), load, boost}`.
Verkehrsgeräusche und Raumklang ([docs/verkehrsgeraeusche.md](docs/verkehrsgeraeusche.md)): `set_traffic(vehicles,
listener)` (Rennsitzung jedes Frame: die Fahrzeugliste des Renderers `[{id, set, z (Heck), x, length, speed (km/h),
heavy?}]`, Polizei mit `id` −2, und die Verfolgerkamera `{z, x, speed}`; nahe Fahrzeuge klingen an ihrer Position, das
Martinshorn an der Polizei; ohne Aufruf, in der Pause und nach `stop_all()` blendet alles aus),
`set_environment({"tunnel": bool})` (Kamera im Tunnel: Tunnelhall blendet ein). `set_siren(on, distance01)` schaltet
das Horn weiter ein und aus; ohne Polizei in der Fahrzeugliste spielt es wie bisher mittig. Weitere Ergänzungen (u. a.
`preview_engine(id)` für die Fahrzeugwahl, `traffic_state()`, `traffic_perf()`): docs/ui.md „Audio“.

**Klang-Hooks der Rennsitzung** (v0.8.0, für das Klangprofil „Modern“ – das Profil ist unabhängig vom Grafikmodus,
`Settings.sound()`, §15.1): Die Sitzung sendet sie in beiden Grafikmodi und beiden Klangprofilen, zusätzlich zu den
unveränderten Aufrufen oben, und nur, wenn der `AudioManager` die Methode hat (`has_method`; das Profil „Arcade“
ignoriert sie):
- `set_track(track, plan)` nach dem Aufbau der Strecke, `set_track(null, null)` beim Verlassen der Szene;
- `set_vehicle_state(state)` in jedem Bild einer laufenden Etappe: `z`, `x` (Wagenmitte, m), `speed` (km/h),
  `throttle`, `brake` (0..1), `steer` (−1..1), `understeer` (0..1), `lat_speed` (m/s), `off_road` (0 Fahrbahn,
  1 Bankett, 2 Grenze), `rail_contact`, `road_left`, `road_right`, `shoulder_m` (m), `in_tunnel` (Kamera), `weather`,
  `hour`, `crash`, `finished`;
- `event(name, args)`: `stage_start {countdown_s}` (vor dem ersten Simulationsschritt), `countdown {n}` (3, 2, 1),
  `go {}`, `collision {speed_kmh, rel_kmh, heavy, side}` (side: −1 links, 0 mittig, +1 rechts), `rail_hit
  {impact_mps, side}`, `radar_flash {}`, `chase_start {}`, `escaped {}`, `busted {}`, `refuel_start {}`,
  `refuel_done {liters, aborted}`, `out_of_fuel {}`, `tow {}`, `stage_finish {record, last_stage}`.
Alles Weitere (Fahrbahnbelag, Rüttelstreifen, Fugen, Brücken, Stadt/Wald/offen, Vorbeifahrt an Objekten) leitet der
Klang selbst aus `Track` ab – nie aus dem Renderer. Tests setzen `race_session.audio_hooks` auf einen Empfänger
(tests/race3d/check_seam.gd „klang“).

## 12. Sprites (`assets/sprites/manifest.json`)

Ein PNG je Sprite-Set, alle Zellen gleich groß. Zellindex `i = ebene · len(angles) + winkel`, angeordnet in
`grid_cols` Spalten (fehlt das Feld: eine Zeile je Ebene, Spalten = Winkel). Sheets höchstens 4096 px je Seite,
Fahrzeug-Sheets VRAM-komprimiert (BPTC) mit Mipmaps.

```json
{ "version": 1, "sets": { "traffic/sedan_blue": {
    "file": "traffic/sedan_blue.png", "cell": [284, 108], "grid_cols": 4,
    "angles": ["l24", "l21", …, "c", …, "r24"], "yaw_deg": [-24.0, -21.0, …, 0.0, …, 24.0],
    "layers": ["base","tail","brake"], "pivot": "rear", "projection": "ortho", "elevation_deg": 9.0,
    "image_width_m": 5.4615, "anchor": [0.5, 0.9663],
    "object": { "width_m": 1.82, "length_m": 4.7, "height_m": 1.48 }, "tags": ["traffic","car"] } } }
```

- Fahrzeugdarstellung v2 (verbindlicher Vertrag: [docs/fahrzeug-darstellung.md](docs/fahrzeug-darstellung.md),
  Pipeline: [docs/sprites.md](docs/sprites.md)):
  - **Pkw im Verkehr, Polizei**: `projection: "ortho"`, `pivot: "rear"`, 17 Winkel −24° … +24° (3°-Schritte).
    Der Renderer wählt den Winkel mit Fahrzeuglänge, sodass die Front dort liegt, wo die Perspektive sie zeigt;
    geglättet und mit Hysterese.
  - **Spielerautos**: `projection: "perspective"`, `pivot: "center"`, 21 Winkel −20° … +20°, gerendert mit der
    Spielkamera (`camera`, `supersample`); bei Änderung von `render.camera_*`/`fov_deg`/`horizon` neu rendern.
  - **Lkw und Busse**: `render: "box"` – texturierte Quader (`parts` mit `faces` rear/left/right/top, `lights`), die
    der Straße abschnittsweise folgen; gezeichnet wird genau die Kollisionsbox.
- `image_width_m` = Weltbreite einer Zelle (Pixel pro Meter = `cell.x / image_width_m`; perspektivisch: in der Ebene
  der Fahrzeugmitte).
- `anchor` = Bodenpunkt innerhalb der Zelle, normiert (`rear`: Heckmitte, `center`: Fahrzeugmitte, Requisiten:
  Objektmitte vorn).
- `yaw_deg` = Gierwinkel je Winkel (+ = nach **rechts** gedreht, rechte Flanke sichtbar); fehlt das Feld, gelten die
  alten Namen `l2/l1/c/r1/r2` = −25°/−12°/0°/12°/25°.
- Ebenen: `base` (unbeleuchtet, Tageslicht), `tail` (Rücklichter, nur Leuchten, transparent), `brake` (Bremslichter),
  `beacon_a`/`beacon_b` (Blaulicht-Phasen), `lights` (Requisiten: Fenster/Lampen nachts).
- Set-IDs: `player/<kompakt|kombi|limousine|sportwagen|gran_turismo>`, `showroom/<dieselben>` (3/4-Ansicht vorn),
  `traffic/<modell>_<farbe>` (Modelle: hatch, sedan, wagon, suv, van, sports, truck, bus; Tags `traffic` + `car`
  bzw. `heavy`), `police/<land>` (de, nl, be, fr, es, ch, it, si, hr, rs, bg, hu, at, cz, pl, lt, lv, ro),
  `props/<name>` (tree_oak, tree_beech, tree_birch, tree_pine, tree_spruce, tree_poplar, tree_cypress, tree_olive,
  tree_palm, bush_round, bush_low, heather, rock_a, rock_b, cliff, haybale, farmhouse, barn, church, windmill,
  wind_turbine, power_pylon, factory, house_med, building_block_a, building_block_b, building_tall,
  building_oldtown, building_shop, streetlight, delineator, fuel_station, fuel_pump, radar_camera, customs_booth,
  ferry_ship), Städte ([docs/staedte.md](docs/staedte.md) §8): `props/city_<stil>_<name>` (Gebäude der Baustile),
  `props/bridge_truss_arch`, `props/bridge_pylon`, `props/bridge_lamp`, `props/houseboat`, `landmarks/<name>`
  (Wahrzeichen, Tag `landmark`), `ui/<icon>` (weather_normal, weather_rain, weather_snow, daytime_day, daytime_night, daytime_dawn,
  daytime_dusk).
- Platzhalter: `tools/placeholders/make_placeholders.py`; echte Grafiken: `tools/blender/` (Blender 5.2, `bpy`).

## 13. Debug-Kommandozeile

Argumente nach `--`: `--stage=<id> --from=<city> --vehicle=<typ> --hour=<0..24> --weather=normal|rain|snow
--start-km=<km> --autopilot [--autopilot-speeding] --no-countdown --seed=<n> --timescale=<f>
--screenshot=<pfad-präfix> --shot-times=1,2.5 --quit-at-finish --engine-bank=<motorbank.json>
--traffic-sounds=<traffic_sounds.json> --audio-config=<schlüssel=wert,…> --mute-bus=<bus,…> --perf`. Die Rennszene läuft auch allein:
`godot --path . res://scenes/race/race.tscn -- --stage=dev_testetappe --start-km=48 --hour=21`.
`--carry-fuel=<Liter>` startet die Etappe als Rennetappe mit diesem übernommenen Tank (v0.7.0: Countdown-Meldung,
Abschleppdienst vor dem Start).
Menüs: `--screen=<bildschirm>`, `--input=gamepad|keyboard`, Titelbild und Demo `--title-time=<s>
--attract-after=<s> --attract-scene=<index|id> --attract-demo-s=<s> --attract-press=<s> --no-attract` (docs/ui.md).

Grafikmodi (v0.8.0, §15), alle optional:

| Argument | Bedeutung |
|---|---|
| `--graphics=arcade\|modern` | erzwingt den Modus und gewinnt über alles (Tests, Screenshots, Notschalter „Arcade“). Jeder Lauf des ganzen Spiels oder der Rennszene aus einem Werkzeug oder Test nennt ihn ausdrücklich. |
| `--gfx-preset=deck\|low\|medium\|high` | Qualitäts-Voreinstellung von „Modern“ für diesen Lauf |
| `--gfx=shadows=0,scale=75,…` | einzelne Qualitätswerte für diesen Lauf (`shadows`, `details`, `scale`, `aa`, `effects`) |
| `--gfx-sync` | deterministischer Testmodus von „Modern“ (synchroner Aufbau, feste Zufallswerte, keine Wanduhr, kein Wächter) – steht in `prepare(ctx).sync` |
| `--gfx-debug=<liste>` | Testansichten von „Modern“: `cover`, `ids`, `nolight`, `chunks`, `wire`, `fail` (`healthy()` meldet false – Prüfung des Rückfalls auf Arcade) |
| `--no-prewarm`, `--no-watchdog` | Shader-Aufwärmen bzw. Langsamkeits-Wächter von „Modern“ auslassen |
| `--sound=arcade\|modern` | erzwingt das Klangprofil für diesen Lauf |
| `--audio-sync` | synchroner Motor-Mixer des Klangprofils „Modern“ (Tests, Movie Maker) |
| `--shot-fast` | `Screenshotter`: das Bild wird erst kurz vor jeder Aufnahme wieder berechnet (mit `--fixed-fps`; in „Arcade“ dieselben Bilder, etwa 4–5× schneller unter Software-OpenGL). Während eine Modern-Etappe vorbereitet wird, rechnet er weiter – Selbsttest und Aufwärmen warten auf gezeichnete Bilder. |
| `--shot-fast-lead=<s>` | Vorlauf von `--shot-fast` (Vorgabe 0,1 s). Was der `RenderingServer` beim Zeichnen selbst fortschreibt – GPU-Partikel vor allem – steht ohne Bild still (gemessen: 1.307 statt 20.191 helle Pixel nach 114 ausgelassenen Bildern): Modern-Bilder mit solchen Effekten brauchen mindestens deren längste Lebensdauer als Vorlauf oder kein `--shot-fast`. |
| `--bench=<szene\|all>`, `--bench-out=<datei.json>` | Leistungstest-Szenen fahren und beenden (ab Welle 2) |
| `--no-chooser` | die Auswahl „GRAFIK WÄHLEN“ beim ersten Start nie zeigen (ab Welle 2) |

In Welle 0 wertet der Kern `--graphics`, `--gfx-preset`, `--gfx`, `--gfx-sync` (an den Renderer gereicht),
`--gfx-debug=fail`, `--sound`, `--shot-fast` und `--shot-fast-lead` aus; die übrigen Argumente gehören den Paketen,
die sie umsetzen.

## 14. Tests, Screenshots, Build

- `tools/run_tests.sh [filter]` – ein Durchlauf, alles headless: kompiliert alle Skripte
  (`tests/check_scripts.gd`) und startet alle `tests/unit/**/test_*.gd` (Basisklasse `TestCase`). Bricht bei
  Skriptfehlern ab. Ohne Filter folgen die Integrationsläufe unten. Seit v0.8.0: `user://` liegt in einem
  temporären Ordner (die Tests sehen weder gespeicherte Einstellungen noch eine Konfiguration des Spielers), es sei
  denn, der Aufrufer setzt `XDG_DATA_HOME` auf einen **absoluten** Pfad – einen relativen ignoriert Godot und fällt
  auf `~/.local/share` zurück, den echten Benutzerordner; ein relativer Wert wird deshalb nicht benutzt. Die Läufe
  des ganzen Spiels und der Rennszene nennen ihren Grafikmodus (`-- --graphics=arcade`). **Allgemeiner Haken** für
  die Prüfungen des Modus „Modern“: jede `tests/race3d/check_*.gd` und jede `tests/sim/modern_*.gd` läuft einzeln
  mit `godot --headless --path . -s <datei>`, gibt Zeilen `CHECK <name> OK|FEHLER` aus und endet mit einem
  Exit-Code – eine neue Prüfung braucht nur ihre Datei, niemand ändert dafür das Skript (mit Filter: die Dateien,
  deren Name ihn enthält). Eine Datei fällt durch bei einem Exit-Code ungleich 0, bei einem Skriptfehler, bei einer
  Zeile `CHECK <name> FEHLER` und wenn sie gar keine Zeile `CHECK <name> OK` ausgibt – dem Exit-Code allein wird
  nicht getraut.
- `tools/run_render_checks.sh [arcade|modern|all] [filter]` – alles, was einen echten Renderer braucht (Xvfb,
  Software-OpenGL, feste 60 Bilder/s; nicht Teil von `run_tests.sh`): `arcade` = `tests/race/check_glow_occlusion.gd`
  und `check_sprite_flip.gd` mit `--graphics=arcade`; `modern` = jede `tests/race3d/render/check_*.gd` mit
  `--graphics=modern --gfx-sync --audio-sync`. Ausgabe der Prüfungen `RENDER-CHECK <name> OK|FEHLER`, dazu je Datei
  `RENDER-CHECK-DATEI <datei> OK|FEHLER`; alle Läufe eines Aufrufs teilen sich ein `XDG_DATA_HOME` (nur ein
  absoluter Pfad des Aufrufers gilt) und einen Mesa-Shader-Cache. Eine Datei fällt auch durch, wenn ein Shader
  nicht übersetzt (`SHADER ERROR`, `Shader compilation failed` – so ein Material zeichnet einfach nichts).
- `tools/golden.sh make|check [filter]|list|compare <a> <b>` – **Bildgleichheit von „Arcade“ mit v0.7.0** (§15.6).
- `tools/screenshot.sh <präfix> [args]` – rendert unter Xvfb (Software-OpenGL) und speichert PNGs;
  `SCREEN=1280x800` rendert auf einem 1280×800-Bildschirm (Steam Deck, Screenshots samt Balken; im Modus „Modern“
  füllt das Bild den Bildschirm). Aufnahmen der Rennszene mit `--graphics=arcade|modern`.
- `tools/pck_report.py <exe|pck> [--archive <zip|tar.gz>]` – Größentabelle eines Builds nach den Teilen des
  Größenbudgets (Programm, Arcade-Sprites, Arcade-Klang, UI/Skripte/Daten, Modern: Modelle, Texturen, Klang,
  Musik; roh und im Archiv) und die Größengrenze: Warnung über 300 MB, Abbruch über 330 MB (hartes Limit des
  Archivs 350 MB). Die Build-Skripte rufen es auf.
- `tools/build_linux.sh` – exportiert `build/CrossingEurope.x86_64` und gibt die Größentabelle aus.
- `tools/build_windows.sh` – exportiert `build/CrossingEurope.exe` (Vorgabe „Windows Desktop“, danach setzt
  `tools/windows/set_exe_icon.py` das vollständige Programm-Icon ein) und packt sie mit `LIZENZEN.txt`
  (`tools/write_licenses.gd`: Godot Engine samt Bestandteilen, Schriften, Kartendaten) in
  `build/CrossingEurope-windows-x86_64.zip`; `tools/build_release.sh <Version>` baut aus einem sauberen Commit mit
  dieser Version Linux und Windows, packt `CrossingEurope-linux-x86_64.tar.gz` und schreibt `build/SHA256SUMS` und
  `build/BUILDINFO.txt`; die Archive sind reproduzierbar ([docs/windows.md](docs/windows.md)). Seit v0.8.0 enden
  beide Build-Skripte mit der Größentabelle, und der Build bricht ab, wenn ein Archiv 330 MB überschreitet.
  Exportiert werden neben den Ressourcen `*.json`, `*.f32` und `*.i16` (rohe Motorbänke des Klangprofils „Modern“).
- Integration: `tests/race/check_session.gd` (15 Szenarien der Rennsitzung: Kollisionsrichtung, leerer Tank,
  Zielauslauf, Polizei beim Tanken, übernommener Tank, Tutorial, Leitplanke, vorab geladene Sprites; seit v0.8.0
  `gfx_independent` – dieselbe Strecke mit beiden Renderern: gleiches Ergebnis und gleicher Verkehrs-Hash in jeder
  Sekunde – und `gfx_fallback`), `tests/race3d/check_seam.gd` (die Naht zwischen Sitzung und Renderern mit einem
  Prüf-Renderer, §15.6), `tests/race/check_attract.gd` (Attract-Modus im ganzen Spiel:
  Leerlauf, Demo, Abbruch per Taste/Gamepad/Klick ohne Menüpunkt, nichts gespeichert), `tests/race/check_sprite_flip.gd` (braucht Xvfb/OpenGL),
  `tests/race/run_stage.gd` (eine Etappe mit Autopilot), `tests/race/run_race.gd` (ein ganzes Rennen durch die Menüs),
  `tests/race/shoot_vehicles.gd` (Fahrzeugszenarien; mit `--write-movie <datei>.avi` samt Ton, `--audio-trace` für die
  Auswertung der Verkehrsgeräusche, docs/ui.md „Audio“).

## 15. Grafikmodi „Arcade“ und „Modern“ (v0.8.0)

Ein Build, zwei Renderer hinter derselben Schnittstelle. „Arcade“ ist der bisherige Pseudo-3D-Renderer
(`RoadRenderer`, eingefroren, bildgleich mit v0.7.0), „Modern“ ein echter 3D-Renderer (`ModernRenderer`,
`scripts/race3d/`). Verbindlicher Bauplan mit allen Entscheidungen: [docs/dev/v080_contract.md](docs/dev/v080_contract.md).
**Stand Welle 0 (Gerüst):** Einstellungen, Modus-Auflösung, die Naht in der Rennsitzung, Werkzeuge und Prüfungen sind
fertig; der Modern-Renderer ist ein Gerüst (Kamera mit Arcades Projektion, Himmelsfarbe über eine Canvas-Ebene, eine
graue Ebene). Daneben stehen die Kerne der drei anderen Bereiche, jeder mit eigener Dokumentation:

- **Geometrie-Kern des Renderers** (`scripts/race3d/`: Pfad der Straße im Raum, Kamera, Geländeprofil,
  Stück-Streamer, Fairness-Prüfungen des ganzen Netzes) – [docs/renderer-modern.md](docs/renderer-modern.md). Das
  Renderer-Gerüst benutzt ihn noch nicht.
- **Modell-Pipeline** (`ModelDB`, `ModernMaterials`, `ModelFactory`, Shader in `assets/shaders/modern/`) mit sechs
  Referenzmodellen; jedes Sprite-Set außer `ui/*` hat in `assets/models/manifest.json` einen Eintrag (Modell oder
  Platzhalter) – [docs/modelle.md](docs/modelle.md).
- **Audio-Kern des Klangprofils „Modern“** (`ModernAudio` hinter dem `AudioManager`, eigene Busse, Pegelplan; die
  Bausteine spielen vorerst den Arcade-Klang über die Modern-Busse) – [docs/audio-modern.md](docs/audio-modern.md).
  Bis `GameFlow` das gespeicherte Profil setzt (Welle 2), ist es nur über `--sound=modern` oder den
  Konfigurationswert `audio.profile` zu hören.

Auswahlbildschirm, Optionen, Showroom, die Klänge und die Musik von „Modern“ und der eigentliche Renderer folgen in
den nächsten Wellen und halten sich an die Schnittstellen dieses Abschnitts.

Grundregeln: Die Simulation ist in beiden Modi dieselbe und liest nie etwas aus einem Renderer
(`RoadProjection.visible_fraction` bleibt die Projektion der Simulation, die Fahrzeugmaße kommen weiter aus dem
Sprite-Manifest). Grafik und Klang sind unabhängig: `AudioManager` und alles unter `scripts/audio/` lesen nie den
Grafikmodus, kein Renderer liest das Klangprofil – jede Kombination muss laufen.

### 15.1 Einstellungen (`Settings`) und reine Helfer (`Gfx`)

`user://settings.json`, `settings_version` 3. Neue Schlüssel – jeder wird erst gespeichert, wenn der Spieler ihn
gewählt hat (Muster von `fullscreen`); ungültige Werte zählen als „nicht gewählt“; Schlüssel, die diese Version nicht
kennt, bleiben beim Speichern erhalten:

| Schlüssel | Werte | ohne Eintrag |
|---|---|---|
| `graphics_mode` | `"arcade"`, `"modern"` | nicht gewählt → das Spiel ist Arcade |
| `sound_profile` | `"auto"`, `"arcade"`, `"modern"` | `"auto"` = wie die **gewählte** Grafik |
| `gfx_preset` | `"deck"`, `"low"`, `"medium"`, `"high"`, `"custom"` | die für die Grafikkarte empfohlene |
| `gfx_custom` | `{shadows 0..3, details 0..2, scale 50..150, aa 0..2, effects 0..2}` | Werte der Voreinstellung |
| `race_music` | bool | `true` |

Falle beim Versionssprung: `Settings.fullscreen_stored_as_choice()` vergleicht mit der festen Konstante
`FULLSCREEN_CHOICE_SINCE := 2`, nicht mit `SETTINGS_VERSION` – sonst verlöre jeder Spieler von v0.6/v0.7 sein
gespeichertes „Vollbild: Aus“. `load_settings()` liest jeden Wert hinter einer Typprüfung: Ein Wert vom falschen
Typ (von Hand geänderte Datei, eine spätere Version mit anderem Typ) zählt als nicht gespeichert und hält den Rest
der Datei nicht vom Lesen ab; die unbekannten Schlüssel werden zuerst gesichert. (Ein ungeprüftes `bool("x")` oder
`float(null)` ist ein Skriptfehler, der die Funktion beendete: Grafikmodus, Klangprofil, Name und die unbekannten
Schlüssel gingen verloren und wurden beim nächsten Speichern aus der Datei gelöscht.)

`Settings` (Autoload) – Felder `graphics_mode` (`""` = nicht gewählt), `sound_profile`, `gfx_preset`, `gfx_custom`,
`race_music` (dazu `sound_profile_chosen`, `race_music_chosen`), `crash_guard`, `marker_path`; Signale
`graphics_changed(mode)` (die gewählte Grafik hat sich geändert), `quality_changed(quality)`,
`sound_profile_changed(profile)` (das **aufgelöste** Profil hat sich geändert); Methoden:

| Methode | Ergebnis |
|---|---|
| `effective_graphics()` | `{"mode": "arcade"\|"modern", "reason": ""\|"cli"\|"config"\|"crash_guard"\|"default"}` |
| `is_modern()` | `effective_graphics().mode == "modern"` |
| `quality()` | `{"preset", "shadows", "details", "scale", "aa", "effects"}` samt `--gfx-preset` / `--gfx` |
| `quality_levels()` | Renderer-Parameter: `Gfx.levels(quality(), config "graphics")` |
| `sound()` | `"arcade"\|"modern"`: `--sound` > config `audio.profile` > `sound_profile`; `auto` = gewählte Grafik, sonst Arcade |
| `adapter_tier()` | `"software"\|"weak"\|"deck"\|"ok"` der laufenden Grafikkarte |
| `arm_crash_guard()`, `disarm_crash_guard(lift = true)` | Absturz-Marker schreiben / entfernen (§15.5) |

**Auflösung des Modus** (`Gfx.resolve_mode(chosen, cli, force, marker)`): Kommandozeile `--graphics=` > config
`graphics.force_mode` > Absturz-Marker des letzten Laufs (→ Arcade, Grund `crash_guard`; bei gewähltem „Arcade“
ändert er nichts) > gespeicherte Wahl > **Arcade** (Grund `default`). Ohne gespeicherte Wahl verhält sich also jedes
Werkzeug, jeder Test und jeder Start von der Kommandozeile wie vor v0.8.0. Eine geänderte Wahl gilt in den Menüs
sofort, im Rennen ab dem nächsten Start einer Etappe; innerhalb einer Etappe wird der Renderer nie gewechselt.
Das Klangprofil folgt bei `auto` der *gewählten* Grafik, nie der wirksamen: Ein Rückfall der Grafik oder ein
`--graphics=` eines Tests ändert den Klang nicht.

`Gfx` (`scripts/core/gfx.gd`, `RefCounted`, nur statische, reine Helfer ohne Autoload-Zugriff): Konstanten `ARCADE`,
`MODERN`, `MODES`, `SOUND_PROFILES`, `PRESET_ORDER`, `QUALITY_KEYS`, `SCALE_STEPS` (50, 67, 75, 85, 100, 125, 150),
`BOOT_MARKER` (`user://modern_start.lock`), `DEFAULT_PRESETS`, `DEFAULT_LEVELS`; Funktionen
`classify_adapter(adapter, vendor = "", api = "", gamescope = false)` (nach dem *Namen* der Grafikkarte),
`recommended_mode(tier)` (Modern für deck/ok, Arcade für software/weak), `recommended_preset(tier)` (deck → deck,
weak/software → low, ok → medium), `resolve_mode(…)`, `resolve_sound(profile, chosen_graphics, cli = "", force = "")`,
`quality(preset, custom, presets)`, `preset_values(id, presets)`, `preset_of(q, presets)`, `sanitized(q)` (jeder Wert
in seinen Bereich, die Skalierung auf die nächste Stufe), `with_cli(q, preset_arg, set_arg, presets)`,
`levels(q, gfx_cfg)`, `watchdog_verdict(median_ms, p95_ms, target_ms, wd_cfg, lowest)` → `"ok"|"slow"|"too_slow"`
(`target_ms` = Bildzeit der Bildwiederholrate oder der Bildbegrenzung – ein Steam Deck mit 40 Hz ist bei 25 ms nicht
langsam; ein Ziel ≤ 0 heißt „unbekannt“ – `DisplayServer.screen_get_refresh_rate()` liefert dann −1 – und wird
gegen 60 Hz beurteilt). `sanitized()` begrenzt vor der Umwandlung in eine Ganzzahl (`--gfx=aa=1e30` ist das obere
Ende, nicht 0), NaN zählt als fehlend. `graphics.watchdog.countdown_min_fps` liest nicht `Gfx`, sondern der Wächter
des Renderers (ab Welle 1): Darunter senkt er im Countdown einmal die Voreinstellung.

`GfxSelfTest` (`scripts/core/gfx_self_test.gd`): `await GfxSelfTest.run(parent, frames = 3)` rendert eine beleuchtete
Kugel und eine Fläche mit eigenem Shader in ein 96×96-`SubViewport` und liefert
`{"ok", "reason": ""|"black"|"shader"|"readback", "ms"}` (headless übersprungen = bestanden; verlässt `parent`
währenddessen den Baum, endet der Test ohne Urteil mit `"aborted": true` – der Renderer ruft ihn deshalb aus einer
statischen Funktion und merkt sich nur ein Urteil); das reine Urteil über ein Bild ist `GfxSelfTest.judge(img)`.
Gemessen auf der Test-VM (llvmpipe): 164–325 ms beim ersten Lauf, 49–86 ms danach.

### 15.2 Qualität von „Modern“

Eine Qualität sind fünf Werte: `shadows` 0–3 (Aus, Niedrig, Mittel, Hoch), `details` 0–2 (Niedrig, Mittel, Hoch),
`scale` (3D-Auflösung in Prozent), `aa` 0–2 (Aus, MSAA 2×, MSAA 4×), `effects` 0–2 (Aus, Einfach, Voll).
Voreinstellungen (config `graphics.presets`): `deck` {1, 1, 100, 1, 1}, `low` {0, 0, 75, 0, 0}, `medium`
{2, 1, 100, 1, 1}, `high` {3, 2, 100, 2, 2}; `custom` = die eigenen Werte des Spielers. `Gfx.levels()` macht daraus
mit config `graphics.levels` ein flaches Wörterbuch für `ModernRenderer.apply_quality()`:

| Schlüssel | Bedeutung |
|---|---|
| `preset`, `shadows`, `details`, `scale`, `aa`, `effects` | die Qualität selbst |
| `shadow_casters` | 0 keine (Blob-Schatten), 1 Fahrzeuge und Bauwerke, 2 + Gebäude und Baum-Stellvertreter, 3 + alle Requisiten |
| `shadow_splits`, `shadow_blend`, `shadow_atlas`, `shadow_distance_m`, `shadow_filter`, `blob_shadows` | Schattenstufen (1 = orthogonal), Überblenden, Atlasgröße, Reichweite, Filter (0 hart, 1 weich niedrig, 2 weich mittel) |
| `vehicle_lod0_m`, `vehicle_lod1_m`, `prop_lod0_m`, `prop_lod1_m` | Entfernung, bis zu der die feinste bzw. mittlere Detailstufe gilt |
| `deco_density`, `terrain_outer_m` | Dichte rein dekorativer Requisiten, äußerster Geländering |
| `glow`, `particles`, `spray`, `wet_reflections`, `ssao`, `ssao_quality`, `sky_reflections`, `omni_pool` | Effekte; `omni_pool` = echte Punktlichter (höchstens 8) |
| `msaa`, `scale_3d` | MSAA 0/2/4, 3D-Skalierung 0,5–1,5 |

Die Typen sind fest (JSON-Zahlen werden umgewandelt), fehlende oder beschädigte Einträge der Konfiguration fallen
auf die eingebauten Startwerte zurück, zusätzliche Schlüssel der Konfiguration werden durchgereicht. **Keine
Qualitätsstufe dünnt aus, kürzt oder dunkelt ab, worauf der Spieler reagieren muss** (Fahrzeuge, ihre Lichter und
Blinker, Schilder, Fahrbahnränder, Markierungen, Leitplanken, Tunnelwände).

### 15.3 Konfiguration `graphics` (`config/game_config.json`)

`force_mode` (`""|"arcade"|"modern"`), `presets`, `levels` (`shadows[4]`, `details[3]`, `aa[3]`, `effects[3]`),
`modern` (Kamera `look_gain`, `look_m`, `yaw_max_deg`, `near_m`, `far_m`; `chunk_segments`, `load_path_m`,
`landmark_path_m`, `keep_behind_m`, `threaded_build`, `commits_per_frame`, `fog`, `terrain`, `lights`, `sky_update_s`,
`prewarm`), `watchdog` (`countdown_min_fps`, `slow_factor`, `too_slow_factor`), `benchmark` (`seconds`, `scenes[]` wie
`attract.scenes`), `budgets` je Voreinstellung (`draw_calls`, `primitives`, `script_ms`, `commit_ms` – Zielwerte für
eine echte Grafikkarte, abgeleitet, nicht gemessen). Arcade liest nichts aus diesem Abschnitt.

### 15.4 Renderer-Naht (`RaceRenderers`, `scripts/race/race_renderers.gd`)

`RaceRenderers.create(mode) -> Node` liefert `RoadRenderer.new()` für `"arcade"` und den Modern-Renderer
(`scripts/race3d/modern_renderer.gd`, zur Laufzeit geladen – Arcade berührt den 3D-Code nie) für `"modern"`; `null`,
wenn der sich nicht erzeugen lässt. Die Variable `renderer` der Sitzung ist untypisiert.

| Methode / Signal | Arcade (`RoadRenderer`) | Modern (`ModernRenderer`, `Node3D`) |
|---|---|---|
| `setup(track, proj, cfg, scenery_db)` | ja | ja |
| `render(view)` jedes Bild | ja | ja – auch während der Vorbereitung (die eingefrorene Startansicht) |
| `perf_stats() -> Dictionary` | ja | ja (`mode: "modern"`, `preset`, Zeiten, Zähler) |
| `apply_quality(levels)` | – | einmal vor `prepare()`, nie während einer Etappe |
| `prepare(ctx)` | – | startet Selbsttest, Laden der Modelle, Shader-Aufwärmen; über mehrere Bilder |
| `is_prepared()`, `prepare_progress()` | – | ja |
| `healthy()`, `fail_reason()` | – | false + Grund: `"selftest:<r>"`, `"manifest"`, `"shader"`, `"timeout"` |
| `debug_snapshot()` | – | reine Daten für headless-Tests |
| `world_to_screen(z, x, h) -> Vector3` | – | (Pixel x, Pixel y, Tiefe m) in logischen Pixeln |
| `signal quality_lowered(preset)` | – | der Wächter hat die Voreinstellung gesenkt |

Die Sitzung ruft die Modern-Methoden nur an einem Renderer mit `prepare`. `ctx` von `prepare()`: `{"sets":
Array[String]` (jede Sprite-Set-ID, die die Etappe zeigen kann – Spielerauto, Verkehr, Polizei der Länder, HUD-Icons,
Requisiten, Wahrzeichen, Skyline), `"plan": StagePlan, "vehicle": String` (Fahrzeugtyp), `"weather", "hour", "sync":
bool` (`--gfx-sync`)`}`. `view.palette` ist in beiden Modi die Außenpalette (`Palette.compute`).

Canvas-Ebenen im Rennen: −10 Hintergrund von „Modern“ (`Environment.BG_CANVAS`), 1–2 Bildeffekte und 2D-Überlagerungen
von „Modern“, 5 HUD und Pausemenü, 6 Ladebild der Sitzung. Arcade zeichnet alles selbst wie bisher.

### 15.5 Ablauf einer Etappe (`race_session.gd`)

1. Modus = `setup.gfx`, sonst `Settings.effective_graphics().mode`. „Modern“: **zuerst** der Absturz-Marker
   (`Settings.arm_crash_guard()`), dann der Renderer; das Fenster wird gefüllt (`content_scale_aspect = EXPAND`;
   Arcade bleibt unberührt, `GameFlow` setzt `KEEP`). Die `RoadProjection` der Simulation bleibt in beiden Modi
   1280×720.
2. Sprite-Blätter: Arcade lädt wie bisher alle vorab. „Modern“ lädt nur die HUD-Icons (`ui/*`); Fahrzeug-,
   Requisiten- und Wahrzeichen-Blätter (allein die Fahrzeuge 281 MB BPTC) bleiben ungeladen.
3. `apply_quality(Settings.quality_levels())`, `prepare(ctx)`, Ladebild „Etappe wird geladen …“ (deckend, Ebene 6;
   `LoadingOverlay.set_progress(p)`, sobald das Widget es hat). **Bis `is_prepared()` läuft nichts von der Etappe:**
   kein Simulationsschritt, kein Countdown, keine HUD-Uhr, kein Klang-Hook, und die Uhr jedes `Screenshotter` steht
   (der eigene der Sitzung über `hold`, jeder andere – der von `GameFlow` in einer Attract-Demo – über den
   statischen Zähler `Screenshotter.preparing`, den die Sitzung für die Dauer der Vorbereitung erhöht; mit
   `--shot-fast` wird das Bild so lange gerechnet) – gleiche Aufnahmezeiten zeigen in beiden Modi denselben
   Simulationszustand. Die Startansicht wird in dieser Zeit weiter an `render(view)` gegeben (der Renderer baut und
   wärmt auf, was das erste Bild zeigt). Der erste Simulationsschritt danach startet die Etappe wie das erste Bild
   einer Arcade-Etappe. Ein Fokusverlust während der Vorbereitung pausiert beim Start.
   Startet `GameFlow` die Etappe beim Spielstart (`-- --stage=…`, der einzige Start eines exportierten Builds),
   hängt die Szene erst nach den Physik-Rückrufen des Bildes im Baum: Sie wird einmal gezeichnet, bevor ihr erster
   Simulationsschritt läuft, und eine Arcade-Etappe ist an jeder Aufnahmezeit einen Schritt zurück. Die Sitzung
   misst diese Zeit (`_lead_s`: `_process`-Sekunden vor dem ersten `_physics_process`) und schreibt sie beim Start
   einer Modern-Etappe den Uhren gut, die standen (`Screenshotter.skip()`, HUD-Zeitgeber, Phase des Blaulichts).
4. `not healthy()` (auch mitten in der Vorbereitung) oder kein Renderer → **Rückfall**: Modern-Renderer frei,
   Arcade-Renderer und seine Sprites, `KEEP`, HUD-Meldung „Der Modus „Modern“ lässt sich mit dieser Grafik nicht
   starten. Das Spiel läuft im Modus „Arcade“ weiter.“, Ergebnis `gfx = "arcade"`, `gfx_fallback = <Grund>`
   (`"renderer"`, wenn er sich nicht erzeugen ließ). Der Klang ändert sich dadurch nicht.
5. Absturz-Marker `user://modern_start.lock`: entfernt nach 2 s gezeichneter Bilder der gestarteten Etappe (dann
   ist auch ein Marker des letzten Laufs erledigt), bei einem Rückfall und wenn die Etappe vorher ordentlich endet
   (nächste Etappe, zurück ins Menü, Spiel beendet – auch während der Vorbereitung). Er bleibt nur, wenn das Spiel
   in „Modern“ abstürzt oder hängt und abgeschossen wird: Der nächste Start findet ihn (`Settings.crash_guard`),
   läuft in Arcade (`reason = "crash_guard"`) und lässt die gespeicherte Wahl stehen, bis der Spieler die Frage auf
   dem Titel beantwortet (`Settings.disarm_crash_guard()`) oder eine Modern-Etappe 2 s gelaufen ist. `GameFlow`
   hängt die Szene der nächsten Etappe ein, bevor die alte den Baum verlassen hat – eine abgehende Etappe nimmt
   deshalb weder den Marker noch die Strecke des Klangs (`set_track`) der neuen mit.
6. Pause: Der Baum wird pausiert wie bisher; in „Modern“ muss das Bild vollständig stehen (alles Bewegte läuft auf
   `view.time`).

### 15.6 Prüfungen der Grafikmodi

- **Bildgleichheit von Arcade** (harte Grenze nach jedem Arbeitspaket): `tools/golden.sh make` exportiert den
  Git-Tag `v0.7.0` in einen temporären Ordner, rendert mit *diesem* Stand die 20 Bilder aus
  `tests/golden/arcade_frames.txt` – 14 Bilder der sieben Attract-Szenen (bei 4 s und 12 s) und 6 Rennbilder mit
  vollem HUD an Referenzpositionen (Countdown, „LOS!“ mit Wetterhinweis, Fahrt bei Tag, Regen, Dämmerung und im
  Tunnel) – unter Xvfb mit Software-OpenGL bei festen 60 Bildern/s und schreibt ihre MD5-Summen nach
  `tests/golden/arcade_v070.md5` (dazu `arcade_v070.env`: Godot-Version und OpenGL-Treiber). `tools/golden.sh check`
  rendert dieselben Bilder mit der Arbeitskopie (`--graphics=arcade --shot-fast`) und vergleicht:
  „GOLDEN arcade: 20 von 20 identisch“, sonst Exit-Code 1. Gemessen auf der Test-VM: `make` 725 s (jedes Bild wird
  berechnet), `check` 153 s. Nach einem Wechsel von Godot oder Mesa die Liste mit `make` neu aus dem Tag erzeugen
  (`check` weist darauf hin). `KEEP=<ordner>` behält die Bilder, `tools/golden.sh compare <a> <b>` zählt die
  verschiedenen Pixel je Bild.
- `tests/unit/core/test_gfx_settings.gd`: Migration der Einstellungsdatei (ohne Version, 2 → 3), die
  Vollbild-Falle, unbekannte Schlüssel, Werte vom falschen Typ in alten Schlüsseln, die Matrizen von `resolve_mode`
  (128 Kombinationen) und `resolve_sound` (144), Voreinstellungen, Grenzen (auch jenseits des Ganzzahlbereichs und
  NaN), Kommandozeile, Renderer-Parameter, Wächter (auch ohne bekanntes Ziel), Absturz-Marker, Urteil des
  Selbsttests.
- `tests/race3d/check_seam.gd` (headless, über den Haken von `run_tests.sh`): die Naht mit einem Prüf-Renderer
  (`tests/race3d/fixtures/seam_probe_renderer.gd`, über `RaceRenderers.modern_script`), der eine einstellbare Zahl
  von Bildern zum Vorbereiten braucht und ausfallen kann – Reihenfolge der Aufrufe, Marker vor dem Renderer,
  Stillstand bis `is_prepared()`, nur `ui/*` als Sprite-Blätter, Marker nach 2 s weg, früher Abgang und
  Etappenwechsel, Rückfall, fehlender Renderer, alle Klang-Hooks, Marker des letzten Laufs, die Uhr eines fremden
  `Screenshotter` (steht in der Vorbereitung, `--shot-fast` rechnet dann weiter; Zähler nach Start, Rückfall,
  frühem Abgang und zwei überlappenden Etappen wieder 0).
- `tests/race3d/check_models.gd` (headless, über den Haken): `tools/blender/validate_models.py` besteht auf den
  eingecheckten Modellen; eine abgeschnittene, fremde oder fehlende Netzdatei ergibt kein halbes Modell
  (docs/modelle.md).
- `tests/race3d/render/check_seam_render.gd` (Xvfb): Selbsttest auf dem echten Renderer, Bild des Gerüsts, gleiche
  Simulationsschritte bei gleicher Aufnahmezeit in beiden Modi – für eine Szene, die zwischen zwei Bildern in den
  Baum kommt, und für eine, die wie beim Start über `GameFlow` nach den Physik-Rückrufen kommt –, Rückfall
  bildgleich mit Arcade, Arcade vor und nach einer Modern-Etappe im selben Prozess bildgleich, 16:10-Fenster
  (Modern füllt, Arcade mit Balken).
- `tests/race3d/render/check_models.gd` (Xvfb): jede Materialklasse zeichnet (ein Shader, der nicht übersetzt,
  zeichnet nichts), die 15 Lampenkanäle und die Lackcodes des Vertexformats, Blinker und Bremslicht der
  Referenzfahrzeuge auf dem Bildschirm, die MultiMesh-Wege samt gespiegeltem Knoten (docs/modelle.md).
- `tests/unit/audio_modern/check_arcade_lean.gd` (Kindprozess von `test_modern_checks.gd`): Start und eine Etappe
  mit Bild und Klang „Arcade“ laden kein Skript des Modern-Klangs, des Modern-Renderers oder der Modell-Datenbank
  (eine typisierte Variable im `AudioManager` ließ sonst bei jedem Start 19 Skripte übersetzen).
- `tests/race/run_stage.gd -- --stage=<id> --graphics=arcade|modern`: `ERGEBNIS` ist in beiden Modi dasselbe bis auf
  `gfx`.
