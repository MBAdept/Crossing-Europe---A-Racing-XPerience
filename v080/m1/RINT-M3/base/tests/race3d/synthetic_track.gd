extends Track
## Synthetic Track for the race3d tests: every segment has a prescribed curve and height instead of the generated
## road, everything else (lanes, edges, window handling, API) is the real Track. Usage:
##   const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
##   var t: Track = SynTrack.new()
##   t.fill(cfg, SynTrack.arc(300, 134.0))                       # 900 m of a right bend with 134 m radius
## update_window() cuts the window behind the camera like the real track (segments are never generated again).
## Owner: race3d kernel (tests only, no autoloads).

const Fix := preload("res://tests/sim/fixtures.gd")


## opts: {lanes (3.0), road ("autobahn"), hills (0–3, level of the one section), curviness (0), city_from_segment (-1),
## tunnel: [first, last segment], water: [first, last segment, depth_m], fuel_lane: [first, last segment],
## finish_segment (count - 21)}
func fill(config: Dictionary, curves: PackedFloat32Array, heights: PackedFloat32Array = PackedFloat32Array(), opts: Dictionary = {}) -> void:
	var n := curves.size()
	var seg := float(ConfigLoader.lookup(config, "render.segment_length_m", 3.0))
	var scale := float(ConfigLoader.lookup(config, "time.time_scale", 10.0))
	var finish := int(opts.get("finish_segment", maxi(1, n - 21)))
	var length_km_ := float(finish) * seg * scale / 1000.0
	var p := Fix.make_plan(config, length_km_)
	(p.sections[0] as Dictionary)["hills"] = int(opts.get("hills", 0))
	(p.sections[0] as Dictionary)["curviness"] = int(opts.get("curviness", 0))
	(p.sections[0] as Dictionary)["road"] = str(opts.get("road", "autobahn"))
	var city_from := int(opts.get("city_from_segment", -1))
	p.city_limits_km = float(city_from) * seg * scale / 1000.0 if city_from >= 0 else length_km_ + 1.0
	var tun: Array = opts.get("tunnel", [])
	if tun.size() >= 2:
		p.tunnels.append({"start_km": float(tun[0]) * seg * scale / 1000.0, "end_km": float(tun[1]) * seg * scale / 1000.0, "name": "Test"})
	setup(p, config, {})
	segment_count = n
	_segs.clear()
	var lanes := float(opts.get("lanes", 3.0))
	var water: Array = opts.get("water", [])
	var fuel: Array = opts.get("fuel_lane", [])
	for i in n:
		var s := TrackSegment.new()
		s.index = i
		s.z = float(i) * seg_len
		s.km = z_to_km(s.z)
		s.curve = curves[i]
		s.y = heights[i] if i < heights.size() else 0.0
		s.lanes = lanes
		s.lane_count = int(lanes)
		s.road = str(opts.get("road", "autobahn"))
		s.runout = s.z > length_z
		s.city = city_from >= 0 and i >= city_from
		s.tunnel = tun.size() >= 2 and i >= int(tun[0]) and i < int(tun[1])
		if water.size() >= 3 and i >= int(water[0]) and i < int(water[1]):
			s.water = true
			s.water_depth = float(water[2])
			s.water_level = -float(water[2])
		if fuel.size() >= 2 and i >= int(fuel[0]) and i < int(fuel[1]):
			s.fuel_lane = 1.0
		_segs[i] = s
	_gen_next = n


## n straight segments.
static func straight(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(0.0)
	return a


## n segments of a bend with `radius` metres (+ = right, - = left).
static func arc(n: int, radius: float, radius_at_1: float = 120.0) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(radius_at_1 / radius)
	return a


## Concatenates curve pieces.
static func join(parts: Array) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		a.append_array(p)
	return a


## Heights of n boundaries from a list of [first segment, grade] pieces (grade = rise per metre from that segment on).
static func grades(n: int, pieces: Array, seg: float = 3.0) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	var y := 0.0
	var g := 0.0
	var pi := 0
	for i in n:
		while pi < pieces.size() and i >= int((pieces[pi] as Array)[0]):
			g = float((pieces[pi] as Array)[1])
			pi += 1
		a[i] = y
		y += g * seg
	return a
