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

const SHADER_DIR := "res://assets/shaders/modern/"
const CLASSES: Array[String] = ["vpbr", "glass", "baked", "baked_cutout", "leaves"]
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
	["ce_sun_color", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(1.0, 0.97, 0.9)],
	["ce_ambient", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.42, 0.46, 0.52)],
	["ce_tunnel", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	["ce_headlight_pos", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO],
	["ce_headlight_dir", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.0, 0.0, -1.0)],
	["ce_headlight", RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(60.0, 0.0)],
	["ce_far_y", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, -4.0],
]

static var _globals_added := false

var _shaders: Dictionary = {}        ## shader key -> Shader
var _materials: Dictionary = {}      ## material key -> ShaderMaterial


func _init() -> void:
	ensure_globals()


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
static func set_global(name: String, value: Variant) -> void:
	RenderingServer.global_shader_parameter_set(StringName(name), value)


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
	else:
		sh = load(SHADER_DIR + class_id + ".gdshader") as Shader
	if sh == null:
		push_error("ModernMaterials: Shader fehlt: " + class_id)
	_shaders[class_id] = sh
	return sh


## Material of a material class for a model (manifest entry). vpbr and glass are shared by all models
## (per-instance data travels as instance uniforms); baked, baked_cutout and leaves get one material per
## texture set of the model.
func material(class_id: String, model: Dictionary = {}) -> Material:
	var textures: Dictionary = model.get("textures", {})
	var key := class_id
	if class_id == "baked" or class_id == "baked_cutout":
		key += "|" + str(textures.get("albedo", "")) + "|" + str(textures.get("emit", "")) + "|" + str(model.get("roughness", 0.9))
	elif class_id == "leaves":
		key += "|" + str(textures.get("leaves", ""))
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = shader(class_id)
	if class_id == "baked" or class_id == "baked_cutout":
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
