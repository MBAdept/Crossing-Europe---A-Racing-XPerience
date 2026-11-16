extends SceneTree
## Review scene of the prop models (docs/modelle.md sections 14 and 15): the models of the manifest beside a road,
## seen through the GAME camera (contract D12: 3.4 m high, no pitch, focal length 711 px at 720 px, horizon at 45 %),
## with the level of detail the props builder picks by distance (lod0 to 60 m, lod1 to 200 m, then the impostor
## or the last level). Needs OpenGL - run it through tools/models/prop_scene.sh (Xvfb):
##   godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/models/prop_scene.gd --
##       --out=<abs.png> --models=<id>,<id>... [--dist=15,40,100,250] [--x=9] [--night] [--zoom=2]
##       [--mode=dist|road|lods|clip] [--tile=360x300] [--sun=x,y,z]
##       [--look=race [--hour=12] [--weather=normal] [--preset=medium] [--vis=<m>]] [--sprite] [--d0=60 --d1=200]
## --mode=dist  one row per model, one tile per distance: a crop of the 1280x720 game picture around the model,
##              magnified by --zoom with whole pixels (what the player sees, pixel for pixel)
## --mode=lods  one row per model: lod0 / lod1 / impostor side by side at the switch distances (60 m and 200 m)
##              - the representations of chunk level 0 / 1 / 2 the props builder takes (_reps(): a model without an
##              impostor keeps its last level, a rock with one level keeps lod0) -
##              in the same crop - colour or size jumps between the levels show here; the mean colour of each
##              tile is printed ("STUFEN <model> …") and the swaps are measured ("UMSCHALT <model> …": share of
##              the model's pixels that change at the swap, change of brightness (luma of the mean colour, %) and
##              of hue (degrees))
## --mode=road  the whole game picture: the models in rows along both roadsides every --every m (yaw and scale
##              varied like the props builder does for vegetation)
## --mode=clip  the camera drives along such a row at --kmh (120) for --secs (2) seconds, 60 frames per second:
##              every frame is written as <out without .png>_NNN.png (wind and levels of detail move with the
##              clock; the level of every model is chosen by its distance with the hysteresis of the props
##              builder) - for judging shimmer of the alpha-tested leaves and pops at the swaps frame by frame
## Variants (model ids without a set of their own) are reachable: the scene loads the manifest with a set for
## every model id.
## --look=race  (AS3) the light of a race instead of the small review rig: the EnvironmentRig of the renderer
##              (scripts/race3d/environment_rig.gd) driven by the palette of --hour / --weather (Palette.compute),
##              the quality levels of --preset (shadows, glow, MSAA, prop LOD distances), the sight of the race
##              (render.draw_distance_m x the visibility factor of the hour and the weather; --vis overrides it),
##              the look the vehicle layer puts on the vpbr material (trunks are vpbr) and the palette's sky
##              behind the picture. Default: the review rig of wave 2 (unchanged).
## --sprite     (AS3) the Arcade sprite of the model's set as a stand-in billboard (as the props builder draws
##              sets without a model) in the same light and fog: one more row per model in --mode=dist, one more
##              column (at the second switch distance) in --mode=lods
## --d0 / --d1  switch distances lod0 -> lod1 -> impostor (default 60 / 200 m, with --look=race those of --preset)

const FOCAL_PX := 711.0
const GAME := Vector2i(1280, 720)
const CAM_H := 3.4
const LOD0_M := 60.0
const LOD1_M := 200.0
const RIG_SCRIPT := "res://scripts/race3d/environment_rig.gd"
const QUALITY_SCRIPT := "res://scripts/race3d/quality.gd"
const VEHICLES_LAYER := "res://scripts/race3d/layers/vehicles.gd"
const SPRITE_MANIFEST := "res://assets/sprites/manifest.json"
const SPRITE_ROOT := "res://assets/sprites/"
const BACKDROP_LAYER := -10
const LOD_HYSTERESIS_M := 6.0          ## props builder: a level is left this much later than it is entered
const SWAP_DIFF := 0.06                ## a pixel counts as changed at a swap when r + g + b differ by more than this

