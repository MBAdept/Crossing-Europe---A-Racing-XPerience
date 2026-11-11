extends SceneTree
## Render checks of the Modern renderer skeleton (v0.8.0, contract amendment A-7; German docs:
## docs/renderer-modern.md "Aufbau: Fassade, Ebenen, Haken") – they need a real renderer and a fixed frame rate:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_facade_render.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## Every check runs the skeleton alone (the probe renderer in its bare mode: no layer, builder or rig file of the
## renderer packages), so the checks mean the same once those packages have added their files.
##   licht       the built-in plain environment lights geometry that is put under renderer.world: a level plate
##               of the reference albedo shows Arcade's colour (albedo × palette.ambient) in the light and only
##               the ambient part in the shadow of a box – exactly ONE DirectionalLight3D, with shadows (D5)
##   nacht       at 23:00 the debug road (unshaded, tinted with the ambient colour of the palette by its update()
##               hook) and a lit plate are as dark as Arcade's road and ground, the one light stays with energy 0
##   pools       assets/shaders/modern/inc/pools.gdshaderinc: a test shader that includes it compiles and lights a
##               plate where a pool is set – full light at the centre, the law (1 − d²/r²)² at half the radius,
##               nothing beyond the radius, pools add up, entries with radius <= 0 or beyond pool_count are
##               skipped; on a lit surface ce_pools_emission() adds the pool to the ambient light. The uniforms
##               are set the way the layer "lights" will: on every material of renderer.pool_materials()
##   aufwaermen  warmup_nodes(): the nodes stand in front of the camera for two drawn frames behind the session's
##               loading cover (hidden by it; seen with the cover taken away), then they are freed; update() gets
##               dt = 0 until is_prepared(); the render self-test runs once per process
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/facade_probe_renderer.gd"
const LAYER := "res://tests/race3d/fixtures/facade_layer.gd"
const POOLS_INC := "res://assets/shaders/modern/inc/pools.gdshaderinc"
const CHECKS := ["licht", "nacht", "pools", "aufwaermen"]
const PlainEnvironment := preload("res://scripts/race3d/plain_environment.gd")
const PLATE_H := 0.3            ## test plates float this far above the road (m)
const LOADING_LAYER := 6        ## canvas layer of the session's loading cover (contract §4.4.4)

