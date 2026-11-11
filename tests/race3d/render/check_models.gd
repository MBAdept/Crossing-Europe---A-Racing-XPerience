extends SceneTree
## Render checks of the model materials of the mode "Modern" (v0.8.0; docs/modelle.md) – what no headless test can
## see: that the five material shaders and the billboard shader compile and draw, what every lamp channel and paint
## code of the vertex format "VPBR-L" shows, that the lamps of the reference vehicles reach the screen, and the
## MultiMesh paths of ModelFactory.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_models.gd -- --graphics=modern --gfx-sync [--only=a,b] [--keep=<dir>]
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   klassen     every material class draws: vpbr, glass, baked (+ night emission), leaves, the cut-out variant of
##               baked (alpha scissor: half of a checkerboard), the billboard (tree impostor) – a shader that does
##               not compile draws nothing
##   lampen      the strip of the 15 lamp channels in the dark: each channel answers to exactly its instance uniform
##               or global; braking shows at least 1.8 × the luminance of the tail light; an indicator is amber, a
##               beacon blue (an over-driven lamp keeps its hue); by day an unlit lamp is dark behind its lens and
##               the number plate (channel 8) and the flood-lit surface (14) keep their own colour
##   lackcodes   paint, paint2 and paint3 take the instance colours, the fixed code keeps the vertex colour
##   blinker     the reference vehicles from straight behind at night, every level of detail: switching an
##               indicator on lights at least 60 cm² on its side – amber on the traffic car – and nothing on the
##               other side; from ahead the same for the traffic car
##   bremslicht  traffic car at night: the lamp pixels with the brake on against the tail light alone, >= 1.8 ×
##   multimesh   ModelFactory.multimesh_parts in a real MultiMesh: instances drawn, a mirrored node (negative
##               determinant) draws the mirror image with correct culling, the lamp of the street light is lit at
##               night in both; the tree impostor as billboards in a MultiMesh, also under a mirrored node
## --keep=<dir>: saves the pictures the checks looked at.
## (Autoloads are not used; ModelDB, ModelFactory and ModernMaterials are static or plain classes.)

const CHECKS := ["klassen", "lampen", "lackcodes", "blinker", "bremslicht", "multimesh"]
## lit colours of the test strip, channel 0 … 14 (8 and 14 are lit surfaces: their own albedo)
const CHANNEL_COLORS: Array[String] = ["#ff1a0e", "#ff2414", "#ff2010", "#ffa01a", "#ffa01a", "#fff3d6", "#eef3ff",
	"#fff6e6", "#eeeeea", "#ffa21a", "#2a6bff", "#2a6bff", "#fff0cf", "#ffffff", "#c8c0b0"]
const PX_PER_M := 200.0             ## orthographic pictures of the vehicles: pixels per metre
const INDICATOR_MIN_CM2 := 60.0     ## as tools/blender/validate_models.py LAMP_MIN_CM2

var _failed: Array[String] = []
var _wall0 := 0
var _keep := ""
var _mats: ModernMaterials


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK models FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--keep="):
			_keep = a.substr(7)
	if _keep != "":
		DirAccess.make_dir_recursive_absolute(_keep)
	ModelDB.load_manifest()
	_mats = ModernMaterials.new()
	if not ModelDB.available():
		print("RENDER-CHECK models FEHLER  kein gültiges Modell-Manifest")
		quit(1)
		return
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-11s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


## A small world of its own: black background, ambient light only (white, `ambient` = its energy; 0 = darkness, only
## emission shows), no sky, no glow, linear tonemapper, the post path pinned as in the game (contract D6), no
## anti-aliasing – pixel values are what the material gives. Orthographic camera looking along -Z.
func _rig(size: Vector2i, ambient: float, width_m: float, centre: Vector3) -> Dictionary:
	var sv := SubViewport.new()
	sv.size = size
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = width_m
	cam.near = 0.1
	cam.far = 200.0
	cam.position = centre + Vector3(0.0, 0.0, 50.0)
	sv.add_child(cam)
	var holder := Node3D.new()
	sv.add_child(holder)
	ModernMaterials.set_global("ce_night", 0.0)
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(Color.WHITE, ambient))
	ModernMaterials.set_global("ce_sun_color", Color(0.0, 0.0, 0.0))
	ModernMaterials.set_global("ce_sun_dir", Vector3(0.0, 1.0, 0.0))
	ModernMaterials.set_global("ce_time", 1.0)
	return {"sv": sv, "cam": cam, "holder": holder, "env": env}


func _shot(rig: Dictionary, name: String = "") -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = (rig["sv"] as SubViewport).get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if _keep != "" and name != "":
		img.save_png(_keep.path_join(name + ".png"))
	return img


