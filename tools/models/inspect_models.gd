extends SceneTree
## Decodes the baked model files for tools/blender/validate_models.py (docs/modelle.md):
##   godot --headless --path . -s res://tools/models/inspect_models.gd -- --out=<file.json> [--manifest=<path>]
## For every mesh of the manifest: surfaces (name, format flags, vertices, triangles, LOD count), bounds,
## the distinct paint codes (COLOR.a) and lamp channels (UV2) of vpbr surfaces, the UV range of baked and
## leaves surfaces, the lowest point (wheels), file size. For every texture: size, format, mipmaps.
## Per vpbr surface also
##   lamps    {"<channel>|<end>": {tris, area, back, front, side, bounds}} - end = "rear" (centre at z > 0) or
##            "front"; area in m2; back / front / side = projected area seen from straight behind (+Z), from
##            straight ahead (-Z) and from the side (|X|), by the winding of the triangles; bounds = [min x,
##            min y, min z, max x, max y, max z]. What a lamp shows to the following driver is its "back" area.
##   lamp_lods  the same per automatic level (index buffers of the decimated mesh): [{"<channel>": area}, ...]
##   winding  {total, against}: triangles whose winding faces against their vertex normals (inside out)
## Per model: "anchors" - for every light anchor of the manifest the distance to the nearest triangle of lod0
## that carries a lamp channel of its role, and whether the anchor lies below that surface.
## Nothing is judged here - the validator does that.

func _initialize() -> void:
	var out := ""
	var manifest := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--manifest="):
			manifest = a.substr(11)
	if manifest != "":
		ModelDB.load_manifest(manifest)
	var report := {"available": ModelDB.available(), "meshes": {}, "textures": {}, "anchors": {}}
	if ModelDB.available():
		for mid: String in ModelDB.model_ids():
			for f: String in ModelDB.files_of(mid):
				if f.ends_with(".res"):
					if not (report["meshes"] as Dictionary).has(f):
						report["meshes"][f] = _mesh(f)
				elif not (report["textures"] as Dictionary).has(f):
					report["textures"][f] = _texture(f)
			var anchors := _anchors(ModelDB.model(mid))
			if not anchors.is_empty():
				report["anchors"][mid] = anchors
	var text := JSON.stringify(report, " ", true)
	if out == "":
		print(text)
	else:
		var fh := FileAccess.open(out, FileAccess.WRITE)
		fh.store_string(text + "\n")
		fh.close()
	quit(0)


func _mesh(rel: String) -> Dictionary:
	var mesh := ModelDB.mesh(rel)
	if mesh == null:
		return {"missing": true}
	var d := {"surfaces": [], "bytes": FileAccess.get_file_as_bytes(ModelDB.ROOT + rel).size(), "has_materials": false}
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	# the stored surfaces carry the automatic levels (index buffers of a decimated mesh) - an ArrayMesh has
	# no other way to ask for them
	var stored: Array = mesh.get("_surfaces") if mesh.get("_surfaces") is Array else []
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		var fmt := mesh.surface_get_format(s)
		var sd := {"name": str(mesh.surface_get_name(s)), "verts": verts.size(),
			"tris": ((idx as PackedInt32Array).size() / 3) if idx != null else verts.size() / 3,
			"compressed": (fmt & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) != 0,
			"tangents": arr[Mesh.ARRAY_TANGENT] != null,
			"lods": _lod_count(stored[s]) if s < stored.size() else 0}
		if mesh.surface_get_material(s) != null:
			d["has_materials"] = true
		for v: Vector3 in verts:
			lo = lo.min(v)
			hi = hi.max(v)
		var cols: Variant = arr[Mesh.ARRAY_COLOR]
		var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
		var uv2: Variant = arr[Mesh.ARRAY_TEX_UV2]
		if cols != null:
			var codes := {}
			var amin := 1.0
			var amax := 0.0
			for c: Color in (cols as PackedColorArray):
				codes[snappedf(c.a, 0.001)] = true
				amin = minf(amin, c.a)
				amax = maxf(amax, c.a)
			var keys: Array = codes.keys()
			keys.sort()
			sd["alpha_values"] = keys.slice(0, 64)
			sd["alpha_count"] = keys.size()
			sd["alpha_range"] = [amin, amax]
		if uv != null:
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for u: Vector2 in (uv as PackedVector2Array):
				mn = mn.min(u)
				mx = mx.max(u)
			sd["uv_range"] = [mn.x, mn.y, mx.x, mx.y]
		if uv2 != null:
			var lamps := {}
			var wmin := 1.0
			var wmax := 0.0
			for u: Vector2 in (uv2 as PackedVector2Array):
				lamps[snappedf(u.x, 0.001)] = true
				if u.x >= 0.0:
					wmin = minf(wmin, u.y)
					wmax = maxf(wmax, u.y)
			var lk: Array = lamps.keys()
			lk.sort()
			sd["lamp_values"] = lk.slice(0, 64)
			sd["lamp_weight_range"] = [wmin, wmax]
			if idx != null:
				sd["lamps"] = _lamp_areas(verts, uv2, idx)
				var levels: Array = []
				if s < stored.size() and stored[s] is Dictionary:
					var raw: Variant = (stored[s] as Dictionary).get("lods", [])
					if raw is Array:
						for li in range(1, (raw as Array).size(), 2):
							levels.append(_lamp_totals(verts, uv2, _indices_of(raw[li], verts.size())))
				sd["lamp_lods"] = levels
		if idx != null and arr[Mesh.ARRAY_NORMAL] != null:
			sd["winding"] = _winding(verts, arr[Mesh.ARRAY_NORMAL], idx)
		(d["surfaces"] as Array).append(sd)
	d["aabb"] = [lo.x, lo.y, lo.z, hi.x, hi.y, hi.z]
	return d


