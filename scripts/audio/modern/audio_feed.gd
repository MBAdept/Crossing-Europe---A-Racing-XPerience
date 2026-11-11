class_name AudioFeed
extends RefCounted
## What the Modern sound knows about the road at the player's car (contract D28, §4.7.2): derived from the Track of
## the stage (AudioManager.set_track) and the vehicle state of the frame (set_vehicle_state) – never from the
## renderer. Pure and read-only: it looks at the structures and sections of the stage (tunnels, bridges, canopies,
## road sections – fixed data of the plan) and at the segments at and behind the car, never ahead of it, and changes
## nothing.
##
## v1 (AU-C1). update(state) fills:
##   surface_l / surface_r   what the left / right wheels run on: the paving of the road ("asphalt", "concrete",
##                           "cobbles", "deck" – a steel bridge deck), "rumble" (profiled edge line and rumble strip,
##                           only on rumble_roads; not on the right while the segment has a fuel lane – its edge is a
##                           plain dashed line, AU-R), "shoulder" (gravel beside the road), "grass" (beyond the shoulder,
##                           no guardrail). In tunnels, on bridges and in the City Limits the shoulder is paved.
##   paving                  the paving at the car: "asphalt", "concrete" (sections of concrete_roads, chosen per
##                           section from concrete_share – the same section has the same paving in both directions),
##                           "cobbles" (blocks of the city centre of cobble_styles, and stone bridges), "deck"
##   deck                    material of the bridge the car is on: "steel", "concrete", "stone" ("" = no bridge)
##   rumble_road             the road has profiled edge lines (rumble_roads)
##   wet, snow               0..1 from the weather (dry inside a tunnel)
##   zone                    "tunnel", "bridge", "city", "cutting" (rock or cliff close beside the road on both sides
##                           within cutting_window_m behind the car), "forest", "valley" (mountains) or "open"
##   tunnel, bridge, cover   the car is in a tunnel / on a bridge of this type / under a canopy ("border", "fuel")
##   road, scenery, city, guardrail, lanes, depth_m (distance to the nearer end of the tunnel or bridge it is in)
##   events                  what the car passed since the last update, in order:
##                           {"name": "tunnel_in" | "tunnel_out" | "bridge_in" | "bridge_out" | "cover_in" | "cover_out", "z", "kind"}
##                           {"name": "joint", "z", "kind": "bridge_end" | "bridge", "deck"}  expansion joints of a bridge
##                              (spacing per deck, joint_every: steel at both ends and between the spans, concrete
##                              viaducts every 32 m, stone arches none – AU-R)
##                           {"name": "pass_object", "z", "side": −1 | 0 | 1, "dist_m", "size", "kind", "set", "contact"}
##                              roadside things within pass_max_m: kind "tree", "building", "post", "sign", "gantry"
##                              (overhead, side 0), "rock", "object"; the delineator posts of roads without a guardrail
##                              (road.delineator_every_m, as the road is drawn) as kind "post", set "delineator";
##                              contact = the body of the car overlaps a delineator (it brushes it down)
## Jumps (start of a stage, more than max_scan_m in one step) reset the position without events.

const SURFACES: Array[String] = ["asphalt", "concrete", "cobbles", "deck", "rumble", "shoulder", "grass"]
const PAVINGS: Array[String] = ["asphalt", "concrete", "cobbles", "deck"]
const ZONES: Array[String] = ["open", "forest", "valley", "cutting", "city", "bridge", "tunnel"]
## Bridge type (CityData.BRIDGE_TYPES) -> deck material.
const BRIDGE_DECKS := {"cable_stayed": "steel", "truss_arch": "steel", "stone_arch": "stone", "canal": "concrete",
	"causeway": "concrete", "river": "concrete"}
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
const DELINEATOR_SIZE := 0.15
const DELINEATOR_INSET_M := 0.3   ## the posts stand this far inside the outer edge of the shoulder (as drawn)
const POST_RADIUS_M := 0.06       ## half the width of a delineator post (contact)

