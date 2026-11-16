extends SceneTree

var _f := 0
var _am: Node


func _buses() -> Array:
	var out := []
	for i in AudioServer.bus_count:
		out.append("%s>%s" % [AudioServer.get_bus_name(i), AudioServer.get_bus_send(i)])
	return out


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_am = root.get_node("AudioManager")
		print("profile at boot: ", _am.call("profile"), " buses ", _buses())
		print("nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " children ", _am.get_child_count())
		_am.call("set_profile", "modern")
		print("profile: ", _am.call("profile"), " buses ", _buses())
		print("nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " children ", _am.get_child_count())
		_am.call("set_vehicle", "limousine")
		_am.call("set_music", true)
	if _f > 2 and _f < 40:
		_am.call("set_engine", 120.0, 1.0, 245.0, true)
		_am.call("set_wind", 120.0)
		_am.call("set_traffic", [{"id": 1, "set": "traffic/sedan_blue", "z": 30.0, "x": 3.0, "length": 4.7, "speed": 100.0}], {"z": 0.0, "x": 0.0, "speed": 120.0})
		_am.call("set_environment", {"tunnel": _f > 20})
		if _f == 10:
			_am.call("play", "crash")
			_am.call("event", "collision", {"speed_kmh": 80.0, "heavy": false, "side": 1})
			_am.call("play", "ui_move")
	if _f == 40:
		var m: Node = _am.get("_modern")
		print(JSON.stringify(m.call("debug_state"), "  "))
		print("engine_state ", _am.call("engine_state"))
		print("traffic_state keys ", (_am.call("traffic_state") as Dictionary).keys())
		_am.call("set_profile", "arcade")
		print("profile: ", _am.call("profile"), " buses ", _buses())
	if _f == 43:
		print("nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " children ", _am.get_child_count())
		return true
	return false
