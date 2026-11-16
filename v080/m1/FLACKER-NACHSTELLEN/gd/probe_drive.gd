extends SceneTree
## FLACKER-NACHSTELLEN instrumented drive (scratch, not part of the game). Drives a stage in Modern with the follow
## pilot (follow_pilot.gd: follows a traffic car at a sweeping gap and steers a little) and logs every frame:
##  * per traffic car with a model (vehicles layer, view distance < LOG_M): set, camera distance, level shown,
##    cross-fade, level switches; the instance uniforms its shown geometry carries on the CPU side (read back with
##    get_instance_shader_parameter) against what they should be (paint of the set, the layer's fade/sun/lamps);
##  * Godot's refusals of instance-uniform slots ("Too many instances using shader instance variables", caught with a
##    Logger, tagged with the frame they were rendered in) and a simulation of the engine's slot allocator over every
##    GeometryInstance3D with an instance-uniform material in the tree (first come, CAPACITY instances), which tells
##    WHICH instances were refused – checked against the Logger frame by frame;
##  * pictures: the frame before / at / after every level switch of the followed car and of any car within SHOT_M,
##    and every frame (up to a limit) in which a car within SHOT_M shows refused geometry.
## Arguments (after --): --stage --from --start-km --end-km --hour --seed --vehicle --sim-s --ts --res --out
##   --prefer=_white --gap-lo --gap-hi --wiggle --shots=1 --max-shots=N --sync=1
## Untyped access to game classes (a -s script compiles before the autoloads exist).

const RACE := "res://scenes/race/race.tscn"
const REFUSAL := "Too many instances using shader instance variables"
const REALLOC := "instance_buffer_pos.has"
const CAPACITY := 254          ## (4096 - 20 slots of the ce_* globals of ZS1) / 16
const LOG_M := 160.0
const SHOT_M := 90.0

class ErrorCatch extends Logger:
	var hits := 0
	var realloc := 0
	var frame_hits: Dictionary = {}
	var frame := 0
	var first := ""
	var others: Dictionary = {}
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var txt := code + " " + rationale
		_lock.lock()
		if txt.contains(REFUSAL):
			hits += 1
			frame_hits[frame] = int(frame_hits.get(frame, 0)) + 1
			if first == "":
				first = txt
		elif txt.contains(REALLOC):
			realloc += 1
		else:
			var k := txt.left(160)
			others[k] = int(others.get(k, 0)) + 1
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catch := ErrorCatch.new()
var _sc: Node
var _frames := 0
var _live := 0
var _t0 := -1.0
var _km0 := -1.0
var _args := {}
var _out := ""
var _sim_s := 600.0
var _end_km := 1.0e9
var _ts := 1.0
var _pilot: Object = null
var _log: FileAccess
var _ev: FileAccess
# allocator simulation
var _alive: Dictionary = {}        ## instance id -> [allocated: bool, frame born, class tag]
var _alloc_n := 0
var _pred_ref_total := 0
var _pred_ref_frames: Dictionary = {}
var _iu_cache: Dictionary = {}     ## "override id|mesh id" -> bool
var _shader_iu: Dictionary = {}    ## shader instance id -> bool
var _mismatch_frames := 0          ## frames where predicted and caught refusals differ
var _alloc_peak := 0
# cars
var _prev_lod: Dictionary = {}     ## car id -> lod
var _lod_hist: Dictionary = {}     ## car id -> [[t, from, to, dist]]
var _paint: Dictionary = {}        ## set id -> Color expected (paint)
# pictures
var _shots := false
var _shot_n := 0
var _max_shots := 80
var _prev_img: Image = null
var _pending_after: Array = []     ## [frame to save, name]
var _wall0 := 0
var _stats := {"frames_with_refused_car": 0, "frames_with_refused_car_near": 0, "readback_mismatch_frames": 0,
	"switches_near": 0, "switches_all": 0, "flipflop_1s": 0, "refused_car_levels": {}}


