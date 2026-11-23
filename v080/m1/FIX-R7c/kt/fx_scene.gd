extends "res://tools/kritik/my_scene.gd"
## FIX-R7c scratch tool (never committed): my_scene's sparkcam with the props look on the placed model's materials –
## --uni=albedo_bias:1.25,albedo_bias_m:30:120,cutout_bias:2 (the uniforms builders/props.gd PROP_LOOK sets in the race).


func _place(mid: String, lod: String, pos: Vector3, yaw: float = 0.0, scale: float = 1.0, mirror: bool = false) -> Node3D:
	var n := super._place(mid, lod, pos, yaw, scale, mirror)
	if n == null or not _args.has("uni") or lod == "sprite":
		return n
	for gi: Node in n.find_children("*", "GeometryInstance3D", true, false):
		var mats: Array = []
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var mesh := (gi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				mats.append(mesh.surface_get_material(s))
		if (gi as GeometryInstance3D).material_override != null:
			mats.append((gi as GeometryInstance3D).material_override)
		for m: Variant in mats:
			if not (m is ShaderMaterial):
				continue
			for kv: String in str(_args["uni"]).split(",", false):
				var parts := kv.split(":")
				if parts.size() == 2:
					(m as ShaderMaterial).set_shader_parameter(parts[0], float(parts[1]))
				elif parts.size() == 3:
					(m as ShaderMaterial).set_shader_parameter(parts[0], Vector2(float(parts[1]), float(parts[2])))
	return n
