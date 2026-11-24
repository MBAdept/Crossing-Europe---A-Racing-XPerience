extends SceneTree
## Render check of the glints of the retro-reflectors (mode "Modern", layer "lights", assets/shaders/modern/reflector.gdshader;
## RINT-M3, lead note 8 after FIX-R7b's hint). It needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_reflector_glint.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   reflektor_punkt  one glint (the layer's own MultiMesh law: a quad of GLINT_RADIUS_M, white, full strength) at 30,
##                    150 and 400 m straight ahead of a camera with the game's focal length, on black: far away it must
##                    keep its minimum size of min_px pixels (a 720-row picture; Arcade's _glow_fixture draws 2 to 2.5 px)
##                    – lit across at least MIN_LIT_PX columns at 400 m – and near it must not grow beyond its own radius
##                    (at 30 m at most 2 × the radius in pixels + 2). In the Compatibility renderer the projection's y
##                    scale is NEGATIVE in the vertex stage (the scene is drawn upside down into its buffer) and
##                    VIEWPORT_SIZE reads 0 there (FIX-R7b, the same bug in the landmark glow): with the signed value the
##                    minimum never applied and a reflector at 400 m was a sub-pixel speck.
## "-- --save=<absolute folder>" keeps the pictures. (Scripts started with -s compile before the autoloads exist.)

const Lights := preload("res://scripts/race3d/layers/lights.gd")
const DISTS: Array[float] = [30.0, 150.0, 400.0]
const MIN_LIT_PX := 2                ## lit columns of a far glint: min_px 2.4 px radius lights about 2.7 px across above LIT (halo² × 0.55)
const LIT := 0.08                    ## a pixel counts as lit above this luminance (0..1) on the black background
const FOV_DEG := 53.7                ## the game's vertical field of view: 2 atan(360 / 711), RoadProjection.focal 711 px at 720 rows

var _failed: Array[String] = []
var _cam: Camera3D
var _mm: MultiMesh
var _mat: ShaderMaterial
var _save := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save="):
			_save = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK reflektor_punkt FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_scene()
	for i in 4:
		await process_frame
	var p: Array[String] = []
	var widths: Array[int] = []
	var vh := float(root.get_visible_rect().size.y)
	var px_per_m_1 := 0.5 * vh / tan(deg_to_rad(FOV_DEG * 0.5))
	for d: float in DISTS:
		_mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * Lights.GLINT_RADIUS_M), Vector3(0.0, 0.0, -d)))
		_mm.set_instance_color(0, Color(1.0, 1.0, 1.0, 1.0))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if _save != "":
			DirAccess.make_dir_recursive_absolute(_save)
			img.save_png("%s/reflektor_%d.png" % [_save, int(d)])
		var w := _lit_columns(img)
		widths.append(w)
		var own_px := Lights.GLINT_RADIUS_M * px_per_m_1 / d
		if d >= 300.0 and w < MIN_LIT_PX:
			p.append("bei %.0f m nur %d Spalten hell (mindestens %d; eigener Radius %.2f px)" % [d, w, MIN_LIT_PX, own_px])
		if d <= 40.0 and float(w) > 2.0 * own_px + 2.0:
			p.append("bei %.0f m %d Spalten (höchstens %.0f: 2 × eigener Radius + 2)" % [d, w, 2.0 * own_px + 2.0])
	var ok := p.is_empty()
	var mp: Variant = _mat.get_shader_parameter("min_px")
	var min_px := float(mp) if mp != null else 2.4      # (the shader's default when the layer sets none)
	print("RENDER-CHECK %-18s %s  helle Spalten bei %s m: %s (Arcade _glow_fixture: 2–2,5 px Radius; min_px %.1f)%s" % [
		"reflektor_punkt", "OK    " if ok else "FEHLER", str(DISTS), str(widths), min_px,
		"" if ok else "  –  FEHLT: " + "; ".join(p)])
	if not ok:
		_failed.append("reflektor_punkt")
	print("RENDER-CHECKS %s  (%d fehlgeschlagen)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size()])
	ModernMaterials.drop_shared()
	quit(0 if _failed.is_empty() else 1)


## Columns of the picture with at least one lit pixel.
static func _lit_columns(img: Image) -> int:
	var n := 0
	for x in img.get_width():
		for y in img.get_height():
			if img.get_pixel(x, y).get_luminance() > LIT:
				n += 1
				break
	return n


func _scene() -> void:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	ModernMaterials.ensure_globals()
	_cam = Camera3D.new()
	_cam.near = 0.5
	_cam.far = 2000.0
	_cam.fov = FOV_DEG
	world.add_child(_cam)
	_cam.current = true
	# the layer's own glint node: the lights layer builds it (one MultiMesh, the reflector material, viewport_h)
	var layer: Node3D = Lights.new()
	world.add_child(layer)
	layer.call("setup", null)
	layer.call("_build_lights")
	var glints: MultiMeshInstance3D = layer.get("_glints")
	_mm = glints.multimesh
	_mat = glints.material_override as ShaderMaterial
	_mm.visible_instance_count = 1
	glints.visible = true
	if layer.has_method(&"sync_viewport"):
		layer.call("sync_viewport")
