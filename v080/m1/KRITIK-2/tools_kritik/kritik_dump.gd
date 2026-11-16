extends SceneTree
## AS1-KRITIK: dumps the vehicle meshes of the manifest as raw arrays for numpy (scratch only).
##   godot --headless --path . -s res://tools/kritik/kritik_dump.gd -- --outdir=<abs dir>
## Per mesh file and surface: <outdir>/<mesh path with / -> __>.<surface>.{v,n,c,uv,uv2,i}.bin + index.json


func _initialize() -> void:
	var outdir := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--outdir="):
			outdir = a.substr(9)
	var index := {}
	for mid: String in ModelDB.model_ids():
		if not (mid.begins_with("player/") or mid.begins_with("traffic/")):
			continue
		for f: String in ModelDB.files_of(mid):
			if not f.ends_with(".res") or index.has(f):
				continue
			var mesh := ModelDB.mesh(f)
			if mesh == null:
				continue
			var surfs := []
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var base := outdir.path_join(f.replace("/", "__") + ".%d" % s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				_store(base + ".v.bin", _v3(v))
				if arr[Mesh.ARRAY_NORMAL] != null:
					_store(base + ".n.bin", _v3(arr[Mesh.ARRAY_NORMAL]))
				if arr[Mesh.ARRAY_COLOR] != null:
					var cf := PackedFloat32Array()
					for c: Color in (arr[Mesh.ARRAY_COLOR] as PackedColorArray):
						cf.append_array(PackedFloat32Array([c.r, c.g, c.b, c.a]))
					_store(base + ".c.bin", cf.to_byte_array())
				if arr[Mesh.ARRAY_TEX_UV] != null:
					_store(base + ".uv.bin", _v2(arr[Mesh.ARRAY_TEX_UV]))
				if arr[Mesh.ARRAY_TEX_UV2] != null:
					_store(base + ".uv2.bin", _v2(arr[Mesh.ARRAY_TEX_UV2]))
				var idx: Variant = arr[Mesh.ARRAY_INDEX]
				if idx != null:
					_store(base + ".i.bin", (idx as PackedInt32Array).to_byte_array())
				surfs.append({"name": str(mesh.surface_get_name(s)), "verts": v.size(), "base": base.get_file()})
			index[f] = surfs
	var fh := FileAccess.open(outdir.path_join("index.json"), FileAccess.WRITE)
	fh.store_string(JSON.stringify(index, " ", true))
	fh.close()
	print("kritik_dump: ", index.size(), " meshes")
	quit(0)


func _v3(a: PackedVector3Array) -> PackedByteArray:
	var f := PackedFloat32Array()
	f.resize(a.size() * 3)
	for i in a.size():
		f[i * 3] = a[i].x
		f[i * 3 + 1] = a[i].y
		f[i * 3 + 2] = a[i].z
	return f.to_byte_array()


func _v2(a: PackedVector2Array) -> PackedByteArray:
	var f := PackedFloat32Array()
	f.resize(a.size() * 2)
	for i in a.size():
		f[i * 2] = a[i].x
		f[i * 2 + 1] = a[i].y
	return f.to_byte_array()


func _store(path: String, data: PackedByteArray) -> void:
	var fh := FileAccess.open(path, FileAccess.WRITE)
	fh.store_buffer(data)
	fh.close()
