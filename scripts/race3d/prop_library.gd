class_name PropLibrary
extends RefCounted
## Mode "Modern" (v0.8.0): what a prop set is for the props builder (scripts/race3d/builders/props.gd) – a model of
## ModelDB, the sprite stand-in (a billboard of the Arcade sprite cell) or nothing – and the meshes and materials
## that draw it. German docs: docs/renderer-modern-gelaende.md.
##
## Use (main thread):
##   lib.request(set_ids, owner)        resolves every set and starts loading: ModelDB.request() for the models
##                                      (all levels, textures, impostor), threaded loads of the sprite sheets
##   lib.pending()                      > 0 while files load; at 0 the library is ready (ready()): sets whose model
##                                      files are missing (ModelDB.missing) have become stand-ins
##   lib.fail_reason()                  "manifest" when ModelDB has no valid manifest, or a model's files are
##                                      missing and the set has no sprite to stand in
##   lib.sets / lib.models              PLAIN DATA for ChunkBuilder.build() on worker threads (never changed once ready)
##   lib.mesh_parts(model_id, rep)      mesh + material pairs of a model level (ModelFactory.multimesh_parts) or of
##                                      its impostor; lib.standin(set_id), lib.contact() likewise
##   lib.clear(owner)                   gives the models back (ModelDB.release_all(owner)) and drops everything
## sets[set_id] = {"kind": NONE | MODEL | SPRITE, "set", "variants": [model ids], "w", "h": size of the sprite cell in
##   metres, "ax", "ay": anchor inside the cell, "extent_l", "extent_r": metres from the anchor to the object's sides
##   (edge alignment), "mirror_left": mirrored on the left roadside, "width", "height": object size (m),
##   "cls": "tree" | "plant" | "rock" | "building" | "landmark" | "other", "veg": tree or plant, "blob": density of
##   its contact shadow (0 = none), "cast": lowest levels.shadow_casters at which it casts a real shadow}
## models[model_id] = {"reps": [representation at chunk LOD level 0, 1, 2] ("lod0" … | "impostor"), "caster": has a
##   low-poly shadow mesh, "lamps": [{"pos", "dir", "role", "color", "size", "range", "energy"}] (anchors with a
##   direction: street lights), "imp_w", "imp_h", "imp_ax": impostor quad}
## The sprite manifest is read from the SpriteDB autoload when the game runs (debug overlays apply) and from its file
## in tests without autoloads.
## Owner: package terrain / props / far ground.

enum { NONE, MODEL, SPRITE }

const SPRITE_MANIFEST := "res://assets/sprites/manifest.json"
const SPRITE_ROOT := "res://assets/sprites/"
const CONTACT_SHADER := "res://assets/shaders/modern/contact_shadow.gdshader"
const BILLBOARD_SHADER := "res://assets/shaders/modern/billboard.gdshader"
const IMPOSTOR := "impostor"
## Part of the sun a stand-in shows when the sun is behind it / behind the camera (billboard.gdshader sun_min,
## sun_max): the Arcade sprites carry baked light and shade, so they get more than an impostor (0.166 / 0.662).
const STANDIN_SUN := Vector2(0.42, 0.92)
const STANDIN_SHADOW_CUT := 0.97
## Light pool of a street light on the ground: Arcade's lamp pools (RoadRenderer._collect_static_lights).
const LAMP_RANGE_M := 9.0
const LAMP_ENERGY := 0.55

var sets: Dictionary = {}
var models: Dictionary = {}
var fallback_sets := 0             ## sets drawn as a sprite stand-in
var missing_files: Array[String] = []

var _mats: ModernMaterials
var _owner: WeakRef                ## a weak reference: the builder owns the library, not the other way round
var _sprite_sets: Dictionary = {}
var _have_sprites := false
var _model_sets: Array[String] = []
var _loading: Dictionary = {}      ## sprite sheet path -> set id (threaded loads)
var _textures: Dictionary = {}     ## set id -> Texture2D
var _ready := false
var _fail := ""
var _parts: Dictionary = {}
var _standins: Dictionary = {}
var _contact: Dictionary = {}


