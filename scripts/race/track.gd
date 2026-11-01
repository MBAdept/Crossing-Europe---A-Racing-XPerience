class_name Track
extends RefCounted
## Streams the road of one stage as short segments (render.segment_length_m visual metres):
## generated ahead of the camera, discarded behind it (design document "Darstellung und Technik").
## Curves and hills come from a seeded road-piece generator driven by the section parameters
## (curviness / hills 0–3). Everything tied to km positions (road type, lanes, fuel lane, tunnels,
## City Limits, signs, stations, radar posts, border posts) is deterministic.
## Implements the track API used by TrafficSystem (see ARCHITECTURE.md §Strecke).
##
## Generation is sequential (one RNG for curves/hills), so a segment depends only on the seed and
## its index – never on the camera path. Props use a per-segment RNG (seed, index).
## After the finish line the road continues straight for road.runout_m (coast-out after "ZIEL").
## Sharp curves (|curve| >= road.curve_warning_min_curve) and blind ones (hidden behind a crest) get a warning
## sign road.curve_warning_m before them (inserted into the already generated segment; generation runs
## generation_lead_m() ahead of the requested window, so the sign is in place before the segment can be seen),
## sharp ones red-white chevron boards on their outside (road.chevron_every_m) – the curve speed matters
## (understeer), and a curve behind a crest must be known in time (tests/sim/curve_sight.gd).
## Owner: race module.

const WALL_SIGN_GAP_M := 0.1           ## gap between a tunnel-wall sign and the wall
const WALL_SIGN_OVERHANG_M := 1.0      ## how far a tunnel-wall sign may reach over the paved road

var plan: StagePlan
var cfg: Dictionary = {}
var scenery_db: Dictionary = {}
var seg_len := 3.0
var time_scale := 12.0
var lane_w := 3.75
var shoulder_w := 2.5
var length_z := 0.0                    ## visual metres from start to finish line
var length_km := 0.0
var segment_count := 0                 ## including the run-out behind the finish
var keep_behind := 64                  ## segments kept behind the camera
var runout_m := 600.0
var hill_scale := 1.0                  ## render.hill_height_scale (visual exaggeration of hills)
## Spanning structures {kind: "fuel"|"fuel_canopy"|"border", z0, z1, ...} sorted by z0.
var zones: Array[Dictionary] = []

var _segs: Dictionary = {}             ## index -> TrackSegment (current window)
var _gen_next := 0                     ## next index to generate
var _seed := 0
var _road_changes: Array[Dictionary] = []   ## {z, from, to}
var _events: Dictionary = {}           ## segment index -> Array[Dictionary] (props/signs from km events)
var _clear: Dictionary = {}            ## segment index -> side mask (1 right, 2 left): no scenery props
var _lane_trans := 180.0
var _taper := 40.0

