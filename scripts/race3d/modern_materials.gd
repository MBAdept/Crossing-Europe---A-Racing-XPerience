class_name ModernMaterials
extends RefCounted
## Materials of the mode "Modern": one shared ShaderMaterial per material class (vpbr, glass), one per
## texture set for the textured classes (baked, baked_cutout, leaves) and billboards (docs/modelle.md).
##
## Whoever shows a Modern shader (renderer, showroom, contact sheet, tests) creates the materials through an
## instance of this class: it first registers the ce_* global shader uniforms at runtime - nothing is
## declared in project.godot, so the Arcade mode stays untouched - and only then loads the shaders with
## load(). Never preload() a Modern shader. The values of the globals are set by the owner of the scene
## (EnvironmentRig in a race; the showroom and the contact sheet bring their own small rig).
##
## ONE instance per process: ModelFactory sets the class materials on the shared mesh resources of ModelDB, so
## two instances would overwrite each other (a car built with the first draws with the materials of the second –
## its class parameters, e.g. lamp energies, then come from the wrong one). The game uses shared(); tools and
## tests that run alone may create their own.
## The materials hold the textures of the baked and leaf classes: leaving the mode "Modern" means
## ModelDB.release_all() AND clear() here (or drop_shared()) – release_all() alone frees no texture memory.

const SHADER_DIR := "res://assets/shaders/modern/"
const CLASSES: Array[String] = ["vpbr", "glass", "baked", "baked_cutout", "leaves"]
## M2INT: the class "vpbr" for STATIC geometry (props, buildings, trees, street furniture – every model that is not a
## vehicle): the same shader with its instance uniforms (paint, lamps, fade, sun, fill, gloss, xfade) turned into plain
## uniforms with the same defaults. Static nodes never set them, but every geometry instance whose material HAS
## instance uniforms takes 16 slots of Godot's global shader buffer (4096 slots on llvmpipe and most desktop drivers,
## tests/race3d/render/check_instance_budget.gd): with the trees of AS3R (a vpbr trunk in every tree model) the props
## of a forest stage at "Hoch" pushed the scene past it – "Too many instances using shader instance variables" at
## T1, T4 and Dortmund – Frankfurt km 121, the refused instances drawn with another one's values. The material is
## kept under the key "vpbr|static", so set_class_parameter("vpbr", …) and apply_look() reach it as before.
const VPBR_STATIC := "vpbr_static"
## R4: the reflections of lamps on the wet road (layer "flares"): flare.gdshader compiled with CE_STREAK.
const FLARE_STREAK := "flare_streak"
## Global uniforms (contract 4.5.6): name, RenderingServer type, default.
const GLOBALS: Array = [
	["ce_night", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	["ce_wet", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	["ce_snow", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	["ce_time", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	["ce_wind", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(1.0, 0.0, 0.3, 0.0)],
	["ce_fog_color", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.75, 0.8, 0.85)],
	["ce_fog_range", RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(400.0, 900.0)],
	["ce_sun_dir", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.4, 0.8, 0.45)],
	["ce_sun_color", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(1.0, 0.93, 0.79)],     # light_value(): linear
	["ce_ambient", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.15, 0.18, 0.23)],
	# RINT-B: Arcade's ambient factor as DISPLAY values (palette.ambient, blended with the tunnel's) – ground shaders
	# show albedo × this on level ground exactly (EnvironmentRig "Bodengesetz", docs/renderer-modern.md §13)
	["ce_ambient_display", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(1.0, 1.0, 1.0)],
	["ce_tunnel", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	["ce_headlight_pos", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO],
	["ce_headlight_dir", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.0, 0.0, -1.0)],
	["ce_headlight", RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(60.0, 0.0)],
	["ce_far_y", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, -4.0],
	# R4: the palette's sky as DISPLAY values (zenith and horizon, blended to the tunnel's darkness) – what wet ground
	# mirrors (road.gdshader); set by the environment rig
	["ce_sky_top", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.11, 0.36, 0.79)],
	["ce_sky_horizon", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.73, 0.87, 0.96)],
]