var _args: Dictionary = {}
var _mats: ModernMaterials
var _sv: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _holder: Node3D
var _label_sv: SubViewport
var _label: Label
var _sky_mat: ProceduralSkyMaterial
var _rig: Node3D                       ## --look=race: the renderer's EnvironmentRig (null: the review rig)
var _quality: RefCounted
var _pal: Dictionary = {}
var _vis := 900.0
var _lod0_m := LOD0_M
var _lod1_m := LOD1_M
var _sprites: Dictionary = {}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	var out := str(_args.get("out", ""))
	if out == "" or not _args.has("models"):
		print("prop_scene: --out=<Datei.png> und --models=<id,...> angeben")
		quit(1)
		return
	if not _load_manifest_with_model_sets():
		print("prop_scene: kein gültiges Modell-Manifest")
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	var models: Array = str(_args["models"]).split(",", false)
	var mode := str(_args.get("mode", "dist"))
	if mode == "clip":
		var n: int = await _clip(models, out)
		print("prop_scene: clip -> %s_NNN.png (%d Bilder)" % [out.get_basename(), n])
		quit(0 if n > 0 else 1)
		return
	var img: Image
	if mode == "road":
		img = await _road(models)
	elif mode == "lods":
		img = await _lods(models)
	else:
		img = await _dist(models)
	var err := img.save_png(out)
	print("prop_scene: %s -> %s%s" % [mode, out, "" if err == OK else "  FEHLER %d" % err])
	quit(0 if err == OK else 1)


## The shipped manifest plus a set "<model id>" for every model that has none (variants) - added to the loaded
## tables of this process only (a review tool; the manifest file is never touched).
func _load_manifest_with_model_sets() -> bool:
	if not ModelDB.load_manifest():
		return false
	for mid: String in ModelDB.model_ids():
		if not ModelDB._sets.has(mid):
			ModelDB._sets[mid] = {"model": mid}
	return true


# --- rig ---------------------------------------------------------------------------------------------------------

func _build_rig() -> void:
	var night := _args.has("night")
	_sv = SubViewport.new()
	_sv.size = GAME
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_2X
	root.add_child(_sv)
	if str(_args.get("look", "")) == "race":
		_build_race_light()
	else:
		_build_review_light(night)
	if _args.has("d0"):
		_lod0_m = float(str(_args["d0"]))
	if _args.has("d1"):
		_lod1_m = maxf(_lod0_m, float(str(_args["d1"])))
	# ground: grass, a two-lane road along -Z under the camera
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000.0, 4000.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.31, 0.12)
	gm.roughness = 0.95
	ground.material_override = gm
	_sv.add_child(ground)
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(9.0, 4000.0)
	road.mesh = rm
	road.position = Vector3(0.0, 0.01, -1990.0)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.17, 0.17, 0.18)
	am.roughness = 0.9
	road.material_override = am
	_sv.add_child(road)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_FRUSTUM
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 1.0
	_cam.far = 2600.0
	_cam.size = 1.0 * float(GAME.y) / FOCAL_PX
	_cam.frustum_offset = Vector2(0.0, -0.05 * _cam.size)
	_cam.position = Vector3(0.0, CAM_H, 0.0)
	_sv.add_child(_cam)
	_holder = Node3D.new()
	_sv.add_child(_holder)
	_label_sv = SubViewport.new()
	_label_sv.size = GAME
	_label_sv.transparent_bg = true
	_label_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_label_sv)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label_sv.add_child(_label)


## The small review rig of wave 2: procedural sky, a fixed sun and ambient light, depth fog 405 .. 900 m.
func _build_review_light(night: bool) -> void:
	_env = Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.adjustment_enabled = true
	_env.glow_enabled = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.0
	# depth fog as the race does it (F4): begin 0.45 x visibility, end = visibility (900 m)
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_begin = 405.0
	_env.fog_depth_end = 900.0
	_env.fog_depth_curve = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	_sv.add_child(we)
	_sun = DirectionalLight3D.new()
	var sd := str(_args.get("sun", "-0.55,0.62,0.55")).split(",")
	var to_sun := Vector3(float(sd[0]), float(sd[1]), float(sd[2])).normalized()
	_sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 200.0
	_sun.shadow_bias = 0.03
	_sun.shadow_normal_bias = 1.0
	_sv.add_child(_sun)
	if night:
		_sky_mat.sky_top_color = Color(0.01, 0.014, 0.035)
		_sky_mat.sky_horizon_color = Color(0.03, 0.04, 0.075)
		_sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.012)
		_sky_mat.ground_horizon_color = Color(0.03, 0.035, 0.06)
		_env.ambient_light_color = Color(0.1, 0.12, 0.2)
		_env.ambient_light_energy = 0.55
		_env.glow_intensity = 0.7
		_env.fog_light_color = Color(0.03, 0.04, 0.07)
		_sun.light_energy = 0.1
		_sun.light_color = Color(0.62, 0.72, 1.0)
	else:
		_sky_mat.sky_top_color = Color(0.24, 0.44, 0.78)
		_sky_mat.sky_horizon_color = Color(0.7, 0.79, 0.9)
		_sky_mat.ground_bottom_color = Color(0.2, 0.19, 0.17)
		_sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.74)
		_env.ambient_light_color = Color(0.6, 0.64, 0.7)
		_env.ambient_light_energy = 1.0
		_env.glow_intensity = 0.25
		_env.fog_light_color = Color(0.7, 0.77, 0.86)
		_sun.light_energy = 0.8
		_sun.light_color = Color(1.0, 0.97, 0.92)
	ModernMaterials.set_global("ce_night", 1.0 if night else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(_env.ambient_light_color, _env.ambient_light_energy))
	ModernMaterials.set_global("ce_sun_dir", to_sun)
	ModernMaterials.set_global("ce_time", float(str(_args.get("time", "1.7"))))
	ModernMaterials.set_global("ce_wind", Vector4(1.0, 0.0, 0.3, 0.0))


