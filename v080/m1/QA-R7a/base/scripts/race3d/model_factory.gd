class_name ModelFactory
extends RefCounted
## Builds scene nodes from the models of ModelDB (docs/modelle.md): used by the vehicle layer, the prop
## layer, the showroom and the contact sheet. Static helpers; materials come from a ModernMaterials instance.
##
## Node tree of build() (contract 4.6.2):
##   <root Node3D, name = model id with "_">        meta: set, model_id, lod, wheels (Array[NodePath]), lights
##     body                MeshInstance3D           vehicles: everything that does not turn; props: all
##     wheel_<axle><l|r>   MeshInstance3D           pivot = wheel centre, spin about local X, steer about Y
##     shadow              MeshInstance3D           only if the model has a caster: SHADOWS_ONLY, and the
##                                                  visible meshes then do not cast
## Articulated vehicles (manifest "groups", e.g. the semitrailer: tractor and trailer with their pivots) can be built
## with build(…, articulated = true): the parts of a group ("tractor/body", "trailer/wheel_0l" …) then hang under a
## Node3D per group placed at the group's pivot (meta "groups": [{name, pivot, path}], leading unit first) – turning
## that node turns the unit about its pivot. Without the flag the tree stays flat, as before.
## Meshes are shared (ModelDB cache) and carry their class materials on the surfaces; everything per
## instance is an instance uniform of the node: paint, paint2, paint3, lamp_a, lamp_b, fade, sun.
## The helpers apply_paint(), set_lamps() and set_instance_parameter() reach every mesh of the tree (also those
## under group nodes).
## Stand-in of a vehicle set without a model ("fallback": "box"): build_box() – a two-box body of the set's size in
## its paint, with dark windows, wheels and lamps on the lamp channels of the vertex format, so the same instance
## uniforms (lamps, fade, sun) drive it; meta "lights" = anchors like a model's lights[].
## Owner: R3 in wave 1 (PIPE in wave 0). Docs: docs/modelle.md §7, docs/renderer-modern.md §10.

const PAINT_KEYS: Array[String] = ["paint", "paint2", "paint3"]
## Stand-in colours (sRGB) of the box vehicle.
const BOX_WINDOW := Color("1b2128")
const BOX_TYRE := Color("161616")
const BOX_HUB := Color("8c9095")
const BOX_TRIM := Color("2a2c2f")
const BOX_LAMP_TAIL := Color("ff2010")
const BOX_LAMP_IND := Color("ffa01a")
const BOX_LAMP_HEAD := Color("fff3d6")
const BOX_PLATE := Color("eeeeea")
const BOX_BEACON := Color("2a6bff")

static var _box_meshes: Dictionary = {}     ## "kind|w|l|h" -> ArrayMesh


## Level a set is shown at when the caller names none: the set's own level ("show" of the showroom sets), else
## lod0. build() and multimesh_parts() resolve "" the same way.
static func level_of(resolved: Dictionary, lod: String) -> String:
	if lod != "":
		return lod
	var own := str(resolved.get("lod", ""))
	return own if own != "" else "lod0"


