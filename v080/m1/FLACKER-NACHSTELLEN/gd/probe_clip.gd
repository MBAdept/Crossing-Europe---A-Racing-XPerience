extends SceneTree
## FLACKER-NACHSTELLEN (scratch): a clip of the mechanism "full global shader buffer" as a player would see it.
## A Modern race with the follow pilot behind a preferred car (--prefer=_white). When the followed car shows lod1 at
## --arm-m (camera distance) and its lod0 does not exist yet, the probe fills the rest of Godot's global shader buffer
## with hidden vpbr instances (--fill=auto: up to the allocator's capacity as counted in the tree, +--extra), so the
## NEXT geometry built is refused – as on a forest stage of ZS1 when the props hold most of the buffer. The pilot then
## follows at a gap that swings the car across its lod0/lod1 switch (--gap-lo / --gap-hi, period --period s) and every
## frame for --clip-s seconds of view time is saved as JPEG (<out>_clip/f#####.jpg) with a log line {d, lod, refused}.
## Without --fill (=0) the same drive is recorded as the reference.
## Arguments: --stage --from --start-km --hour --seed --pilot=<abs follow_pilot.gd> --prefer --arm-m=48 --fill=auto|0|N
##   --extra=0 --gap-lo --gap-hi --period --clip-s=12 --res=960x540 --out

const RACE := "res://scenes/race/race.tscn"
const REFUSAL := "Too many instances using shader instance variables"
const CAPACITY := 254

class ErrorCatch extends Logger:
	var hits := 0
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if (code + " " + rationale).contains(REFUSAL):
			_lock.lock()
			hits += 1
			_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catch := ErrorCatch.new()
var _sc: Node
var _args := {}
var _out := ""
var _pilot: Object = null
var _phase := 0
var _t_arm := -1.0
var _target := -1
var _n := 0
var _log: FileAccess
var _dummies: Array = []
var _frames := 0
var _refused_ids: Dictionary = {}    ## geometry instance ids built after the fill (refused when the buffer is full)


func _arg(k: String, d: String) -> String:
	return str(_args.get(k, d))


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = _arg("out", "/tmp/clip")
	var res := _arg("res", "960x540").split("x")
	root.size = Vector2i(int(res[0]), int(res[1]))
	OS.add_logger(_catch)
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": _arg("stage", "erfurt_kassel"), "from_city": _arg("from", "erfurt"),
		"vehicle": _arg("vehicle", "limousine"), "start_world_minutes": float(_arg("hour", "12")) * 60.0, "weather": "normal",
		"start_km": float(_arg("start-km", "0")), "autopilot": true, "seed": int(_arg("seed", "11")), "gfx": "modern",
		"no_countdown": true, "start_speed_kmh": float(_arg("start-speed", "120")), "traffic_warmup": true, "autopilot_refuel": "never"}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	DirAccess.make_dir_recursive_absolute(_out + "_clip")
	_log = FileAccess.open(_out + "_clip.jsonl", FileAccess.WRITE)


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames > 30000:
		return _done("timeout")
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return false
	var r: Object = _sc.get("renderer")
	if r == null or not r.has_method("layer"):
		return false
	var vl: Object = r.call(&"layer", "vehicles")
	var view: Dictionary = r.get("view")
	var t := float(view.get("time", 0.0))
	if _pilot == null:
		_install_pilot()
	var cars: Dictionary = vl.get("_cars")
	var tid := int(_pilot.get("target_id"))
	var car: Object = cars.get(tid)
	match _phase:
		0:
			if car != null and bool(car.get("shown")) and not bool((car.get("info") as Dictionary).get("box", false)) \
					and str(car.get("lod")) == "lod1" and float(car.get("dist")) >= float(_arg("arm-m", "48")) - 4.0 \
					and float(car.get("dist")) <= float(_arg("arm-m", "48")) + 6.0:
				_target = tid
				var levels: Dictionary = car.get("levels")
				if levels.has("lod0"):
					# the car was near before: drop its lod0 so that it is built again (after the fill)
					var n: Node3D = levels["lod0"]
					var geo := _geometry_of(n).size()
					levels.erase("lod0")
					vl.set("_inst_n", int(vl.get("_inst_n")) - geo)
					n.queue_free()
				_fill(r)
				_pilot.set("gap_lo", float(_arg("gap-lo", "21")))
				_pilot.set("gap_hi", float(_arg("gap-hi", "33")))
				_pilot.set("gap_period_s", float(_arg("period", "5")))
				_pilot.set("wobble_m", 0.0)
				_pilot.set("_t", 0.0)
				_t_arm = t
				_phase = 1
				_log.store_line(JSON.stringify({"ev": "arm", "t": t, "id": tid, "set": str(car.get("set_id")), "d": float(car.get("dist")),
					"dummies": _dummies.size(), "refusals_before": _catch.hits}))
		1:
			# record: the frame shown is the state of the last iteration (the layer's car state is from then as well)
			var img := root.get_texture().get_image()
			_n += 1
			img.save_jpg(_out + "_clip/f%05d.jpg" % _n, 0.92)
			var c2: Object = cars.get(_target)
			var rec := {"n": _n, "t": snappedf(t - _t_arm, 0.001), "refusals": _catch.hits, "followed": tid == _target}
			if c2 != null:
				rec["d"] = snappedf(float(c2.get("dist")), 0.01)
				rec["lod"] = str(c2.get("lod"))
				rec["shown"] = bool(c2.get("shown"))
				var node: Node3D = c2.get("node")
				# a level node that did not exist at the fill was built while the buffer was full (refused)
				rec["new_level"] = node != null and not _known_nodes.has(node.get_instance_id())
				var cam: Camera3D = r.get("camera")
				var pose: Transform3D = c2.get("pose")
				if cam != null and cam.is_inside_tree():
					var p := cam.unproject_position(pose.origin + Vector3(0.0, 0.75, 0.0))
					var sc := float(img.get_width()) / float(root.get_visible_rect().size.x)
					rec["px"] = [snappedf(p.x * sc, 0.1), snappedf(p.y * sc, 0.1)]
			_log.store_line(JSON.stringify(rec))
			if t - _t_arm >= float(_arg("clip-s", "12")):
				return _done("ok")
	return false


