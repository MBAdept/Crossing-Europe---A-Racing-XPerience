extends SceneTree
## Vehicle layer, flare layer and signs of the mode "Modern" (R3; contract §6 R3, docs/renderer-modern.md §10),
## checked headless in the real race scene with the shipped renderer (every layer and builder that exists):
##   godot --headless --path . -s res://tests/race3d/check_vehicles.gd [-- --only=lampen,leistung]
## tools/run_tests.sh runs it through its generic hook (tests/race3d/check_*.gd).
##   lampen     every car of the view within sight is in debug_snapshot().vehicles with its set, model (or the box
##              stand-in) and the lamp levels of its view flags (tail with the lights of the palette and inside
##              tunnels, brake, indicators with Arcade's period, beacons) – by day and at night, with traffic
##   kasten     a set without a model (traffic/sports_red, police/at) is drawn as the box stand-in, never missing;
##              the semitrailer is drawn in two units at lod0
##   leistung   23 cars in sight (traffic of every kind incl. trucks and stand-ins, indicators and brakes): GDScript
##              time of the vehicle layer per car and frame <= 40 µs (median over the frames, after the nodes of
##              all cars exist); no node is created while the same cars drive on
##   schilder   the signs of the stage are drawn from the atlas made in prepare(): no SubViewport and no texture
##              is created while driving (SignAtlas counters), every sign the chunks hold has an atlas cell
##   lampen_fest  renderer.add_lamps(parent, lamps) (A-7) reaches the flare layer: static lamps glow at night (not
##              by day), follow their parent when it moves, are stronger far away (far-field glow) and are forgotten
##              when the parent leaves the tree
##   schatten   every preset (deck, low, medium, high – one stage each, the renderer takes its quality once): a
##              contact shadow lies under every car in sight (models, stand-ins, the player), the model's shadow hull
##              or the stand-in itself casts exactly when the quality levels have vehicle casters
## Prints "CHECK <name> OK|FEHLER …"; exit code 0 when all pass. (Autoloads are reached untyped: -s scripts compile
## before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const CHECKS := ["lampen", "kasten", "leistung", "schilder", "lampen_fest", "schatten"]
const PLAYER_ID := -999999

var _failed: Array[String] = []
var _probe: GDScript
var _renderers: GDScript
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_probe = load(PROBE)
	_renderers = load("res://scripts/race/race_renderers.gd")
	var settings: Node = root.get_node("Settings")
	settings.call("disarm_crash_guard")
	var cli := CliArgs.all()
	var cli_graphics: Variant = cli.get("graphics", null)
	cli.erase("graphics")
	var only := str(cli.get("only", ""))
	_renderers.set("modern_script", PROBE)
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_probe.call("reset")
	_renderers.set("modern_script", _renderers.get("MODERN_SCRIPT"))
	settings.call("disarm_crash_guard")
	if cli_graphics != null:
		cli["graphics"] = cli_graphics
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems.slice(0, 8))])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _launch(extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	root.add_child(sc)
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, max_frames: int = 3000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _ready_stage(sc: Node) -> ModernRenderer:
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 2, 3000)
	return sc.get("renderer") as ModernRenderer


func _snap_by_id(r: ModernRenderer) -> Dictionary:
	var out := {}
	for v: Dictionary in r.debug_snapshot().get("vehicles", []):
		out[int(v["id"])] = v
	return out


# --- lampen ------------------------------------------------------------------------------------------------------