var _failed: Array[String] = []
var _probe: GDScript
var _layer: GDScript
var _renderers: GDScript
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK facade_render FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_probe = load(PROBE)
	_layer = load(LAYER)
	_renderers = load("res://scripts/race/race_renderers.gd")
	var only := str(CliArgs.all().get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_use_skeleton(false)
	ModernMaterials.drop_shared()   # what leaving the mode "Modern" does: nothing of it is left at the exit
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-14s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


## The skeleton alone (see the header), or the shipped renderer again.
func _use_skeleton(on: bool) -> void:
	_probe.call("reset")
	_layer.call("reset")
	_probe.set("bare", on)
	_renderers.set("modern_script", PROBE if on else str(_renderers.get("MODERN_SCRIPT")))


## A Modern stage at Kiel – Hamburg km 2 by day whose car stands still (no autopilot, no input): the camera does
## not move, test geometry under renderer.world stays where it is in the picture.
func _launch(extra: Dictionary = {}) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false   # the judged pixels are never under the start lights or a message
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, max_frames: int = 2000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


## The picture of the window after the next drawn frame.
func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## "-- --save=<absolute folder>" keeps the judged pictures as <folder>/facade_<name>.png (for a look, not for a test).
func _keep(img: Image, pic_name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir.path_join("facade_%s.png" % pic_name))


## Colour of the picture where the camera shows the world point `at` (mean of 3 × 3 pixels).
func _pixel(img: Image, r: ModernRenderer, at: Vector3) -> Color:
	var px := r.camera.unproject_position(at)
	var x := clampi(int(px.x), 1, img.get_width() - 2)
	var y := clampi(int(px.y), 1, img.get_height() - 2)
	var sum := Color(0.0, 0.0, 0.0)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := img.get_pixel(x + dx, y + dy)
			sum.r += c.r
			sum.g += c.g
			sum.b += c.b
	return Color(sum.r / 9.0, sum.g / 9.0, sum.b / 9.0)


## What the renderer shows for a linear value (per channel).
func _show(lin: Color) -> Color:
	return Color(PlainEnvironment.engine_show(lin.r), PlainEnvironment.engine_show(lin.g), PlainEnvironment.engine_show(lin.b))


func _times(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f)


func _plus(a: Color, b: Color) -> Color:
	return Color(a.r + b.r, a.g + b.g, a.b + b.b)


## Largest difference of a channel, in steps of 1/255.
func _steps(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0


func _rgb(c: Color) -> String:
	return "%d/%d/%d" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]


func _nodes_of(n: Node, cls: String, out: Array) -> void:
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		_nodes_of(c, cls, out)


## A level plate under renderer.world, `ahead` metres in front of the camera and `side` metres beside its axis.
func _plate(r: ModernRenderer, ahead: float, side: float, size: Vector2, mat: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.world.add_child(mi)
	# a rigid frame on the road (yaw only), so that "side" is across the road and the plate lies level
	mi.global_transform = r.path.frame_at(float(r.view["camera_z"]) + ahead, float(r.view["camera_x"]) + side, PLATE_H)
	return mi


# --- licht: the built-in environment lights geometry ------------------------------------------------------------

func _check_licht() -> void:
	var p: Array[String] = []
	_use_skeleton(true)
	var sc: Node = await _launch()
	var r: ModernRenderer = sc.get("renderer")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 5, 2000)
	var env_node: Node = r.get("_environment")
	_need(p, r.env == null and env_node != null and env_node.get_script() == PlainEnvironment, "die eingebaute Umgebung (kein Rig)")
	var suns: Array = []
	_nodes_of(r, "DirectionalLight3D", suns)
	_need(p, suns.size() == 1 and (suns[0] as DirectionalLight3D).shadow_enabled, "genau EIN DirectionalLight3D mit shadow_enabled (%d)" % suns.size())
	var omnis: Array = []
	_nodes_of(r, "OmniLight3D", omnis)
	_nodes_of(r, "SpotLight3D", omnis)
	_need(p, omnis.is_empty(), "keine weiteren Lichter im Gerüst")
	var st: Dictionary = env_node.get("state")
	var to_sun: Vector3 = st["to_sun"]
	var pal: Dictionary = r.view["palette"]
	var amb: Color = pal["ambient"]
	var a := PlainEnvironment.REF_ALBEDO
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(a, a, a)
	grey.roughness = 1.0
	grey.metallic_specular = 0.0
	var plate := _plate(r, 22.0, 0.0, Vector2(9.0, 7.0), grey)
	# a box above the plate, placed so that its shadow falls on the middle of the plate
	var box := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(1.8, 1.8, 1.8)
	box.mesh = cube
	box.material_override = grey
	r.world.add_child(box)
	var centre := plate.global_transform.origin
	box.global_transform = Transform3D(plate.global_transform.basis, centre + to_sun * (2.6 / to_sun.y))
	await _frames(3)
	var img: Image = await _capture()
	_keep(img, "licht")
	var right := plate.global_transform.basis.x
	var lit := _pixel(img, r, centre + right * 3.0)
	var lit_2 := _pixel(img, r, centre - right * 3.0)
	var shade := _pixel(img, r, centre)
	var want_lit := Color(a * amb.r, a * amb.g, a * amb.b)
	var rest: Color = st["ambient_display"]
	var want_shade := Color(a * rest.r, a * rest.g, a * rest.b)
	_need(p, _steps(lit, want_lit) <= 5.0 and _steps(lit_2, want_lit) <= 5.0, "ebene Fläche im Licht = Albedo × palette.ambient wie in Arcade (%s und %s statt %s)" % [_rgb(lit), _rgb(lit_2), _rgb(want_lit)])
	_need(p, _steps(shade, want_shade) <= 5.0, "im Schatten nur der Umgebungsanteil (%s statt %s)" % [_rgb(shade), _rgb(want_shade)])
	_need(p, lit.get_luminance() - shade.get_luminance() > 0.08, "der Schatten ist deutlich dunkler (%.3f gegen %.3f)" % [shade.get_luminance(), lit.get_luminance()])
	_need(p, float(st["share"]) > 0.4 and to_sun.y > 0.8, "Mittag: die Hälfte des Lichts gerichtet, Sonne hoch (%.2f, %.2f)" % [float(st["share"]), to_sun.y])
	# without the box the shadow is gone: it was the box's
	box.queue_free()
	await _frames(3)
	var free_img: Image = await _capture()
	var no_shade := _pixel(free_img, r, centre)
	_need(p, _steps(no_shade, want_lit) <= 5.0, "ohne den Kasten kein Schatten (%s)" % _rgb(no_shade))
	_report("licht", p, "eingebaute Umgebung: Platte (Albedo %.2f) im Licht %s (Arcade: %s), im Schatten des Kastens %s (Umgebungsanteil: %s), ein DirectionalLight3D mit Schatten" % [
		a, _rgb(lit), _rgb(want_lit), _rgb(shade), _rgb(want_shade)])
	await _free(sc)


# --- nacht: the stand-in road and lit geometry at night -----------------------------------------------------------

func _check_nacht() -> void:
	var p: Array[String] = []
	_use_skeleton(true)
	var sc: Node = await _launch({"start_world_minutes": 23.0 * 60.0})
	var r: ModernRenderer = sc.get("renderer")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 5, 2000)
	var pal: Dictionary = r.view["palette"]
	var amb: Color = pal["ambient"]
	_need(p, float(pal.get("night", 0.0)) > 0.9 and amb.get_luminance() < 0.4, "Nacht (Umgebungslicht der Palette %s)" % _rgb(amb))
	var a := PlainEnvironment.REF_ALBEDO
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(a, a, a)
	grey.roughness = 1.0
	grey.metallic_specular = 0.0
	var plate := _plate(r, 20.0, 11.0, Vector2(6.0, 6.0), grey)   # beside the road
	await _frames(3)
	var img: Image = await _capture()
	_keep(img, "nacht")
	# the debug road is unshaded and tinted by its update() hook: Arcade's colour of the asphalt (one of its two
	# greys) – a little darker in the picture, the renderer cuts dark values off (docs/modelle.md §4)
	var cam_z := float(r.view["camera_z"])
	var road := _pixel(img, r, r.road_to_world(cam_z + 14.0, 0.0, 0.02))
	var want_a := Color(0.30 * amb.r, 0.31 * amb.g, 0.34 * amb.b)
	var want_b := Color(0.33 * amb.r, 0.34 * amb.g, 0.37 * amb.b)
	var want_road := want_a if _steps(road, want_a) <= _steps(road, want_b) else want_b
	_need(p, _steps(road, want_road) <= 14.0 and road.get_luminance() < 0.15 and road.b > 0.03,
		"die Debug-Straße ist nachts so dunkel wie in Arcade (%s, Arcade %s)" % [_rgb(road), _rgb(want_road)])
	var grass := _pixel(img, r, r.road_to_world(cam_z + 30.0, -30.0, 0.0) + Vector3(0.0, -0.3, 0.0))
	_need(p, grass.get_luminance() < 0.2 and grass.g >= grass.r, "das Gelände der Debug-Straße auch (%s)" % _rgb(grass))
	# lit geometry: no directed light at night, the plate shows the ambient light alone
	var lit := _pixel(img, r, plate.global_transform.origin)
	var want_lit := Color(a * amb.r, a * amb.g, a * amb.b)
	_need(p, _steps(lit, want_lit) <= 12.0 and lit.get_luminance() > 0.03, "ebene Fläche nachts = Albedo × palette.ambient (%s, Arcade %s)" % [_rgb(lit), _rgb(want_lit)])
	var suns: Array = []
	_nodes_of(r, "DirectionalLight3D", suns)
	_need(p, suns.size() == 1 and (suns[0] as DirectionalLight3D).shadow_enabled and (suns[0] as DirectionalLight3D).light_energy == 0.0,
		"das eine Schattenlicht bleibt, Energie 0")
	_report("nacht", p, "23 Uhr: Debug-Straße %s (Arcade %s), Gelände %s, beleuchtete Platte %s (Arcade %s)" % [
		_rgb(road), _rgb(want_road), _rgb(grass), _rgb(lit), _rgb(want_lit)])
	await _free(sc)