func _drop(rig: Dictionary) -> void:
	(rig["sv"] as SubViewport).queue_free()
	await process_frame


func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Mean colour of a rectangle of a picture.
func _mean(img: Image, r: Rect2i) -> Color:
	var s := Vector3.ZERO
	var n := 0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
			var c := img.get_pixel(x, y)
			s += Vector3(c.r, c.g, c.b)
			n += 1
	return Color(s.x / maxf(n, 1.0), s.y / maxf(n, 1.0), s.z / maxf(n, 1.0))


## Pixels of a rectangle for which `pick` is true.
func _count(img: Image, r: Rect2i, pick: Callable) -> int:
	var n := 0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
			if bool(pick.call(img.get_pixel(x, y))):
				n += 1
	return n


func _lit(c: Color) -> bool:
	return _lum(c) > 0.03


## Hue in degrees (0 red, 30–45 amber, 60 yellow, 240 blue).
func _hue(c: Color) -> float:
	return c.h * 360.0


## A mesh of upright quads in the XY plane (facing +Z), one per entry: {x, y, w, h, color, alpha, uv, uv2}.
func _quads(list: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for q: Dictionary in list:
		var base := verts.size()
		var x0 := float(q["x"])
		var y0 := float(q["y"])
		var corners := [Vector2(x0, y0 + float(q["h"])), Vector2(x0 + float(q["w"]), y0 + float(q["h"])), Vector2(x0 + float(q["w"]), y0), Vector2(x0, y0)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in 4:
			verts.append(Vector3(corners[i].x, corners[i].y, 0.0))
			normals.append(Vector3(0.0, 0.0, 1.0))
			var c := Color(str(q.get("color", "#808080")))
			c.a = float(q.get("alpha", 1.0))
			colors.append(c)
			uv.append(q.get("uv", uvs[i]) if q.has("uv") else uvs[i])
			uv2.append(q.get("uv2", Vector2(-1.0, 0.0)))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _instance(mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat != null:
		mi.material_override = mat
	parent.add_child(mi)
	return mi


# --- klassen: every material class draws -----------------------------------------------------------------------

func _check_klassen() -> void:
	var p: Array[String] = []
	var notes: Array[String] = []
	# vpbr and glass on plain quads, by day: a grey quad shows its grey, glass veils what is behind it
	var rig := _rig(Vector2i(400, 200), 1.0, 4.0, Vector3(2.0, 1.0, 0.0))
	var holder: Node3D = rig["holder"]
	_instance(_quads([{"x": 0.2, "y": 0.2, "w": 1.6, "h": 1.6, "color": "#b0b0b0", "uv": Vector2(0.9, 0.0)},
		{"x": 2.2, "y": 0.2, "w": 1.6, "h": 1.6, "color": "#b0b0b0", "uv": Vector2(0.9, 0.0)}]), _mats.material("vpbr"), holder)
	var glass := _instance(_quads([{"x": 2.5, "y": 0.5, "w": 1.0, "h": 1.0, "color": "#102040", "alpha": 0.5, "uv": Vector2(0.1, 0.0)}]), _mats.material("glass"), holder)
	glass.position.z = 0.5
	var img: Image = await _shot(rig, "klassen_vpbr_glas")
	var grey := _mean(img, Rect2i(60, 60, 80, 80))
	var veiled := _mean(img, Rect2i(275, 75, 50, 50))
	var beside := _mean(img, Rect2i(225, 30, 150, 12))
	_need(p, absf(grey.r - 0.69) < 0.03 and absf(grey.r - grey.g) < 0.01 and absf(grey.g - grey.b) < 0.01, "vpbr zeigt sein Grau (%s statt #b0b0b0)" % grey.to_html(false))
	_need(p, absf(beside.r - grey.r) < 0.01 and veiled.r < grey.r - 0.15 and veiled.b > veiled.r + 0.02, "glass verschleiert, was dahinter liegt (%s neben %s)" % [veiled.to_html(false), beside.to_html(false)])
	notes.append("vpbr %s, hinter Glas %s" % [grey.to_html(false), veiled.to_html(false)])
	await _drop(rig)
	# the textured classes on the reference models: baked (day, and the emission atlas at night), leaves, billboard
	for job: Array in [["props/farmhouse", "lod0", 16.0, Vector3(0.0, 3.5, 0.0), "baked"], ["props/tree_oak", "lod0", 14.0, Vector3(0.0, 5.0, 0.0), "leaves"],
			["props/tree_oak", "impostor", 14.0, Vector3(0.0, 5.0, 0.0), "billboard"]]:
		rig = _rig(Vector2i(320, 240), 1.0, float(job[2]), job[3])
		var node: Node3D = ModelFactory.build_impostor(str(job[0]), _mats) if str(job[1]) == "impostor" else ModelFactory.build(str(job[0]), str(job[1]), _mats)
		_need(p, node != null, "%s %s lässt sich bauen" % [job[0], job[1]])
		if node == null:
			await _drop(rig)
			continue
		(rig["holder"] as Node3D).add_child(node)
		node.rotation.y = deg_to_rad(180.0) if str(job[4]) == "baked" else 0.0      # the approach side towards the camera
		img = await _shot(rig, "klassen_" + str(job[4]))
		var drawn := _count(img, Rect2i(0, 0, 320, 240), _lit)
		var mean := _mean(img, Rect2i(120, 60, 80, 90))
		_need(p, drawn > 3000, "Klasse %s zeichnet (%d Pixel)" % [job[4], drawn])
		if str(job[4]) != "baked":
			_need(p, mean.g > mean.r and mean.g > mean.b, "%s: Laub ist grün (%s)" % [job[4], mean.to_html(false)])
		notes.append("%s %d px" % [job[4], drawn])
		if str(job[4]) == "baked":
			# night: only the emission atlas shows
			(rig["env"] as Environment).ambient_light_energy = 0.0
			ModernMaterials.set_global("ce_night", 1.0)
			var night: Image = await _shot(rig, "klassen_baked_nacht")
			var windows := _count(night, Rect2i(0, 0, 320, 240), _lit)
			ModernMaterials.set_global("ce_night", 0.0)
			var off: Image = await _shot(rig)
			_need(p, windows > 40 and windows < drawn / 2, "baked: beleuchtete Fenster bei Nacht (%d Pixel)" % windows)
			_need(p, _count(off, Rect2i(0, 0, 320, 240), _lit) == 0, "baked: ohne ce_night leuchtet nichts")
			notes.append("Fenster bei Nacht %d px" % windows)
		await _drop(rig)
	# the cut-out variant of baked (no reference model has one yet): a checkerboard of alpha on a quad – half of it
	# is cut away, the rest shows the texture
	rig = _rig(Vector2i(200, 200), 1.0, 2.0, Vector3(1.0, 1.0, 0.0))
	var board := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			board.set_pixel(x, y, Color(0.9, 0.6, 0.2, 1.0 if (x + y) % 2 == 0 else 0.0))
	var mat := ShaderMaterial.new()
	mat.shader = _mats.shader("baked_cutout")
	mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(board))
	_need(p, mat.shader != null, "Shader baked_cutout")
	_instance(_quads([{"x": 0.0, "y": 0.0, "w": 2.0, "h": 2.0}]), mat, rig["holder"])
	img = await _shot(rig, "klassen_cutout")
	var kept := _count(img, Rect2i(0, 0, 200, 200), _lit)
	var orange := _mean(img, Rect2i(3, 3, 18, 18))
	_need(p, absf(float(kept) / 40000.0 - 0.5) < 0.06, "baked_cutout schneidet die Hälfte weg (%.1f %% bleiben)" % (float(kept) / 400.0))
	_need(p, orange.r > 0.8 and orange.g > 0.5 and orange.b < 0.35, "baked_cutout zeigt die Textur (%s)" % orange.to_html(false))
	notes.append("cutout %.0f %%" % (float(kept) / 400.0))
	await _drop(rig)
	_report("klassen", p, "alle Materialklassen zeichnen: " + ", ".join(notes))


# --- lampen: the lamp channels -----------------------------------------------------------------------------------

func _strip() -> ArrayMesh:
	var list: Array = []
	for ch in CHANNEL_COLORS.size():
		list.append({"x": float(ch) * 0.6 + 0.05, "y": 0.1, "w": 0.5, "h": 0.8, "color": CHANNEL_COLORS[ch], "uv": Vector2(0.5, 0.0),
			"uv2": Vector2(float(ch) + 0.5, 1.0)})
	# reference quads without a lamp: the colours of the plate and of the flood-lit surface
	list.append({"x": 9.05, "y": 0.1, "w": 0.5, "h": 0.8, "color": CHANNEL_COLORS[8], "uv": Vector2(0.5, 0.0)})
	list.append({"x": 9.65, "y": 0.1, "w": 0.5, "h": 0.8, "color": CHANNEL_COLORS[14], "uv": Vector2(0.5, 0.0)})
	return _quads(list)


func _check_lampen() -> void:
	var p: Array[String] = []
	var size := Vector2i(1020, 100)             # 100 px per metre: a quad is 50 x 80 px
	var rig := _rig(size, 0.0, 10.2, Vector3(5.1, 0.5, 0.0))
	var mi := _instance(_strip(), _mats.material("vpbr"), rig["holder"])
	var cell := func(img: Image, i: int) -> Color:
		return _mean(img, Rect2i(i * 60 + 15, 30, 30, 40))
	# state: [name, lamp_a, lamp_b, ce_night, channels that must be lit]
	var states: Array = [
		["aus", Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0), 0.0, [6, 13]],
		["ruecklicht", Vector4(1, 0, 0, 0), Vector4(0, 0, 0, 0), 0.0, [0, 2, 6, 8, 9, 13]],
		["bremse", Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 0), 0.0, [1, 2, 6, 13]],
		["blinker_links", Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 0), 0.0, [3, 6, 13]],
		["blinker_rechts", Vector4(0, 0, 0, 1), Vector4(0, 0, 0, 0), 0.0, [4, 6, 13]],
		["scheinwerfer", Vector4(0, 0, 0, 0), Vector4(1, 0, 0, 0), 0.0, [5, 6, 13]],
		["rueckfahrlicht", Vector4(0, 0, 0, 0), Vector4(0, 1, 0, 0), 0.0, [6, 7, 13]],
		["blaulicht_a", Vector4(0, 0, 0, 0), Vector4(0, 0, 1, 0), 0.0, [6, 10, 13]],
		["blaulicht_b", Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 1), 0.0, [6, 11, 13]],
		["nacht", Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0), 1.0, [6, 12, 13, 14]],
	]
	var seen := {}
	for st: Array in states:
		mi.set_instance_shader_parameter("lamp_a", st[1])
		mi.set_instance_shader_parameter("lamp_b", st[2])
		ModernMaterials.set_global("ce_night", float(st[3]))
		var img: Image = await _shot(rig, "lampen_" + str(st[0]))
		var lit: Array = []
		var cols: Array = []
		for ch in 17:
			var c: Color = cell.call(img, ch)
			cols.append(c)
			if _lum(c) > 0.02:
				lit.append(ch)
		seen[str(st[0])] = cols
		_need(p, lit == st[4], "%s: es leuchten die Kanäle %s (statt %s)" % [st[0], str(lit), str(st[4])])
	ModernMaterials.set_global("ce_night", 0.0)
	var tail: Color = seen["ruecklicht"][2]
	var brake: Color = seen["bremse"][2]
	var ratio := _lum(brake) / maxf(_lum(tail), 0.0001)
	_need(p, ratio >= 1.8, "Bremslicht mindestens 1,8 × so hell wie das Rücklicht (Kanal 2: %.2f ×, %s gegen %s)" % [ratio, brake.to_html(false), tail.to_html(false)])
	_need(p, tail.r < 0.8 and tail.r > 0.4, "das Rücklicht bleibt deutlich unter Weiß (%s)" % tail.to_html(false))
	_need(p, _lum(seen["ruecklicht"][0]) > _lum(tail) * 1.5, "Kanal 0 (nur Rücklicht) heller als das Rücklicht von Kanal 2 (35 %)")
	var amber: Color = seen["blinker_links"][3]
	_need(p, _hue(amber) >= 20.0 and _hue(amber) <= 46.0 and amber.r > 0.9, "Blinker bernsteinfarben (%s, Farbton %.0f°)" % [amber.to_html(false), _hue(amber)])
	_need(p, (seen["blinker_rechts"][4] as Color).is_equal_approx(amber), "beide Blinker gleich")
	var blue: Color = seen["blaulicht_a"][10]
	_need(p, _hue(blue) >= 205.0 and _hue(blue) <= 245.0 and blue.b > 0.9 and blue.r < 0.6, "Blaulicht blau (%s, Farbton %.0f°)" % [blue.to_html(false), _hue(blue)])
	var head: Color = seen["scheinwerfer"][5]
	_need(p, head.r > 0.95 and head.g > 0.9 and head.b > 0.75, "Scheinwerfer weiß (%s)" % head.to_html(false))
	_need(p, _lum(seen["scheinwerfer"][6]) < _lum(seen["aus"][6]) * 0.8, "Tagfahrlicht mit dem Abblendlicht gedimmt")
	var plate_night: Color = seen["ruecklicht"][8]
	_need(p, _lum(plate_night) > 0.3 and _lum(plate_night) < 0.85, "Kennzeichen unter seiner Leuchte lesbar, nicht überstrahlt (%s)" % plate_night.to_html(false))
	# by day (ambient light only, all lamps off): unlit lamps are dark behind their lens; the lit surfaces keep
	# their colour – the plate was grey while it was drawn as an unlit lamp
	(rig["env"] as Environment).ambient_light_energy = 1.0
	mi.set_instance_shader_parameter("lamp_a", Vector4.ZERO)
	mi.set_instance_shader_parameter("lamp_b", Vector4(1, 0, 0, 0))      # low beam on: the daytime running light dims
	var day: Image = await _shot(rig, "lampen_tag")
	var plate: Color = cell.call(day, 8)
	var plate_ref: Color = cell.call(day, 15)
	var flood: Color = cell.call(day, 14)
	var flood_ref: Color = cell.call(day, 16)
	_need(p, absf(plate.r - plate_ref.r) < 0.012 and absf(plate.g - plate_ref.g) < 0.012 and absf(plate.b - plate_ref.b) < 0.012 and plate.r > 0.85,
		"Kennzeichen bei Tag in seiner eigenen Farbe (%s, ohne Lampenkanal %s)" % [plate.to_html(false), plate_ref.to_html(false)])
	_need(p, absf(flood.r - flood_ref.r) < 0.012 and absf(flood.g - flood_ref.g) < 0.012, "angestrahlte Fläche bei Tag in ihrer eigenen Farbe (%s / %s)" % [flood.to_html(false), flood_ref.to_html(false)])
	for ch: int in [0, 1, 2, 3, 4, 7, 9, 10, 11, 12]:
		var c: Color = cell.call(day, ch)
		# uniform lamp_off: half the display value = 22 % of the light (very dark channels come out a little darker
		# still: the renderer's conversions do not round-trip below about 5 %)
		var off := Color(CHANNEL_COLORS[ch]) * 0.5
		_need(p, absf(c.r - off.r) < 0.06 and absf(c.g - off.g) < 0.06 and absf(c.b - off.b) < 0.06,
			"Kanal %d bei Tag aus: die Lampe dunkel hinter der Linse (%s statt %s)" % [ch, c.to_html(false), off.to_html(false)])
	await _drop(rig)
	_report("lampen", p, "15 Lampenkanäle: jeder antwortet nur auf seinen Wert; Bremslicht %.2f × Rücklicht (%s / %s); Blinker %s (%.0f°), Blaulicht %s (%.0f°); Kennzeichen bei Tag %s, bei Nacht %s" % [
		ratio, brake.to_html(false), tail.to_html(false), amber.to_html(false), _hue(amber), blue.to_html(false), _hue(blue), plate.to_html(false), plate_night.to_html(false)])


