extends SceneTree
# FIX-RINT probe: vertex extents of the fuel station model per lateral band (x) – front z of the shop and the canopy.
func _initialize() -> void:
	var m: Mesh = load("res://assets/models/props/fuel_station/lod0_body.res")
	var bands := {}
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for p in v:
			var b := int(floor(p.x / 2.0))
			var e: Array = bands.get(b, [1e9, -1e9, 1e9, -1e9])
			e[0] = minf(e[0], p.z); e[1] = maxf(e[1], p.z); e[2] = minf(e[2], p.y); e[3] = maxf(e[3], p.y)
			bands[b] = e
	var keys := bands.keys()
	keys.sort()
	for b in keys:
		var e: Array = bands[b]
		print("x %5.1f..%5.1f  z %.2f..%.2f  y %.2f..%.2f" % [b * 2.0, b * 2.0 + 2.0, e[0], e[1], e[2], e[3]])
	quit(0)