## Node tree of a sprite set at a level ("" = the set's own level or lod0). null if the set has no model
## (stand-ins are the renderer's business), the level does not exist, or ANY mesh of the level – a part or the
## shadow caster – cannot be loaded: never half a model (a car of four wheels without its body). The caller then
## shows the stand-in; ModelDB.missing() names the files.
static func build(set_id: String, lod: String, mats: ModernMaterials, articulated: bool = false) -> Node3D:
	var r := ModelDB.resolve(set_id)
	var model: Dictionary = r.get("model", {})
	if model.is_empty():
		return null
	var lod_name := level_of(r, lod)
	var entry := ModelDB.lod(model, lod_name)
	if entry.is_empty() or (entry.get("parts", []) as Array).is_empty():
		return null
	var has_caster := model.has("shadow") and lod_name != "shadow"
	var meshes: Array[ArrayMesh] = []
	for p: Variant in entry.get("parts", []):
		var part: Dictionary = p
		var mesh := surfaced_mesh(str(part.get("mesh", "")), part.get("classes", []), model, mats)
		if mesh == null:
			return null
		meshes.append(mesh)
	var smesh: ArrayMesh = null
	if has_caster:
		smesh = surfaced_mesh(str((model["shadow"] as Dictionary).get("mesh", "")), ["vpbr"], model, mats)
		if smesh == null:
			return null
	var root := Node3D.new()
	root.name = str(r["model_id"]).replace("/", "_")
	var wheels: Array[NodePath] = []
	var parts: Array = entry.get("parts", [])
	# articulated units: one node per group at its pivot (only when the level really has grouped parts)
	var group_nodes: Dictionary = {}       ## group name -> Node3D
	var group_info: Array = []
	if articulated:
		for g: Dictionary in groups_of(model, entry):
			var gn := Node3D.new()
			gn.name = str(g["name"])
			gn.position = g["pivot"]
			root.add_child(gn)
			group_nodes[str(g["name"])] = gn
			group_info.append({"name": str(g["name"]), "pivot": g["pivot"], "path": NodePath(gn.name)})
	for i in parts.size():
		var part: Dictionary = parts[i]
		var mi := MeshInstance3D.new()
		var node_name := str(part.get("node", "body"))
		var parent: Node3D = root
		var tr := part_transform(part)
		var slash := node_name.find("/")
		if slash > 0 and group_nodes.has(node_name.substr(0, slash)):
			parent = group_nodes[node_name.substr(0, slash)]
			tr.origin -= parent.position
			node_name = node_name.substr(slash + 1)
		mi.name = node_name
		mi.mesh = meshes[i]
		mi.transform = tr
		if has_caster:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		if part.has("wheel"):
			wheels.append(NodePath(mi.name) if parent == root else NodePath("%s/%s" % [parent.name, mi.name]))
	if has_caster:
		var si := MeshInstance3D.new()
		si.name = "shadow"
		si.mesh = smesh
		si.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		root.add_child(si)
	root.set_meta("set", set_id)
	root.set_meta("model_id", str(r["model_id"]))
	root.set_meta("lod", lod_name)
	root.set_meta("wheels", wheels)
	root.set_meta("lights", model.get("lights", []))
	if articulated:
		root.set_meta("groups", group_info)
	apply_paint(root, r.get("paint", {}))
	return root


## The articulated units of a model's level, leading unit first: [{"name", "pivot": Vector3 (model space),
## "front_z": the front-most wheel of the unit}] – only groups of the manifest ("groups": {name: {"pivot": […]}})
## that really have parts "<name>/…" in this level (a merged far level has none: it is rigid).
static func groups_of(model: Dictionary, entry: Dictionary) -> Array:
	var out: Array = []
	var groups: Variant = model.get("groups", {})
	if not (groups is Dictionary):
		return out
	for gname: Variant in groups:
		var g: Variant = (groups as Dictionary)[gname]
		if not (g is Dictionary):
			continue
		var pv: Variant = (g as Dictionary).get("pivot", [])
		if not (pv is Array) or (pv as Array).size() < 3:
			continue
		var front := INF
		var found := false
		for p: Variant in entry.get("parts", []):
			var node := str((p as Dictionary).get("node", ""))
			if not node.begins_with(str(gname) + "/"):
				continue
			found = true
			var pos: Variant = (p as Dictionary).get("pos", null)
			if (p as Dictionary).has("wheel") and pos is Array and (pos as Array).size() >= 3:
				front = minf(front, float(pos[2]))
		if found:
			out.append({"name": str(gname), "pivot": Vector3(float(pv[0]), float(pv[1]), float(pv[2])), "front_z": front})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["front_z"]) < float(b["front_z"]))
	return out