func _arg(k: String, d: String) -> String:
	return str(_args.get(k, d))


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = _arg("out", "/tmp/probe")
	_sim_s = float(_arg("sim-s", "600"))
	_end_km = float(_arg("end-km", "1e9"))
	_ts = float(_arg("ts", "1"))
	_shots = _arg("shots", "1") == "1"
	_max_shots = int(_arg("max-shots", "80"))
	var res := _arg("res", "640x360").split("x")
	root.size = Vector2i(int(res[0]), int(res[1]))
	OS.add_logger(_catch)
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": _arg("stage", "erfurt_kassel"), "from_city": _arg("from", "erfurt"),
		"vehicle": _arg("vehicle", "limousine"), "start_world_minutes": float(_arg("hour", "12")) * 60.0, "weather": _arg("weather", "normal"),
		"start_km": float(_arg("start-km", "0")), "autopilot": true, "seed": int(_arg("seed", "11")), "gfx": "modern",
		"no_countdown": true, "start_speed_kmh": float(_arg("start-speed", "120")), "traffic_warmup": true,
		"autopilot_refuel": "never"}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	_log = FileAccess.open(_out + "_frames.jsonl", FileAccess.WRITE)
	_ev = FileAccess.open(_out + "_events.jsonl", FileAccess.WRITE)
	if _shots:
		DirAccess.make_dir_recursive_absolute(_out + "_shots")


func _process(_dt: float) -> bool:
	# Logger tag: refusals raised while this iteration renders belong to frame _frames
	var rendered := _frames - 1          # the frame whose render we look at now (previous iteration)
	_catch.frame = _frames
	_frames += 1
	var caught := int(_catch.frame_hits.get(rendered, 0))
	var pred := _simulate(rendered)
	if pred != caught:
		_mismatch_frames += 1
		_event({"ev": "alloc_mismatch", "f": rendered, "pred": pred, "caught": caught, "alloc_n": _alloc_n})
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return _frames > 8000 and _finish()
	var r: Object = _sc.get("renderer")
	if r == null or not r.has_method("layer"):
		return _frames > 8000 and _finish()
	var vl: Object = r.call(&"layer", "vehicles")
	var view: Dictionary = r.get("view")
	if _t0 < 0.0:
		_t0 = float(view.get("time", 0.0))
		_km0 = float(_sc.get("pos_km"))
		Engine.time_scale = _ts
		_install_pilot()
	_live += 1
	var t := float(view.get("time", 0.0)) - _t0
	var km := float(_sc.get("pos_km"))
	var img: Image = null
	if _shots and _shot_n < _max_shots:
		img = root.get_texture().get_image()
	var row := _frame_row(rendered, t, km, vl, r, caught, pred, img)
	_log.store_line(JSON.stringify(row))
	_prev_img = img
	if t >= _sim_s or km >= _end_km or _live > 200000 or bool(_sc.get("finished")):
		return _finish()
	return false


func _install_pilot() -> void:
	# --density-k: stress test, the traffic's base density (vehicles per visible km) times k
	var dk := float(_arg("density-k", "1"))
	if dk != 1.0:
		var tr: Object = _sc.get("traffic")
		var bd: Dictionary = (tr.get("_base_density") as Dictionary).duplicate()
		for k: Variant in bd.keys():
			bd[k] = float(bd[k]) * dk
		tr.set("_base_density", bd)
		_event({"ev": "density", "k": dk, "base": bd})
	if _arg("pilot", "") == "none":
		return
	var path := _arg("pilot", "")
	var scr: Script = load(path) if path != "" else null
	if scr == null:
		push_error("pilot script missing: " + path)
		return
	var old: Object = _sc.get("autopilot")
	_pilot = scr.new()
	_pilot.set("target_kmh", old.get("target_kmh") if old != null else 235.0)
	_pilot.set("obey_radar", true)
	_pilot.set("refuel_mode", "never")
	_pilot.set("prefer", _arg("prefer", ""))
	_pilot.set("gap_lo", float(_arg("gap-lo", "18")))
	_pilot.set("gap_hi", float(_arg("gap-hi", "70")))
	_pilot.set("wiggle", float(_arg("wiggle", "0.10")))
	var ms := {}
	# ModelDB is a class with static functions (scripts/core/model_db.gd); has_model(set) tells which sets have a model
	var model_db: Script = load("res://scripts/core/model_db.gd")
	var sprite_db: Object = root.get_node(^"SpriteDB")
	for sid: Variant in sprite_db.call(&"ids_with_tag", "traffic"):
		if bool(model_db.call(&"has_model", str(sid))):
			ms[str(sid)] = true
	_pilot.set("model_sets", ms)
	_sc.set("autopilot", _pilot)
	_event({"ev": "pilot", "model_sets": ms.keys(), "prefer": _arg("prefer", "")})


func _event(d: Dictionary) -> void:
	_ev.store_line(JSON.stringify(d))


