extends SceneTree
## FLACKER-ANALYSE (scratch only): which value does a REFUSED instance read for each of the ten instance uniforms of
## vpbr.gdshader (indices 0..9), with the ce_* globals registered exactly as the game does (ModernMaterials)?
## Each ce_* global gets a unique first component (slot i -> 0.05 * (i + 1)); probe k shows instance uniform k (.x).

var _frames := 0
var _probes: Array = []
var _cam: Camera3D
const NAMES := ["paint", "paint2", "paint3", "lamp_a", "lamp_b", "fade", "sun", "fill", "gloss", "xfade"]


func _initialize() -> void:
	root.size = Vector2i(800, 200)
	ModernMaterials.ensure_globals()
	var i := 0
	for g: Array in ModernMaterials.GLOBALS:
		var v := 0.30 + 0.04 * float(i)
		var t: int = g[1]
		var val: Variant = v
		if t == RenderingServer.GLOBAL_VAR_TYPE_VEC2:
			val = Vector2(v, 0.0)
		elif t == RenderingServer.GLOBAL_VAR_TYPE_VEC3:
			val = Vector3(v, 0.0, 0.0)
		elif t == RenderingServer.GLOBAL_VAR_TYPE_VEC4:
			val = Vector4(v, 0.0, 0.0, 0.0)
		elif t == RenderingServer.GLOBAL_VAR_TYPE_COLOR:
			val = Color(v, 0.0, 0.0, 1.0)
		RenderingServer.global_shader_parameter_set(StringName(str(g[0])), val)
		i += 1
	var world := Node3D.new()
	root.add_child(world)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 4.0
	_cam.position = Vector3(4.5, -0.5, 10.0)
	world.add_child(_cam)
	_cam.current = true
	# fill the buffer with hidden dummies of a material with instance uniforms
	var dsh := Shader.new()
	dsh.code = "shader_type spatial;\ninstance uniform vec4 d0 : instance_index(0);\nvoid fragment(){ ALBEDO = d0.rgb; }"
	var dm := ShaderMaterial.new()
	dm.shader = dsh
	var qd := QuadMesh.new()
	qd.size = Vector2(0.01, 0.01)
	qd.material = dm
	for n in 300:
		var mi := MeshInstance3D.new()
		mi.mesh = qd
		mi.position = Vector3(0.0, -100.0, 0.0)
		world.add_child(mi)
	_world_ref = world


var _world_ref: Node3D


var _calib: Array = []


func _make_calib() -> void:
	for i in ModernMaterials.GLOBALS.size():
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment(){ ALBEDO = vec3(%f); }" % (0.30 + 0.04 * float(i))
		var m := ShaderMaterial.new()
		m.shader = sh
		var qm := QuadMesh.new()
		qm.size = Vector2(0.4, 0.4)
		qm.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.position = Vector3(float(i) * 0.5, -1.0, 0.0)
		_world_ref.add_child(mi)
		_calib.append(mi)


func _make_probes() -> void:
	var decl := ""
	for k in NAMES.size():
		decl += "instance uniform vec4 u%d : instance_index(%d) = vec4(0.99);\n" % [k, k]
	for k in NAMES.size():
		var sh := Shader.new()
		var sum := ""
		for j in NAMES.size():
			sum += "u%d.x * 0.0 + " % j
		sh.code = "shader_type spatial;\nrender_mode unshaded;\n" + decl + "void fragment(){ float v = %s u%d.x; ALBEDO = vec3(v); }" % [sum, k]
		var m := ShaderMaterial.new()
		m.shader = sh
		var qm := QuadMesh.new()
		qm.size = Vector2(0.8, 0.8)
		qm.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.position = Vector3(float(k), 0.0, 0.0)
		_world_ref.add_child(mi)
		_probes.append(mi)


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 4:
		_make_probes()
		_make_calib()
		return false
	if _frames < 10:
		return false
	var img := root.get_texture().get_image()
	var out: Array[String] = []
	for k in _probes.size():
		var p := _cam.unproject_position((_probes[k] as Node3D).global_position)
		var c := img.get_pixelv(Vector2i(p))
		# unshaded ALBEDO goes through sRGB -> linear -> sRGB: the displayed value is the value
		var slot := -1
		var best := 1.0
		for i in _calib.size():
			var pc := _cam.unproject_position((_calib[i] as Node3D).global_position)
			var cc := img.get_pixelv(Vector2i(pc))
			if absf(cc.r - c.r) < best:
				best = absf(cc.r - c.r)
				slot = i
		if best > 0.012:
			slot = -1
		var gname := str(ModernMaterials.GLOBALS[slot][0]) if slot >= 0 and slot < ModernMaterials.GLOBALS.size() else "?"
		out.append("%s(idx %d) liest %.3f -> %s" % [NAMES[k], k, c.r, "0 (ausserhalb)" if c.r < 0.02 else ("Vorgabe 0.99 (nicht abgelehnt)" if c.r > 0.95 else "Slot %d %s" % [slot, gname])])
	for l in out:
		print("FLK ", l)
	quit(0)
	return true