## Mesh + material pairs of a level for MultiMesh layers:
## [{"node", "mesh": ArrayMesh (class materials on its surfaces when mats is given), "classes": Array,
##   "transform": Transform3D (pose of the part in the model), "shadow": bool}].
## The entry with "shadow" = true is the model's low-poly caster (if it has one).
## lod "" = the set's own level or lod0, as in build(). [] if the set has no model, the level does not exist or
## any mesh of it cannot be loaded (as build(): never half a model).
static func multimesh_parts(set_id: String, lod: String, mats: ModernMaterials = null) -> Array:
	var out: Array = []
	var r := ModelDB.resolve(set_id)
	var model: Dictionary = r.get("model", {})
	if model.is_empty():
		return out
	var entry := ModelDB.lod(model, level_of(r, lod))
	for p: Variant in entry.get("parts", []):
		var part: Dictionary = p
		var mesh := surfaced_mesh(str(part.get("mesh", "")), part.get("classes", []), model, mats)
		if mesh == null:
			return []
		out.append({"node": str(part.get("node", "body")), "mesh": mesh, "classes": part.get("classes", []),
			"transform": part_transform(part), "shadow": false})
	if model.has("shadow") and not out.is_empty():
		var smesh := surfaced_mesh(str((model["shadow"] as Dictionary).get("mesh", "")), ["vpbr"], model, mats)
		if smesh == null:
			return []
		out.append({"node": "shadow", "mesh": smesh, "classes": ["vpbr"], "transform": Transform3D.IDENTITY, "shadow": true})
	return out


## Cached mesh with the class materials of `mats` set on its surfaces (surface names = classes). A "vpbr" surface of
## a model that is not a vehicle gets ModernMaterials.VPBR_STATIC (no instance uniforms, M2INT – class_for()).
static func surfaced_mesh(rel_path: String, classes: Array, model: Dictionary, mats: ModernMaterials) -> ArrayMesh:
	var mesh := ModelDB.mesh(rel_path)
	if mesh == null:
		return null
	if mats != null:
		for s in mesh.get_surface_count():
			var cls := str(mesh.surface_get_name(s))
			if cls == "" and s < classes.size():
				cls = str(classes[s])
			var want := mats.material(ModernMaterials.class_for(cls, model), model)
			if mesh.surface_get_material(s) != want:
				mesh.surface_set_material(s, want)
	return mesh


## Pose of a part: "pos" (model space) and "yaw_deg" about Y (left wheels: 180).
static func part_transform(part: Dictionary) -> Transform3D:
	var t := Transform3D.IDENTITY
	if part.has("yaw_deg"):
		t.basis = Basis(Vector3.UP, deg_to_rad(float(part["yaw_deg"])))
	var pos: Variant = part.get("pos", null)
	if pos is Array and (pos as Array).size() >= 3:
		t.origin = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	return t


## Paint of a set on every mesh of a built model: {"paint": "#rrggbb", "paint2", "paint3", "metal": 0..1}.
## The alpha of a paint uniform is the metallic value of that paint.
static func apply_paint(root: Node3D, paint: Dictionary) -> void:
	var metal := float(paint.get("metal", 0.3))
	for gi: GeometryInstance3D in geometry_of(root):
		for k: String in PAINT_KEYS:
			if paint.has(k):
				var col := Color(str(paint[k]))
				col.a = metal
				gi.set_instance_shader_parameter(k, col)


## Lamp levels (0..1) on every mesh of a built model: lamp_a = (tail, brake, indicator left, indicator
## right), lamp_b = (head, reverse, beacon A, beacon B).
static func set_lamps(root: Node3D, lamp_a: Vector4, lamp_b: Vector4) -> void:
	for gi: GeometryInstance3D in geometry_of(root):
		gi.set_instance_shader_parameter("lamp_a", lamp_a)
		gi.set_instance_shader_parameter("lamp_b", lamp_b)


## Instance uniform on every mesh of a built model ("fade", "sun").
static func set_instance_parameter(root: Node3D, param: String, value: Variant) -> void:
	for gi: GeometryInstance3D in geometry_of(root):
		gi.set_instance_shader_parameter(param, value)


