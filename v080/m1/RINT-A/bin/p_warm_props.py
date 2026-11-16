import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'scripts/race3d/builders/props.gd'
rep(p, '''## Hook of the renderer: one node per shader the props use (card tree, baked house, lamp post, stand-in billboard,
## contact shadow), compiled behind the loading cover.
func warmup_nodes() -> Array:
	var out: Array = []
	var lib := _lib()
	if not lib.ready():
		return out
	var seen := {}
	for set_id: String in lib.sets:
		var e: Dictionary = lib.sets[set_id]
		var parts: Array = []
		var key := ""
		if int(e["kind"]) == PropLibrary.MODEL and not (e["variants"] as Array).is_empty():
			var mid := str((e["variants"] as Array)[0])
			var reps: Array = (lib.models[mid] as Dictionary).get("reps", [])
			if reps.is_empty():
				continue
			parts = lib.mesh_parts(mid, str(reps[0]))
			key = "m" + str(e["cls"])
		elif int(e["kind"]) == PropLibrary.SPRITE:
			var s := lib.standin(set_id)
			if not s.is_empty():
				parts = [s]
			key = "s"
		if key == "" or seen.has(key) or parts.is_empty():
			continue
		seen[key] = true
		for p: Variant in parts:
			var part: Dictionary = p
			var mi := MeshInstance3D.new()
			mi.mesh = part["mesh"]
			if part.get("material") != null:
				mi.material_override = part["material"]
			mi.scale = Vector3.ONE * (2.0 / maxf(1.0, float(e["height"])))
			out.append(mi)
''', '''## Hook of the renderer: what the props draw, compiled behind the loading cover – every representation of every
## model the stage loaded, as commit() draws it (a MultiMesh of one instance; shadow parts as casters), one stand-in
## billboard and the contact shadows. Per model, not per material class: a model whose textures or vertex layout
## differ from the first model of its class needs program variants of its own on some drivers (one node per class
## left two variants to the drive at Kiel – Hamburg km 2, cold-cache check of the assembly of M1).
func warmup_nodes() -> Array:
	var out: Array = []
	var lib := _lib()
	if not lib.ready():
		return out
	var one := PackedFloat32Array()
	_put(one, Transform3D.IDENTITY)
	var one_c := one.duplicate()
	one_c.append_array(PackedFloat32Array([1.0, 1.0, 1.0, 1.0]))
	var models := {}
	var standin := false
	for set_id: String in lib.sets:
		var e: Dictionary = lib.sets[set_id]
		if int(e["kind"]) == PropLibrary.MODEL:
			for v: Variant in e["variants"]:
				var mid := str(v)
				if models.has(mid) or not lib.models.has(mid):
					continue
				models[mid] = true
				var k := 2.0 / maxf(1.0, float(e["height"]))
				var reps := {}
				for r: Variant in (lib.models[mid] as Dictionary).get("reps", []):
					reps[str(r)] = true
				for r: String in reps:
					for p: Variant in lib.mesh_parts(mid, r):
						var part: Dictionary = p
						var node := _mmi(part, one, 1, false, false)
						node.scale = Vector3.ONE * k
						node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if bool(part["shadow"]) \\
							else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
						out.append(node)
		elif int(e["kind"]) == PropLibrary.SPRITE and not standin:
			var s := lib.standin(set_id)
			if not s.is_empty():
				standin = true
				out.append(_mmi(s, one_c, 1, true, false))
''')
print('ok')