# road piece generator state (curves)
var _rng := RandomNumberGenerator.new()
var _c_len := 0
var _c_pos := 0
var _c_mag := 0.0
var _c_is_curve := false
var _c_last := 0.0
var _c_new := false                    ## the last _next_curve() started a curve piece
var _c_in_piece := false               ## the last _next_curve() was part of a curve piece (not a fade)
var _c_in_fade := false                ## the last _next_curve() was the fade-out of a piece cut by a break
## Warning signs decided early because a section / tunnel break cut their curve piece during its ramp-in
## (diagnostics for tests, see _place_curve_signs).
var curve_signs_cut := 0
var _chev_i := 0                       ## segment counter of the running piece incl. its fade (chevron spacing)
var _sign_pending := false             ## warning sign of the running curve piece not decided yet
var _sign_start_z := 0.0               ## z of the first segment of that piece
var _warn_curve := 0.25                ## road.curve_warning_min_curve
var _warn_blind := 0.12                ## road.curve_warning_blind_min_curve
var _warn_sight := 150.0               ## road.curve_warning_sight_m
var _warn_m := 200.0                   ## road.curve_warning_m
var _chev_n := 10                      ## road.chevron_every_m in segments
var _cam_h := 3.4                      ## render.camera_height_m (sight over crests)
var _cam_d := 9.0                      ## render.camera_distance_m
var _c_fade := 0                       ## segments left of a fade-out at a section change
var _c_fade_n := 1
var _c_fade_from := 0.0
var _breaks: Array[float] = []        ## z where the road pieces restart (section starts, before tunnels)
var _break_i := 0
# hills
var _h_len := 0
var _h_pos := 0
var _h_trans := 1
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
	runout_m = float(ConfigLoader.lookup(cfg, "road.runout_m", 600.0))
	hill_scale = float(ConfigLoader.lookup(cfg, "render.hill_height_scale", 1.0))
	_lane_trans = float(ConfigLoader.lookup(cfg, "road.lane_transition_m", 180.0))
	_taper = float(ConfigLoader.lookup(cfg, "road.fuel_lane_taper_m", 40.0))
	_warn_curve = float(ConfigLoader.lookup(cfg, "road.curve_warning_min_curve", 0.25))
	_warn_m = maxf(0.0, float(ConfigLoader.lookup(cfg, "road.curve_warning_m", 200.0)))
	_warn_blind = float(ConfigLoader.lookup(cfg, "road.curve_warning_blind_min_curve", 0.12))
	_warn_sight = float(ConfigLoader.lookup(cfg, "road.curve_warning_sight_m", 150.0))
	_cam_h = float(ConfigLoader.lookup(cfg, "render.camera_height_m", 3.4))
	_cam_d = float(ConfigLoader.lookup(cfg, "render.camera_distance_m", 9.0))
	_chev_n = maxi(1, int(round(float(ConfigLoader.lookup(cfg, "road.chevron_every_m", 30.0)) / seg_len)))
	length_km = plan.length_km
	length_z = km_to_z(length_km)
	segment_count = int(ceil((length_z + runout_m) / seg_len)) + 1
	_seed = plan.seed if seed_override < 0 else seed_override
	_rng.seed = _seed
	_segs.clear()
	_gen_next = 0
	_c_len = 0
	_c_pos = 0
	_c_is_curve = false
	_c_last = 0.0
	_c_fade = 0
	_break_i = 0
	_breaks.clear()
	for sec in plan.sections:
		if float(sec["start_km"]) > 0.0:
			_breaks.append(km_to_z(float(sec["start_km"])))
	for t in plan.tunnels:
		_breaks.append(maxf(0.0, km_to_z(float(t["start_km"])) - 60.0))
	_breaks.sort()
	_h_len = 0
	_h_pos = 0
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

## Generates segments up to camera_z + ahead_m (plus generation_lead_m(), so that curve warning signs are
## placed before their segment comes into view) and discards those far behind the camera.
func update_window(camera_z: float, ahead_m: float) -> void:
	var last := segment_index_at(camera_z + ahead_m + generation_lead_m()) + 2
	while _gen_next <= mini(last, segment_count - 1):
		_generate(_gen_next)
		_gen_next += 1
	var first := segment_index_at(camera_z) - keep_behind
	for i: int in _segs.keys():
		if i < first:
			_segs.erase(i)


## Segment by index. Generates forward on demand; indices discarded behind return the oldest kept.
func get_segment(index: int) -> TrackSegment:
	index = clampi(index, 0, segment_count - 1)
	while _gen_next <= index:
		_generate(_gen_next)
		_gen_next += 1
	var s: TrackSegment = _segs.get(index)
	if s != null:
		return s
	var keys := _segs.keys()
	keys.sort()
	return _segs[keys[0]]


func segment_at(z: float) -> TrackSegment:
	return get_segment(segment_index_at(z))


## Number of segments currently held in memory (window size, for tests/diagnostics).
func window_size() -> int:
	return _segs.size()


# --- Generation -----------------------------------------------------------------------------

func _generate(i: int) -> void:
	var s := TrackSegment.new()
	s.index = i
	s.z = i * seg_len
	s.km = z_to_km(s.z)
	var km := minf(s.km, length_km)
	var sec := plan.section_at(km)
	s.runout = s.z > length_z
	s.road = plan.road_at(km)
	s.city = plan.is_city(km)
	s.scenery = "city" if s.city and scenery_db.has("city") else str(sec.get("scenery", "north_plain"))
	s.country = str(sec.get("country", "DE"))
	s.speed_limit = plan.speed_limit_at(km)
	s.tunnel = plan.in_tunnel(km) and not s.runout
	s.guardrail = bool(ConfigLoader.lookup(cfg, "road.guardrail." + s.road, false))
	s.lanes = lanes_at(s.z)
	s.lane_count = lane_count_at(s.z)
	s.fuel_lane = fuel_lane_factor(s.z)
	if _break_i < _breaks.size() and s.z >= _breaks[_break_i]:
		while _break_i < _breaks.size() and s.z >= _breaks[_break_i]:
			_break_i += 1
		# new section / tunnel ahead: fade the running curve out (60 m) and start new road pieces
		# with the limits that apply there
		_c_fade_from = _c_last
		_c_fade_n = int(60.0 / seg_len)
		_c_fade = _c_fade_n
		_c_pos = _c_len
		_c_is_curve = true
		_h_pos = _h_len
	s.curve = _next_curve(sec, s)
	_c_last = s.curve
	s.y = _y
	_y += _next_grade(sec, s) * seg_len * hill_scale
	_mark_zones(s)
	_place_props(s)
	_segs[i] = s
	_place_curve_signs(s)