## --look=race: the light, fog, shadows and globals of a race at --hour / --weather with the levels of --preset.
func _build_race_light() -> void:
	var cfg: Dictionary = ConfigLoader.load_merged()
	var hour := float(str(_args.get("hour", "12")))
	var weather := str(_args.get("weather", "normal"))
	_pal = Palette.compute(hour, weather, ConfigLoader.lookup(cfg, "daytime", {}), false)
	var em := EnvironmentModel.new()
	em.setup(cfg)
	_vis = float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0)) * em.visibility_factor(hour, weather, false)
	if _args.has("vis"):
		_vis = float(str(_args["vis"]))
	var gfx_cfg: Dictionary = ConfigLoader.lookup(cfg, "graphics", {})
	var presets: Dictionary = gfx_cfg.get("presets", {})
	var levels := Gfx.levels(Gfx.preset_values(str(_args.get("preset", "medium")), presets), gfx_cfg)
	_lod0_m = float(levels.get("prop_lod0_m", LOD0_M))
	_lod1_m = maxf(_lod0_m, float(levels.get("prop_lod1_m", LOD1_M)))
	_quality = (load(QUALITY_SCRIPT) as GDScript).new()
	_quality.call("apply", _sv, levels)
	_rig = (load(RIG_SCRIPT) as GDScript).new()
	_sv.add_child(_rig)
	_rig.call("setup", null)
	_rig.call("apply_quality", levels)
	# the look the vehicle layer puts on the shared class materials (tree trunks are vpbr): the class material
	# must exist before it is tuned - a material created afterwards would miss the look
	var look: Variant = (load(VEHICLES_LAYER) as GDScript).get_script_constant_map().get("LOOK", [])
	if look is Array:
		for l: Variant in look:
			var e: Array = l
			_mats.material(str(e[0]))
			_mats.set_class_parameter(str(e[0]), str(e[1]), e[2])
	# ... and the environment it mirrors (layers/vehicles.gd _set_environment)
	var top: Color = _pal.get("sky_top", Color(0.11, 0.36, 0.79))
	var bottom: Color = _pal.get("sky_bottom", Color(0.73, 0.87, 0.96))
	var amb: Color = _pal.get("ambient", Color.WHITE)
	var horizon := bottom.lerp(_pal.get("fog", bottom), 0.35)
	for cls: String in ["vpbr", "glass"]:
		_mats.material(cls)
		_mats.set_class_parameter(cls, "env_zenith", top)
		_mats.set_class_parameter(cls, "env_horizon", horizon)
		_mats.set_class_parameter(cls, "env_ground", Color(0.30 * amb.r, 0.31 * amb.g, 0.32 * amb.b))
		_mats.set_class_parameter(cls, "env_tunnel", Palette.TUNNEL_AMBIENT * 0.45)
	_race_update(float(str(_args.get("time", "1.7"))))
	# the palette's sky behind the 3D picture (BG_CANVAS: canvas layers up to -10 are the background)
	var layer := CanvasLayer.new()
	layer.layer = BACKDROP_LAYER
	_sv.add_child(layer)
	var sky := ColorRect.new()
	sky.size = Vector2(GAME)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec4 top : source_color;\nuniform vec4 mid : source_color;\n" \
		+ "uniform vec4 bottom : source_color;\nuniform vec4 fog : source_color;\nuniform float horizon = 0.45;\n" \
		+ "void fragment() {\n\tfloat y = UV.y / horizon;\n\tvec3 c = y < 0.6 ? mix(top.rgb, mid.rgb, y / 0.6) : " \
		+ "mix(mid.rgb, bottom.rgb, clamp((y - 0.6) / 0.4, 0.0, 1.0));\n\tCOLOR = vec4(y > 1.0 ? fog.rgb : c, 1.0);\n}\n"
	var smat := ShaderMaterial.new()
	smat.shader = sh
	smat.set_shader_parameter("top", top)
	smat.set_shader_parameter("mid", _pal.get("sky_mid", top.lerp(bottom, 0.5)))
	smat.set_shader_parameter("bottom", bottom)
	smat.set_shader_parameter("fog", _pal.get("fog", bottom))
	sky.material = smat
	layer.add_child(sky)
	print("prop_scene: Renn-Licht %s Uhr, %s, Voreinstellung %s, Sicht %.0f m, Stufen %.0f / %.0f m" % [
		str(_args.get("hour", "12")), weather, str(_args.get("preset", "medium")), _vis, _lod0_m, _lod1_m])


