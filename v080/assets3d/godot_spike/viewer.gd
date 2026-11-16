extends Node3D
## Asset spike viewer (Compatibility renderer): loads .glb models exported by ce3d, assigns the role
## materials, lights them (sun with shadows / night with emissive lights) and saves screenshots.
##
## Args after "--":  --model=res://models/a.glb[@x,z,yaw][;res://...]  --out=prefix  --mode=day|night
##   --cam=px,py,pz,tx,ty,tz  --fov=40  --paint=#c01818  --brake  --frames=6  --ground=asphalt|grass
##   --steer=20  --shadow_dist=60 --no_override  --size=1280x720

var args: Dictionary = {}
var frame: int = 0
var models: Array[Node3D] = []
var out_prefix: String = ""
var night: bool = false
var t_load_ms: float = 0.0
var mats_emissive: Array[ShaderMaterial] = []
var total_tris: int = 0
var total_surfaces: int = 0

const TRIM := preload("res://shaders/trim.gdshader")
const EMIS := preload("res://shaders/emissive.gdshader")
const LENS := preload("res://shaders/lens.gdshader")
const BPAINT := preload("res://shaders/baked_paint.gdshader")
const LEAVES := preload("res://shaders/leaves.gdshader")


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func _vec3(s: String, i: int = 0) -> Vector3:
	var p: PackedStringArray = s.split(",")
	return Vector3(p[i].to_float(), p[i + 1].to_float(), p[i + 2].to_float())


func _ready() -> void:
	_parse_args()
	night = String(args.get("mode", "day")) == "night"
	out_prefix = String(args.get("out", "user://shot"))
	if args.has("size"):
		var sz: PackedStringArray = String(args["size"]).split("x")
		get_window().size = Vector2i(sz[0].to_int(), sz[1].to_int())
	_build_world()
	if args.has("loadtex"):
		for tp: String in String(args["loadtex"]).split(";", false):
			var t1: int = Time.get_ticks_usec()
			var tx: Texture2D = ResourceLoader.load(tp, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			var ms: float = float(Time.get_ticks_usec() - t1) / 1000.0
			print("LOADTEX %s %.1f ms %dx%d fmt=%d" % [tp, ms, tx.get_width(), tx.get_height(), tx.get_image().get_format() if tx.get_image() != null else -1])
	var t0: int = Time.get_ticks_usec()
	for spec: String in String(args.get("model", "")).split(";", false):
		var parts: PackedStringArray = spec.split("@")
		var ps: PackedScene = load(parts[0]) as PackedScene
		if ps == null:
			push_error("cannot load " + parts[0])
			continue
		var inst: Node3D = ps.instantiate() as Node3D
		add_child(inst)
		if parts.size() > 1:
			var q: PackedStringArray = parts[1].split(",")
			inst.position = Vector3(q[0].to_float(), 0.0, q[1].to_float())
			if q.size() > 2:
				inst.rotation.y = deg_to_rad(q[2].to_float())
			if q.size() > 3 and q[3] == "m":
				inst.scale = Vector3(-1.0, 1.0, 1.0)
		models.append(inst)
		if not args.has("no_override"):
			_apply_roles(inst, parts[0])
		_count(inst)
	t_load_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	if args.has("multimesh"):
		_multimesh_test(String(args["multimesh"]))
	if args.has("steer"):
		for m: Node3D in models:
			for n: Node in m.find_children("wheel_0*", "Node3D", true, false):
				(n as Node3D).rotation.y = deg_to_rad(-String(args["steer"]).to_float())
	if night and args.has("headlights"):
		for m2: Node3D in models:
			if m2.scene_file_path.contains("player") or m2.scene_file_path.contains("traffic"):
				_add_headlights(m2)


func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	if night:
		sm.sky_top_color = Color(0.01, 0.015, 0.04)
		sm.sky_horizon_color = Color(0.03, 0.04, 0.08)
		sm.ground_bottom_color = Color(0.01, 0.01, 0.015)
		sm.ground_horizon_color = Color(0.03, 0.04, 0.07)
		sm.sun_angle_max = 1.0
	else:
		sm.sky_top_color = Color(0.22, 0.42, 0.78)
		sm.sky_horizon_color = Color(0.68, 0.78, 0.9)
		sm.ground_bottom_color = Color(0.18, 0.17, 0.15)
		sm.ground_horizon_color = Color(0.62, 0.68, 0.74)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0 if not night else 1.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6 if night else 0.25
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	if args.has("fog"):
		env.fog_enabled = true
		env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -128.0, 0.0) if not night else Vector3(-55.0, 40.0, 0.0)
	sun.light_energy = 1.25 if not night else 0.06
	sun.light_color = Color(1.0, 0.96, 0.9) if not night else Color(0.6, 0.7, 1.0)
	sun.shadow_enabled = not args.has("noshadow")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = String(args.get("shadow_dist", "60")).to_float()
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.2
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000.0, 3000.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	if String(args.get("ground", "asphalt")) == "grass":
		gm.albedo_color = Color(0.2, 0.33, 0.12)
		gm.roughness = 0.95
	else:
		gm.albedo_color = Color(0.2, 0.2, 0.21)
		gm.roughness = 0.82
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	var c: String = String(args.get("cam", "4.2,1.6,5.5,0,0.6,0"))
	cam.position = _vec3(c, 0)
	cam.fov = String(args.get("fov", "40")).to_float()
	cam.near = String(args.get("near", "0.3")).to_float()
	cam.far = 4000.0
	add_child(cam)
	cam.look_at(_vec3(c, 3), Vector3.UP)
	cam.current = true
	if night and args.has("lamp"):
		var lp := OmniLight3D.new()
		lp.position = _vec3(String(args["lamp"]), 0)
		lp.light_color = Color(1.0, 0.78, 0.5)
		lp.light_energy = 6.0
		lp.omni_range = 30.0
		lp.shadow_enabled = true
		add_child(lp)


