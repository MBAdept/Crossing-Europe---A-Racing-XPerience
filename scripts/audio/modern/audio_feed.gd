class_name AudioFeed
extends RefCounted
## What the Modern sound knows about the road at the player's car (contract D28, §4.7.2): derived from the Track of
## the stage (AudioManager.set_track) and the vehicle state of the frame (set_vehicle_state) – never from the
## renderer. Pure and read-only: it looks at the structures of the stage (tunnels, bridges, canopies – fixed data of
## the plan) and at the segments at and behind the car, never ahead of it, and changes nothing.
##
## v0 (wave 0). update(state) fills:
##   surface_l / surface_r   what the left / right wheels run on: "asphalt", "rumble" (edge line and rumble strip),
##                           "shoulder" (gravel beside the road), "grass" (beyond the shoulder, no guardrail)
##   wet, snow               0..1 from the weather (dry inside a tunnel)
##   zone                    "tunnel", "bridge", "city", "forest", "valley" (mountains) or "open"
##   tunnel, bridge, cover   the car is in a tunnel / on a bridge of this type / under a canopy ("border", "fuel")
##   road, scenery, city, guardrail, lanes, depth_m (distance to the nearer end of the tunnel or bridge it is in)
##   events                  what the car passed since the last update, in order:
##                           {"name": "tunnel_in" | "tunnel_out" | "bridge_in" | "bridge_out" | "cover_in" | "cover_out", "z", "kind"}
##                           {"name": "joint", "z", "kind": "bridge_end" | "bridge"}  expansion joints of a bridge
##                           {"name": "pass_object", "z", "side": −1 | 0 | 1, "dist_m", "size", "kind", "set"}
##                              roadside things within pass_max_m: kind "tree", "building", "post", "sign", "gantry"
##                              (overhead, side 0), "rock", "object"
## Jumps (start of a stage, more than max_scan_m in one step) reset the position without events.

const SURFACES: Array[String] = ["asphalt", "rumble", "shoulder", "grass"]
const ZONES: Array[String] = ["open", "forest", "valley", "city", "bridge", "tunnel"]
## Sprite set prefix -> [kind, size] of a passed roadside object (first match wins).
const PROP_KINDS: Array = [
	["props/tree_", "tree", 1.0], ["props/bush", "", 0.0], ["props/heather", "", 0.0], ["props/haybale", "", 0.0],
	["props/rock", "rock", 0.8], ["props/cliff", "rock", 2.0],
	["props/streetlight", "post", 0.3], ["props/delineator", "post", 0.15], ["props/power_pylon", "post", 0.8],
	["props/radar_camera", "post", 0.3], ["props/fuel_pump", "post", 0.5],
	["props/city_", "building", 2.0], ["props/building", "building", 2.0], ["props/house", "building", 1.6],
	["props/farmhouse", "building", 1.6], ["props/barn", "building", 1.8], ["props/fuel_station", "building", 1.5],
	["props/customs_booth", "building", 1.0], ["landmarks/", "building", 3.0],
]
## Scenery background style (data/scenery.json) -> zone.
const STYLE_ZONES := {"forest": "forest", "mountains": "valley", "alps": "valley", "city": "city", "suburb": "city",
	"industrial": "city"}

# configuration (audio.modern.feed)
var rumble_in_m := 0.3           ## width of the edge line inside the paved edge that sounds as "rumble"
var rumble_out_m := 0.5          ## width of the rumble strip outside the paved edge
var track_half_m := 0.78         ## half the track width of the car (wheel positions x ± this)
var pass_max_m := 18.0           ## roadside objects farther from the car than this are not reported
var max_scan_m := 90.0           ## a larger step than this is a jump (no events)
var joint_every_m := 24.0        ## expansion joints on a bridge (0 = only at its ends)
var max_events := 12             ## per update

var track: Object = null
var plan: Object = null

