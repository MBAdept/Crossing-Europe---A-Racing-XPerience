class_name ModelDB
extends RefCounted
## Real-time models of the graphics mode "Modern" (docs/modelle.md). Static and lazy - NOT an autoload: the
## Arcade mode never touches it and pays nothing.
##
## Manifest res://assets/models/manifest.json (generated: tools/blender/export_models.py --manifest-only):
##   models  {"<group>/<name>": {kind, object, extent_m, aabb, lods: [{name, max_dist_m, tris, parts: [{node,
##           mesh, classes, pos, yaw_deg, wheel}]}], shadow, lights, paint, textures, roughness, impostor,
##           auto_lod, tags, bytes, hash}}
##   sets    {"<sprite set id>": {"model": id, "paint": {...}, "lod": "show", "showroom": bool, "variants": [...]}
##           or {"fallback": "sprite" | "box", "object": {...}, "paint": {...}}}
## Every sprite set except ui/* has a sets entry, so every stage can be drawn in Modern: a model, a billboard
## of the Arcade sprite ("sprite") or a box in the vehicle's colour ("box").
## Paths in the manifest are relative to the folder of the manifest (ROOT for the shipped one).

const ROOT := "res://assets/models/"
const MANIFEST := "manifest.json"
const FALLBACKS: Array[String] = ["sprite", "box"]

static var _loaded := false
static var _ok := false
static var _root := ROOT
static var _models: Dictionary = {}
static var _sets: Dictionary = {}
static var _meshes: Dictionary = {}       ## rel path -> ArrayMesh
static var _textures: Dictionary = {}     ## rel path -> Texture2D
static var _pending: Dictionary = {}      ## rel path -> true while a threaded load runs
## Diagnostics: files loaded since the last release_all() (tests: nothing is loaded while driving).
static var loads := 0


## True when the manifest is present and valid.
static func available() -> bool:
	_ensure()
	return _ok


## (Re)loads a manifest; "" = the shipped one. Tests load fixtures: mesh and texture paths are then relative
## to the folder of that manifest. Returns false (and resolves nothing) if it is missing or invalid.
## (Not called "reload": on a class name GDScript resolves that to Script.reload(keep_state) of the script
## resource - ModelDB.reload("...") from another script would never reach a static function of that name.)
static func load_manifest(manifest_path: String = "") -> bool:
	release_all()
	_loaded = true
	_ok = false
	_models = {}
	_sets = {}
	var path := manifest_path if manifest_path != "" else ROOT + MANIFEST
	_root = path.get_base_dir() + "/"
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return false
	var d: Dictionary = data
	if int(d.get("version", 0)) != 1 or not d.get("models") is Dictionary or not d.get("sets") is Dictionary:
		return false
	_models = d["models"]
	_sets = d["sets"]
	_ok = true
	return true


static func _ensure() -> void:
	if not _loaded:
		load_manifest()


## All model ids / all set ids of the manifest (sorted).
static func model_ids() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for k: String in _models:
		out.append(k)
	out.sort()
	return out


static func set_ids() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for k: String in _sets:
		out.append(k)
	out.sort()
	return out


## Model entry of the manifest by model id ({} = unknown).
static func model(model_id: String) -> Dictionary:
	_ensure()
	return _models.get(model_id, {})


## What a sprite set is in Modern. {} = unknown set (or no valid manifest). Otherwise:
##   "set"       the set id
##   "model_id"  model id ("" for a stand-in)        "model"     its manifest entry ({} for a stand-in)
##   "fallback"  "" | "sprite" | "box"               "lod"       forced level ("" = by distance; "show")
##   "paint"     {"paint": "#rrggbb", "paint2", "paint3", "metal"} - the set's over the model's default
##   "object"    {"width_m", "length_m", "height_m"}  "showroom"  true = good enough for the 3D showroom
##   "variants"  model ids to pick from (stable hash of segment and prop index); [model_id] by default
static func resolve(set_id: String) -> Dictionary:
	_ensure()
	if not _ok or not _sets.has(set_id):
		return {}
	var s: Dictionary = _sets[set_id]
	var out := {"set": set_id, "model_id": "", "model": {}, "fallback": "", "lod": str(s.get("lod", "")),
		"paint": {}, "object": s.get("object", {}), "showroom": bool(s.get("showroom", false)), "variants": []}
	var mid := str(s.get("model", ""))
	if mid != "" and _models.has(mid):
		var m: Dictionary = _models[mid]
		out["model_id"] = mid
		out["model"] = m
		out["object"] = m.get("object", {})
		var paint: Dictionary = (m.get("paint", {}) as Dictionary).duplicate()
		paint.merge(s.get("paint", {}), true)
		out["paint"] = paint
		var variants: Array = []
		for v: Variant in s.get("variants", [mid]):
			if _models.has(str(v)):
				variants.append(str(v))
		out["variants"] = variants
	else:
		var fb := str(s.get("fallback", "sprite"))
		out["fallback"] = fb if FALLBACKS.has(fb) else "sprite"
		out["paint"] = s.get("paint", {})
	return out