## The rig of the race follows the clock (wind, ce_time); the camera stands at road z 0 on a straight road.
func _race_update(t: float) -> void:
	if _rig == null:
		ModernMaterials.set_global("ce_time", t)
		return
	_rig.call("update", {"palette": _pal, "camera_z": 0.0, "visibility_m": _vis, "time": t, "bg_offset": 0.0}, 0.0)


# --- placing ------------------------------------------------------------------------------------------------------

func _level_for(mid: String, dist: float) -> String:
	var m := ModelDB.model(mid)
	var names: Array[String] = []
	for l: Variant in m.get("lods", []):
		var n := str((l as Dictionary).get("name", ""))
		if n != "show":
			names.append(n)
	if dist <= _lod0_m:
		return names[0]
	if dist <= _lod1_m:
		return names[mini(1, names.size() - 1)]
	return "impostor" if m.has("impostor") else names[mini(2, names.size() - 1)]


func _place(mid: String, lod: String, pos: Vector3, yaw: float = 0.0, scale: float = 1.0, mirror: bool = false) -> Node3D:
	var node: Node3D
	if lod == "impostor":
		node = ModelFactory.build_impostor(mid, _mats)
	elif lod == "sprite":
		node = _sprite_node(_set_of_model(mid))
	else:
		node = ModelFactory.build(mid, lod, _mats)
	if node == null:
		print("prop_scene: FEHLER %s %s lässt sich nicht bauen" % [mid, lod])
		return null
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.scale = Vector3(-scale if mirror else scale, scale, scale)
	holder.add_child(node)
	_holder.add_child(holder)
	return holder


## The sprite set a model serves: its own id, or the set whose "variants" name it (seed variants).
func _set_of_model(mid: String) -> String:
	_load_sprites()
	if _sprites.has(mid):
		return mid
	for sid: String in ModelDB._sets:
		var e: Variant = ModelDB._sets[sid]
		if e is Dictionary and ((e as Dictionary).get("variants", []) as Array).has(mid) and _sprites.has(sid):
			return sid
	return mid


func _load_sprites() -> void:
	if not _sprites.is_empty():
		return
	var m: Variant = ConfigLoader.load_json(SPRITE_MANIFEST)
	if m is Dictionary and (m as Dictionary).get("sets") is Dictionary:
		_sprites = (m as Dictionary)["sets"]


## The Arcade sprite of a set as the props builder draws a set without a model (PropLibrary.standin): a billboard
## of the cell "c", lit like the ground (baked light), the baked ground shadow cut away.
func _sprite_node(set_id: String) -> Node3D:
	_load_sprites()
	var sp: Dictionary = _sprites.get(set_id, {})
	if sp.is_empty():
		return null
	var tex := load(str(sp.get("root", SPRITE_ROOT)) + str(sp.get("file", ""))) as Texture2D
	if tex == null:
		return null
	var layers: Array = sp.get("layers", ["base"])
	var angles: Array = sp.get("angles", ["c"])
	var cols := maxi(1, int(sp.get("grid_cols", angles.size())))
	var rows := int(ceil(float(maxi(1, layers.size() * angles.size())) / float(cols)))
	var cell := Vector2(1.0 / float(cols), 1.0 / float(rows))
	var ci := maxi(0, angles.find("c"))
	var bi := maxi(0, layers.find("base")) * angles.size() + ci
	var base_rect := Rect2(float(bi % cols) * cell.x, float(bi / cols) * cell.y, cell.x, cell.y)
	var mat := _mats.billboard(tex, base_rect, Rect2())
	mat.set_shader_parameter("sun_min", PropLibrary.STANDIN_SUN.x)
	mat.set_shader_parameter("sun_max", PropLibrary.STANDIN_SUN.y)
	mat.set_shader_parameter("shadow_cut", PropLibrary.STANDIN_SHADOW_CUT)
	mat.set_shader_parameter("baked_light", 1.0)
	var cellpx: Array = sp.get("cell", [64, 64])
	var w := float(sp.get("image_width_m", 1.0))
	var h := w * float(cellpx[1]) / maxf(1.0, float(cellpx[0]))
	var anchor: Array = sp.get("anchor", [0.5, 1.0])
	var mi := MeshInstance3D.new()
	mi.name = "sprite"
	mi.mesh = PropLibrary.standin_mesh(w, h, float(anchor[0]), float(anchor[1]))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _clear() -> void:
	for c: Node in _holder.get_children():
		c.free()