## Resolves the sets and starts loading their files. owner = whoever asks (ModelDB.request's owner).
func request(set_ids: Array, owner: Object) -> void:
	_owner = weakref(owner) if owner != null else null
	if not ModelDB.available():
		_fail = "manifest"
		return
	_load_sprite_manifest()
	var added: Array[String] = []
	for id: Variant in set_ids:
		var set_id := str(id)
		if set_id != "" and not sets.has(set_id) and not added.has(set_id):
			added.append(set_id)
	if added.is_empty() and _ready:
		return
	if _ready:
		# builds on worker threads may be reading the tables: add to copies, the old ones stay as they are
		sets = sets.duplicate()
		models = models.duplicate()
	_ready = false
	var new_models: Array[String] = []
	for set_id: String in added:
		var e := _resolve(set_id)
		sets[set_id] = e
		if int(e["kind"]) == MODEL:
			_model_sets.append(set_id)
			new_models.append(set_id)
		elif int(e["kind"]) == SPRITE:
			_request_sheet(set_id)
	if not new_models.is_empty():
		ModelDB.request(new_models, [], owner)


## Number of files still loading. When it reaches 0 the library becomes ready.
func pending() -> int:
	if _ready or _fail != "":
		return 0
	var n := ModelDB.pending() if not _model_sets.is_empty() else 0
	for path: String in _loading.keys():
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			n += 1
		else:
			var set_id := str(_loading[path])
			_loading.erase(path)
			_textures[set_id] = ResourceLoader.load_threaded_get(path) as Texture2D if st == ResourceLoader.THREAD_LOAD_LOADED else null
	if n == 0:
		_finish()
	return n


func ready() -> bool:
	return _ready


func fail_reason() -> String:
	return _fail


## Everything is loaded: models whose files are missing become stand-ins, sprites without a sheet become nothing.
func _finish() -> void:
	missing_files = ModelDB.missing(_model_sets) if not _model_sets.is_empty() else ([] as Array[String])
	if not missing_files.is_empty():
		for set_id: String in _model_sets:
			if ModelDB.missing([set_id]).is_empty():
				continue
			var e: Dictionary = sets[set_id]
			if _sprite_sets.has(set_id):
				e["kind"] = SPRITE
				e["variants"] = []
				_load_sheet_now(set_id)
			else:
				e["kind"] = NONE
				_fail = "manifest"
	fallback_sets = 0
	for set_id: String in sets:
		var e: Dictionary = sets[set_id]
		if int(e["kind"]) == SPRITE:
			if _textures.get(set_id) == null:
				e["kind"] = NONE      # no sheet: Arcade skips such a set as well
			else:
				fallback_sets += 1
	_ready = true


## Gives the models back and drops meshes, materials and textures.
func clear(owner: Object = null) -> void:
	for path: String in _loading.keys():
		ResourceLoader.load_threaded_get(path)
	_loading.clear()
	var who: Variant = owner
	if who == null and _owner != null:
		who = _owner.get_ref()
	if who is Object:
		ModelDB.release_all(who)
	sets = {}
	models = {}
	_textures.clear()
	_parts.clear()
	_standins.clear()
	_contact.clear()
	_model_sets.clear()
	_ready = false


# --- resolving ----------------------------------------------------------------------------------------------------