## Fade factor 0..1 that keeps the road straight and flat at the start and around the finish.
func _calm(z: float, near_start: float, near_end: float) -> float:
	var a := smoothstep(near_start, near_start + 120.0, z)
	var b := 1.0 - smoothstep(length_z - near_end - 120.0, length_z - near_end, z)
	return a * b


func _next_curve(sec: Dictionary, s: TrackSegment) -> float:
	_c_new = false
	_c_in_piece = false
	_c_in_fade = false
	if _c_fade > 0:
		_c_fade -= 1
		_c_in_fade = absf(_c_fade_from) > 0.0005
		return _c_fade_from * smoothstep(0.0, 1.0, float(_c_fade) / float(_c_fade_n))
	if _c_pos >= _c_len:
		_c_pos = 0
		var level := int(sec.get("curviness", 1))
		var maxes: Array = ConfigLoader.lookup(cfg, "road.curviness_max_curve", [0.0, 0.30, 0.45, 0.9])
		var max_curve := float(maxes[clampi(level, 0, maxes.size() - 1)])
		if s.tunnel:
			max_curve = minf(max_curve, 0.25)
		if s.city:
			max_curve = minf(max_curve, 0.35)
		if _c_is_curve or max_curve <= 0.0:
			_c_is_curve = false
			_c_len = int(_rng.randf_range(120.0, 700.0 - level * 140.0) / seg_len)
			_c_mag = 0.0
		else:
			_c_is_curve = true
			_c_len = int(_rng.randf_range(150.0, 520.0) / seg_len)
			_c_mag = _rng.randf_range(0.35, 1.0) * max_curve * (1.0 if _rng.randf() < 0.5 else -1.0)
			_c_new = true
	var t := float(_c_pos) / maxf(1.0, float(_c_len))
	_c_pos += 1
	_c_in_piece = _c_is_curve
	if s.runout:
		return 0.0
	var ease := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.7, 1.0, t))
	return _c_mag * ease * _calm(s.z, 40.0, 60.0)


## Curve signs of a curve piece (not in tunnels, not where the start/finish calm zone flattens it). Warning sign
## road.curve_warning_m before its first segment on the right (inserted into that earlier segment, on the tunnel
## wall if that is inside a tunnel) when it is sharp (|magnitude| >= road.curve_warning_min_curve) or blind:
## |magnitude| >= road.curve_warning_blind_min_curve and some point of its ramp-in hidden behind a crest from
## road.curve_warning_sight_m before it. Decided at the end of the ramp-in (30 % of the piece), when the heights of
## that part exist – or earlier, when a section / tunnel break cuts the piece: its 60-m fade-out starts at the
## value the piece had reached (_c_fade_from), which is then its peak. Sharp pieces also get a chevron board every
## road.chevron_every_m on the outside of the bend along their strong part (|curve| >= 60 % of the magnitude,
## the fade included; not in City Limits). Warning signs also stand in City Limits (no radar there, so cars arrive
## at full speed). value = direction (+1 right, -1 left).
func _place_curve_signs(s: TrackSegment) -> void:
	if _c_new:
		_sign_pending = true
		_sign_start_z = s.z
		_chev_i = 0
	if s.runout or not (_c_in_piece or _c_in_fade):
		_sign_pending = false
		return
	var mag := _c_fade_from if _c_in_fade else _c_mag
	var i := _chev_i
	_chev_i += 1
	if absf(mag) < minf(_warn_curve, _warn_blind) or s.tunnel:
		if _c_in_fade:
			_sign_pending = false
		return
	var dir := 1 if mag > 0.0 else -1
	var sharp := absf(mag) >= _warn_curve
	if _sign_pending and (_c_in_fade or float(_c_pos) >= 0.3 * float(_c_len) or _c_pos >= _c_len):
		_sign_pending = false
		var mid := s.z if _c_in_fade else _sign_start_z + float(_c_len) * seg_len * 0.5
		if _calm(mid, 40.0, 60.0) > 0.6 and (sharp or _blind(_sign_start_z, s.z)):
			_place_warning_sign(_sign_start_z - _warn_m, dir)
			if _c_in_fade:
				curve_signs_cut += 1
	if sharp and not s.city and i % _chev_n == 0 and absf(s.curve) >= 0.6 * absf(mag):
		s.sprites.append({"kind": "sign", "sign": "chevron", "value": dir, "side": -dir, "z": s.z, "scale": 1.0,
			"x": _prop_x(road_edges_at(s.z), -dir, "outer", 0.6), "country": s.country, "road": s.road})
		_sort_sprites(s)


