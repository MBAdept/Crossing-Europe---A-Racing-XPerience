class_name Track
extends RefCounted
## Streams the road of one stage as short segments (render.segment_length_m visual metres):
## generated ahead of the camera, discarded behind it (design document "Darstellung und Technik").
## Curves and hills come from a seeded road-piece generator driven by the section parameters
## (curviness / hills 0–3). Everything tied to km positions (road type, lanes, fuel lane, tunnels,
## City Limits, signs, stations, radar posts, border posts) is deterministic.
## Implements the track API used by TrafficSystem (see ARCHITECTURE.md §Strecke).
## Owner: race module.

var plan: StagePlan
var cfg: Dictionary = {}
var scenery_db: Dictionary = {}
var seg_len := 3.0
var time_scale := 12.0
var lane_w := 3.75
var shoulder_w := 2.5
var length_z := 0.0
var length_km := 0.0
var segment_count := 0
var keep_behind := 64                  ## segments kept behind the camera

var _segs: Dictionary = {}             ## index -> TrackSegment (current window)
var _gen_next := 0                     ## next index to generate
var _seed := 0
var _road_changes: Array[Dictionary] = []   ## {z, from_lanes, to_lanes}
var _events: Dictionary = {}           ## segment index -> Array[Dictionary] (props/signs from km events)

# road piece generator state (curves)
var _rng := RandomNumberGenerator.new()
var _c_len := 0
var _c_pos := 0
var _c_mag := 0.0
var _c_is_curve := false
# hills
var _h_len := 0
var _h_pos := 0
var _h_from := 0.0
var _h_to := 0.0
var _h_grade := 0.0
var _y := 0.0


func setup(stage_plan: StagePlan, config: Dictionary, scenery: Dictionary, seed_override: int = -1) -> void:
	plan = stage_plan
	cfg = config
	scenery_db = scenery
	seg_len = float(ConfigLoader.lookup(cfg, "render.segment_length_m", 3.0))
	time_scale = float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	lane_w = float(ConfigLoader.lookup(cfg, "road.lane_width_m", 3.75))
	shoulder_w = float(ConfigLoader.lookup(cfg, "road.shoulder_width_m", 2.5))
	length_km = plan.length_km
	length_z = km_to_z(length_km)
	segment_count = int(ceil(length_z / seg_len)) + 1
	_seed = plan.seed if seed_override < 0 else seed_override
	_rng.seed = _seed
	_segs.clear()
	_gen_next = 0
	_c_len = 0
	_h_len = 0
	_h_grade = 0.0
	_y = 0.0
	_build_road_changes()
	_build_events()


# --- Conversions ----------------------------------------------------------------------------

func km_to_z(km: float) -> float:
	return km * 1000.0 / time_scale


func z_to_km(z: float) -> float:
	return z * time_scale / 1000.0


func segment_index_at(z: float) -> int:
	return clampi(int(floor(z / seg_len)), 0, segment_count - 1)


# --- Window ---------------------------------------------------------------------------------

## Generates segments up to camera_z + ahead_m and discards those far behind the camera.
func update_window(camera_z: float, ahead_m: float) -> void:
	var last := segment_index_at(camera_z + ahead_m) + 2
	while _gen_next <= mini(last, segment_count - 1):
		_generate(_gen_next)
		_gen_next += 1
	var first := segment_index_at(camera_z) - keep_behind
	for i in _segs.keys():
		if i < first:
			_segs.erase(i)


## Segment by index. Generates forward on demand; indices discarded behind return the oldest kept.
func get_segment(index: int) -> TrackSegment:
	index = clampi(index, 0, segment_count - 1)
	while _gen_next <= index:
		_generate(_gen_next)
		_gen_next += 1
	if _segs.has(index):
		return _segs[index]
	var keys := _segs.keys()
	keys.sort()
	return _segs[keys[0]]


func segment_at(z: float) -> TrackSegment:
	return get_segment(segment_index_at(z))


# --- Generation -----------------------------------------------------------------------------

