extends "res://tools/kritik/my_scene.gd"
## KRITIK-5a1 scratch tool (never committed): --mode=drive
##   --items=<spec>;<spec>..  spec = model@x*scale (x < 0: left roadside, mirrored like the props builder)
##   the specs repeated along the road every --every m (26) from --start (10) to --reach (400), --as=model|sprite,
##   the game camera drives at --kmh (50) for --secs (3) from --from (0 m) at 60 fps; every frame <out>_NNN.png;
##   level by distance with the props builder's hysteresis (6 m). Prints SWAP lines (frame, model, level).


func _run() -> void:
	if str(_args.get("mode", "")) != "drive":
		super._run()
		return
	var out := str(_args.get("out", ""))
	if not _load_manifest_with_model_sets():
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	var items: Array = str(_args.get("items", "")).split(";", false)
	var n: int = await _drive(items, out)
	print("k5_scene: drive -> %d Bilder" % n)
	quit(0 if n > 0 else 1)


func _drive(items: Array, out: String) -> int:
	var every := float(str(_args.get("every", "26")))
	var reach := float(str(_args.get("reach", "400")))
	var z := float(str(_args.get("start", "10")))
	var as_sprite := str(_args.get("as", "model")) == "sprite"
	_clear()
	var i := 0
	while z < reach:
		var sp := _spec(str(items[i % items.size()]))
		i += 1
		var mid := str(sp["mid"])
		var holder := Node3D.new()
		var sc := float(sp["scale"])
		holder.position = Vector3(float(sp["x"]), 0.0, -z)
		var mirror := bool(sp["mirror"]) and not as_sprite
		holder.scale = Vector3(-sc if mirror else sc, sc, sc)
		holder.set_meta(&"model", mid)
		holder.set_meta(&"level", "")
		var reps: Array = ["sprite"] if as_sprite else ["lod0", "lod1"]
		for rep: Variant in reps:
			var node: Node3D = _sprite_node(_set_of_model(mid)) if rep == "sprite" else ModelFactory.build(mid, rep, _mats)
			if node == null:
				continue
			node.set_meta(&"rep", rep)
			node.visible = false
			holder.add_child(node)
		_holder.add_child(holder)
		var m := ModelDB.model(mid)
		var bb: Array = m.get("aabb", [-1, 0, -1, 1, 2, 1])
		z += maxf(every, (float(bb[5]) - float(bb[2])) * sc + 2.0) if not items.size() > 1 or i % 2 == 0 else 0.0
	var kmh := float(str(_args.get("kmh", "50")))
	var secs := float(str(_args.get("secs", "3")))
	var z0 := float(str(_args.get("from", "0")))
	var fps := 60.0
	var t0 := 1.7
	var frames := int(round(secs * fps))
	var prefix := out.get_basename()
	for f in frames:
		var cz := -z0 - kmh / 3.6 * float(f) / fps
		_cam.position = Vector3(0.0, CAM_H, cz)
		_race_update(t0 + float(f) / fps)
		for c: Node in _holder.get_children():
			var h := c as Node3D
			if not h.has_meta(&"model"):
				continue
			var d := maxf(0.0, cz - h.position.z)
			var mid := str(h.get_meta(&"model", ""))
			var old := str(h.get_meta(&"level", ""))
			var lv := "sprite" if as_sprite else _level_for(mid, d)
			if not as_sprite and old != "" and old != lv and _level_for(mid, maxf(0.0, d - LOD_HYSTERESIS_M)) == old:
				lv = old
			if lv != old:
				h.set_meta(&"level", lv)
				if old != "":
					print("SWAP f%03d %s %s->%s d=%.1f x=%.1f" % [f, mid.get_file(), old, lv, d, h.position.x])
				for rep: Node in h.get_children():
					(rep as Node3D).visible = str(rep.get_meta(&"rep", "")) == lv
		var img := await _frame()
		img.save_png("%s_%03d.png" % [prefix, f])
	return frames