## One frame of the log (the state the last render showed).
func _frame_row(f: int, t: float, km: float, vl: Object, r: Object, caught: int, pred: int, img: Image) -> Dictionary:
	var veh: Object = _sc.get("vehicle")
	var row := {"f": f, "t": snappedf(t, 0.001), "km": snappedf(km, 0.0001), "v": snappedf(float(veh.get("speed")), 0.1),
		"st": snappedf(float(veh.get("steer_visual")), 0.001), "ref": caught, "pred": pred, "an": _alloc_n}
	if _pilot != null:
		row["tg"] = int(_pilot.get("target_id"))
		row["gap"] = snappedf(float(_pilot.get("gap_now")), 0.01)
		row["gw"] = snappedf(float(_pilot.get("gap_want")), 0.1)
	var cam: Camera3D = r.get("camera")
	if cam != null:
		row["yaw"] = snappedf(rad_to_deg(cam.global_rotation.y), 0.01)
	var cars: Dictionary = vl.get("_cars")
	var list: Array = []
	var any_ref_near := false
	var any_ref := false
	var any_mm := false
	var cam_ok := cam != null and cam.is_inside_tree()
	for id: Variant in cars:
		var car: Object = cars[id]
		if int(id) < 0:
			continue          # player and police
		var dist := float(car.get("dist"))
		if dist > LOG_M or dist < -20.0:
			continue
		var info: Dictionary = car.get("info")
		if bool(info.get("box", false)):
			# stand-in (sprite / box picture): no levels
			list.append({"id": int(id), "s": str(car.get("set_id")).trim_prefix("traffic/"), "d": snappedf(dist, 0.01), "l": "standin",
				"sh": bool(car.get("shown"))})
			continue
		var lod := str(car.get("lod"))
		var shown := bool(car.get("shown"))
		var node: Node3D = car.get("node")
		var nref := 0
		var ngeo := 0
		var mm := ""
		if node != null and is_instance_valid(node):
			for gi: Node in _geometry_of(node):
				ngeo += 1
				var a: Variant = _alive.get(gi.get_instance_id())
				if a != null and not bool((a as Array)[0]):
					nref += 1
			mm = _readback(car, node)
		var xf := float(car.get("xf_t"))
		var xref := 0
		var xfn: Node3D = car.get("xf_node")
		if xfn != null and is_instance_valid(xfn):
			for gi: Node in _geometry_of(xfn):
				var a2: Variant = _alive.get(gi.get_instance_id())
				if a2 != null and not bool((a2 as Array)[0]):
					xref += 1
		var e := {"id": int(id), "s": str(car.get("set_id")).trim_prefix("traffic/"), "d": snappedf(dist, 0.01), "l": lod, "sh": shown}
		if xf > 0.0:
			e["xf"] = snappedf(xf, 0.01)
			e["xl"] = str(car.get("xf_lod"))
		if nref > 0:
			e["ref"] = nref
			e["ng"] = ngeo
		if xref > 0:
			e["xref"] = xref
		if mm != "":
			e["mm"] = mm
			any_mm = any_mm or shown
		list.append(e)
		# level switches
		var prev := str(_prev_lod.get(int(id), ""))
		if prev != "" and prev != lod:
			_stats["switches_all"] = int(_stats["switches_all"]) + 1
			if dist < 80.0:
				_stats["switches_near"] = int(_stats["switches_near"]) + 1
			var h: Array = _lod_hist.get(int(id), [])
			for old: Array in h:
				if t - float(old[0]) <= 1.0 and str(old[1]) == lod and str(old[2]) == prev:
					_stats["flipflop_1s"] = int(_stats["flipflop_1s"]) + 1
					_event({"ev": "flipflop", "f": f, "t": t, "id": int(id), "set": str(car.get("set_id")), "from": prev, "to": lod,
						"dt": t - float(old[0]), "d": dist})
					break
			h.append([t, prev, lod, dist])
			if h.size() > 8:
				h.pop_front()
			_lod_hist[int(id)] = h
			_event({"ev": "switch", "f": f, "t": t, "km": km, "id": int(id), "set": str(car.get("set_id")), "from": prev, "to": lod,
				"d": dist, "followed": _pilot != null and int(_pilot.get("target_id")) == int(id), "ref_after": nref,
				"st": float(veh_steer())})
			if img != null and dist < SHOT_M and _shot_n < _max_shots and cam_ok:
				_save_switch(f, int(id), car, cam, img, prev, lod)
		_prev_lod[int(id)] = lod
		if shown and nref > 0:
			any_ref = true
			if dist < SHOT_M:
				any_ref_near = true
				var key := "%s|%s" % [str(car.get("set_id")), lod]
				var rc: Dictionary = _stats["refused_car_levels"]
				rc[key] = int(rc.get(key, 0)) + 1
				if img != null and _shot_n < _max_shots and cam_ok and int(rc[key]) % 20 == 1:
					_save_img(img, "refused_f%06d_id%d_%s_%s_%.0fm" % [f, int(id), str(car.get("set_id")).trim_prefix("traffic/"), lod, dist])
	if any_ref:
		_stats["frames_with_refused_car"] = int(_stats["frames_with_refused_car"]) + 1
	if any_ref_near:
		_stats["frames_with_refused_car_near"] = int(_stats["frames_with_refused_car_near"]) + 1
	if any_mm:
		_stats["readback_mismatch_frames"] = int(_stats["readback_mismatch_frames"]) + 1
	row["cars"] = list
	# pictures after a switch
	if img != null:
		var keep: Array = []
		for p: Array in _pending_after:
			if int(p[0]) <= f:
				_save_img(img, str(p[1]))
			else:
				keep.append(p)
		_pending_after = keep
	return row


