extends SceneTree
## QA: colours of the vpbr surfaces by paint code (COLOR.rgb as stored) and the biggest fixed colours by area.
func _initialize() -> void:
	for f: String in ["traffic/sedan/lod0_body.res", "traffic/sedan/lod1_body.res", "traffic/sedan/lod2_body.res", "player/limousine/lod0_body.res", "player/limousine/wheel.res", "traffic/sedan/wheel.res", "props/streetlight/lod0_body.res", "props/tree_oak/lod0_body.res"]:
		var mesh := load("res://assets/models/" + f) as ArrayMesh
		for s in mesh.get_surface_count():
			if str(mesh.surface_get_name(s)) != "vpbr":
				continue
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var by := {}
			var t := 0
			while t + 2 < idx.size():
				var i0 := idx[t]
				var ar := (verts[idx[t + 1]] - verts[i0]).cross(verts[idx[t + 2]] - verts[i0]).length() * 0.5
				var c := cols[i0]
				var lamp := "lamp %d" % int(floor(uv2[i0].x)) if uv2[i0].x >= 0.0 else "-"
				var key := "code %.2f  #%s  rough %.2f metal %.2f  %s" % [c.a, c.to_html(false), uv[i0].x, uv[i0].y, lamp]
				by[key] = float(by.get(key, 0.0)) + ar
				t += 3
			var keys: Array = by.keys()
			keys.sort_custom(func(a: String, b: String) -> bool: return by[a] > by[b])
			print("== %s [vpbr]: %d colour/material combinations" % [f, keys.size()])
			for k: String in keys.slice(0, 14):
				print("   %8.3f m2  %s" % [by[k], k])
	quit(0)
