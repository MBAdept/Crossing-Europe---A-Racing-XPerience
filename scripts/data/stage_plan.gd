class_name StagePlan
extends RefCounted
## One stage resolved for a driving direction. Built by GameData.get_stage_plan() via StagePlan.build().
## All positions are odometer km from the start of the stage in driving direction.
## Stages are defined once in data/network.json and can be driven in both directions;
## in reverse direction sections are reversed and all positions mirrored.
## Design rules enforced here (violations are dropped and reported in `warnings`):
##  * last fuel station at least fuel.last_station_min_before_end_km before the finish (and never in City Limits)
##  * no radar zone in the last radar.no_radar_before_city_km before the City Limits
##  * City Limits = last city_limits.length_km of the stage

var stage_id := ""
var reversed := false
var board_key := ""            ## leaderboard key "stage:<id>:fwd" / "stage:<id>:rev"
var from_id := ""
var to_id := ""
var from_name := ""
var to_name := ""
var display_name := ""         ## "Kiel – Hamburg"
var length_km := 0.0
## Normalized sections: {start_km, end_km, length_km, road, curviness, hills, scenery, country,
## speed_limit (int km/h, 0 = no limit), traffic (density factor)}
var sections: Array[Dictionary] = []
var fuel_stations_km: Array[float] = []
## Fuel lanes: {station_km, start_km, end_km}. The lane is the last 1–2 km before the station (right side).
var fuel_lanes: Array[Dictionary] = []
## Radar zones: {km (zone start), end_km, limit (km/h), warn_km (where the 10-km warning appears)}
var radars: Array[Dictionary] = []
## Tunnels: {start_km, end_km, name}
var tunnels: Array[Dictionary] = []
## Border crossings: {km, from, to (country codes), name, name_local (of the country entered)}
var borders: Array[Dictionary] = []
var city_limits_km := 0.0      ## start of the City Limits
var city_speed_limit := 50
var climate := "default"       ## climate of the dominant country (weather picking)
var countries_in_order: Array[String] = []
var weather_hint := ""         ## optional fixed weather from the data ("weather" field)
var seed := 0
var dev := false
var warnings: Array[String] = []


static func build(stage: Dictionary, from_city_id: String, cities: Dictionary, countries: Dictionary, cfg: Dictionary) -> StagePlan:
	var p := StagePlan.new()
	p.stage_id = str(stage.get("id", ""))
	p.dev = bool(stage.get("dev", false))
	var a := str(stage.get("from", ""))
	var b := str(stage.get("to", ""))
	if from_city_id == "" or from_city_id == a:
		p.reversed = false
	elif from_city_id == b:
		p.reversed = true
	else:
		p.warnings.append("Etappe %s beginnt nicht in %s – fahre vorwärts" % [p.stage_id, from_city_id])
	p.from_id = b if p.reversed else a
	p.to_id = a if p.reversed else b
	p.from_name = str(cities.get(p.from_id, {}).get("name", p.from_id))
	p.to_name = str(cities.get(p.to_id, {}).get("name", p.to_id))
	p.display_name = "%s – %s" % [p.from_name, p.to_name]
	p.board_key = "stage:%s:%s" % [p.stage_id, "rev" if p.reversed else "fwd"]
	p.weather_hint = str(stage.get("weather", ""))
	var base_seed := int(stage.get("seed", abs(hash(p.stage_id))))
	p.seed = (base_seed ^ 0x5bd1e995) & 0x7fffffff if p.reversed else base_seed & 0x7fffffff

	_build_sections(p, stage, cities, countries)
	var city_len := float(ConfigLoader.lookup(cfg, "city_limits.length_km", 20.0))
	p.city_limits_km = maxf(0.0, p.length_km - city_len)
	var last_country := p.country_at(p.length_km)
	var city_limit: Variant = countries.get(last_country, {}).get("limits", {}).get("city", 50)
	p.city_speed_limit = 50 if city_limit == null else int(city_limit)
	_build_stations(p, stage, cfg)
	_build_radars(p, stage, cfg, countries)
	_build_tunnels(p, stage)
	_build_borders(p, stage, countries)
	_compute_climate(p, countries)
	return p


