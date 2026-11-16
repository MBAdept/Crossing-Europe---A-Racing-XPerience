extends SceneTree
## Counts the lamp channels (UV2.x = channel + 0.5) of every vpbr surface of the given meshes.
## godot --headless --path <wt> -s <this> -- res://a.res res://b.res ...

func _initialize() -> void:
	for p: String in OS.get_cmdline_user_args():
		var m := load(p) as ArrayMesh
		if m == null:
			print("FEHLT ", p)
			continue
		var counts := {}
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
			if uv2.is_empty():
				continue
			for v in uv2:
				var ch := -1 if v.x < 0.0 else int(floor(v.x))
				counts[ch] = int(counts.get(ch, 0)) + 1
		var keys := counts.keys()
		keys.sort()
		var parts: Array[String] = []
		for k: int in keys:
			parts.append("%d:%d" % [k, counts[k]])
		print(p.get_file(), "  ", p.get_base_dir().get_file(), "  ", " ".join(parts))
	quit(0)
