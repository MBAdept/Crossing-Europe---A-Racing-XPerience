# Datenmodul – Streckennetz, Routing, Bestenlisten, Spielstand, Karte

Eigentum (ARCHITECTURE.md §1): `scripts/data/*`, `data/network.json`, `data/countries.json`, `data/map/*`,
`tools/map/*`, `tests/unit/data/*`, dieses Dokument; Konfiguration `leaderboard`, `routing`, `stages`.

| Datei | Inhalt |
|---|---|
| `data/network.json` | Städte, Etappen, Fähren, Rennen (Quelle der Wahrheit fürs Spiel) |
| `data/countries.json` | Länder: Namen, Tempolimits, Klima, Polizei-Sprite, Farben |
| `data/map/europe_map.json` | Europakarte (Ländergrenzen als Polygone, Projektion) |
| `scripts/data/game_data.gd` | Autoload `GameData` – lädt alles, delegiert an `RoadNetwork` |
| `scripts/data/road_network.gd` | `RoadNetwork` – Routing (Dijkstra), Rennoptionen, Zusammenfassungen, Validierung (rein, testbar) |
| `scripts/data/stage_plan.gd` | `StagePlan` – eine Etappe für eine Fahrtrichtung aufgelöst |
| `scripts/data/leaderboards.gd` / `leaderboard_store.gd` | Autoload `Leaderboards` / Logik `LeaderboardStore` |
| `scripts/data/save_game.gd` | Autoload `SaveGame` |
| `scripts/data/json_file.gd` | `JsonFile` – atomares Schreiben, robustes Lesen |
| `tools/map/network_data.py` | Kompakte Quelldefinition des Netzes (Abschnitte, Radar, Tunnel, Rennen) |
| `tools/map/build_network.py` | Erzeugt `network.json`, setzt Tankstellen, prüft alle Regeln, schreibt die Tabellen unten |
| `tools/map/build_map.mjs` | Erzeugt die Karte und schreibt `map_pos` aller Städte (gleiche Projektion) |
| `tools/map/preview_map.py` | Vorschau-PNG der Karte mit Städten und Etappen (Pillow) |

## Arbeitsablauf

```bash
python3 tools/map/build_network.py --check     # nur Regeln prüfen + Routen ausgeben
python3 tools/map/build_network.py             # data/network.json + Tabellen in docs/daten.md
# Karte (npm-Pakete außerhalb des Repos installieren, node_modules nie einchecken):
cp tools/map/package.json /tmp/maptools/ && npm install --prefix /tmp/maptools
MAP_NODE_MODULES=/tmp/maptools/node_modules node tools/map/build_map.mjs [--width=1000] [--margin-km=170] [--min-area=0.8]
python3 tools/map/preview_map.py /tmp/karte.png --scale=1.4 --race=koenigsrennen   # braucht Pillow
tools/run_tests.sh data                          # Datentests
```

`build_network.py` übernimmt vorhandene `map_pos`-Werte; neue Städte bekommen `[0, 0]`, bis `build_map.mjs`
gelaufen ist (der Test `test_cities_inside_map_and_projection_consistent` meldet das). Die eingecheckte
`network.json` ist maßgeblich – Handänderungen sind erlaubt, sollten aber in `network_data.py` nachgezogen werden.

## Datenformat – Erweiterungen zu ARCHITECTURE.md §4.1

Alle Erweiterungen sind optional; ältere Dateien bleiben gültig.

- `version: 2` (Datei), Städte: `name_local` (Landesname, z. B. „Liège“ für Lüttich).
- Etappen: `roads` (Straßennummern fürs Menü, z. B. „A215 · A7“), `description` (deutsch).
- Abschnitte: `name` (z. B. „A7 Kasseler Berge“) – landet in `StagePlan.sections[i].name`.
- Radar: `"dir": "fwd" | "rev"` – nur in einer Fahrtrichtung (fwd = from→to, rev = to→from). Positionen bleiben
  in km ab `from`. Viele echte Blitzer sind gerichtet; kurze Etappen (Kiel – Hamburg, 95 km) können so in jeder
  Richtung ein Radar haben, obwohl dort kein Ort beide Regeln („nie in den letzten 50 km“) zugleich erfüllt.