func _check_lampen() -> void:
	var p: Array[String] = []
	_probe.call("reset")
	var compared := 0
	var states := {}
	for hour: float in [12.0, 22.0]:
		var sc := _launch({"start_world_minutes": hour * 60.0, "traffic_warmup": true})
		var r := await _ready_stage(sc)
		if r == null or not r.has_method("debug_snapshot"):
			_need(p, false, "Modern-Renderer der Etappe (%.0f Uhr)" % hour)
			await _free(sc)
			continue
		for f in 90:
			await process_frame
			if f % 6 != 0:
				continue
			var snap := _snap_by_id(r)
			var view: Dictionary = r.view
			var cam_z := float(view.get("camera_z", 0.0))
			var vis := float(view.get("visibility_m", 900.0))
			for c: Dictionary in view.get("cars", []):
				var z := float(c.get("z", 0.0))
				if z < cam_z + 5.0 or z > cam_z + vis:
					continue
				var id := int(c.get("id", -1))
				if not snap.has(id):
					_need(p, false, "Auto %d (%s, %.0f m) im Schnappschuss" % [id, str(c.get("set", "")), z - cam_z])
					continue
				var s: Dictionary = snap[id]
				var in_tunnel := r.track.is_tunnel_at(z + float(c.get("length", 4.5)) * 0.5)
				var la := VehiclePose3D.lamp_a(c, in_tunnel)
				var lb := VehiclePose3D.lamp_b(c, in_tunnel)
				var lamps: Dictionary = s["lamps"]
				var got := Vector4(float(lamps["tail"]), float(lamps["brake"]), float(lamps["ind_l"]), float(lamps["ind_r"]))
				var got_b := Vector4(float(lamps["head"]), 0.0, float(lamps["beacon_a"]), float(lamps["beacon_b"]))
				_need(p, got.is_equal_approx(la) and got_b.is_equal_approx(lb), "Lampen von Auto %d = Ansicht (%s / %s gegen %s / %s)" % [id, str(got), str(got_b), str(la), str(lb)])
				_need(p, str(s["set"]) == str(c.get("set", "")), "Set von Auto %d" % id)
				_need(p, bool(s["shown"]), "Auto %d gezeigt (%.0f m)" % [id, z - cam_z])
				var expect_model := str(ModelDB.resolve(str(c.get("set", ""))).get("model_id", ""))
				_need(p, str(s["model"]) == expect_model and bool(s["box"]) == (expect_model == ""), "Modell von Auto %d (%s)" % [id, expect_model])
				compared += 1
				states["tail" if la.x > 0.5 else "no_tail"] = true
				if la.y > 0.5:
					states["brake"] = true
				if la.z > 0.5 or la.w > 0.5:
					states["indicator"] = true
			if snap.has(PLAYER_ID):
				var pl: Dictionary = view.get("player", {})
				var ps: Dictionary = snap[PLAYER_ID]
				var pa := VehiclePose3D.lamp_a(pl, r.track.is_tunnel_at(float(pl.get("z", 0.0)) + 2.4))
				_need(p, absf(float((ps["lamps"] as Dictionary)["tail"]) - pa.x) < 1.0e-4, "Rücklicht des Spielers")
		await _free(sc)
	_need(p, compared >= 30, "genug Autos verglichen (%d)" % compared)
	_need(p, states.has("tail") and states.has("no_tail"), "Tag und Nacht gesehen (%s)" % str(states.keys()))
	_report("lampen", p, "%d Autos der Ansicht mit Set, Modell und Lampen im Schnappschuss (Zustände: %s)" % [compared, ", ".join(PackedStringArray(states.keys()))])


# --- kasten ------------------------------------------------------------------------------------------------------

func _check_kasten() -> void:
	var p: Array[String] = []
	var sc := _launch({"autopilot": false, "start_speed_kmh": 0.0})
	var r := await _ready_stage(sc)
	var cam_z := float(r.view.get("camera_z", 0.0))
	var x := float((r.view.get("player", {}) as Dictionary).get("x", 0.0))
	_probe.set("inject", [
		{"kind": "car", "id": 9101, "set": "traffic/sports_red", "z": cam_z + 30.0, "x": x - 3.75, "length": 4.45, "tail": 0.0, "brake": 1.0, "speed": 0.0},
		{"kind": "car", "id": 9102, "set": "police/at", "z": cam_z + 45.0, "x": x, "length": 4.8, "tail": 0.0, "brake": 0.0, "speed": 0.0, "beacon": "a"},
		{"kind": "car", "id": 9103, "set": "traffic/truck_white", "z": cam_z + 25.0, "x": x + 3.75, "length": 16.5, "tail": 0.0, "brake": 0.0, "speed": 0.0}])
	await _frames(4)
	var snap := _snap_by_id(r)
	for id: int in [9101, 9102]:
		var s: Dictionary = snap.get(id, {})
		_need(p, not s.is_empty() and bool(s["box"]) and bool(s["shown"]) and str(s["lod"]) == "box", "Set ohne Modell als Kasten gezeigt (%d: %s)" % [id, str(s)])
	_need(p, float(((snap.get(9102, {}) as Dictionary).get("lamps", {}) as Dictionary).get("beacon_a", 0.0)) == 1.0, "Blaulicht des Kastens")
	var truck: Dictionary = snap.get(9103, {})
	_need(p, not truck.is_empty() and str(truck["lod"]) == "lod0" and not bool(truck["box"]), "Sattelzug mit Modell in lod0")
	var vl: Node = r.layer("vehicles")
	var groups := 0
	if vl != null:
		for n: Node in vl.call("debug_units", 9103):
			groups += 1
	_need(p, groups == 2, "Sattelzug in zwei Einheiten (Zugmaschine, Auflieger: %d)" % groups)
	_probe.call("reset")
	await _free(sc)
	_report("kasten", p, "Sets ohne Modell als Kasten mit Lampen, Sattelzug in %d Einheiten" % groups)


