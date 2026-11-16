extends SceneTree
## FLACKER-ANALYSE (scratch only): counts the geometry instances whose material has instance uniforms (16 slots each of
## Godot's global shader buffer, 4096 slots = 256 instances incl. the globals) while the autopilot drives a stage in
## Modern – split into vehicles, props and the rest – headless (the count is a property of the scene tree).
## usage: godot --headless --path . -s res://flk_count.gd -- --gfx-preset=medium --flk-stage=erfurt_kassel
##        --flk-from=kassel --flk-km=0 --flk-span-km=155 --flk-scale=6

const RACE := "res://scenes/race/race.tscn"

var _sc: Node
var _frames := 0
var _t0 := -1.0
var _scale := 6.0
var _span_km := 155.0
var _start_km := 0.0
var _rows: Array = []
var _max := {"total": 0, "veh": 0, "props": 0, "other": 0}
var _max_at := 0.0
var _wall0 := 0
var _hist := {}
var _per_km := {}
var _label := ""


func _arg(name: String, def: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_scale = float(_arg("flk-scale", "6"))
	_span_km = float(_arg("flk-span-km", "155"))
	_start_km = float(_arg("flk-km", "0"))
	var stage := _arg("flk-stage", "erfurt_kassel")
	var from := _arg("flk-from", "kassel")
	_label = "%s ab %s km %.1f preset %s" % [stage, from, _start_km, _arg("gfx-preset", "?")]
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": stage, "from_city": from, "vehicle": "limousine",
		"start_world_minutes": 13.0 * 60.0, "weather": "normal", "start_km": _start_km, "autopilot": true, "seed": 3,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_dt: float) -> bool:
	_frames += 1
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return _frames > 20000 and _finish("kein Start")
	var r: Object = _sc.get("renderer")
	var view: Dictionary = r.get("view")
	if _t0 < 0.0:
		_t0 = float(view.get("time", 0.0))
		Engine.time_scale = _scale
	if _frames % 4 == 0:
		_sample(r, view)
	var km := _km(view)
	if km - _start_km >= _span_km:
		return _finish("strecke")
	if bool(_sc.get("finished")):
		return _finish("ziel")
	if Time.get_ticks_msec() - _wall0 > 40 * 60 * 1000:
		return _finish("wanduhr")
	return false


func _km(view: Dictionary) -> float:
	var p: Variant = view.get("player", {})
	var tr: Variant = _sc.get("track")
	if p is Dictionary and tr != null and (tr as Object).has_method(&"z_to_km"):
		return float((tr as Object).call(&"z_to_km", float((p as Dictionary).get("z", 0.0))))
	return float(view.get("camera_z", 0.0)) / 1000.0


func _sample(r: Object, view: Dictionary) -> void:
	var c := _count(root)
	var km := _km(view)
	var vl: Object = r.call(&"layer", "vehicles")
	var pf: Dictionary = vl.call(&"perf") if vl != null else {}
	c["layer_inst"] = int(pf.get("vehicle_instances", 0))
	c["cars"] = int(pf.get("vehicles", 0))
	c["km"] = snappedf(km, 0.01)
	_rows.append(c)
	if int(c["total"]) > int(_max["total"]):
		_max = c
		_max_at = km
	var b := int(c["total"]) / 10 * 10
	_hist[b] = int(_hist.get(b, 0)) + 1
	var k := int(km)
	var e: Dictionary = _per_km.get(k, {"total": 0, "props": 0, "veh": 0})
	for key: String in ["total", "props", "veh"]:
		e[key] = maxi(int(e[key]), int(c[key]))
	_per_km[k] = e


## Instances with instance uniforms: vehicles = under a node "car_*" (vehicle layer roots), props = under a "Props"
## holder, other = the rest (roadside, stations, gantries, stand-in sheets …).
func _count(n: Node) -> Dictionary:
	var out := {"total": 0, "veh": 0, "props": 0, "other": 0, "props_by": {}}
	var stack: Array = [[n, ""]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var x: Node = it[0]
		var cat: String = it[1]
		var nm := str(x.name)
		if cat == "":
			if nm.begins_with("car_"):
				cat = "veh"
			elif nm == "Props":
				cat = "props"
		for ch in x.get_children():
			stack.append([ch, cat])
		if not (x is GeometryInstance3D) or x.is_queued_for_deletion():
			continue
		if _uses(x as GeometryInstance3D):
			out["total"] += 1
			var c2 := cat if cat != "" else "other"
			out[c2] += 1
			if c2 == "props" and x is MultiMeshInstance3D:
				var mm := (x as MultiMeshInstance3D).multimesh
				var key := str(mm.mesh.resource_path.get_file()) if mm != null and mm.mesh != null else "?"
				var pb: Dictionary = out["props_by"]
				pb[key] = int(pb.get(key, 0)) + 1
			elif c2 == "other":
				var pb2: Dictionary = out["props_by"]
				var key2 := "other:" + str(x.get_parent().name if x.get_parent() != null else "?")
				pb2[key2] = int(pb2.get(key2, 0)) + 1
	return out


static func _uses(gi: GeometryInstance3D) -> bool:
	var mats: Array[Material] = []
	if gi.material_override != null:
		mats.append(gi.material_override)
	if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
		var mi := gi as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(k)
			if m != null:
				mats.append(m)
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
		var mesh := (gi as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for k in mesh.get_surface_count():
				var m2: Material = mesh.surface_get_material(k)
				if m2 != null:
					mats.append(m2)
	for m: Material in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("instance uniform"):
			return true
	return false


func _finish(why: String) -> bool:
	Engine.time_scale = 1.0
	var keys := _hist.keys()
	keys.sort()
	var hs: Array[String] = []
	for k: int in keys:
		hs.append("%d-%d:%d" % [k, k + 9, int(_hist[k])])
	var over := 0
	var near := 0
	for row: Dictionary in _rows:
		if int(row["total"]) > 255:
			over += 1
		if int(row["total"]) > 230:
			near += 1
	print("FLK %s (%s): %d Proben, max ganze Szene %d bei km %.1f (Fahrzeuge %d, Requisiten %d, Rest %d; Ebene %d, Autos %d) – über 255: %d, über 230: %d; %.0f s Wand" % [
		_label, why, _rows.size(), int(_max["total"]), _max_at, int(_max["veh"]), int(_max["props"]), int(_max["other"]),
		int(_max.get("layer_inst", 0)), int(_max.get("cars", 0)), over, near, (Time.get_ticks_msec() - _wall0) / 1000.0])
	print("FLK max props_by ", JSON.stringify(_max.get("props_by", {})))
	print("FLK hist ", " ".join(hs))
	var ks := _per_km.keys()
	ks.sort()
	var pk: Array[String] = []
	for k: int in ks:
		var e: Dictionary = _per_km[k]
		pk.append("%d:%d/%d/%d" % [k, int(e["total"]), int(e["props"]), int(e["veh"])])
	print("FLK per km (max total/props/veh) ", " ".join(pk))
	quit(0)
	return true
