class_name SampleData
extends RefCounted
## Sample data for the debug screens (CLI --screen=<name>): a small synthetic network around
## Kiel – Nürnberg (only used while the real data/network.json is still sparse), generated
## leaderboard entries and race states/results built by simulating stages with plausible times.

const CITIES := [
	["kiel", "Kiel", "DE", 54.323, 10.123], ["hamburg", "Hamburg", "DE", 53.551, 9.994],
	["bremen", "Bremen", "DE", 53.079, 8.802], ["hannover", "Hannover", "DE", 52.375, 9.732],
	["berlin", "Berlin", "DE", 52.520, 13.405], ["rostock", "Rostock", "DE", 54.092, 12.099],
	["leipzig", "Leipzig", "DE", 51.340, 12.375], ["dresden", "Dresden", "DE", 51.050, 13.738],
	["kassel", "Kassel", "DE", 51.312, 9.479], ["dortmund", "Dortmund", "DE", 51.514, 7.466],
	["koeln", "Köln", "DE", 50.938, 6.960], ["frankfurt", "Frankfurt", "DE", 50.110, 8.682],
	["wuerzburg", "Würzburg", "DE", 49.791, 9.953], ["nuernberg", "Nürnberg", "DE", 49.452, 11.077],
	["muenchen", "München", "DE", 48.137, 11.576], ["amsterdam", "Amsterdam", "NL", 52.370, 4.895],
	["riga", "Riga", "LV", 56.946, 24.106],
]
## id, from, to, km, unlimited share, curviness, hills, scenery, traffic, radar count, tunnel
const STAGES := [
	["kiel_hamburg", "kiel", "hamburg", 95, 0.8, 1, 1, "north_plain", 1.0, 1, false],
	["hamburg_bremen", "hamburg", "bremen", 120, 0.5, 1, 0, "heath", 1.1, 1, false],
	["hamburg_hannover", "hamburg", "hannover", 155, 0.55, 1, 1, "heath", 1.0, 1, false],
	["hamburg_berlin", "hamburg", "berlin", 290, 0.7, 1, 0, "north_plain", 0.8, 2, false],
	["bremen_hannover", "bremen", "hannover", 125, 0.4, 1, 0, "north_plain", 1.0, 1, false],
	["bremen_dortmund", "bremen", "dortmund", 235, 0.35, 1, 1, "industrial", 1.4, 2, false],
	["hannover_kassel", "hannover", "kassel", 165, 0.45, 2, 2, "forest_hills", 1.0, 2, true],
	["hannover_berlin", "hannover", "berlin", 285, 0.65, 1, 0, "north_plain", 0.9, 2, false],
	["hannover_leipzig", "hannover", "leipzig", 265, 0.5, 1, 1, "farmland_fr", 0.9, 2, false],
	["kassel_frankfurt", "kassel", "frankfurt", 190, 0.3, 2, 2, "forest_hills", 1.3, 3, true],
	["kassel_wuerzburg", "kassel", "wuerzburg", 210, 0.5, 2, 2, "forest_hills", 0.85, 2, true],
	["dortmund_koeln", "dortmund", "koeln", 95, 0.2, 1, 1, "industrial", 1.6, 1, false],
	["koeln_frankfurt", "koeln", "frankfurt", 190, 0.3, 2, 2, "rhine_main", 1.3, 2, true],
	["frankfurt_wuerzburg", "frankfurt", "wuerzburg", 120, 0.25, 1, 1, "rhine_main", 1.4, 2, false],
	["wuerzburg_nuernberg", "wuerzburg", "nuernberg", 110, 0.6, 1, 1, "farmland_fr", 0.9, 1, false],
	["leipzig_nuernberg", "leipzig", "nuernberg", 280, 0.55, 2, 2, "forest_hills", 0.8, 2, true],
	["berlin_leipzig", "berlin", "leipzig", 190, 0.7, 0, 0, "east_plain", 0.8, 1, false],
	["leipzig_dresden", "leipzig", "dresden", 115, 0.6, 1, 1, "east_plain", 0.8, 1, false],
	["nuernberg_muenchen", "nuernberg", "muenchen", 170, 0.45, 1, 1, "farmland_fr", 1.1, 2, false],
	["berlin_rostock", "berlin", "rostock", 230, 0.75, 0, 0, "north_plain", 0.7, 1, false],
	["amsterdam_dortmund", "amsterdam", "dortmund", 225, 0.3, 0, 0, "polder", 1.3, 2, false],
]