## Warning sign "Kurve" at zw on the right (on the tunnel wall inside a tunnel), inserted into its already
## generated segment.
func _place_warning_sign(zw: float, dir: int) -> void:
	var target: TrackSegment = _segs.get(segment_index_at(zw)) if zw > 0.0 else null
	if target == null:
		return
	var p := {"kind": "sign", "sign": "curve", "value": dir, "side": 1, "z": zw, "scale": 1.0,
		"x": _prop_x(road_edges_at(zw), 1, "outer", 1.0), "country": target.country, "road": target.road}
	if target.tunnel:
		_mount_on_tunnel_wall(p, road_edges_at(zw), 1)
	target.sprites.append(p)
	_sort_sprites(target)


## True when some point of [z0, z1] (every 15 m) cannot be seen from road.curve_warning_sight_m before it.
func _blind(z0: float, z1: float) -> bool:
	var z := z0
	while z <= z1 + 0.001:
		if not _sees(z - _warn_sight, z):
			return true
		z += 15.0
	return false


## How far generation runs ahead of the requested window (m): the warning sign distance plus the longest
## ramp-in of a curve piece (30 % of 520 m; the sign is decided at its end).
func generation_lead_m() -> float:
	return _warn_m + 0.3 * 520.0 + 10.0


## True when the road at z_p can be seen from the camera of a car at z_car (render.camera_height_m above the
## road at the car, render.camera_distance_m behind it): no crest of the generated road in between.
func _sees(z_car: float, z_p: float) -> bool:
	if z_car <= 0.0:
		return true
	var zc := maxf(0.0, z_car - _cam_d)
	var yc := _seg_y(z_car) + _cam_h
	var yp := _seg_y(z_p)
	var k := segment_index_at(zc) + 1
	var last := segment_index_at(z_p)
	while k < last:
		var sk: TrackSegment = _segs.get(k)
		if sk != null and sk.y > yc + (yp - yc) * (sk.z - zc) / maxf(z_p - zc, 0.01) + 0.05:
			return false
		k += 1
	return true


func _seg_y(z: float) -> float:
	var sk: TrackSegment = _segs.get(segment_index_at(z))
	return sk.y if sk != null else _y


func _sort_sprites(s: TrackSegment) -> void:
	s.sprites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("z", 0.0)) > float(b.get("z", 0.0)))


func _next_grade(sec: Dictionary, s: TrackSegment) -> float:
	if _h_pos >= _h_len:
		_h_pos = 0
		var level := int(sec.get("hills", 1))
		var ahead := plan.in_tunnel(minf(length_km, s.km + z_to_km(80.0)))
		var maxes: Array = ConfigLoader.lookup(cfg, "road.hills_max_grade", [0.0, 0.025, 0.045, 0.07])
		var max_grade := float(maxes[clampi(level, 0, maxes.size() - 1)])
		if s.tunnel or ahead:
			max_grade *= 0.4
		_h_from = _h_grade
		# mostly alternate up/down so that real crests and dips appear
		var dir := -signf(_h_from) if absf(_h_from) > 0.003 else (1.0 if _rng.randf() < 0.5 else -1.0)
		if _rng.randf() < 0.22:
			dir = -dir
		_h_to = dir * _rng.randf_range(0.5, 1.0) * max_grade
		if _rng.randf() < 0.12:
			_h_to = 0.0
		_h_len = maxi(8, int(_rng.randf_range(130.0, 420.0) / seg_len))
		_h_trans = clampi(int(float(_h_len) * _rng.randf_range(0.25, 0.55)), 6, _h_len)
	var t := clampf(float(_h_pos) / float(_h_trans), 0.0, 1.0)
	_h_pos += 1
	_h_grade = lerpf(_h_from, _h_to, smoothstep(0.0, 1.0, t))
	if s.runout:
		return 0.0
	return _h_grade * _calm(s.z, 30.0, 40.0)


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


