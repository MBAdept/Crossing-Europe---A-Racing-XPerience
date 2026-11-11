extends SceneTree
## Facade of the Modern renderer (v0.8.0, docs/dev/v080_contract.md amendment A-7; German docs:
## docs/renderer-modern.md "Aufbau: Fassade, Ebenen, Haken"), checked headless in the real race scene:
##   godot --headless --path . -s res://tests/race3d/check_facade.gd [-- --only=haken,lampen]
## tools/run_tests.sh runs it through its generic hook (tests/race3d/check_*.gd). The renderer is the real one
## (tests/race3d/fixtures/facade_probe_renderer.gd only lets fixtures stand in for layers, builders and the rig);
## the fixtures facade_layer.gd and facade_builder.gd have every hook and record what happens to them. Every check
## but "geruest" runs the skeleton alone ("bare": no layer, builder or rig file of scripts/race3d/ is loaded), so
## the checks mean the same once the renderer packages have added their files.
##   haken      every hook of builders and layers is called in the documented order: all exist before the first
##              setup(); setup, apply_quality, prepare on all; nothing is updated and the stage does not start while
##              a prepare_pending() is above 0; then the chunks of the start view, the first update() of the builder
##              and of every layer (path integrated, camera placed, chunks committed), warmup_nodes(); the warm-up
##              nodes are freed; dt is 0 until is_prepared(); headless: no self-test, no warm-up frames
##   fassade    the public members of amendment A-7, layer(id), builder(id), road_to_world(), world_to_screen() =
##              ChaseCamera3D.project() = Camera3D.unproject_position(), camera = ChaseCamera3D (transform and
##              frustum for the logical picture size), services in collect() and commit()
##   lampen     add_lamps() reaches the layers "lights" and "flares" (and only those) with the parent node and
##              the lamps; add_pool_material() / pool_materials()
##   rebased    a move of the floating origin arrives at the builder, at the layers and at the signal, with the
##              streamer's shift
##   statistik  perf_stats() and debug_snapshot(): every key of contract §4.4.5, the hooks' perf() / snapshot()
##              merged in, the streamer's numbers
##   ausfall    a hook's fail_reason() during the preparation, a layer file that gives no node and a preparation
##              that never ends (timeout): healthy() is false with that reason, the session falls back to Arcade
##   umgebung   an environment rig: exposed as `env`, first in every hook phase, updated before the camera is
##              placed; no built-in environment beside it. Without a rig: the built-in plain environment
##              (BG_CANVAS behind layer -10, exactly one DirectionalLight3D with shadow_enabled) and plain sky;
##              the unshaded debug road carries the ambient colour of the palette (white at noon, dark at night)
##   geruest    the shipped renderer without any fixture, with whatever builders and layers exist: prepared (in two
##              frames while nothing has to load), the road or the debug road that stands in for it; a layer
##              exactly when its file exists; a stage that leaves frees every node. Bare: with a terrain builder
##              the debug road draws no rings. Sync mode (--gfx-sync) leaves nothing pending after any render()
## Prints "CHECK <name> OK|FEHLER …" per check; exit code 0 when all pass.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const PROBE := "res://tests/race3d/fixtures/facade_probe_renderer.gd"
const LAYER := "res://tests/race3d/fixtures/facade_layer.gd"
const BUILDER := "res://tests/race3d/fixtures/facade_builder.gd"
const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["haken", "fassade", "lampen", "rebased", "statistik", "ausfall", "umgebung", "geruest"]
const LAYER_IDS := ["backdrop", "far_ground", "lights", "vehicles", "flares", "weather", "overlay", "post"]
const FIXTURE_LAYERS := ["backdrop", "lights", "flares", "weather", "post"]
const PERF_KEYS := ["mode", "preset", "render_ms_avg", "render_ms_max", "chunks", "chunk_build_ms_avg", "chunk_build_ms_max",
	"chunk_commit_ms_max", "draw_calls", "draw_calls_shadow", "primitives", "primitives_shadow", "lights_omni", "lights_spot",
	"vehicles", "instances", "frame_ms_median", "frame_ms_p95", "prewarm_ms", "fallback_sets", "tex_mem_mb"]
const SNAPSHOT_KEYS := ["camera", "chunks", "vehicles", "lights", "props", "signs", "quality"]

var _failed: Array[String] = []
var _probe: GDScript
var _layer: GDScript
var _builder: GDScript
var _renderers: GDScript
var _settings: Node
var _scene: Node            ## the stage of the checks haken … statistik
var _wall0 := 0


func _initialize() -> void:
	var ts := 20.0
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = int(60.0 * ts)
	Engine.max_physics_steps_per_frame = 64
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_probe = load(PROBE)
	_layer = load(LAYER)
	_builder = load(BUILDER)
	_renderers = load("res://scripts/race/race_renderers.gd")
	_settings = root.get_node("Settings")
	_settings.call("disarm_crash_guard")
	var cli := CliArgs.all()
	var cli_graphics: Variant = cli.get("graphics", null)
	cli.erase("graphics")   # these checks choose the mode themselves
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	if _scene != null and is_instance_valid(_scene):
		await _free(_scene)
	_reset()
	_renderers.set("modern_script", _renderers.get("MODERN_SCRIPT"))
	_settings.call("disarm_crash_guard")
	if cli_graphics != null:
		cli["graphics"] = cli_graphics
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _reset() -> void:
	_probe.call("reset")
	_layer.call("reset")
	_builder.call("reset")


