extends SceneTree
## QA-SYSTEM: the race scene (Arcade) driven N frames, then the pause menu opened through _pause_now(); a picture after
## 30 more frames. Run in v0.7.0 and v0.8.0 with --fixed-fps 60 and compare. Args after --: --out=<png> plus the
## race scene's own CLI setup (--stage=… --autopilot …).

var _out := ""
var _scene: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	for i in 150:
		await process_frame
	_scene.call("_pause_now")
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out)
	print("saved ", _out, " paused=", paused)
	quit(0)
