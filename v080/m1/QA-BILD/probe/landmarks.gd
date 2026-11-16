extends SceneTree
## QA-BILD probe (headless): which landmark sets the Modern renderer has placed (debug_snapshot().props), and which
## landmarks the Track knows ahead (track.landmarks z), every 2 s of a drive. -- --stage=… --from=… --start-km=… [--secs=40]

var _sc: Node
var _t0 := -1
var _next := 0.0
var _secs := 40.0


func _initialize() -> void:
	var a := CliArgs.all()
	_secs = float(a.get("secs", 40.0))
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "kiel")), "vehicle": "limousine", "start_world_minutes": 12.0 * 60.0,
		"weather": "normal", "start_km": float(a.get("start-km", 80.0)), "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": "modern", "no_countdown": true, "start_speed_kmh": 50.0, "traffic_warmup": true}
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_dt: float) -> bool:
	if not bool(_sc.call("is_live")):
		return false
	var sim := float(_sc.get("stage_time"))
	if sim < _next:
		return false
	_next = sim + 2.0
	var r: Object = _sc.get("renderer")
	var snap: Dictionary = r.call("debug_snapshot")
	var cam_z := float((snap["camera"] as Dictionary)["z"])
	var placed := []
	var props: Dictionary = snap.get("props", {})
	for k: String in props.keys():
		if k.begins_with("landmarks/"):
			placed.append("%s×%d" % [k, int(props[k])])
	var ahead := []
	var tr: Object = _sc.get("track")
	if tr != null:
		var lms: Variant = tr.get("landmarks")
		if lms is Array:
			for it: Dictionary in lms:
				var d := float(it.get("z", 0.0)) - cam_z
				if d > -50.0 and d < 3000.0:
					ahead.append("%s@%.0fm" % [str(it.get("set", it.get("id", "?"))), d])
	print("LM t=%.1f km=%.2f placed=%s track_ahead=%s" % [sim, float(_sc.get("pos_km")), str(placed), str(ahead)])
	if sim > _secs:
		quit(0)
		return true
	return false
