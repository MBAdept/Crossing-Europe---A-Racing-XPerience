W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"


def sub(path, old, new, c=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    assert t.count(old) == c, (path, old[:70], t.count(old))
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)


P = "scripts/race3d/builders/props.gd"
sub(P, """## RINT-M2: the custom data of a stand-in (no tint there: its tint is the instance colour). Godot's Compatibility
## renderer reads INSTANCE_CUSTOM of a MultiMesh with colours but without custom data from the bytes behind the colour
## (measured: (0, 1, 0, 1) – a bright green tint in billboard/vpbr/baked/leaves); with custom data a = 0 the shaders
## leave the albedo as it is. A MultiMesh with neither reads (0, 0, 0, 0), a MeshInstance3D 0 as well.
const NO_CUSTOM := [0.0, 0.0, 0.0, 0.0]""",
    """## RINT-M2 (A-19): every MultiMesh of this builder carries an instance colour AND custom data – 20 floats per
## instance: transform, colour, custom. A stand-in: colour = its tint, custom = NO_CUSTOM; a model: colour = white
## (MODEL_COLOR – Godot multiplies it into the vertex colour, which the models use as data), custom = its tint (r, g, b, 1).
## Godot's Compatibility renderer (4.7.2, measured with probes on llvmpipe) reads INSTANCE_CUSTOM wrongly in the two
## other layouts: with colours but no custom data as (0, 1, 0, 1), and with custom data but no colours, set through
## MultiMesh.buffer, as garbage on the real prop meshes (bright green windows, trees and turbines) – fine only through
## set_instance_custom_data(), which is too slow per instance. A MultiMesh with neither reads (0, 0, 0, 0) and a
## MeshInstance3D 0: a < 0.5, the shaders leave the albedo as it is.
const NO_CUSTOM := [0.0, 0.0, 0.0, 0.0]
const MODEL_COLOR := [1.0, 1.0, 1.0, 1.0]
const INSTANCE_FLOATS := 20""")
# far landmark stand-in
sub(P, """					one.append_array(PackedFloat32Array(NO_CUSTOM))
					var mm := _mmi(pd, one, 1, true, false, true)""", """					one.append_array(PackedFloat32Array(NO_CUSTOM))
					var mm := _mmi(pd, one, 1, false)""")
# warm-up: one buffer for models and stand-ins (white colour, white custom)
sub(P, """	var one_c := one.duplicate()
	one_c.append_array(PackedFloat32Array([1.0, 1.0, 1.0, 1.0]))""", """	var one_c := one.duplicate()
	one_c.append_array(PackedFloat32Array(MODEL_COLOR))
	one_c.append_array(PackedFloat32Array([1.0, 1.0, 1.0, 1.0]))""")
sub(P, """						var node := _mmi(part, one_c, 1, false, false, true)""", """						var node := _mmi(part, one_c, 1, false)""")
sub(P, """				var one_cc := one_c.duplicate()
				one_cc.append_array(PackedFloat32Array(NO_CUSTOM))
				out.append(_mmi(s, one_cc, 1, true, false, true))""", """				out.append(_mmi(s, one_c, 1, false))""")
# placement
sub(P, """	# the placement tint (tint × fallback_tint, white without one): a stand-in carries it as its instance colour, a model
	# as its instance custom data (r, g, b, 1) – RINT-M2 (A-19): baked, vpbr_static, leaves and billboard multiply the
	# albedo by it as Arcade multiplies the sprite; never an instance uniform (the global shader buffer, A-19)
	buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
	if not is_model:
		buf.append_array(PackedFloat32Array(NO_CUSTOM))   # see NO_CUSTOM""", """	# the placement tint (tint × fallback_tint, white without one): a stand-in carries it as its instance colour, a model
	# as its instance custom data (r, g, b, 1) – RINT-M2 (A-19): baked, vpbr_static, leaves and billboard multiply the
	# albedo by it as Arcade multiplies the sprite; never an instance uniform (the global shader buffer, A-19). Layout:
	# INSTANCE_FLOATS (see NO_CUSTOM)
	if is_model:
		buf.append_array(PackedFloat32Array(MODEL_COLOR))
		buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
	else:
		buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
		buf.append_array(PackedFloat32Array(NO_CUSTOM))""")
sub(P, """					var node := _mmi(mp, buf, n, false, bool(g["mirror"]), true)""", """					var node := _mmi(mp, buf, n, bool(g["mirror"]))""", 2)
sub(P, """			var node := _mmi(s, buf, n, true, bool(g["mirror"]), true)""", """			var node := _mmi(s, buf, n, bool(g["mirror"]))""")
sub(P, """## A MultiMeshInstance3D for one mesh: with_color = the buffer carries an instance colour (stand-ins), with_custom =
## instance custom data (models: their placement tint, RINT-M2). With colours the buffer always carries custom data too
## (a stand-in: NO_CUSTOM).
static func _mmi(part: Dictionary, buf: PackedFloat32Array, n: int, with_color: bool, mirrored: bool,
		with_custom: bool = false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = with_color
	# RINT-M2: colours never without custom data (see NO_CUSTOM) – a caller with colours passes NO_CUSTOM in the buffer
	mm.use_custom_data = with_custom or with_color
	mm.mesh = part["mesh"]""", """## A MultiMeshInstance3D for one mesh; buf: INSTANCE_FLOATS per instance (transform, colour, custom – see NO_CUSTOM).
static func _mmi(part: Dictionary, buf: PackedFloat32Array, n: int, mirrored: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = part["mesh"]""")
sub(P, """		var stride := 12 + (4 if with_color else 0) + (4 if mm.use_custom_data else 0)
		for i in n:
			var o := i * stride""", """		for i in n:
			var o := i * INSTANCE_FLOATS""")