## Every GeometryInstance3D of a built model: the children of the root and of its group nodes (articulated units).
static func geometry_of(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for c: Node in root.get_children():
		if c is GeometryInstance3D:
			out.append(c)
		elif c.get_child_count() > 0:
			out.append_array(geometry_of(c))
	return out


# --- stand-in of a vehicle without a model ("fallback": "box") -----------------------------------------------------

## Kind of box a set gets: "heavy" (long vehicles: buses, trucks), "van" (tall), else "car"; police sets carry
## the beacon bar ("police" in the second element).
static func box_kind(set_id: String, obj: Dictionary) -> Array:
	var l := float(obj.get("length_m", 4.5))
	var h := float(obj.get("height_m", 1.5))
	var kind := "car"
	if l > 7.0:
		kind = "heavy"
	elif h > 2.0:
		kind = "van"
	return [kind, set_id.begins_with("police/")]


## Node of the stand-in of a vehicle set without a model: root (meta set, model_id "", lod "box", wheels [], lights,
## box true) / body (MeshInstance3D, vpbr). null when the set has no "box" stand-in and no model either (unknown set)
## or no size. The set's paint is applied; lamps, fade and sun are the same instance uniforms as on a model.
static func build_box(set_id: String, mats: ModernMaterials) -> Node3D:
	var r := ModelDB.resolve(set_id)
	var obj: Dictionary = r.get("object", {})
	if r.is_empty() or not obj.has("length_m") or not obj.has("width_m"):
		return null
	var kb := box_kind(set_id, obj)
	var mesh := box_mesh(obj, str(kb[0]), bool(kb[1]))
	if mats != null:
		var want := mats.material("vpbr")
		if mesh.surface_get_material(0) != want:
			mesh.surface_set_material(0, want)
	var root := Node3D.new()
	root.name = set_id.replace("/", "_") + "_box"
	var mi := MeshInstance3D.new()
	mi.name = "body"
	mi.mesh = mesh
	root.add_child(mi)
	root.set_meta("set", set_id)
	root.set_meta("model_id", "")
	root.set_meta("lod", "box")
	root.set_meta("wheels", [] as Array[NodePath])
	root.set_meta("lights", box_lights(obj, str(kb[0]), bool(kb[1])))
	root.set_meta("box", true)
	apply_paint(root, r.get("paint", {}))
	return root


## Heights of the box body: [sill, front (hood) top, belt line, rear (trunk) top] in m.
static func _box_heights(h: float, kind: String) -> PackedFloat32Array:
	if kind == "heavy":
		return PackedFloat32Array([0.38, h, h, h])
	if kind == "van":
		return PackedFloat32Array([0.24, 0.42 * h, 0.5 * h, 0.5 * h])
	return PackedFloat32Array([0.2, 0.5 * h, 0.6 * h, 0.58 * h])


## Lamp anchors of the box (manifest format of lights[]: role, pos, dir, size, color): rear lamps (tail and brake at
## the same place), indicators at both ends, headlights, the beacons of a police car.
static func box_lights(obj: Dictionary, kind: String, police: bool) -> Array:
	var w := float(obj.get("width_m", 1.8))
	var l := float(obj.get("length_m", 4.5))
	var h := float(obj.get("height_m", 1.5))
	var hs := _box_heights(h, kind)
	var hw := w * 0.5
	var zr := l * 0.5 + 0.01
	var zf := -l * 0.5 - 0.01
	var yr := 0.95 if kind == "heavy" else float(hs[3]) - 0.105
	var yf := 0.85 if kind == "heavy" else float(hs[1]) - 0.1
	var out: Array = []
	for side: float in [-1.0, 1.0]:
		var xr := side * (hw - 0.27)
		out.append({"role": "tail", "pos": [xr, yr, zr], "dir": [0, 0, 1], "size": 0.34, "color": BOX_LAMP_TAIL.to_html(false)})
		out.append({"role": "brake", "pos": [xr, yr, zr], "dir": [0, 0, 1], "size": 0.34, "color": BOX_LAMP_TAIL.to_html(false)})
		var ind := "ind_l" if side < 0.0 else "ind_r"
		out.append({"role": ind, "pos": [side * (hw - 0.1), yr - 0.14, zr], "dir": [0, 0, 1], "size": 0.12, "color": BOX_LAMP_IND.to_html(false)})
		out.append({"role": ind, "pos": [side * (hw - 0.06), yf, zf], "dir": [0, 0, -1], "size": 0.1, "color": BOX_LAMP_IND.to_html(false)})
		out.append({"role": "head", "pos": [side * (hw - 0.3), yf, zf], "dir": [0, 0, -1], "size": 0.3, "color": BOX_LAMP_HEAD.to_html(false)})
	if police:
		out.append({"role": "beacon_a", "pos": [-0.3, h + 0.13, 0.0], "dir": [0, 1, 0], "size": 0.3, "color": BOX_BEACON.to_html(false)})
		out.append({"role": "beacon_b", "pos": [0.3, h + 0.13, 0.0], "dir": [0, 1, 0], "size": 0.3, "color": BOX_BEACON.to_html(false)})
	return out


## Mesh of the box stand-in in the vertex format VPBR-L (one "vpbr" surface, flat shaded), cached per size and kind.
static func box_mesh(obj: Dictionary, kind: String, police: bool) -> ArrayMesh:
	var w := float(obj.get("width_m", 1.8))
	var l := float(obj.get("length_m", 4.5))
	var h := float(obj.get("height_m", 1.5))
	var key := "%s|%s|%.3f|%.3f|%.3f" % [kind, police, w, l, h]
	if _box_meshes.has(key):
		return _box_meshes[key]
	var b := _BoxBuilder.new()
	var hs := _box_heights(h, kind)
	var y0 := float(hs[0])
	var hw := w * 0.5
	var hl := l * 0.5
	var paint := Color(0, 0, 0, 0.0)          # paint code 0: the instance colour
	var r_wheel := 0.5 if kind == "heavy" else clampf(0.215 * h, 0.27, 0.42)
	if kind == "heavy":
		# one long body; window band along both sides and the windscreen; the lamp band at the rear
		b.box(Vector3(-hw, y0, -hl), Vector3(hw, h, hl), paint, 0.35, 0.1)
		var wy0 := 0.45 * h
		var wy1 := 0.84 * h
		b.side_band(-hw - 0.004, -hl + 0.5, hl - 0.9, wy0, wy1, BOX_WINDOW, -1.0)
		b.side_band(hw + 0.004, -hl + 0.5, hl - 0.9, wy0, wy1, BOX_WINDOW, 1.0)
		b.end_rect(-hl - 0.004, -hw + 0.12, hw - 0.12, 0.42 * h, 0.9 * h, BOX_WINDOW, -1.0, -1.0, 0.0)
		b.end_rect(hl + 0.004, -hw + 0.1, hw - 0.1, 0.25, 0.55, BOX_TRIM, 1.0, -1.0, 0.0)
		# lamps at the anchors of box_lights(): rear lamps, indicators, headlights
		for side: float in [-1.0, 1.0]:
			var xr := side * (hw - 0.27)
			b.end_rect(hl + 0.006, xr - 0.17, xr + 0.17, 0.95 - 0.07, 0.95 + 0.07, BOX_LAMP_TAIL, 1.0, 2.0, 1.0)
			var xi := side * (hw - 0.1)
			b.end_rect(hl + 0.006, xi - 0.06, xi + 0.06, 0.95 - 0.14 - 0.05, 0.95 - 0.14 + 0.05, BOX_LAMP_IND, 1.0, 3.0 if side < 0.0 else 4.0, 1.0)
			var xh := side * (hw - 0.3)
			b.end_rect(-hl - 0.006, xh - 0.15, xh + 0.15, 0.85 - 0.07, 0.85 + 0.07, BOX_LAMP_HEAD, -1.0, 5.0, 1.0)
			var xf := side * (hw - 0.06)
			b.end_rect(-hl - 0.006, xf - 0.05, xf + 0.05, 0.85 - 0.06, 0.85 + 0.06, BOX_LAMP_IND, -1.0, 3.0 if side < 0.0 else 4.0, 1.0)
		for axle_z: float in [-hl + 2.6, hl - 3.2]:
			for side: float in [-1.0, 1.0]:
				b.wheel(Vector3(side * (hw - 0.3), r_wheel, axle_z), r_wheel, 0.32, side)
	else:
		var yf := float(hs[1])
		var belt := float(hs[2])
		var yr := float(hs[3])
		var hood := 0.1 if kind == "van" else 0.16
		var deck := 0.06 if kind == "van" else 0.1
		# lower body (full width): side profile front-bottom, front-top, hood end, deck start, rear-top, rear-bottom
		var low := PackedVector2Array([Vector2(-hl, y0), Vector2(-hl, yf), Vector2(-hl + hood * l, belt), Vector2(hl - deck * l, belt),
			Vector2(hl, yr), Vector2(hl, y0)])
		b.prism(low, -hw, hw, paint, 0.35, 0.1)
		# greenhouse (narrower, windows all round, painted roof)
		var g0 := -hl + (0.2 if kind == "van" else 0.3) * l
		var g1 := -hl + (0.3 if kind == "van" else 0.46) * l
		var g2 := hl - (0.08 if kind == "van" else 0.3) * l
		var g3 := hl - (0.04 if kind == "van" else 0.15) * l
		var top := PackedVector2Array([Vector2(g0, belt), Vector2(g1, h), Vector2(g2, h), Vector2(g3, belt)])
		b.greenhouse(top, hw * 0.94, hw * 0.84, BOX_WINDOW, paint)
		# lamps: rear lamps (tail + brake), indicators, plate; headlights and indicators at the front
		for side: float in [-1.0, 1.0]:
			var x0 := side * (hw - 0.44)
			var x1 := side * (hw - 0.1)
			b.end_rect(hl + 0.004, minf(x0, x1), maxf(x0, x1), yr - 0.17, yr - 0.04, BOX_LAMP_TAIL, 1.0, 2.0, 1.0)
			var i0 := side * (hw - 0.16)
			var i1 := side * (hw - 0.04)
			b.end_rect(hl + 0.004, minf(i0, i1), maxf(i0, i1), yr - 0.3, yr - 0.19, BOX_LAMP_IND, 1.0, 3.0 if side < 0.0 else 4.0, 1.0)
			var h0 := side * (hw - 0.46)
			var h1 := side * (hw - 0.12)
			b.end_rect(-hl - 0.004, minf(h0, h1), maxf(h0, h1), yf - 0.16, yf - 0.04, BOX_LAMP_HEAD, -1.0, 5.0, 1.0)
			var f0 := side * (hw - 0.11)
			var f1 := side * (hw - 0.03)
			b.end_rect(-hl - 0.004, minf(f0, f1), maxf(f0, f1), yf - 0.16, yf - 0.04, BOX_LAMP_IND, -1.0, 3.0 if side < 0.0 else 4.0, 1.0)
		b.end_rect(hl + 0.004, -0.26, 0.26, yr - 0.36, yr - 0.25, BOX_PLATE, 1.0, 8.0, 1.0)
		b.end_rect(-hl - 0.004, -0.4, 0.4, y0 + 0.02, y0 + 0.14, BOX_TRIM, -1.0, -1.0, 0.0)
		var wb := hl - (0.8 if kind == "van" else 0.72)
		for axle_z: float in [-wb, wb]:
			for side: float in [-1.0, 1.0]:
				b.wheel(Vector3(side * (hw - 0.14), r_wheel, axle_z), r_wheel, 0.24, side)
		if police:
			b.box(Vector3(-0.55, h, -0.12), Vector3(0.0, h + 0.13, 0.12), BOX_BEACON, 0.2, 0.0, 10.0)
			b.box(Vector3(0.0, h, -0.12), Vector3(0.55, h + 0.13, 0.12), BOX_BEACON, 0.2, 0.0, 11.0)
	var mesh := b.commit()
	_box_meshes[key] = mesh
	return mesh


## Collects flat-shaded faces in the vertex format VPBR-L (COLOR = albedo + paint code, UV = roughness / metallic,
## UV2 = lamp channel + 0.5 / weight).
class _BoxBuilder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	## Quad a b c d (counter-clockwise seen from the front side); colour.a = paint code (1 = fixed colour).
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, rough: float, metal: float, lamp: float = -1.0, weight: float = 0.0) -> void:
		var nn := (b - a).cross(cc - a)
		if nn.length_squared() < 1.0e-12:
			nn = (cc - a).cross(d - a)
		nn = nn.normalized()
		var base := v.size()
		for p: Vector3 in [a, b, cc, d]:
			v.append(p)
			n.append(nn)
			c.append(col)
			uv.append(Vector2(rough, metal))
			uv2.append(Vector2(lamp + 0.5, weight) if lamp >= 0.0 else Vector2(-1.0, 0.0))
		idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))

	func tri(a: Vector3, b: Vector3, cc: Vector3, col: Color, rough: float, metal: float) -> void:
		quad(a, b, cc, cc, col, rough, metal)

	## Axis-aligned box from lo to hi (all six faces facing out).
	func box(lo: Vector3, hi: Vector3, col: Color, rough: float, metal: float, lamp: float = -1.0) -> void:
		var w := 1.0 if lamp >= 0.0 else 0.0
		var x0 := lo.x
		var x1 := hi.x
		var y0 := lo.y
		var y1 := hi.y
		var z0 := lo.z
		var z1 := hi.z
		quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), col, rough, metal, lamp, w)  # +Z
		quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), col, rough, metal, lamp, w)  # -Z
		quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), col, rough, metal, lamp, w)  # +X
		quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), col, rough, metal, lamp, w)  # -X
		quad(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), col, rough, metal, lamp, w)  # +Y
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), col, rough, metal, lamp, w)  # -Y

	## Prism of a convex side profile (points (z, y) in order, front to rear over the top) between x0 and x1.
	func prism(profile: PackedVector2Array, x0: float, x1: float, col: Color, rough: float, metal: float) -> void:
		var m := profile.size()
		for i in range(1, m - 1):
			# side faces as fans (left looks to -X, right to +X)
			var a := profile[0]
			var b := profile[i]
			var d := profile[i + 1]
			tri(Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x1, d.y, d.x), col, rough, metal)
			tri(Vector3(x0, a.y, a.x), Vector3(x0, d.y, d.x), Vector3(x0, b.y, b.x), col, rough, metal)
		for i in m:
			var p := profile[i]
			var q := profile[(i + 1) % m]
			quad(Vector3(x1, p.y, p.x), Vector3(x0, p.y, p.x), Vector3(x0, q.y, q.x), Vector3(x1, q.y, q.x), col, rough, metal)

	## Greenhouse over the belt line: profile (z, y) windscreen base, roof front, roof rear, rear window base;
	## half width hb at the belt, ht at the roof; windows in `glass`, the roof in `roof`.
	func greenhouse(p: PackedVector2Array, hb: float, ht: float, glass: Color, roof: Color) -> void:
		var a := p[0]
		var b := p[1]
		var cc := p[2]
		var d := p[3]
		# windscreen, roof, rear window
		quad(Vector3(hb, a.y, a.x), Vector3(-hb, a.y, a.x), Vector3(-ht, b.y, b.x), Vector3(ht, b.y, b.x), glass, 0.06, 0.0)
		quad(Vector3(ht, b.y, b.x), Vector3(-ht, b.y, b.x), Vector3(-ht, cc.y, cc.x), Vector3(ht, cc.y, cc.x), roof, 0.35, 0.1)
		quad(Vector3(ht, cc.y, cc.x), Vector3(-ht, cc.y, cc.x), Vector3(-hb, d.y, d.x), Vector3(hb, d.y, d.x), glass, 0.06, 0.0)
		# side windows (trapezoids), each side
		for s: float in [-1.0, 1.0]:
			var pa := Vector3(s * hb, a.y, a.x)
			var pb := Vector3(s * ht, b.y, b.x)
			var pc := Vector3(s * ht, cc.y, cc.x)
			var pd := Vector3(s * hb, d.y, d.x)
			if s > 0.0:
				quad(pa, pb, pc, pd, glass, 0.06, 0.0)
			else:
				quad(pa, pd, pc, pb, glass, 0.06, 0.0)

	## A band on a side face at x (facing s = -1 left / +1 right) from z0 to z1, y0 to y1.
	func side_band(x: float, z0: float, z1: float, y0: float, y1: float, col: Color, s: float) -> void:
		if s > 0.0:
			quad(Vector3(x, y0, z1), Vector3(x, y0, z0), Vector3(x, y1, z0), Vector3(x, y1, z1), col, 0.06, 0.0)
		else:
			quad(Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0), col, 0.06, 0.0)

	## A rectangle on an end face at z (facing s = +1 rear / -1 front), x0..x1, y0..y1, optionally a lamp channel.
	func end_rect(z: float, x0: float, x1: float, y0: float, y1: float, col: Color, s: float, lamp: float, weight: float) -> void:
		var rough := 0.12 if lamp >= 0.0 else 0.4
		if s > 0.0:
			quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), col, rough, 0.0, lamp, weight)
		else:
			quad(Vector3(x1, y0, z), Vector3(x0, y0, z), Vector3(x0, y1, z), Vector3(x1, y1, z), col, rough, 0.0, lamp, weight)

	## Wheel: an octagonal tyre (axis X) with a hub disc on the outer face (side -1 left, +1 right).
	func wheel(centre: Vector3, r: float, width: float, side: float) -> void:
		var seg := 10
		var xo := centre.x + side * width * 0.5
		var xi := centre.x - side * width * 0.5
		for i in seg:
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			var p0 := Vector2(cos(a0), sin(a0)) * r
			var p1 := Vector2(cos(a1), sin(a1)) * r
			var o0 := Vector3(xo, centre.y + p0.y, centre.z + p0.x)
			var o1 := Vector3(xo, centre.y + p1.y, centre.z + p1.x)
			var i0 := Vector3(xi, centre.y + p0.y, centre.z + p0.x)
			var i1 := Vector3(xi, centre.y + p1.y, centre.z + p1.x)
			# tread (facing out from the axis)
			if side > 0.0:
				quad(i0, o0, o1, i1, BOX_TYRE, 0.9, 0.0)
			else:
				quad(o0, i0, i1, o1, BOX_TYRE, 0.9, 0.0)
			# outer face: tyre ring and hub
			var hub0 := Vector3(xo + side * 0.005, centre.y + p0.y * 0.62, centre.z + p0.x * 0.62)
			var hub1 := Vector3(xo + side * 0.005, centre.y + p1.y * 0.62, centre.z + p1.x * 0.62)
			var cen := Vector3(xo + side * 0.005, centre.y, centre.z)
			if side > 0.0:
				quad(o0, hub0, hub1, o1, BOX_TYRE, 0.9, 0.0)
				tri(cen, hub1, hub0, BOX_HUB, 0.35, 0.8)
			else:
				quad(o1, hub1, hub0, o0, BOX_TYRE, 0.9, 0.0)
				tri(cen, hub0, hub1, BOX_HUB, 0.35, 0.8)

	func commit() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_name(0, "vpbr")
		return mesh