## The vehicle LOOK in one place (A-13): the class parameters a scene puts on the shared vehicle materials – [class,
## uniform, value]. The shaders' defaults are neutral (the look of the vertex format alone, what the contact sheet's
## --look=neutral shows). Read by the vehicle layer (race), the showroom and the contact sheet / prop scene tools;
## the far-level albedo constants of the models (traffic3d TRAFFIC_GLASS_FAR, FAR_PLATE, truck3d GLASS_FAR,
## police3d CHECK_MEAN_EXP) are measured against VEHICLE_LOOK – re-measure them when it changes (docs/modelle.md 17).
## RINT-B: unlit vehicle lamps at 0.28 of their lit colour (0.5 read as switched on by day – art review B1), the tail
## light of a combined tail/brake lamp (channel 2) at half the lamp (brake stays more than twice as bright); paint
## exposure (art review A1/B8/C2): a soft knee above 0.7 of the brightest channel (slope 0.45) and 8 % desaturation
## instead of a flat 0.9 on every paint – bright paints no longer clip, mid ones keep their value (measured against the
## sprites, docs/renderer-modern.md §13.4); at night the mirrored palette sky at 0.35 and the player's fill at 0.3 of
## their day values (the metallic player car was +44 % against its sprite at 22:00).
## M2INT (art review KRITIK-2 A4: 83 sparkling pixels per frame on the GT at race distance): no metallic flakes in the
## race – a flake cell (1/260 m) is 0.3 px wide at the player car's 9 m and only shimmers; the showroom keeps them.
const VEHICLE_LOOK: Array = [["vpbr", "env_energy", 1.6], ["vpbr", "paint_base", 1.0], ["vpbr", "paint_knee", 0.7],
	["vpbr", "paint_knee_slope", 0.45], ["vpbr", "paint_desat", 0.08], ["vpbr", "flake_strength", 0.0],
	["vpbr", "lamp_off", 0.28], ["vpbr", "tail_level", 0.5], ["vpbr", "env_night", 0.35], ["vpbr", "fill_night", 0.3],
	["glass", "env_energy", 2.2]]
## Extra ambient light on the player car in a race (vpbr instance uniform fill, a share of ce_ambient): Arcade draws its
## player sprite brighter than the scene (ambient x 1.15 + 0.08) – the car stays readable in its own shade.
const VEHICLE_PLAYER_FILL := 0.7
## The studio look of the showroom (RINT-B): the engine's reflection of the studio sky (env_energy 0) and the same paint
## exposure and lamp levels as the race; the flakes sparkle at the showroom's distance.
const STUDIO_LOOK: Array = [["vpbr", "env_energy", 0.0], ["vpbr", "paint_base", 1.0], ["vpbr", "paint_knee", 0.7],
	["vpbr", "paint_knee_slope", 0.45], ["vpbr", "paint_desat", 0.08], ["vpbr", "flake_strength", 0.6],
	["vpbr", "lamp_off", 0.28], ["vpbr", "tail_level", 0.5], ["glass", "env_energy", 0.0]]

static var _globals_added := false
static var _shared: ModernMaterials = null

var _shaders: Dictionary = {}        ## shader key -> Shader
var _materials: Dictionary = {}      ## material key -> ShaderMaterial


func _init() -> void:
	ensure_globals()


## The instance of the running game (renderer, showroom, Leistungstest): created on first use.
static func shared() -> ModernMaterials:
	if _shared == null:
		_shared = ModernMaterials.new()
	return _shared


## Clears and forgets the shared instance (leaving the mode "Modern", after ModelDB.release_all()).
static func drop_shared() -> void:
	if _shared != null:
		_shared.clear()
		_shared = null


## Registers the ce_* globals once per process (idempotent; headless the dummy renderer ignores it).
## The RenderingServer cannot be asked which globals exist outside the editor (global_shader_parameter_
## get_list / _get raise an error in a running game), so the state is kept here: nothing else may add them.
static func ensure_globals() -> void:
	if _globals_added:
		return
	_globals_added = true
	for g: Array in GLOBALS:
		RenderingServer.global_shader_parameter_add(StringName(str(g[0])), g[1], g[2])


## Sets a ce_* global (convenience for small rigs; EnvironmentRig may call the RenderingServer directly).
## Registers the globals first if nobody has yet (setting an unknown global is an engine error).
static func set_global(name: String, value: Variant) -> void:
	ensure_globals()
	RenderingServer.global_shader_parameter_set(StringName(name), value)


## Value of ce_sun_color / ce_ambient for a light colour (as picked: sRGB) and its energy: the linear
## colour times the energy - what the renderer itself multiplies a linear albedo with for a
## DirectionalLight3D (light_color, light_energy) and for Environment.ambient_light_color / _energy.
## Shaders that imitate lit surfaces (billboards, far ground) need exactly that; keep every rig on this
## one definition.
static func light_value(color: Color, energy: float) -> Color:
	var c := color.srgb_to_linear()
	return Color(c.r * energy, c.g * energy, c.b * energy)


## Shader of a class: "vpbr", "glass", "baked", "baked_cutout", "leaves", "billboard".
func shader(class_id: String) -> Shader:
	if _shaders.has(class_id):
		return _shaders[class_id]
	var sh: Shader = null
	if class_id == "baked_cutout":
		# same source as "baked", compiled with the cut-out branch
		var base := shader("baked")
		if base != null:
			sh = Shader.new()
			sh.code = base.code.replace("shader_type spatial;", "shader_type spatial;\n#define CE_CUTOUT")
	elif class_id == VPBR_STATIC:
		var vb := shader("vpbr")
		if vb != null:
			sh = Shader.new()
			sh.code = static_code(vb.code)
	elif class_id == FLARE_STREAK:
		# R4: the reflection of a lamp on the wet road – same source as "flare", compiled with the streak branch
		var fl := shader("flare")
		if fl != null:
			sh = Shader.new()
			sh.code = fl.code.replace("shader_type spatial;", "shader_type spatial;\n#define CE_STREAK")
	else:
		sh = load(SHADER_DIR + class_id + ".gdshader") as Shader
	if sh == null:
		push_error("ModernMaterials: Shader fehlt: " + class_id)
	_shaders[class_id] = sh
	return sh


