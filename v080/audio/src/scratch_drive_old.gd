extends SceneTree
## v0.8.0 audio study (scratch, not part of the repo): drives the real AudioManager (engine bank, wind, room buses)
## with a scripted drive under the Movie Maker and writes a trace per frame.
##   --vehicle=gran_turismo --trace=<csv> [--accel-scale=1.8]

var _am: Node
var _t := 0.0
var _speed := 0.0
var _vmax := 270.0
var _spec: Dictionary = {}
var _trace: FileAccess
var _phases: Array = []
var _pi := 0
var _pt := 0.0
var _scale := 1.8
var _started := false


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var vehicle := CliArgs.get_string("vehicle", "gran_turismo")
	_scale = CliArgs.get_float("accel-scale", 1.8)
	_spec = VehicleModel.resolve_spec(cfg, vehicle)
	_vmax = float(_spec["vmax_kmh"])
	_am = root.get_node("AudioManager")
	_am.call("set_vehicle", vehicle)
	_trace = FileAccess.open(CliArgs.get_string("trace", "/tmp/drive_old.csv"), FileAccess.WRITE)
	_trace.store_line("t,speed_kmh,throttle,rpm,gear,load,boost,phase")
	# [name, seconds (max), throttle, mode, arg]
	_phases = [
		["start_idle", 2.6, 0.0, "stand", 0.0],
		["blip1", 0.25, 1.0, "stand", 0.0], ["idle", 0.8, 0.0, "stand", 0.0],
		["blip2", 0.32, 1.0, "stand", 0.0], ["idle", 1.0, 0.0, "stand", 0.0],
		["launch", 40.0, 1.0, "accel", 0.985],
		["flat_out", 6.0, 1.0, "hold", 0.0],
		["lift", 2.2, 0.0, "coast", 0.0],
		["brake", 10.0, 0.0, "brake", 130.0],
		["cruise130", 4.5, 0.3, "hold", 0.0],
		["kickdown", 4.0, 1.0, "accel", 0.985],
		["lift2", 1.2, 0.0, "coast", 0.0],
		["brake_stop", 10.0, 0.0, "brake", 0.0],
		["idle_end", 1.6, 0.0, "stand", 0.0],
	]


func _process(delta: float) -> bool:
	if _pi >= _phases.size():
		_trace.close()
		_am.call("stop_all")
		return true
	var ph: Array = _phases[_pi]
	var thr: float = ph[2]
	var done := false
	match str(ph[3]):
		"stand":
			_speed = 0.0
		"accel":
			var a0 := float(_spec["accel_a0"])
			var q := float(_spec["accel_q"])
			_speed = VehicleModel.curve_speed(VehicleModel.curve_time(_speed, _vmax, a0, q) + delta * thr * _scale, _vmax, a0, q)
			if _speed >= _vmax * float(ph[4]):
				done = true
		"hold":
			pass
		"coast":
			_speed = maxf(0.0, _speed - 9.0 * delta)
		"brake":
			_speed = maxf(float(ph[4]), _speed - 70.0 * delta)
			if _speed <= float(ph[4]):
				done = true
	_am.call("set_engine", _speed, thr, _vmax, true)
	_am.call("set_wind", _speed)
	_am.call("set_environment", {"tunnel": false})
	var st: Dictionary = _am.call("engine_state")
	_trace.store_line("%.4f,%.2f,%.2f,%.1f,%d,%.3f,%.3f,%s" % [_t, _speed, thr, float(st["rpm"]), int(st["gear"]), float(st["load"]), float(st["boost"]), str(ph[0])])
	_t += delta
	_pt += delta
	if done or _pt >= float(ph[1]):
		_pi += 1
		_pt = 0.0
	return false