func veh_steer() -> float:
	return float((_sc.get("vehicle") as Object).get("steer_visual"))


func _save_switch(f: int, id: int, car: Object, cam: Camera3D, img: Image, from: String, to: String) -> void:
	var base := "switch_f%06d_id%d_%s_%s-%s_%.1fm" % [f, id, str(car.get("set_id")).trim_prefix("traffic/"), from, to, float(car.get("dist"))]
	if _prev_img != null:
		_save_img(_prev_img, base + "_a_before")
	_save_img(img, base + "_b_at")
	_pending_after.append([f + 2, base + "_c_after2"])


func _save_img(img: Image, name: String) -> void:
	if _shot_n >= _max_shots:
		return
	_shot_n += 1
	img.save_png(_out + "_shots/" + name + ".png")


## CPU-side instance uniforms of the shown level against what they should be: "" when right, else the keys that
## differ (paint of the set, the layer's cached fade / sun / lamps).
func _readback(car: Object, node: Node3D) -> String:
	var sid := str(car.get("set_id"))
	var want: Variant = _paint.get(sid)
	if want == null:
		var model_db: Script = load("res://scripts/core/model_db.gd")
		var rr: Dictionary = model_db.call(&"resolve", sid)
		var p: Dictionary = rr.get("paint", {})
		var col := Color(str(p.get("paint", "#808085")))
		col.a = float(p.get("metal", 0.3))
		want = col
		_paint[sid] = col
	var bad: Array[String] = []
	var fade := float(car.get("fade"))
	var sun := float(car.get("sun"))
	var la: Vector4 = car.get("la")
	var lb: Vector4 = car.get("lb")
	var body: Array = car.get("body")
	for gi: Node in _geometry_of(node):
		var g := gi as GeometryInstance3D
		var pv: Variant = g.get_instance_shader_parameter(&"paint")
		if not (pv is Color) or not (pv as Color).is_equal_approx(want as Color):
			if not bad.has("paint"):
				bad.append("paint")
		var fv: Variant = g.get_instance_shader_parameter(&"fade")
		if fade >= 0.0 and (not (fv is float) or absf(float(fv) - fade) > 0.002):
			if not bad.has("fade"):
				bad.append("fade")
		var sv: Variant = g.get_instance_shader_parameter(&"sun")
		if sun >= 0.0 and (not (sv is float) or absf(float(sv) - sun) > 0.001):
			if not bad.has("sun"):
				bad.append("sun")
		if body.has(g):
			var av: Variant = g.get_instance_shader_parameter(&"lamp_a")
			if la.x >= 0.0 and (not (av is Vector4) or not (av as Vector4).is_equal_approx(la)):
				if not bad.has("lamp_a"):
					bad.append("lamp_a")
			var bv: Variant = g.get_instance_shader_parameter(&"lamp_b")
			if lb.x >= 0.0 and (not (bv is Vector4) or not (bv as Vector4).is_equal_approx(lb)):
				if not bad.has("lamp_b"):
					bad.append("lamp_b")
	return ",".join(bad)


func _geometry_of(n: Node) -> Array:
	var out: Array = []
	for c: Node in n.get_children():
		if c is GeometryInstance3D:
			out.append(c)
		elif c.get_child_count() > 0:
			out.append_array(_geometry_of(c))
	return out


