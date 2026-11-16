import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
pairs = [
('''		g = {"model": model_id, "set": str(e["set"]), "mirror": flipped, "buf": PackedFloat32Array(), "n": 0,
			"landmark": landmark and not is_model}''', '''		g = {"model": model_id, "set": str(e["set"]), "mirror": flipped, "buf": PackedFloat32Array(), "n": 0,
			"landmark": landmark}'''),
('''					var node := _mmi(mp, buf, n, false, bool(g["mirror"]))
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_ok and not has_caster and not bool(mp["billboard"]) \\
						else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF''', '''					var node := _mmi(mp, buf, n, false, bool(g["mirror"]))
					if bool(g.get("landmark", false)):
						_landmark_override(node, mp)
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_ok and not has_caster and not bool(mp["billboard"]) \\
						else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF'''),
# far: models too
('''		if e.is_empty() or int(e["kind"]) != PropLibrary.SPRITE:
			continue
		var mat := landmark_material(str(e["set"]))
		var s := lib.standin(str(e["set"]))
		if mat == null or s.is_empty():
			continue''', '''		if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
			continue
		var is_model := int(e["kind"]) == PropLibrary.MODEL
		var parts: Array = []
		if is_model:
			var variants: Array = e.get("variants", [])
			var md: Dictionary = lib.models.get(str(variants[0]) if not variants.is_empty() else "", {})
			var reps: Array = md.get("reps", [])
			if reps.is_empty():
				continue
			for pv: Variant in lib.mesh_parts(str(variants[0]), str(reps[reps.size() - 1])):
				if not bool((pv as Dictionary)["shadow"]):
					parts.append(pv)
		else:
			var mat := landmark_material(str(e["set"]))
			var st := lib.standin(str(e["set"]))
			if mat != null and not st.is_empty():
				parts.append({"mesh": st["mesh"], "material": mat, "transform": Transform3D.IDENTITY})
		if parts.is_empty():
			continue'''),
('''		var node: MeshInstance3D = _far.get(li)
		if node == null or not is_instance_valid(node):
			node = MeshInstance3D.new()
			node.name = "FarLandmark%d" % li
			node.mesh = s["mesh"]
			node.material_override = mat
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(world as Node3D).add_child(node)
			_far[li] = node
		node.transform = Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), _renderer.call(&"road_to_world", z, x, h))
		keep[li] = true''', '''		var node: Node3D = _far.get(li)
		if node == null or not is_instance_valid(node):
			node = Node3D.new()
			node.name = "FarLandmark%d" % li
			for pv: Variant in parts:
				var pd: Dictionary = pv
				var mi := MeshInstance3D.new()
				mi.mesh = pd["mesh"]
				mi.transform = pd.get("transform", Transform3D.IDENTITY)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if pd.get("material") != null:
					mi.material_override = pd["material"]
				elif is_model:
					_landmark_override(mi, pd)
				node.add_child(mi)
			(world as Node3D).add_child(node)
			_far[li] = node
		var basis := Basis.from_scale(Vector3(sc, sc, sc))
		if is_model:
			# a model stands like in its chunk: ChunkContext.frame() – turned with the road at z, never mirrored
			var path: Variant = _renderer.get("path")
			if path is RoadPath3D:
				var a := (path as RoadPath3D).heading_at(z)
				basis = Basis(RoadPath3D.right_of(a), Vector3.UP, -RoadPath3D.fwd_of(a)).scaled_local(Vector3(sc, sc, sc))
		node.transform = Transform3D(basis, _renderer.call(&"road_to_world", z, x, h))
		keep[li] = true'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)
anchor = '''## Arcade's landmark range for a visibility (RoadRenderer._landmark_range).'''
assert s.count(anchor) == 1
helper = '''## A landmark model drawn with Arcade's landmark law: its one surface's material (baked.gdshader) duplicated with
## landmark_law set, as the override of the node. Models with several surfaces keep their materials (none in M1).
func _landmark_override(node: GeometryInstance3D, part: Dictionary) -> void:
	var mesh: Variant = part.get("mesh")
	if not (mesh is Mesh) or (mesh as Mesh).get_surface_count() != 1:
		return
	var src := (mesh as Mesh).surface_get_material(0)
	if not (src is ShaderMaterial):
		return
	var key := "m%d" % src.get_instance_id()
	var m: Variant = _lm_mats.get(key)
	if m == null:
		var dup := (src as ShaderMaterial).duplicate() as ShaderMaterial
		dup.set_shader_parameter("landmark_law", _lm_law)
		_lm_mats[key] = dup
		m = dup
	node.material_override = m


'''
s = s.replace(anchor, helper + anchor)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
