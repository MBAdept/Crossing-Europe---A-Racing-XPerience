extends SceneTree
# prints the vertices of a mesh beyond a lateral bound: y range and z range per x band
func _initialize() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var xlim := float(OS.get_cmdline_user_args()[1])
	var zlim := float(OS.get_cmdline_user_args()[2])
	var m: Mesh = load(path)
	var ymin := INF; var ymax := -INF; var zmin := INF; var zmax := -INF; var n := 0
	var y2min := INF; var y2max := -INF; var x2min := INF; var x2max := -INF; var n2 := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for p in v:
			if p.x < xlim:
				n += 1; ymin = minf(ymin, p.y); ymax = maxf(ymax, p.y); zmin = minf(zmin, p.z); zmax = maxf(zmax, p.z)
			if p.z > zlim:
				n2 += 1; y2min = minf(y2min, p.y); y2max = maxf(y2max, p.y); x2min = minf(x2min, p.x); x2max = maxf(x2max, p.x)
	print("x < %.2f: %d verts, y %.2f..%.2f, z %.2f..%.2f" % [xlim, n, ymin, ymax, zmin, zmax])
	print("z > %.2f: %d verts, y %.2f..%.2f, x %.2f..%.2f" % [zlim, n2, y2min, y2max, x2min, x2max])
	quit()
