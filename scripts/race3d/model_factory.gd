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
## Meshes are shared (ModelDB cache) and carry their class materials on the surfaces; everything per
## instance is an instance uniform of the node: paint, paint2, paint3, lamp_a, lamp_b, fade, sun.

const PAINT_KEYS: Array[String] = ["paint", "paint2", "paint3"]


## Node tree of a sprite set at a level ("" = the set's own level or lod0). null if the set has no model
## (stand-ins are the renderer's business) or the level does not exist.
static func build(set_id: String, lod: String, mats: ModernMaterials) -> Node3D:
	var r := ModelDB.resolve(set_id)
	var model: Dictionary = r.get("model", {})
	if model.is_empty():
		return null
	var lod_name := lod if lod != "" else (str(r.get("lod", "")) if str(r.get("lod", "")) != "" else "lod0")
	var entry := ModelDB.lod(model, lod_name)
	if entry.is_empty():
		return null
	var root := Node3D.new()
	root.name = str(r["model_id"]).replace("/", "_")
	var wheels: Array[NodePath] = []
	var has_caster := model.has("shadow") and lod_name != "shadow"
	for p: Variant in entry.get("parts", []):
		var part: Dictionary = p
		var mesh := surfaced_mesh(str(part.get("mesh", "")), part.get("classes", []), model, mats)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = str(part.get("node", "body"))
		mi.mesh = mesh
		mi.transform = part_transform(part)
		if has_caster:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		if part.has("wheel"):
			wheels.append(NodePath(mi.name))
	if has_caster:
		var sh: Dictionary = model["shadow"]
		var smesh := surfaced_mesh(str(sh.get("mesh", "")), ["vpbr"], model, mats)
		if smesh != null:
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
	apply_paint(root, r.get("paint", {}))
	return root


## Mesh + material pairs of a level for MultiMesh layers:
## [{"node", "mesh": ArrayMesh (class materials on its surfaces when mats is given), "classes": Array,
##   "transform": Transform3D (pose of the part in the model), "shadow": bool}].
## The entry with "shadow" = true is the model's low-poly caster (if it has one).
static func multimesh_parts(set_id: String, lod: String, mats: ModernMaterials = null) -> Array:
	var out: Array = []
	var r := ModelDB.resolve(set_id)
	var model: Dictionary = r.get("model", {})
	if model.is_empty():
		return out
	var entry := ModelDB.lod(model, lod if lod != "" else "lod0")
	for p: Variant in entry.get("parts", []):
		var part: Dictionary = p
		var mesh := surfaced_mesh(str(part.get("mesh", "")), part.get("classes", []), model, mats)
		if mesh != null:
			out.append({"node": str(part.get("node", "body")), "mesh": mesh, "classes": part.get("classes", []),
				"transform": part_transform(part), "shadow": false})
	if model.has("shadow"):
		var smesh := surfaced_mesh(str((model["shadow"] as Dictionary).get("mesh", "")), ["vpbr"], model, mats)
		if smesh != null:
			out.append({"node": "shadow", "mesh": smesh, "classes": ["vpbr"], "transform": Transform3D.IDENTITY, "shadow": true})
	return out


## Cached mesh with the class materials of `mats` set on its surfaces (surface names = classes).
static func surfaced_mesh(rel_path: String, classes: Array, model: Dictionary, mats: ModernMaterials) -> ArrayMesh:
	var mesh := ModelDB.mesh(rel_path)
	if mesh == null:
		return null
	if mats != null:
		for s in mesh.get_surface_count():
			var cls := str(mesh.surface_get_name(s))
			if cls == "" and s < classes.size():
				cls = str(classes[s])
			var want := mats.material(cls, model)
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
	for c: Node in root.get_children():
		var gi := c as GeometryInstance3D
		if gi == null:
			continue
		for k: String in PAINT_KEYS:
			if paint.has(k):
				var col := Color(str(paint[k]))
				col.a = metal
				gi.set_instance_shader_parameter(k, col)


## Lamp levels (0..1) on every mesh of a built model: lamp_a = (tail, brake, indicator left, indicator
## right), lamp_b = (head, reverse, beacon A, beacon B).
static func set_lamps(root: Node3D, lamp_a: Vector4, lamp_b: Vector4) -> void:
	for c: Node in root.get_children():
		var gi := c as GeometryInstance3D
		if gi != null:
			gi.set_instance_shader_parameter("lamp_a", lamp_a)
			gi.set_instance_shader_parameter("lamp_b", lamp_b)


## Instance uniform on every mesh of a built model ("fade", "sun").
static func set_instance_parameter(root: Node3D, param: String, value: Variant) -> void:
	for c: Node in root.get_children():
		var gi := c as GeometryInstance3D
		if gi != null:
			gi.set_instance_shader_parameter(param, value)


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


## Impostor of a model as a billboard node (null if the model has none): the far level of card trees.
static func build_impostor(set_id: String, mats: ModernMaterials) -> MeshInstance3D:
	var model: Dictionary = ModelDB.resolve(set_id).get("model", {})
	if not model.has("impostor"):
		return null
	var imp: Dictionary = model["impostor"]
	var size: Array = imp.get("size_m", [1.0, 1.0])
	var mi := MeshInstance3D.new()
	mi.name = "impostor"
	mi.mesh = billboard_mesh(float(size[0]), float(size[1]), float(imp.get("anchor_x", 0.5)))
	mi.material_override = mats.billboard(ModelDB.texture(str(imp.get("texture", ""))))
	return mi