sub(P, """			if with_color:
				mm.set_instance_color(i, Color(buf[o + 12], buf[o + 13], buf[o + 14], buf[o + 15]))
			if mm.use_custom_data:
				var c := o + (16 if with_color else 12)
				mm.set_instance_custom_data(i, Color(buf[c], buf[c + 1], buf[c + 2], buf[c + 3]))""", """			mm.set_instance_color(i, Color(buf[o + 12], buf[o + 13], buf[o + 14], buf[o + 15]))
			mm.set_instance_custom_data(i, Color(buf[o + 16], buf[o + 17], buf[o + 18], buf[o + 19]))""")

T = "tests/unit/race3d/test_props.gd"
sub(T, """	assert_eq(buf.size(), 3 * 16, "je Instanz Transformation und Tönung (12 + 4)")
	if buf.size() == 48:
		var want := Color("#e8b8a4")
		assert_near(buf[12], want.r, 1.0e-4, "getönt: rot")
		assert_near(buf[13], want.g, 1.0e-4, "getönt: grün")
		assert_near(buf[14], want.b, 1.0e-4, "getönt: blau")
		assert_near(buf[15], 1.0, 1.0e-6, "getönt: a = 1 (die Shader lesen die Tönung nur dann)")
		for k in 4:
			assert_near(buf[16 + 12 + k], 1.0, 1.0e-6, "ungetönt: weiß (Bild unverändert) [%d]" % k)
		var fb := Color("#ff8080") * Color("#808080")
		assert_near(buf[32 + 12], fb.r, 1.0e-4, "Ersatz-Set: tint × fallback_tint (rot)")
		assert_near(buf[32 + 13], fb.g, 1.0e-4, "Ersatz-Set: tint × fallback_tint (grün)")""",
    """	assert_eq(buf.size(), 3 * Props.INSTANCE_FLOATS, "je Instanz Transformation, Farbe (weiß) und Tönung (12 + 4 + 4)")
	if buf.size() == 60:
		var want := Color("#e8b8a4")
		for k in 4:
			assert_near(buf[12 + k], 1.0, 1.0e-6, "Instanzfarbe eines Modells weiß [%d]" % k)
		assert_near(buf[16], want.r, 1.0e-4, "getönt: rot")
		assert_near(buf[17], want.g, 1.0e-4, "getönt: grün")
		assert_near(buf[18], want.b, 1.0e-4, "getönt: blau")
		assert_near(buf[19], 1.0, 1.0e-6, "getönt: a = 1 (die Shader lesen die Tönung nur dann)")
		for k in 4:
			assert_near(buf[20 + 16 + k], 1.0, 1.0e-6, "ungetönt: weiß (Bild unverändert) [%d]" % k)
		var fb := Color("#ff8080") * Color("#808080")
		assert_near(buf[40 + 16], fb.r, 1.0e-4, "Ersatz-Set: tint × fallback_tint (rot)")
		assert_near(buf[40 + 17], fb.g, 1.0e-4, "Ersatz-Set: tint × fallback_tint (grün)")""")
sub(T, """		assert_true(mmi.multimesh.use_custom_data, "Modell-Knoten trägt die Tönung als Instanzdaten (%s)" % mmi.multimesh.mesh.resource_path)
		assert_false(mmi.multimesh.use_colors, "… nicht als Farbe (die Scheitelfarben der Modelle sind Daten)")""",
    """		assert_true(mmi.multimesh.use_custom_data, "Modell-Knoten trägt die Tönung als Instanzdaten (%s)" % mmi.multimesh.mesh.resource_path)
		assert_true(mmi.multimesh.use_colors, "… und eine (weiße) Instanzfarbe – siehe Props.NO_CUSTOM")""")
sub(T, """	# Godot's Compatibility renderer reads garbage custom data from a MultiMesh with colours but without custom data
	# (measured: a bright green tint): _mmi() gives every MultiMesh with colours custom data as well, a stand-in's
	# buffer carries NO_CUSTOM (headless there are no stand-ins in a chunk: the builder's node maker directly)
	var one := PackedFloat32Array()
	Props._put(one, Transform3D.IDENTITY)
	one.append_array(PackedFloat32Array([1.0, 0.5, 0.5, 1.0]))
	one.append_array(PackedFloat32Array(Props.NO_CUSTOM))
	var sn := Props._mmi({"mesh": QuadMesh.new()}, one, 1, true, false)
	assert_true(sn.multimesh.use_colors and sn.multimesh.use_custom_data, "Vertretung: Farbe und Custom-Daten")""",
    """	# Godot's Compatibility renderer reads INSTANCE_CUSTOM wrongly unless a MultiMesh has colours AND custom data
	# (measured: bright green tints, see Props.NO_CUSTOM): _mmi() makes every node so, a stand-in's buffer carries
	# NO_CUSTOM (headless there are no stand-ins in a chunk: the builder's node maker directly)
	var one := PackedFloat32Array()
	Props._put(one, Transform3D.IDENTITY)
	one.append_array(PackedFloat32Array([1.0, 0.5, 0.5, 1.0]))
	one.append_array(PackedFloat32Array(Props.NO_CUSTOM))
	var sn := Props._mmi({"mesh": QuadMesh.new()}, one, 1, false)
	assert_true(sn.multimesh.use_colors and sn.multimesh.use_custom_data, "Vertretung: Farbe und Custom-Daten")""")
print("ok")
