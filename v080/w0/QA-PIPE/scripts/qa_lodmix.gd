extends SceneTree
## QA: automatic mesh levels (ImporterMesh.generate_lods) of vpbr surfaces: do their triangles mix vertices with
## different lamp channels / paint codes? (the codes are flat varyings: a mixed triangle takes one vertex's code)

func _initialize() -> void:
	for f: String in ["props/streetlight/lod0_body.res", "player/limousine/wheel.res", "player/limousine/show_wheel.res", "traffic/sedan/wheel.res", "props/farmhouse/lod0_body.res", "landmarks/michel/lod0_body.res"]:
		var mesh := load("res://assets/models/" + f) as ArrayMesh
		var stored: Array = mesh.get("_surfaces")
		for s in mesh.get_surface_count():
			var st: Dictionary = stored[s]
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv2: Variant = arr[Mesh.ARRAY_TEX_UV2]
			var cols: Variant = arr[Mesh.ARRAY_COLOR]
			var uvs: Variant = arr[Mesh.ARRAY_TEX_UV]
			var lods: Array = st.get("lods", [])
			var wide := verts.size() > 65535
			var base_idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			print("== %s [%s] %d vertices, level 0: %d triangles, %d automatic levels" % [f, str(mesh.surface_get_name(s)), verts.size(), base_idx.size() / 3, lods.size() / 2])
			var i := 0
			while i + 1 < lods.size():
				var edge := float(lods[i])
				var data: PackedByteArray = lods[i + 1]
				var n := data.size() / (4 if wide else 2)
				var mixed_lamp := 0
				var mixed_area := 0.0
				var lamp_area := 0.0
				var lamp_area_first := 0.0
				var lamp_area_last := 0.0
				var mixed_rm := 0
				var total_area := 0.0
				var longest := 0.0
				var t := 0
				while t + 2 < n:
					var a := data.decode_u32(t * 4) if wide else data.decode_u16(t * 2)
					var b := data.decode_u32((t + 1) * 4) if wide else data.decode_u16((t + 1) * 2)
					var c := data.decode_u32((t + 2) * 4) if wide else data.decode_u16((t + 2) * 2)
					t += 3
					var ar := (verts[b] - verts[a]).cross(verts[c] - verts[a]).length() * 0.5
					total_area += ar
					if uv2 != null:
						var u: PackedVector2Array = uv2
						var la := floorf(u[a].x)
						var lb := floorf(u[b].x)
						var lc := floorf(u[c].x)
						if la != lb or la != lc:
							mixed_lamp += 1
							mixed_area += ar
							longest = maxf(longest, maxf(verts[a].distance_to(verts[b]), maxf(verts[b].distance_to(verts[c]), verts[a].distance_to(verts[c]))))
						if u[a].x >= 0.0:
							lamp_area_first += ar
						if u[c].x >= 0.0:
							lamp_area_last += ar
						if la >= 0.0 and la == lb and la == lc:
							lamp_area += ar
					if uvs != null and str(mesh.surface_get_name(s)) == "vpbr":
						var w: PackedVector2Array = uvs
						if w[a].distance_to(w[b]) > 0.01 or w[a].distance_to(w[c]) > 0.01:
							mixed_rm += 1
				print("   level edge %.3f m: %5d triangles, area %.2f m2 | triangles mixing lamp channels: %d (%.3f m2, longest edge %.2f m) | lamp area if the FIRST vertex decides %.3f m2, if the LAST %.3f m2, pure lamp triangles %.3f m2 | mixing roughness/metal: %d" % [
					edge, n / 3, total_area, mixed_lamp, mixed_area, longest, lamp_area_first, lamp_area_last, lamp_area, mixed_rm])
				i += 2
	quit(0)
