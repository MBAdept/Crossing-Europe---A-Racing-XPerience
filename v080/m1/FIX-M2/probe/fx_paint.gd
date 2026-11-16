extends SceneTree
## FIX-M2: what ModelDB.resolve() gives as "paint" for the player sets, and what ModelFactory.build() puts on the meshes.

func _initialize() -> void:
	ModelDB.load_manifest()
	for sid: String in ["player/limousine", "player/kompakt", "player/sportwagen"]:
		var r := ModelDB.resolve(sid)
		print("FX-PAINT ", sid, " paint=", r.get("paint", {}), " desat=", ModernMaterials.player_paint(r.get("paint", {})))
		var n := ModelFactory.build(sid, "lod0", ModernMaterials.shared(), true)
		if n != null:
			for gi: GeometryInstance3D in ModelFactory.geometry_of(n):
				print("  ", gi.name, " paint=", gi.get_instance_shader_parameter("paint"))
				break
			n.free()
	quit(0)
