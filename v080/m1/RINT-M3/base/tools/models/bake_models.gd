extends SceneTree
## Bake of the real-time models (step 2 of the model pipeline, docs/modelle.md):
##   godot --headless --path . -s res://tools/models/bake_models.gd -- [--only=<glob>] [--cache=<dir>] [--out=<dir>]
##
## Reads the intermediates of tools/blender/export_models.py (tools/blender/_cache3d/<group>/<name>/
## {model.glb, model_meta.json, textures}) and writes the committed resources:
##   assets/models/<group>/<name>/<mesh>.res   node-free ArrayMesh, attributes compressed, surface names =
##                                             material class, NO materials inside, no UID (the id of
##                                             the inner resource derives from the target path, see below)
##   assets/models/<group>/<name>/<texture>    copies of the texture sources (+ .import, written by
##                                             tools/models/set_model_import.py)
##   assets/models/<group>/<name>/model.json   manifest fragment (model entry with measured triangles,
##                                             bytes and hash, and the sets of the model)
## The .glb goes through GLTFDocument; nothing of Godot's scene import is used, so the result does not
## depend on import settings or random node ids: two bakes of the same intermediates INTO THE SAME FOLDER are
## byte-identical (measured). Baked into another folder (--out) the content differs in the five characters
## of the path-derived id "local://ArrayMesh_<id>" - and, the files being saved compressed, the files differ
## in many bytes and sometimes in length; bytes and hash in model.json therefore hold for assets/models.
## Times go to _cache3d/bake_report.json, never into the model folders.
## Automatic mesh LODs (ImporterMesh.generate_lods) are only made for meshes the exporter flags "auto_lod"
## (never for cars with decal patches). After a bake run `godot --headless --path . --import` once (textures).

const DEFAULT_CACHE := "res://tools/blender/_cache3d"
const DEFAULT_OUT := "res://assets/models"
const CLASSES: Array[String] = ["vpbr", "glass", "baked", "baked_cutout", "leaves"]
const LOD_NORMAL_MERGE_DEG := 60.0
const LOD_NORMAL_SPLIT_DEG := 25.0

var _failed := 0


