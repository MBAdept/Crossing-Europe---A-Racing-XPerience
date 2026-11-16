extends SceneTree
## RINT-M2 probe: which MultiMeshes draw with the tint-reading shaders (vpbr, baked, leaves, billboard), with which
## instance data (colours / custom), plus a screenshot. Args: --stage --from --km --hour --out --tag

const RACE := "res://scenes/race/race.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _shader_of(mmi: MultiMeshInstance3D) -> String:
	var m: Material = mmi.material_override
	if m == null and mmi.multimesh != null and mmi.multimesh.mesh != null and mmi.multimesh.mesh.get_surface_count() > 0:
		m = mmi.multimesh.mesh.surface_get_material(0)
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var sh := (m as ShaderMaterial).shader
		if sh.resource_path != "":
			return sh.resource_path.get_file()
		var c := sh.code
		for k in ["v_tint", "INSTANCE_CUSTOM"]:
			if c.contains(k):
				return "code-with-" + k
		return "code"
	return str(m)


func _walk(n: Node, out: Dictionary, samples: Array) -> void:
	if n is MultiMeshInstance3D:
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm != null:
			var key := "%s colors=%s custom=%s" % [_shader_of(mmi), mm.use_colors, mm.use_custom_data]
			out[key] = int(out.get(key, 0)) + 1
			if mm.use_custom_data and samples.size() < 12 and mm.instance_count > 0 and _shader_of(mmi).contains("v"):
				samples.append("%s %s custom0=%s" % [mmi.get_path(), mm.mesh.resource_path.get_file() if mm.mesh else "?", mm.get_instance_custom_data(0)])
	for c in n.get_children():
		_walk(c, out, samples)


func _run() -> void:
	var a := CliArgs.all()
	var out_dir := str(a.get("out", "/tmp"))
	var tag := str(a.get("tag", "dump"))
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "kiel")), "vehicle": "limousine",
		"start_world_minutes": float(a.get("hour", 12.0)) * 60.0, "weather": "normal",
		"start_km": float(a.get("km", 0.6)), "autopilot": false, "seed": 11, "gfx": "modern", "no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while int(sc.get("_sim_steps")) < 5 and n < 6000:
		await process_frame
		n += 1
	for i in 240:
		await process_frame
	var counts := {}
	var samples := []
	_walk(sc, counts, samples)
	var keys := counts.keys()
	keys.sort()
	for k: String in keys:
		print("MMDUMP ", k, " : ", counts[k])
	for s: String in samples:
		print("MMSAMPLE ", s)
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(tag + ".png"))
	quit(0)
