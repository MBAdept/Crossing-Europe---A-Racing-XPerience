extends SceneTree
## Scratch probe (not part of the repo): can a test change the window's aspect ratio under Xvfb?

func _initialize() -> void:
	_run.call_deferred()


func _show(tag: String) -> void:
	print(tag, ": mode ", DisplayServer.window_get_mode(), " ds size ", DisplayServer.window_get_size(), " root.size ", root.size,
		" visible ", root.get_visible_rect().size, " screen ", DisplayServer.screen_get_size(), " aspect ", root.content_scale_aspect,
		" scale_mode ", root.content_scale_mode, " scale_size ", root.content_scale_size)


func _run() -> void:
	for i in 3:
		await process_frame
	_show("start")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for i in 5:
		await process_frame
	_show("windowed")
	DisplayServer.window_set_size(Vector2i(1152, 720))
	for i in 10:
		await process_frame
	_show("ds resized")
	root.size = Vector2i(1152, 720)
	for i in 10:
		await process_frame
	_show("root.size set")
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	for i in 5:
		await process_frame
	_show("expand")
	await RenderingServer.frame_post_draw
	print("image ", root.get_texture().get_image().get_size())
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for i in 5:
		await process_frame
	_show("keep")
	await RenderingServer.frame_post_draw
	print("image ", root.get_texture().get_image().get_size())
	quit(0)