# configuration (audio.modern.feed)
var rumble_in_m := 0.3           ## width of the edge line inside the paved edge that sounds as "rumble"
var rumble_out_m := 0.5          ## width of the rumble strip outside the paved edge
var track_half_m := 0.78         ## half the track width of the car (wheel positions x ± this)
var body_half_m := 0.93          ## half the body width of the car (contact with a delineator)
var pass_max_m := 18.0           ## roadside objects farther from the car than this are not reported
var max_scan_m := 90.0           ## a larger step than this is a jump (no events)
## Expansion joints of a bridge per deck material (feed.joint_every_m – a table, or one number for every deck):
## metres between the joints (visible metres), 0 = only at the two ends, < 0 = none at all. A continuous steel
## girder has joints at its abutments and between its spans, a masonry arch none, an old concrete viaduct of simply
## supported spans one every span (KRITIK-FAHRBAHN B5).
var joint_every: Dictionary = {"steel": 100.0, "stone": -1.0, "concrete": 32.0}
var max_events := 12             ## per update
var rumble_roads: Array[String] = ["autobahn"]       ## road types with profiled edge lines
var concrete_roads: Array[String] = ["autobahn"]     ## road types that can be concrete
var concrete_share: Dictionary = {"DE": 0.35, "_": 0.12}   ## country -> share of concrete sections ("_" = others)
var concrete_threshold: Dictionary = {}   ## country -> [share, hash threshold] (calibrate_concrete.gd; AU-R)
var cobble_styles: Array[String] = []                ## city styles with cobbled blocks in the centre
var cobble_share := 0.6          ## share of the centre's blocks that are cobbled
var cobble_block_m := 90.0       ## length of such a block (visible metres)
var cutting_dist_m := 14.0       ## a rock or cliff this close to the paved edge counts for a cutting …
var cutting_window_m := 60.0     ## … when both sides had one within this distance behind the car
var delineators := true          ## report the delineator posts of roads without a guardrail

var track: Object = null
var plan: Object = null

var valid := false               ## update() ran with a state that has a position
var z := 0.0
var x := 0.0
var surface_l := "asphalt"
var surface_r := "asphalt"
var paving := "asphalt"
var deck := ""
var rumble_road := true
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
var fuel_lane := 0.0             ## share of the fuel lane on the right of the segment at the car (0 = none)
var events: Array[Dictionary] = []

var _structures: Array[Dictionary] = []   ## {kind: "tunnel"|"bridge"|"cover", type, z0, z1}, sorted by z0
var _prev_z := 0.0
var _has_prev := false
var _seg_len := 3.0
var _time_scale := 10.0
var _delin_every := 50.0
var _shoulder_w := 2.5
var _concrete: Dictionary = {}   ## section index -> bool (cached decision)
var _cobbles: Dictionary = {}    ## block index -> bool
var _rock_z := [-1.0e9, -1.0e9]  ## z of the last rock / cliff close to the left / right edge


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
	var je: Variant = d.get("joint_every_m", null)
	if je is Dictionary:
		for k: String in je:
			if not k.begins_with("_"):
				joint_every[k] = float(je[k])
	elif je is float or je is int:
		for k: String in ["steel", "stone", "concrete"]:
			joint_every[k] = float(je)
	max_events = clampi(int(d.get("max_events", max_events)), 1, 64)
	rumble_roads = _strings(d.get("rumble_roads", rumble_roads))
	concrete_roads = _strings(d.get("concrete_roads", concrete_roads))
	if d.get("concrete_share", null) is Dictionary:
		concrete_share = (d["concrete_share"] as Dictionary).duplicate()
	if d.get("concrete_threshold", null) is Dictionary:
		concrete_threshold = (d["concrete_threshold"] as Dictionary).duplicate(true)
	cobble_styles = _strings(d.get("cobble_styles", cobble_styles))
	cobble_share = clampf(float(d.get("cobble_share", cobble_share)), 0.0, 1.0)
	cobble_block_m = maxf(float(d.get("cobble_block_m", cobble_block_m)), 10.0)
	cutting_dist_m = maxf(float(d.get("cutting_dist_m", cutting_dist_m)), 0.0)
	cutting_window_m = maxf(float(d.get("cutting_window_m", cutting_window_m)), 0.0)
	delineators = bool(d.get("delineators", delineators))


