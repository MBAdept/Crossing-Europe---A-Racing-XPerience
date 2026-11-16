extends SceneTree
## R3 look bench (scratch, not in the repo): vehicles built by ModelFactory with the shared ModernMaterials, lit by the
## built-in PlainEnvironment of the renderer (the same light law as the race), seen by the game camera (focal 711 px,
## 3.4 m high) – quick iterations on paint, glass, lamps, contact shadow and flares.
##   godot --path . -s <this> -- --out=<png> [--hour=12] [--weather=normal] [--scene=chase|side|traffic|night]

const PlainEnvironment := preload("res://scripts/race3d/plain_environment.gd")

var _vp: SubViewport
var _env: Node
var _cam: Camera3D
var _mats: ModernMaterials


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, def: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def


func _run() -> void:
	var out := _arg("out", "/tmp/bench.png")
	var hour := float(_arg("hour", "12"))
	var weather := _arg("weather", "normal")
	var scene := _arg("scene", "chase")
	ModelDB.load_manifest()
	_mats = ModernMaterials.shared()
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var sky := ColorRect.new()
	_env = PlainEnvironment.new()
	_vp.add_child(_env)
	_env.call("apply_quality", {"shadow_splits": 2, "shadow_distance_m": 120.0})
	var daytime: Dictionary = ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {})
	var pal := Palette.compute(hour, weather, daytime, false)
	var canvas := CanvasLayer.new()
	canvas.layer = -10
	_vp.add_child(canvas)
	sky.color = pal["sky_bottom"]
	sky.size = Vector2(1280, 720)
	canvas.add_child(sky)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var near := 1.0
	var size := near * 720.0 / 711.0
	_cam.set_frustum(size, Vector2(0.0, -0.05 * size), near, 2600.0)
	_vp.add_child(_cam)
	_cam.make_current()
	# road: a lit plane (albedo 0.38 like the reference asphalt)
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 2000.0)
	road.mesh = pm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.36, 0.36, 0.37)
	rm.roughness = 0.9
	road.material_override = rm
	road.position = Vector3(0.0, 0.0, -900.0)
	_vp.add_child(road)
	var view := {"palette": pal, "camera_in_tunnel": false, "visibility_m": 900.0, "bg_offset": 0.0, "time": 1.0}
	_env.call("update", view, 0.0)
	# vehicles: [set, x, z (centre, m ahead of the camera), yaw_deg, lamps a, lamps b]
	var cars: Array = []
	match scene:
		"side":
			_cam.position = Vector3(-7.0, 1.6, 0.0)
			_cam.rotation = Vector3(0.0, -PI * 0.5, 0.0)
			cars = [["player/limousine", 0.0, -2.0, 0.0], ["traffic/sedan_red", 0.0, 4.5, 0.0], ["traffic/hatch_yellow", 0.0, -8.0, 0.0]]
		"boxes":
			_cam.position = Vector3(0.0, 3.4, 0.0)
			cars = [["traffic/sports_yellow", -3.75, -16.0, 8.0], ["traffic/suv_grey", 3.75, -18.0, -8.0], ["traffic/van_white", 0.0, -30.0, 0.0],
				["traffic/bus_red", -3.75, -45.0, 0.0], ["police/de", 3.75, -40.0, 0.0], ["traffic/hatch_yellow", -7.5, -26.0, 0.0]]
		"trucks":
			_cam.position = Vector3(0.0, 3.4, 0.0)
			cars = [["traffic/truck_white", -3.75, -20.0, 0.0], ["traffic/truck_red", 3.75, -45.0, 0.0], ["traffic/truck_blue", 0.0, -90.0, 0.0]]
		"traffic":
			_cam.position = Vector3(0.0, 3.4, 0.0)
			cars = [["player/limousine", 0.0, -9.0, 0.0], ["traffic/sedan_red", -3.75, -22.0, 0.0], ["traffic/hatch_yellow", -3.75, -55.0, 0.0],
				["traffic/wagon_silver", 3.75, -35.0, 0.0], ["traffic/truck_white", 3.75, -70.0, 0.0], ["police/de", -3.75, -40.0, 0.0],
				["traffic/van_red", 0.0, -90.0, 0.0], ["traffic/bus_blue", -3.75, -120.0, 0.0]]
		_:
			_cam.position = Vector3(0.0, 3.4, 0.0)
			cars = [["player/limousine", 0.0, -9.0, 0.0], ["traffic/hatch_yellow", -3.75, -25.0, 0.0], ["traffic/sedan_red", 3.75, -18.0, 0.0]]
	var lods := _arg("lod", "")
	for c: Array in cars:
		var sid := str(c[0])
		var z := float(c[2])
		var dist := absf(z - _cam.position.z)
		var lod := lods
		if lod == "":
			lod = "lod0" if dist < 40.0 else ("lod1" if dist < 120.0 else "lod2")
		var n: Node3D = null
		if ModelDB.has_model(sid):
			n = ModelFactory.build(sid, "" if sid.begins_with("player/") else lod, _mats, true)
		else:
			n = ModelFactory.build_box(sid, _mats)
		if n == null:
			print("kein Modell: ", sid)
			continue
		n.position = Vector3(float(c[1]), 0.0, z)
		n.rotation.y = deg_to_rad(float(c[3]))
		_vp.add_child(n)
		var night := float(pal.get("lights", 0.0))
		ModelFactory.set_lamps(n, Vector4(night, 0.0, 0.0, 0.0), Vector4(night, 0.0, 0.0, 0.0))
	# environment of the paint as the vehicle layer sets it
	var top: Color = pal["sky_top"]
	var bottom: Color = pal["sky_bottom"]
	var amb: Color = pal["ambient"]
	var fog: Color = pal["fog"]
	_mats.set_class_parameter("vpbr", "env_energy", 1.6)
	_mats.set_class_parameter("vpbr", "paint_base", 0.9)
	_mats.set_class_parameter("vpbr", "flake_strength", 0.6)
	_mats.set_class_parameter("glass", "env_energy", 2.2)
	for cls: String in ["vpbr", "glass"]:
		_mats.set_class_parameter(cls, "env_zenith", top)
		_mats.set_class_parameter(cls, "env_horizon", bottom.lerp(fog, 0.35))
		_mats.set_class_parameter(cls, "env_ground", Color(0.30 * amb.r, 0.31 * amb.g, 0.32 * amb.b))
	for i in 6:
		await process_frame
	var img := _vp.get_texture().get_image()
	img.save_png(out)
	print("gespeichert: ", out)
	quit(0)
