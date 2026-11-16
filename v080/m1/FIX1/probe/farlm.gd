extends SceneTree
## FIX1 probe (headless): far landmark stand-ins of the props builder (builders/props.gd _far) every 2 s.
## -- --stage=… --from=… --start-km=… [--secs=12]

var _sc: Node
var _next := 0.0
var _secs := 12.0


func _initialize() -> void:
	var a := CliArgs.all()
	_secs = float(a.get("secs", 12.0))
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
	var props: Object = r.call("builder", "props")
	var far: Dictionary = props.get("_far")
	var cam: Camera3D = r.get("camera")
	var out := []
	for k: Variant in far:
		var n: Node3D = far[k]
		var lm: Dictionary = (_sc.get("track") as Object).get("landmarks")[int(k)]
		out.append("%s d=%.0f pos=%s cam=%s scale=%.2f" % [str(lm.get("set")), n.global_position.distance_to(cam.global_position),
			str(n.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(cam.global_position.snapped(Vector3(0.1, 0.1, 0.1))), n.scale.x])
	print("FAR t=%.1f km=%.2f %s" % [sim, float(_sc.get("pos_km")), str(out)])
	var st: Object = r.get("streamer")
	var trk: Object = _sc.get("track")
	var lib: Object = props.get("library")
	for lm: Dictionary in trk.get("landmarks"):
		var z := float(lm["z"])
		var ci := int(floor(z / (float(st.get("chunk_segments")) * 3.0)))
		var e: Dictionary = (lib.get("sets") as Dictionary).get(str(lm["set"]), {})
		print("   LM %s z=%.0f dz=%.0f chunk=%d committed=%s kind=%s x=%.1f side=%s" % [str(lm["set"]), z, z - float((r.get("view") as Dictionary).get("camera_z", 0.0)), ci,
			str(st.call("chunk_node", ci) != null), str(e.get("kind", "-")), float(lm.get("x", 0.0)), str(lm.get("side"))])
	var snap: Dictionary = r.call("debug_snapshot")
	for c: Dictionary in snap.get("chunks", []):
		var pp: Dictionary = (c.get("parts", {}) as Dictionary).get("props", {})
		if not pp.is_empty() and int(c["index"]) >= 0:
			var d: Variant = pp.get("dropped", {})
			if d is Dictionary and (int((d as Dictionary).get("ribbon", 0)) > 0 or int((d as Dictionary).get("missing", 0)) > 0):
				print("   chunk %d dropped %s" % [int(c["index"]), str(d)])
	if sim > _secs:
		quit(0)
		return true
	return false