# --- pools: the light pool include --------------------------------------------------------------------------------

func _pool_shader(body: String, mode: String) -> Shader:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode %s;\n#include \"%s\"\nvarying vec3 v_world;\nvoid vertex() { v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() { %s }\n" % [mode, POOLS_INC, body]
	return sh


func _check_pools() -> void:
	var p: Array[String] = []
	_use_skeleton(true)
	var sc: Node = await _launch()
	var r: ModernRenderer = sc.get("renderer")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 5, 2000)
	var a := PlainEnvironment.REF_ALBEDO
	# plate 1, unlit and white: it shows the light of the pools alone
	var law := ShaderMaterial.new()
	law.shader = _pool_shader("ALBEDO = ce_pools_emission(vec3(1.0), v_world);", "unshaded, cull_disabled")
	# plate 2, lit like a road: the pools come on top of the ambient light
	var lit := ShaderMaterial.new()
	lit.shader = _pool_shader("ALBEDO = vec3(%.2f); ROUGHNESS = 1.0; SPECULAR = 0.0; EMISSION = ce_pools_emission(ALBEDO, v_world);" % a, "cull_disabled")
	var plate_1 := _plate(r, 20.0, -7.0, Vector2(12.0, 9.0), law)
	var plate_2 := _plate(r, 20.0, 5.5, Vector2(9.0, 9.0), lit)
	r.add_pool_material(law)
	r.add_pool_material(lit)
	_need(p, r.pool_materials().size() == 2, "zwei Materialien angemeldet (%d)" % r.pool_materials().size())
	var c1 := plate_1.global_transform.origin
	var c2 := plate_2.global_transform.origin
	var right := plate_1.global_transform.basis.x
	var light_a := Color(0.8, 0.5, 0.2)
	var light_b := Color(0.1, 0.3, 0.6)
	var light_c := Color(0.3, 0.1, 0.05)
	var light_p := Color(0.5, 0.4, 0.3)
	# on plate 1 (12 m wide): A from -6 to 0 m, a gap, B and C from 1 to 6 m (a pixel is 3 cm across but 18 cm along
	# the road at this distance – the pools are large against that)
	var centre_a := c1 - right * 3.0
	var gap := c1 + right * 0.5
	var centre_bc := c1 + right * 3.5
	# entries: A · one with radius -1 in the gap (skipped) · B and C at the same place (they add up) · P on the lit
	# plate · and beyond pool_count a huge bright one that must not count
	var pos := PackedVector4Array([_v4(centre_a, 3.0), _v4(gap, -1.0), _v4(centre_bc, 2.5), _v4(centre_bc, 2.5), _v4(c2, 3.0), _v4(c1, 60.0)])
	var col := PackedVector4Array([_c4(light_a, 0.0), Vector4(5.0, 5.0, 5.0, 0.0), _c4(light_b, 0.0), _c4(light_c, 1.0), _c4(light_p, 0.0),
		Vector4(5.0, 5.0, 5.0, 0.0)])
	pos.resize(22)
	col.resize(22)
	# what the layer "lights" does once per frame: the three uniforms on every registered material
	for m: ShaderMaterial in r.pool_materials():
		m.set_shader_parameter("pool_pos_r", pos)
		m.set_shader_parameter("pool_col", col)
		m.set_shader_parameter("pool_count", 5)
	await _frames(3)
	var img: Image = await _capture()
	_keep(img, "pools")
	var at_a := _pixel(img, r, centre_a)
	var at_half := _pixel(img, r, centre_a + right * 1.5)   # half the radius of A
	var at_gap := _pixel(img, r, gap)
	var at_bc := _pixel(img, r, centre_bc)
	_need(p, _steps(at_a, _show(light_a)) <= 4.0, "volle Helligkeit in der Mitte (%s statt %s)" % [_rgb(at_a), _rgb(_show(light_a))])
	_need(p, _steps(at_half, _show(_times(light_a, 0.5625))) <= 7.0, "beim halben Radius (1 − ¼)² = 56 %% des Lichts (%s statt %s)" % [_rgb(at_half), _rgb(_show(_times(light_a, 0.5625)))])
	_need(p, at_gap.get_luminance() < 0.02, "jenseits des Radius nichts; Radius <= 0 und Einträge hinter pool_count zählen nicht (%s)" % _rgb(at_gap))
	_need(p, _steps(at_bc, _show(_plus(light_b, light_c))) <= 4.0, "zwei Kegel addieren sich (%s statt %s)" % [_rgb(at_bc), _rgb(_show(_plus(light_b, light_c)))])
	# the lit plate: outside the pool Arcade's colour, inside the pool on top of the ambient light
	var env_node: Node = r.get("_environment")
	var st: Dictionary = env_node.get("state")
	var amb_lin: Color = st["ambient"]
	var a_lin := PlainEnvironment.engine_to_linear(a)
	var outside := _pixel(img, r, c2 + right * 3.8)
	var inside := _pixel(img, r, c2)
	var pal: Dictionary = r.view["palette"]
	var amb: Color = pal["ambient"]
	var want_out := Color(a * amb.r, a * amb.g, a * amb.b)
	var gain := Color(inside.r - outside.r, inside.g - outside.g, inside.b - outside.b)
	var with_pool := _show(_times(_plus(amb_lin, light_p), a_lin))
	var without := _show(_times(amb_lin, a_lin))
	var want_gain := Color(with_pool.r - without.r, with_pool.g - without.g, with_pool.b - without.b)
	_need(p, _steps(outside, want_out) <= 5.0, "beleuchtete Platte außerhalb des Kegels = Albedo × palette.ambient (%s statt %s)" % [_rgb(outside), _rgb(want_out)])
	_need(p, _steps(gain, want_gain) <= 5.0 and gain.r > 0.08, "im Kegel kommt sein Licht zum Umgebungslicht dazu (+%s statt +%s)" % [_rgb(gain), _rgb(want_gain)])
	# pool_count 0: no pool at all
	for m: ShaderMaterial in r.pool_materials():
		m.set_shader_parameter("pool_count", 0)
	await _frames(2)
	var off: Image = await _capture()
	var dark := _pixel(off, r, centre_a)
	var plain := _pixel(off, r, c2)
	_need(p, dark.get_luminance() < 0.02 and _steps(plain, want_out) <= 5.0, "pool_count 0: kein Kegel (%s, %s)" % [_rgb(dark), _rgb(plain)])
	_report("pools", p, "Prüf-Shader mit pools.gdshaderinc: Mitte %s (erwartet %s), halber Radius %s (%s), daneben %s, zwei Kegel %s (%s); beleuchtete Platte außerhalb %s, im Kegel +%s (erwartet +%s)" % [
		_rgb(at_a), _rgb(_show(light_a)), _rgb(at_half), _rgb(_show(_times(light_a, 0.5625))), _rgb(at_gap), _rgb(at_bc),
		_rgb(_show(_plus(light_b, light_c))), _rgb(outside), _rgb(gain), _rgb(want_gain)])
	await _free(sc)