## Number of automatic levels of a stored surface: "lods" is a flat list (edge length, index data, ...).
func _lod_count(surface: Variant) -> int:
	if not surface is Dictionary:
		return 0
	var lods: Variant = (surface as Dictionary).get("lods", [])
	return (lods as Array).size() / 2 if lods is Array else 0


func _texture(rel: String) -> Dictionary:
	var path := ModelDB.ROOT + rel
	var d := {"file_bytes": FileAccess.get_file_as_bytes(path).size(), "import": FileAccess.file_exists(path + ".import")}
	var tex := ModelDB.texture(rel)
	if tex == null:
		d["missing"] = true
		return d
	d["size"] = [tex.get_width(), tex.get_height()]
	var img := tex.get_image()
	if img != null:
		d["format"] = img.get_format()
		d["format_name"] = _format_name(img.get_format())
		d["mipmaps"] = img.has_mipmaps()
		d["vram_bytes"] = img.get_data().size()
	return d


func _format_name(f: int) -> String:
	match f:
		Image.FORMAT_DXT1:
			return "BC1"
		Image.FORMAT_DXT3:
			return "BC2"
		Image.FORMAT_DXT5:
			return "BC3"
		Image.FORMAT_RGTC_R:
			return "BC4"
		Image.FORMAT_RGTC_RG:
			return "BC5"
		Image.FORMAT_BPTC_RGBA:
			return "BC7"
		Image.FORMAT_RGBA8:
			return "RGBA8"
		Image.FORMAT_RGB8:
			return "RGB8"
	return "format %d" % f


# --- lamps, winding, anchors ------------------------------------------------------------------------------------

## Geometric normal times twice the area of a triangle; Godot's front faces are wound clockwise.
func _face(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return -(b - a).cross(c - a)


## Per lamp channel and end of the model: triangles, area, projected areas, bounds (see the file header).
func _lamp_areas(verts: PackedVector3Array, uv2: PackedVector2Array, idx: PackedInt32Array) -> Dictionary:
	var out := {}
	var t := 0
	while t + 2 < idx.size():
		var ia := idx[t]
		var ib := idx[t + 1]
		var ic := idx[t + 2]
		t += 3
		if uv2[ia].x < 0.0:
			continue
		var g := _face(verts[ia], verts[ib], verts[ic])
		var area := g.length() * 0.5
		if area <= 0.0:
			continue
		var n := g / (area * 2.0)
		var cen := (verts[ia] + verts[ib] + verts[ic]) / 3.0
		var key := "%d|%s" % [int(floor(uv2[ia].x)), "rear" if cen.z > 0.0 else "front"]
		var e: Dictionary = out.get(key, {"tris": 0, "area": 0.0, "back": 0.0, "front": 0.0, "side": 0.0,
			"bounds": [INF, INF, INF, -INF, -INF, -INF]})
		e["tris"] = int(e["tris"]) + 1
		e["area"] = float(e["area"]) + area
		e["back"] = float(e["back"]) + area * maxf(n.z, 0.0)
		e["front"] = float(e["front"]) + area * maxf(-n.z, 0.0)
		e["side"] = float(e["side"]) + area * absf(n.x)
		var b: Array = e["bounds"]
		for v: Vector3 in [verts[ia], verts[ib], verts[ic]]:
			b[0] = minf(b[0], v.x)
			b[1] = minf(b[1], v.y)
			b[2] = minf(b[2], v.z)
			b[3] = maxf(b[3], v.x)
			b[4] = maxf(b[4], v.y)
			b[5] = maxf(b[5], v.z)
		out[key] = e
	return out


## Area per lamp channel for one index buffer (an automatic level): {"<channel>": m2}.
func _lamp_totals(verts: PackedVector3Array, uv2: PackedVector2Array, idx: PackedInt32Array) -> Dictionary:
	var out := {}
	var t := 0
	while t + 2 < idx.size():
		var ia := idx[t]
		var ib := idx[t + 1]
		var ic := idx[t + 2]
		t += 3
		if ia >= verts.size() or ib >= verts.size() or ic >= verts.size() or uv2[ia].x < 0.0:
			continue
		var key := str(int(floor(uv2[ia].x)))
		out[key] = float(out.get(key, 0.0)) + _face(verts[ia], verts[ib], verts[ic]).length() * 0.5
	return out


## Index buffer of a stored automatic level: 16-bit while the surface has at most 65,535 vertices, else 32-bit.
func _indices_of(raw: Variant, vertex_count: int) -> PackedInt32Array:
	if raw is PackedInt32Array:
		return raw
	var out := PackedInt32Array()
	if raw is PackedByteArray:
		var bytes: PackedByteArray = raw
		if vertex_count <= 65535:
			for i in range(0, bytes.size() - 1, 2):
				out.append(bytes.decode_u16(i))
		else:
			for i in range(0, bytes.size() - 3, 4):
				out.append(bytes.decode_u32(i))
	return out


## Triangles whose winding faces against the mean of their vertex normals: a surface drawn with back-face culling
## (and a shadow caster) loses them.
func _winding(verts: PackedVector3Array, normals: PackedVector3Array, idx: PackedInt32Array) -> Dictionary:
	var against := 0
	var total := 0
	var t := 0
	while t + 2 < idx.size():
		var ia := idx[t]
		var ib := idx[t + 1]
		var ic := idx[t + 2]
		t += 3
		var g := _face(verts[ia], verts[ib], verts[ic])
		if g.length_squared() <= 1.0e-16:
			continue
		total += 1
		if g.dot(normals[ia] + normals[ib] + normals[ic]) < 0.0:
			against += 1
	return {"total": total, "against": against}


## Closest point of triangle abc to p (Ericson, Real-Time Collision Detection 5.1.5).
func _closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)