- Rennen: `avoid_stages` – Etappen, die das Routing dieses Rennens ignoriert (hält die geplanten Routen
  sauber, siehe unten), `description`.
- Fähren sind in beide Richtungen nutzbar (wie Etappen); `fixed_time_s` = feste Rennzeit, `world_hours` =
  vorrückende Weltzeit.

### Regeln je Etappe (beide Richtungen, `StagePlan.build` ohne Warnungen – getestet)

- Abschnittssumme = `length_km`; Landschaften nur aus der Liste in ARCHITECTURE.md §4.1 (`city` nie manuell);
  `speed_limit: null` (ohne Limit) nur auf deutscher Autobahn; erster/letzter Abschnitt im Land der Start-/Zielstadt.
- Tankstellen alle 60–90 km, die erste spätestens nach 90 km, die letzte ≥ 25 km vor dem Ziel – in beiden
  Richtungen, also zwischen km 26 und Länge−26. Keine Tankspur in Tunneln (neue `StagePlan`-Warnung), Abstand zu
  Radarzonen, Tunneln und Grenzen ≥ 3 km (Generator).
- Radarzonen (5 km) nie in den letzten 50 km (= 20 km City Limits + 30 km davor) einer Richtung: beidseitige
  Radare zwischen km 50 und Länge−55. Das Radarlimit entspricht dem Tempolimit der Abschnitte unter der Zone.
- Tunnel liegen innerhalb der Etappe und überlappen sich nicht; Grenzen ergeben sich aus Länderwechseln.
- `dev`-Etappen (z. B. `dev_testetappe`) werden nur vorwärts geprüft – ihre Testpositionen (Radar bei km 12,
  Tankstelle bei km 20) sind absichtlich kurz hinter dem Start.

## Routing

`GameData.next_options(race_id, current_city, waypoint_index, visited)` (Logik in `RoadNetwork`):

1. Ziele eines Rennens: `race_targets() = waypoints + [finish]`; `waypoint_index` zeigt auf das nächste Ziel
   (`waypoints.size()` = Ziel ist das Finish). Steht man im aktuellen Ziel, wird automatisch weitergezählt.
2. Gesperrt sind alle Städte des **aktuellen Abschnitts** (seit dem letzten erreichten Ziel bzw. dem Start).
   `visited` darf die ganze Route des Rennens sein – frühere Abschnitte dürfen erneut befahren werden
   (Königsrennen: Sofia → Niš → Belgrad zurück).
3. Für jede Verbindung (Etappe in beide Richtungen, Fähre) wird `Länge + kürzester Rest` (Dijkstra, gesperrte
   Städte und `avoid_stages` gemieden) berechnet. Erlaubt ist, was höchstens `routing.detour_tolerance` (0,35)
   über der besten Option liegt; höchstens `routing.max_options`, beste zuerst. Fähren zählen 0 km.
4. Rückgabe je Option: `{kind, id, from, to, length_km, remaining_km, total_km, detour, best, target,
   target_index, via, name, board_key}` (+ `name, fixed_time_s, world_hours` bei Fähren); `[]` nach dem Ziel.

Hilfen für die UI (alle in `GameData`): `race_targets`, `next_target(race_id, idx)`,
`advance_waypoint_index(race_id, city, idx)` (nach jeder Etappe im Rennstand speichern),
`is_race_finished(race_id, city, idx)`, `race_routes(race_id)` (alle fahrbaren Routen: Städte, Etappen, km),
`race_choices(race_id)` (Wahlpunkte), `race_summary(race_id)` (Etappen, min/max km, Länder, Wahlpunkte),
`stage_summary(stage_id, from_city)` (`StagePlan.summary()` + Name, Bestenlisten-Schlüssel, Straßen),
`shortest_path(a, b)`, `board_length_km(key)`, `leg_name(leg)`, `get_stage/get_race/get_ferry`,
`map_size()`, `project_latlon(lat, lon)`, `city_map_pos(id)`, `missing_scenery_ids()`, `validate()`.

