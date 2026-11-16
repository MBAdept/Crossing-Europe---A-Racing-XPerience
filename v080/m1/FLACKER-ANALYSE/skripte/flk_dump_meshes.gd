extends SceneTree
## FLACKER-ANALYSE (scratch only, never committed): dumps the vertex data of every vehicle model level of a manifest –
## per surface: class, vertices, triangles, area per paint code, projected area seen from behind (chase view) per code,
## area-weighted albedo of the fixed-colour parts, lamp channels, roughness / metal, normal sanity.
## usage: godot --headless --path . -s res://flk_dump_meshes.gd -- <models root res://…/> <out.json> [model prefix …]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var root := args[0] if args.size() > 0 else "res://assets/models/"
	var out_path := args[1] if args.size() > 1 else "/tmp/flk_meshes.json"
	var prefixes: Array = args.slice(2) if args.size() > 2 else ["traffic/", "police/", "player/"]
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(root + "manifest.json"))
	var out := {}
	for mid: String in (man["models"] as Dictionary):
		var ok := false
		for p: String in prefixes:
			if mid.begins_with(p):
				ok = true
		if not ok:
			continue
		var md: Dictionary = man["models"][mid]
		var levels := {}
		for l: Dictionary in md.get("lods", []):
			var parts := []
			for p: Dictionary in l.get("parts", []):
				parts.append(_part(root, p))
			levels[str(l["name"])] = {"max_dist_m": l.get("max_dist_m"), "parts": parts}
		if md.has("shadow"):
			levels["shadow"] = {"parts": [_part(root, {"node": "shadow", "mesh": md["shadow"]["mesh"]})]}
		out[mid] = levels
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("FLK done ", out.size(), " models -> ", out_path)
	quit(0)


func _part(root: String, p: Dictionary) -> Dictionary:
	var mesh := load(root + str(p["mesh"])) as ArrayMesh
	var res := {"node": p.get("node", ""), "mesh": p["mesh"], "surfaces": []}
	if mesh == null:
		res["error"] = "load failed"
		return res
	# chase view: the camera looks at the rear of the car ahead (model +Z faces the camera), a little from above
	var views := {"rear": Vector3(0, 0, 1), "rear5": Vector3(0, sin(deg_to_rad(5.0)), cos(deg_to_rad(5.0))),
		"rear_side20": Vector3(sin(deg_to_rad(20.0)), sin(deg_to_rad(4.0)), cos(deg_to_rad(20.0))).normalized()}
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2] if arr[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(v.size())
			for i in v.size():
				idx[i] = i
		var codes := {}          # code name -> {area, proj{view: area}, alb_sum (Color * area), n_tris, alpha values}
		var mixed := 0           # triangles whose three vertices disagree on the paint code
		var flipped := 0         # triangles whose vertex normals point against the face normal
		var alphas := {}
		var lamps := {}
		var aabb := AABB()
		if v.size() > 0:
			aabb = AABB(v[0], Vector3.ZERO)
			for q in v:
				aabb = aabb.expand(q)
		var tri_n := idx.size() / 3
		for t in tri_n:
			var i0 := idx[t * 3]
			var i1 := idx[t * 3 + 1]
			var i2 := idx[t * 3 + 2]
			var a := v[i0]
			var b := v[i1]
			var c := v[i2]
			var cr := (b - a).cross(c - a)
			var area := cr.length() * 0.5
			if area <= 0.0:
				continue
			var fn := cr.normalized()
			# Godot's front face is clockwise: the outward normal of a front face is -cross for CCW … use the vertex normals
			var vn := Vector3.ZERO
			if nrm.size() == v.size():
				vn = (nrm[i0] + nrm[i1] + nrm[i2]).normalized()
				if vn.dot(fn) > 0.0:
					flipped += 1
			var code := "fixed"
			var ca := 1.0
			if col.size() == v.size():
				# provoking vertex of GL: the last vertex of the triangle (flat varying)
				ca = col[i2].a
				var c0 := _code(col[i0].a)
				var c1 := _code(col[i1].a)
				var c2 := _code(col[i2].a)
				if c0 != c1 or c1 != c2:
					mixed += 1
				code = c2
				var key := "%.3f" % ca
				alphas[key] = int(alphas.get(key, 0)) + 1
			var lamp := -1.0
			if uv2.size() == v.size():
				lamp = uv2[i2].x
				if lamp >= 0.0:
					var lk := str(int(floor(lamp)))
					lamps[lk] = float(lamps.get(lk, 0.0)) + area
			var e: Dictionary = codes.get(code, {})
			if e.is_empty():
				e = {"area": 0.0, "tris": 0, "alb": [0.0, 0.0, 0.0], "rough": 0.0, "metal": 0.0, "proj": {}}
				codes[code] = e
			e["area"] = float(e["area"]) + area
			e["tris"] = int(e["tris"]) + 1
			if col.size() == v.size():
				var al: Array = e["alb"]
				al[0] = float(al[0]) + col[i2].r * area
				al[1] = float(al[1]) + col[i2].g * area
				al[2] = float(al[2]) + col[i2].b * area
			if uv.size() == v.size():
				e["rough"] = float(e["rough"]) + uv[i2].x * area
				e["metal"] = float(e["metal"]) + uv[i2].y * area
			# projected area towards the camera: outward normal = vertex normal (robust against winding)
			var on := vn if vn != Vector3.ZERO else -fn
			for vk: String in views:
				var d := on.dot(views[vk] as Vector3)
				if d > 0.0:
					var pr: Dictionary = e["proj"]
					pr[vk] = float(pr.get(vk, 0.0)) + area * d
		for k: String in codes:
			var e: Dictionary = codes[k]
			var ar := maxf(float(e["area"]), 1e-9)
			var al: Array = e["alb"]
			e["alb"] = [snappedf(float(al[0]) / ar, 0.001), snappedf(float(al[1]) / ar, 0.001), snappedf(float(al[2]) / ar, 0.001)]
			e["rough"] = snappedf(float(e["rough"]) / ar, 0.001)
			e["metal"] = snappedf(float(e["metal"]) / ar, 0.001)
			e["area"] = snappedf(float(e["area"]), 0.0001)
			var pr: Dictionary = e["proj"]
			for vk: String in pr:
				pr[vk] = snappedf(float(pr[vk]), 0.0001)
		for lk: String in lamps:
			lamps[lk] = snappedf(float(lamps[lk]), 0.0001)
		res["surfaces"].append({"name": str(mesh.surface_get_name(s)), "verts": v.size(), "tris": tri_n, "codes": codes,
			"mixed_code_tris": mixed, "normal_against_face": flipped, "alpha_values": alphas, "lamp_area": lamps,
			"aabb": [aabb.position.x, aabb.position.y, aabb.position.z, aabb.end.x, aabb.end.y, aabb.end.z],
			"format": mesh.surface_get_format(s)})
	return res


static func _code(a: float) -> String:
	if a < 0.125:
		return "paint"
	if a < 0.375:
		return "paint2"
	if a < 0.75:
		return "paint3"
	if a > 0.8 and a < 0.95:
		return "rotor"
	return "fixed"