## The probe renderer, bare, with fixtures: `layers` = ids that get the fixture layer, `with_builder` adds the
## fixture builder (next to the debug road).
func _use(layers: Array, with_builder: bool) -> void:
	_reset()
	_renderers.set("modern_script", PROBE)
	_probe.set("bare", true)
	var scripts := {}
	for id: String in layers:
		scripts[id] = LAYER
	_probe.set("layer_scripts", scripts)
	var builders: Array[String] = []
	if with_builder:
		builders.append(BUILDER)
	_probe.set("builder_scripts", builders)


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
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP   # GameFlow does this between stages


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, max_frames: int = 4000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _renderer_file(sc: Node) -> String:
	var r: Variant = sc.get("renderer")
	if r == null or not (r is Object) or (r as Object).get_script() == null:
		return ""
	return str(((r as Object).get_script() as Script).resource_path).get_file()


func _log() -> Array[String]:
	var out: Array[String] = []
	for e: String in _layer.get("log"):
		out.append(e)
	return out


func _phase(hook: String, ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids:
		out.append(id + "." + hook)
	return out


## The stage of the first checks (fixture layers and builder, already driving), started on demand.
func _stage() -> Node:
	if _scene == null or not is_instance_valid(_scene):
		_use(FIXTURE_LAYERS, true)
		_scene = _launch({})
		await _until(func() -> bool: return int(_scene.get("_sim_steps")) > 0, 400)
	return _scene


## True when two lists hold the same strings in the same order (typed or not).
func _same_list(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array) or (a as Array).size() != (b as Array).size():
		return false
	for i in (a as Array).size():
		if str((a as Array)[i]) != str((b as Array)[i]):
			return false
	return true


func _nodes_of(n: Node, cls: String, out: Array) -> void:
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		_nodes_of(c, cls, out)


# --- haken: order of the hooks -----------------------------------------------------------------------------------

func _check_haken() -> void:
	var p: Array[String] = []
	_use(FIXTURE_LAYERS, true)
	_layer.set("pending_frames", {"lights": 4})
	_builder.set("pending_polls", 2)
	var sc := _launch({})
	_scene = sc
	var r: Node = sc.get("renderer")
	_need(p, _renderer_file(sc) == "facade_probe_renderer.gd" and r is ModernRenderer, "der echte Renderer mit Prüf-Ebenen")
	var ids: Array = ["facade_probe"] + FIXTURE_LAYERS
	# right after the scene is built: everything exists, the three hook phases ran, nothing else
	var want: Array[String] = []
	for hook: String in ["setup", "apply_quality", "prepare"]:
		want.append_array(_phase(hook, ids))
	_need(p, _log() == want, "erst setup auf allen, dann apply_quality, dann prepare – Builder vor den Ebenen in Listenfolge (ist: %s)" % " ".join(_log()))
	var at_setup: Dictionary = _layer.get("at_setup")
	var first: Dictionary = at_setup.get("backdrop", {})
	_need(p, _same_list(first.get("layers", []), FIXTURE_LAYERS), "alle Ebenen bestehen vor dem ersten setup() (%s)" % str(first.get("layers", [])))
	for key: String in ["camera", "world", "streamer", "materials", "chase", "terrain", "path", "levels", "prep", "in_tree", "probe_builder"]:
		_need(p, bool(first.get(key, false)), "in setup() vorhanden: " + key)
	_need(p, not bool(first.get("path_ready", true)), "der Pfad ist in setup() noch nicht integriert (erst ab dem ersten update())")
	var b_setup: Dictionary = _builder.get("at_setup")
	_need(p, bool(b_setup.get("layers_exist", false)) and bool(b_setup.get("registered", false)), "Builder: in setup() registriert, Ebenen bestehen")
	_need(p, ((_layer.get("quality_seen") as Dictionary).get("post", {}) as Dictionary).has("shadow_casters")
		and ((_layer.get("ctx_seen") as Dictionary).get("post", {}) as Dictionary).has("sets"), "apply_quality(levels) und prepare(ctx) mit den Daten der Sitzung")
	# while a hook is pending: no update, no chunk, no start
	var frames := 0
	var early_updates := 0
	var early_chunks := 0
	var early_steps := 0
	var early_warm := 0
	while not bool(r.call("is_prepared")) and frames < 200:
		await process_frame
		frames += 1
		if bool(r.call("is_prepared")):
			break
		var pending_now: bool = ((r.call("layer", "lights") as Node).get("_polls") as int) <= 4
		if pending_now:
			early_updates = maxi(early_updates, (_layer.get("updates") as Dictionary).size())
			early_chunks = maxi(early_chunks, int((r.get("streamer") as Node).call("chunk_count")))
			early_warm = maxi(early_warm, (_layer.get("warm_ids") as Array).size())
		early_steps = maxi(early_steps, int(sc.get("_sim_steps")))
	_need(p, frames >= 4, "die Vorbereitung dauert, solange ein prepare_pending() offen ist (%d Bilder)" % frames)
	_need(p, early_updates == 0 and early_chunks == 0 and early_warm == 0, "vorher kein update(), kein Stück, kein Aufwärmen (%d / %d / %d)" % [early_updates, early_chunks, early_warm])
	_need(p, early_steps == 0, "kein Simulationsschritt vor is_prepared()")
	want.append_array(_phase("prepare_pending", ids))
	want.append_array(["facade_probe.collect", "facade_probe.commit"] as Array[String])
	want.append_array(_phase("update", ids))
	want.append_array(_phase("warmup_nodes", ids))
	_need(p, _log() == want, "danach: Stücke der Startansicht, erstes update() des Builders und jeder Ebene, warmup_nodes() (ist: %s)" % " ".join(_log().slice(18)))
	var bu: Dictionary = _builder.get("at_update")
	_need(p, bool(bu.get("path_ready", false)) and bool(bu.get("camera_placed", false)) and int(bu.get("chunks", 0)) >= 4
		and int(bu.get("pending_chunks", 1)) == 0 and int(bu.get("layers_before", 1)) == 0,
		"Builder: erstes update() nach Streamer und Kamera, vor den Ebenen (%s)" % str(bu))
	var at_update: Dictionary = _layer.get("at_update")
	for id: String in FIXTURE_LAYERS:
		var u: Dictionary = at_update.get(id, {})
		_need(p, bool(u.get("path_ready", false)) and int(u.get("chunks", 0)) >= 4 and int(u.get("pending_chunks", 1)) == 0,
			"%s: beim ersten update() ist der Pfad integriert und die Startansicht eingehängt (%s)" % [id, str(u)])
		_need(p, bool(u.get("camera_placed", false)) and bool(u.get("view_is_current", false)) and bool(u.get("visibility", false)),
			"%s: Kamera steht, renderer.view und visibility_m sind die des Bildes" % id)
		_need(p, int(u.get("others_pending", 1)) == 0, "%s: kein update(), solange eine Vorbereitung offen ist" % id)
		var w: Dictionary = (_layer.get("at_warmup") as Dictionary).get(id, {})
		_need(p, int(w.get("chunks", 0)) >= 4 and int(w.get("pending_chunks", 1)) == 0 and int(w.get("updates", 0)) >= 1 and not bool(w.get("prepared", true)),
			"%s: warmup_nodes() nach den Stücken und dem ersten update(), vor is_prepared()" % id)
	var warm: Array = (_layer.get("warm_ids") as Array) + (_builder.get("warm_ids") as Array)
	var alive := 0
	for wid: int in warm:
		alive += 1 if is_instance_id_valid(wid) else 0
	_need(p, warm.size() == ids.size() and alive == 0, "die Aufwärm-Knoten sind nach der Vorbereitung freigegeben (%d von %d leben)" % [alive, warm.size()])
	_need(p, (r.get("selftest") as Dictionary).is_empty(), "headless: kein Selbsttest")
	await _until(func() -> bool: return float(sc.get("stage_time")) > 2.0, 600)
	await _frames(12)   # the time lapse makes 2 s of the stage only a handful of frames
	_need(p, int(sc.get("_sim_steps")) > 0 and str((sc.call("build_result") as Dictionary).get("gfx", "")) == "modern", "die Etappe läuft in Modern")
	_need(p, int(_builder.get("off_main")) == 0 and int(_builder.get("commits")) >= 4, "collect() und commit() im Hauptthread")
	var ups: Dictionary = _layer.get("updates")
	_need(p, int(ups.get("post", 0)) > 10 and int(ups.get("backdrop", 0)) == int(ups.get("post", 0))
		and int(ups.get("facade_probe", 0)) == int(ups.get("post", 0)), "update() jedes Bild am Builder und auf jeder Ebene (%s)" % str(ups))
	# the frozen start view stands still: dt is 0 until is_prepared(), the frame time afterwards
	var dt_prep: Dictionary = _layer.get("dt_preparing")
	var dt_live: Dictionary = _layer.get("dt_live")
	var dt_bad: Array[String] = []
	for id: String in ids:
		if not dt_prep.has(id) or float(dt_prep[id]) != 0.0 or float(dt_live.get(id, 0.0)) <= 0.0:
			dt_bad.append(id)
	_need(p, dt_bad.is_empty(), "dt = 0 während der Vorbereitung, danach die Bildzeit (falsch bei %s: %s / %s)" % [str(dt_bad), str(dt_prep), str(dt_live)])
	_report("haken", p, "%d Haken-Aufrufe in der dokumentierten Reihenfolge; %d Bilder Vorbereitung mit offenem prepare_pending(), %d Aufwärm-Knoten gezeigt und freigegeben" % [
		_log().size(), frames, warm.size()])


# --- fassade: public members -------------------------------------------------------------------------------------

func _check_fassade() -> void:
	var p: Array[String] = []
	var sc: Node = await _stage()
	var r: ModernRenderer = sc.get("renderer")
	_need(p, r.track == sc.get("track") and r.proj == sc.get("proj") and not r.cfg.is_empty() and not r.scenery_db.is_empty(), "track, proj, cfg, scenery_db")
	_need(p, r.levels.has("preset") and r.levels.has("msaa") and r.sync == false and r.prep.has("plan") and r.prep.has("sets"), "levels, sync, prep")
	_need(p, r.path != null and r.path.is_ready() and r.terrain != null and r.streamer != null and r.chase != null and r.camera != null, "path, terrain, streamer, chase, camera")
	_need(p, r.materials == ModernMaterials.shared() and r.world != null and r.world.global_transform == Transform3D.IDENTITY, "materials = ModernMaterials.shared(), world mit Einheitstransformation")
	_need(p, r.env == null, "env ist null, solange es environment_rig.gd nicht gibt")
	_need(p, r.streamer.get_parent() == r.world, "die Stücke hängen unter world")
	var view: Dictionary = r.view
	_need(p, view.has("camera_z") and view.has("palette") and is_equal_approx(r.visibility_m, float(view.get("visibility_m", -1.0))), "view und visibility_m des Bildes")
	for id: String in LAYER_IDS:
		var l := r.layer(id)
		if FIXTURE_LAYERS.has(id):
			_need(p, l != null and l.get_parent() == r and str(l.name) == id, "layer(\"%s\") ist ein Kind des Renderers mit dem Namen der Ebene" % id)
		else:
			_need(p, l == null, "layer(\"%s\") ist null ohne Datei" % id)
	_need(p, r.layer("gibt_es_nicht") == null, "unbekannte Ebene: null")
	_need(p, r.builder("debug_road") != null and r.builder("facade_probe") != null and r.builder("gibt_es_nicht") == null, "builder(id)")
	# road coordinates -> world -> screen
	var cam_z := float(view["camera_z"])
	var worst_world := 0.0
	var worst_px := 0.0
	var worst_engine := 0.0
	var size := root.get_visible_rect().size
	var fr := r.chase.frustum(size, view.get("shake", Vector2.ZERO))
	for d: float in [12.0, 40.0, 120.0, 300.0, 700.0]:
		for x: float in [-9.0, 0.0, 5.6]:
			var z := cam_z + d
			var w := r.road_to_world(z, x, 0.5)
			worst_world = maxf(worst_world, w.distance_to(r.path.world(z, x, 0.5)))
			var px := r.world_to_screen(z, x, 0.5)
			var want := ChaseCamera3D.project(r.chase.transform(view, r.path), fr, size, w)
			worst_px = maxf(worst_px, Vector2(px.x - want.x, px.y - want.y).length() + absf(px.z - want.z))
			var eng := r.camera.unproject_position(w)
			worst_engine = maxf(worst_engine, Vector2(px.x - eng.x, px.y - eng.y).length())
	_need(p, worst_world == 0.0, "road_to_world() = RoadPath3D.world()")
	_need(p, worst_px < 0.001, "world_to_screen() = ChaseCamera3D.project() (%.5f px)" % worst_px)
	_need(p, worst_engine < 0.02, "world_to_screen() = Camera3D.unproject_position() (%.4f px)" % worst_engine)
	var ahead := r.world_to_screen(cam_z + 100.0, 0.0, 0.0)
	_need(p, ahead.z > 99.0 and ahead.z < 101.0 and ahead.y > size.y * 0.45 and absf(ahead.x - size.x * 0.5) < 80.0, "ein Punkt 100 m voraus liegt unter dem Horizont in Bildmitte (%s)" % str(ahead))
	# the camera is the ChaseCamera3D
	var tr := r.chase.transform(view, r.path)
	_need(p, r.camera.global_transform.is_equal_approx(tr), "Kamera = ChaseCamera3D.transform(view, path)")
	_need(p, r.camera.projection == Camera3D.PROJECTION_FRUSTUM and r.camera.keep_aspect == Camera3D.KEEP_HEIGHT and r.camera.current, "Frustum-Kamera, KEEP_HEIGHT, aktiv")
	_need(p, is_equal_approx(r.camera.size, float(fr["size"])) and r.camera.frustum_offset.is_equal_approx(fr["offset"])
		and is_equal_approx(r.camera.near, float(fr["near"])) and is_equal_approx(r.camera.far, float(fr["far"])), "Frustum aus ChaseCamera3D.frustum() für die logische Bildgröße %s" % str(size))
	# services
	var sv: Dictionary = r.streamer.services
	_need(p, sv.get("renderer") == r and sv.get("materials") == r.materials, "ChunkStreamer.services = {renderer, materials}")
	var seen: Array = (_builder.get("services_in_collect") as Array) + (_builder.get("services_in_commit") as Array)
	var same := 0
	for s: Variant in seen:
		same += 1 if is_same(s, sv) else 0
	_need(p, seen.size() >= 8 and same == seen.size(), "ctx.services in collect() und commit() (%d von %d)" % [same, seen.size()])
	_report("fassade", p, "Mitglieder der Fassade gesetzt; world_to_screen gegen ChaseCamera3D %.5f px, gegen Camera3D %.4f px; services in %d Aufrufen" % [worst_px, worst_engine, seen.size()])


# --- lampen: add_lamps, add_pool_material -------------------------------------------------------------------------

func _check_lampen() -> void:
	var p: Array[String] = []
	var sc: Node = await _stage()
	var r: ModernRenderer = sc.get("renderer")
	var statics: Array = _layer.get("statics")
	var commits := int(_builder.get("commits"))
	var by_layer := {}
	for s: Array in statics:
		by_layer[str(s[0])] = int(by_layer.get(str(s[0]), 0)) + 1
	_need(p, commits >= 4 and int(by_layer.get("lights", 0)) == commits and int(by_layer.get("flares", 0)) == commits,
		"jede Lampe eines Stücks erreicht lights und flares (%d Stücke, %s)" % [commits, str(by_layer)])
	_need(p, by_layer.size() == 2, "nur lights und flares bekommen add_static() (%s)" % str(by_layer.keys()))
	var parents: Array = _builder.get("lamp_parents")
	var first: Array = statics[0] if not statics.is_empty() else ["", 0, [{}]]
	_need(p, not parents.is_empty() and int(first[1]) == int(parents[0]) and (first[2] as Array).size() == 1
		and str(((first[2] as Array)[0] as Dictionary).get("role", "")) == "street" and float(((first[2] as Array)[0] as Dictionary).get("range", 0.0)) == 9.0,
		"parent und lamps kommen unverändert an")
	var holder := Node3D.new()
	r.world.add_child(holder)
	var before := statics.size()
	r.add_lamps(holder, [{"pos": Vector3.ZERO, "role": "tunnel"}, {"pos": Vector3(1, 0, 0), "role": "tunnel"}])
	_need(p, statics.size() == before + 2 and int((statics[before] as Array)[1]) == holder.get_instance_id() and ((statics[before] as Array)[2] as Array).size() == 2, "add_lamps() direkt: beide Ebenen, zwei Lampen")
	r.add_lamps(holder, [])
	r.add_lamps(null, [{"pos": Vector3.ZERO}])
	_need(p, statics.size() == before + 2, "leere Liste oder kein parent: nichts")
	holder.queue_free()
	# pool materials
	var mats := r.pool_materials()
	var mat: ShaderMaterial = _builder.get("material")
	_need(p, mats.size() == 1 and mats[0] == mat, "add_pool_material(): dasselbe Material aus jedem Stück steht einmal in pool_materials() (%d)" % mats.size())
	var extra := ShaderMaterial.new()
	r.add_pool_material(extra)
	r.add_pool_material(extra)
	r.add_pool_material(null)
	_need(p, r.pool_materials().size() == 2 and r.pool_materials()[1] == extra, "ein weiteres Material, null wird ignoriert")
	_need(p, int(r.debug_snapshot().get("pool_materials", 0)) == 2 and int(r.debug_snapshot().get("lamps", 0)) == commits + 2, "Zähler im Schnappschuss")
	_report("lampen", p, "%d Lampen aus %d Stücken an lights und flares; %d Pool-Materialien" % [statics.size(), commits, r.pool_materials().size()])


# --- rebased --------------------------------------------------------------------------------------------------------

func _check_rebased() -> void:
	var p: Array[String] = []
	var sc: Node = await _stage()
	var r: ModernRenderer = sc.get("renderer")
	var got: Array[Vector3] = []
	var order: Array[int] = []
	r.rebased.connect(func(shift: Vector3) -> void:
		got.append(shift)
		order.append((_layer.get("shifts") as Array).size()))
	var from_streamer: Array[Vector3] = []
	r.streamer.rebased.connect(func(shift: Vector3) -> void: from_streamer.append(shift))
	r.streamer.rebase_m = 200.0   # the shipped 2 km would need a long drive
	var cam0 := r.camera.global_transform.origin
	await _until(func() -> bool: return got.size() >= 1, 3000)
	_need(p, got.size() >= 1, "der Ursprung wurde verlegt")
	if not got.is_empty():
		var shifts: Array = _layer.get("shifts")
		var mine: Array = shifts.filter(func(s: Array) -> bool: return (s[1] as Vector3) == got[0])
		var who: Array = []
		for s: Array in mine:
			who.append(str(s[0]))
		var ids: Array = ["facade_probe"] + FIXTURE_LAYERS
		_need(p, _same_list(who, ids), "rebased(shift) an den Builder und an jede Ebene in Listenfolge (%s)" % str(who))
		_need(p, order[0] == ids.size(), "erst Builder und Ebenen, dann das Signal")
		_need(p, from_streamer.size() >= 1 and from_streamer[0] == got[0] and got[0].length() > 150.0 and got[0].y == 0.0, "die Verschiebung des Streamers (%s)" % str(got[0]))
		_need(p, r.camera.global_transform.origin.length() < 60.0 and cam0.length() > 150.0, "die Kamera steht wieder nahe am Ursprung (%.0f m, vorher %.0f m)" % [
			r.camera.global_transform.origin.length(), cam0.length()])
		_need(p, int(r.perf_stats()["streamer"]["rebases"]) >= 1, "Zähler des Streamers")
	r.streamer.rebase_m = 2000.0
	_report("rebased", p, "Ursprung verlegt um %s: der Builder, %d Ebenen und das Signal benachrichtigt" % [str(got[0]) if not got.is_empty() else "–", FIXTURE_LAYERS.size()])


# --- statistik: perf_stats, debug_snapshot ------------------------------------------------------------------------

func _check_statistik() -> void:
	var p: Array[String] = []
	var sc: Node = await _stage()
	var r: ModernRenderer = sc.get("renderer")
	await _frames(20)
	var perf := r.perf_stats()
	for k: String in PERF_KEYS:
		_need(p, perf.has(k), "perf_stats: " + k)
	_need(p, str(perf.get("mode", "")) == "modern" and int(perf.get("frames", 0)) > 20 and float(perf.get("render_ms_avg", 0.0)) > 0.0
		and float(perf.get("render_ms_max", 0.0)) >= float(perf.get("render_ms_avg", 0.0)), "Zeiten von render()")
	_need(p, int(perf.get("chunks", 0)) == r.streamer.chunk_count() and int(perf.get("chunks", 0)) >= 4, "chunks = Stücke des Streamers")
	_need(p, float(perf.get("frame_ms_median", 0.0)) > 0.0 and float(perf.get("frame_ms_p95", 0.0)) >= float(perf.get("frame_ms_median", 0.0)), "Bildzeiten")
	# 5 layers + 1 builder report 3 instances each; "lights" one omni light; nobody reports vehicles
	_need(p, int(perf.get("instances", 0)) == 18 and int(perf.get("lights_omni", 0)) == 1 and int(perf.get("vehicles", -1)) == 0, "perf() der Haken addiert (instances %d, lights_omni %d)" % [
		int(perf.get("instances", 0)), int(perf.get("lights_omni", 0))])
	_need(p, int(perf.get("draw_calls", -1)) == 0 and float(perf.get("tex_mem_mb", -1.0)) == 0.0, "headless: keine Zähler des Renderers")
	_need(p, (perf.get("load", {}) as Dictionary).has("commits") and int((perf["load"] as Dictionary)["commits"]) >= 4, "Zeiten des Ladens getrennt (load)")
	var session_perf: Dictionary = sc.call("perf_stats")
	_need(p, str(session_perf.get("mode", "")) == "modern" and int(session_perf.get("sim_steps", 0)) > 0, "perf_stats der Sitzung")
	var snap := r.debug_snapshot()
	for k: String in SNAPSHOT_KEYS:
		_need(p, snap.has(k), "debug_snapshot: " + k)
	var cam: Dictionary = snap.get("camera", {})
	for k: String in ["z", "x", "y", "yaw_deg", "frustum"]:
		_need(p, cam.has(k), "camera." + k)
	_need(p, is_equal_approx(float(cam.get("z", 0.0)), float(r.view["camera_z"])) and (cam.get("frustum", {}) as Dictionary).has("size"), "Kamera des Bildes")
	var chunks: Array = snap.get("chunks", [])
	_need(p, chunks.size() == r.streamer.chunk_count() and chunks.size() >= 4, "chunks (%d)" % chunks.size())
	if not chunks.is_empty():
		var c: Dictionary = chunks[0]
		var parts: Dictionary = c.get("parts", {})
		_need(p, c.has("index") and c.has("seg_a") and c.has("seg_b") and int(c["seg_b"]) - int(c["seg_a"]) == 32, "Stück mit index, seg_a, seg_b")
		_need(p, parts.has("debug_road") and int((parts["debug_road"] as Dictionary).get("vertices", 0)) > 0 and int((parts.get("facade_probe", {}) as Dictionary).get("rows", 0)) == 33,
			"parts je Builder (debug_road, facade_probe)")
	_need(p, (snap.get("vehicles", []) as Array).size() == FIXTURE_LAYERS.size(), "snapshot() der Haken: Listen angehängt (vehicles %d)" % (snap.get("vehicles", []) as Array).size())
	var lights: Dictionary = snap.get("lights", {})
	_need(p, int(lights.get("omni", -1)) == 1 and int(lights.get("spot", -1)) == 0 and int(lights.get("pools", -1)) == 10, "lights zusammengeführt (%s)" % str(lights))
	_need(p, (snap.get("props", {}) as Dictionary).has("probe") and (snap.get("props", {}) as Dictionary).has("post") and (snap.get("signs", []) as Array).size() == 1, "props und signs")
	_need(p, (snap.get("quality", {}) as Dictionary).has("shadows") and _same_list(snap.get("layers", []), FIXTURE_LAYERS) and (snap.get("builders", []) as Array).has("facade_probe"), "quality, layers, builders")
	_need(p, str(snap.get("stage", "")) == "done" and bool(snap.get("prepared", false)), "Zustand der Vorbereitung")
	_need(p, bool((snap.get("environment", {}) as Dictionary).get("plain", false)) and not bool((snap.get("backdrop", {}) as Dictionary).get("plain", false)),
		"eingebaute Umgebung im Schnappschuss; der eingebaute Himmel fehlt, wenn es eine Ebene backdrop gibt")
	_report("statistik", p, "perf_stats %d Schlüssel (render() Ø %.3f ms, höchstens %.3f ms, %d Stücke, Bauen Ø %.2f ms), debug_snapshot %d Schlüssel" % [
		perf.size(), float(perf.get("render_ms_avg", 0.0)), float(perf.get("render_ms_max", 0.0)), int(perf.get("chunks", 0)),
		float(perf.get("chunk_build_ms_avg", 0.0)), snap.size()])
	await _free(sc)
	_scene = null


# --- ausfall: fail_reason of hooks, broken files, timeout ---------------------------------------------------------

func _fallback_of(sc: Node, max_frames: int = 600) -> String:
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, max_frames)
	return str(sc.get("gfx_fallback"))