func _frame() -> Image:
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## Screen rect (px) of a model's bounds placed at pos.
func _screen_rect(mid: String, pos: Vector3, scale: float = 1.0) -> Rect2:
	var m := ModelDB.model(mid)
	var bb: Array = m.get("aabb", [-1, 0, -1, 1, 2, 1])
	var r := Rect2()
	var first := true
	for i in 8:
		var p := Vector3(float(bb[0] if i & 1 == 0 else bb[3]), float(bb[1] if i & 2 == 0 else bb[4]),
			float(bb[2] if i & 4 == 0 else bb[5])) * scale + pos
		if _cam.is_position_behind(p):
			continue
		var s := _cam.unproject_position(p)
		if first:
			r = Rect2(s, Vector2.ZERO)
			first = false
		else:
			r = r.expand(s)
	return r


func _caption(img: Image, text: String, at: Vector2i) -> Image:
	_label.text = text
	_label.position = Vector2(at)
	await process_frame
	await RenderingServer.frame_post_draw
	var lab := _label_sv.get_texture().get_image()
	lab.convert(Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	img.blend_rect(lab, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return img


## Crop of the game picture around a rect, magnified by zoom (nearest), centred into a tile.
func _crop(img: Image, rect: Rect2, tile: Vector2i, zoom: int) -> Image:
	var need := Vector2(tile) / float(zoom)
	var c := rect.get_center()
	var x0 := int(clampf(c.x - need.x * 0.5, 0.0, float(GAME.x) - need.x))
	var y0 := int(clampf(c.y - need.y * 0.5, 0.0, float(GAME.y) - need.y))
	var part := img.get_region(Rect2i(x0, y0, int(need.x), int(need.y)))
	part.resize(int(need.x) * zoom, int(need.y) * zoom, Image.INTERPOLATE_NEAREST)
	var out := Image.create(tile.x, tile.y, false, Image.FORMAT_RGB8)
	out.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i.ZERO)
	return out


# --- modes --------------------------------------------------------------------------------------------------------

func _tile_size() -> Vector2i:
	var p := str(_args.get("tile", "360x300")).split("x")
	return Vector2i(int(p[0]), int(p[1]))


func _dist(models: Array) -> Image:
	var dists: Array = str(_args.get("dist", "15,40,100,250")).split(",", false)
	var x := float(str(_args.get("x", "9")))
	var tile := _tile_size()
	var rows: Array = []
	for m: Variant in models:
		rows.append([str(m), ""])
		if _args.has("sprite"):
			rows.append([str(m), "sprite"])
	var sheet := Image.create(tile.x * dists.size(), tile.y * rows.size(), false, Image.FORMAT_RGB8)
	for r in rows.size():
		var mid := str(rows[r][0])
		for c in dists.size():
			var d := float(str(dists[c]))
			_clear()
			var lod := str(rows[r][1]) if str(rows[r][1]) != "" else _level_for(mid, d)
			var pos := Vector3(x, 0.0, -d)
			_place(mid, lod, pos)
			var img := await _frame()
			var rect := _screen_rect(mid, pos)
			# zoom: as large as the tile allows, at most --zoom, whole pixels
			var zmax := int(str(_args.get("zoom", "4")))
			var zoom := clampi(int(floor(minf(float(tile.x) / maxf(8.0, rect.size.x * 1.15), float(tile.y) / maxf(8.0, rect.size.y * 1.15)))), 1, zmax)
			var t := _crop(img, rect, tile, zoom)
			var what := mid if lod != "sprite" else "Arcade-Sprite " + _set_of_model(mid)
			t = await _caption_tile(t, "%s · %d m · %s · %d×" % [what, int(d), lod, zoom])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
			print("SZENE %s %d m %s %.0fx%.0f px" % [mid, int(d), lod, rect.size.x, rect.size.y])
	return sheet


func _caption_tile(t: Image, text: String) -> Image:
	var big := Image.create(GAME.x, GAME.y, false, Image.FORMAT_RGBA8)
	t.convert(Image.FORMAT_RGBA8)
	big.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i.ZERO)
	big = await _caption(big, text, Vector2i(6, t.get_height() - 22))
	var out := big.get_region(Rect2i(Vector2i.ZERO, t.get_size()))
	out.convert(Image.FORMAT_RGB8)
	return out