**Warum `avoid_stages`?** Das Netz ist in Norddeutschland dicht: Mit den Etappen anderer Rennen (Hannover –
Bremen, Hannover – Dortmund, Kassel – Dortmund) böte Kiel – Nürnberg sonst ungeplante Querwechsel (z. B. in
Dortmund weiter über Kassel, Umweg nur 5 %). Kiel – Nürnberg schließt diese drei Etappen aus und hat so genau die
zwei geplanten Routen. Die Tests prüfen für jedes Rennen, dass nur an den geplanten Orten gewählt werden kann.

**Optionaler Ersatz ohne Neubau:** Eine `network.json` neben der exportierten ausführbaren Datei (oder in
`data/` daneben) ersetzt das eingebaute Netz, wenn sie Städte und Etappen enthält (`GameData.network_source`).

## Balancing der Routenwahl

- **Kiel – Nürnberg** (Wahl in Hamburg): Ost über Hannover – Kassel – Würzburg (A7, 730 km) ist 175 km kürzer,
  hat aber die Kasseler Berge und die Rhön (Hügel 3), mehr Tempolimits, 8 Radarfallen und nur 9 Tankstellen
  (Abstand 70–85 km). West „über Frankfurt“ (A1/A45/A3, 905 km) ist länger und voller (Ruhrgebiet und
  Rhein-Main: Verkehr 1,3–1,6), dafür 508 statt 283 km Autobahn ohne Limit, nur 4 Radarfallen und 12 Tankstellen
  (alle ~60–78 km). Wer schnell fährt und Polizei meidet, holt im Westen auf; sicherer und kürzer ist der Osten.
- **Dresden – Dortmund** (Wahl in Leipzig): Süd über Erfurt/Kassel (Saaletal, Jagdbergtunnel, Hörselberge,
  25 km Landstraße in der Lücke der A44, mehr Radar) gegen Nord über Magdeburg/Hannover (15 km länger, flach,
  viel LKW-Verkehr auf der A2, mehr Tankstellen).
- **München – Bremen** (Wahl in Würzburg): spiegelt Kiel – Nürnberg – über Kassel/Hannover (kürzer, hügelig,
  mehr Radar) oder über Frankfurt/Dortmund (länger, mehr Verkehr, mehr freie Autobahn).
- **Königsrennen** (Wahl in Saragossa): Küste über Barcelona (Autopista, dichter Verkehr um Barcelona,
  7 Radare) oder Pyrenäen über den Somport-Tunnel (50 km länger, ~115 km kurvige Bergstraße, wenig Verkehr,
  4 Radare, mehr Tankstellen).

Das Königsrennen ist mit realistischen Straßenentfernungen rund **9.200 km** lang (Somport-Variante 9.250 km,
40–41 Etappen + Fähre). Das Design-Dokument schätzt 11.000–12.000 km; die Summe der echten Autobahn-Distanzen
der vorgegebenen Stationen liegt aber bei gut 9.000 km – künstliche Umwege wären unrealistisch. Wer mehr will:
weitere Wahlrouten (z. B. Mailand – Sofia über Ancona/Fähre) lassen sich ohne Codeänderung ergänzen.

## Bestenlisten (`Leaderboards`, Logik `LeaderboardStore`)

- Schlüssel `stage:<id>:fwd|rev` und `race:<id>`; Eintrag `{name, time_s, avg_kmh, vehicle, weather,
  start_hour, daytime, date, route?, seeded?}`.
- **Offener Punkt „gemeinsam oder je Fahrzeugtyp?“ – beides:** Mit `leaderboard.store_per_vehicle` behält jede
  Liste die besten `leaderboard.size` (10) **je Fahrzeugtyp**; die Gesamtliste ist darin immer vollständig
  enthalten. Filter `""`/`"all"` = alle Fahrzeuge, sonst Fahrzeug-ID (`Settings.leaderboard_filter`).
- `top(key, filter, count)`, `record(key, filter)`, `would_rank(key, time_s, filter)` (1..10, 0 = kein Platz;
  gleiche Zeit landet hinter bestehenden Einträgen), `submit(key, entry, filter="")` liefert den Rang in der
  gefilterten Liste (= `would_rank` vor dem Aufruf), `rank_for_vehicle(key, time_s, vehicle)`,
  `qualifies(key, time_s, vehicle)` (Namenseingabe, wenn Gesamt- oder Fahrzeugliste erreicht), `board_keys()`.