func _check_ausfall() -> void:
	var p: Array[String] = []
	# a layer reports a reason in the middle of the preparation
	_use(["weather", "post"], true)
	_layer.set("pending_frames", {"post": -1})
	_layer.set("fail_after", {"weather": [3, "manifest"]})
	var sc := _launch({})
	var r: Node = sc.get("renderer")
	await _frames(1)
	_need(p, bool(r.call("healthy")) and not bool(r.call("is_prepared")), "vor dem Ausfall: gesund, in Vorbereitung")
	var why: String = await _fallback_of(sc)
	_need(p, why == "manifest" and _renderer_file(sc) == "road_renderer.gd", "fail_reason() einer Ebene: Rückfall auf Arcade mit dem Grund (%s)" % why)
	await _free(sc)
	# a builder reports a reason
	_use([], true)
	_builder.set("pending_polls", 6)
	_builder.set("fail_after", [3, "shader"])
	sc = _launch({})
	why = await _fallback_of(sc)
	_need(p, why == "shader", "fail_reason() eines Builders (%s)" % why)
	await _free(sc)
	# a layer file that gives no node
	_use([], false)
	_probe.set("layer_scripts", {"weather": BUILDER})
	sc = _launch({})
	r = sc.get("renderer")
	_need(p, not bool(r.call("healthy")) and str(r.call("fail_reason")) == "script:layers/weather.gd", "Ebenen-Datei ohne Knoten: sofort nicht gesund (%s)" % str(r.call("fail_reason")))
	why = await _fallback_of(sc)
	_need(p, why == "script:layers/weather.gd", "… Rückfall mit dem Dateinamen (%s)" % why)
	await _free(sc)
	# a preparation that never ends
	_use(["post"], false)
	_layer.set("pending_frames", {"post": -1})
	_probe.set("modern_cfg", {"prepare_timeout_s": 0.3})
	sc = _launch({})
	var t0 := Time.get_ticks_msec()
	why = await _fallback_of(sc, 4000)
	var waited := float(Time.get_ticks_msec() - t0) / 1000.0
	_need(p, why == "timeout" and waited >= 0.25, "Zeitlimit der Vorbereitung (%s nach %.2f s)" % [why, waited])
	await _free(sc)
	# … but not in sync mode (Rule 10: nothing reads the wall clock)
	_use(["post"], false)
	_layer.set("pending_frames", {"post": -1})
	_probe.set("modern_cfg", {"prepare_timeout_s": 0.2})
	CliArgs.all()["gfx-sync"] = true
	sc = _launch({})
	CliArgs.all().erase("gfx-sync")
	r = sc.get("renderer")
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 600:
		await process_frame
	_need(p, bool(r.call("healthy")) and not bool(r.call("is_prepared")) and bool(r.get("sync")), "im Sync-Modus kein Zeitlimit")
	await _free(sc)
	_report("ausfall", p, "Gründe manifest (Ebene), shader (Builder), script:layers/weather.gd, timeout nach %.2f s – jedes Mal Rückfall auf Arcade" % waited)