func _v4(pos: Vector3, radius: float) -> Vector4:
	return Vector4(pos.x, pos.y, pos.z, radius)


func _c4(c: Color, kind: float) -> Vector4:
	return Vector4(c.r, c.g, c.b, kind)


# --- aufwaermen: warm-up nodes behind the loading cover -----------------------------------------------------------

## Number of magenta samples of the picture (every 4th pixel in both directions): the warm-up boxes of the fixture.
func _magenta(img: Image) -> int:
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			if c.r > 0.9 and c.g < 0.1 and c.b > 0.9:
				n += 1
	return n


## Starts a stage with two fixture layers that hand out a magenta box each and captures every frame until the
## renderer is prepared. Returns what was seen.
func _watch_preparation(hide_cover: bool) -> Dictionary:
	_use_skeleton(true)
	_probe.set("layer_scripts", {"weather": LAYER, "post": LAYER})
	_layer.set("warm_meshes", true)
	var sc: Node = await _launch()
	var r: ModernRenderer = sc.get("renderer")
	var cover: CanvasLayer = sc.get("_loading")
	var out := {"scene": sc, "cover": cover != null and cover.layer == LOADING_LAYER, "frames": 0, "shown": 0, "most": 0, "warm_frames": 0,
		"steps": 0, "cover_px": Color.BLACK}
	if cover != null and hide_cover:
		cover.visible = false
	while not r.is_prepared() and int(out["frames"]) < 600:
		var img: Image = await _capture()
		out["frames"] = int(out["frames"]) + 1
		var n := _magenta(img)
		out["most"] = maxi(int(out["most"]), n)
		if n > 100:
			out["shown"] = int(out["shown"]) + 1
			_keep(img, "aufwaermen")
		if str(r.debug_snapshot().get("stage", "")) == "warmup":
			out["warm_frames"] = int(out["warm_frames"]) + 1
			out["cover_px"] = img.get_pixel(640, 450)
		out["steps"] = maxi(int(out["steps"]), int(sc.get("_sim_steps")))
	out["updates"] = (_layer.get("updates") as Dictionary).duplicate()
	out["dt_preparing"] = (_layer.get("dt_preparing") as Dictionary).duplicate()
	out["selftest"] = ModernRenderer.selftest.duplicate()
	return out


