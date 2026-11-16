extends SceneTree

var _frames := 0

func _initialize() -> void:
	print("init: root inside tree = ", root.is_inside_tree(), " children = ", root.get_child_count())
	var am := root.get_node_or_null("AudioManager")
	print("init: AudioManager = ", am, " ready? sounds_ready=", am.get("sounds_ready") if am else null)
	print("init: buses = ", _buses())
	print("init: driver = ", AudioServer.get_driver_name(), " mix rate = ", AudioServer.get_mix_rate(), " display = ", DisplayServer.get_name())
	var n := Node.new()
	n.name = "ProbeNode"
	root.add_child(n)
	print("init: probe inside tree = ", n.is_inside_tree())

func _buses() -> Array:
	var out := []
	for i in AudioServer.bus_count:
		out.append(AudioServer.get_bus_name(i))
	return out

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		print("frame1: root inside tree = ", root.is_inside_tree(), " buses = ", _buses())
		var am := root.get_node_or_null("AudioManager")
		print("frame1: AudioManager children = ", am.get_child_count() if am else -1)
	return _frames >= 2
