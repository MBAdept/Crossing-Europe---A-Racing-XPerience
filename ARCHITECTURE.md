# Architektur – Crossing Europe

Technischer Bauplan zum [Design-Dokument](docs/Design-Dokument.md). Er beschreibt Module, Schnittstellen,
Datenformate und Konventionen. **Öffentliche APIs in diesem Dokument sind Verträge**: erweitern ist erlaubt,
Signaturen ändern oder entfernen nicht.

- Engine: **Godot 4.7.2**, GDScript, Renderer *GL Compatibility* (läuft auch auf schwacher Hardware).
- Auflösung: 1280×720 logisch, Stretch-Modus `canvas_items`; Seitenverhältnis `keep` im Rennen, `expand` in den
  Menüs (der Menühintergrund füllt z. B. 16:10 auf dem Steam Deck, siehe [docs/steam-deck.md](docs/steam-deck.md)).
- Zielplattform: Linux x86_64 als einzelne ausführbare Datei (PCK eingebettet).

## 1. Verzeichnisse und Modul-Eigentümer

| Modul | Dateien (Eigentum) |
|---|---|
| Kern (Gerüst) | `project.godot`, `export_presets.cfg`, `scripts/core/*`, `tests/run_tests.gd`, `tests/test_case.gd`, `tests/check_scripts.gd`, `tools/*.sh` |
| Renn-Modul | `scripts/race/*`, `scenes/race/*`, `data/scenery.json`, `tests/unit/race/*` |
| Gameplay | `scripts/gameplay/*`, `tests/unit/gameplay/*`, `tests/sim/*` |
| Daten | `scripts/data/*`, `data/network.json`, `data/countries.json`, `data/map/*`, `tools/map/*`, `tests/unit/data/*` |
| UI und Audio | `scripts/ui/*`, `scripts/audio/*`, `scenes/main.tscn`, `scenes/ui/*`, `assets/fonts/*`, `assets/ui/*`, `tests/unit/ui/*` |
| Sprites | `tools/blender/*`, `assets/sprites/*` (inkl. `manifest.json`) |

Abschnitte der zentralen Konfiguration `config/game_config.json`:
`time, daytime, vehicles, driving, collision, traffic, fuel, radar, police, city_limits, weather` → Gameplay ·
`road, render, debug` → Renn-Modul · `hud, audio` → UI · `leaderboard, routing, stages` → Daten.

## 2. Konventionen

**Einheiten und Zeitraffer** (`scripts/core/units.gd`):

- Geschwindigkeit in **km/h**.
- **km** = Kilometerzähler (Etappenkilometer). Alle Positionen in den Daten sind km.
- **m / z** = sichtbare Meter der Straße. `m = km * 1000 / time_scale` (bei Faktor 12: 1 km = 83,3 m).
  Der Renderer scrollt mit Tachotempo, Kilometerzähler und Uhr laufen 12-mal schneller.
- **Spielzeit** = echte Sekunden; **Weltzeit** = Minuten (absolut, Tag 0 00:00 = 0), läuft 12-mal schneller.
  100 km bei 100 km/h = 300 s = 5:00. Durchschnittstempo = `Units.avg_speed_kmh(km, s, 12)`.
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
| `InputSetup` | `scripts/core/input_setup.gd` | registriert Aktionen `steer_left/right`, `accelerate`, `brake`, `pause` (Tastatur + Gamepad); meldet das aktive Eingabegerät an `InputMode` (Tastenhinweise) |
| `Settings` | `scripts/core/settings.gd` | Nutzer-Einstellungen `user://settings.json` (Lautstärke, Vollbild, Name, Sprache, Bestenlisten-Filter) |
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

## 7. Gameplay (`scripts/gameplay/*`, reine Logik)

| Klasse | Kern-API |
|---|---|
| `VehicleModel` | `setup(cfg, vehicle_id)`, `resolve_spec()` (statisch), `update(dt, input{steer,throttle,brake}, road{curve,grade,left_edge,right_edge,shoulder_m,guardrail,grip}, env{vmax_factor})`, `start_crash(other_x, space_left, space_right)`, `auto_control(target_kmh, rate_kmh_s, steer_x=NAN)`, `release_auto()`, `is_controllable()`, `safe_curve_speed(curve, grip)`, `max_speed(grade, factor)`; Felder `speed, x, state (DRIVING/CRASH/AUTO), invulnerable, blink_visible, steer_visual, braking, understeer, off_road, vmax_effective, length_m, width_m, spec`; Signale `crash_started(dir)`, `crash_finished` |
| `TrafficSystem` | `setup(cfg, track, car_set_ids, heavy_set_ids, seed)`, `update(dt, player{z,x,speed}, ctx{hour,chase,camera_z})`, `find_collision(player{z,x,length,width}, camera_z, visible_fraction: Callable) → Car`, `space_beside(z, x, half_len, left, right) → Vector2`, `density_factor(hour)`, `speed_factor(hour)`; `cars: Array[Car]` mit `z, x, lane, speed, cruise_speed, set_id, length, width, height, heavy, braking, in_fuel_lane` |
| `FuelSystem` | `setup(cfg, vehicle_spec, plan)`, `update(dt, pos_km, delta_km, speed, in_fuel_lane, throttle)`, `control_request()`, `take_penalty()`, `consumption_per_100km(v)`, `base_consumption(cfg, v)` (statisch), `range_km(v)`, `distance_to_next_station(km)`; Felder `tank_l, fuel_l, state (NORMAL/REFUELING/TOWING), refuel_progress, refuel_time_left, liters_added`; Signale `announced(km_before, station_km)`, `refuel_started`, `refuel_finished(liters, aborted)`, `ran_dry`, `tow_finished(penalty_s)` |
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