# --- lackcodes ---------------------------------------------------------------------------------------------------

func _check_lackcodes() -> void:
	var p: Array[String] = []
	var rig := _rig(Vector2i(400, 100), 1.0, 4.0, Vector3(2.0, 0.5, 0.0))
	var list: Array = []
	var alphas := [1.0, 0.0, 0.25, 0.5]
	for i in 4:
		list.append({"x": float(i) + 0.1, "y": 0.1, "w": 0.8, "h": 0.8, "color": "#808080", "alpha": alphas[i], "uv": Vector2(0.9, 0.0)})
	var mi := _instance(_quads(list), _mats.material("vpbr"), rig["holder"])
	# the alpha of a paint uniform is its metallic value: 0 here, so the ambient light shows the plain colour
	mi.set_instance_shader_parameter("paint", Color(0.8, 0.1, 0.1, 0.0))
	mi.set_instance_shader_parameter("paint2", Color(0.1, 0.7, 0.1, 0.0))
	mi.set_instance_shader_parameter("paint3", Color(0.1, 0.1, 0.8, 0.0))
	var img: Image = await _shot(rig, "lackcodes")
	var got: Array = []
	for i in 4:
		got.append(_mean(img, Rect2i(i * 100 + 30, 30, 40, 40)))
	var want := [Color(0.5, 0.5, 0.5), Color(0.8, 0.1, 0.1), Color(0.1, 0.7, 0.1), Color(0.1, 0.1, 0.8)]
	var names := ["feste Farbe", "paint", "paint2", "paint3"]
	for i in 4:
		var g: Color = got[i]
		var w: Color = want[i]
		_need(p, absf(g.r - w.r) < 0.04 and absf(g.g - w.g) < 0.04 and absf(g.b - w.b) < 0.04, "%s zeigt %s (statt %s)" % [names[i], g.to_html(false), w.to_html(false)])
	await _drop(rig)
	_report("lackcodes", p, "feste Farbe %s, paint %s, paint2 %s, paint3 %s" % [(got[0] as Color).to_html(false), (got[1] as Color).to_html(false),
		(got[2] as Color).to_html(false), (got[3] as Color).to_html(false)])