static func _build_sections(p: StagePlan, stage: Dictionary, cities: Dictionary, countries: Dictionary) -> void:
	var raw: Array = stage.get("sections", [])
	var total := 0.0
	for s in raw:
		total += float(s.get("length_km", 0.0))
	p.length_km = float(stage.get("length_km", total))
	if p.length_km <= 0.0:
		p.length_km = maxf(total, 1.0)
		p.warnings.append("Etappe %s ohne Länge" % p.stage_id)
	if raw.is_empty():
		raw = [{"length_km": p.length_km}]
		total = p.length_km
	var scale := 1.0
	if absf(total - p.length_km) > 0.5 and total > 0.0:
		p.warnings.append("Etappe %s: Abschnitte %.1f km ≠ Länge %.1f km – skaliert" % [p.stage_id, total, p.length_km])
		scale = p.length_km / total
	var secs: Array = raw.duplicate(true)
	if p.reversed:
		secs.reverse()
	var default_country := str(cities.get(p.from_id, {}).get("country", "DE"))
	var km := 0.0
	for s: Dictionary in secs:
		var length := float(s.get("length_km", 0.0)) * scale
		var country := str(s.get("country", default_country))
		var road := str(s.get("road", "autobahn"))
		var limit := 0
		if s.has("speed_limit"):
			limit = 0 if s["speed_limit"] == null else int(s["speed_limit"])
		else:
			var def: Variant = countries.get(country, {}).get("limits", {}).get(road, null)
			limit = 0 if def == null else int(def)
		p.sections.append({
			"start_km": km, "end_km": km + length, "length_km": length,
			"road": road,
			"curviness": clampi(int(s.get("curviness", 1)), 0, 3),
			"hills": clampi(int(s.get("hills", 1)), 0, 3),
			"scenery": str(s.get("scenery", "north_plain")),
			"country": country,
			"speed_limit": limit,
			"traffic": float(s.get("traffic", 1.0)),
		})
		km += length
	if not p.sections.is_empty():
		p.sections[-1]["end_km"] = p.length_km
		p.sections[-1]["length_km"] = p.length_km - float(p.sections[-1]["start_km"])


static func _build_stations(p: StagePlan, stage: Dictionary, cfg: Dictionary) -> void:
	var min_before_end := float(ConfigLoader.lookup(cfg, "fuel.last_station_min_before_end_km", 25.0))
	var last_ok := minf(p.length_km - min_before_end, p.city_limits_km)
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed + 101
	var raw: Array = []
	if stage.has("fuel_stations_km"):
		raw = stage["fuel_stations_km"]
	else:
		var spacing: Array = ConfigLoader.lookup(cfg, "fuel.station_spacing_km", [60, 90])
		var k := rng.randf_range(float(spacing[0]), float(spacing[1]))
		while k <= last_ok:
			raw.append(k if not p.reversed else p.length_km - k)
			k += rng.randf_range(float(spacing[0]), float(spacing[1]))
	var lane_len: Array = ConfigLoader.lookup(cfg, "fuel.lane_length_km", [1.0, 2.0])
	var out: Array[float] = []
	for v in raw:
		var km := float(v)
		if p.reversed:
			km = p.length_km - km
		if km < 2.0 or km > last_ok:
			p.warnings.append("Tankstelle bei km %.1f verworfen (Regel: spätestens %.0f km vor dem Ziel, nicht in den City Limits)" % [km, min_before_end])
			continue
		out.append(km)
	out.sort()
	p.fuel_stations_km = out
	for km in out:
		var length := rng.randf_range(float(lane_len[0]), float(lane_len[1]))
		p.fuel_lanes.append({"station_km": km, "start_km": maxf(0.0, km - length), "end_km": km})


static func _build_radars(p: StagePlan, stage: Dictionary, cfg: Dictionary, countries: Dictionary) -> void:
	var zone := float(ConfigLoader.lookup(cfg, "radar.zone_length_km", 5.0))
	var warn := float(ConfigLoader.lookup(cfg, "radar.warning_km", 10.0))
	var gap := float(ConfigLoader.lookup(cfg, "radar.no_radar_before_city_km", 30.0))
	var default_limit := int(ConfigLoader.lookup(cfg, "radar.default_limit_kmh", 120))
	var max_end := p.city_limits_km - gap
	for r: Dictionary in stage.get("radars", []):
		var km := float(r.get("km", 0.0))
		var start := (p.length_km - km - zone) if p.reversed else km
		start = maxf(0.0, start)
		if start + zone > max_end + 0.001:
			p.warnings.append("Radar bei km %.1f verworfen (keine Radarfallen in den letzten %.0f km vor den City Limits)" % [start, gap])
			continue
		var limit := 0
		if r.has("limit") and r["limit"] != null:
			limit = int(r["limit"])
		else:
			limit = int(p.section_at(start).get("speed_limit", 0))
		if limit <= 0:
			limit = default_limit
			p.warnings.append("Radar bei km %.1f ohne Tempolimit – nutze %d" % [start, limit])
		p.radars.append({"km": start, "end_km": start + zone, "limit": limit, "warn_km": maxf(0.0, start - warn)})
	p.radars.sort_custom(func(x, y): return float(x["km"]) < float(y["km"]))


static func _build_tunnels(p: StagePlan, stage: Dictionary) -> void:
	for t: Dictionary in stage.get("tunnels", []):
		var km := float(t.get("km", 0.0))
		var length := float(t.get("length_km", 1.0))
		var start := (p.length_km - km - length) if p.reversed else km
		start = clampf(start, 0.0, p.length_km)
		p.tunnels.append({"start_km": start, "end_km": minf(start + length, p.length_km), "name": str(t.get("name", ""))})
	p.tunnels.sort_custom(func(x, y): return float(x["start_km"]) < float(y["start_km"]))