func _resolve(set_id: String) -> Dictionary:
	var r := ModelDB.resolve(set_id)
	var sp: Dictionary = _sprite_sets.get(set_id, {})
	var e := {"kind": NONE, "set": set_id, "variants": [], "w": 1.0, "h": 1.0, "ax": 0.5, "ay": 1.0, "extent_l": 0.5,
		"extent_r": 0.5, "mirror_left": false, "width": 1.0, "height": 1.0, "cls": "other", "veg": false, "blob": 0.0,
		"cast": 3}
	var tags: Array = sp.get("tags", [])
	var obj: Dictionary = sp.get("object", {})
	if not sp.is_empty():
		var cell: Array = sp.get("cell", [64, 64])
		var w := float(sp.get("image_width_m", 1.0))
		var anchor: Array = sp.get("anchor", [0.5, 1.0])
		e["w"] = w
		e["h"] = w * float(cell[1]) / maxf(1.0, float(cell[0]))
		e["ax"] = float(anchor[0])
		e["ay"] = float(anchor[1])
		e["width"] = float(obj.get("width_m", w * 0.8))
		e["height"] = float(obj.get("height_m", float(e["h"]) * 0.9))
		var half := float(e["width"]) * 0.5
		var ext: Array = sp.get("extent_m", [half, half])
		e["extent_l"] = float(ext[0]) if ext.size() >= 2 else half
		e["extent_r"] = float(ext[1]) if ext.size() >= 2 else half
	var model: Dictionary = r.get("model", {})
	if not model.is_empty():
		e["kind"] = MODEL
		tags = model.get("tags", tags)
		obj = model.get("object", obj)
		e["width"] = float(obj.get("width_m", e["width"]))
		e["height"] = float(obj.get("height_m", e["height"]))
		var ext: Dictionary = model.get("extent_m", {})
		e["extent_l"] = float(ext.get("left", e["extent_l"]))
		e["extent_r"] = float(ext.get("right", e["extent_r"]))
		var variants: Array = r.get("variants", [])
		if variants.is_empty():
			variants = [str(r.get("model_id", ""))]
		for mid: Variant in variants:
			_add_model(str(mid))
		e["variants"] = variants
		if str(model.get("kind", "")) != "":
			e["cls"] = _cls_of_kind(str(model["kind"]))
	elif not sp.is_empty() and str(r.get("fallback", "sprite")) == "sprite":
		e["kind"] = SPRITE
	e["mirror_left"] = tags.has("mirror_left")
	if str(e["cls"]) == "other":
		e["cls"] = _cls_of_tags(tags)
	e["veg"] = str(e["cls"]) == "tree" or str(e["cls"]) == "plant"
	match str(e["cls"]):
		"tree":
			e["blob"] = 1.0
			e["cast"] = 2
		"plant":
			e["blob"] = 0.8
		"rock":
			e["blob"] = 0.85
		"building":
			e["blob"] = 0.7
			e["cast"] = 2
		"other":
			e["blob"] = 0.85 if float(e["height"]) <= 6.0 and not tags.has("road") and not tags.has("bridge") and not tags.has("ship") and not tags.has("boat") else 0.0
	return e


static func _cls_of_kind(kind: String) -> String:
	match kind:
		"tree", "plant", "rock", "building", "landmark":
			return kind
	return "other"


static func _cls_of_tags(tags: Array) -> String:
	for c: String in ["landmark", "tree", "plant", "rock", "building"]:
		if tags.has(c):
			return c
	return "other"


## Plain data of a model: its representation per chunk LOD level, its caster, its lamps.
func _add_model(model_id: String) -> void:
	if models.has(model_id):
		return
	var m := ModelDB.model(model_id)
	var levels: Array[String] = []
	for l: Variant in m.get("lods", []):
		var d: Dictionary = l
		if float(d.get("max_dist_m", 0.0)) > 0.0:
			levels.append(str(d.get("name", "")))
	var imp: Dictionary = m.get("impostor", {})
	var reps: Array[String] = []
	if not levels.is_empty():
		var near := levels[0]
		var mid := levels[mini(1, levels.size() - 1)]
		var far := IMPOSTOR if not imp.is_empty() else levels[mini(2, levels.size() - 1)]
		reps = [near, mid, far]
	var lamps: Array = []
	for l: Variant in m.get("lights", []):
		var d: Dictionary = l
		var dir: Variant = d.get("dir")
		var pos: Variant = d.get("pos")
		if not (dir is Array) or (dir as Array).size() < 3 or not (pos is Array) or (pos as Array).size() < 3:
			continue      # baked lights (window panes of a house) live in the emission atlas
		lamps.append({"pos": Vector3(float(pos[0]), float(pos[1]), float(pos[2])),
			"dir": Vector3(float(dir[0]), float(dir[1]), float(dir[2])).normalized(), "role": str(d.get("role", "lights")),
			"color": Color(str(d.get("color", "#fff0cf"))), "size": float(d.get("size", 0.3)), "range": LAMP_RANGE_M,
			"energy": LAMP_ENERGY})
	var size: Array = imp.get("size_m", [1.0, 1.0])
	models[model_id] = {"reps": reps, "caster": m.has("shadow"), "lamps": lamps, "imp_w": float(size[0]) if size.size() >= 2 else 1.0,
		"imp_h": float(size[1]) if size.size() >= 2 else 1.0, "imp_ax": float(imp.get("anchor_x", 0.5))}


