extends SceneTree
## Pictures of the second Arcade identity list (tests/golden/arcade_ui_frames.txt, tools/golden.sh) that the
## Screenshotter of the game cannot take: the pause menu over a running Arcade stage and the loading picture as the
## menus show it. Runs unchanged in the tree of tag v0.7.0 (tools/golden.sh make copies it there) and in this one –
## it only uses the scene tree and nodes both versions have, by path and by method name.
##
##   godot --path <tree> --fixed-fps 60 … -s res://tests/golden/ui_shots.gd -- --shot=pause --out=<file.png> <race args>
##   godot --path <tree> --fixed-fps 60 … -s res://tests/golden/ui_shots.gd -- --shot=loading --out=<file.png>
##
## pause    the race scene (standalone, its own command line: --stage=… --graphics=arcade …) runs PAUSE_AFTER frames,
##          then opens its pause menu (_pause_now()); the picture is taken PAUSED_FRAMES frames later.
## loading  "Etappe wird geladen …" (LoadingOverlay without a progress call) over a plain background.
## Exit code 0 when the picture was written, 1 otherwise.

const PAUSE_AFTER := 150
const PAUSED_FRAMES := 30
const LOADING_FRAMES := 8

var _shot := ""
var _out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--out="):
			_out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	if _out == "":
		printerr("ui_shots: --out=<file.png> fehlt")
		quit(1)
		return
	match _shot:
		"pause":
			await _pause()
		"loading":
			await _loading()
		_:
			printerr("ui_shots: unbekannte Aufnahme \"%s\" (pause | loading)" % _shot)
			quit(1)
			return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(_out) if img != null else ERR_CANT_CREATE
	print("UI-SHOT ", _shot, " ", _out, " -> ", error_string(err))
	quit(0 if err == OK else 1)


func _pause() -> void:
	var scene: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in PAUSE_AFTER:
		await process_frame
	scene.call("_pause_now")
	for i in PAUSED_FRAMES:
		await process_frame


func _loading() -> void:
	var gf: Node = root.get_node_or_null("GameFlow")
	if gf != null and gf.get("attract") != null:
		(gf.get("attract") as Node).set("enabled", false)
	for i in 5:
		await process_frame
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.2, 0.3)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var overlay: Control = (load("res://scripts/ui/widgets/loading_overlay.gd") as GDScript).new()
	layer.add_child(overlay)
	for i in LOADING_FRAMES:
		await process_frame