static func _build_borders(p: StagePlan, stage: Dictionary, countries: Dictionary) -> void:
	var kms: Array[float] = []
	for bd: Dictionary in stage.get("borders", []):
		var km := float(bd.get("km", 0.0))
		kms.append(p.length_km - km if p.reversed else km)
	# Every change of country between sections is a border crossing, even if not listed explicitly.
	for i in range(1, p.sections.size()):
		if p.sections[i]["country"] != p.sections[i - 1]["country"]:
			var km := float(p.sections[i]["start_km"])
			var known := false
			for k in kms:
				if absf(k - km) < 1.0:
					known = true
			if not known:
				kms.append(km)
	kms.sort()
	for km in kms:
		var from_c := p.country_at(maxf(0.0, km - 0.05))
		var to_c := p.country_at(minf(p.length_km, km + 0.05))
		if from_c == to_c:
			p.warnings.append("Grenze bei km %.1f passt zu keinem Länderwechsel der Abschnitte" % km)
		var to_info: Dictionary = countries.get(to_c, {})
		p.borders.append({"km": km, "from": from_c, "to": to_c,
			"name": str(to_info.get("name", to_c)), "name_local": str(to_info.get("name_local", to_info.get("name", to_c)))})


static func _compute_climate(p: StagePlan, countries: Dictionary) -> void:
	var share := {}
	for s in p.sections:
		var c := str(s["country"])
		share[c] = float(share.get(c, 0.0)) + float(s["length_km"])
		if p.countries_in_order.is_empty() or p.countries_in_order[-1] != c:
			p.countries_in_order.append(c)
	var best := ""
	var best_len := -1.0
	for c in share:
		if float(share[c]) > best_len:
			best = c
			best_len = float(share[c])
	p.climate = str(countries.get(best, {}).get("climate", "default"))


# --- Queries -------------------------------------------------------------------------------

func section_index_at(km: float) -> int:
	for i in sections.size():
		if km < float(sections[i]["end_km"]):
			return i
	return sections.size() - 1


func section_at(km: float) -> Dictionary:
	if sections.is_empty():
		return {}
	return sections[section_index_at(km)]


func country_at(km: float) -> String:
	return str(section_at(km).get("country", "DE"))


func scenery_at(km: float) -> String:
	return str(section_at(km).get("scenery", "north_plain"))


func is_city(km: float) -> bool:
	return km >= city_limits_km


## Road type at km; inside the City Limits always "city".
func road_at(km: float) -> String:
	if is_city(km):
		return "city"
	return str(section_at(km).get("road", "autobahn"))


## Posted speed limit (km/h) at km, 0 = no limit.
func speed_limit_at(km: float) -> int:
	if is_city(km):
		return city_speed_limit
	return int(section_at(km).get("speed_limit", 0))


func traffic_factor_at(km: float) -> float:
	return float(section_at(km).get("traffic", 1.0))


func tunnel_at(km: float) -> Dictionary:
	for t in tunnels:
		if km >= float(t["start_km"]) and km < float(t["end_km"]):
			return t
	return {}


func in_tunnel(km: float) -> bool:
	return not tunnel_at(km).is_empty()


func fuel_lane_at(km: float) -> Dictionary:
	for l in fuel_lanes:
		if km >= float(l["start_km"]) and km <= float(l["end_km"]):
			return l
	return {}


## Next fuel station at or ahead of km; -1 if none.
func next_station_km(km: float) -> float:
	for s in fuel_stations_km:
		if s >= km:
			return s
	return -1.0


## Next radar zone that has not been passed yet (zone end ahead of km); {} if none.
func next_radar(km: float) -> Dictionary:
	for r in radars:
		if float(r["end_km"]) > km:
			return r
	return {}


func radar_zone_at(km: float) -> Dictionary:
	for r in radars:
		if km >= float(r["km"]) and km < float(r["end_km"]):
			return r
	return {}


## Plain-data summary for menus (route choice, stage screen).
func summary() -> Dictionary:
	var autobahn_km := 0.0
	var unlimited_km := 0.0
	var traffic_weighted := 0.0
	for s in sections:
		var length := float(s["length_km"])
		if s["road"] == "autobahn":
			autobahn_km += length
			if int(s["speed_limit"]) == 0:
				unlimited_km += length
		traffic_weighted += length * float(s["traffic"])
	return {
		"length_km": length_km,
		"autobahn_km": autobahn_km,
		"unlimited_km": unlimited_km,
		"radars": radars.size(),
		"stations": fuel_stations_km.size(),
		"tunnels": tunnels.size(),
		"borders": borders.size(),
		"traffic": traffic_weighted / maxf(length_km, 0.001),
		"countries": countries_in_order.duplicate(),
	}