## Effective (fractional) lane count at z; lane changes blend over road.lane_transition_m
## (starting at the change point).
func lanes_at(z: float) -> float:
	var lanes := float(_lanes_for(plan.road_at(clampf(z_to_km(z), 0.0, length_km))))
	for c in _road_changes:
		var d := z - float(c["z"])
		if d >= 0.0 and d < _lane_trans:
			lanes = lerpf(float(c["from"]), float(c["to"]), smoothstep(0.0, 1.0, d / _lane_trans))
	return lanes


## Lanes usable by traffic at z (during a transition and shortly before it the smaller count).
func lane_count_at(z: float) -> int:
	var n := _lanes_for(plan.road_at(clampf(z_to_km(z), 0.0, length_km)))
	for c in _road_changes:
		var d := z - float(c["z"])
		if d >= -_lane_trans and d < _lane_trans:
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
	for l in plan.fuel_lanes:
		var z0 := km_to_z(float(l["start_km"]))
		var z1 := km_to_z(float(l["end_km"]))
		if z >= z0 and z <= z1 + _taper:
			if z < z0 + _taper:
				return smoothstep(z0, z0 + _taper, z)
			if z <= z1:
				return 1.0
			return 1.0 - smoothstep(z1, z1 + _taper, z)
	return 0.0


## True where the fuel lane is fully open and refuelling can trigger (StagePlan.fuel_lanes span).
func fuel_lane_at(z: float) -> bool:
	return fuel_lane_factor(z) >= 0.99 and not plan.fuel_lane_at(z_to_km(z)).is_empty()


func fuel_lane_x(z: float) -> float:
	return main_right_edge(z) + lane_w * 0.5


## Visual metres from z to the start of the next fuel lane ahead (INF if none). Used by the autopilot.
func distance_to_fuel_lane(z: float) -> float:
	for l in plan.fuel_lanes:
		var z0 := km_to_z(float(l["start_km"]))
		var z1 := km_to_z(float(l["end_km"]))
		if z1 >= z:
			return maxf(0.0, z0 - z)
	return INF


func road_type_at(z: float) -> String:
	return plan.road_at(clampf(z_to_km(z), 0.0, length_km))


func is_city_at(z: float) -> bool:
	return plan.is_city(clampf(z_to_km(z), 0.0, length_km))


func is_tunnel_at(z: float) -> bool:
	return z <= length_z and plan.in_tunnel(z_to_km(z))


func traffic_factor_at(z: float) -> float:
	return plan.traffic_factor_at(clampf(z_to_km(z), 0.0, length_km))


func country_at(z: float) -> String:
	return plan.country_at(clampf(z_to_km(z), 0.0, length_km))


func speed_limit_at(z: float) -> int:
	return plan.speed_limit_at(clampf(z_to_km(z), 0.0, length_km))


func curve_at(z: float) -> float:
	return get_segment(segment_index_at(z)).curve


## Grip factor of the road at z for the driving model (VehicleModel road "grip", curve limits): the weather
## grip (EnvironmentModel.grip) in the open, 1.0 inside a tunnel (the roof keeps the road dry).
func grip_at(z: float, weather_grip: float) -> float:
	return 1.0 if get_segment(segment_index_at(z)).tunnel else weather_grip


## Road height at z (visual metres, interpolated between segment starts).
func height_at(z: float) -> float:
	var i := segment_index_at(z)
	var a := get_segment(i)
	var b := get_segment(mini(i + 1, segment_count - 1))
	var t := clampf((z - a.z) / seg_len, 0.0, 1.0)
	return lerpf(a.y, b.y, t)


## Physical grade (rise/run) at z, + = uphill (without the visual hill exaggeration).
func grade_at(z: float) -> float:
	var i := segment_index_at(z)
	var a := get_segment(i)
	var b := get_segment(mini(i + 1, segment_count - 1))
	return (b.y - a.y) / seg_len / maxf(0.001, hill_scale)


# --- Events: signs, stations, borders -------------------------------------------------------

