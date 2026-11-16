extends SceneTree
# Saves one baked mesh uncompressed into two folders, to see which bytes depend on the path.
func _initialize() -> void:
	var dirs := OS.get_cmdline_user_args()
	var mesh: ArrayMesh = ResourceLoader.load("res://assets/models/props/streetlight/lod0_body.res", "", ResourceLoader.CACHE_MODE_IGNORE)
	for d: String in dirs:
		var m: ArrayMesh = mesh.duplicate(true)
		var e := ResourceSaver.save(m, d.path_join("lod0_body.res"), 0)
		print("save ", d, " -> ", e, " uid ", ResourceLoader.get_resource_uid(d.path_join("lod0_body.res")))
	print("committed uid ", ResourceLoader.get_resource_uid("res://assets/models/props/streetlight/lod0_body.res"))
	quit(0)
