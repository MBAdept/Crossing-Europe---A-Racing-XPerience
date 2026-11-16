extends SceneTree
## Scratch probe of AU-B: the Modern engine in Movie Maker mode with --audio-sync – is the audio track of two runs the
## same, sample for sample? Run with --write-movie, --fixed-fps 60, -- --sound=modern --audio-sync [--vehicle=…].

var _am: Node
var _frame := 0
var _vehicle := "gran_turismo"
var _vmax := 270.0
var _a0 := 0.0
var _q := 0.0
var _v := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vehicle="):
			_vehicle = a.substr(10)
	_start.call_deferred()


func _start() -> void:
	_am = root.get_node("AudioManager")
	_am.call("set_profile", "modern")
	var spec := VehicleModel.resolve_spec(ConfigLoader.load_merged(), _vehicle)
	_vmax = float(spec["vmax_kmh"])
	_a0 = float(spec["accel_a0"])
	_q = float(spec["accel_q"])
	_am.call("set_vehicle", _vehicle)
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	var t := _frame / 60.0
	var thr := 0.0
	if t < 2.5:
		_v = 0.0
	elif t < 7.5:
		thr = 1.0
		_v = VehicleModel.curve_speed(VehicleModel.curve_time(_v, _vmax, _a0, _q) + 1.0 / 60.0, _vmax, _a0, _q)
	elif t < 10.0:
		_v = maxf(_v - 8.0 / 60.0, 0.0)
	else:
		var m: Variant = _am.get("_modern")
		var ctx: Variant = m.get("ctx") if m != null else null
		print("movie_probe: fertig, sync=%s live=%s perf=%s" % [str(ctx.get("sync")) if ctx != null else "?", str(ctx.get("live")) if ctx != null else "?",
			str(_am.call("engine_perf"))])
		quit(0)
		return
	_am.call("set_engine", _v, thr, _vmax, true)
	_am.call("set_environment", {"tunnel": false})
