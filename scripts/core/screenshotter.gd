class_name Screenshotter
extends Node
## Debug helper: saves viewport screenshots at given real-time seconds after it entered the tree,
## then optionally quits. Used by the debug CLI (--screenshot=/path/prefix --shot-times=1,2.5,5).
## Files: <prefix>_<index>.png (index starting at 0, two digits).

signal all_done

var prefix := ""
var times: Array[float] = []
var quit_when_done := true
var _t := 0.0
var _next := 0
var _busy := false


func configure(path_prefix: String, shot_times: Array[float], quit_after: bool = true) -> void:
	prefix = path_prefix
	times = shot_times.duplicate()
	times.sort()
	quit_when_done = quit_after
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if prefix == "" or _busy:
		return
	_t += delta
	if _next < times.size() and _t >= times[_next]:
		_capture(_next)
		_next += 1


func _capture(index: int) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s_%02d.png" % [prefix, index]
	var err := img.save_png(path)
	print("Screenshot ", path, " -> ", error_string(err))
	_busy = false
	if _next >= times.size():
		all_done.emit()
		if quit_when_done:
			get_tree().quit()
