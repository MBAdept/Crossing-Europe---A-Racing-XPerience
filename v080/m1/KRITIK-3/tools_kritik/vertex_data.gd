extends SceneTree
## KRITIK-3 scratch tool: what the leaves / wood meshes of the AS3 models carry in their vertex data.
##   godot --headless --path . -s res://tools/kritik/vertex_data.gd -- --models=props/tree_oak,...
## Per model and level: wood (vpbr) lowest y, leaves: sway amplitude (COLOR.r) against height, phases (COLOR.g),
## stiffness (COLOR.b), brightness (COLOR.a), share of up-facing normals, normals pointing into the crown.


func _initialize() -> void:
	var models := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--models="):
			models = a.substr(9)
	if not ModelDB.load_manifest():
		print("kein Manifest")
		quit(1)
		return
	for mid: String in models.split(",", false):
		var m := ModelDB.model(mid)
		for l: Variant in m.get("lods", []):
			var ld: Dictionary = l
			for p: Variant in ld.get("parts", []):
				var pd: Dictionary = p
				var mesh := ModelDB.mesh(str(pd.get("mesh", "")))
				if mesh == null:
					continue
				_report(mid, str(ld.get("name", "")), mesh)
	quit(0)


func _report(mid: String, lod: String, mesh: ArrayMesh) -> void:
	for s in mesh.get_surface_count():
		var name := mesh.surface_get_name(s)
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var ymin := INF
		var ymax := -INF
		var cen := Vector3.ZERO
		for p: Vector3 in v:
			ymin = minf(ymin, p.y)
			ymax = maxf(ymax, p.y)
			cen += p
		cen /= maxf(1.0, float(v.size()))
		if name != "leaves" or c.is_empty():
			print("DATEN %s %s %s: %d Ecken, y %.2f .. %.2f" % [mid, lod, name, v.size(), ymin, ymax])
			continue
		# sway amplitude by height: mean COLOR.r in five height bands
		var bands := [0.0, 0.0, 0.0, 0.0, 0.0]
		var bn := [0, 0, 0, 0, 0]
		var phases := {}
		var stiff := {}
		var bmin := 1.0
		var bmax := 0.0
		var bsum := 0.0
		var up := 0
		var inward := 0
		for i in v.size():
			var t := clampf((v[i].y - ymin) / maxf(0.01, ymax - ymin), 0.0, 0.999)
			var k := int(t * 5.0)
			bands[k] += c[i].r
			bn[k] += 1
			phases[snappedf(c[i].g, 0.02)] = true
			stiff[snappedf(c[i].b, 0.01)] = true
			bmin = minf(bmin, c[i].a)
			bmax = maxf(bmax, c[i].a)
			bsum += c[i].a
			if n[i].y > 0.5:
				up += 1
			var out := Vector3(v[i].x - cen.x, 0.0, v[i].z - cen.z)
			if out.length() > 0.3 and n[i].dot(out.normalized()) < -0.3 and n[i].y < 0.3:
				inward += 1
		var bs: Array[String] = []
		for k in 5:
			bs.append("%.2f" % (bands[k] / maxf(1.0, float(bn[k]))))
		var st: Array[String] = []
		for key: Variant in stiff.keys():
			st.append("%.2f" % float(key))
		print("DATEN %s %s leaves: %d Ecken, y %.2f .. %.2f, Ausschlag nach Höhe (5 Bänder) %s, %d Phasen, Steifheit %s, Helligkeit %.2f/%.2f/%.2f, Normale nach oben %.0f %%, nach innen %.1f %%" % [
			mid, lod, v.size(), ymin, ymax, " ".join(bs), phases.size(), ",".join(st), bmin, bsum / float(v.size()), bmax,
			100.0 * float(up) / float(v.size()), 100.0 * float(inward) / float(v.size())])
