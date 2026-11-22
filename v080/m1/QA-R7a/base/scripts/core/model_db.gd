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
##
## Who drops the caches: leaving the mode "Modern" (the mode switch) calls release_all() AND
## ModernMaterials.clear() – the materials hold the textures, so release_all() alone frees no texture memory
## (measured: 13.60 MB stay until the materials go, then 9.01 MB as before). The end of a stage is NOT "leaving
## Modern": GameFlow adds the next stage before the last one has left the tree, and an unconditional release at
## that moment would take the new stage's requests along (pending() says 0, the files then load synchronously on
## first use). A renderer that wants to give its share back passes itself: request(sets, lods, self) and
## release_all(self) – the caches then only go when no other owner is left.

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
static var _owners: Dictionary = {}       ## instance id -> true: who requested files with an owner (request)
## Diagnostics: files loaded since the last release_all() (tests: nothing is loaded while driving).
static var loads := 0
## A file that cannot be loaded is reported with push_warning (tests of exactly that switch it off).
static var warn_missing := true


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
	var version: Variant = d.get("version", 0)
	if not (version is float or version is int) or int(version) != 1:
		return false
	if not d.get("models") is Dictionary or not d.get("sets") is Dictionary or not _well_formed(d["models"], d["sets"]):
		return false
	# a test manifest may name the folder its mesh and texture paths are relative to ("root": "res://assets/models/"):
	# the shipped models with a changed set table (tests/race3d/check_vehicles.gd "kasten"); the generator never
	# writes the key
	var root_dir: Variant = d.get("root", "")
	if root_dir is String and (root_dir as String).begins_with("res://"):
		_root = (root_dir as String).trim_suffix("/") + "/"
	_models = d["models"]
	_sets = d["sets"]
	_ok = true
	return true


## True when every entry has the shape the functions below read without checking again: a manifest whose
## entries have the wrong type (a set that is a string, "lods" that is no list of dictionaries) counts as
## invalid as a whole – resolve(), lod() and files_of() would raise script errors on it otherwise.
static func _well_formed(models: Dictionary, sets: Dictionary) -> bool:
	for sid: Variant in sets:
		var s: Variant = sets[sid]
		if not s is Dictionary:
			return false
		var sd: Dictionary = s
		if not _is_of(sd, "paint", TYPE_DICTIONARY) or not _is_of(sd, "object", TYPE_DICTIONARY) \
				or not _is_of(sd, "variants", TYPE_ARRAY):
			return false
	for mid: Variant in models:
		var m: Variant = models[mid]
		if not m is Dictionary:
			return false
		var md: Dictionary = m
		for key: String in ["object", "paint", "textures", "shadow", "impostor", "extent_m"]:
			if not _is_of(md, key, TYPE_DICTIONARY):
				return false
		for key: String in ["lods", "lights", "tags", "aabb"]:
			if not _is_of(md, key, TYPE_ARRAY):
				return false
		for l: Variant in md.get("lods", []):
			if not l is Dictionary or not _is_of(l, "parts", TYPE_ARRAY):
				return false
			for p: Variant in (l as Dictionary).get("parts", []):
				if not p is Dictionary:
					return false
		for l: Variant in md.get("lights", []):
			if not l is Dictionary:
				return false
	return true


## True when `d` has no `key` or its value is of `type`.
static func _is_of(d: Dictionary, key: String, type: int) -> bool:
	return not d.has(key) or typeof(d[key]) == type


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
## exceeded; levels with max_dist_m 0 ("show") are never picked by distance. Beyond the last mesh level:
## IMPOSTOR ("impostor") when the model has one (card trees: ModelFactory.build_impostor), else the last mesh
## level stays.
const IMPOSTOR := "impostor"

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
	return IMPOSTOR if model_entry.has("impostor") and last != "" else last


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
		if warn_missing:
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
## load ([] = all). Poll pending() until it is 0; mesh() / texture() then return at once – missing() then names
## what could not be loaded. owner: whoever asks (a renderer, the showroom) – see release_all(owner).
static func request(set_ids: Array, lods: Array = [], owner: Object = null) -> void:
	_ensure()
	if owner != null:
		_owners[owner.get_instance_id()] = true
	for sid: Variant in set_ids:
		for f: String in _files_of_set(str(sid), lods):
			if _meshes.has(f) or _textures.has(f) or _pending.has(f):
				continue
			var path := _root + f
			if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
				_pending[f] = true


## Files (manifest paths) the models of a set need at the given levels ([] = all), its variants included; a set
## with a level of its own ("show") gets that level as well.
static func _files_of_set(set_id: String, lods: Array) -> Array[String]:
	var out: Array[String] = []
	var r := resolve(set_id)
	var want: Array = lods
	if str(r.get("lod", "")) != "" and not lods.is_empty() and not lods.has(str(r["lod"])):
		want = lods + [str(r["lod"])]
	for mid: Variant in r.get("variants", []):
		for f: String in files_of(str(mid), want):
			if not out.has(f):
				out.append(f)
	return out


## Files (manifest paths) of the sets' models that cannot be used: not there, or there but not loadable (a
## truncated or foreign file – known once it was loaded: after request() and pending() == 0, or after mesh() /
## texture()). The renderer's prepare() asks this after loading: anything missing = fail reason "manifest", the
## stage starts in Arcade. Loads nothing itself.
static func missing(set_ids: Array, lods: Array = []) -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for sid: Variant in set_ids:
		for f: String in _files_of_set(str(sid), lods):
			if out.has(f):
				continue
			var failed := (_meshes.has(f) and _meshes[f] == null) or (_textures.has(f) and _textures[f] == null)
			if failed or not (_pending.has(f) or _meshes.has(f) or _textures.has(f) or _exists(f)):
				out.append(f)
	out.sort()
	return out


## True when a file of the manifest is there (imported resource, or a raw picture next to a fixture manifest).
static func _exists(rel_path: String) -> bool:
	var path := _root + rel_path
	return ResourceLoader.exists(path) or (FileAccess.file_exists(path) and (rel_path.ends_with(".png") or rel_path.ends_with(".webp")))


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


## Drops the mesh and texture caches. The manifest stays loaded.
## Without an owner: unconditionally – for the mode switch that leaves "Modern" (together with
## ModernMaterials.clear(), which holds the textures) and for tests; no Modern scene may be preparing or showing.
## With an owner (what it passed to request()): the owner signs off, and the caches only go when no other owner
## is left – a stage that ends does not take away what the next stage (already in the tree) has requested.
static func release_all(owner: Object = null) -> void:
	if owner != null:
		_owners.erase(owner.get_instance_id())
		for id: int in _owners.keys():
			if not is_instance_id_valid(id):
				_owners.erase(id)      # freed without signing off
		if not _owners.is_empty():
			return
	_owners.clear()
	for f: String in _pending.keys():
		ResourceLoader.load_threaded_get(_root + f)       # finish running loads before dropping them
	_pending.clear()
	_meshes.clear()
	_textures.clear()
	loads = 0