## Synthetic network in the format of GameData (+ "race_order").
static func network() -> Dictionary:
	var cities := {}
	for c in CITIES:
		var pos := MapView.project_latlon(float(c[3]), float(c[4]))
		cities[c[0]] = {"id": c[0], "name": c[1], "country": c[2], "latlon": [c[3], c[4]], "map_pos": [pos.x, pos.y]}
	var stages := {}
	for s in STAGES:
		var km := float(s[3])
		var unl := float(s[4])
		var secs: Array = []
		var country_to := str(cities[s[2]]["country"])
		var country_from := str(cities[s[1]]["country"])
		if country_from != country_to:
			secs.append({"length_km": km * 0.45, "road": "autobahn", "curviness": s[5], "hills": s[6], "scenery": s[7], "country": country_from, "speed_limit": 130, "traffic": s[8]})
			secs.append({"length_km": km * 0.55, "road": "autobahn", "curviness": s[5], "hills": s[6], "scenery": s[7], "country": country_to, "speed_limit": null, "traffic": s[8]})
		else:
			secs.append({"length_km": km * unl, "road": "autobahn", "curviness": s[5], "hills": s[6], "scenery": s[7], "country": country_from, "speed_limit": null, "traffic": s[8]})
			secs.append({"length_km": km * (1.0 - unl) * 0.6, "road": "autobahn", "curviness": s[5], "hills": s[6], "scenery": s[7], "country": country_from, "speed_limit": 120, "traffic": s[8] * 1.1})
			secs.append({"length_km": km * (1.0 - unl) * 0.4, "road": "landstrasse", "curviness": mini(int(s[5]) + 1, 3), "hills": s[6], "scenery": s[7], "country": country_from, "traffic": s[8]})
		var radars: Array = []
		for i in int(s[9]):
			radars.append({"km": km * (0.12 + 0.25 * i), "limit": 120})
		var tunnels: Array = []
		if bool(s[10]):
			tunnels.append({"km": km * 0.42, "length_km": 2.5, "name": "Tunnel"})
		stages[s[0]] = {"id": s[0], "from": s[1], "to": s[2], "length_km": km, "sections": secs,
			"radars": radars, "tunnels": tunnels, "borders": [], "seed": absi(hash(s[0])) % 100000}
	var ferries := {"riga_rostock": {"id": "riga_rostock", "from": "riga", "to": "rostock", "name": "Fähre Riga – Rostock", "fixed_time_s": 240, "world_hours": 24}}
	var races := {
		"kiel_nuernberg": {"id": "kiel_nuernberg", "name": "Kiel – Nürnberg", "start": "kiel", "finish": "nuernberg", "waypoints": [], "description": "Der Klassiker quer durch Deutschland: über Kassel oder über Frankfurt?"},
		"dresden_dortmund": {"id": "dresden_dortmund", "name": "Dresden – Dortmund", "start": "dresden", "finish": "dortmund", "waypoints": [], "description": "Von der Elbe ins Ruhrgebiet."},
		"muenchen_bremen": {"id": "muenchen_bremen", "name": "München – Bremen", "start": "muenchen", "finish": "bremen", "waypoints": ["kassel"], "description": "Einmal von Süd nach Nord – Pflichtstation Kassel."},
	}
	return {"cities": cities, "stages": stages, "ferries": ferries, "races": races,
		"race_order": ["kiel_nuernberg", "dresden_dortmund", "muenchen_bremen"]}


## True if the real network is too sparse for meaningful debug screens.
static func real_network_sparse(real_cities: Dictionary) -> bool:
	var n := 0
	for id in real_cities:
		if not bool(real_cities[id].get("dev", false)):
			n += 1
	return n < 6


