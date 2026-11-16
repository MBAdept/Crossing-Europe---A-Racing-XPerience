extends SceneTree
## QA-M2-BILD probe (headless): what does the main-thread collect of a chunk cost per builder along a stage?
## Drives the stage with the autopilot (--timescale); every --every seconds of wall time it captures a ChunkContext for
## a chunk --lead chunks ahead of the camera (inside the integrated path) and times ctx.capture() and every builder's
## collect(ctx) – the work ChunkStreamer._collect() does on the main thread. Prints "QA-COLLECT km=… ci=… capture=… ms
## <builder>=… ms …" and at the end the maxima per builder.
##   godot --headless --path . -s <this> -- --graphics=modern --gfx-preset=medium --stage=kiel_hamburg --from=kiel
##       [--start-km=0] [--timescale=8] [--every=1.0] [--lead=6] [--quit-km=95]

const RACE := "res://scenes/race/race.tscn"

var _sc: Node
var _a := {}
var _next := 0.0
var _max := {}
var _sum := {}
var _n := 0
var _done := false


func _initialize() -> void:
	_a = CliArgs.all()
	root.get_node("Settings").call("disarm_crash_guard")
	var ts := float(_a.get("timescale", 8.0))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(_a.get("stage", "kiel_hamburg")),
		"from_city": str(_a.get("from", "kiel")), "vehicle": "limousine", "start_world_minutes": 720.0, "weather": "normal",
		"start_km": float(_a.get("start-km", 0.0)), "autopilot": true, "autopilot_refuel": "auto", "no_countdown": true,
		"seed": 11, "gfx": "modern"}
	if _a.has("start-speed"):
		setup["start_speed_kmh"] = float(_a.get("start-speed", 120.0))
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	_sc.connect("stage_finished", func(_r: Dictionary) -> void: _finish())
	root.add_child(_sc)


func _process(_d: float) -> bool:
	if _done:
		return true
	if not bool(_sc.call("is_live")):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next:
		return false
	_next = now + float(_a.get("every", 1.0))
	var r: Node = _sc.get("renderer")
	var st: Object = r.get("streamer")
	var path: Object = r.get("path")
	var terrain: Object = r.get("terrain")
	var track: Object = _sc.get("track")
	var n := int(st.get("chunk_segments"))
	var view: Dictionary = r.get("view")
	var cam_seg := int(floor(float(view["camera_z"]) / float(track.get("seg_len"))))
	var ci := cam_seg / n + int(_a.get("lead", 6))
	var a := ci * n
	var b := a + n
	if b > int(path.call("last")) or int((track.call("get_segment", a) as Object).get("index")) != a:
		return false
	var ctx: Object = load("res://scripts/race3d/chunk_context.gd").new()
	ctx.set("cfg", st.get("cfg"))
	ctx.set("scenery_db", terrain.get("scenery_db"))
	ctx.set("levels", st.get("levels"))
	ctx.set("sync", true)
	ctx.set("services", st.get("services"))
	var t0 := Time.get_ticks_usec()
	ctx.call("capture", ci, a, b, path, terrain, track)
	var cap := float(Time.get_ticks_usec() - t0) / 1000.0
	var parts := []
	_acc("capture", cap)
	for bld: Object in st.call("builders"):
		var t1 := Time.get_ticks_usec()
		bld.call("collect", ctx)
		var ms := float(Time.get_ticks_usec() - t1) / 1000.0
		var id := str(bld.call("id"))
		_acc(id, ms)
		parts.append("%s=%.2f" % [id, ms])
	_n += 1
	print("QA-COLLECT km=%.1f ci=%d capture=%.2f %s" % [float(_sc.get("pos_km")), ci, cap, " ".join(parts)])
	if float(_a.get("quit-km", 1.0e9)) <= float(_sc.get("pos_km")):
		_finish()
	return false


func _acc(k: String, ms: float) -> void:
	_max[k] = maxf(float(_max.get(k, 0.0)), ms)
	_sum[k] = float(_sum.get(k, 0.0)) + ms


func _finish() -> void:
	if _done:
		return
	_done = true
	var out := []
	for k: String in _max:
		out.append("%s avg %.2f max %.2f" % [k, float(_sum[k]) / maxf(1.0, float(_n)), float(_max[k])])
	print("QA-COLLECT-SUM n=%d %s" % [_n, " | ".join(out)])
	quit(0)
