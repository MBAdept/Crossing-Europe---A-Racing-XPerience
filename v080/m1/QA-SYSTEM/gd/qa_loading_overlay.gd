extends SceneTree
## QA-SYSTEM: picture of the LoadingOverlay as the menus use it (no set_progress call) – run in v0.7.0 and v0.8.0,
## compare the PNGs. Usage: godot --path <tree> ... -s <this> -- --out=<file.png>

var _out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	var gf: Node = root.get_node_or_null("GameFlow")
	if gf != null and gf.get("attract") != null:
		(gf.get("attract") as Node).set("enabled", false)
	for i in 5:
		await process_frame
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.2, 0.3)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	layer.add_child(bg)
	var script: GDScript = load("res://scripts/ui/widgets/loading_overlay.gd")
	var ov: Control = script.new()
	layer.add_child(ov)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out)
	print("saved ", _out)
	quit(0)