# --- sprite sheets --------------------------------------------------------------------------------------------------

func _load_sprite_manifest() -> void:
	if _have_sprites:
		return
	_have_sprites = true
	var db := _sprite_db()
	if db != null:
		_sprite_sets = db.get("sets")
		return
	var m: Variant = ConfigLoader.load_json(SPRITE_MANIFEST)
	if m is Dictionary and (m as Dictionary).get("sets") is Dictionary:
		_sprite_sets = (m as Dictionary)["sets"]


## The SpriteDB autoload, or null in tests without autoloads.
static func _sprite_db() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"SpriteDB")


func _sheet_path(set_id: String) -> String:
	var sp: Dictionary = _sprite_sets.get(set_id, {})
	return str(sp.get("root", SPRITE_ROOT)) + str(sp.get("file", ""))


func _request_sheet(set_id: String) -> void:
	var path := _sheet_path(set_id)
	if _textures.has(set_id) or _loading.has(path):
		return
	if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
		_loading[path] = set_id
	else:
		_load_sheet_now(set_id)


func _load_sheet_now(set_id: String) -> void:
	var path := _sheet_path(set_id)
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		# fixtures outside the import system: straight from the picture
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_textures[set_id] = tex


# --- meshes and materials (main thread, after ready()) --------------------------------------------------------------

func _materials() -> ModernMaterials:
	if _mats == null:
		_mats = ModernMaterials.shared()
	return _mats


## Parts of a model representation for MultiMesh nodes: [{"mesh": Mesh, "material": Material or null (the mesh
## carries its class materials), "transform": Transform3D, "shadow": bool (the low-poly caster), "billboard": bool}].
## rep = a level name ("lod0" …) or IMPOSTOR. [] when the level cannot be shown.
func mesh_parts(model_id: String, rep: String) -> Array:
	var key := model_id + "|" + rep
	if _parts.has(key):
		return _parts[key]
	var out: Array = []
	var md: Dictionary = models.get(model_id, {})
	if rep == IMPOSTOR:
		var m := ModelDB.model(model_id)
		var imp: Dictionary = m.get("impostor", {})
		var tex := ModelDB.texture(str(imp.get("texture", ""))) if not imp.is_empty() else null
		if tex != null:
			out.append({"mesh": ModelFactory.billboard_mesh(float(md.get("imp_w", 1.0)), float(md.get("imp_h", 1.0)), float(md.get("imp_ax", 0.5))),
				"material": _billboard(tex, Rect2(0.0, 0.0, 1.0, 1.0), Rect2()), "transform": Transform3D.IDENTITY, "shadow": false,
				"billboard": true})
	else:
		# ModelFactory resolves a SET; every model is reachable through a set of its own name or through this model id
		for p: Variant in _factory_parts(model_id, rep):
			var part: Dictionary = p
			out.append({"mesh": part["mesh"], "material": null, "transform": part.get("transform", Transform3D.IDENTITY),
				"shadow": bool(part.get("shadow", false)), "billboard": false})
	_parts[key] = out
	return out


## ModelFactory.multimesh_parts() for a model id: through the set that names the model (a variant model without a set
## of its own name is built from its manifest entry directly).
func _factory_parts(model_id: String, rep: String) -> Array:
	if str(ModelDB.resolve(model_id).get("model_id", "")) == model_id:
		return ModelFactory.multimesh_parts(model_id, rep, _materials())
	var out: Array = []
	var model := ModelDB.model(model_id)
	var entry := ModelDB.lod(model, rep)
	for p: Variant in entry.get("parts", []):
		var part: Dictionary = p
		var mesh := ModelFactory.surfaced_mesh(str(part.get("mesh", "")), part.get("classes", []), model, _materials())
		if mesh == null:
			return []
		out.append({"mesh": mesh, "transform": ModelFactory.part_transform(part), "shadow": false})
	if model.has("shadow") and not out.is_empty():
		var smesh := ModelFactory.surfaced_mesh(str((model["shadow"] as Dictionary).get("mesh", "")), ["vpbr"], model, _materials())
		if smesh == null:
			return []
		out.append({"mesh": smesh, "transform": Transform3D.IDENTITY, "shadow": true})
	return out