# --- blinker, bremslicht: the lamps of the reference vehicles ------------------------------------------------------

## A vehicle in the dark, seen orthographically from straight behind (or ahead): pictures for lamp states.
func _vehicle_rig(set_id: String, lod: String, from_ahead: bool) -> Dictionary:
	var size := Vector2i(int(2.4 * PX_PER_M), int(1.6 * PX_PER_M))
	var rig := _rig(size, 0.0, 2.4, Vector3(0.0, 0.8, 0.0))
	var node := ModelFactory.build(set_id, lod, _mats)
	if node != null:
		(rig["holder"] as Node3D).add_child(node)
		if from_ahead:
			node.rotation.y = PI
	rig["node"] = node
	rig["size"] = size
	return rig


## Pixels that got clearly brighter from picture a to b in the left and in the right half: [left, right] of the
## PICTURE, and the mean colour of those pixels in b.
func _brighter(a: Image, b: Image) -> Dictionary:
	var half := a.get_width() / 2
	var n := [0, 0]
	var sum := Vector3.ZERO
	for y in a.get_height():
		for x in a.get_width():
			var cb := b.get_pixel(x, y)
			if _lum(cb) - _lum(a.get_pixel(x, y)) > 0.08:
				n[0 if x < half else 1] += 1
				sum += Vector3(cb.r, cb.g, cb.b)
	var total := maxf(float(n[0] + n[1]), 1.0)
	return {"left": n[0], "right": n[1], "color": Color(sum.x / total, sum.y / total, sum.z / total)}