## 8. Rennsitzung (`scripts/race/race_session.gd`, Szene `scenes/race/race.tscn`)

`setup` (vor dem Einhängen gesetzt; leer = Kommandozeile): `{mode: "race"|"single", race_id, stage_id, from_city,
vehicle, start_world_minutes, weather, start_km?, autopilot?, seed}`.
Signale: `stage_finished(result)`, `stage_aborted(reason)`, `restart_requested`.

**Ergebnis** (`result`): `board_key, stage_id, from_city, to_city, stage_name, time_s (inkl. Strafen), penalty_s,
avg_speed_kmh, distance_km, vehicle, weather, start_world_minutes, end_world_minutes, start_hour, daytime,
collisions, refuels, liters_refueled, radar_flashes, police_stops, police_escapes, tow_events, aborted`.

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
(Start = Ende + 12 h Weltzeit, Pause zählt nicht) / Fähre (Szene, feste Zeit) → Rennergebnis + Rennbestenliste.
Nach jeder Etappe `SaveGame.save_race(state)`. Nach 60 s ohne Eingabe im Titel zeigt der Attract-Modus eine 30-s-Demo
in der echten Rennszene (Autopilot, Titelmusik, Effekte stumm, nichts wird gespeichert; docs/ui.md „Attract-Modus“).

**Rennstand** (`SaveGame`): `{race_id, vehicle, start_hour, current_city, waypoint_index, legs[{kind, id, from, to,
time_s, avg_kmh, weather, start_world_minutes, end_world_minutes}], total_time_s, world_minutes, route[], seed}`.

**Bestenlisten** (`Leaderboards`): `top(key, vehicle_filter="", count=10)`, `record(key, filter)`,
`would_rank(key, time_s, filter) → 1..10 | 0`, `submit(key, entry) → Rang`. Eintrag: `{name, time_s, avg_kmh,
vehicle, weather, start_hour, daytime, date, route?}`.

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
  bzw. `heavy`), `police/<land>` (de, nl, be, fr, es, ch, it, si, hr, rs, bg, hu, at, cz, pl, lt, lv),
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
Menüs: `--screen=<bildschirm>`, `--input=gamepad|keyboard`, Titelbild und Demo `--title-time=<s>
--attract-after=<s> --attract-scene=<index|id> --attract-demo-s=<s> --attract-press=<s> --no-attract` (docs/ui.md).

## 14. Tests, Screenshots, Build

- `tools/run_tests.sh [filter]` – kompiliert alle Skripte (`tests/check_scripts.gd`) und startet alle
  `tests/unit/**/test_*.gd` (Basisklasse `TestCase`). Bricht bei Skriptfehlern ab.
- `tools/screenshot.sh <präfix> [args]` – rendert unter Xvfb (Software-OpenGL) und speichert PNGs;
  `SCREEN=1280x800` rendert auf einem 1280×800-Bildschirm (Steam Deck, Screenshots samt Balken).
- `tools/build_linux.sh` – exportiert `build/CrossingEurope.x86_64`.
- Integration: `tests/race/check_session.gd` (9 Szenarien der Rennsitzung: Kollisionsrichtung, leerer Tank,
  Zielauslauf, Polizei beim Tanken, Tutorial), `tests/race/check_attract.gd` (Attract-Modus im ganzen Spiel:
  Leerlauf, Demo, Abbruch per Taste/Gamepad/Klick ohne Menüpunkt, nichts gespeichert), `tests/race/check_sprite_flip.gd` (braucht Xvfb/OpenGL),
  `tests/race/run_stage.gd` (eine Etappe mit Autopilot), `tests/race/run_race.gd` (ein ganzes Rennen durch die Menüs),
  `tests/race/shoot_vehicles.gd` (Fahrzeugszenarien; mit `--write-movie <datei>.avi` samt Ton, `--audio-trace` für die
  Auswertung der Verkehrsgeräusche, docs/ui.md „Audio“).
