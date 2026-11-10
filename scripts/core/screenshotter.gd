class_name Screenshotter
extends Node
## Debug helper: saves viewport screenshots at given real-time seconds after it entered the tree,
## then optionally quits. Used by the debug CLI (--screenshot=/path/prefix --shot-times=1,2.5,5).
## Files: <prefix>_<index>.png (index starting at 0, two digits).
## A window larger than the 16:9 picture (e.g. 1280×800 like the Steam Deck, stretch aspect "keep")
## is saved whole: the picture centred with black bars, exactly as the screen shows it.
##
## --shot-fast (v0.8.0, with --fixed-fps): the game runs every frame, but the picture is only rendered from
## FAST_LEAD_S before each shot on (RenderingServer.render_loop_enabled) – software OpenGL otherwise spends its time
## on pictures nobody looks at. Scripts, _draw() and the simulation run as always, so the shots are the same
## pictures (tools/golden.sh compares them with fully rendered runs), about 4× faster.
## hold: the clock stands while it is true – the race session holds it until a Modern renderer has prepared its
## stage, so equal shot times show equal simulation states in both graphics modes.

signal all_done

## --shot-fast: seconds before a shot from which the picture is rendered again (6 frames at 60 fps).
const FAST_LEAD_S := 0.1

var prefix := ""
var times: Array[float] = []
var quit_when_done := true
var hold := false
var fast := false
var _t := 0.0
var _next := 0
var _busy := false


func configure(path_prefix: String, shot_times: Array[float], quit_after: bool = true) -> void:
	prefix = path_prefix
	times = shot_times.duplicate()
	times.sort()
	quit_when_done = quit_after
	fast = CliArgs.has("shot-fast")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if prefix == "" or _busy or hold:
		return
	_t += delta
	if fast and _next < times.size():
		RenderingServer.render_loop_enabled = _t >= times[_next] - FAST_LEAD_S
	if _next < times.size() and _t >= times[_next]:
		_capture(_next)
		_next += 1


func _exit_tree() -> void:
	if fast:
		RenderingServer.render_loop_enabled = true


func _capture(index: int) -> void:
	_busy = true
	if fast:
		RenderingServer.render_loop_enabled = true
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
