extends SceneTree
## Prints node names, extras metadata and material names of an imported glb (headless).

func _init() -> void:
	var ps: PackedScene = load("res://models/player_kompakt_d1.glb") as PackedScene
	var root: Node = ps.instantiate()
	print("root: ", root.name, " type=", root.get_class(), " meta=", root.get_meta_list())
	for c: Node in root.get_children():
		var extra: String = ""
		if c.has_meta("extras"):
			extra = str(c.get_meta("extras")).substr(0, 160)
		print("  child: ", c.name, " type=", c.get_class(), " pos=", (c as Node3D).position, " extras=", extra)
		for g: Node in c.get_children():
			var mi: MeshInstance3D = g as MeshInstance3D
			var names: PackedStringArray = []
			if mi != null:
				for s: int in mi.mesh.get_surface_count():
					var m: Material = mi.mesh.surface_get_material(s)
					names.append(m.resource_name + ("*" if m.has_meta("extras") else ""))
			print("    ", g.name, " ", g.get_class(), " pos=", (g as Node3D).position, " surfaces=", names)
	quit()