## The representations of chunk LOD level 0, 1, 2 as the props builder takes them (PropLibrary "reps"): the
## levels with a range in order, the impostor - or the coarsest level - far away. A bush without an impostor stays
## lod1 beyond the second switch, a rock with one level (automatic mesh LODs) stays lod0.
func _reps(mid: String) -> Array[String]:
	var m := ModelDB.model(mid)
	var levels: Array[String] = []
	for l: Variant in m.get("lods", []):
		var d: Dictionary = l
		if float(d.get("max_dist_m", 0.0)) > 0.0:
			levels.append(str(d.get("name", "")))
	if levels.is_empty():
		return ["lod0", "lod1", "impostor"]
	var far := "impostor" if m.has("impostor") else levels[mini(2, levels.size() - 1)]
	return [levels[0], levels[mini(1, levels.size() - 1)], far]


func _lods(models: Array) -> Image:
	var x := float(str(_args.get("x", "9")))
	var tile := _tile_size()
	# [chunk level, distance]: level 0 and 1 at the first switch, level 1 and 2 at the second
	var cols := [[0, _lod0_m], [1, _lod0_m], [1, _lod1_m], [2, _lod1_m]]
	if _args.has("sprite"):
		cols.append([-1, _lod1_m])
	var sheet := Image.create(tile.x * cols.size(), tile.y * models.size(), false, Image.FORMAT_RGB8)
	_clear()
	var bg := await _frame()              # the scene without a model (the same for every tile)
	for r in models.size():
		var mid := str(models[r])
		var reps := _reps(mid)
		var means: Array[String] = []
		var shots: Array = []
		for c in cols.size():
			var lvl := int(cols[c][0])
			var lod := "sprite" if lvl < 0 else reps[lvl]
			var d := float(cols[c][1])
			_clear()
			var pos := Vector3(x, 0.0, -d)
			var n := _place(mid, lod, pos)
			var img := await _frame()
			var rect := _screen_rect(mid, pos)
			shots.append([img, rect])
			var zoom := clampi(int(floor(minf(float(tile.x) / maxf(8.0, rect.size.x * 1.15), float(tile.y) / maxf(8.0, rect.size.y * 1.15)))), 1, 8)
			if n == null:
				means.append("%s fehlt" % lod)
			else:
				var mean_s: String = await _mean_in(img, rect)
				means.append("%s@%dm %s" % [lod, int(d), mean_s])
			var t := _crop(img, rect, tile, zoom)
			t = await _caption_tile(t, "%s · %s · %d m · %d×" % [mid, lod, int(d), zoom])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
		print("STUFEN %s  %s" % [mid, "  ".join(means)])
		var swaps: Array[String] = []
		swaps.append("lod0>lod1 @%d m: %s" % [int(_lod0_m), _swap(shots[0], shots[1], bg)])
		swaps.append("lod1>Fernbild @%d m: %s" % [int(_lod1_m), _swap(shots[2], shots[3], bg)])
		if shots.size() > 4:
			swaps.append("Fernbild>Sprite @%d m: %s" % [int(_lod1_m), _swap(shots[3], shots[4], bg)])
		print("UMSCHALT %s  %s" % [mid, "  ".join(swaps)])
	return sheet


## Mean colour (0..255) and covered pixel count of what differs from the background inside rect: the model's own
## pixels (measured against a frame without the model).
func _mean_in(img: Image, rect: Rect2) -> String:
	var hold := _holder.get_children()
	for c: Node in hold:
		(c as Node3D).visible = false
	var bg := await _frame()
	for c: Node in hold:
		(c as Node3D).visible = true
	var sum := Vector3.ZERO
	var n := 0
	var r := Rect2i(rect.grow(2.0)).intersection(Rect2i(Vector2i.ZERO, GAME))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var a := img.get_pixel(x, y)
			var b := bg.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.03:
				sum += Vector3(a.r, a.g, a.b)
				n += 1
	if n == 0:
		return "(0 px)"
	sum /= float(n)
	return "rgb(%d,%d,%d) %d px" % [int(sum.x * 255.0), int(sum.y * 255.0), int(sum.z * 255.0), n]