# --- umgebung: rig or built-in environment ------------------------------------------------------------------------

func _check_umgebung() -> void:
	var p: Array[String] = []
	# a rig (the fixture layer stands in for scripts/race3d/environment_rig.gd)
	_use(["weather"], true)
	_probe.set("rig_script", LAYER)
	var sc := _launch({})
	var r: ModernRenderer = sc.get("renderer")
	_need(p, r.env != null and str(r.env.name) == "Environment" and r.env.get_parent() == r, "env = der Knoten des Rigs")
	_need(p, _log().slice(0, 3) == (["Environment.setup", "facade_probe.setup", "weather.setup"] as Array[String]), "das Rig ist in jeder Phase das erste (%s)" % " ".join(_log().slice(0, 3)))
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 400)
	var at_update: Dictionary = _layer.get("at_update")
	var e: Dictionary = at_update.get("Environment", {})
	var w: Dictionary = at_update.get("weather", {})
	_need(p, bool(e.get("path_ready", false)) and int(e.get("chunks", 0)) >= 4, "erstes update() des Rigs: Pfad integriert, Startansicht geladen")
	_need(p, not bool(e.get("camera_placed", true)) and bool(w.get("camera_placed", false)), "Umgebung vor der Kamera, Ebenen danach")
	await _frames(6)
	var ups: Dictionary = _layer.get("updates")
	_need(p, int(ups.get("Environment", 0)) == int(ups.get("weather", -1)) and int(ups.get("Environment", 0)) > 3, "update() des Rigs jedes Bild (%d / %d)" % [
		int(ups.get("Environment", 0)), int(ups.get("weather", -1))])
	var suns: Array = []
	_nodes_of(r, "DirectionalLight3D", suns)
	var envs: Array = []
	_nodes_of(r, "WorldEnvironment", envs)
	_need(p, suns.is_empty() and envs.is_empty(), "mit Rig keine eingebaute Umgebung daneben (%d Lichter, %d Umgebungen)" % [suns.size(), envs.size()])
	var snap := r.debug_snapshot()
	_need(p, not snap.has("environment") and bool((snap.get("backdrop", {}) as Dictionary).get("plain", false)), "eingebauter Himmel bleibt, solange layers/backdrop.gd fehlt")
	await _free(sc)
	# no rig: the built-in plain environment and sky
	_use([], false)
	sc = _launch({})
	r = sc.get("renderer")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 400)
	await _frames(2)
	suns.clear()
	envs.clear()
	_nodes_of(r, "DirectionalLight3D", suns)
	_nodes_of(r, "WorldEnvironment", envs)
	_need(p, r.env == null, "ohne Rig bleibt env null")
	_need(p, suns.size() == 1 and (suns[0] as DirectionalLight3D).shadow_enabled and (suns[0] as DirectionalLight3D).visible, "genau EIN DirectionalLight3D mit shadow_enabled (%d)" % suns.size())
	_need(p, envs.size() == 1, "eine WorldEnvironment")
	if envs.size() == 1 and suns.size() == 1:
		var en: Environment = (envs[0] as WorldEnvironment).environment
		var sun: DirectionalLight3D = suns[0]
		_need(p, en.background_mode == Environment.BG_CANVAS and en.background_canvas_max_layer == -10, "BG_CANVAS hinter Ebene −10")
		_need(p, en.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and en.tonemap_mode == Environment.TONE_MAPPER_LINEAR and en.adjustment_enabled, "Umgebungslicht als Farbe, linearer Tonemapper, Nachbearbeitung fest an")
		var vis := float(r.view.get("visibility_m", 900.0))
		_need(p, en.fog_enabled and en.fog_mode == Environment.FOG_MODE_DEPTH and is_equal_approx(en.fog_depth_begin, 0.45 * vis) and is_equal_approx(en.fog_depth_end, vis), "Tiefennebel 0,45 … 1,0 × Sichtweite")
		var pal: Dictionary = r.view["palette"]
		_need(p, en.fog_light_color.is_equal_approx(pal["fog"]), "Nebelfarbe der Palette")
		_need(p, sun.light_energy > 0.15 and en.ambient_light_energy > 0.05, "Sonne und Umgebungslicht bei Tag an (%.2f / %.2f)" % [sun.light_energy, en.ambient_light_energy])
		var to_sun := sun.global_transform.basis.z
		_need(p, to_sun.y > 0.8 and to_sun.y < 0.9, "Sonnenstand am Mittag rund 60° (%.3f)" % to_sun.y)
		_need(p, sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS or r.levels.get("shadow_splits", 2) != 2, "Schattenstufen aus den Qualitätsstufen")
	var skies: Array = []
	_nodes_of(r, "CanvasLayer", skies)
	_need(p, skies.size() == 1 and (skies[0] as CanvasLayer).layer == -10, "Himmel auf Canvas-Ebene −10")
	snap = r.debug_snapshot()
	_need(p, bool((snap.get("environment", {}) as Dictionary).get("plain", false)) and bool((snap.get("backdrop", {}) as Dictionary).get("plain", false)), "beides im Schnappschuss")
	# the debug road is unshaded: its update() hook tints it with the ambient colour of the palette (Arcade's law)
	var noon: Color = (r.view["palette"] as Dictionary)["ambient"]
	var road_mat: Variant = r.builder("debug_road").get("_material")
	_need(p, road_mat is StandardMaterial3D and (road_mat as StandardMaterial3D).albedo_color.is_equal_approx(Color(noon.r, noon.g, noon.b)) and noon.get_luminance() > 0.9,
		"die Debug-Straße trägt das Umgebungslicht der Palette (Mittag: %s)" % noon.to_html(false))
	# night: the light stays, its energy is 0; a tunnel as well
	await _free(sc)
	sc = _launch({"start_world_minutes": 23.0 * 60.0})
	r = sc.get("renderer")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 400)
	suns.clear()
	_nodes_of(r, "DirectionalLight3D", suns)
	_need(p, suns.size() == 1 and (suns[0] as DirectionalLight3D).shadow_enabled and (suns[0] as DirectionalLight3D).visible
		and (suns[0] as DirectionalLight3D).light_energy == 0.0, "Nacht: das Licht bleibt (shadow_enabled), Energie 0")
	var night: Color = (r.view["palette"] as Dictionary)["ambient"]
	road_mat = r.builder("debug_road").get("_material")
	_need(p, road_mat is StandardMaterial3D and (road_mat as StandardMaterial3D).albedo_color.is_equal_approx(Color(night.r, night.g, night.b)) and night.get_luminance() < 0.4,
		"Nacht: die Debug-Straße ist so dunkel wie das Umgebungslicht der Palette (%s)" % night.to_html(false))
	await _free(sc)
	_report("umgebung", p, "Rig: env gesetzt, zuerst in jeder Phase, vor der Kamera aktualisiert; ohne Rig: eingebaute Umgebung mit einem Schattenlicht und Himmel auf Ebene −10")


