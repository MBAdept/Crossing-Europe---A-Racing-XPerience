extends RefCounted
## Shared fixtures for the gameplay unit tests and simulations (no autoloads).
## Owner: gameplay module (tests only).

const FakeTrack := preload("res://tests/sim/fake_track.gd")
const VEHICLES := ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
const DT := 1.0 / 60.0


## The merged game configuration, optionally deep-merged with overrides.
static func config(overrides: Dictionary = {}) -> Dictionary:
	var base := ConfigLoader.load_merged()
	if overrides.is_empty():
		return base
	return ConfigLoader.deep_merge(base, overrides)


## Straight, flat road dictionary for VehicleModel.update.
static func flat_road(lanes: int = 3, guardrail: bool = true, curve: float = 0.0, grip: float = 1.0) -> Dictionary:
	var half := float(lanes) * 3.75 * 0.5
	return {"curve": curve, "grade": 0.0, "left_edge": -half, "right_edge": half, "shoulder_m": 2.5,
		"guardrail": guardrail, "grip": grip}


static func vehicle(cfg: Dictionary, id: String) -> VehicleModel:
	var v := VehicleModel.new()
	v.setup(cfg, id)
	return v


## A StagePlan built directly from its documented fields (no network data needed).
## stations: [km, ...] – each gets a fuel lane of lane_len_km before it;
## radars: [{km, limit}, ...] – zone radar.zone_length_km long, warning radar.warning_km before.
static func make_plan(cfg: Dictionary, length_km: float = 200.0, stations: Array = [], radars: Array = [], lane_len_km: float = 1.5) -> StagePlan:
	var p := StagePlan.new()
	p.stage_id = "test"
	p.display_name = "Test – Ziel"
	p.length_km = length_km
	p.city_limits_km = maxf(0.0, length_km - float(ConfigLoader.lookup(cfg, "city_limits.length_km", 20.0)))
	p.sections.append({"start_km": 0.0, "end_km": length_km, "length_km": length_km, "road": "autobahn", "curviness": 0,
		"hills": 0, "scenery": "north_plain", "country": "DE", "speed_limit": 0, "traffic": 1.0})
	for s in stations:
		var km := float(s)
		p.fuel_stations_km.append(km)
		p.fuel_lanes.append({"station_km": km, "start_km": km - lane_len_km, "end_km": km})
	var zone := float(ConfigLoader.lookup(cfg, "radar.zone_length_km", 5.0))
	var warn := float(ConfigLoader.lookup(cfg, "radar.warning_km", 10.0))
	for r: Dictionary in radars:
		var km := float(r.get("km", 30.0))
		p.radars.append({"km": km, "end_km": km + zone, "limit": int(r.get("limit", 120)), "warn_km": maxf(0.0, km - warn)})
	p.climate = "north"
	p.seed = 4711
	return p


## Plain-text table with aligned columns.
static func table(title: String, headers: Array, rows: Array) -> String:
	var widths: Array[int] = []
	for h in headers:
		widths.append(str(h).length())
	for r: Array in rows:
		for i in r.size():
			if i < widths.size():
				widths[i] = maxi(widths[i], str(r[i]).length())
	var out := "\n== %s ==\n" % title
	var line := ""
	for i in headers.size():
		line += str(headers[i]).rpad(widths[i] + 2)
	out += line.strip_edges(false, true) + "\n"
	for r: Array in rows:
		line = ""
		for i in r.size():
			line += str(r[i]).rpad(widths[i] + 2)
		out += line.strip_edges(false, true) + "\n"
	return out