func _check_blinker() -> void:
	var p: Array[String] = []
	var min_px := int(INDICATOR_MIN_CM2 * 1.0e-4 * PX_PER_M * PX_PER_M)        # 60 cm² at 200 px/m = 240 px
	var notes: Array[String] = []
	# [set, level, seen from ahead, the lamp must be amber on screen (not behind a tinted lens)]
	var jobs: Array = [["traffic/sedan_silver", "lod0", false, true], ["traffic/sedan_silver", "lod1", false, true], ["traffic/sedan_silver", "lod2", false, true],
		["traffic/sedan_silver", "lod0", true, true], ["traffic/sedan_silver", "lod1", true, true], ["traffic/sedan_silver", "lod2", true, true],
		["player/limousine", "lod0", false, false]]
	for job: Array in jobs:
		var rig := _vehicle_rig(str(job[0]), str(job[1]), bool(job[2]))
		var node: Node3D = rig["node"]
		var tag := "%s %s %s" % [str(job[0]).get_file(), job[1], "von vorn" if bool(job[2]) else "von hinten"]
		_need(p, node != null, tag + ": Modell lässt sich bauen")
		if node == null:
			await _drop(rig)
			continue
		var head := 1.0 if bool(job[2]) else 0.0
		ModelFactory.set_lamps(node, Vector4(1, 0, 0, 0), Vector4(head, 0, 0, 0))
		var base: Image = await _shot(rig)
		ModelFactory.set_lamps(node, Vector4(1, 0, 1, 0), Vector4(head, 0, 0, 0))
		var left_on: Image = await _shot(rig, "blinker_%s_%s_%s_links" % [str(job[0]).get_file(), job[1], "vorn" if bool(job[2]) else "hinten"])
		ModelFactory.set_lamps(node, Vector4(1, 0, 0, 1), Vector4(head, 0, 0, 0))
		var right_on: Image = await _shot(rig)
		var dl := _brighter(base, left_on)
		var dr := _brighter(base, right_on)
		# seen from behind the car's left is the picture's left; seen from ahead it is the picture's right
		var own := "right" if bool(job[2]) else "left"
		var other := "left" if bool(job[2]) else "right"
		_need(p, int(dl[own]) >= min_px and int(dl[other]) <= 4, "%s: Blinker links leuchtet auf seiner Seite (%d Pixel, drüben %d; verlangt %d)" % [tag, int(dl[own]), int(dl[other]), min_px])
		_need(p, int(dr[other]) >= min_px and int(dr[own]) <= 4, "%s: Blinker rechts leuchtet auf seiner Seite (%d Pixel, drüben %d; verlangt %d)" % [tag, int(dr[other]), int(dr[own]), min_px])
		var col: Color = dl["color"]
		if bool(job[3]):
			_need(p, _hue(col) >= 20.0 and _hue(col) <= 46.0 and col.r > 0.85, "%s: Blinker bernsteinfarben (%s, %.0f°)" % [tag, col.to_html(false), _hue(col)])
		notes.append("%s %d/%d px %s" % [tag, int(dl[own]), int(dr[other]), col.to_html(false)])
		await _drop(rig)
	_report("blinker", p, "Blinker bei Nacht, je Seite mindestens %d Pixel (60 cm² bei 200 px/m): %s" % [min_px, "; ".join(notes)])


