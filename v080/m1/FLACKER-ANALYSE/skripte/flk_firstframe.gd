extends SceneTree
## FLACKER-ANALYSE (scratch only): does a geometry instance whose instance uniforms are allocated or changed in frame N
## show its own values in the picture of frame N (GL Compatibility, Godot 4.7)? Unshaded quads, instance uniform col
## (index 0) and fade (index 5, < 0.5 = discard, like vpbr's dither at fade 0). The picture of every frame is read in
## frame_post_draw and the centre pixel of each quad is logged.
## Steps: A red (left) for some frames -> A freed and B green created at the same place in the same frame (B takes
## A's slots) -> C yellow on fresh slots (right) -> B set to blue in place -> D magenta on A's freed slots after a
## frame without any owner -> E: an instance that is added without any value set (defaults).
## usage: xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://flk_firstframe.gd

var _frames := 0
var _mat: ShaderMaterial
var _qm: QuadMesh
var _world: Node3D
var _cam: Camera3D
var _a: MeshInstance3D
var _b: MeshInstance3D
var _c: MeshInstance3D
var _d: MeshInstance3D
var _e: MeshInstance3D
var _note := ""


func _initialize() -> void:
	root.size = Vector2i(320, 120)
	RenderingServer.set_default_clear_color(Color(0.5, 0.5, 0.5))
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\n" \
		+ "instance uniform vec4 col : instance_index(0) = vec4(0.0, 0.0, 1.0, 1.0);\n" \
		+ "instance uniform float fade : instance_index(5) = 1.0;\n" \
		+ "void fragment() { if (fade < 0.5) { discard; } ALBEDO = col.rgb; }\n"
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_qm = QuadMesh.new()
	_qm.size = Vector2(0.9, 0.9)
	_qm.material = _mat
	_world = Node3D.new()
	root.add_child(_world)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 1.2
	_cam.position = Vector3(0.0, 0.0, 3.0)
	_world.add_child(_cam)
	_cam.current = true
	RenderingServer.frame_post_draw.connect(_post)


func _quad(c: Variant, x: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _qm
	mi.position = Vector3(x, 0.0, 0.0)
	if c is Color:
		mi.set_instance_shader_parameter(&"col", c)
		mi.set_instance_shader_parameter(&"fade", 1.0)
	_world.add_child(mi)
	return mi


func _process(_dt: float) -> bool:
	_frames += 1
	_note = ""
	match _frames:
		3:
			_a = _quad(Color(1, 0, 0), -1.0)
			_note = "A rot links neu (frische Plaetze)"
		8:
			_a.free()
			_b = _quad(Color(0, 1, 0), -1.0)
			_note = "A frei, B gruen links neu (Plaetze von A)"
		13:
			_c = _quad(Color(1, 1, 0), 1.0)
			_note = "C gelb rechts neu (frische Plaetze)"
		18:
			_b.set_instance_shader_parameter(&"col", Color(0, 0, 1))
			_note = "B auf blau gesetzt"
		23:
			_b.free()
			_note = "B frei (Plaetze leer, ein Bild ohne Besitzer)"
		25:
			_d = _quad(Color(1, 0, 1), -1.0)
			_note = "D magenta links neu (Plaetze von B)"
		30:
			_c.free()
			_e = _quad(null, 1.0)
			_note = "C frei, E ohne gesetzte Werte rechts neu (Plaetze von C, Vorgaben blau/fade 1)"
		36:
			quit(0)
	return false


func _post() -> void:
	if _frames < 2:
		return
	var img := root.get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var l := img.get_pixel(int(w * 0.5 - _px_off(w)), h / 2)
	var r := img.get_pixel(int(w * 0.5 + _px_off(w)), h / 2)
	print("FLKFF f%02d links %s rechts %s %s" % [_frames, _name(l), _name(r), _note])


func _px_off(w: int) -> float:
	# x = 1.0 world -> pixels: ortho size 1.2 is the height; width = 1.2 * aspect
	var aspect := float(w) / float(root.size.y)
	return 1.0 / (1.2 * aspect) * float(w)


static func _name(c: Color) -> String:
	var t := "(%d,%d,%d)" % [roundi(c.r8), roundi(c.g8), roundi(c.b8)]
	var names := {"rot": Color(1, 0, 0), "gruen": Color(0, 1, 0), "blau": Color(0, 0, 1), "gelb": Color(1, 1, 0),
		"magenta": Color(1, 0, 1), "schwarz": Color(0, 0, 0), "grau(Hintergrund)": Color(0.5, 0.5, 0.5)}
	var best := ""
	var bd := 1e9
	for k: String in names:
		var n: Color = names[k]
		var d := absf(n.r - c.r) + absf(n.g - c.g) + absf(n.b - c.b)
		if d < bd:
			bd = d
			best = k
	return best + t