## The engine's slot allocator, simulated over the tree after the last frame: instances that left the tree free
## their slots, new ones (in tree order) get one while fewer than CAPACITY are allocated, else they are refused for
## good. Returns the number of refusals predicted for that frame.
func _simulate(f: int) -> int:
	var seen: Dictionary = {}
	var order: Array = []
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if _uses_iu(gi):
			var id := gi.get_instance_id()
			seen[id] = true
			if not _alive.has(id):
				order.append(gi)
	for id: Variant in _alive.keys():
		if not seen.has(id):
			if bool((_alive[id] as Array)[0]):
				_alloc_n -= 1
			_alive.erase(id)
	var refused := 0
	# Godot queues dirty instances at the FRONT of its update list (SelfList::add): the newest is allocated first, so
	# the oldest new ones of a frame are the ones refused (FLACKER-ANALYSE measured it: the first quads were refused)
	order.reverse()
	for gi: GeometryInstance3D in order:
		var ok := _alloc_n < CAPACITY
		if ok:
			_alloc_n += 1
		else:
			refused += 1
		_alive[gi.get_instance_id()] = [ok, f, _tag(gi)]
	_alloc_peak = maxi(_alloc_peak, _alloc_n + 0)
	if refused > 0:
		_pred_ref_total += refused
		_pred_ref_frames[f] = refused
		var tags: Dictionary = {}
		for gi: GeometryInstance3D in order.slice(order.size() - refused):    # (reversed: the last ones are the oldest)
			var tg := _tag(gi)
			tags[tg] = int(tags.get(tg, 0)) + 1
		_event({"ev": "refused", "f": f, "n": refused, "tags": tags, "alloc_n": _alloc_n})
	return refused


func _tag(gi: GeometryInstance3D) -> String:
	var p: Node = gi.get_parent()
	var s := str(gi.name)
	for i in 4:
		if p == null:
			break
		s = str(p.name) + "/" + s
		p = p.get_parent()
	return s.left(80)


func _uses_iu(gi: GeometryInstance3D) -> bool:
	var ov: Material = gi.material_override
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	var key := "%d|%d" % [ov.get_instance_id() if ov != null else 0, mesh.get_instance_id() if mesh != null else 0]
	if gi is MeshInstance3D and (gi as MeshInstance3D).get_surface_override_material_count() > 0:
		for k in (gi as MeshInstance3D).get_surface_override_material_count():
			var so: Material = (gi as MeshInstance3D).get_surface_override_material(k)
			if so != null:
				key += "|%d" % so.get_instance_id()
	var c: Variant = _iu_cache.get(key)
	if c != null:
		return bool(c)
	var res := false
	if ov != null:
		res = _mat_iu(ov)
	elif mesh != null:
		for k in mesh.get_surface_count():
			var m: Material = null
			if gi is MeshInstance3D:
				m = (gi as MeshInstance3D).get_active_material(k)
			else:
				m = mesh.surface_get_material(k)
			if m != null and _mat_iu(m):
				res = true
				break
	# the overlay material counts as well
	if not res and gi.material_overlay != null:
		res = _mat_iu(gi.material_overlay)
	_iu_cache[key] = res
	return res


func _mat_iu(m: Material) -> bool:
	if m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		if sh == null:
			return false
		var c: Variant = _shader_iu.get(sh.get_instance_id())
		if c == null:
			c = sh.code.contains("instance uniform")
			_shader_iu[sh.get_instance_id()] = c
		if bool(c):
			return true
		if m.next_pass != null:
			return _mat_iu(m.next_pass)
	return false


func _finish() -> bool:
	Engine.time_scale = 1.0
	OS.remove_logger(_catch)
	var km := float(_sc.get("pos_km")) if _sc != null else -1.0
	var summary := {"args": _args, "frames": _frames, "live_frames": _live, "km_start": _km0, "km_end": km,
		"view_s": float((_sc.get("renderer").get("view") as Dictionary).get("time", 0.0)) - _t0 if _sc != null and _sc.get("renderer") != null else -1.0,
		"refusals_caught": _catch.hits, "refusal_frames_caught": _catch.frame_hits.size(), "realloc_errors": _catch.realloc,
		"refusals_predicted": _pred_ref_total, "refusal_frames_predicted": _pred_ref_frames.size(), "alloc_mismatch_frames": _mismatch_frames,
		"alloc_peak": _alloc_peak, "stats": _stats, "shots": _shot_n, "wall_s": (Time.get_ticks_msec() - _wall0) / 1000.0,
		"other_errors": _catch.others}
	var g := FileAccess.open(_out + "_summary.json", FileAccess.WRITE)
	if g != null:
		g.store_string(JSON.stringify(summary, "  "))
		g.close()
	_log.close()
	_ev.close()
	print("PROBE summary ", JSON.stringify(summary))
	quit(0)
	return true
