extends SceneTree
## QA-BILD probe (headless): prop drops per chunk at a position (props builder debug()).
##   godot --headless --path . -s <this> -- --stage=… --from=… --start-km=… [--secs=2]

var _sc: Node
var _t0 := -1
var _secs := 2.0


func _initialize() -> void:
	var a := CliArgs.all()
	_secs = float(a.get("secs", 2.0))
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kassel_wuerzburg")),
		"from_city": str(a.get("from", "kassel")), "vehicle": "kombi", "start_world_minutes": 15.0 * 60.0,
		"weather": "normal", "start_km": float(a.get("start-km", 61.9)), "autopilot": true, "autopilot_refuel": "never",
		"seed": int(a.get("seed", 12)), "gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": true}
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_dt: float) -> bool:
	if not bool(_sc.call("is_live")):
		return false
	if _t0 < 0:
		_t0 = Time.get_ticks_msec()
	if Time.get_ticks_msec() - _t0 < int(_secs * 1000.0):
		return false
	var r: Object = _sc.get("renderer")
	var snap: Dictionary = r.call("debug_snapshot")
	var cam_z := float((snap["camera"] as Dictionary)["z"])
	print("CAM z=%.1f km=%.2f" % [cam_z, float(_sc.get("pos_km"))])
	var tot := {}
	for c: Dictionary in snap["chunks"]:
		var parts: Dictionary = c.get("parts", {})
		var p: Dictionary = parts.get("props", {})
		var d: Dictionary = p.get("dropped", {})
		var t: Dictionary = parts.get("terrain", {})
		print("chunk %d seg %d..%d  dz0=%.0f m  placed=%s dropped=%s cover=%s" % [int(c["index"]), int(c["seg_a"]), int(c["seg_b"]),
			float(c["seg_a"]) * 3.0 - cam_z, str(p.get("count", (p.get("list", []) as Array).size())), JSON.stringify(d), str(p.get("cover", 0))])
		for k: String in d.keys():
			tot[k] = int(tot.get(k, 0)) + int(d[k])
	print("TOTAL dropped ", JSON.stringify(tot))
	quit(0)
	return true