var valid := false               ## update() ran with a state that has a position
var z := 0.0
var x := 0.0
var surface_l := "asphalt"
var surface_r := "asphalt"
var wet := 0.0
var snow := 0.0
var zone := "open"
var tunnel := false
var bridge := ""
var cover := ""
var depth_m := 0.0
var road := "autobahn"
var scenery := ""
var city := false
var guardrail := false
var lanes := 3.0
var events: Array[Dictionary] = []

var _structures: Array[Dictionary] = []   ## {kind: "tunnel"|"bridge"|"cover", type, z0, z1}, sorted by z0
var _prev_z := 0.0
var _has_prev := false
var _seg_len := 3.0


func setup(modern: Dictionary) -> void:
	var f: Variant = modern.get("feed", {})
	if not (f is Dictionary):
		return
	var d: Dictionary = f
	rumble_in_m = maxf(float(d.get("rumble_in_m", rumble_in_m)), 0.0)
	rumble_out_m = maxf(float(d.get("rumble_out_m", rumble_out_m)), 0.0)
	track_half_m = clampf(float(d.get("track_half_m", track_half_m)), 0.3, 1.5)
	pass_max_m = maxf(float(d.get("pass_max_m", pass_max_m)), 0.0)
	max_scan_m = maxf(float(d.get("max_scan_m", max_scan_m)), 3.0)
	joint_every_m = maxf(float(d.get("joint_every_m", joint_every_m)), 0.0)
	max_events = clampi(int(d.get("max_events", max_events)), 1, 64)


## Half the track width from the car's body width (vehicles.types.<id>.width_m).
func set_vehicle_width(width_m: float) -> void:
	if width_m > 0.5:
		track_half_m = clampf(width_m * 0.42, 0.3, 1.5)


## The track of the stage (and its plan), or (null, null) when the stage is over.
func set_track(p_track: Object, p_plan: Object = null) -> void:
	track = p_track
	plan = p_plan
	_structures.clear()
	_has_prev = false
	valid = false
	events.clear()
	_reset_values()
	if track == null:
		return
	var sl: Variant = track.get("seg_len")
	_seg_len = maxf(float(sl), 0.5) if (sl is float or sl is int) else 3.0
	if plan == null and track.get("plan") != null:
		plan = track.get("plan")
	_collect_structures()


func has_track() -> bool:
	return track != null


func _reset_values() -> void:
	surface_l = "asphalt"
	surface_r = "asphalt"
	wet = 0.0
	snow = 0.0
	zone = "open"
	tunnel = false
	bridge = ""
	cover = ""
	depth_m = 0.0
	road = "autobahn"
	scenery = ""
	city = false
	guardrail = false
	lanes = 3.0


## Tunnels (plan), bridges and canopies (track) as z intervals – fixed data of the stage, no segment is touched.
func _collect_structures() -> void:
	var ts: float = float(track.get("time_scale")) if track.get("time_scale") != null else 10.0
	var tunnels: Variant = plan.get("tunnels") if plan != null else null
	if tunnels is Array:
		for t: Variant in tunnels:
			if t is Dictionary and (t as Dictionary).has("start_km") and (t as Dictionary).has("end_km"):
				_structures.append({"kind": "tunnel", "type": "tunnel", "z0": float(t["start_km"]) * 1000.0 / ts,
					"z1": float(t["end_km"]) * 1000.0 / ts})
	var bridges: Variant = track.get("bridges")
	if bridges is Array:
		for b: Variant in bridges:
			if b is Dictionary and (b as Dictionary).has("z0") and (b as Dictionary).has("z1"):
				_structures.append({"kind": "bridge", "type": str((b as Dictionary).get("type", "bridge")), "z0": float(b["z0"]), "z1": float(b["z1"])})
	var zones: Variant = track.get("zones")
	if zones is Array:
		for zn: Variant in zones:
			if not (zn is Dictionary):
				continue
			var kind := str((zn as Dictionary).get("kind", ""))
			if kind == "border" or kind == "fuel_canopy":
				_structures.append({"kind": "cover", "type": "border" if kind == "border" else "fuel", "z0": float(zn["z0"]), "z1": float(zn["z1"])})
	_structures.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["z0"]) < float(b["z0"]))