## True when the set resolves to a model (not to a stand-in).
static func has_model(set_id: String) -> bool:
	return not (resolve(set_id).get("model", {}) as Dictionary).is_empty()


## Physical size {"width_m", "length_m", "height_m"} (may be partial) - equal to the sprite manifest.
static func object_size(set_id: String) -> Dictionary:
	return resolve(set_id).get("object", {})


## LOD entry of a model by name ({} = the model has no such level).
static func lod(model_entry: Dictionary, lod_name: String) -> Dictionary:
	for l: Variant in model_entry.get("lods", []):
		if str((l as Dictionary).get("name", "")) == lod_name:
			return l
	return {}


## Name of the level a renderer shows at a distance: the first level whose max_dist_m (scaled) is not
## exceeded; levels with max_dist_m 0 ("show") are never picked by distance.
static func lod_for_distance(model_entry: Dictionary, dist_m: float, dist_scale: float = 1.0) -> String:
	var last := ""
	for l: Variant in model_entry.get("lods", []):
		var d: Dictionary = l
		var mx := float(d.get("max_dist_m", 0.0))
		if mx <= 0.0:
			continue
		last = str(d.get("name", ""))
		if dist_m <= mx * dist_scale:
			return last
	return last


## Cached mesh by its manifest path (null if missing).
static func mesh(rel_path: String) -> ArrayMesh:
	if _meshes.has(rel_path):
		return _meshes[rel_path]
	var m := _take(rel_path) as ArrayMesh
	_meshes[rel_path] = m
	return m


## Cached texture by its manifest path (null if missing).
static func texture(rel_path: String) -> Texture2D:
	if _textures.has(rel_path):
		return _textures[rel_path]
	var t := _take(rel_path) as Texture2D
	_textures[rel_path] = t
	return t


static func _take(rel_path: String) -> Resource:
	var path := _root + rel_path
	var res: Resource = null
	if _pending.has(rel_path):
		_pending.erase(rel_path)
		res = ResourceLoader.load_threaded_get(path)      # waits if the load is still running
	elif ResourceLoader.exists(path):
		res = load(path)
	elif FileAccess.file_exists(path) and (rel_path.ends_with(".png") or rel_path.ends_with(".webp")):
		# fixtures outside the import system: straight from the image file
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			res = ImageTexture.create_from_image(img)
	if res == null:
		push_warning("ModelDB: Datei fehlt: " + path)
	else:
		loads += 1
	return res


## Files (manifest paths) of a model: meshes of the given levels ([] = all levels and the shadow caster)
## and all its textures.
static func files_of(model_id: String, lods: Array = []) -> Array[String]:
	var out: Array[String] = []
	var m := model(model_id)
	for l: Variant in m.get("lods", []):
		var d: Dictionary = l
		if not lods.is_empty() and not lods.has(str(d.get("name", ""))):
			continue
		for p: Variant in d.get("parts", []):
			var f := str((p as Dictionary).get("mesh", ""))
			if f != "" and not out.has(f):
				out.append(f)
	if m.has("shadow") and (lods.is_empty() or lods.has("shadow")):
		var sf := str((m["shadow"] as Dictionary).get("mesh", ""))
		if sf != "" and not out.has(sf):
			out.append(sf)
	for k: String in m.get("textures", {}):
		out.append(str(m["textures"][k]))
	if m.has("impostor"):
		var it := str((m["impostor"] as Dictionary).get("texture", ""))
		if it != "" and not out.has(it):
			out.append(it)
	return out


## Starts threaded loads of every file the sets need (models incl. their variants); lods = level names to
## load ([] = all). Poll pending() until it is 0; mesh() / texture() then return at once.
static func request(set_ids: Array, lods: Array = []) -> void:
	_ensure()
	for sid: Variant in set_ids:
		var r := resolve(str(sid))
		var want: Array = lods
		if str(r.get("lod", "")) != "" and not lods.is_empty() and not lods.has(str(r["lod"])):
			want = lods + [str(r["lod"])]
		for mid: Variant in r.get("variants", []):
			for f: String in files_of(str(mid), want):
				if _meshes.has(f) or _textures.has(f) or _pending.has(f):
					continue
				var path := _root + f
				if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
					_pending[f] = true


## Number of requested files that are still loading (0 = everything requested is loaded).
static func pending() -> int:
	var n := 0
	for f: String in _pending.keys():
		var st := ResourceLoader.load_threaded_get_status(_root + f)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			n += 1
		else:
			# finished (or failed): move it into the cache
			if f.ends_with(".res"):
				mesh(f)
			else:
				texture(f)
	return n


## Drops the mesh and texture caches (leaving Modern). The manifest stays loaded.
static func release_all() -> void:
	for f: String in _pending.keys():
		ResourceLoader.load_threaded_get(_root + f)       # finish running loads before dropping them
	_pending.clear()
	_meshes.clear()
	_textures.clear()
	loads = 0