## Lamp channels (vpbr UV2) whose triangles an anchor of a role belongs to.
const ROLE_CHANNELS := {"tail": [0, 2], "brake": [1, 2], "ind_l": [3], "ind_r": [4], "head": [5], "marker": [9],
	"beacon_a": [10], "beacon_b": [11], "lights": [12]}


## For every light anchor of a model: {role, pos, dist_mm (to the nearest lamp triangle of its role in lod0; -1 =
## the level has no such triangle - baked models carry their lamps in the atlas), below_mm (> 0: the anchor lies
## that far under the surface there, by the triangle's winding), dir_dot (anchor "dir" . normal of that triangle;
## 2 = the anchor has no direction)}.
func _anchors(model: Dictionary) -> Array:
	var lights: Array = model.get("lights", [])
	if lights.is_empty():
		return []
	var tris := {}          # channel -> PackedVector3Array of triangle corners in model space
	for p: Variant in ModelDB.lod(model, "lod0").get("parts", []):
		var part: Dictionary = p
		var mesh := ModelDB.mesh(str(part.get("mesh", "")))
		if mesh == null:
			continue
		var xf := ModelFactory.part_transform(part)
		for s in mesh.get_surface_count():
			if str(mesh.surface_get_name(s)) != "vpbr":
				continue
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv2: Variant = arr[Mesh.ARRAY_TEX_UV2]
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if uv2 == null or idx == null:
				continue
			var u: PackedVector2Array = uv2
			var ix: PackedInt32Array = idx
			var t := 0
			while t + 2 < ix.size():
				if u[ix[t]].x >= 0.0:
					var ch := int(floor(u[ix[t]].x))
					var list: PackedVector3Array = tris.get(ch, PackedVector3Array())
					list.append(xf * verts[ix[t]])
					list.append(xf * verts[ix[t + 1]])
					list.append(xf * verts[ix[t + 2]])
					tris[ch] = list
				t += 3
	var out: Array = []
	for l: Variant in lights:
		var ld: Dictionary = l
		var lp: Array = ld.get("pos", [0, 0, 0])
		var pos := Vector3(float(lp[0]), float(lp[1]), float(lp[2]))
		var best := INF
		var below := 0.0
		var normal := Vector3.ZERO
		for ch: int in ROLE_CHANNELS.get(str(ld.get("role", "")), []):
			var list: PackedVector3Array = tris.get(ch, PackedVector3Array())
			var i := 0
			while i + 2 < list.size():
				var q := _closest_on_triangle(pos, list[i], list[i + 1], list[i + 2])
				var dist := pos.distance_to(q)
				if dist < best:
					best = dist
					normal = _face(list[i], list[i + 1], list[i + 2]).normalized()
					below = -(pos - q).dot(normal)
				i += 3
		var e := {"role": str(ld.get("role", "")), "pos": lp, "dist_mm": -1.0, "below_mm": 0.0, "dir_dot": 2.0}
		if best < INF:
			e["dist_mm"] = best * 1000.0
			e["below_mm"] = below * 1000.0
			var dir: Variant = ld.get("dir", null)
			if dir is Array and (dir as Array).size() == 3:
				e["dir_dot"] = Vector3(float(dir[0]), float(dir[1]), float(dir[2])).normalized().dot(normal)
		out.append(e)
	return out
