extends SceneTree
## Probe (RINT-B): the pop of the lod1 -> lod2 switch on screen. A model car (player hidden, still scene, noon) moves
## slowly away from 0.85 to 1.15 x vehicle_lod1_m; every frame the share of the car's pixels that changed against the
## frame before is counted (max channel difference > 0.06). Prints the switch frame, the change there, the largest
## change and the median change of the other frames (motion alone). Run under Xvfb (opengl3), --gfx-sync.
## usage: ... -s <this> -- --graphics=modern --gfx-sync [--set=traffic/sedan_red] [--out=<dir>] [--step=0.06]

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
var THRESH := 0.06

var _sc: Node
var _probe: GDScript
var _phase := 0
var _frames := 0
var _set := "traffic/sedan_red"
var _out := ""
var _step := 0.03
var _d := 0.0
var _d1 := 0.0
var _lod1 := 120.0
var _len := 4.5
var _cam_z := 0.0
var _x0 := 0.0
var _bg: Image
var _prev: Image
var _box := Rect2i()
var _car_px := 1
var _rows: Array = []        # [dist, lod, xfade, changed share]
var _strip: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			_set = a.substr(6)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--step="):
			_step = float(a.substr(7))
		elif a.begins_with("--thresh="):
			THRESH = float(a.substr(9))
	root.get_node("Settings").call("disarm_crash_guard")
	var rr: GDScript = load("res://scripts/race/race_renderers.gd")
	rr.set("modern_script", PROBE)
	_probe = load(PROBE)
	_probe.set("hide_player", true)
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _car() -> Dictionary:
	return {"kind": "car", "id": 9800, "set": _set, "z": _cam_z + _d - _len * 0.5, "x": _x0, "length": _len,
		"tail": 0.0, "brake": 0.0, "speed": 0.0}


func _snap() -> Dictionary:
	var r: Object = _sc.get("renderer")
	for v: Dictionary in (r.call("debug_snapshot") as Dictionary).get("vehicles", []):
		if int(v["id"]) == 9800:
			return v
	return {}


func _process(_dt: float) -> bool:
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return false
	_frames += 1
	var r: Object = _sc.get("renderer")
	match _phase:
		0:
			if _frames > 30:
				var view: Dictionary = r.get("view")
				_cam_z = float(view.get("camera_z", 0.0))
				_x0 = float((view.get("player", {}) as Dictionary).get("x", 0.0))
				var lv: Variant = r.get("levels")
				_lod1 = float((lv as Dictionary).get("vehicle_lod1_m", 120.0)) if lv is Dictionary else 120.0
				var sz: Dictionary = ModelDB.object_size(_set)
				_len = float(sz.get("length_m", 4.5))
				_bg = root.get_texture().get_image()
				_census("start")
				_d = 0.85 * _lod1
				_d1 = 1.15 * _lod1
				_probe.set("inject", [_car()])
				_phase = 1
				_frames = 0
		1:
			if _frames > 30:
				var im := root.get_texture().get_image()
				_box = _car_box(r, _snap())
				_car_px = 1
				_prev = im
				_phase = 2
				_frames = 0
		2:
			var im := root.get_texture().get_image()
			var v := _snap()
			var nb := _car_box(r, v)
			var ub := nb.merge(_box) if _box.size.x > 0 else nb
			_box = ub
			_rows.append([snappedf(_d, 0.01), str(v.get("lod", "")), float(v.get("xfade", 0.0)), _changed(_prev, im)])
			_box = nb
			if _out != "" and absf(_d - _lod1) < 6.0:
				_strip.append(im.get_region(_box.grow(6)))
			_prev = im
			_d += _step
			_probe.set("inject", [_car()])
			if _d > _d1:
				_report()
				return true
	return false


func _find_box(im: Image) -> void:
	var x0 := 100000
	var y0 := 100000
	var x1 := -1
	var y1 := -1
	var n := 0
	var cx := im.get_width() / 2
	for y in range(240, 470):
		for x in range(cx - 140, cx + 140):
			if _diff(im.get_pixel(x, y), _bg.get_pixel(x, y)) > THRESH:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
				n += 1
	_box = Rect2i(x0 - 3, y0 - 3, x1 - x0 + 7, y1 - y0 + 7)
	_car_px = maxi(n, 1)