static func _strings(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for s: Variant in v:
			out.append(str(s))
	return out


## Half the track and the body width from the car's width (vehicles.types.<id>.width_m).
func set_vehicle_width(width_m: float) -> void:
	if width_m > 0.5:
		track_half_m = clampf(width_m * 0.42, 0.3, 1.5)
		body_half_m = clampf(width_m * 0.5, 0.3, 1.6)


## The track of the stage (and its plan), or (null, null) when the stage is over.
func set_track(p_track: Object, p_plan: Object = null) -> void:
	track = p_track
	plan = p_plan
	_structures.clear()
	_concrete.clear()
	_cobbles.clear()
	_has_prev = false
	valid = false
	events.clear()
	_reset_values()
	if track == null:
		return
	var sl: Variant = track.get("seg_len")
	_seg_len = maxf(float(sl), 0.5) if (sl is float or sl is int) else 3.0
	var ts: Variant = track.get("time_scale")
	_time_scale = float(ts) if (ts is float or ts is int) else 10.0
	var sw: Variant = track.get("shoulder_w")
	_shoulder_w = float(sw) if (sw is float or sw is int) else 2.5
	var tc: Variant = track.get("cfg")
	_delin_every = maxf(float(ConfigLoader.lookup(tc, "road.delineator_every_m", 50.0)), 1.0) if tc is Dictionary else 50.0
	if plan == null and track.get("plan") != null:
		plan = track.get("plan")
	_collect_structures()


func has_track() -> bool:
	return track != null


func _reset_values() -> void:
	surface_l = "asphalt"
	surface_r = "asphalt"
	paving = "asphalt"
	deck = ""
	rumble_road = true
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
	fuel_lane = 0.0
	_rock_z = [-1.0e9, -1.0e9]


## Tunnels (plan), bridges and canopies (track) as z intervals – fixed data of the stage, no segment is touched.
func _collect_structures() -> void:
	var tunnels: Variant = plan.get("tunnels") if plan != null else null
	if tunnels is Array:
		for t: Variant in tunnels:
			if t is Dictionary and (t as Dictionary).has("start_km") and (t as Dictionary).has("end_km"):
				_structures.append({"kind": "tunnel", "type": "tunnel", "z0": float(t["start_km"]) * 1000.0 / _time_scale,
					"z1": float(t["end_km"]) * 1000.0 / _time_scale})
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


## Deck material of a bridge type ("concrete" for an unknown one).
static func deck_of(bridge_type: String) -> String:
	return str(BRIDGE_DECKS.get(bridge_type, "concrete"))


## Metres between the expansion joints of a deck: > 0 every so many metres and at both ends, 0 only at the ends,
## < 0 none at all.
func joint_spacing(deck_material: String) -> float:
	return float(joint_every.get(deck_material, joint_every.get("concrete", 32.0)))


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
	if not moved:
		_rock_z = [-1.0e9, -1.0e9]
	_update_structures(moved)
	_update_segment(state)
	if moved:
		_scan_objects(_prev_z, z, state)
	_update_zone()
	_update_surfaces(state)
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
			var dk := deck_of(str(s["type"])) if kind == "bridge" else ""
			var every := joint_spacing(dk) if kind == "bridge" else -1.0
			if _prev_z < z0 and z >= z0:
				_event({"name": kind + "_in", "z": z0, "kind": str(s["type"])})
				if kind == "bridge" and every >= 0.0:
					_event({"name": "joint", "z": z0, "kind": "bridge_end", "deck": dk})
			if kind == "bridge" and every > 0.0 and z > z0 and _prev_z < z1:
				var a := int(floor((clampf(_prev_z, z0, z1) - z0) / every))
				var b := int(floor((clampf(z, z0, z1) - z0) / every))
				for j in range(a + 1, b + 1):
					var zj := z0 + float(j) * every
					if zj < z1 - 0.5 * every:
						_event({"name": "joint", "z": zj, "kind": "bridge", "deck": dk})
			if _prev_z < z1 and z >= z1:
				if kind == "bridge" and every >= 0.0:
					_event({"name": "joint", "z": z1, "kind": "bridge_end", "deck": dk})
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
		var fl: Variant = seg.get("fuel_lane")
		fuel_lane = float(fl) if (fl is float or fl is int) else 0.0
	var w := str(state.get("weather", "normal"))
	wet = 1.0 if (w == "rain" and not tunnel) else 0.0
	snow = 1.0 if (w == "snow" and not tunnel) else 0.0
	rumble_road = rumble_roads.has(road)
	deck = deck_of(bridge) if bridge != "" else ""
	paving = _paving()


## Paving at the car: a steel deck, a stone bridge (setts), a cobbled block of the city centre, a concrete section,
## else asphalt.
func _paving() -> String:
	if deck == "steel":
		return "deck"
	if deck == "stone":
		return "cobbles"
	if tunnel:
		return "asphalt"
	var km := _km(z)
	if city and _cobbled(km):
		return "cobbles"
	if not city and concrete_roads.has(road) and _concrete_section(km):
		return "concrete"
	return "asphalt"


func _km(at_z: float) -> float:
	if track.has_method("z_to_km"):
		return float(track.call("z_to_km", at_z))
	return at_z * _time_scale / 1000.0


## The section at km is concrete: decided once per section from a hash of what identifies it in both driving
## directions (stage, name, length, country, scenery) against the share of its country.
func _concrete_section(km: float) -> bool:
	if plan == null or not plan.has_method("section_index_at") or not plan.has_method("section_at"):
		return false
	var i := int(plan.call("section_index_at", km))
	if _concrete.has(i):
		return bool(_concrete[i])
	var sec: Variant = plan.call("section_at", km)
	var yes := false
	if sec is Dictionary and not (sec as Dictionary).is_empty():
		var d: Dictionary = sec
		var country := str(d.get("country", ""))
		var share := float(concrete_share.get(country, concrete_share.get("_", 0.0)))
		yes = unit_hash(section_key(str(plan.get("stage_id")), d)) < concrete_threshold_for(country, share)
	_concrete[i] = yes
	return yes


## The hash threshold of a country's concrete sections: its calibrated value (concrete_threshold: country ->
## [share, threshold], tools/audio/modern/calibrate_concrete.gd – the country gets its share over all its sections,
## not only on average over many), as long as the share in effect is the one it was calibrated for; else the share.
func concrete_threshold_for(country: String, share: float) -> float:
	var cal: Variant = concrete_threshold.get(country, null)
	if cal is Array and (cal as Array).size() >= 2 and absf(float(cal[0]) - share) < 1.0e-6:
		return float(cal[1])
	return share


## What identifies an autobahn section in both driving directions: stage, name, length, country, scenery.
static func section_key(stage_id: String, section: Dictionary) -> String:
	return "%s|%s|%.3f|%s|%s" % [stage_id, str(section.get("name", "")), float(section.get("length_km", 0.0)),
		str(section.get("country", "")), str(section.get("scenery", ""))]


## The block of the city centre at km is cobbled (centre of a city whose style has cobbles; blocks counted from the
## finish line, so they do not move when the stage is longer or shorter in front of the city). Which blocks: see
## cobbled_blocks (AU-R: every centre gets cobble_share of its length, not only on average over all cities).
func _cobbled(km: float) -> bool:
	if plan == null or cobble_styles.is_empty():
		return false
	var style: Variant = plan.get("city_style")
	if not (style is String) or not cobble_styles.has(str(style)):
		return false
	if not plan.has_method("in_city_center") or not bool(plan.call("in_city_center", km)):
		return false
	var length: Variant = plan.get("length_km")
	var to_finish_m := maxf((float(length) - km) * 1000.0 / _time_scale, 0.0) if (length is float or length is int) else z
	var block := int(floor(to_finish_m / cobble_block_m))
	if _cobbles.is_empty():
		var centre: Variant = plan.get("city_center_km")
		if (length is float or length is int) and (centre is float or centre is int):
			_cobbles = cobbled_blocks(str(plan.get("to_id")), maxf(float(length) - float(centre), 0.0) * 1000.0 / _time_scale,
				cobble_block_m, cobble_share)
	if _cobbles.has(block):
		return bool(_cobbles[block])
	var yes := unit_hash("%s|%d" % [str(plan.get("to_id")), block]) < cobble_share     # a plan without a centre length
	_cobbles[block] = yes
	return yes


## The cobbled blocks of a city centre of centre_m visible metres (blocks of block_m counted from the finish line, the
## last one shorter): block -> bool for every block. In the order of their hashes a block is taken while that brings
## the cobbled length nearer to share × centre_m, so each centre gets its share within half a block (an 800-m centre
## 0.55 or 0.56 at 0.6) and the hash only decides which blocks (KRITIK-FAHRBAHN B2; with a decision per block from the
## hash alone a centre got 0.34–0.90, measured over all stages).
static func cobbled_blocks(city: String, centre_m: float, block_m: float, share: float) -> Dictionary:
	var out := {}
	if centre_m <= 0.0 or block_m <= 0.0:
		return out
	var n := maxi(int(ceil(centre_m / block_m - 1.0e-6)), 1)
	var order: Array = []
	for b in n:
		order.append([unit_hash("%s|%d" % [city, b]), b])
		out[b] = false
	order.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var target := clampf(share, 0.0, 1.0) * centre_m
	var got := 0.0
	for row: Array in order:
		var b := int(row[1])
		var w := minf(block_m, centre_m - b * block_m)
		if absf(got + w - target) < absf(got - target):
			got += w
			out[b] = true
	return out


## A number in [0, 1) from a text – the same on every machine and in every run. String.hash() is djb2: keys that
## differ only in their last character ("hamburg|0", "hamburg|1") differ only in the last bits of the hash, and the
## low 24 bits used before AU-R gave every block of a city the same decision (KRITIK-FAHRBAHN B2: Hamburg always
## cobbled, Paris never). The finaliser of MurmurHash3 (fmix32) spreads every input bit over the whole word.
static func unit_hash(key: String) -> float:
	var h := key.hash() & 0xFFFFFFFF
	h ^= h >> 16
	h = _mul32(h, 0x85EBCA6B)
	h ^= h >> 13
	h = _mul32(h, 0xC2B2AE35)
	h ^= h >> 16
	return float(h >> 8) / float(0x1000000)


## (a · b) mod 2^32 for 32-bit unsigned a, b without overflowing the 64-bit int (16-bit halves of b).
static func _mul32(a: int, b: int) -> int:
	var lo := a * (b & 0xFFFF)
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & 0xFFFFFFFF


func _update_zone() -> void:
	if tunnel:
		zone = "tunnel"
	elif bridge != "":
		zone = "bridge"
	elif city:
		zone = "city"
	elif cutting_window_m > 0.0 and z - float(_rock_z[0]) <= cutting_window_m and z - float(_rock_z[1]) <= cutting_window_m:
		zone = "cutting"
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
	var wl := x - track_half_m
	var wr := x + track_half_m
	surface_l = wheel_surface(surface_at(wl, left, right, shoulder, at_limit and x < (left + right) * 0.5), wl >= left and wl <= right)
	# the right edge of a fuel lane is a plain dashed line without a profile, paved on both sides (KRITIK-FAHRBAHN B13)
	surface_r = wheel_surface(surface_at(wr, left, right, shoulder, at_limit and x >= (left + right) * 0.5), wr >= left and wr <= right,
		fuel_lane > 0.0)


## Surface under a wheel at lateral position wx: paved between left and right (the edge line counts as "rumble"),
## the rumble strip just outside, then the shoulder; "grass" when the car is at the open limit on that side or the
## wheel is beyond the shoulder. (The rule without the road: wheel_surface() turns it into what this road has.)
func surface_at(wx: float, left: float, right: float, shoulder_m: float, on_grass: bool) -> String:
	var out := maxf(left - wx, wx - right)   # > 0: outside the paved road by this much
	if on_grass or out > shoulder_m:
		return "grass"
	if out > rumble_out_m:
		return "shoulder"
	if out > -rumble_in_m:
		return "rumble"
	return "asphalt"


## What a wheel really runs on on this road: the paving instead of plain "asphalt"; the edge line is a rumble only
## on rumble roads (elsewhere paving inside the edge, shoulder outside); `plain_edge`: this edge is the dashed line
## of a fuel lane – paving on both sides of it; in tunnels, on bridges and in the City Limits the shoulder is paved
## (walkway, deck, pavement).
func wheel_surface(raw: String, inside: bool, plain_edge: bool = false) -> String:
	var paved_shoulder := tunnel or bridge != "" or city
	match raw:
		"asphalt":
			return paving
		"rumble":
			if plain_edge:
				return paving
			if rumble_road:
				return "rumble"
			return paving if (inside or paved_shoulder) else "shoulder"
		"shoulder", "grass":
			return paving if paved_shoulder else raw
	return raw


## Roadside objects of the segments the car passed in (z_from, z_to], and the delineator posts there.
func _scan_objects(z_from: float, z_to: float, state: Dictionary) -> void:
	var left := float(state.get("road_left", -5.625))
	var right := float(state.get("road_right", 5.625))
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
			var px := float(d.get("x", 0.0))
			if str(info[0]) == "rock" and side != 0:
				# a cutting: rocks close to the paved edge on both sides
				var from_edge := (px - right) if side > 0 else (left - px)
				if from_edge <= cutting_dist_m:
					_rock_z[0 if side < 0 else 1] = pz
			var dx := px - x
			var dist := 0.0 if side == 0 else absf(dx)
			if dist > pass_max_m:
				continue
			_event({"name": "pass_object", "z": pz, "side": 0 if side == 0 else (1 if dx >= 0.0 else -1), "dist_m": dist,
				"size": float(info[1]) * float(d.get("scale", 1.0)), "kind": str(info[0]),
				"set": str(d.get("set", d.get("sign", d.get("obj", "")))), "contact": false})
	if delineators:
		_scan_delineators(z_from, z_to, left, right)


## The delineator posts of the stretch (z_from, z_to]: every road.delineator_every_m on roads without a guardrail,
## outside the City Limits and tunnels, DELINEATOR_INSET_M inside the outer edge of the shoulder (as the road is
## drawn: the right one only where there is no fuel lane and no canopy).
func _scan_delineators(z_from: float, z_to: float, left: float, right: float) -> void:
	var zd := ceilf(z_from / _delin_every) * _delin_every
	if zd <= z_from:
		zd += _delin_every
	while zd <= z_to:
		var seg := _segment(int(floor(zd / _seg_len)))
		if seg != null and not bool(seg.get("guardrail")) and not bool(seg.get("city")) and not bool(seg.get("tunnel")):
			var fuel := float(seg.get("fuel_lane")) if seg.get("fuel_lane") != null else 0.0
			var right_ok := fuel < 0.01 and str(seg.get("cover")) == ""
			for side: int in ([-1, 1] if right_ok else [-1]):
				var px := (left - _shoulder_w + DELINEATOR_INSET_M) if side < 0 else (right + _shoulder_w - DELINEATOR_INSET_M)
				var dist := absf(px - x)
				if dist <= pass_max_m:
					_event({"name": "pass_object", "z": zd, "side": side, "dist_m": dist, "size": DELINEATOR_SIZE,
						"kind": "post", "set": "delineator", "contact": dist < body_half_m + POST_RADIUS_M})
		zd += _delin_every


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
	return {"valid": valid, "z": z, "x": x, "surface_l": surface_l, "surface_r": surface_r, "paving": paving,
		"deck": deck, "rumble_road": rumble_road, "wet": wet, "snow": snow, "zone": zone, "tunnel": tunnel,
		"bridge": bridge, "cover": cover, "depth_m": depth_m, "road": road, "scenery": scenery, "city": city,
		"guardrail": guardrail, "lanes": lanes, "fuel_lane": fuel_lane, "events": events.size()}