func _extras(m: Material) -> Dictionary:
	if m != null and m.has_meta("extras"):
		var e: Variant = m.get_meta("extras")
		if e is Dictionary:
			return e
	return {}


func _apply_roles(root: Node3D, path: String) -> void:
	var base: String = path.get_basename()
	var paint_col: Color = Color(String(args.get("paint", "")))if args.has("paint") else Color(0, 0, 0, 0)
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var mesh: Mesh = mi.mesh
		for s: int in mesh.get_surface_count():
			var src: Material = mesh.surface_get_material(s)
			var mname: String = src.resource_name if src != null else ""
			var ex: Dictionary = _extras(src)
			if mname == "trim":
				var sm := ShaderMaterial.new()
				sm.shader = TRIM
				mi.set_surface_override_material(s, sm)
			elif mname == "paint":
				var pm := StandardMaterial3D.new()
				var bm: BaseMaterial3D = src as BaseMaterial3D
				pm.albedo_color = paint_col if paint_col.a > 0.0 else bm.albedo_color
				pm.metallic = bm.metallic
				pm.roughness = bm.roughness
				pm.clearcoat_enabled = true
				pm.clearcoat = 1.0
				pm.clearcoat_roughness = 0.04
				mi.set_surface_override_material(s, pm)
			elif mname == "glass":
				var gm := StandardMaterial3D.new()
				gm.albedo_color = Color(0.02, 0.025, 0.03)
				gm.roughness = 0.03
				gm.metallic = 0.0
				gm.metallic_specular = 1.0
				gm.clearcoat_enabled = true
				gm.clearcoat = 0.6
				gm.clearcoat_roughness = 0.01
				mi.set_surface_override_material(s, gm)
			elif mname == "leaves":
				var lf := ShaderMaterial.new()
				lf.shader = LEAVES
				lf.set_shader_parameter("leaf_tex", (src as BaseMaterial3D).albedo_texture)
				lf.set_shader_parameter("wind_time", String(args.get("wind_t", "0")).to_float())
				mi.set_surface_override_material(s, lf)
			elif mname == "lens":
				var lm := ShaderMaterial.new()
				lm.shader = LENS
				mi.set_surface_override_material(s, lm)
			elif mname.begins_with("em_"):
				var em := ShaderMaterial.new()
				em.shader = EMIS
				var emit: Dictionary = ex.get("emit", {})
				var energy: float = 0.0
				var col: Color = Color(0, 0, 0)
				for layer: String in emit.keys():
					var on: bool = (layer == "tail" and night) or (layer == "brake" and args.has("brake")) \
							or (layer == "lights" and night) or (layer.begins_with("beacon") and args.has("beacon"))
					if on:
						var v: Array = emit[layer]
						col += Color(float(v[0]), float(v[1]), float(v[2]))
						energy = 1.0
				var mx: float = maxf(col.r, maxf(col.g, col.b))
				if mx > 0.0:
					col = Color(col.r / mx, col.g / mx, col.b / mx)
					energy = clampf(mx, 0.25, 1.0) * 3.5
				em.set_shader_parameter("emit_color", col)
				em.set_shader_parameter("energy", energy)
				mi.set_surface_override_material(s, em)
			elif mname == "baked":
				if FileAccess.file_exists(base + "_emit_tail.png") or ResourceLoader.exists(base + "_emit_tail.png"):
					var bp := ShaderMaterial.new()
					bp.shader = BPAINT
					var bm2: BaseMaterial3D = src as BaseMaterial3D
					bp.set_shader_parameter("albedo_tex", bm2.albedo_texture)
					bp.set_shader_parameter("orm_tex", bm2.roughness_texture)
					bp.set_shader_parameter("tail_tex", load(base + "_emit_tail.png"))
					if ResourceLoader.exists(base + "_emit_brake.png"):
						bp.set_shader_parameter("brake_tex", load(base + "_emit_brake.png"))
					bp.set_shader_parameter("tail_energy", 4.0 if night else 0.0)
					bp.set_shader_parameter("brake_energy", 6.0 if args.has("brake") else 0.0)
					if paint_col.a > 0.0:
						bp.set_shader_parameter("paint_color", paint_col)
					else:
						bp.set_shader_parameter("use_paint", 0.0)
					mi.set_surface_override_material(s, bp)
				else:
					var bm3: BaseMaterial3D = (src as BaseMaterial3D).duplicate() as BaseMaterial3D
					if args.has("albedo_override"):
						bm3.albedo_texture = load(String(args["albedo_override"])) as Texture2D
					if bm3.emission_texture != null:
						bm3.emission_enabled = night
						bm3.emission = Color(1, 1, 1)
						bm3.emission_energy_multiplier = 1.1
					mi.set_surface_override_material(s, bm3)


