extends SceneTree
## Probe: when does the engine generator underrun? Drives the end of the test stage and prints engine_perf() over time.

var _scene: Node
var _t0 := 0
var _n := 0
var _last_skips := 0
var _max_dt := 0.0
var _done := false


func _initialize() -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": "dev_testetappe", "from_city": "", "vehicle": "limousine",
		"start_world_minutes": 480.0, "weather": "rain", "start_km": 126.5, "autopilot": true, "no_countdown": true, "seed": 7}
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	_scene.connect("stage_finished", func(_r: Dictionary) -> void: _done = true)
	root.add_child(_scene)
	_t0 = Time.get_ticks_msec()


func _process(delta: float) -> bool:
	_n += 1
	_max_dt = maxf(_max_dt, delta)
	var am := root.get_node("AudioManager")
	var perf: Dictionary = am.call("engine_perf")
	var skips := int(perf.get("skips", 0))
	var eng: Object = am.get("_eng")
	var mo: Variant = am.get("_modern")
	if mo != null:
		eng = (mo as Object).get("engine").get("_eng")
	if eng != null and (skips != _last_skips or (_n > 60 and _n < 135)):
		var pb: Variant = eng.get("_playback")
		var avail := -1
		if pb != null:
			avail = (pb as AudioStreamGeneratorPlayback).get_frames_available()
		print("  Bild %4d dt %.3f  queued %5d  burst %7.1f  frame_dt %.3f  capacity %d  frei %d  fade %.2f  skips %d" % [_n, delta,
			int(eng.get("_queued")), float(eng.get("_burst")), float(eng.get("_frame_dt")), int(eng.get("_capacity")), avail,
			float(eng.get("_fade")) if "_fade" in eng else -1.0, skips])
	if skips != _last_skips or _n % 30 == 0:
		var st: Dictionary = am.call("engine_state")
		print("t %6.2f s  Bild %4d  dt max %.3f  skips %d (+%d)  frames %d  rpm %.0f  km %.2f" % [
			(Time.get_ticks_msec() - _t0) / 1000.0, _n, _max_dt, skips, skips - _last_skips, int(perf.get("frames", 0)),
			float(st.get("rpm", 0.0)), float(_scene.get("pos_km"))])
		_last_skips = skips
		_max_dt = 0.0
	if _done or Time.get_ticks_msec() - _t0 > 40000:
		print("ENDE skips ", skips)
		quit(0)
		return true
	return false