## Ten plausible entries for a board key ("stage:<id>:fwd|rev" or "race:<id>").
static func board_entries(board_key: String, config: Dictionary) -> Array:
	var length := 200.0
	var parts := board_key.split(":")
	if parts.size() >= 2 and parts[0] == "stage":
		length = float(UiData.stages().get(parts[1], {}).get("length_km", 200.0))
	elif parts.size() >= 2 and parts[0] == "race":
		var st := UiData.race_summary(parts[1])
		length = maxf(float(st.get("min_km", 0.0)), 300.0)
	var names: Array = ConfigLoader.lookup(config, "leaderboard.seed_names", ["Anke", "Bernd", "Clara", "Dieter", "Elif", "Frank", "Gabi", "Hakan", "Ines", "Jörg"])
	var vehicles: Array = ConfigLoader.lookup(config, "vehicles.order", ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"])
	var ts := float(ConfigLoader.lookup(config, "time.time_scale", 12.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(board_key))
	var out: Array = []
	var avg := rng.randf_range(196.0, 204.0)
	for i in 10:
		avg -= rng.randf_range(1.5, 6.5)
		var hour := float(rng.randi_range(0, 47)) * 0.5
		var w_roll := rng.randf()
		var weather := "normal" if w_roll < 0.7 else ("rain" if w_roll < 0.92 else "snow")
		var entry := {
			"name": str(names[(i + rng.randi_range(0, 9)) % names.size()]),
			"time_s": Units.game_seconds_for(length, avg, ts),
			"avg_kmh": avg,
			"vehicle": str(vehicles[rng.randi_range(0, vehicles.size() - 1)]),
			"weather": weather,
			"start_hour": hour,
			"daytime": WorldClock.daytime_category(hour, config),
			"date": "2026-10-%02d" % rng.randi_range(1, 29),
		}
		out.append(entry)
	return out


## Race state after `stages_done` simulated stages of a race (first option at every junction).
static func race_state(race_id: String, stages_done: int, config: Dictionary) -> RaceState:
	var race := UiData.race(race_id)
	var s := RaceState.create(race, "sportwagen", 7.5, 4711)
	var ts := float(ConfigLoader.lookup(config, "time.time_scale", 12.0))
	var avgs := [182.0, 176.5, 191.2, 169.8, 187.3, 179.9, 184.0, 172.6]
	var guard := 0
	while not s.is_finished() and s.stage_count() < stages_done and guard < 200:   # Königsrennen: 40 stages + ferry
		guard += 1
		var opts := UiData.next_options(s.race_id, s.current_city, s.waypoint_index, s.visited())
		if opts.is_empty():
			break
		var leg: Dictionary = opts[0]
		if str(leg.get("kind", "stage")) == "ferry":
			s.apply_ferry(UiData.ferries().get(str(leg["id"]), {}), leg)
			continue
		var km := float(leg.get("length_km", 150.0))
		var avg: float = avgs[s.stage_count() % avgs.size()]
		var t := Units.game_seconds_for(km, avg, ts)
		var weather: String = ["normal", "rain", "normal", "snow", "normal"][s.stage_count() % 5]
		var res := {"stage_id": leg["id"], "from_city": leg["from"], "to_city": leg["to"], "time_s": t, "penalty_s": 0.0,
			"avg_speed_kmh": avg, "distance_km": km, "weather": weather, "start_world_minutes": s.world_minutes,
			"end_world_minutes": s.world_minutes + Units.world_minutes_delta(t, ts),
			"stage_name": "%s – %s" % [UiData.city_name(str(leg["from"])), UiData.city_name(str(leg["to"]))]}
		s.apply_stage_result(leg, res, config)
	return s


static func saved_race() -> Dictionary:
	var ids := UiData.visible_race_ids()
	if ids.is_empty():
		return {}
	return race_state(ids[0], 1, UiData.cfg()).to_dict()


## A finished stage result (race session format) for the result screen.
static func stage_result(stage_id: String, from_city: String, config: Dictionary, fast: bool = true) -> Dictionary:
	var plan := UiData.stage_plan(stage_id, from_city)
	var km := plan.length_km if plan != null else 155.0
	var ts := float(ConfigLoader.lookup(config, "time.time_scale", 12.0))
	var board := plan.board_key if plan != null else "stage:%s:fwd" % stage_id
	var rec := UiData.record(board)
	var t := Units.game_seconds_for(km, 188.0, ts)
	if fast and not rec.is_empty():
		t = float(rec["time_s"]) * 1.012
	return {
		"board_key": board, "stage_id": stage_id, "from_city": from_city,
		"to_city": plan.to_id if plan != null else "", "stage_name": plan.display_name if plan != null else stage_id,
		"time_s": t + 12.5, "penalty_s": 12.5, "avg_speed_kmh": Units.avg_speed_kmh(km, t + 12.5, ts), "distance_km": km,
		"vehicle": "sportwagen", "weather": "rain", "start_world_minutes": 7.5 * 60.0,
		"end_world_minutes": 7.5 * 60.0 + Units.world_minutes_delta(t, ts), "start_hour": 7.5, "daytime": "day",
		"collisions": 2, "refuels": 1, "liters_refueled": 38.4, "radar_flashes": 1, "police_stops": 0,
		"police_escapes": 1, "tow_events": 0, "aborted": false,
	}