- **Starteinträge** (`leaderboard.seed_entries`): Eine nie beschriebene Liste bekommt 10 deterministische
  Einträge (Namen aus `seed_names`, Schnitt in `seed_avg_kmh` 150–190 km/h, gemischte Fahrzeuge, `"seeded": true`),
  berechnet aus der Länge der Liste: Etappenlänge bzw. **kürzeste Route** des Rennens. So gibt es immer einen
  Rekord als Laufschrift. Sie werden erst mit dem ersten echten Eintrag gespeichert.
- Datei `user://leaderboards.json`: `{"version": 2, "boards": {…}}`, atomar geschrieben (Temp-Datei + Umbenennen,
  Vorversion als `.bak`). Beschädigte Datei: wird als `.corrupt` aufbewahrt, gelesen wird die `.bak`-Kopie
  (sonst leer); ungültige Einträge werden verworfen. Version 1 (Stub-Format) wird gelesen.

## Spielstand (`SaveGame`)

`save_race(state) -> bool`, `load_race()`, `has_race()`, `clear_race()`; `path` ist änderbar (Tests).
Datei `{"version": 2, "saved_at", "game_version", "race": state}`, atomar mit `.bak`. Beim Laden werden Felder
ergänzt und Typen hergestellt (`waypoint_index`, `seed` als int, Zeiten als float); kaputte Datei → `.bak`,
sonst „kein Spielstand“. `has_race()` prüft im laufenden Spiel zusätzlich, ob Rennen und Stadt noch existieren.

## Karte (`data/map/europe_map.json`)

```json
{ "version": 1, "size": [1000, 777], "projection": "Lambertsche flächentreue Azimutalprojektion …",
  "projection_params": { "type": "azimuthal_equal_area", "center_lonlat": [15, 52], "scale": 2455.99,
                         "translate": [672.0, 291.2], "earth_radius_km": 6371.0088, "km_per_px": 2.594 },
  "source": "…", "countries": [ { "code": "DE", "name": "Deutschland", "name_en": "Germany", "label": [546.9, 328.7],
                                 "polygons": [[[x, y], …], …] } ] }
```

- `name` deutsch (sonst englischer Natural-Earth-Name), `label` = Schwerpunkt des größten Polygons (Anker für
  Ländernamen; bei am Rand abgeschnittenen Ländern nahe am Rand).
- Pixelkoordinaten (y nach unten) im selben Raum wie `cities[].map_pos`; Kartenausschnitt = alle Städte + 170 km
  Rand, 1000 px breit, ~2,6 km/px. 41 Länder mit ISO-3166-Alpha-2-Code (Kosovo = `XK`), nur Außenringe
  (Enklaven entfallen), im Uhrzeigersinn, an den Rand geschnitten, Inseln < 4 px² entfernt. Alle Polygone sind
  mit `Geometry2D.triangulate_polygon` triangulierbar (getestet) – also direkt mit `draw_colored_polygon` /
  `Polygon2D` zeichenbar. ~5.400 Punkte, 76 KiB.
- Projektion: `GameData.project_latlon(lat, lon)` (Formel auch in der Datei), z. B. für Fähr-Linien oder
  zusätzliche Orte. Länderfarben stehen in `countries.json` (`colors`).

## Integration für GameFlow / UI (Kurzfassung)

```gdscript
# Rennstart
var state := {"race_id": id, "vehicle": v, "start_hour": h, "current_city": GameData.get_race(id)["start"],
	"waypoint_index": 0, "legs": [], "total_time_s": 0.0, "world_minutes": h * 60.0,
	"route": [GameData.get_race(id)["start"]], "seed": randi()}
# Vor jeder Etappe: Optionen (1 Option = keine Wahl anzeigen; Fähre = kind "ferry")
var opts := GameData.next_options(state.race_id, state.current_city, state.waypoint_index, state.route)
# Nach der Etappe/Fähre:
state.current_city = leg.to
state.route.append(leg.to)
state.waypoint_index = GameData.advance_waypoint_index(state.race_id, leg.to, state.waypoint_index)
if GameData.is_race_finished(state.race_id, leg.to, state.waypoint_index): pass  # Rennergebnis
SaveGame.save_race(state)
# Bestenlisten
if Leaderboards.qualifies(key, time_s, vehicle): pass  # Namenseingabe
var rank := Leaderboards.submit(key, entry, Settings.leaderboard_filter)
```

