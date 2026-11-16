extends SceneTree
## QA lens 3: what a sequence of stages leaves loaded. Works on tag v0.7.0 (setup.gfx is ignored there) and on the
## integrated tree.  godot --path <tree> --fixed-fps 60 -s <this> -- --seq=arcade,modern,arcade [--sound=…]
##     [--frames=120] [--out=<json>] [--stage=kiel_hamburg --km=2 --vehicle=limousine]
## Per step: texture / buffer / video memory, node / object / resource counts, resources in the ResourceLoader
## cache by folder, the window's 3D state.

const RACE := "res://scenes/race/race.tscn"

var _rows: Array = []
var _files: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".import") and not f.ends_with(".uid"):
			_files.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scan(dir.path_join(sub))


func _cached() -> Dictionary:
	var out := {}
	var listed: Array = []
	for f in _files:
		if ResourceLoader.has_cached(f):
			var parts := f.trim_prefix("res://").split("/")
			var key := "/".join(parts.slice(0, mini(3, parts.size() - 1)))
			if parts[0] == "scripts" or parts[0] == "tests":
				key = "/".join(parts.slice(0, mini(2, parts.size() - 1)))
			out[key] = int(out.get(key, 0)) + 1
			listed.append(f)
	return {"by_folder": out, "files": listed}


func _row(label: String) -> void:
	var c := _cached()
	var r := {"step": label,
		"tex_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"buf_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"buses": AudioServer.bus_count, "aspect": root.content_scale_aspect, "msaa3d": root.msaa_3d,
		"scale3d": root.scaling_3d_scale, "atlas": root.positional_shadow_atlas_size, "hdr2d": root.use_hdr_2d,
		"root_children": root.get_child_count(), "cached": c["by_folder"], "cached_files": c["files"],
		"tex_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))}
	_rows.append(r)
	print("MEM %-26s tex %7.1f MB  buf %6.1f  video %7.1f  static %6.1f | nodes %4d orphans %d objects %5d res %4d buses %2d | aspect %d | %s" % [
		label, r["tex_mb"], r["buf_mb"], r["video_mb"], r["static_mb"], r["nodes"], r["orphans"], r["objects"], r["resources"],
		r["buses"], r["aspect"], JSON.stringify(c["by_folder"])])


func _run() -> void:
	await _frames(5)
	for d in ["res://assets", "res://scripts", "res://scenes"]:
		_scan(d)
	var seq := _arg("seq", "arcade").split(",", false)
	var frames := int(_arg("frames", "120"))
	var am: Node = root.get_node_or_null("AudioManager")
	_row("boot")
	var i := 0
	for mode in seq:
		if mode == "icons":
			var sdb: Node = root.get_node("SpriteDB")
			var ids: Array = sdb.call("ids_with_tag", "icon")
			for id: String in ids:
				sdb.call("texture", id)
			await _frames(5)
			_row("%d icons (%d Sets)" % [i, ids.size()])
			i += 1
			continue
		if mode == "disable3d":
			root.disable_3d = true
			await _frames(10)
			_row("%d disable_3d an" % i)
			root.disable_3d = false
			await _frames(10)
			_row("%d disable_3d wieder aus" % i)
			i += 1
			continue
		if mode == "fonts":
			var lbl := Label.new()
			lbl.text = "Etappe wird geladen … 0123456789 km/h ÄÖÜ"
			root.add_child(lbl)
			await _frames(5)
			lbl.queue_free()
			await _frames(3)
			_row("%d fonts" % i)
			i += 1
			continue
		if mode == "3d" or mode == "3d_noenv":
			var holder := Node3D.new()
			if mode == "3d":
				var env := Environment.new()
				env.background_mode = Environment.BG_CANVAS
				env.background_canvas_max_layer = -10
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
				env.adjustment_enabled = true
				var we := WorldEnvironment.new()
				we.environment = env
				holder.add_child(we)
			var cam := Camera3D.new()
			holder.add_child(cam)
			var mi := MeshInstance3D.new()
			mi.mesh = PlaneMesh.new()
			mi.position = Vector3(0, -1, -5)
			holder.add_child(mi)
			root.add_child(holder)
			cam.make_current()
			await _frames(20)
			_row("%d %s läuft" % [i, mode])
			holder.queue_free()
			await _frames(20)
			_row("%d %s beendet" % [i, mode])
			i += 1
			continue
		var m := mode
		var sound := ""
		if m.contains("/"):
			sound = m.get_slice("/", 1)
			m = m.get_slice("/", 0)
		if sound != "" and am.has_method("set_profile"):
			am.call("set_profile", sound)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP   # what GameFlow does before every stage
		var setup := {"mode": "single", "race_id": "", "stage_id": _arg("stage", "kiel_hamburg"), "from_city": _arg("from", "kiel"),
			"vehicle": _arg("vehicle", "limousine"), "start_world_minutes": float(_arg("hour", "12")) * 60.0,
			"weather": _arg("weather", "normal"), "start_km": float(_arg("km", "2")), "autopilot": true, "no_countdown": true,
			"seed": 11, "traffic_warmup": true, "start_speed_kmh": 100.0, "gfx": m}
		var sc: Node = (load(RACE) as PackedScene).instantiate()
		sc.set("setup", setup)
		await physics_frame
		root.add_child(sc)
		await _frames(frames)
		var real := str(sc.get("gfx")) if "gfx" in sc else "arcade(v070)"
		_row("%d %s läuft (%s)" % [i, mode, real])
		sc.queue_free()
		await _frames(10)
		am.call("stop_all")
		if am.has_method("set_profile"):
			am.call("set_profile", "arcade")
		await _frames(10)
		_row("%d %s beendet" % [i, mode])
		i += 1
	var out := _arg("out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(_rows, "\t") + "\n")
		f.close()
	quit(0)