func _check_bremslicht() -> void:
	var p: Array[String] = []
	var notes: Array[String] = []
	for lod: String in ["lod0", "lod1", "lod2"]:
		var rig := _vehicle_rig("traffic/sedan_silver", lod, false)
		var node: Node3D = rig["node"]
		_need(p, node != null, lod + ": Modell lässt sich bauen")
		if node == null:
			await _drop(rig)
			continue
		ModelFactory.set_lamps(node, Vector4(1, 0, 0, 0), Vector4.ZERO)
		var tail: Image = await _shot(rig, "bremslicht_%s_ruecklicht" % lod)
		ModelFactory.set_lamps(node, Vector4(1, 1, 0, 0), Vector4.ZERO)
		var brake: Image = await _shot(rig, "bremslicht_%s_bremse" % lod)
		# the tail lamps: what is red in the tail-light picture (the plate is lit as well, but it is not red)
		var lum_t := 0.0
		var lum_b := 0.0
		var n := 0
		for y in tail.get_height():
			for x in tail.get_width():
				var c := tail.get_pixel(x, y)
				if c.r > 0.3 and c.r > c.g * 2.5:
					n += 1
					lum_t += _lum(c)
					lum_b += _lum(brake.get_pixel(x, y))
		var ratio := lum_b / maxf(lum_t, 0.0001)
		var third := _count(brake, Rect2i(0, 0, tail.get_width(), int(0.45 * PX_PER_M)), _lit)      # the brake light in the rear window
		_need(p, n > 800, "%s: Rücklichter im Bild (%d Pixel)" % [lod, n])
		_need(p, ratio >= 1.8, "%s: Bremsen mindestens 1,8 × so hell wie das Rücklicht (%.2f ×)" % [lod, ratio])
		_need(p, third > 40 and _count(tail, Rect2i(0, 0, tail.get_width(), int(0.45 * PX_PER_M)), _lit) == 0, "%s: dritte Bremsleuchte nur beim Bremsen (%d Pixel)" % [lod, third])
		notes.append("%s %.2f × auf %d Pixeln" % [lod, ratio, n])
		await _drop(rig)
	_report("bremslicht", p, "Verkehrs-Limousine bei Nacht, Leuchtdichte der Heckleuchten beim Bremsen gegen Rücklicht allein: " + ", ".join(notes))


