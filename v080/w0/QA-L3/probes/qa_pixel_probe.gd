extends SceneTree
## QA lens 3: Arcade pixels before and after N stages of another kind in the same process.
##   xvfb-run … godot --path <tree> --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720
##       --fixed-fps 60 -s <this> -- --between=modern|arcade|mixed --n=20 [--out=<dir>] [--graphics=arcade]
## A: an Arcade stage (Kiel – Hamburg km 2, countdown, traffic, full HUD), pictures at frames 30, 132 and 300.
## Then n stages (--between: "modern" = Modern picture + Modern sound, "arcade" = control, "mixed" = alternating
## picture and sound), each 40 frames. Then A again. Prints the SHA-256 of every picture and "PIXEL … GLEICH|ANDERS".
## On tag v0.7.0 only --between=arcade means something (setup.gfx is ignored there).

const RACE := "res://scenes/race/race.tscn"
const SHOTS: Array[int] = [30, 132, 300]

var _am: Node


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


static func sha(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()


func _setup(gfx_mode: String, extra: Dictionary = {}) -> Dictionary:
	var s := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11,
		"traffic_warmup": true, "gfx": gfx_mode}
	s.merge(extra, true)
	return s


func _stage(setup: Dictionary, frames: int, shots: Array[int], label: String, out_dir: String) -> Dictionary:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP   # GameFlow.start_stage() does this before every stage
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var hashes := {}
	for f in frames:
		await process_frame
		if shots.has(f + 1):
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			hashes[f + 1] = sha(img.get_data())
			if out_dir != "":
				img.save_png("%s/%s_%03d.png" % [out_dir, label, f + 1])
	var info := "gfx=%s renderer=%s" % [str(sc.get("gfx")) if "gfx" in sc else "-",
		str((sc.get("renderer") as Object).get_script().resource_path).get_file() if sc.get("renderer") != null else "null"]
	hashes["info"] = info
	hashes["pos_z"] = var_to_str(sc.get("pos_z"))
	sc.queue_free()
	await _frames(3)
	_am.call("stop_all")
	await _frames(2)
	return hashes


func _run() -> void:
	await _frames(5)
	_am = root.get_node("AudioManager")
	var between := _arg("between", "modern")
	var n := int(_arg("n", "20"))
	var out_dir := _arg("out", "")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var can_profile := _am.has_method("set_profile")
	var a1 := await _stage(_setup("arcade"), 300, SHOTS, "a1", out_dir)
	print("PIXEL A1 %s" % str(a1))
	for i in n:
		var g := "arcade"
		var snd := "arcade"
		if between == "modern":
			g = "modern"
			snd = "modern"
		elif between == "mixed":
			g = "modern" if i % 2 == 0 else "arcade"
			snd = "modern" if (i / 2) % 2 == 0 else "arcade"
		if can_profile:
			_am.call("set_profile", snd)
		var h := await _stage(_setup(g, {"vehicle": ["limousine", "kombi", "kompakt", "gran_turismo", "sportwagen"][i % 5],
			"weather": ["normal", "rain", "snow"][i % 3], "start_km": 2.0 + 7.0 * i, "seed": 20 + i, "no_countdown": i % 2 == 0,
			"start_world_minutes": (6.0 + i) * 60.0}), 40, [], "b%d" % i, "")
		if i < 2 or i == n - 1:
			print("PIXEL zwischen %d: %s, Klang %s" % [i, h["info"], str(_am.call("profile")) if can_profile else "-"])
		if can_profile:
			_am.call("set_profile", "arcade")
		await _frames(2)
	var a2 := await _stage(_setup("arcade"), 300, SHOTS, "a2", out_dir)
	print("PIXEL A2 %s" % str(a2))
	var same := true
	for f in SHOTS:
		if a1.get(f) != a2.get(f):
			same = false
	print("PIXEL %s nach %d × %s: %s  (Positionen %s / %s; Fenster aspect %d, msaa3d %d, scale3d %s)" % [
		"GLEICH" if same else "ANDERS", n, between, str(SHOTS), a1["pos_z"], a2["pos_z"], root.content_scale_aspect, root.msaa_3d,
		str(root.scaling_3d_scale)])
	var mm: Variant = load("res://scripts/race3d/modern_materials.gd") if ResourceLoader.exists("res://scripts/race3d/modern_materials.gd") else null
	if mm is GDScript:
		print("PIXEL globale Shader-Parameter ce_* registriert (ModernMaterials._globals_added): %s" % str((mm as GDScript).get("_globals_added")))
	print("PIXEL Knoten %d, verwaist %d, Busse %d, Textur %d Bytes" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), AudioServer.bus_count,
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))])
	quit(0 if same else 1)