func _diff(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


## share of the car's pixels (car in either frame: differs from the background) that changed against the frame before
func _changed(a: Image, b: Image) -> float:
	var n := 0
	var car := 0
	for y in range(_box.position.y, _box.end.y):
		for x in range(_box.position.x, _box.end.x):
			var bg := _bg.get_pixel(x, y)
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			var in_car := _diff(pa, bg) > THRESH or _diff(pb, bg) > THRESH
			if not in_car:
				continue
			car += 1
			if _diff(pa, pb) > THRESH:
				n += 1
	return float(n) / float(maxi(car, 1))


func _report() -> void:
	_census("end")
	var switch_i := -1
	for i in range(1, _rows.size()):
		if str(_rows[i][1]) != str(_rows[i - 1][1]) and switch_i < 0:
			switch_i = i
	var others: Array[float] = []
	var mx := 0.0
	var mx_i := -1
	var win := 0.0   # summed change over the 40 frames from the switch
	for i in _rows.size():
		var c := float(_rows[i][3])
		if c > mx:
			mx = c
			mx_i = i
		if switch_i >= 0 and i >= switch_i and i < switch_i + 40:
			win += c
		elif switch_i >= 0 and absf(i - switch_i) > 45:
			others.append(c)
	others.sort()
	var med: float = others[int(others.size() / 2.0)] if not others.is_empty() else 0.0
	var around: Array = []
	if switch_i >= 0:
		for i in range(maxi(switch_i - 2, 0), mini(switch_i + 34, _rows.size())):
			around.append(snappedf(float(_rows[i][3]) * 100.0, 0.1))
	print("POP " + JSON.stringify({"set": _set, "lod1_m": _lod1, "box": [_box.position.x, _box.position.y, _box.size.x, _box.size.y],
		"car_px": _car_px, "frames": _rows.size(), "switch_frame": switch_i,
		"switch_dist": _rows[switch_i][0] if switch_i >= 0 else -1.0,
		"max_change_pct": snappedf(mx * 100.0, 0.1), "max_at": mx_i, "median_other_pct": snappedf(med * 100.0, 0.1),
		"sum_40_frames_pct": snappedf(win * 100.0, 0.1), "around_switch_pct": around}))
	if _out != "" and not _strip.is_empty():
		var w: int = (_strip[0] as Image).get_width()
		var h: int = (_strip[0] as Image).get_height()
		var n := mini(_strip.size(), 40)
		var sheet := Image.create(w * 10, h * int(ceil(n / 10.0)), false, Image.FORMAT_RGBA8)
		for i in n:
			var src: Image = _strip[i]
			src.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(src, Rect2i(0, 0, mini(w, src.get_width()), mini(h, src.get_height())), Vector2i((i % 10) * w, (i / 10) * h))
		sheet.save_png(_out.path_join("pop_strip.png"))


## screen box of the car from its snapshot position (origin-relative world, the car's rear axle / origin on the road)
func _car_box(r: Object, v: Dictionary) -> Rect2i:
	var cam: Camera3D = r.get("camera")
	if cam == null or not v.has("pos"):
		return Rect2i()
	var pa: Array = v["pos"]
	var p := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
	var c0 := cam.unproject_position(p)
	var c1 := cam.unproject_position(p + Vector3(0.0, 1.6, 0.0))
	var scale := float(root.get_texture().get_size().x) / float(root.get_visible_rect().size.x)
	var dist := maxf(float(v.get("dist", 100.0)), 1.0)
	var half_w := 711.0 * 1.2 / dist * scale + 4.0
	var top := minf(c0.y, c1.y) * scale - 4.0
	var bottom := maxf(c0.y, c1.y) * scale + 4.0
	var cx := c0.x * scale
	return Rect2i(int(cx - half_w), int(top), int(2.0 * half_w), int(bottom - top))


## census of the geometry instances whose material has instance uniforms (16 slots each in the global buffer)
func _census(tag: String) -> void:
	var counts := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is GeometryInstance3D:
			var gi := n as GeometryInstance3D
			var mats: Array = []
			if gi.material_override != null:
				mats.append(gi.material_override)
			if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
				var mi := gi as MeshInstance3D
				for k in mi.mesh.get_surface_count():
					var m: Material = mi.get_active_material(k)
					if m != null:
						mats.append(m)
			var key := "other"
			for m in mats:
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
					var sp := (m as ShaderMaterial).shader.resource_path.get_file()
					if (m as ShaderMaterial).shader.code.contains("instance uniform"):
						key = sp
						break
			var parent_name := str(gi.get_parent().name) if gi.get_parent() != null else ""
			counts[key] = int(counts.get(key, 0)) + 1
	print("CENSUS %s %s" % [tag, JSON.stringify(counts)])