func _build_events() -> void:
	_events.clear()
	_clear.clear()
	zones.clear()
	var dest := plan.to_name
	# Fuel stations: announcements 30/15/5 km, lane sign, price pylon, pump islands, canopies, shop.
	var announce: Array = ConfigLoader.lookup(cfg, "fuel.announce_km", [30, 15, 5])
	for st in plan.fuel_stations_km:
		for k in announce:
			_add_event(st - float(k), {"kind": "sign", "sign": "fuel", "text": "%d km" % int(k), "value": int(k), "side": 1})
	for l in plan.fuel_lanes:
		var z0 := km_to_z(float(l["start_km"]))
		var z1 := km_to_z(float(l["end_km"]))
		_add_event_z(z0 - 22.0, {"kind": "sign", "sign": "fuel_lane", "side": 1})
		_add_event_z(z0 + _taper * 0.6, {"kind": "object", "obj": "fuel_pylon", "side": 1, "at": "edge", "offset": 6.5})
		var za := z0 + _taper + 4.0
		var zb := z1 - 4.0
		zones.append({"kind": "fuel", "z0": za, "z1": zb})
		var zc := za + 4.0
		while zc + 8.0 < zb:
			var ze := minf(zc + 12.0, zb - 2.0)
			zones.append({"kind": "fuel_canopy", "z0": zc, "z1": ze})
			for zp: float in [zc + 3.0, zc + 8.5]:
				if zp < ze - 1.0:
					_add_event_z(zp, {"kind": "prop", "set": "props/fuel_pump", "proc": "pump", "side": 1, "at": "edge", "offset": 1.35})
			zc += 22.0
		_add_event_z(z1 - 8.0, {"kind": "prop", "set": "props/fuel_station", "proc": "station", "side": 1, "at": "edge", "offset": 19.0})
		_mark_clear(z0 - 40.0, z1 + _taper + 30.0, 1)
	# Radar: warning 10 km before (with limit), limit signs at the zone, cameras, end of the limit.
	for r in plan.radars:
		var rk := float(r["km"])
		var lim := int(r["limit"])
		_add_event(float(r["warn_km"]), {"kind": "sign", "sign": "radar", "value": lim, "text": "%d km" % int(round(rk - float(r["warn_km"]))), "side": 1})
		_add_event(rk, {"kind": "sign", "sign": "limit", "value": lim, "side": 1})
		_add_event(rk, {"kind": "sign", "sign": "limit", "value": lim, "side": -1})
		_add_event(rk + 0.25, {"kind": "prop", "set": "props/radar_camera", "proc": "radar_cam", "side": 1, "offset": 0.3})
		var mid := (rk + float(r["end_km"])) * 0.5
		_add_event(mid, {"kind": "sign", "sign": "limit", "value": lim, "side": 1})
		_add_event(mid + 0.25, {"kind": "prop", "set": "props/radar_camera", "proc": "radar_cam", "side": 1, "offset": 0.3})
		var after := plan.speed_limit_at(float(r["end_km"]) + 0.05)
		if after != lim:
			_add_event(float(r["end_km"]), {"kind": "sign", "sign": "limit" if after > 0 else "unlimited", "value": after, "side": 1})
		for k: float in [rk, rk + 0.25, mid, mid + 0.25]:
			_mark_clear(km_to_z(k) - 12.0, km_to_z(k) + 6.0, 3)
	# Speed limits and road type at section starts.
	var prev_limit := -1
	var prev_road := ""
	for sec in plan.sections:
		var start := float(sec["start_km"])
		var lim := int(sec["speed_limit"])
		var road := str(sec["road"])
		if start >= plan.city_limits_km:
			break
		if road != prev_road and start > 0.0:
			if road == "autobahn":
				_add_event(start + 0.05, {"kind": "sign", "sign": "autobahn", "side": 1})
			elif prev_road == "autobahn":
				_add_event(start + 0.05, {"kind": "sign", "sign": "autobahn_end", "side": 1})
		if lim != prev_limit and not (lim == 0 and prev_limit <= 0 and start > 0.0):
			_add_event(start + 0.2, {"kind": "sign", "sign": "limit" if lim > 0 else "unlimited", "value": lim, "side": 1})
		prev_limit = lim
		prev_road = road
	# Tunnels: name sign before the portal, no scenery right at the portals.
	for t in plan.tunnels:
		var t0 := float(t["start_km"])
		var t1 := float(t["end_km"])
		if str(t["name"]) != "":
			_add_event(maxf(0.0, t0 - 0.6), {"kind": "sign", "sign": "tunnel", "text": str(t["name"]), "value": int(round((t1 - t0) * 1000.0)), "side": 1})
		_mark_clear(km_to_z(t0) - 45.0, km_to_z(t1) + 12.0, 3)
	# Borders: EU country sign, control station (canopy + booths), new speed limit.
	for b in plan.borders:
		var bk := float(b["km"])
		var bz := km_to_z(bk)
		var name_local := str(b.get("name_local", b.get("name", b["to"])))
		_add_event_z(bz - 22.0, {"kind": "sign", "sign": "border", "text": name_local, "side": 1, "country": str(b["to"])})
		_add_event_z(bz - 22.0, {"kind": "sign", "sign": "border", "text": name_local, "side": -1, "country": str(b["to"])})
		zones.append({"kind": "border", "z0": bz, "z1": bz + 18.0, "country": str(b["to"])})
		_add_event_z(bz + 5.0, {"kind": "prop", "set": "props/customs_booth", "proc": "booth", "side": 1, "at": "edge", "offset": 1.6})
		_add_event_z(bz + 5.0, {"kind": "prop", "set": "props/customs_booth", "proc": "booth", "side": -1, "at": "edge", "offset": 1.6})
		var new_limit := plan.speed_limit_at(bk + 0.6)
		if new_limit != plan.speed_limit_at(maxf(0.0, bk - 0.05)) and bk + 0.6 < plan.city_limits_km:
			_add_event(bk + 0.6, {"kind": "sign", "sign": "limit" if new_limit > 0 else "unlimited", "value": new_limit, "side": 1})
		_mark_clear(bz - 45.0, bz + 45.0, 3)
	# City Limits: yellow town sign with the destination, city speed limit.
	_add_event(plan.city_limits_km, {"kind": "sign", "sign": "town", "text": dest, "side": 1})
	_add_event(plan.city_limits_km, {"kind": "sign", "sign": "town", "text": dest, "side": -1})
	_add_event(plan.city_limits_km + 0.15, {"kind": "sign", "sign": "limit", "value": plan.city_speed_limit, "side": 1})
	_mark_clear(km_to_z(plan.city_limits_km) - 20.0, km_to_z(plan.city_limits_km) + 20.0, 3)
	# Distance signs to the destination.
	for left: float in [25.0, 50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0, 400.0]:
		var pos := plan.length_km - left
		if pos > 1.5 and pos < plan.city_limits_km - 0.5:
			_add_event(pos, {"kind": "sign", "sign": "distance", "text": dest, "value": int(left), "side": 1})
	if plan.length_km > 30.0:
		_add_event(1.0, {"kind": "sign", "sign": "distance", "text": dest, "value": int(round(plan.length_km - 1.0)), "side": 1})
	# Start gantry (countdown lights) and finish gantry.
	_add_event_z(14.0, {"kind": "sign", "sign": "start", "side": 0})
	_add_event_z(length_z, {"kind": "sign", "sign": "finish", "text": "ZIEL", "side": 0})
	_mark_clear(length_z - 30.0, length_z + 20.0, 3)
	zones.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["z0"]) < float(y["z0"]))