func _generate(i: int) -> void:
	var s := TrackSegment.new()
	s.index = i
	s.z = i * seg_len
	s.km = z_to_km(s.z)
	var km := s.km
	var sec := plan.section_at(km)
	s.road = plan.road_at(km)
	s.scenery = "city" if plan.is_city(km) and scenery_db.has("city") else str(sec.get("scenery", "north_plain"))
	s.country = str(sec.get("country", "DE"))
	s.speed_limit = plan.speed_limit_at(km)
	s.tunnel = plan.in_tunnel(km)
	s.city = plan.is_city(km)
	s.guardrail = bool(ConfigLoader.lookup(cfg, "road.guardrail." + s.road, false))
	s.lanes = lanes_at(s.z)
	s.lane_count = lane_count_at(s.z)
	s.fuel_lane = fuel_lane_factor(s.z)
	s.curve = _next_curve(i, sec, s)
	s.y = _y
	_y += _next_grade(i, sec, s) * seg_len * float(ConfigLoader.lookup(cfg, "render.hill_height_scale", 1.0))
	_place_props(s)
	_segs[i] = s


func _next_curve(i: int, sec: Dictionary, s: TrackSegment) -> float:
	if _c_pos >= _c_len:
		_c_pos = 0
		var level := int(sec.get("curviness", 1))
		var max_curve := float((ConfigLoader.lookup(cfg, "road.curviness_max_curve", [0.0, 0.22, 0.45, 0.9]) as Array)[level])
		if s.tunnel:
			max_curve = minf(max_curve, 0.25)
		if _c_is_curve or max_curve <= 0.0:
			_c_is_curve = false
			_c_len = int(_rng.randf_range(120.0, 700.0 - level * 140.0) / seg_len)
			_c_mag = 0.0
		else:
			_c_is_curve = true
			_c_len = int(_rng.randf_range(150.0, 520.0) / seg_len)
			_c_mag = _rng.randf_range(0.35, 1.0) * max_curve * (1.0 if _rng.randf() < 0.5 else -1.0)
	var t := float(_c_pos) / maxf(1.0, float(_c_len))
	_c_pos += 1
	# no curves on the first and last 150 m (start grid / finish line)
	if s.z < 150.0 or s.z > length_z - 150.0:
		return 0.0
	var ease := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.7, 1.0, t))
	return _c_mag * ease


func _next_grade(i: int, sec: Dictionary, s: TrackSegment) -> float:
	if _h_pos >= _h_len:
		_h_pos = 0
		var level := int(sec.get("hills", 1))
		var max_grade := float((ConfigLoader.lookup(cfg, "road.hills_max_grade", [0.0, 0.025, 0.045, 0.07]) as Array)[level])
		if s.tunnel:
			max_grade *= 0.4
		_h_from = _h_grade
		_h_to = _rng.randf_range(-max_grade, max_grade)
		_h_len = int(_rng.randf_range(180.0, 650.0) / seg_len)
	var t := float(_h_pos) / maxf(1.0, float(_h_len))
	_h_pos += 1
	_h_grade = lerpf(_h_from, _h_to, smoothstep(0.0, 1.0, t))
	if s.z < 60.0:
		return 0.0
	return _h_grade


# --- Lanes, edges, fuel lane ----------------------------------------------------------------

func _lanes_for(road: String) -> int:
	return int(ConfigLoader.lookup(cfg, "road.lanes." + road, 2))


func _build_road_changes() -> void:
	_road_changes.clear()
	var points: Array[float] = []
	for sec in plan.sections:
		points.append(float(sec["start_km"]))
	points.append(plan.city_limits_km)
	points.sort()
	for km in points:
		if km <= 0.0 or km >= plan.length_km:
			continue
		var before := _lanes_for(plan.road_at(km - 0.01))
		var after := _lanes_for(plan.road_at(km + 0.01))
		if before != after:
			_road_changes.append({"z": km_to_z(km), "from": before, "to": after})


## Effective (fractional) lane count at z; lane changes blend over road.lane_transition_m.
func lanes_at(z: float) -> float:
	var trans := float(ConfigLoader.lookup(cfg, "road.lane_transition_m", 180.0))
	var lanes := float(_lanes_for(plan.road_at(z_to_km(z))))
	for c in _road_changes:
		var d := z - float(c["z"])
		if d >= 0.0 and d < trans:
			lanes = lerpf(float(c["from"]), float(c["to"]), smoothstep(0.0, 1.0, d / trans))
	return lanes


