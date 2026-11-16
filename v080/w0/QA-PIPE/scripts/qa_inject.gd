extends SceneTree
## QA: MainLoop script used TOGETHER with the race scene (godot -s qa_inject.gd res://scenes/race/race.tscn -- ...):
## while the Arcade race runs, it loads every Modern shader, material and model in the same process and renders
## them in a SubViewport - the Arcade picture taken by the Screenshotter afterwards must be the golden frame.
##   --inject=none      nothing (control run of this harness)
##   --inject=before    Modern scene from frame 20 to frame 70, then freed, ModelDB.release_all()
##   --inject=during    Modern scene from frame 20 on and still alive (night values in the globals) at the shot

var _frame := 0
var _mode := "none"
var _sv: SubViewport
var _mats: ModernMaterials
var _said := false


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--inject="):
			_mode = a.substr(9)
	print("QA inject: mode ", _mode)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 5 and not _said:
		_said = true
		var names: Array = []
		for c in root.get_children():
			names.append(str(c.name))
		print("QA inject: root children at frame 5: ", names)
	if _mode != "none" and _frame == 20:
		_build()
	if _mode == "before" and _frame == 70:
		_sv.queue_free()
		_sv = null
		_mats.clear()
		_mats = null
		ModelDB.release_all()
		print("QA inject: Modern scene freed at frame 70, loads ", ModelDB.loads)
	return false


func _build() -> void:
	_mats = ModernMaterials.new()
	_sv = SubViewport.new()
	_sv.size = Vector2i(640, 360)
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.adjustment_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, 200, 0)
	_sv.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(8, 10, 70)
	cam.far = 3000.0
	_sv.add_child(cam)
	var x := -50.0
	var n := 0
	for sid: String in ["landmarks/michel", "props/farmhouse", "props/tree_oak", "props/streetlight", "traffic/sedan_red", "player/limousine", "showroom/limousine"]:
		var node := ModelFactory.build(sid, "", _mats)
		if node != null:
			node.position = Vector3(x, 0, 0)
			ModelFactory.set_lamps(node, Vector4(1, 1, 1, 1), Vector4(1, 1, 1, 1))
			_sv.add_child(node)
			n += 1
		x += 16.0
	var imp := ModelFactory.build_impostor("props/tree_oak", _mats)
	imp.position = Vector3(40, 0, 10)
	_sv.add_child(imp)
	cam.look_at(Vector3(0, 6, 0))
	ModernMaterials.set_global("ce_night", 1.0)
	ModernMaterials.set_global("ce_wet", 1.0)
	ModernMaterials.set_global("ce_snow", 1.0)
	ModernMaterials.set_global("ce_time", 123.4)
	ModernMaterials.set_global("ce_fog_color", Color(1, 0, 1))
	ModernMaterials.set_global("ce_sun_color", Color(5, 5, 5))
	ModernMaterials.set_global("ce_ambient", Color(3, 0, 0))
	print("QA inject: Modern scene built at frame 20: %d models, %d materials, loads %d" % [n, _mats.all_materials().size(), ModelDB.loads])
