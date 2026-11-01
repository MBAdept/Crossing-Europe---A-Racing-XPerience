class_name Screenshotter
extends Node
## Debug helper: saves viewport screenshots at given real-time seconds after it entered the tree,
## then optionally quits. Used by the debug CLI (--screenshot=/path/prefix --shot-times=1,2.5,5).
## Files: <prefix>_<index>.png (index starting at 0, two digits).
## A window larger than the 16:9 picture (e.g. 1280×800 like the Steam Deck, stretch aspect "keep")
## is saved whole: the picture centred with black bars, exactly as the screen shows it.

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
	var img := window_image(get_viewport().get_texture().get_image())
	var path := "%s_%02d.png" % [prefix, index]
	var err := img.save_png(path)
	print("Screenshot ", path, " -> ", error_string(err))
	_busy = false
	if _next >= times.size():
		all_done.emit()
		if quit_when_done:
			await _quiet_audio()
			get_tree().quit()


## Stops the menu music and gives the audio thread a moment to drop its playback before quitting – quitting while the
## title theme played reported its stream as "resources still in use at exit" (AudioManager releases it on exit).
func _quiet_audio() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("set_music"):
		am.call("set_music", false)
		await get_tree().create_timer(0.5, true, false, true).timeout


## The viewport picture as the window shows it: with "keep" the picture is centred in a larger window
## and the rest stays black (letterbox bars).
static func window_image(img: Image) -> Image:
	if img == null or DisplayServer.get_name() == "headless":
		return img
	var win := DisplayServer.window_get_size()
	if win.x <= img.get_width() and win.y <= img.get_height():
		return img
	var full := Image.create_empty(maxi(win.x, img.get_width()), maxi(win.y, img.get_height()), false, img.get_format())
	full.fill(Color.BLACK)
	var at := (full.get_size() - img.get_size()) / 2
	full.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	return full