# --- leistung ----------------------------------------------------------------------------------------------------

func _check_leistung() -> void:
	var p: Array[String] = []
	var sc := _launch({"autopilot": false, "start_speed_kmh": 0.0})
	var r := await _ready_stage(sc)
	var cam_z := float(r.view.get("camera_z", 0.0))
	var x0 := float((r.view.get("player", {}) as Dictionary).get("x", 0.0))
	var sets := ["traffic/sedan_red", "traffic/hatch_blue", "traffic/wagon_silver", "traffic/truck_red", "traffic/sports_blue",
		"traffic/van_white", "traffic/bus_red", "traffic/suv_grey", "police/de"]
	var cars: Array = []
	for i in 23:
		var lane := float(i % 3 - 1) * 3.75
		var sid: String = sets[i % sets.size()]
		var l := float(ModelDB.object_size(sid).get("length_m", 4.5))
		cars.append({"kind": "car", "id": 9200 + i, "set": sid, "z": cam_z + 14.0 + float(i) * 17.0, "x": x0 + lane, "length": l,
			"tail": 0.0, "brake": 1.0 if i % 4 == 0 else 0.0, "speed": 0.0, "blink": 1 if i % 5 == 0 else 0, "blink_t": 0.1})
	_probe.set("inject", cars)
	await _frames(30)
	var vl: Node = r.layer("vehicles")
	var before: Dictionary = vl.call("perf")
	var samples: Array[float] = []
	var drawn := 0
	for f in 120:
		var t0 := Time.get_ticks_usec()
		vl.call("update", r.view, 1.0 / 60.0)
		var us := float(Time.get_ticks_usec() - t0)
		drawn = int((vl.call("perf") as Dictionary)["vehicles"])
		samples.append(us / maxf(1.0, float(drawn)))
		await process_frame
	samples.sort()
	var median := samples[samples.size() / 2]
	var after: Dictionary = vl.call("perf")
	_need(p, drawn >= 23, "23 Autos gezeichnet (%d)" % drawn)
	_need(p, median <= 40.0, "≤ 40 µs je Auto und Bild (Median %.1f µs)" % median)
	_need(p, int(after["vehicle_builds"]) == int(before["vehicle_builds"]), "keine Knoten gebaut, solange dieselben Autos fahren (%d → %d)" % [int(before["vehicle_builds"]), int(after["vehicle_builds"])])
	_probe.call("reset")
	await _free(sc)
	_report("leistung", p, "%d Autos (Pkw, Lkw, Kästen, Polizei): Fahrzeug-Ebene im Median %.1f µs je Auto und Bild (p90 %.1f µs), %d Knotenbauten beim Erscheinen" % [
		drawn, median, samples[int(samples.size() * 0.9)], int(after["vehicle_builds"])])


# --- schatten --------------------------------------------------------------------------------------------------------

