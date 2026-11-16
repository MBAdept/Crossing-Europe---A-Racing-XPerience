extends SceneTree
## QA-M2-BILD probe (headless): does the props library load sets during the drive (after prepare())? Every frame the
## number of sets / models of the props builder's PropLibrary is compared with the last frame; a change is printed with
## the km and the time the frame's render() took (renderer._render_us difference).
##   godot --headless --path . -s <this> -- --graphics=modern --gfx-preset=medium --stage=kiel_hamburg --from=kiel
##       [--timescale=8]

const RACE := "res://scenes/race/race.tscn"

var _sc: Node
var _last_sets := -1
var _last_models := -1
var _prev_us := 0
var _done := false
var _live := false


func _initialize() -> void:
	var a := CliArgs.all()
	root.get_node("Settings").call("disarm_crash_guard")
	var ts := float(a.get("timescale", 8.0))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "kiel")), "vehicle": "limousine", "start_world_minutes": 720.0, "weather": "normal",
		"start_km": float(a.get("start-km", 0.0)), "autopilot": true, "autopilot_refuel": "auto", "no_countdown": true,
		"seed": 11, "gfx": "modern"}
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	_sc.connect("stage_finished", func(_r: Dictionary) -> void: _end())
	root.add_child(_sc)


func _process(_d: float) -> bool:
	if _done:
		return true
	var r: Variant = _sc.get("renderer")
	if not (r is Object):
		return false
	var st: Object = (r as Object).get("streamer")
	if st == null:
		return false
	var props: Object = null
	for b: Object in st.call("builders"):
		if str(b.call("id")) == "props":
			props = b
	if props == null:
		return false
	var lib: Object = props.call("_lib")
	var ns := (lib.get("sets") as Dictionary).size()
	var nm := (lib.get("models") as Dictionary).size()
	var us := int((r as Object).get("_render_us"))
	var live := bool(_sc.call("is_live"))
	if live and not _live:
		print("QA-LIB live km=%.2f sets=%d models=%d" % [float(_sc.get("pos_km")), ns, nm])
		_live = true
	elif live and (ns != _last_sets or nm != _last_models):
		print("QA-LIB change km=%.2f sets %d->%d models %d->%d frame_render_ms=%.1f" % [float(_sc.get("pos_km")), _last_sets, ns,
			_last_models, nm, float(us - _prev_us) / 1000.0])
	_last_sets = ns
	_last_models = nm
	_prev_us = us
	return false


func _end() -> void:
	print("QA-LIB end km=%.2f sets=%d models=%d" % [float(_sc.get("pos_km")), _last_sets, _last_models])
	_done = true
	quit(0)