func _arg(key: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return default


func _initialize() -> void:
	var only := _arg("only", "*")
	var cache := ProjectSettings.globalize_path(_arg("cache", DEFAULT_CACHE))
	var out := ProjectSettings.globalize_path(_arg("out", DEFAULT_OUT))
	var ids: Array[String] = []
	for group: String in _dirs(cache):
		for name: String in _dirs(cache.path_join(group)):
			var id := group + "/" + name
			if id.match(only) and FileAccess.file_exists(cache.path_join(id).path_join("model_meta.json")):
				ids.append(id)
	ids.sort()
	if ids.is_empty():
		print("bake_models: keine Zwischenstände für '%s' in %s (erst tools/blender/export_models.py)" % [only, cache])
		quit(1)
		return
	var report := {}
	var t_all := Time.get_ticks_msec()
	for id: String in ids:
		var t0 := Time.get_ticks_msec()
		var r := _bake(id, cache.path_join(id), out.path_join(id))
		if r.is_empty():
			_failed += 1
			continue
		r["bake_s"] = snappedf(float(Time.get_ticks_msec() - t0) / 1000.0, 0.01)
		report[id] = r
		print("%-28s %7d Dreiecke  %2d Netze  %8d Bytes  %5.2f s" % [id, int(r["tris"]), int(r["meshes"]), int(r["bytes"]), float(r["bake_s"])])
	# timings and sizes for reports (never committed): the models of this run replace their entries
	var report_path := cache.path_join("bake_report.json")
	var all: Dictionary = {}
	if FileAccess.file_exists(report_path):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		if old is Dictionary:
			all = old
	all.merge(report, true)
	var rf := FileAccess.open(report_path, FileAccess.WRITE)
	if rf != null:
		rf.store_string(JSON.stringify(all, " ", true) + "\n")
		rf.close()
	# .import files of the textures (one implementation: the Python tool). Only inside the project: a test
	# bake into a folder outside of it has no res:// paths an .import file could name.
	if ProjectSettings.localize_path(out).begins_with("res://"):
		var tool := ProjectSettings.globalize_path("res://tools/models/set_model_import.py")
		var res: Array = []
		var code := OS.execute("python3", [tool, "--root", out, "--quiet"], res, true)
		if code != 0:
			print("bake_models: set_model_import.py meldet Fehler:\n", "\n".join(res))
			_failed += 1
	print("bake_models: %d Modelle in %.1f s, %d Fehler" % [report.size(), float(Time.get_ticks_msec() - t_all) / 1000.0, _failed])
	quit(1 if _failed > 0 else 0)


func _dirs(path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(path)
	if d != null:
		for n: String in d.get_directories():
			if not n.begins_with("."):
				out.append(n)
	out.sort()
	return out


func _fail(id: String, msg: String) -> Dictionary:
	print("FEHLER %s: %s" % [id, msg])
	return {}


## Bakes one model. Returns {} on failure, else the numbers for the report.
func _bake(id: String, src: String, dst: String) -> Dictionary:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(src.path_join("model_meta.json")))
	if not meta is Dictionary or not (meta as Dictionary).has("model"):
		return _fail(id, "model_meta.json ist ungültig")
	var model: Dictionary = (meta as Dictionary)["model"]
	var mesh_meta: Dictionary = (meta as Dictionary).get("meshes", {})
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(src.path_join("model.glb"), state)
	if err != OK:
		return _fail(id, "model.glb nicht lesbar (Fehler %d)" % err)
	# meshes straight from the glTF state: no scene, no nodes
	var meshes := {}
	for gm: GLTFMesh in state.get_meshes():
		var im: ImporterMesh = gm.mesh
		if im == null:
			continue
		# original_name = the mesh name of the exporter (resource_name gets the file name as a prefix)
		meshes[str(gm.original_name)] = im
	# clean target folder: only what this bake writes stays
	DirAccess.make_dir_recursive_absolute(dst)
	var old := DirAccess.open(dst)
	for f: String in old.get_files():
		old.remove(f)
	var files: Array[String] = []
	var tris_by_mesh := {}
	var names: Array = mesh_meta.keys()
	names.sort()
	for mname: String in names:
		if not meshes.has(mname):
			return _fail(id, "Netz '%s' fehlt in model.glb" % mname)
		var mm: Dictionary = mesh_meta[mname]
		var built := _array_mesh(meshes[mname], bool(mm.get("auto_lod", false)))
		if built.is_empty():
			return _fail(id, "Netz '%s': unbekannte Materialklasse oder leere Fläche" % mname)
		var mesh: ArrayMesh = built["mesh"]
		var path := dst.path_join(mname + ".res")
		var e2 := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		if e2 != OK:
			return _fail(id, "Speichern von %s schlug fehl (Fehler %d)" % [path, e2])
		files.append(mname + ".res")
		tris_by_mesh[mname] = int(built["tris"])
		if int(mm.get("tris", built["tris"])) != int(built["tris"]):
			return _fail(id, "Netz '%s': %d Dreiecke nach dem Backen, exportiert %d" % [mname, int(built["tris"]), int(mm["tris"])])
	for mname: String in meshes:
		if not mesh_meta.has(mname):
			return _fail(id, "Netz '%s' in model.glb, aber nicht in model_meta.json" % mname)
	# textures: plain copies of the sources
	for tex: String in (meta as Dictionary).get("textures", []):
		var data := FileAccess.get_file_as_bytes(src.path_join(tex))
		if data.is_empty():
			return _fail(id, "Textur %s fehlt" % tex)
		var tf := FileAccess.open(dst.path_join(tex), FileAccess.WRITE)
		tf.store_buffer(data)
		tf.close()
		files.append(tex)
	# measured values into the fragment
	files.sort()
	var total := 0
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	for f: String in files:
		var bytes := FileAccess.get_file_as_bytes(dst.path_join(f))
		total += bytes.size()
		ctx.update((f + "\n").to_utf8_buffer())
		ctx.update(bytes)
	var all_tris := 0
	for lod: Dictionary in model.get("lods", []):
		var n := 0
		for part: Dictionary in lod.get("parts", []):
			n += int(tris_by_mesh.get(str(part["mesh"]).get_file().get_basename(), 0))
		lod["tris"] = n
		all_tris += n
	if model.has("shadow"):
		var sh: Dictionary = model["shadow"]
		sh["tris"] = int(tris_by_mesh.get(str(sh["mesh"]).get_file().get_basename(), 0))
	model["bytes"] = total
	model["hash"] = ctx.finish().hex_encode()
	var frag := {"version": int((meta as Dictionary).get("version", 1)), "exporter": str((meta as Dictionary).get("exporter", "")),
		"id": id, "model": model, "sets": (meta as Dictionary).get("sets", {})}
	var jf := FileAccess.open(dst.path_join("model.json"), FileAccess.WRITE)
	jf.store_string(_json(frag, 0) + "\n")
	jf.close()
	return {"tris": all_tris, "meshes": tris_by_mesh.size(), "bytes": total, "tris_by_mesh": tris_by_mesh}


## ImporterMesh of the glTF -> ArrayMesh with compressed attributes, surfaces named by class and ordered as
## CLASSES, no tangents, no materials. {} if a surface has an unknown class.
func _array_mesh(src: ImporterMesh, auto_lod: bool) -> Dictionary:
	var im := ImporterMesh.new()
	var tris := 0
	var by_class := {}
	for s in src.get_surface_count():
		var mat := src.get_surface_material(s)
		var cls := str(mat.resource_name) if mat != null else str(src.get_surface_name(s))
		if not CLASSES.has(cls) or by_class.has(cls):
			return {}
		by_class[cls] = s
	for cls: String in CLASSES:
		if not by_class.has(cls):
			continue
		var s: int = by_class[cls]
		var arrays := src.get_surface_arrays(s)
		arrays[Mesh.ARRAY_TANGENT] = null
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).is_empty():
			return {}
		tris += (idx as PackedInt32Array).size() / 3
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, null, cls, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	if auto_lod:
		im.generate_lods(LOD_NORMAL_MERGE_DEG, LOD_NORMAL_SPLIT_DEG, [])
	var mesh := im.get_mesh()
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, null)
	return {"mesh": mesh, "tris": tris}