## Lanes usable by traffic at z (during a transition the smaller count).
func lane_count_at(z: float) -> int:
	var trans := float(ConfigLoader.lookup(cfg, "road.lane_transition_m", 180.0))
	var n := _lanes_for(plan.road_at(z_to_km(z)))
	for c in _road_changes:
		var d := z - float(c["z"])
		if d >= -trans and d < trans:
			n = mini(int(c["from"]), int(c["to"]))
	return n


## Centre x of a lane (0 = leftmost). lane == lane_count_at(z) addresses the fuel lane.
func lane_center_x(z: float, lane: int) -> float:
	var lanes := lanes_at(z)
	return -lanes * lane_w * 0.5 + lane_w * (float(lane) + 0.5)


## Paved road edges (x of left edge, x of right edge) including an open fuel lane.
func road_edges_at(z: float) -> Vector2:
	var half := lanes_at(z) * lane_w * 0.5
	return Vector2(-half, half + fuel_lane_factor(z) * lane_w)


## Right edge of the regular lanes (without fuel lane).
func main_right_edge(z: float) -> float:
	return lanes_at(z) * lane_w * 0.5


## 0..1 width of the fuel lane at z (tapers in/out over road.fuel_lane_taper_m).
func fuel_lane_factor(z: float) -> float:
	var taper := float(ConfigLoader.lookup(cfg, "road.fuel_lane_taper_m", 40.0))
	for l in plan.fuel_lanes:
		var z0 := km_to_z(float(l["start_km"]))
		var z1 := km_to_z(float(l["end_km"]))
		if z >= z0 and z <= z1 + taper:
			if z < z0 + taper:
				return smoothstep(z0, z0 + taper, z)
			if z <= z1:
				return 1.0
			return 1.0 - smoothstep(z1, z1 + taper, z)
	return 0.0


## True where the fuel lane is fully open and refuelling can trigger (StagePlan.fuel_lanes span).
func fuel_lane_at(z: float) -> bool:
	return fuel_lane_factor(z) >= 0.99 and not plan.fuel_lane_at(z_to_km(z)).is_empty()


func fuel_lane_x(z: float) -> float:
	return main_right_edge(z) + lane_w * 0.5


func road_type_at(z: float) -> String:
	return plan.road_at(z_to_km(z))


func is_city_at(z: float) -> bool:
	return plan.is_city(z_to_km(z))


func is_tunnel_at(z: float) -> bool:
	return plan.in_tunnel(z_to_km(z))


func traffic_factor_at(z: float) -> float:
	return plan.traffic_factor_at(z_to_km(z))


func country_at(z: float) -> String:
	return plan.country_at(z_to_km(z))


func speed_limit_at(z: float) -> int:
	return plan.speed_limit_at(z_to_km(z))


func curve_at(z: float) -> float:
	return get_segment(segment_index_at(z)).curve


## Road height at z (interpolated between segment starts).
func height_at(z: float) -> float:
	var i := segment_index_at(z)
	var a := get_segment(i)
	var b := get_segment(mini(i + 1, segment_count - 1))
	var t := clampf((z - a.z) / seg_len, 0.0, 1.0)
	return lerpf(a.y, b.y, t)


## Grade (rise/run) at z, + = uphill.
func grade_at(z: float) -> float:
	var i := segment_index_at(z)
	var a := get_segment(i)
	var b := get_segment(mini(i + 1, segment_count - 1))
	return (b.y - a.y) / seg_len / maxf(0.001, float(ConfigLoader.lookup(cfg, "render.hill_height_scale", 1.0)))


# --- Props ----------------------------------------------------------------------------------

