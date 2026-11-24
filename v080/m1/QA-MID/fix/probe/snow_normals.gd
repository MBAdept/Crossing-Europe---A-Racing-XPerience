extends SceneTree
## QA-mid probe: distribution of the leaves' normal y (the snow law of leaves.gdshader: k = smoothstep(0.35, 0.85, up)
## * 0.85) per tree model, weighted by triangle area – how much of a crown turns white in snow.
func _initialize() -> void:
	for id in ["props/tree_spruce", "props/tree_spruce_b", "props/tree_pine", "props/tree_oak", "props/tree_beech", "props/tree_birch"]:
		var path := "res://assets/models/%s/lod0_body.res" % id
		if not ResourceLoader.exists(path):
			print("FEHLT ", path)
			continue
		var mesh: Mesh = load(path)
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var mat := mesh.surface_get_material(s)
			var mname := str(mat.resource_name) if mat != null else ""
			var tot := 0.0
			var k_sum := 0.0
			var hist := [0.0, 0.0, 0.0, 0.0, 0.0]
			var tris := idx.size() / 3 if idx.size() > 0 else v.size() / 3
			for t in tris:
				var i0 := idx[t * 3] if idx.size() > 0 else t * 3
				var i1 := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
				var i2 := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
				var area := (v[i1] - v[i0]).cross(v[i2] - v[i0]).length() * 0.5
				var up := (n[i0].y + n[i1].y + n[i2].y) / 3.0
				var k := smoothstep(0.35, 0.85, up) * 0.85
				tot += area
				k_sum += k * area
				hist[clampi(int(floor((up + 1.0) / 0.4)), 0, 4)] += area
			var hs := []
			for h in hist:
				hs.append("%.2f" % (h / maxf(tot, 1e-9)))
			print("%-22s surf %d %-14s tris %5d  mittlerer Schnee %.2f  up-Verteilung [-1..-.6 .. .6..1] %s" % [id, s, mname, tris, k_sum / maxf(tot, 1e-9), " ".join(hs)])
	quit(0)