Fähren: `fixed_time_s` zur Rennzeit addieren, Weltzeit um `world_hours` vorrücken (keine Etappe, keine
Bestenliste). Für den Etappenbildschirm: `stage_summary()`, `city_map_pos()`, `map_data`; für die Routenwahl:
`next_options()` (inkl. `via`, `remaining_km`, `detour`) und `race_routes()`.

## Lizenzen

- Ländergrenzen: **Natural Earth** 1:50m Admin 0 – Countries, gemeinfrei (public domain), naturalearthdata.com.
- Aufbereitet über npm **world-atlas** 2.0.2 (ISC-Lizenz, © Mike Bostock).
- Werkzeuge (nur zur Erzeugung, nicht im Spiel): topojson-client 3.1.0, topojson-simplify 3.0.3 (ISC),
  d3-geo 3.1.1, d3-geo-projection 4.0.0 (ISC). Die Karte enthält nur abgeleitete Koordinaten.
- Streckendaten (Entfernungen, Abschnitte, Tunnel) sind eigene, gerundete Angaben nach öffentlich bekannten
  Straßenverläufen.

## Netzübersicht

Die folgenden Tabellen erzeugt `tools/map/build_network.py` aus den Daten.

<!-- BEGIN NETZ (generiert von tools/map/build_network.py) -->
### Rennen

| Rennen | Start → Ziel | Pflichtstationen | Routen | km (kürzeste–längste) | Etappen |
|---|---|---|---|---|---|
| Kiel – Nürnberg (`kiel_nuernberg`) | Kiel → Nürnberg | 0 | 2 | 730–905 | 5–6 |
| Dresden – Dortmund (`dresden_dortmund`) | Dresden → Dortmund | 0 | 2 | 580–595 | 4–4 |
| München – Bremen (`muenchen_bremen`) | München → Bremen | 0 | 2 | 780–860 | 5–5 |
| Königsrennen (`koenigsrennen`) | Kiel → Kiel | 17 | 2 | 9.200–9.250 | 40–41 |

**Kiel – Nürnberg** – Routen:

| Route | km | Etappen | frei km | Radar | Tankstellen | Verkehr Ø | max. Hügel | Landstraße km |
|---|---|---|---|---|---|---|---|---|
| über Hannover, Kassel | 730 | 5 | 283 | 8 | 9 | 1,11 | 3 | 0 |
| über Bremen, Dortmund, Frankfurt | 905 | 6 | 508 | 4 | 12 | 1,25 | 2 | 0 |

- 730 km, 5 Etappen: Kiel – Hamburg – Hannover – Kassel – Würzburg – Nürnberg
- 905 km, 6 Etappen: Kiel – Hamburg – Bremen – Dortmund – Frankfurt – Würzburg – Nürnberg
- Wahlpunkte: Hamburg → Hannover / Bremen

**Dresden – Dortmund** – Routen:

| Route | km | Etappen | frei km | Radar | Tankstellen | Verkehr Ø | max. Hügel | Landstraße km |
|---|---|---|---|---|---|---|---|---|
| über Erfurt, Kassel | 580 | 4 | 310 | 5 | 7 | 1,13 | 2 | 25 |
| über Magdeburg, Hannover | 595 | 4 | 327 | 4 | 8 | 1,29 | 2 | 0 |

- 580 km, 4 Etappen: Dresden – Leipzig – Erfurt – Kassel – Dortmund
- 595 km, 4 Etappen: Dresden – Leipzig – Magdeburg – Hannover – Dortmund
- Wahlpunkte: Leipzig → Erfurt / Magdeburg

**München – Bremen** – Routen:

| Route | km | Etappen | frei km | Radar | Tankstellen | Verkehr Ø | max. Hügel | Landstraße km |
|---|---|---|---|---|---|---|---|---|
| über Kassel, Hannover | 780 | 5 | 350 | 8 | 10 | 1,12 | 3 | 0 |
| über Frankfurt, Dortmund | 860 | 5 | 500 | 4 | 11 | 1,26 | 2 | 0 |