func _check_aufwaermen() -> void:
	var p: Array[String] = []
	# a) the loading cover taken away: the boxes are in the picture
	var seen: Dictionary = await _watch_preparation(true)
	var sc: Node = seen["scene"]
	var r: ModernRenderer = sc.get("renderer")
	_need(p, bool(seen["cover"]), "Ladebild der Sitzung auf Canvas-Ebene %d" % LOADING_LAYER)
	_need(p, int(seen["shown"]) >= ModernRenderer.WARMUP_FRAMES, "die Aufwärm-Knoten stehen mindestens %d gezeichnete Bilder vor der Kamera (%d, bis zu %d Proben)" % [
		ModernRenderer.WARMUP_FRAMES, int(seen["shown"]), int(seen["most"])])
	_need(p, int(seen["steps"]) == 0, "kein Simulationsschritt während der Vorbereitung")
	var ups: Dictionary = seen["updates"]
	var dts: Dictionary = seen["dt_preparing"]
	_need(p, int(ups.get("post", 0)) >= 1 + ModernRenderer.WARMUP_FRAMES and float(dts.get("post", 1.0)) == 0.0 and float(dts.get("weather", 1.0)) == 0.0,
		"update() läuft während des Aufwärmens mit dt = 0 (%d Aufrufe, dt %s)" % [int(ups.get("post", 0)), str(dts)])
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 3, 600)
	var after: Image = await _capture()
	var alive := 0
	for wid: int in _layer.get("warm_ids"):
		alive += 1 if is_instance_id_valid(wid) else 0
	_need(p, _magenta(after) == 0 and alive == 0 and (_layer.get("warm_ids") as Array).size() == 2, "nach dem Start sind sie fort und freigegeben (%d Proben, %d von %d leben)" % [
		_magenta(after), alive, (_layer.get("warm_ids") as Array).size()])
	var perf := r.perf_stats()
	_need(p, int(perf.get("warmup_nodes", 0)) == 2 and float(perf.get("prewarm_ms", 0.0)) > 0.0, "perf_stats: warmup_nodes 2, prewarm_ms %.1f" % float(perf.get("prewarm_ms", 0.0)))
	var st_a: Dictionary = seen["selftest"]
	_need(p, bool(st_a.get("ok", false)) and float(st_a.get("ms", 0.0)) > 0.0, "Selbsttest gelaufen (%s)" % str(st_a))
	await _free(sc)
	# b) as the player gets it: the cover hides the boxes
	var hidden: Dictionary = await _watch_preparation(false)
	sc = hidden["scene"]
	_need(p, int(hidden["warm_frames"]) >= ModernRenderer.WARMUP_FRAMES and int(hidden["most"]) == 0,
		"hinter dem Ladebild ist nichts davon zu sehen (%d Aufwärmbilder, %d Proben)" % [int(hidden["warm_frames"]), int(hidden["most"])])
	_need(p, (hidden["cover_px"] as Color).get_luminance() < 0.1, "das Ladebild deckt das Bild (%s)" % _rgb(hidden["cover_px"]))
	var st_b: Dictionary = hidden["selftest"]
	_need(p, st_b == st_a and int(hidden["frames"]) <= int(seen["frames"]), "der Selbsttest läuft einmal je Prozess (zweite Etappe: %d statt %d Bilder Vorbereitung)" % [
		int(hidden["frames"]), int(seen["frames"])])
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 3, 600)
	# c) --no-prewarm (graphics.modern.prewarm = false): no warm-up node is asked for
	await _free(sc)
	_use_skeleton(true)
	_probe.set("layer_scripts", {"post": LAYER})
	_probe.set("modern_cfg", {"prewarm": false})
	_layer.set("warm_meshes", true)
	sc = await _launch()
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 3, 600)
	_need(p, (_layer.get("warm_ids") as Array).is_empty() and int((sc.get("renderer") as ModernRenderer).perf_stats().get("warmup_nodes", -1)) == 0,
		"ohne Aufwärmen (prewarm = false) wird kein Knoten verlangt")
	await _free(sc)
	_report("aufwaermen", p, "Aufwärm-Knoten in %d gezeichneten Bildern vor der Kamera (ohne Ladebild sichtbar, %d Proben), mit Ladebild verdeckt; danach freigegeben; Vorbereitung %d Bilder beim ersten und %d beim zweiten Mal (Selbsttest %.0f ms, einmal je Prozess)" % [
		int(seen["shown"]), int(seen["most"]), int(seen["frames"]), int(hidden["frames"]), float(st_a.get("ms", 0.0))])