var _known_nodes: Dictionary = {}   ## level nodes that existed when the buffer was filled


func _fill(r: Object) -> void:
	var mode := _arg("fill", "auto")
	if mode == "0":
		return
	# remember the level nodes that exist now (built before the fill)
	var vl: Object = r.call(&"layer", "vehicles")
	var cars: Dictionary = vl.get("_cars")
	for id: Variant in cars:
		for lod: Variant in (cars[id].get("levels") as Dictionary):
			var ln: Node3D = (cars[id].get("levels") as Dictionary)[lod]
			if ln != null:
				_known_nodes[ln.get_instance_id()] = true
	var n := 0
	if mode == "auto":
		n = maxi(0, CAPACITY - _count_iu()) + int(_arg("extra", "0"))
	else:
		n = int(mode)
	var mats: Object = r.get("materials")
	var m: Material = mats.call(&"material", "vpbr")
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.1, 0.1)
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = m
		mi.visible = false
		root.add_child(mi)
		_dummies.append(mi)


func _count_iu() -> int:
	var n := 0
	for x: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := x as GeometryInstance3D
		var mats: Array = []
		if gi.material_override != null:
			mats.append(gi.material_override)
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
		if mesh != null and gi.material_override == null:
			for k in mesh.get_surface_count():
				var mm: Material = (gi as MeshInstance3D).get_active_material(k) if gi is MeshInstance3D else mesh.surface_get_material(k)
				if mm != null:
					mats.append(mm)
		for mm: Variant in mats:
			if mm is ShaderMaterial and (mm as ShaderMaterial).shader != null and (mm as ShaderMaterial).shader.code.contains("instance uniform"):
				n += 1
				break
	return n


func _geometry_of(n: Node) -> Array:
	var out: Array = []
	for c: Node in n.get_children():
		if c is GeometryInstance3D:
			out.append(c)
		elif c.get_child_count() > 0:
			out.append_array(_geometry_of(c))
	return out


func _install_pilot() -> void:
	var scr: Script = load(_arg("pilot", ""))
	var old: Object = _sc.get("autopilot")
	_pilot = scr.new()
	_pilot.set("target_kmh", old.get("target_kmh") if old != null else 235.0)
	_pilot.set("refuel_mode", "never")
	_pilot.set("prefer", _arg("prefer", "_white"))
	_pilot.set("gap_lo", 45.0)
	_pilot.set("gap_hi", 60.0)
	_pilot.set("gap_period_s", 40.0)
	_pilot.set("wiggle", float(_arg("wiggle", "0.08")))
	var ms := {}
	var model_db: Script = load("res://scripts/core/model_db.gd")
	for sid: Variant in root.get_node(^"SpriteDB").call(&"ids_with_tag", "traffic"):
		if bool(model_db.call(&"has_model", str(sid))):
			ms[str(sid)] = true
	_pilot.set("model_sets", ms)
	_sc.set("autopilot", _pilot)


func _done(why: String) -> bool:
	_log.store_line(JSON.stringify({"ev": "done", "why": why, "frames": _n, "refusals": _catch.hits}))
	_log.close()
	print("CLIP done ", why, " frames ", _n, " refusals ", _catch.hits)
	quit(0)
	return true