## A swap between two levels at the same place: [image, rect] before and after, bg = the scene without the model.
## Share of the model's pixels (union of both) whose colour changes, and the change of the mean colour's luma (%)
## and hue (degrees).
func _swap(a: Array, b: Array, bg: Image) -> String:
	var ia: Image = a[0]
	var ib: Image = b[0]
	var r := Rect2i((a[1] as Rect2).merge(b[1] as Rect2).grow(2.0)).intersection(Rect2i(Vector2i.ZERO, GAME))
	var union := 0
	var changed := 0
	var sa := Vector3.ZERO
	var sb := Vector3.ZERO
	var na := 0
	var nb := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ca := ia.get_pixel(x, y)
			var cb := ib.get_pixel(x, y)
			var cg := bg.get_pixel(x, y)
			var in_a := absf(ca.r - cg.r) + absf(ca.g - cg.g) + absf(ca.b - cg.b) > 0.03
			var in_b := absf(cb.r - cg.r) + absf(cb.g - cg.g) + absf(cb.b - cg.b) > 0.03
			if not (in_a or in_b):
				continue
			union += 1
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > SWAP_DIFF:
				changed += 1
			if in_a:
				sa += Vector3(ca.r, ca.g, ca.b)
				na += 1
			if in_b:
				sb += Vector3(cb.r, cb.g, cb.b)
				nb += 1
	if union == 0 or na == 0 or nb == 0:
		return "(keine Pixel)"
	# the same in 3x3 blocks (block means): what a swap changes in shape and colour, without the leaf-scale detail
	# that differs between any two levels pixel by pixel
	var bu := 0
	var bch := 0
	var by := r.position.y
	while by + 3 <= r.end.y:
		var bx := r.position.x
		while bx + 3 <= r.end.x:
			var ma := Vector3.ZERO
			var mb := Vector3.ZERO
			var model := false
			for y in range(by, by + 3):
				for x in range(bx, bx + 3):
					var ca := ia.get_pixel(x, y)
					var cb := ib.get_pixel(x, y)
					var cg := bg.get_pixel(x, y)
					ma += Vector3(ca.r, ca.g, ca.b)
					mb += Vector3(cb.r, cb.g, cb.b)
					if absf(ca.r - cg.r) + absf(ca.g - cg.g) + absf(ca.b - cg.b) > 0.03 \
							or absf(cb.r - cg.r) + absf(cb.g - cg.g) + absf(cb.b - cg.b) > 0.03:
						model = true
			if model:
				bu += 1
				var dd := (ma - mb).abs() / 9.0
				if dd.x + dd.y + dd.z > SWAP_DIFF:
					bch += 1
			bx += 3
		by += 3
	# brightness and hue from the INSIDE of each picture (pixels whose four neighbours are the model's as well):
	# the edge pixels of a thin model are mixed with the sky by the multisampling of the meshes, never by the
	# alpha-tested impostor - a bias of up to 25 % for a pine or a palm at 200 m (measured)
	var ia_in := _interior_mean(ia, bg, r)
	var ib_in := _interior_mean(ib, bg, r)
	if ia_in.w > 8.0 and ib_in.w > 8.0:
		sa = Vector3(ia_in.x, ia_in.y, ia_in.z) * float(na)
		sb = Vector3(ib_in.x, ib_in.y, ib_in.z) * float(nb)
	sa /= float(na)
	sb /= float(nb)
	var la := 0.2126 * sa.x + 0.7152 * sa.y + 0.0722 * sa.z
	var lb := 0.2126 * sb.x + 0.7152 * sb.y + 0.0722 * sb.z
	var ha := Color(sa.x, sa.y, sa.z).h * 360.0
	var hb := Color(sb.x, sb.y, sb.z).h * 360.0
	var dh := fposmod(hb - ha + 180.0, 360.0) - 180.0
	return "%.1f %% der Pixel / %.1f %% der 3x3-Blöcke geändert, Helligkeit %+.1f %%, Farbton %+.1f°, Pixel %d -> %d" % [
		100.0 * float(changed) / float(union), 100.0 * float(bch) / float(maxi(1, bu)), 100.0 * (lb - la) / maxf(0.001, la),
		dh, na, nb]


