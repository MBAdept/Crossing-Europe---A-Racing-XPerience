extends "res://tests/race3d/render/check_instance_budget_wald.gd"
## RINT-M3 probe: the forest instance check (check_instance_budget_wald.gd) with a breakdown of the counted geometry
## instances at the frame of the highest count – by shader (resource path, or the first line of a generated shader) and
## by the owner (the first ancestor whose name is not a generated one), and whether the shader really declares an
## instance uniform (a line that starts with it) or only mentions the words (a comment).

var _best := -1
var _best_hist: Dictionary = {}


func _scene_instances() -> int:
	var n := 0
	var hist := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		for c in x.get_children():
			stack.append(c)
		if not (x is GeometryInstance3D) or x.is_queued_for_deletion():
			continue
		var sh := _iu_shader(x as GeometryInstance3D)
		if sh == null:
			continue
		n += 1
		var real := false
		for line: String in sh.code.split("\n"):
			if line.strip_edges().begins_with("instance uniform"):
				real = true
				break
		var name := sh.resource_path.get_file() if sh.resource_path != "" else "gen:" + sh.code.substr(0, 60).replace("\n", " ")
		var owner := _owner_of(x)
		var key := "%s | %s | %s" % ["echt" if real else "nur Kommentar", name, owner]
		hist[key] = int(hist.get(key, 0)) + 1
	if n > _best:
		_best = n
		_best_hist = hist
	return n


func _owner_of(x: Node) -> String:
	var p := x.get_parent()
	var chain: Array[String] = []
	while p != null and chain.size() < 4:
		chain.append(str(p.name))
		p = p.get_parent()
	var rx := RegEx.create_from_string("[0-9]+")
	return rx.sub("/".join(chain), "#", true)


static func _iu_shader(gi: GeometryInstance3D) -> Shader:
	var mats: Array[Material] = []
	if gi.material_override != null:
		mats.append(gi.material_override)
	if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
		var mi := gi as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(k)
			if m != null:
				mats.append(m)
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
		var mesh := (gi as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for k in mesh.get_surface_count():
				var m2: Material = mesh.surface_get_material(k)
				if m2 != null:
					mats.append(m2)
	for m: Material in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("instance uniform"):
			return (m as ShaderMaterial).shader
	return null


func _finish() -> bool:
	print("HIST worst %d" % _best)
	var keys := _best_hist.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(_best_hist[a]) > int(_best_hist[b]))
	for k: String in keys:
		print("HIST %4d  %s" % [int(_best_hist[k]), k])
	return super._finish()
