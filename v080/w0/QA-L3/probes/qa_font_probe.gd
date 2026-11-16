extends SceneTree
## Where the texture memory of a stage that loads no sprite sheets comes from: font atlases?
const RACE := "res://scenes/race/race.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _process(_d: float) -> bool:
	return false

func _font_bytes() -> Dictionary:
	var total := 0
	var n := 0
	var per := {}
	var d := DirAccess.open("res://assets/fonts")
	for f in d.get_files():
		var p := "res://assets/fonts/" + f
		if f.ends_with(".import") or not ResourceLoader.has_cached(p):
			continue
		var font: FontFile = load(p)
		var b := 0
		for ci in font.get_cache_count():
			for size: Vector2i in font.get_size_cache_list(ci):
				for t in font.get_texture_count(ci, size):
					var img := font.get_texture_image(ci, size, t)
					if img != null:
						b += img.get_data().size()
						n += 1
		per[f] = b
		total += b
	return {"total": total, "textures": n, "per_font": per}

func _run() -> void:
	for i in 5:
		await process_frame
	var mode := "modern"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
	var t0 := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 720.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "no_countdown": true,
		"seed": 11, "traffic_warmup": true, "start_speed_kmh": 100.0, "gfx": mode}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var last := t0
	for i in 120:
		await process_frame
		var t := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
		if t != last:
			print("FRAME %3d  tex %+12d -> %12d bytes" % [i, t - last, t])
			last = t
	var fb := _font_bytes()
	print("FONTS %s: %d atlas textures, %d bytes (%.1f MiB) of %d bytes the stage added (%.1f MiB)" % [mode, fb["textures"], fb["total"],
		fb["total"] / 1048576.0, last - t0, (last - t0) / 1048576.0])
	print("FONTS per font: ", fb["per_font"])
	quit(0)