## Mean colour (xyz) and count (w) of the model's interior pixels inside rect: the pixel and its four neighbours
## differ from the background.
func _interior_mean(img: Image, bg: Image, r: Rect2i) -> Vector4:
	var sum := Vector3.ZERO
	var n := 0
	for y in range(maxi(1, r.position.y), mini(GAME.y - 1, r.end.y)):
		for x in range(maxi(1, r.position.x), mini(GAME.x - 1, r.end.x)):
			var inside := true
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c := img.get_pixel(x + o.x, y + o.y)
				var g := bg.get_pixel(x + o.x, y + o.y)
				if absf(c.r - g.r) + absf(c.g - g.g) + absf(c.b - g.b) <= 0.03:
					inside = false
					break
			if inside:
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	if n == 0:
		return Vector4(0.0, 0.0, 0.0, 0.0)
	sum /= float(n)
	return Vector4(sum.x, sum.y, sum.z, float(n))


func _road(models: Array) -> Image:
	_place_row(models)
	for c: Node in _holder.get_children():
		var h := c as Node3D
		var mid := str(h.get_meta(&"model", ""))
		for rep: Node in h.get_children():
			(rep as Node3D).visible = str(rep.get_meta(&"rep", "")) == _level_for(mid, h.position.length())
	var img := await _frame()
	return img


## Rows of models along both roadsides every --every m from 12 to 700 m (yaw and scale varied like the props builder
## does for vegetation). Every holder carries all levels of its model (meta "rep"); callers pick the visible one.
func _place_row(models: Array) -> void:
	var every := float(str(_args.get("every", "30")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var z := 12.0
	var i := 0
	var reach := float(str(_args.get("reach", "700")))
	while z < reach:
		for side: int in [-1, 1]:
			var mid := str(models[i % models.size()])
			i += 1
			var m := ModelDB.model(mid)
			var veg := ["tree", "plant"].has(str(m.get("kind", "")))
			var x := float(side) * rng.randf_range(7.0, 22.0)
			var pos := Vector3(x, 0.0, -z - rng.randf_range(0.0, every * 0.5))
			var yaw := rng.randf() * TAU if veg or str(m.get("kind", "")) == "rock" else 0.0
			var sc := rng.randf_range(0.85, 1.15) if veg else 1.0
			var mirror := side < 0 and (m.get("tags", []) as Array).has("mirror_left")
			var holder := Node3D.new()
			holder.position = pos
			holder.rotation.y = yaw
			holder.scale = Vector3(-sc if mirror else sc, sc, sc)
			holder.set_meta(&"model", mid)
			holder.set_meta(&"level", "")
			var reps: Array[String] = []
			for l: Variant in m.get("lods", []):
				var n := str((l as Dictionary).get("name", ""))
				if n != "show":
					reps.append(n)
			if m.has("impostor"):
				reps.append("impostor")
			for rep: String in reps:
				var node: Node3D
				if rep == "impostor":
					node = ModelFactory.build_impostor(mid, _mats)
				else:
					node = ModelFactory.build(mid, rep, _mats)
				if node == null:
					continue
				node.set_meta(&"rep", rep)
				node.visible = false
				holder.add_child(node)
			_holder.add_child(holder)
		z += every


## --mode=clip: the camera drives along the rows; every frame is written. Returns the number of frames.
func _clip(models: Array, out: String) -> int:
	_place_row(models)
	var kmh := float(str(_args.get("kmh", "120")))
	var secs := float(str(_args.get("secs", "2")))
	var fps := 60.0
	var t0 := float(str(_args.get("time", "1.7")))
	var frames := int(round(secs * fps))
	var prefix := out.get_basename()
	for f in frames:
		var cz := -kmh / 3.6 * float(f) / fps
		_cam.position = Vector3(0.0, CAM_H, cz)
		_race_update(t0 + float(f) / fps)
		for c: Node in _holder.get_children():
			var h := c as Node3D
			var d := maxf(0.0, cz - h.position.z)
			if h.position.z > cz:
				d = 0.0                     # behind the camera: keep the near level
			var mid := str(h.get_meta(&"model", ""))
			var old := str(h.get_meta(&"level", ""))
			var lv := _level_for(mid, d)
			# hysteresis of the props builder: a nearer level is kept LOD_HYSTERESIS_M longer
			if old != "" and old != lv and _level_for(mid, maxf(0.0, d - LOD_HYSTERESIS_M)) == old:
				lv = old
			if lv != old:
				h.set_meta(&"level", lv)
				for rep: Node in h.get_children():
					(rep as Node3D).visible = str(rep.get_meta(&"rep", "")) == lv
		var img := await _frame()
		img.save_png("%s_%03d.png" % [prefix, f])
	return frames