func _build_events() -> void:
	_events.clear()
	var dest := plan.to_name
	for st in plan.fuel_stations_km:
		for k in ConfigLoader.lookup(cfg, "fuel.announce_km", [30, 15, 5]):
			_add_event(st - float(k), {"kind": "sign", "sign": "fuel", "text": "%d km" % int(k), "value": int(k), "side": 1})
	for l in plan.fuel_lanes:
		var z0 := km_to_z(float(l["start_km"]))
		var z1 := km_to_z(float(l["end_km"]))
		var z := z0 + 30.0
		while z < z1:
			_add_event_z(z, {"kind": "prop", "set": "props/fuel_pump", "side": 1, "offset": 4.5, "fuel_lane": true})
			z += 24.0
		_add_event_z(z1, {"kind": "prop", "set": "props/fuel_station", "side": 1, "offset": 9.0, "fuel_lane": true})
	for r in plan.radars:
		_add_event(float(r["warn_km"]), {"kind": "sign", "sign": "radar", "value": int(r["limit"]), "side": 1})
		_add_event(float(r["km"]), {"kind": "sign", "sign": "limit", "value": int(r["limit"]), "side": 1})
		_add_event(float(r["km"]), {"kind": "sign", "sign": "limit", "value": int(r["limit"]), "side": -1})
		_add_event(float(r["km"]) + 0.4, {"kind": "prop", "set": "props/radar_camera", "side": 1, "offset": 1.5})
	for t in plan.tunnels:
		if str(t["name"]) != "":
			_add_event(maxf(0.0, float(t["start_km"]) - 0.6), {"kind": "sign", "sign": "tunnel", "text": str(t["name"]), "side": 1})
	for b in plan.borders:
		var name_local := str(b.get("name_local", b["to"]))
		_add_event(float(b["km"]) - 0.3, {"kind": "sign", "sign": "border", "text": name_local, "value": 0, "side": 1, "country": str(b["to"])})
		_add_event(float(b["km"]), {"kind": "prop", "set": "props/customs_booth", "side": 1, "offset": 2.0})
		_add_event(float(b["km"]), {"kind": "prop", "set": "props/customs_booth", "side": -1, "offset": 2.0})
	_add_event(plan.city_limits_km, {"kind": "sign", "sign": "town", "text": dest, "side": 1})
	var prev_limit := -1
	for sec in plan.sections:
		var lim := int(sec["speed_limit"])
		if lim != prev_limit and float(sec["start_km"]) < plan.city_limits_km:
			_add_event(float(sec["start_km"]) + 0.2, {"kind": "sign", "sign": "limit" if lim > 0 else "unlimited", "value": lim, "side": 1})
		prev_limit = lim
	var km := 50.0
	while km < plan.city_limits_km - 10.0:
		_add_event(plan.length_km - km, {"kind": "sign", "sign": "distance", "text": "%s %d km" % [dest, int(km)], "side": 1})
		km += 50.0
	_add_event_z(length_z - seg_len * 2.0, {"kind": "sign", "sign": "finish", "text": "ZIEL", "side": 0})


func _add_event(km: float, e: Dictionary) -> void:
	if km < 0.0 or km > plan.length_km:
		return
	_add_event_z(km_to_z(km), e)


func _add_event_z(z: float, e: Dictionary) -> void:
	var i := segment_index_at(z)
	if not _events.has(i):
		_events[i] = []
	_events[i].append(e)


func _place_props(s: TrackSegment) -> void:
	var edges := road_edges_at(s.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_seed * 7919 + s.index)
	for e: Dictionary in _events.get(s.index, []):
		var p := e.duplicate()
		var side := int(e.get("side", 1))
		var offset := float(e.get("offset", 1.2))
		if side > 0:
			p["x"] = edges.y + shoulder_w + offset
		elif side < 0:
			p["x"] = edges.x - shoulder_w - offset
		else:
			p["x"] = 0.0
		p["scale"] = 1.0
		s.sprites.append(p)
	if s.tunnel:
		return
	var sc: Dictionary = scenery_db.get(s.scenery, {})
	var z_mod := s.z
	for rule: Dictionary in sc.get("props", []):
		var every := float(rule.get("every_m", 30.0))
		if fmod(z_mod, every) >= seg_len:
			continue
		if rng.randf() > float(rule.get("chance", 1.0)):
			continue
		var side_rule := str(rule.get("side", "both"))
		var side := 1
		if side_rule == "left":
			side = -1
		elif side_rule == "both":
			side = -1 if rng.randf() < 0.5 else 1
		var xr: Array = rule.get("x", [8.0, 30.0])
		var off := rng.randf_range(float(xr[0]), float(xr[1]))
		var x := (edges.y + shoulder_w + off) if side > 0 else (edges.x - shoulder_w - off)
		var sr: Array = rule.get("scale", [1.0, 1.0])
		s.sprites.append({"kind": "prop", "set": str(rule["set"]), "x": x, "scale": rng.randf_range(float(sr[0]), float(sr[1])), "side": side})