- 780 km, 5 Etappen: München – Nürnberg – Würzburg – Kassel – Hannover – Bremen
- 860 km, 5 Etappen: München – Nürnberg – Würzburg – Frankfurt – Dortmund – Bremen
- Wahlpunkte: Würzburg → Kassel / Frankfurt

**Königsrennen** – Routen:

| Route | km | Etappen | frei km | Radar | Tankstellen | Verkehr Ø | max. Hügel | Landstraße km |
|---|---|---|---|---|---|---|---|---|
| über Barcelona | 9.200 | 40 | 548 | 85 | 123 | 1,10 | 3 | 267 |
| über Pau, Toulouse | 9.250 | 41 | 548 | 82 | 125 | 1,09 | 3 | 382 |

- 9.200 km, 40 Etappen: Kiel – Hamburg – Bremen – Groningen – Amsterdam – Lüttich – Valenciennes – Paris – Tours – Bordeaux – San Sebastián – Burgos – Madrid – Saragossa – Barcelona – Montpellier – Lyon – Bern – Mailand – Venedig – Ljubljana – Zagreb – Slavonski Brod – Belgrad – Niš – Sofia – Niš – Belgrad – Szeged – Budapest – Wien – Prag – Dresden – Leipzig – Berlin – Posen – Warschau – Białystok – Kaunas – Riga – Rostock – Kiel
- 9.250 km, 41 Etappen: Kiel – Hamburg – Bremen – Groningen – Amsterdam – Lüttich – Valenciennes – Paris – Tours – Bordeaux – San Sebastián – Burgos – Madrid – Saragossa – Pau – Toulouse – Montpellier – Lyon – Bern – Mailand – Venedig – Ljubljana – Zagreb – Slavonski Brod – Belgrad – Niš – Sofia – Niš – Belgrad – Szeged – Budapest – Wien – Prag – Dresden – Leipzig – Berlin – Posen – Warschau – Białystok – Kaunas – Riga – Rostock – Kiel
- Wahlpunkte: Saragossa → Barcelona / Pau

### Etappen

Radar = Radarfallen vorwärts/rückwärts, Tank = Tankstellen, Verkehr = längengewichteter Faktor, frei = Autobahn ohne Tempolimit.

