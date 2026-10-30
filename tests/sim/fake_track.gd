extends RefCounted
## Minimal straight track for gameplay tests and simulations (duck-typed like Track, see ARCHITECTURE.md
## §Strecke): sections with road type / lane count / traffic factor, optional City Limits, fuel lanes,
## lane transitions and curves. Owner: gameplay module (tests only).

var length_z := 20000.0
var seg_len := 3.0
var lane_w := 3.75
var shoulder_w := 2.5
var time_scale := 12.0
var lane_transition_m := 180.0
## {z0, z1, road, lanes, traffic, curve}
var sections: Array[Dictionary] = []
var city_z := INF:
	set(v):
		city_z = v
		_dirty = true
var city_lanes := 2:
	set(v):
		city_lanes = v
		_dirty = true
## {z0, z1} spans where the fuel lane is fully open
var fuel_spans: Array[Dictionary] = []
var guardrail := {"autobahn": true, "landstrasse": false, "city": false}

var _dirty := true
var _change_cache: Array[Dictionary] = []


func _init(length_m: float = 20000.0, road: String = "autobahn", lanes: int = 3) -> void:
	length_z = length_m
	sections = [{"z0": 0.0, "z1": length_m, "road": road, "lanes": lanes, "traffic": 1.0, "curve": 0.0}]
	_dirty = true


## Replaces the sections: [{length, road, lanes, traffic?, curve?}, ...] laid out from z = 0.
func set_sections(list: Array) -> void:
	sections.clear()
	var z := 0.0
	for s: Dictionary in list:
		var length := float(s.get("length", 1000.0))
		sections.append({"z0": z, "z1": z + length, "road": str(s.get("road", "autobahn")), "lanes": int(s.get("lanes", 3)),
			"traffic": float(s.get("traffic", 1.0)), "curve": float(s.get("curve", 0.0))})
		z += length
	length_z = z
	_dirty = true


func add_fuel_lane(z0: float, z1: float) -> void:
	fuel_spans.append({"z0": z0, "z1": z1})


func km_to_z(km: float) -> float:
	return km * 1000.0 / time_scale


func z_to_km(z: float) -> float:
	return z * time_scale / 1000.0


func _section(z: float) -> Dictionary:
	for s in sections:
		if z < float(s["z1"]):
			return s
	return sections[sections.size() - 1]


func _lanes_raw(z: float) -> int:
	if z >= city_z:
		return city_lanes
	return int(_section(z)["lanes"])


## Lane changes: section boundaries and the City Limits start.
func _changes() -> Array[Dictionary]:
	if not _dirty:
		return _change_cache
	var out: Array[Dictionary] = []
	var pts: Array[float] = []
	for s in sections:
		pts.append(float(s["z0"]))
	if city_z < length_z:
		pts.append(city_z)
	for z in pts:
		if z <= 0.0:
			continue
		var a := _lanes_raw(z - 0.01)
		var b := _lanes_raw(z + 0.01)
		if a != b:
			out.append({"z": z, "from": a, "to": b})
	_change_cache = out
	_dirty = false
	return out


func lanes_at(z: float) -> float:
	var lanes := float(_lanes_raw(z))
	for c in _changes():
		var d := z - float(c["z"])
		if d >= 0.0 and d < lane_transition_m:
			lanes = lerpf(float(c["from"]), float(c["to"]), smoothstep(0.0, 1.0, d / lane_transition_m))
	return lanes


func lane_count_at(z: float) -> int:
	var n := _lanes_raw(z)
	for c in _changes():
		var d := z - float(c["z"])
		if d >= -lane_transition_m and d < lane_transition_m:
			n = mini(int(c["from"]), int(c["to"]))
	return n


func lane_center_x(z: float, lane: int) -> float:
	return -lanes_at(z) * lane_w * 0.5 + lane_w * (float(lane) + 0.5)


func main_right_edge(z: float) -> float:
	return lanes_at(z) * lane_w * 0.5


func fuel_lane_factor(z: float) -> float:
	return 1.0 if fuel_lane_at(z) else 0.0


func road_edges_at(z: float) -> Vector2:
	var half := lanes_at(z) * lane_w * 0.5
	return Vector2(-half, half + fuel_lane_factor(z) * lane_w)


func fuel_lane_at(z: float) -> bool:
	for f in fuel_spans:
		if z >= float(f["z0"]) and z <= float(f["z1"]):
			return true
	return false


func fuel_lane_x(z: float) -> float:
	return main_right_edge(z) + lane_w * 0.5


func road_type_at(z: float) -> String:
	if z >= city_z:
		return "city"
	return str(_section(z)["road"])


func is_city_at(z: float) -> bool:
	return z >= city_z


func is_tunnel_at(_z: float) -> bool:
	return false


func traffic_factor_at(z: float) -> float:
	return float(_section(z)["traffic"])


func curve_at(z: float) -> float:
	return float(_section(z)["curve"])


func grade_at(_z: float) -> float:
	return 0.0


func guardrail_at(z: float) -> bool:
	return bool(guardrail.get(road_type_at(z), false))


## Road dictionary for VehicleModel.update at z (like RaceSession.road_info).
func road_info(z: float, grip: float = 1.0) -> Dictionary:
	var e := road_edges_at(z)
	return {"curve": curve_at(z), "grade": grade_at(z), "left_edge": e.x, "right_edge": e.y,
		"shoulder_m": shoulder_w, "guardrail": guardrail_at(z), "grip": grip}