func _count(root: Node3D) -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for s: int in mesh.get_surface_count():
			total_surfaces += 1
			var arr: Array = mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx != null:
				total_tris += (idx as PackedInt32Array).size() / 3


func _add_headlights(m: Node3D) -> void:
	var aabb := AABB()
	var first: bool = true
	for n: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var bb: AABB = mi.global_transform * mi.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	for sx: float in [-0.6, 0.6]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(aabb.get_center().x + sx, 0.65, aabb.position.z - 0.05)
		sp.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
		sp.spot_range = 60.0
		sp.spot_angle = 28.0
		sp.light_energy = 14.0
		sp.light_color = Color(1.0, 0.97, 0.9)
		sp.shadow_enabled = sx > 0.0
		add_child(sp)


func _process(_dt: float) -> void:
	frame += 1
	var want: int = String(args.get("frames", "8")).to_int()
	if frame == want:
		var img: Image = get_viewport().get_texture().get_image()
		var p: String = out_prefix + ".png"
		img.save_png(p)
		var prims: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var objs: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		var vmem: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
		var tmem: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
		var bmem: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
		print("SHOT %s mode=%s load_ms=%.1f mesh_tris=%d mesh_surfaces=%d frame_prims=%d draw_calls=%d objects=%d vmem_mb=%.1f tex_mb=%.1f buf_mb=%.1f" % [
			p, "night" if night else "day", t_load_ms, total_tris, total_surfaces, prims, draws, objs,
			float(vmem) / 1048576.0, float(tmem) / 1048576.0, float(bmem) / 1048576.0])
	if frame > want + 1:
		get_tree().quit()


func _multimesh_test(path: String) -> void:
	# two instances of the first mesh of a model in one MultiMesh, the second mirrored (scale.x = -1)
	var ps: PackedScene = load(path) as PackedScene
	var inst: Node3D = ps.instantiate() as Node3D
	var mis: Array[Node] = inst.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (mis[0] as MeshInstance3D).mesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 2
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(16.0, 0.0, 0.0)))
	mm.set_instance_transform(1, Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3(-16.0, 0.0, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	inst.free()