| Etappe (`id`) | Straßen | km | Länder | Autobahn / frei km | Radar | Tank | Tunnel | Verkehr |
|---|---|---|---|---|---|---|---|---|
| Kiel – Hamburg (`kiel_hamburg`) | A215 · A7 | 95 | DE | 95 / 33 | 1/1 | 1 | – | 1,10 |
| Hamburg – Hannover (`hamburg_hannover`) | A7 | 150 | DE | 150 / 75 | 2/2 | 2 | Elbtunnel (3,3 km) | 1,12 |
| Hannover – Kassel (`hannover_kassel`) | A7 | 165 | DE | 165 / 65 | 1/2 | 2 | – | 1,10 |
| Kassel – Würzburg (`kassel_wuerzburg`) | A7 | 210 | DE | 210 / 70 | 3/3 | 3 | – | 1,06 |
| Hamburg – Bremen (`hamburg_bremen`) | A1 | 120 | DE | 120 / 80 | 0/0 | 2 | – | 1,25 |
| Bremen – Dortmund (`bremen_dortmund`) | A1 | 235 | DE | 235 / 150 | 1/1 | 3 | – | 1,24 |
| Dortmund – Frankfurt (`dortmund_frankfurt`) | A45 · A5 | 225 | DE | 225 / 135 | 1/1 | 3 | – | 1,34 |
| Frankfurt – Würzburg (`frankfurt_wuerzburg`) | A3 | 120 | DE | 120 / 70 | 0/0 | 2 | – | 1,27 |
| Würzburg – Nürnberg (`wuerzburg_nuernberg`) | A3 | 110 | DE | 110 / 40 | 1/1 | 1 | – | 1,19 |
| München – Nürnberg (`muenchen_nuernberg`) | A9 | 170 | DE | 170 / 105 | 1/1 | 2 | – | 1,21 |
| Hannover – Bremen (`hannover_bremen`) | A7 · A27 | 125 | DE | 125 / 70 | 1/1 | 2 | – | 1,10 |
| Dresden – Leipzig (`dresden_leipzig`) | A4 · A14 | 115 | DE | 115 / 65 | 1/1 | 1 | – | 1,15 |
| Leipzig – Erfurt (`leipzig_erfurt`) | A9 · A4 | 150 | DE | 150 / 65 | 1/1 | 2 | Jagdbergtunnel (3,1 km) | 1,15 |
| Erfurt – Kassel (`erfurt_kassel`) | A4 · B7 · A44 | 155 | DE | 130 / 75 | 2/2 | 2 | – | 1,06 |
| Kassel – Dortmund (`kassel_dortmund`) | A44 | 160 | DE | 160 / 105 | 1/1 | 2 | – | 1,17 |
| Leipzig – Magdeburg (`leipzig_magdeburg`) | A14 | 125 | DE | 125 / 67 | 1/1 | 2 | – | 1,17 |
| Magdeburg – Hannover (`magdeburg_hannover`) | A2 | 145 | DE | 145 / 85 | 1/1 | 2 | – | 1,36 |
| Hannover – Dortmund (`hannover_dortmund`) | A2 | 210 | DE | 210 / 110 | 1/1 | 3 | – | 1,39 |
| Bremen – Groningen (`bremen_groningen`) | A28 · A31 · A7 (NL) | 180 | DE → NL | 180 / 80 | 1/2 | 2 | Emstunnel (0,9 km) | 1,01 |
| Groningen – Amsterdam (`groningen_amsterdam`) | A7 · A6 · A10 | 185 | NL | 185 / 0 | 2/2 | 3 | – | 1,15 |
| Amsterdam – Lüttich (`amsterdam_luettich`) | A2 · E25 | 235 | NL → BE | 235 / 0 | 2/2 | 3 | Koning-Willem-Alexander-Tunnel (2,3 km) | 1,26 |
| Lüttich – Valenciennes (`luettich_valenciennes`) | E42 · E19 · A2 | 190 | BE → FR | 190 / 0 | 2/2 | 3 | – | 1,18 |
| Valenciennes – Paris (`valenciennes_paris`) | A2 · A1 | 205 | FR | 205 / 0 | 2/3 | 3 | Tunnel du Landy (1,3 km) | 1,15 |
| Paris – Tours (`paris_tours`) | A10 | 240 | FR | 240 / 0 | 2/2 | 3 | – | 1,10 |
| Tours – Bordeaux (`tours_bordeaux`) | A10 | 345 | FR | 345 / 0 | 3/3 | 5 | – | 1,01 |
| Bordeaux – San Sebastián (`bordeaux_san_sebastian`) | A63 · AP-8 | 240 | FR → ES | 240 / 0 | 2/2 | 3 | – | 1,12 |
| San Sebastián – Burgos (`san_sebastian_burgos`) | A-15 · A-1 · AP-1 | 225 | ES | 225 / 0 | 2/2 | 3 | – | 1,06 |
| Burgos – Madrid (`burgos_madrid`) | A-1 | 240 | ES | 240 / 0 | 2/2 | 3 | – | 1,04 |
| Madrid – Saragossa (`madrid_saragossa`) | A-2 | 315 | ES | 315 / 0 | 3/3 | 4 | – | 1,04 |
| Saragossa – Barcelona (`saragossa_barcelona`) | AP-2 · AP-7 | 300 | ES | 300 / 0 | 3/3 | 4 | – | 1,08 |
| Barcelona – Montpellier (`barcelona_montpellier`) | AP-7 · A9 | 350 | ES → FR | 350 / 0 | 4/4 | 5 | – | 1,13 |
| Saragossa – Pau (`saragossa_pau`) | A-23 · N-330 · N134 | 260 | ES → FR | 145 / 0 | 1/1 | 4 | Somport-Tunnel (8,6 km) | 0,82 |
| Pau – Toulouse (`pau_toulouse`) | A64 | 195 | FR | 195 / 0 | 1/1 | 3 | – | 1,04 |
| Toulouse – Montpellier (`toulouse_montpellier`) | A61 · A9 | 245 | FR | 245 / 0 | 2/2 | 4 | – | 1,10 |
| Montpellier – Lyon (`montpellier_lyon`) | A9 · A7 | 305 | FR | 305 / 0 | 3/3 | 4 | – | 1,33 |
| Lyon – Bern (`lyon_bern`) | A42 · A40 · A1 · A12 | 310 | FR → CH | 310 / 0 | 3/3 | 4 | Tunnel de Chamoise (3,3 km) | 1,17 |
| Bern – Mailand (`bern_mailand`) | A1 · A2 · A9 (I) | 365 | CH → IT | 348 / 0 | 3/4 | 5 | Sonnenbergtunnel (1,5 km), Seelisbergtunnel (9,3 km), Gotthard-Strassentunnel (16,9 km) | 1,18 |
| Mailand – Venedig (`mailand_venedig`) | A4 | 275 | IT | 275 / 0 | 3/3 | 4 | – | 1,31 |
| Venedig – Ljubljana (`venedig_ljubljana`) | A4 · RA13 · A3/A1 (SI) | 245 | IT → SI | 245 / 0 | 2/2 | 3 | – | 1,11 |
| Ljubljana – Zagreb (`ljubljana_zagreb`) | A2 (SI) · A3 (HR) | 140 | SI → HR | 140 / 0 | 1/1 | 2 | – | 1,12 |
| Zagreb – Slavonski Brod (`zagreb_slavonski_brod`) | A3 | 195 | HR | 195 / 0 | 2/2 | 3 | – | 0,93 |
| Slavonski Brod – Belgrad (`slavonski_brod_belgrad`) | A3 | 205 | HR → RS | 205 / 0 | 2/2 | 3 | – | 1,01 |
| Belgrad – Niš (`belgrad_nis`) | A1 | 240 | RS | 240 / 0 | 2/2 | 3 | – | 1,01 |
| Niš – Sofia (`nis_sofia`) | A4 · I-8 · A6 | 155 | RS → BG | 125 / 0 | 1/1 | 2 | – | 0,96 |
| Belgrad – Szeged (`belgrad_szeged`) | A1 · M5 | 230 | RS → HU | 230 / 0 | 2/2 | 3 | – | 1,01 |
| Szeged – Budapest (`szeged_budapest`) | M5 | 170 | HU | 170 / 0 | 2/2 | 2 | – | 1,11 |
| Budapest – Wien (`budapest_wien`) | M1 · A4 | 245 | HU → AT | 245 / 0 | 3/3 | 3 | – | 1,15 |
| Wien – Prag (`wien_prag`) | A5 · I/52 · D52 · D1 | 335 | AT → CZ | 305 / 0 | 4/3 | 4 | – | 1,20 |
| Prag – Dresden (`prag_dresden`) | D8 · A17 | 150 | CZ → DE | 150 / 0 | 1/2 | 2 | Tunel Radejčín (0,6 km), Tunnel Dölzschen (1,1 km) | 1,12 |
| Leipzig – Berlin (`leipzig_berlin`) | A9 · A10 · A115 | 190 | DE | 190 / 105 | 1/2 | 3 | – | 1,18 |
| Berlin – Posen (`berlin_posen`) | A12 · A2 (PL) | 270 | DE → PL | 270 / 45 | 3/3 | 4 | – | 1,13 |
| Posen – Warschau (`posen_warschau`) | A2 | 305 | PL | 305 / 0 | 3/3 | 4 | – | 1,10 |
| Warschau – Białystok (`warschau_bialystok`) | S8 | 200 | PL | 200 / 0 | 2/2 | 3 | – | 1,03 |
| Białystok – Kaunas (`bialystok_kaunas`) | S8 · S61 · A5 (LT) | 230 | PL → LT | 195 / 0 | 2/2 | 3 | – | 0,95 |
| Kaunas – Riga (`kaunas_riga`) | A8 · A10 (LT) · A7 (LV) | 255 | LT → LV | 130 / 0 | 3/3 | 3 | – | 0,95 |
| Rostock – Kiel (`rostock_kiel`) | A20 · A21 | 210 | DE | 210 / 140 | 2/2 | 3 | – | 0,97 |

Fähren: Fähre Riga – Rostock (`riga_rostock`, 240 s Rennzeit, 24 h Weltzeit)

Summe aller Etappen: 11.960 km in 56 Etappen, 50 Städte.
<!-- END NETZ -->