func _add_event(km: float, e: Dictionary) -> void:
	if km < 0.0 or km > plan.length_km:
		return
	_add_event_z(km_to_z(km), e)


func _add_event_z(z: float, e: Dictionary) -> void:
	if z < 0.0:
		return
	var i := segment_index_at(z)
	if not _events.has(i):
		_events[i] = []
	var ev := e.duplicate()
	ev["z"] = z
	(_events[i] as Array).append(ev)


func _mark_clear(z0: float, z1: float, mask: int) -> void:
	for i in range(segment_index_at(maxf(0.0, z0)), segment_index_at(maxf(0.0, z1)) + 1):
		_clear[i] = int(_clear.get(i, 0)) | mask


## Signs/props from km events, sorted by z inside the segment.
func events_for_segment(index: int) -> Array:
	return _events.get(index, [])


func _mark_zones(s: TrackSegment) -> void:
	var z0 := s.z
	var z1 := s.z + seg_len
	for zn in zones:
		var a := float(zn["z0"])
		var b := float(zn["z1"])
		if a > z1:
			break
		if b <= z0:
			continue
		match str(zn["kind"]):
			"fuel":
				s.fuel_zone |= TrackSegment.FUEL_ISLAND
			"fuel_canopy":
				s.fuel_zone |= TrackSegment.FUEL_CANOPY
				if a >= z0 and a < z1:
					s.fuel_zone |= TrackSegment.FUEL_CANOPY_FRONT
			"border":
				s.cover = "border"
				s.country_to = str(zn.get("country", ""))
				if a >= z0 and a < z1:
					s.cover_front = true