## Quad and material of a sprite stand-in: {"mesh", "material"}; {} when the set has no sheet.
func standin(set_id: String) -> Dictionary:
	if _standins.has(set_id):
		return _standins[set_id]
	var out := {}
	var e: Dictionary = sets.get(set_id, {})
	var tex: Texture2D = _textures.get(set_id)
	if tex != null and not e.is_empty():
		var sp: Dictionary = _sprite_sets.get(set_id, {})
		var layers: Array = sp.get("layers", ["base"])
		var angles: Array = sp.get("angles", ["c"])
		var cols := maxi(1, int(sp.get("grid_cols", angles.size())))
		var cells := maxi(1, layers.size() * angles.size())
		var rows := int(ceil(float(cells) / float(cols)))
		var cell := Vector2(1.0 / float(cols), 1.0 / float(rows))
		var ci := maxi(0, angles.find("c"))
		var base_rect := _cell_rect(layers.find("base"), ci, angles.size(), cols, cell)
		var lights_rect := _cell_rect(layers.find("lights"), ci, angles.size(), cols, cell)
		var mat := _billboard(tex, base_rect, lights_rect)
		mat.set_shader_parameter("sun_min", STANDIN_SUN.x)
		mat.set_shader_parameter("sun_max", STANDIN_SUN.y)
		mat.set_shader_parameter("shadow_cut", STANDIN_SHADOW_CUT)
		mat.set_shader_parameter("baked_light", 1.0)
		out = {"mesh": standin_mesh(float(e["w"]), float(e["h"]), float(e["ax"]), float(e["ay"])), "material": mat}
	_standins[set_id] = out
	return out


## A billboard material of this library's own (ModernMaterials.billboard() keeps its materials – and their sprite
## sheets – for the whole process; these go with the library).
func _billboard(tex: Texture2D, uv_rect: Rect2, lights_rect: Rect2) -> ShaderMaterial:
	ModernMaterials.ensure_globals()
	var mat := ShaderMaterial.new()
	mat.shader = load(BILLBOARD_SHADER) as Shader
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("uv_rect", Vector4(uv_rect.position.x, uv_rect.position.y, uv_rect.size.x, uv_rect.size.y))
	mat.set_shader_parameter("lights_rect", Vector4(lights_rect.position.x, lights_rect.position.y, lights_rect.size.x, lights_rect.size.y))
	return mat


static func _cell_rect(layer_row: int, angle_index: int, angle_count: int, cols: int, cell: Vector2) -> Rect2:
	if layer_row < 0:
		return Rect2()
	var i := layer_row * angle_count + angle_index
	return Rect2(float(i % cols) * cell.x, float(i / cols) * cell.y, cell.x, cell.y)


## Quad for billboard.gdshader showing a whole sprite cell: x = 0 is the anchor column, y = 0 the anchor row (the
## ground); the strip of the cell below the anchor reaches under the ground.
static func standin_mesh(width_m: float, height_m: float, anchor_x: float, anchor_y: float) -> ArrayMesh:
	var x0 := -anchor_x * width_m
	var x1 := (1.0 - anchor_x) * width_m
	var y0 := -(1.0 - anchor_y) * height_m
	var y1 := anchor_y * height_m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x0, y0, 0.0), Vector3(x1, y0, 0.0), Vector3(x1, y1, 0.0), Vector3(x0, y1, 0.0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var r := maxf(absf(x0), absf(x1))
	mesh.custom_aabb = AABB(Vector3(-r, y0, -r), Vector3(2.0 * r, y1 - y0, 2.0 * r))
	return mesh


## Quad and material of the contact shadows: {"mesh", "material"}.
func contact() -> Dictionary:
	if not _contact.is_empty():
		return _contact
	ModernMaterials.ensure_globals()
	var mat := ShaderMaterial.new()
	mat.shader = load(CONTACT_SHADER) as Shader
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1.0, 0.0, -1.0), Vector3(1.0, 0.0, -1.0), Vector3(1.0, 0.0, 1.0), Vector3(-1.0, 0.0, 1.0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# the shader stretches the patch away from the sun: bounds for the longest shadow in every direction
	mesh.custom_aabb = AABB(Vector3(-6.0, -1.0, -6.0), Vector3(12.0, 2.0, 12.0))
	_contact = {"mesh": mesh, "material": mat}
	return _contact
