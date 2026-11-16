extends SceneTree
## QA attack A: broken / odd manifests against ModelDB and ModelFactory (headless).
## --dir=<folder with the manifest variants>  (each *.json is loaded as a manifest; meshes relative to it)

var _n_ok := 0
var _n_bad := 0

func _arg(key: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return default


func _say(ok: bool, text: String) -> void:
	if ok:
		_n_ok += 1
	else:
		_n_bad += 1
	print("%s %s" % ["  ok   " if ok else "  FAIL ", text])


func _initialize() -> void:
	var dir := _arg("dir", "")
	var files := DirAccess.get_files_at(dir)
	var names: Array = []
	for f in files:
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f: String in names:
		print("== manifest ", f)
		var loaded := ModelDB.load_manifest(dir.path_join(f))
		print("   load_manifest -> %s, available() -> %s, models %d, sets %d" % [str(loaded), str(ModelDB.available()), ModelDB.model_ids().size(), ModelDB.set_ids().size()])
		if not loaded:
			_say(ModelDB.resolve("traffic/sedan_red").is_empty(), "resolve() gives {} while unavailable")
			_say(not ModelDB.has_model("traffic/sedan_red"), "has_model false while unavailable")
			_say(ModelDB.object_size("traffic/sedan_red").is_empty(), "object_size {} while unavailable")
			_say(ModelFactory.build("traffic/sedan_red", "lod0", null) == null, "ModelFactory.build null while unavailable")
			ModelDB.request(["traffic/sedan_red"], ["lod0"])
			_say(ModelDB.pending() == 0, "request() on an unavailable manifest leaves nothing pending")
			continue
		# a loaded manifest: walk every set and try everything a renderer does
		for sid: String in ModelDB.set_ids():
			var r := ModelDB.resolve(sid)
			if r.is_empty():
				print("   resolve(%s) -> {}" % sid)
				continue
			var _o := ModelDB.object_size(sid)
			var _h := ModelDB.has_model(sid)
			if not (r["model"] as Dictionary).is_empty():
				for lod: String in ["", "lod0", "lod1", "lod2", "show"]:
					var node := ModelFactory.build(sid, lod, null)
					if node != null:
						var kids: Array = []
						for c in node.get_children():
							kids.append(c.name)
						if sid in ["traffic/sedan_red", "props/tree_oak", "props/farmhouse", "player/limousine"] and lod in ["", "lod0"]:
							print("   build(%s, '%s') -> %s" % [sid, lod, str(kids)])
						node.free()
				var parts := ModelFactory.multimesh_parts(sid, "lod0", null)
				var _d := ModelDB.lod_for_distance(r["model"], 50.0)
		ModelDB.request(ModelDB.set_ids(), [])
		var guard := 0
		while ModelDB.pending() > 0 and guard < 2000:
			OS.delay_msec(5)
			guard += 1
		print("   request(all): pending %d after %d polls, loads %d" % [ModelDB.pending(), guard, ModelDB.loads])
	ModelDB.load_manifest()
	_say(ModelDB.available(), "the shipped manifest loads again afterwards")
	print("QA attack_manifest: %d ok, %d FAIL" % [_n_ok, _n_bad])
	quit(0)
