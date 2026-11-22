extends SceneTree
## NACH-RINT probe: a chunk part that registered reflectors (roadside commit -> lights.add_reflectors(mi, list)) while
## its chunk was still COMMITTING (node not in the tree) and that is freed before it ever entered the tree
## (ChunkStreamer._drop of a COMMITTING chunk, then _free_trash / clear()). The lights layer forgets reflectors only on
## tree_exiting, which such a node never emits. Then _update_glints() runs with the low beam on.
## For comparison the same with add_static (FIX-RINT added an is_instance_valid() check there).


func _initialize() -> void:
	var L: Node = (load("res://scripts/race3d/layers/lights.gd") as GDScript).new()
	root.add_child(L)
	L.call("setup", null)
	L.call("_build_lights")
	var part := Node3D.new()
	L.call("add_reflectors", part, [{"pos": Vector3(0, 0, 10), "dir": Vector3(0, 0, -1), "color": Color.WHITE, "size": 0.1}])
	print("PROBE before free: reflector_count=", L.get("_reflector_count"))
	part.free()
	L.set("_beam", 1.0)
	L.set("_beam_pos", Vector3.ZERO)
	L.set("_beam_dir", Vector3(0, 0, 1))
	for i in 3:
		L.call("_update_glints")
	print("PROBE after 3 updates: reflector_count=", L.get("_reflector_count"), " entries=", (L.get("_reflectors") as Array).size())
	quit()
