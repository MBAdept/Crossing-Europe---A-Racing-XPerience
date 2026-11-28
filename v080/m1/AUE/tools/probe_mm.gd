extends SceneTree
## AU-E probe: Movie Maker + AudioEffectCapture on Master in the real race scene. Prints per-frame capture growth.
var _sc: Node
var _cap: AudioEffectCapture
var _frame := 0
var _grow: Array = []
var _t0 := 0
var _last := 0
var _n := 300

func _initialize() -> void:
	var args := CliArgs.all()
	_n = int(args.get("frames", 300))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(args.get("stage", "kiel_hamburg")), "from_city": str(args.get("from", "kiel")),
		"vehicle": "gran_turismo", "start_world_minutes": 12.0 * 60.0, "weather": "normal",
		"start_km": float(args.get("km", 30.0)), "autopilot": true, "no_countdown": true, "seed": 5}
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _cap)
	_t0 = Time.get_ticks_usec()

func _process(_d: float) -> bool:
	_frame += 1
	var a := _cap.get_frames_available()
	if a > 0:
		_cap.get_buffer(a)
	_grow.append(a)
	if _frame % 30 == 0:
		var m: Object = root.get_node("AudioManager").get("_modern")
		var veh: Object = _sc.get("vehicle")
		if m != null:
			var st: Dictionary = m.call("debug_state")
			var sl: Dictionary = st.get("slots", {})
			print("T ", _frame, " v ", snappedf(float(veh.get("speed")), 0.1), " pz ", snappedf(float(_sc.get("pos_z")), 0.1),
				" alive ", st.get("alive"), " paused ", st.get("paused"), " tunnel ", st.get("tunnel"), " duck ", JSON.stringify(st.get("mix", {}).get("duck_db")),
				" slots ", JSON.stringify(sl).left(900))
	if _frame == _n:
		var dt := (Time.get_ticks_usec() - _t0) / 1.0e6
		var h := {}
		for g: int in _grow:
			h[g] = int(h.get(g, 0)) + 1
		print("PROBE frames ", _n, " wall ", snappedf(dt, 0.01), " s = ", snappedf(dt / _n * 1000.0, 0.1), " ms/frame; capture growth histogram ", h,
			" profile ", root.get_node("AudioManager").call("get_profile") if root.get_node("AudioManager").has_method("get_profile") else "?",
			" movie ", Engine.get_write_movie_path())
		quit(0)
	return false