func _check_schatten() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	var settings: Node = root.get_node("Settings")
	var cli := CliArgs.all()
	var saved_cli := {}
	for k: String in ["gfx-preset", "gfx"]:
		if cli.has(k):
			saved_cli[k] = cli[k]
			cli.erase(k)
	var saved_preset := str(settings.get("gfx_preset"))
	var sets := ["traffic/sedan_red", "traffic/truck_red", "traffic/sports_blue", "police/de"]
	for preset: String in ["deck", "low", "medium", "high"]:
		settings.set("gfx_preset", preset)
		var sc := _launch({"autopilot": false, "start_speed_kmh": 0.0})
		var r := await _ready_stage(sc)
		var cam_z := float(r.view.get("camera_z", 0.0))
		var x0 := float((r.view.get("player", {}) as Dictionary).get("x", 0.0))
		var cars: Array = []
		for i in sets.size():
			var sid: String = sets[i]
			cars.append({"kind": "car", "id": 9400 + i, "set": sid, "z": cam_z + 18.0 + float(i) * 24.0,
				"x": x0 + (3.75 if i % 2 == 1 else 0.0), "length": float(ModelDB.object_size(sid).get("length_m", 4.5)),
				"tail": 0.0, "brake": 0.0, "speed": 0.0})
		_probe.set("inject", cars)
		await _frames(20)
		var want := int(r.levels.get("shadow_casters", 0)) >= 1
		var vl: Node = r.layer("vehicles")
		var buf: PackedFloat32Array = vl.get("_shadow_buf")
		var n := int((vl.call("perf") as Dictionary).get("contact_shadows", 0))
		var near := 0
		var under := 0
		var placed := 0
		var hulls := 0
		for v: Dictionary in (vl.call("snapshot") as Dictionary)["vehicles"]:
			if not bool(v["shown"]) or float(v["fade"]) < 0.05:
				continue
			near += 1
			var id := int(v["id"])
			if bool(v["player"]) or (id >= 9400 and id < 9400 + sets.size()):
				placed += 1
			var pa: Array = v["pos"]
			var pos := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
			var found := false
			for j in n:
				var o := j * 16
				if Vector3(buf[o + 3], buf[o + 7], buf[o + 11]).distance_to(pos) < 0.1:
					found = true
					break
			if found:
				under += 1
			else:
				p.append("%s: kein Kontaktschatten unter %s" % [preset, str(v["set"])])
			if bool(v["cast"]) != want:
				p.append("%s: %s wirft %s Schatten" % [preset, str(v["set"]), "keinen" if want else "einen"])
			if int(v["caster"]) >= 0:
				hulls += 1
				if (int(v["caster"]) == 1) != want:
					p.append("%s: Schattenhülle von %s %s" % [preset, str(v["set"]), "verborgen" if want else "sichtbar"])
		_need(p, placed == sets.size() + 1, "%s: die 4 gestellten Autos und das Spielerauto in Sicht (%d)" % [preset, placed])
		_need(p, hulls >= 1, "%s: mindestens ein Modell mit Schattenhülle (%d)" % [preset, hulls])
		msgs.append("%s: Werfer %s, Kontaktschatten unter %d von %d Autos" % [preset, "an" if want else "aus", under, near])
		_probe.call("reset")
		await _free(sc)
	settings.set("gfx_preset", saved_preset)
	for k: Variant in saved_cli:
		cli[k] = saved_cli[k]
	_report("schatten", p, "; ".join(msgs))


# --- lampen_fest -----------------------------------------------------------------------------------------------------

func _statics(fl: Node) -> Array:
	var out: Array = []
	for f: Dictionary in fl.call("flares"):
		if not bool(f["vehicle"]):
			out.append(f)
	return out


## The static flares that belong to the test lamps: within 12 m of one of the given nodes.
func _own(flares: Array, nodes: Array) -> Array:
	var out: Array = []
	for f: Dictionary in flares:
		for n: Variant in nodes:
			if is_instance_valid(n) and (f["pos"] as Vector3).distance_to((n as Node3D).global_position) < 12.0:
				out.append(f)
				break
	return out