## Quad for billboard.gdshader: x = 0 is the anchor column, y = 0 the ground; width_m x height_m,
## anchor_x = position of the anchor inside the picture (0..1 from the left).
static func billboard_mesh(width_m: float, height_m: float, anchor_x: float = 0.5) -> ArrayMesh:
	var x0 := -anchor_x * width_m
	var x1 := (1.0 - anchor_x) * width_m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x0, 0.0, 0.0), Vector3(x1, 0.0, 0.0), Vector3(x1, height_m, 0.0), Vector3(x0, height_m, 0.0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# the shader turns the quad about the anchor: bounds for every direction
	var r := maxf(absf(x0), absf(x1))
	mesh.custom_aabb = AABB(Vector3(-r, 0.0, -r), Vector3(2.0 * r, height_m, 2.0 * r))
	return mesh


## Impostor of a model as a billboard node (null if the model has none or its texture cannot be loaded): the
## far level of card trees.
static func build_impostor(set_id: String, mats: ModernMaterials) -> MeshInstance3D:
	var model: Dictionary = ModelDB.resolve(set_id).get("model", {})
	if not model.has("impostor"):
		return null
	var imp: Dictionary = model["impostor"]
	if ModelDB.texture(str(imp.get("texture", ""))) == null:
		return null
	var size: Array = imp.get("size_m", [1.0, 1.0])
	var mi := MeshInstance3D.new()
	mi.name = "impostor"
	mi.mesh = billboard_mesh(float(size[0]), float(size[1]), float(imp.get("anchor_x", 0.5)))
	mi.material_override = mats.billboard(ModelDB.texture(str(imp.get("texture", ""))))
	return mi