## Deterministic JSON text: keys in insertion order, whole numbers without a fraction, short lists and
## dictionaries of scalars on one line.
func _json(v: Variant, ind: int) -> String:
	var pad := " ".repeat(ind)
	if v is Dictionary:
		var d: Dictionary = v
		if d.is_empty():
			return "{}"
		var flat := d.size() <= 6
		for k: Variant in d:
			if d[k] is Dictionary or d[k] is Array:
				flat = false
		var items: Array[String] = []
		for k: Variant in d:
			items.append(JSON.stringify(str(k)) + ": " + _json(d[k], ind + 1))
		if flat:
			return "{" + ", ".join(items) + "}"
		return "{\n" + pad + " " + (",\n" + pad + " ").join(items) + "\n" + pad + "}"
	if v is Array:
		var a: Array = v
		var scalars := true
		for x: Variant in a:
			if x is Dictionary or x is Array:
				scalars = false
		var parts: Array[String] = []
		for x: Variant in a:
			parts.append(_json(x, ind + 1))
		if scalars:
			return "[" + ", ".join(parts) + "]"
		return "[\n" + pad + " " + (",\n" + pad + " ").join(parts) + "\n" + pad + "]"
	if v is float:
		var f: float = v
		if is_equal_approx(f, roundf(f)) and absf(f) < 1.0e15:
			return str(int(roundf(f)))
		return String.num(f, 6)
	if v is int:
		return str(v)
	if v is bool:
		return "true" if v else "false"
	if v == null:
		return "null"
	return JSON.stringify(str(v))