func _check_lampen_fest() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	for hour: float in [12.0, 22.0]:
		var sc := _launch({"autopilot": false, "start_speed_kmh": 0.0, "start_world_minutes": hour * 60.0})
		var r := await _ready_stage(sc)
		var fl: Node = r.layer("flares")
		if fl == null:
			_need(p, false, "Ebene flares")
			await _free(sc)
			break
		var cam_z := float(r.view.get("camera_z", 0.0))
		# the stage's own static lamps (street lights, wall lamps and beacons of the prop models since the assembly of
		# M1) are the baseline: the two test lamps come on top and must go again (the car stands, nothing streams)
		var base_flares := _statics(fl).size()
		var base_lamps := int((fl.call("snapshot") as Dictionary)["lights"]["static_lamps"])
		var near := Node3D.new()
		var far := Node3D.new()
		r.world.add_child(near)
		r.world.add_child(far)
		near.transform = r.path.frame_at(cam_z + 40.0, 9.0, 0.0)
		far.transform = r.path.frame_at(cam_z + 0.6 * float(r.visibility_m), 9.0, 0.0)
		var lamp := {"pos": Vector3(-2.1, 9.3, 0.0), "dir": Vector3.DOWN, "role": "lights", "color": Color(1.0, 0.94, 0.8), "size": 0.6,
			"range": 12.0, "energy": 1.0}
		r.add_lamps(near, [lamp])
		r.add_lamps(far, [lamp])
		await _frames(3)
		var st := _own(_statics(fl), [near, far])
		if hour < 18.0:
			_need(p, st.is_empty() and _statics(fl).size() == base_flares, "bei Tag leuchten die Lampen nicht (%d Lichtpunkte)" % st.size())
		else:
			_need(p, st.size() == 2, "nachts beide Lampen als Lichtpunkt (%d, dazu %d der Etappe)" % [st.size(), base_flares])
			if st.size() == 2:
				var a: Dictionary = st[0]
				var b: Dictionary = st[1]
				var near_f: Dictionary = a if (a["pos"] as Vector3).distance_to(near.global_position) < (b["pos"] as Vector3).distance_to(near.global_position) else b
				var far_f: Dictionary = b if near_f == a else a
				var want := near.global_transform * (Vector3(-2.1, 9.3, 0.0) + Vector3.DOWN * 0.12)
				_need(p, (near_f["pos"] as Vector3).distance_to(want) < 0.01, "Lichtpunkt am Ort der Lampe (%s gegen %s)" % [str(near_f["pos"]), str(want)])
				_need(p, float(far_f["strength"]) > float(near_f["strength"]), "fern stärker als nah – Fernschein, wo die Leuchte unter einem Pixel ist (%.2f / %.2f)" % [float(far_f["strength"]), float(near_f["strength"])])
				msgs.append("Nacht: nah %.2f, fern %.2f" % [float(near_f["strength"]), float(far_f["strength"])])
				# the parent moves: the flare follows
				near.position += Vector3(0.0, 0.0, -5.0)
				await _frames(2)
				var moved := false
				for f: Dictionary in _statics(fl):
					moved = moved or (f["pos"] as Vector3).distance_to(near.global_transform * (Vector3(-2.1, 9.3, 0.0) + Vector3.DOWN * 0.12)) < 0.01
				_need(p, moved, "Lichtpunkt folgt seinem Knoten")
		near.queue_free()
		far.queue_free()
		await _frames(3)
		_need(p, _statics(fl).size() == base_flares, "%.0f Uhr: Lampen vergessen, wenn der Knoten den Baum verlässt (%d statt %d)" % [
			hour, _statics(fl).size(), base_flares])
		_need(p, int((fl.call("snapshot") as Dictionary)["lights"]["static_lamps"]) == base_lamps, "%.0f Uhr: die Test-Lampen sind abgemeldet (%d statt %d)" % [
			hour, int((fl.call("snapshot") as Dictionary)["lights"]["static_lamps"]), base_lamps])
		await _free(sc)
	_report("lampen_fest", p, "add_lamps() → Ebene flares: bei Tag aus; %s; folgt dem Knoten; vergessen beim Freigeben" % ", ".join(msgs))


# --- schilder ----------------------------------------------------------------------------------------------------

func _check_schilder() -> void:
	var p: Array[String] = []
	var sc := _launch({"start_km": 1.0})
	var r := await _ready_stage(sc)
	var vp0 := int(SignAtlas.subviewports_created)
	var tx0 := int(SignAtlas.textures_created)
	var drive0 := int(SignAtlas.created_while_driving)
	var kinds := {}
	var seen := 0
	for f in 600:
		await process_frame
		if f % 30 == 0:
			for s: Dictionary in r.debug_snapshot().get("signs", []):
				kinds[str(s["kind"])] = true
				seen += 1
	var b: ChunkBuilder = r.builder("signs")
	var atlas: Variant = b.call("atlas") if b != null else null
	_need(p, b != null and atlas != null, "Builder signs mit Atlas")
	_need(p, int(SignAtlas.subviewports_created) == vp0 and int(SignAtlas.textures_created) == tx0, "keine SubViewport und keine Textur während der Fahrt (%d / %d → %d / %d)" % [
		vp0, tx0, int(SignAtlas.subviewports_created), int(SignAtlas.textures_created)])
	_need(p, int(SignAtlas.created_while_driving) == 0 and drive0 == 0, "Zähler created_while_driving = 0")
	_need(p, seen > 0, "Schilder in den Stücken (%s)" % str(kinds.keys()))
	if atlas != null:
		_need(p, int((atlas as Object).get("missing")) == 0, "jedes Schild hat eine Zelle im Atlas (fehlend: %d)" % int((atlas as Object).get("missing")))
	await _free(sc)
	_report("schilder", p, "%d Schilder gesehen (%s), Atlas in prepare() (%d Zellen), während der Fahrt nichts erzeugt" % [
		seen, ", ".join(PackedStringArray(kinds.keys())), ((atlas as Object).get("entries") as Dictionary).size() if atlas != null else 0])
