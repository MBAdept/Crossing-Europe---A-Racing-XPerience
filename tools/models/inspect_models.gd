extends SceneTree
## Decodes the baked model files for tools/blender/validate_models.py (docs/modelle.md):
##   godot --headless --path . -s res://tools/models/inspect_models.gd -- --out=<file.json> [--manifest=<path>]
## For every mesh of the manifest: surfaces (name, format flags, vertices, triangles, LOD count), bounds,
## the distinct paint codes (COLOR.a) and lamp channels (UV2) of vpbr surfaces, the UV range of baked and
## leaves surfaces, the lowest point (wheels), file size. For every texture: size, format, mipmaps.
## Nothing is judged here - the validator does that.

func _initialize() -> void:
	var out := ""
	var manifest := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--manifest="):
			manifest = a.substr(11)
	if manifest != "":
		ModelDB.load_manifest(manifest)
	var report := {"available": ModelDB.available(), "meshes": {}, "textures": {}}
	if ModelDB.available():
		for mid: String in ModelDB.model_ids():
			for f: String in ModelDB.files_of(mid):
				if f.ends_with(".res"):
					if not (report["meshes"] as Dictionary).has(f):
						report["meshes"][f] = _mesh(f)
				elif not (report["textures"] as Dictionary).has(f):
					report["textures"][f] = _texture(f)
	var text := JSON.stringify(report, " ", true)
	if out == "":
		print(text)
	else:
		var fh := FileAccess.open(out, FileAccess.WRITE)
		fh.store_string(text + "\n")
		fh.close()
	quit(0)


func _mesh(rel: String) -> Dictionary:
	var mesh := ModelDB.mesh(rel)
	if mesh == null:
		return {"missing": true}
	var d := {"surfaces": [], "bytes": FileAccess.get_file_as_bytes(ModelDB.ROOT + rel).size(), "has_materials": false}
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	# the stored surfaces carry the automatic levels (index buffers of a decimated mesh) - an ArrayMesh has
	# no other way to ask for them
	var stored: Array = mesh.get("_surfaces") if mesh.get("_surfaces") is Array else []
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		var fmt := mesh.surface_get_format(s)
		var sd := {"name": str(mesh.surface_get_name(s)), "verts": verts.size(),
			"tris": ((idx as PackedInt32Array).size() / 3) if idx != null else verts.size() / 3,
			"compressed": (fmt & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) != 0,
			"tangents": arr[Mesh.ARRAY_TANGENT] != null,
			"lods": _lod_count(stored[s]) if s < stored.size() else 0}
		if mesh.surface_get_material(s) != null:
			d["has_materials"] = true
		for v: Vector3 in verts:
			lo = lo.min(v)
			hi = hi.max(v)
		var cols: Variant = arr[Mesh.ARRAY_COLOR]
		var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
		var uv2: Variant = arr[Mesh.ARRAY_TEX_UV2]
		if cols != null:
			var codes := {}
			var amin := 1.0
			var amax := 0.0
			for c: Color in (cols as PackedColorArray):
				codes[snappedf(c.a, 0.001)] = true
				amin = minf(amin, c.a)
				amax = maxf(amax, c.a)
			var keys: Array = codes.keys()
			keys.sort()
			sd["alpha_values"] = keys.slice(0, 64)
			sd["alpha_count"] = keys.size()
			sd["alpha_range"] = [amin, amax]
		if uv != null:
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for u: Vector2 in (uv as PackedVector2Array):
				mn = mn.min(u)
				mx = mx.max(u)
			sd["uv_range"] = [mn.x, mn.y, mx.x, mx.y]
		if uv2 != null:
			var lamps := {}
			var wmin := 1.0
			var wmax := 0.0
			for u: Vector2 in (uv2 as PackedVector2Array):
				lamps[snappedf(u.x, 0.001)] = true
				if u.x >= 0.0:
					wmin = minf(wmin, u.y)
					wmax = maxf(wmax, u.y)
			var lk: Array = lamps.keys()
			lk.sort()
			sd["lamp_values"] = lk.slice(0, 64)
			sd["lamp_weight_range"] = [wmin, wmax]
		(d["surfaces"] as Array).append(sd)
	d["aabb"] = [lo.x, lo.y, lo.z, hi.x, hi.y, hi.z]
	return d


## Number of automatic levels of a stored surface: "lods" is a flat list (edge length, index data, ...).
func _lod_count(surface: Variant) -> int:
	if not surface is Dictionary:
		return 0
	var lods: Variant = (surface as Dictionary).get("lods", [])
	return (lods as Array).size() / 2 if lods is Array else 0


func _texture(rel: String) -> Dictionary:
	var path := ModelDB.ROOT + rel
	var d := {"file_bytes": FileAccess.get_file_as_bytes(path).size(), "import": FileAccess.file_exists(path + ".import")}
	var tex := ModelDB.texture(rel)
	if tex == null:
		d["missing"] = true
		return d
	d["size"] = [tex.get_width(), tex.get_height()]
	var img := tex.get_image()
	if img != null:
		d["format"] = img.get_format()
		d["format_name"] = _format_name(img.get_format())
		d["mipmaps"] = img.has_mipmaps()
		d["vram_bytes"] = img.get_data().size()
	return d


func _format_name(f: int) -> String:
	match f:
		Image.FORMAT_DXT1:
			return "BC1"
		Image.FORMAT_DXT3:
			return "BC2"
		Image.FORMAT_DXT5:
			return "BC3"
		Image.FORMAT_RGTC_R:
			return "BC4"
		Image.FORMAT_RGTC_RG:
			return "BC5"
		Image.FORMAT_BPTC_RGBA:
			return "BC7"
		Image.FORMAT_RGBA8:
			return "RGBA8"
		Image.FORMAT_RGB8:
			return "RGB8"
	return "format %d" % f
