extends SceneTree
## QA: independent decode of every baked mesh (.res) under res://assets/models. Does not use ModelDB or
## inspect_models.gd. Output: JSON (--out=<file>).

func _arg(key: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return default


func _files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_files(dir.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".res"):
			out.append(dir.path_join(f))


func _initialize() -> void:
	var root_dir := _arg("root", "res://assets/models")
	var files: Array = []
	_files(root_dir, files)
	files.sort()
	var report := {}
	for path: String in files:
		report[path] = _mesh(path)
	var fh := FileAccess.open(_arg("out", "user://qa_decode.json"), FileAccess.WRITE)
	fh.store_string(JSON.stringify(report, " ", true))
	fh.close()
	print("qa_decode: %d Dateien" % files.size())
	quit(0)


func _hist_add(h: Dictionary, key: String, n: int = 1) -> void:
	h[key] = int(h.get(key, 0)) + n


func _mesh(path: String) -> Dictionary:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var d := {"class": res.get_class() if res != null else "null", "bytes": FileAccess.get_file_as_bytes(path).size()}
	var mesh := res as ArrayMesh
	if mesh == null:
		return d
	d["resource_name"] = mesh.resource_name
	d["deps"] = ResourceLoader.get_dependencies(path)
	d["uid"] = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
	d["blend_shapes"] = mesh.get_blend_shape_count()
	d["custom_aabb"] = str(mesh.custom_aabb)
	d["shadow_mesh"] = mesh.shadow_mesh != null
	var aabb := mesh.get_aabb()
	d["aabb"] = [aabb.position.x, aabb.position.y, aabb.position.z, aabb.end.x, aabb.end.y, aabb.end.z]
	var stored: Variant = mesh.get("_surfaces")
	var surfaces: Array = []
	for s in mesh.get_surface_count():
		var sd := {}
		var fmt := mesh.surface_get_format(s)
		sd["name"] = str(mesh.surface_get_name(s))
		sd["format"] = fmt
		sd["has_normal"] = (fmt & Mesh.ARRAY_FORMAT_NORMAL) != 0
		sd["has_tangent"] = (fmt & Mesh.ARRAY_FORMAT_TANGENT) != 0
		sd["has_color"] = (fmt & Mesh.ARRAY_FORMAT_COLOR) != 0
		sd["has_uv"] = (fmt & Mesh.ARRAY_FORMAT_TEX_UV) != 0
		sd["has_uv2"] = (fmt & Mesh.ARRAY_FORMAT_TEX_UV2) != 0
		sd["has_custom"] = (fmt & (Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2 | Mesh.ARRAY_FORMAT_CUSTOM3)) != 0
		sd["has_bones"] = (fmt & Mesh.ARRAY_FORMAT_BONES) != 0
		sd["compressed"] = (fmt & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) != 0
		sd["primitive"] = mesh.surface_get_primitive_type(s)
		sd["material"] = mesh.surface_get_material(s) != null
		if stored is Array and s < (stored as Array).size() and (stored as Array)[s] is Dictionary:
			var st: Dictionary = (stored as Array)[s]
			sd["stored_keys"] = st.keys()
			var lods: Variant = st.get("lods", [])
			var lod_info: Array = []
			if lods is Array:
				var la: Array = lods
				var i := 0
				while i + 1 < la.size():
					var idxb: Variant = la[i + 1]
					var n := 0
					if idxb is PackedByteArray:
						n = (idxb as PackedByteArray).size()
					elif idxb is PackedInt32Array:
						n = (idxb as PackedInt32Array).size()
					lod_info.append([la[i], n])
					i += 2
			sd["lods"] = lod_info
			sd["vertex_bytes"] = (st.get("vertex_data", PackedByteArray()) as PackedByteArray).size()
			sd["attr_bytes"] = (st.get("attribute_data", PackedByteArray()) as PackedByteArray).size()
			sd["index_bytes"] = (st.get("index_data", PackedByteArray()) as PackedByteArray).size()
			sd["uv_scale"] = str(st.get("uv_scale", ""))
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var normals: Variant = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var cols: Variant = arr[Mesh.ARRAY_COLOR]
		var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
		var uv2: Variant = arr[Mesh.ARRAY_TEX_UV2]
		sd["verts"] = verts.size()
		sd["tris"] = idx.size() / 3
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for v in verts:
			lo = lo.min(v)
			hi = hi.max(v)
		sd["aabb"] = [lo.x, lo.y, lo.z, hi.x, hi.y, hi.z]
		# normals: length, agreement with the winding
		var bad_len := 0
		if normals != null:
			for n: Vector3 in (normals as PackedVector3Array):
				if absf(n.length() - 1.0) > 0.02 or is_nan(n.x):
					bad_len += 1
		sd["normals_bad_length"] = bad_len
		var agree := 0
		var against := 0
		var degenerate := 0
		var area_total := 0.0
		var mixed_code := 0
		var mixed_lamp := 0
		var code_hist := {}
		var lamp_hist := {}
		var lamp_area := {}
		var lamp_lo := {}
		var lamp_hi := {}
		var lamp_col := {}
		var lamp_w := {}
		var rough_hist := {}
		var code_tri := {}
		var code_area := {}
		var ca: PackedColorArray = cols if cols != null else PackedColorArray()
		var u2: PackedVector2Array = uv2 if uv2 != null else PackedVector2Array()
		var u1: PackedVector2Array = uv if uv != null else PackedVector2Array()
		var na: PackedVector3Array = normals if normals != null else PackedVector3Array()
		var t := 0
		while t + 2 < idx.size():
			var i0 := idx[t]
			var i1 := idx[t + 1]
			var i2 := idx[t + 2]
			t += 3
			var a := verts[i0]
			var b := verts[i1]
			var c := verts[i2]
			var g := (b - a).cross(c - a)
			var ar := g.length() * 0.5
			area_total += ar
			if ar < 1.0e-10:
				degenerate += 1
			elif na.size() > 0:
				var nm := (na[i0] + na[i1] + na[i2])
				# Godot: clockwise front faces -> the geometric normal of a front face is -(b-a)x(c-a)
				if (-g).dot(nm) > 0.0:
					agree += 1
				else:
					against += 1
			if ca.size() > 0:
				var k0 := snappedf(ca[i0].a, 0.001)
				if absf(ca[i0].a - ca[i1].a) > 0.004 or absf(ca[i0].a - ca[i2].a) > 0.004:
					mixed_code += 1
				_hist_add(code_tri, str(k0))
				code_area[str(k0)] = float(code_area.get(str(k0), 0.0)) + ar
			if u2.size() > 0:
				var l0 := snappedf(u2[i0].x, 0.001)
				if absf(u2[i0].x - u2[i1].x) > 0.004 or absf(u2[i0].x - u2[i2].x) > 0.004 or absf(u2[i0].y - u2[i1].y) > 0.004 or absf(u2[i0].y - u2[i2].y) > 0.004:
					mixed_lamp += 1
				var lk := str(l0)
				_hist_add(lamp_hist, lk)
				lamp_area[lk] = float(lamp_area.get(lk, 0.0)) + ar
				var cen := (a + b + c) / 3.0
				var plo: Vector3 = lamp_lo.get(lk, Vector3(INF, INF, INF))
				var phi: Vector3 = lamp_hi.get(lk, Vector3(-INF, -INF, -INF))
				lamp_lo[lk] = plo.min(a).min(b).min(c)
				lamp_hi[lk] = phi.max(a).max(b).max(c)
				if ca.size() > 0:
					var pc: Dictionary = lamp_col.get(lk, {})
					_hist_add(pc, ca[i0].to_html(false))
					lamp_col[lk] = pc
				var pw: Dictionary = lamp_w.get(lk, {})
				_hist_add(pw, str(snappedf(u2[i0].y, 0.001)))
				lamp_w[lk] = pw
			if u1.size() > 0 and sd["name"] in ["vpbr", "glass"]:
				_hist_add(rough_hist, "%s/%s" % [str(snappedf(u1[i0].x, 0.01)), str(snappedf(u1[i0].y, 0.01))])
		sd["area_m2"] = area_total
		sd["winding_agree"] = agree
		sd["winding_against"] = against
		sd["degenerate"] = degenerate
		sd["mixed_code_tris"] = mixed_code
		sd["mixed_lamp_tris"] = mixed_lamp
		# per vertex histograms
		for c: Color in ca:
			_hist_add(code_hist, str(snappedf(c.a, 0.0001)))
		sd["code_hist_vertices"] = code_hist
		sd["code_tris"] = code_tri
		sd["code_area"] = code_area
		sd["lamp_tris"] = lamp_hist
		sd["lamp_area"] = lamp_area
		var lb := {}
		for k: String in lamp_lo:
			var l: Vector3 = lamp_lo[k]
			var h: Vector3 = lamp_hi[k]
			lb[k] = [l.x, l.y, l.z, h.x, h.y, h.z]
		sd["lamp_bounds"] = lb
		sd["lamp_colors"] = lamp_col
		sd["lamp_weights"] = lamp_w
		sd["rough_metal_tris"] = rough_hist
		# raw per-vertex extremes
		var u2x := {}
		for u: Vector2 in u2:
			_hist_add(u2x, str(snappedf(u.x, 0.0001)))
		sd["uv2x_hist_vertices"] = u2x
		if u1.size() > 0:
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for u: Vector2 in u1:
				mn = mn.min(u)
				mx = mx.max(u)
			sd["uv_range"] = [mn.x, mn.y, mx.x, mx.y]
		if sd["name"] == "leaves" and ca.size() > 0:
			var rmin := Color(1, 1, 1, 1)
			var rmax := Color(0, 0, 0, 0)
			for c: Color in ca:
				rmin = Color(minf(rmin.r, c.r), minf(rmin.g, c.g), minf(rmin.b, c.b), minf(rmin.a, c.a))
				rmax = Color(maxf(rmax.r, c.r), maxf(rmax.g, c.g), maxf(rmax.b, c.b), maxf(rmax.a, c.a))
			sd["leaf_color_range"] = [rmin.r, rmin.g, rmin.b, rmin.a, rmax.r, rmax.g, rmax.b, rmax.a]
			# outward normals: from the centre of the surface
			var cen := (lo + hi) * 0.5
			var outw := 0
			for i in verts.size():
				if na[i].dot(verts[i] - cen) > 0.0:
					outw += 1
			sd["leaf_normals_outward"] = float(outw) / float(maxi(1, verts.size()))
		if sd["name"] == "glass" and ca.size() > 0:
			var gh := {}
			for c: Color in ca:
				_hist_add(gh, "%s a=%s" % [c.to_html(false), str(snappedf(c.a, 0.001))])
			sd["glass_colors"] = gh
		surfaces.append(sd)
	d["surfaces"] = surfaces
	return d
