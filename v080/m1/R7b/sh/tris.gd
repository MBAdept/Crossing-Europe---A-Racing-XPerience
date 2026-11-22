extends SceneTree
const L := preload("res://scripts/race3d/builders/landmarks.gd")

func _initialize() -> void:
	for c: Dictionary in [{"proc": "domed_church", "height_m": 82.0, "wall": "#f0ece2", "dome": "#6f9c86"},
			{"proc": "domed_church", "height_m": 98.0, "cross": false}, {"proc": "tv_tower", "height_m": 209.0},
			{"proc": "lighthouse", "height_m": 51.0}, {"proc": "skyscrapers", "height_m": 250.0}]:
		var t0 := Time.get_ticks_usec()
		var o: Dictionary = L.proc_mesh(c)
		var aabb: AABB = (o["mesh"] as Mesh).get_aabb()
		print("TRIS %s %d glows %d  aabb %s  build %.1f ms" % [c["proc"], int(o["tris"]), int(o["glows"]), str(aabb.size), (Time.get_ticks_usec() - t0) / 1000.0])
	quit(0)