## The structures of the stage as collected ({kind, type, z0, z1}) – tests.
func structures() -> Array[Dictionary]:
	return _structures


## One frame: `state` = the vehicle state of §4.7.2 (needs "z" and "x"). Without a track or a position nothing is
## derived (valid = false, neutral values).
func update(state: Dictionary) -> void:
	events.clear()
	if track == null or not state.has("z"):
		valid = false
		return
	z = float(state["z"])
	x = float(state.get("x", 0.0))
	valid = true
	var moved := _has_prev and z >= _prev_z and z - _prev_z <= max_scan_m
	_update_structures(moved)
	_update_segment(state)
	_update_surfaces(state)
	if moved and pass_max_m > 0.0:
		_scan_objects(_prev_z, z)
	_prev_z = z
	_has_prev = true


func _update_structures(moved: bool) -> void:
	tunnel = false
	bridge = ""
	cover = ""
	depth_m = 0.0
	for s in _structures:
		var z0 := float(s["z0"])
		var z1 := float(s["z1"])
		var kind := str(s["kind"])
		if moved:
			# boundaries crossed since the last update
			if _prev_z < z0 and z >= z0:
				_event({"name": kind + "_in", "z": z0, "kind": str(s["type"])})
				if kind == "bridge":
					_event({"name": "joint", "z": z0, "kind": "bridge_end"})
			if kind == "bridge" and joint_every_m > 0.0 and z > z0 and _prev_z < z1:
				var a := int(floor((clampf(_prev_z, z0, z1) - z0) / joint_every_m))
				var b := int(floor((clampf(z, z0, z1) - z0) / joint_every_m))
				for j in range(a + 1, b + 1):
					var zj := z0 + float(j) * joint_every_m
					if zj < z1 - 0.5 * joint_every_m:
						_event({"name": "joint", "z": zj, "kind": "bridge"})
			if _prev_z < z1 and z >= z1:
				if kind == "bridge":
					_event({"name": "joint", "z": z1, "kind": "bridge_end"})
				_event({"name": kind + "_out", "z": z1, "kind": str(s["type"])})
		if z >= z0 and z < z1:
			match kind:
				"tunnel":
					tunnel = true
					depth_m = minf(z - z0, z1 - z)
				"bridge":
					bridge = str(s["type"])
					if not tunnel:
						depth_m = minf(z - z0, z1 - z)
				"cover":
					cover = str(s["type"])


func _segment(index: int) -> Object:
	if index < 0 or not track.has_method("get_segment"):
		return null
	var s: Variant = track.call("get_segment", index)
	# a segment already discarded behind the camera comes back as the oldest one kept
	if s is Object and int((s as Object).get("index")) == index:
		return s
	return null


func _update_segment(state: Dictionary) -> void:
	var seg := _segment(int(floor(z / _seg_len)))
	if seg != null:
		road = str(seg.get("road"))
		scenery = str(seg.get("scenery"))
		city = bool(seg.get("city"))
		guardrail = bool(seg.get("guardrail"))
		lanes = float(seg.get("lanes"))
	var w := str(state.get("weather", "normal"))
	wet = 1.0 if (w == "rain" and not tunnel) else 0.0
	snow = 1.0 if (w == "snow" and not tunnel) else 0.0
	if tunnel:
		zone = "tunnel"
	elif bridge != "":
		zone = "bridge"
	elif city:
		zone = "city"
	else:
		zone = "open"
		var db: Variant = track.get("scenery_db")
		if db is Dictionary and (db as Dictionary).get(scenery, null) is Dictionary:
			var bg: Variant = ((db as Dictionary)[scenery] as Dictionary).get("background", {})
			if bg is Dictionary:
				zone = str(STYLE_ZONES.get(str((bg as Dictionary).get("style", "")), "open"))


