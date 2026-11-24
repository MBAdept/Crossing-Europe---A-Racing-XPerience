extends SceneTree
func _initialize() -> void:
	for p in ["res://assets/models/props/tree_spruce/lod0_body.res", "res://assets/models/props/tree_spruce/lod1_body.res"]:
		var mesh: Mesh = load(p)
		var arr := mesh.surface_get_arrays(1)
		var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var hist := []
		hist.resize(10)
		hist.fill(0)
		var snowy := 0
		for col in c:
			hist[clampi(int(col.g * 10.0), 0, 9)] += 1
			if fmod(col.g * 7.31 + 0.17, 1.0) < 0.29:
				snowy += 1
		print(p.get_file(), " verts ", c.size(), " g-Verteilung ", hist, " Anteil mit Schnee ", "%.2f" % (float(snowy) / c.size()))
	quit(0)