## Source of VPBR_STATIC from the source of vpbr: every "instance uniform … instance_index(n) = default" becomes a
## plain "uniform … = default" (the hint list loses its instance_index; the defaults stay). Comments too lose the
## words "instance uniform", so a look at the code (check_instance_budget.gd) sees none.
static func static_code(code: String) -> String:
	var rx := RegEx.create_from_string("(,\\s*|\\s*:\\s*)instance_index\\(\\s*\\d+\\s*\\)")
	return rx.sub(code, "", true).replace("instance uniform", "uniform")


## Material class a model's surface of class `cls` draws with: VPBR_STATIC for "vpbr" on every model that is not a
## vehicle (manifest kind "vehicle" or "heavy": paint, lamps, fade, sun, fill and the level cross-fade are per car).
static func class_for(cls: String, model: Dictionary) -> String:
	if cls == "vpbr" and not model.is_empty() and not (str(model.get("kind", "")) in ["vehicle", "heavy"]):
		return VPBR_STATIC
	return cls


## Material of a material class for a model (manifest entry). vpbr and glass are shared by all models
## (per-instance data travels as instance uniforms); baked, baked_cutout and leaves get one material per
## texture set of the model.
func material(class_id: String, model: Dictionary = {}) -> Material:
	var textures: Dictionary = model.get("textures", {})
	var key := class_id
	if class_id == VPBR_STATIC:
		key = "vpbr|static"
	elif class_id == "baked" or class_id == "baked_cutout":
		key += "|" + str(textures.get("albedo", "")) + "|" + str(textures.get("emit", "")) + "|" + str(model.get("roughness", 0.9))
	elif class_id == "leaves":
		key += "|" + str(textures.get("leaves", ""))
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = shader(class_id)
	if class_id == VPBR_STATIC:
		# the class parameters the scene has already put on "vpbr" (look, lamp energies, coat_sun …)
		var vm := material("vpbr") as ShaderMaterial
		for u: Dictionary in vm.shader.get_shader_uniform_list():
			var v: Variant = vm.get_shader_parameter(StringName(str(u["name"])))
			if v != null:
				mat.set_shader_parameter(StringName(str(u["name"])), v)
	elif class_id == "baked" or class_id == "baked_cutout":
		if textures.has("albedo"):
			mat.set_shader_parameter("albedo_tex", ModelDB.texture(str(textures["albedo"])))
		if textures.has("emit"):
			mat.set_shader_parameter("emit_tex", ModelDB.texture(str(textures["emit"])))
		mat.set_shader_parameter("roughness", float(model.get("roughness", 0.9)))
	elif class_id == "leaves":
		if textures.has("leaves"):
			mat.set_shader_parameter("leaf_tex", ModelDB.texture(str(textures["leaves"])))
	_materials[key] = mat
	return mat


## Billboard material for a texture: impostors (whole texture) or a sprite cell (uv_rect in 0..1, optional
## cell of the light layer).
func billboard(tex: Texture2D, uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0), lights_rect: Rect2 = Rect2()) -> ShaderMaterial:
	var key := "billboard|%d|%s|%s" % [tex.get_instance_id() if tex != null else 0, str(uv_rect), str(lights_rect)]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = shader("billboard")
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("uv_rect", Vector4(uv_rect.position.x, uv_rect.position.y, uv_rect.size.x, uv_rect.size.y))
	mat.set_shader_parameter("lights_rect", Vector4(lights_rect.position.x, lights_rect.position.y, lights_rect.size.x, lights_rect.size.y))
	_materials[key] = mat
	return mat


## Sets a uniform on the shared material of a class (lamp energies, sway ...), e.g. per quality level.
## Puts a look (VEHICLE_LOOK, STUDIO_LOOK or a tool's own list of [class, uniform, value]) on the class materials,
## creating each class material first (set_class_parameter reaches only materials that exist – art review C2).
func apply_look(look: Array) -> void:
	for l: Variant in look:
		var e: Array = l
		material(str(e[0]))
		set_class_parameter(str(e[0]), str(e[1]), e[2])


func set_class_parameter(class_id: String, param: String, value: Variant) -> void:
	for key: String in _materials:
		if key == class_id or key.begins_with(class_id + "|"):
			(_materials[key] as ShaderMaterial).set_shader_parameter(param, value)


## All materials created so far (shader warm-up lists).
func all_materials() -> Array:
	return _materials.values()


## Drops the materials (leaving Modern). The registered globals stay - they cost nothing.
func clear() -> void:
	_materials.clear()
	_shaders.clear()