# --- geruest: the shipped renderer on its own ----------------------------------------------------------------------

func _check_geruest() -> void:
	var p: Array[String] = []
	var orphans0 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_reset()
	_renderers.set("modern_script", _renderers.get("MODERN_SCRIPT"))
	var sc := _launch({})
	var r: ModernRenderer = sc.get("renderer")
	_need(p, _renderer_file(sc) == "modern_renderer.gd", "der ausgelieferte Renderer")
	# the skeleton alone has nothing to load; content of the renderer packages may take frames (models, sign textures)
	var content := not BuilderRegistry.existing_builders().is_empty() or not BuilderRegistry.existing_layers().is_empty() \
		or ResourceLoader.exists("res://scripts/race3d/environment_rig.gd")
	var frames: int = await _until(func() -> bool: return r.is_prepared(), 2000)
	_need(p, r.is_prepared() and r.healthy() and (content or frames <= 2), "headless vorbereitet, das Gerüst allein in höchstens zwei Bildern (%d)" % frames)
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 100)
	var snap := r.debug_snapshot()
	var chunks: Array = snap.get("chunks", [])
	var builders: Array = snap.get("builders", [])
	var want_road := "road" if builders.has("road") else "debug_road"
	_need(p, builders.has(want_road), "die Straße (oder ihre Debug-Vertretung) ist registriert (%s)" % str(builders))
	_need(p, chunks.size() >= 8 and int(snap.get("pending_chunks", 1)) == 0, "die Stücke der Startansicht hängen (%d)" % chunks.size())
	if want_road == "debug_road" and not chunks.is_empty() and not builders.has("terrain"):
		var part: Dictionary = ((chunks[0] as Dictionary).get("parts", {}) as Dictionary).get("debug_road", {})
		_need(p, int(part.get("vertices", 0)) == 32 * (5 + 12) * 4, "Debug-Straße mit Geländeringen (%d Eckpunkte)" % int(part.get("vertices", 0)))
	var listed: Array = snap.get("layers", [])
	for id: String in LAYER_IDS:
		_need(p, (r.layer(id) != null) == listed.has(id) and listed.has(id) == ResourceLoader.exists("res://scripts/race3d/layers/%s.gd" % id), "Ebene %s genau dann, wenn ihre Datei da ist" % id)
	await _until(func() -> bool: return float(sc.get("stage_time")) > 3.0, 600)
	var perf := r.perf_stats()
	_need(p, int(perf.get("frames", 0)) > 5 and float(perf.get("render_ms_avg", 99.0)) < 20.0, "render() läuft (Ø %.3f ms)" % float(perf.get("render_ms_avg", 0.0)))
	var core_ms := float(perf.get("render_ms_avg", 0.0))
	await _free(sc)
	await _frames(2)
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_need(p, orphans <= orphans0 and nodes <= nodes0, "nach der Etappe ist jeder Knoten frei (verwaist %d → %d, Knoten %d → %d)" % [orphans0, orphans, nodes0, nodes])
	# a terrain builder: the debug road draws no rings
	_use([], true)
	_builder.set("builder_id", "terrain")
	sc = _launch({})
	r = sc.get("renderer")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 100)
	chunks = r.debug_snapshot().get("chunks", [])
	if r.builder("debug_road") != null and not chunks.is_empty():
		var part2: Dictionary = ((chunks[0] as Dictionary).get("parts", {}) as Dictionary).get("debug_road", {})
		_need(p, int(part2.get("vertices", 0)) == 32 * 5 * 4, "mit einem Gelände-Builder zeichnet die Debug-Straße keine Ringe (%d Eckpunkte)" % int(part2.get("vertices", 0)))
	await _free(sc)
	# sync mode: every render() leaves everything built and committed
	_reset()
	_renderers.set("modern_script", _renderers.get("MODERN_SCRIPT"))
	CliArgs.all()["gfx-sync"] = true
	sc = _launch({"start_speed_kmh": 200.0})
	CliArgs.all().erase("gfx-sync")
	r = sc.get("renderer")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 100)
	var worst_pending := 0
	var seen_chunks := {}
	var at_once := r.streamer.chunk_count()
	var z0 := float(sc.get("pos_z"))
	var n := 0
	while float(sc.get("pos_z")) < z0 + 500.0 and n < 6000:
		await process_frame
		n += 1
		worst_pending = maxi(worst_pending, r.streamer.pending_count())
		for c: Dictionary in r.streamer.snapshot()["chunks"]:
			seen_chunks[int(c["index"])] = true
	_need(p, r.sync and r.streamer.sync and worst_pending == 0 and seen_chunks.size() >= at_once + 4,
		"Sync-Modus: nach jedem render() ist nichts offen (%d Stücke über 500 m, %d zugleich)" % [seen_chunks.size(), at_once])
	await _free(sc)
	_report("geruest", p, "ausgelieferter Renderer: in %d Bildern vorbereitet, %d Stücke, Builder %s, render() Ø %.3f ms headless; Sync-Modus ohne offene Stücke; Knoten nach der Etappe frei" % [
		frames, chunks.size(), str(builders), core_ms])