# --- multimesh ---------------------------------------------------------------------------------------------------

## A MultiMeshInstance3D with one instance per transform for every part of a level.
func _multimesh_nodes(parts: Array, transforms: Array, parent: Node3D) -> Array:
	var out: Array = []
	for part: Dictionary in parts:
		if bool(part["shadow"]):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part["mesh"]
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, (transforms[i] as Transform3D) * (part["transform"] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		parent.add_child(mmi)
		out.append(mmi)
	return out


func _flip_x(img: Image) -> Image:
	var out: Image = img.duplicate()
	out.flip_x()
	return out


## Share of the pixels that differ clearly between two pictures of the same size.
func _differ(a: Image, b: Image) -> float:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.12:
				n += 1
	return float(n) / float(a.get_width() * a.get_height())


func _check_multimesh() -> void:
	var p: Array[String] = []
	var size := Vector2i(480, 360)
	# the street light (vpbr, lamp channel 12): two instances per MultiMesh, seen from the road side; then the same
	# MultiMesh under a node mirrored in X (the left roadside, contract D24)
	var parts := ModelFactory.multimesh_parts("props/streetlight", "", _mats)
	_need(p, parts.size() == 1, "multimesh_parts(props/streetlight): ein Teil (%d)" % parts.size())
	var transforms := [Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)), Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), Vector3(4.5, 0.0, -1.0))]
	var pictures := {}
	for mirrored: bool in [false, true]:
		for night: float in [0.0, 1.0]:
			var rig := _rig(size, 1.0 if night == 0.0 else 0.0, 16.0, Vector3(0.0, 5.0, 0.0))
			var holder: Node3D = rig["holder"]
			if mirrored:
				holder.scale = Vector3(-1.0, 1.0, 1.0)
			_multimesh_nodes(parts, transforms, holder)
			ModernMaterials.set_global("ce_night", night)
			pictures["%s_%d" % ["spiegel" if mirrored else "normal", int(night)]] = await _shot(rig, "multimesh_laterne_%s_%s" % ["gespiegelt" if mirrored else "normal", "nacht" if night > 0.0 else "tag"])
			await _drop(rig)
	ModernMaterials.set_global("ce_night", 0.0)
	var day: Image = pictures["normal_0"]
	var day_m: Image = pictures["spiegel_0"]
	var drawn := _count(day, Rect2i(Vector2i.ZERO, size), _lit)
	var drawn_m := _count(day_m, Rect2i(Vector2i.ZERO, size), _lit)
	_need(p, drawn > 600, "beide Instanzen der Laterne gezeichnet (%d Pixel)" % drawn)
	_need(p, _count(day, Rect2i(0, 0, size.x / 2 - 40, size.y), _lit) > 100 and _count(day, Rect2i(size.x / 2 + 40, 0, size.x / 2 - 40, size.y), _lit) > 100, "je eine Instanz links und rechts der Bildmitte")
	# the mirrored node shows the mirror image: same silhouette, same shading – inside out it would show the dark
	# inner faces or holes
	var diff := _differ(_flip_x(day), day_m)
	_need(p, absi(drawn - drawn_m) <= drawn / 50 and diff < 0.004, "gespiegelter Knoten = Spiegelbild mit richtiger Flächenorientierung (%d / %d Pixel, %.2f %% verschieden)" % [drawn, drawn_m, diff * 100.0])
	var lamp := _count(pictures["normal_1"], Rect2i(Vector2i.ZERO, size), _lit)
	var lamp_m := _count(pictures["spiegel_1"], Rect2i(Vector2i.ZERO, size), _lit)
	_need(p, lamp > 20 and lamp < drawn / 3 and absi(lamp - lamp_m) <= maxi(lamp / 10, 3), "die Lampen leuchten bei Nacht, normal wie gespiegelt (%d / %d Pixel)" % [lamp, lamp_m])
	# the far level of the card tree: billboards in a MultiMesh (three instances), then under a mirrored node
	var model: Dictionary = ModelDB.resolve("props/tree_oak").get("model", {})
	var imp: Dictionary = model.get("impostor", {})
	var tex := ModelDB.texture(str(imp.get("texture", "")))
	_need(p, tex != null, "Impostor-Textur der Eiche")
	var counts: Array = []
	if tex != null:
		var size_m: Array = imp.get("size_m", [1.0, 1.0])
		var quad := ModelFactory.billboard_mesh(float(size_m[0]), float(size_m[1]), float(imp.get("anchor_x", 0.5)))
		quad.surface_set_material(0, _mats.billboard(tex))
		var spots := [Transform3D(Basis.IDENTITY, Vector3(-14.0, 0.0, 0.0)), Transform3D(Basis(Vector3.UP, 1.0), Vector3(0.0, 0.0, -6.0)), Transform3D(Basis(Vector3.UP, 2.5), Vector3(14.0, 0.0, 3.0))]
		for mirrored: bool in [false, true]:
			var rig := _rig(size, 1.0, 44.0, Vector3(0.0, 6.0, 0.0))
			var holder: Node3D = rig["holder"]
			if mirrored:
				holder.scale = Vector3(-1.0, 1.0, 1.0)
			_multimesh_nodes([{"mesh": quad, "transform": Transform3D.IDENTITY, "shadow": false}], spots, holder)
			var img: Image = await _shot(rig, "multimesh_impostor_%s" % ("gespiegelt" if mirrored else "normal"))
			var thirds: Array = []
			for i in 3:
				thirds.append(_count(img, Rect2i(i * size.x / 3, 0, size.x / 3, size.y), _lit))
			counts.append(thirds)
			await _drop(rig)
		var a: Array = counts[0]
		var b: Array = counts[1]
		_need(p, int(a[0]) > 1500 and int(a[1]) > 1500 and int(a[2]) > 1500, "drei Impostor-Instanzen gezeichnet, wie auch immer sie gedreht sind (%s Pixel)" % str(a))
		_need(p, absi(int(a[0]) - int(a[1])) < int(a[0]) / 12 and absi(int(a[1]) - int(a[2])) < int(a[1]) / 12, "alle drei stehen parallel zum Bild (gleich groß)")
		_need(p, absi(int(a[0]) - int(b[2])) < int(a[0]) / 12 and absi(int(a[1]) - int(b[1])) < int(a[1]) / 12 and absi(int(a[2]) - int(b[0])) < int(a[2]) / 12,
			"unter einem gespiegelten Knoten ebenso (%s Pixel)" % str(b))
	_report("multimesh", p, "Laterne als MultiMesh: %d Pixel, gespiegelter Knoten %.2f %% vom Spiegelbild verschieden, Lampen bei Nacht %d / %d Pixel; Impostor-Billboards im MultiMesh %s, gespiegelt %s" % [
		drawn, diff * 100.0, lamp, lamp_m, str(counts[0]) if counts.size() > 0 else "–", str(counts[1]) if counts.size() > 1 else "–"])