## Inside a tunnel the roadside ends at the tube wall (paved edge + shoulder): a sign there is mounted on
## the wall ("wall": true, no posts) with its board inside the tube, scaled down when it would reach
## more than WALL_SIGN_OVERHANG_M over the paved road (it hangs above the traffic's height).
func _mount_on_tunnel_wall(p: Dictionary, edges: Vector2, side: int) -> void:
	var hw := SignPainter.board_half_width(str(p.get("sign", "")))
	var room := shoulder_w - WALL_SIGN_GAP_M + WALL_SIGN_OVERHANG_M
	var sc := minf(float(p.get("scale", 1.0)), room / (2.0 * hw))
	var wall_x := edges.y + shoulder_w if side > 0 else edges.x - shoulder_w
	p["scale"] = sc
	p["wall"] = true
	p["x"] = wall_x - float(side) * (WALL_SIGN_GAP_M + hw * sc)


func _prop_x(edges: Vector2, side: int, at: String, offset: float) -> float:
	if side == 0:
		return 0.0
	var base := edges.y if side > 0 else edges.x
	if at != "edge":
		base += shoulder_w * float(side)
	return base + offset * float(side)


func _place_props(s: TrackSegment) -> void:
	var edges := road_edges_at(s.z)
	for e: Dictionary in _events.get(s.index, []):
		var p := e.duplicate()
		var side := int(e.get("side", 1))
		var kind := str(e.get("kind", "prop"))
		p["scale"] = float(e.get("scale", 1.0))
		if kind == "sign":
			# sign style follows the country and road type where the sign stands (border signs keep the
			# country they announce)
			if not p.has("country"):
				p["country"] = s.country
			p["road"] = s.road
		if s.tunnel and side != 0:
			if kind != "sign":
				continue   # no room for booths, cameras or pumps inside the tube
			_mount_on_tunnel_wall(p, edges, side)
		else:
			p["x"] = _prop_x(edges, side, str(e.get("at", "outer")), float(e.get("offset", 1.0)))
		s.sprites.append(p)
	if s.tunnel:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_seed * 7919 + s.index)
	if s.city:
		# street lights on both sides (procedural, lit at night)
		var every := float(ConfigLoader.lookup(cfg, "road.streetlight_every_m", 33.0))
		var phase := fposmod(s.z, every)
		if phase < seg_len:
			s.sprites.append({"kind": "object", "obj": "streetlight", "side": 1, "x": _prop_x(edges, 1, "outer", -0.6), "scale": 1.0, "z": s.z})
		elif fposmod(s.z + every * 0.5, every) < seg_len:
			s.sprites.append({"kind": "object", "obj": "streetlight", "side": -1, "x": _prop_x(edges, -1, "outer", -0.6), "scale": 1.0, "z": s.z})
	var clear := int(_clear.get(s.index, 0))
	var sc: Dictionary = scenery_db.get(s.scenery, {})
	for rule: Dictionary in sc.get("props", []):
		var every := float(rule.get("every_m", 30.0))
		if fposmod(s.z + float(rule.get("phase_m", 0.0)), every) >= seg_len:
			continue
		var roads: Array = rule.get("roads", [])
		if not roads.is_empty() and not roads.has(s.road):
			continue
		var count := int(rule.get("count", 1))
		for n in count:
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
			var sr: Array = rule.get("scale", [1.0, 1.0])
			var scale := rng.randf_range(float(sr[0]), float(sr[1]))
			var dz := rng.randf_range(0.0, seg_len)
			if off < 25.0 and (clear & (1 if side > 0 else 2)) != 0:
				continue
			var p := {"kind": "prop", "set": str(rule["set"]), "x": _prop_x(edges, side, "outer", off),
				"scale": scale, "side": side, "z": s.z + dz}
			for key: String in ["fallback", "fallback_scale", "tint", "mirror", "align"]:
				if rule.has(key):
					p[key] = rule[key]
			s.sprites.append(p)
	s.sprites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("z", 0.0)) > float(b.get("z", 0.0)))