func _update_surfaces(state: Dictionary) -> void:
	var left := float(state.get("road_left", -5.625))
	var right := float(state.get("road_right", 5.625))
	if not state.has("road_left") and track.has_method("road_edges_at"):
		var e: Variant = track.call("road_edges_at", z)
		if e is Vector2:
			left = (e as Vector2).x
			right = (e as Vector2).y
	var shoulder := float(state.get("shoulder_m", 2.5))
	var at_limit := int(state.get("off_road", 0)) >= 2 and not bool(state.get("rail_contact", false))
	surface_l = surface_at(x - track_half_m, left, right, shoulder, at_limit and x < (left + right) * 0.5)
	surface_r = surface_at(x + track_half_m, left, right, shoulder, at_limit and x >= (left + right) * 0.5)


## Surface under a wheel at lateral position wx: paved between left and right (the edge line counts as "rumble"),
## the rumble strip just outside, then the shoulder; "grass" when the car is at the open limit on that side or the
## wheel is beyond the shoulder.
func surface_at(wx: float, left: float, right: float, shoulder_m: float, on_grass: bool) -> String:
	var out := maxf(left - wx, wx - right)   # > 0: outside the paved road by this much
	if on_grass or out > shoulder_m:
		return "grass"
	if out > rumble_out_m:
		return "shoulder"
	if out > -rumble_in_m:
		return "rumble"
	return "asphalt"


## Roadside objects of the segments the car passed in (z_from, z_to].
func _scan_objects(z_from: float, z_to: float) -> void:
	var i0 := int(floor(z_from / _seg_len))
	var i1 := int(floor(z_to / _seg_len))
	for i in range(i0, i1 + 1):
		var seg := _segment(i)
		if seg == null:
			continue
		var sprites: Variant = seg.get("sprites")
		if not (sprites is Array):
			continue
		var seg_z := float(seg.get("z"))
		for p: Variant in sprites:
			if not (p is Dictionary):
				continue
			var d: Dictionary = p
			var pz := float(d.get("z", seg_z))
			if pz <= z_from or pz > z_to:
				continue
			var info := object_kind(d)
			if str(info[0]) == "":
				continue
			var side := int(d.get("side", 1))
			var dx := float(d.get("x", 0.0)) - x
			var dist := 0.0 if side == 0 else absf(dx)
			if dist > pass_max_m:
				continue
			_event({"name": "pass_object", "z": pz, "side": 0 if side == 0 else (1 if dx >= 0.0 else -1), "dist_m": dist,
				"size": float(info[1]) * float(d.get("scale", 1.0)), "kind": str(info[0]),
				"set": str(d.get("set", d.get("sign", d.get("obj", ""))))})


## [kind, size] of a segment sprite as a passed object ("" = makes no sound: bushes, low things).
static func object_kind(p: Dictionary) -> Array:
	var kind := str(p.get("kind", "prop"))
	if kind == "sign":
		return ["gantry", 2.0] if int(p.get("side", 1)) == 0 else ["sign", 0.5]
	if kind == "object":
		var obj := str(p.get("obj", ""))
		return ["post", 0.3 if obj == "streetlight" else 0.6]
	var set_id := str(p.get("set", ""))
	for row: Array in PROP_KINDS:
		if set_id.begins_with(str(row[0])):
			return [str(row[1]), float(row[2])]
	return ["object", 0.5]


func _event(e: Dictionary) -> void:
	if events.size() < max_events:
		events.append(e)


## Plain data for tests and debugging.
func state() -> Dictionary:
	return {"valid": valid, "z": z, "x": x, "surface_l": surface_l, "surface_r": surface_r, "wet": wet, "snow": snow,
		"zone": zone, "tunnel": tunnel, "bridge": bridge, "cover": cover, "depth_m": depth_m, "road": road,
		"scenery": scenery, "city": city, "guardrail": guardrail, "lanes": lanes, "events": events.size()}
