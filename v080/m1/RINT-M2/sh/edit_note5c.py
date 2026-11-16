W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
p = W + "tests/unit/race3d/test_props.gd"
t = open(p, encoding="utf-8").read()
anchor = "func test_chunk_lod_shows_one_representation() -> void:"
assert t.count(anchor) == 1
new = '''## RINT-M2 (A-19): the placement tint ("tint", times "fallback_tint") reaches a MODEL instance as its MultiMesh custom data
## (r, g, b, 1) – the shaders multiply the albedo by it as Arcade multiplies the sprite; an untinted model gets white
## (its picture stays as it was); never an instance uniform. Stand-ins keep it as their instance colour.
func test_model_instances_carry_the_placement_tint() -> void:
	var t := _track()
	_put(t, 195, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0, "tint": "#e8b8a4"})
	_put(t, 197, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0})
	_put(t, 199, {"kind": "prop", "set": "props/does_not_exist", "fallback": "props/farmhouse", "fallback_tint": "#808080",
		"tint": "#ff8080", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var g: Dictionary = (part["groups"] as Dictionary).get("m|props/farmhouse|0", {})
	assert_eq(int(g.get("n", 0)), 3, "drei Bauernhäuser in einer Gruppe")
	var buf: PackedFloat32Array = g.get("buf", PackedFloat32Array())
	assert_eq(buf.size(), 3 * 16, "je Instanz Transformation und Tönung (12 + 4)")
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
		assert_near(buf[32 + 13], fb.g, 1.0e-4, "Ersatz-Set: tint × fallback_tint (grün)")
	var parent := Node3D.new()
	b.commit(ctx, part, parent)
	var holder := parent.get_child(0) as Node3D
	var models := 0
	for c: Node in holder.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.name == &"Contact":
			continue
		models += 1
		assert_true(mmi.multimesh.use_custom_data, "Modell-Knoten trägt die Tönung als Instanzdaten (%s)" % mmi.multimesh.mesh.resource_path)
		assert_false(mmi.multimesh.use_colors, "… nicht als Farbe (die Scheitelfarben der Modelle sind Daten)")
		assert_eq(mmi.multimesh.instance_count, 3, "drei Instanzen")
	assert_true(models >= 1, "Knoten des Modells gebaut (%d)" % models)
	# the shaders read it: custom data, a > 0.5, multiplied into the albedo
	var mats := ModernMaterials.shared()
	for cls: String in ["baked", "leaves", "billboard", "vpbr"]:
		var code := mats.shader(cls).code
		assert_true(code.contains("INSTANCE_CUSTOM.a > 0.5 ? INSTANCE_CUSTOM.rgb : vec3(1.0)") and code.contains("v_tint"),
			"%s liest die Tönung aus den Instanzdaten" % cls)
		assert_false(code.contains("instance uniform vec4 tint") or code.contains("instance uniform vec3 tint"), "%s: keine Instanz-Uniform dafür" % cls)
	assert_true(ModernMaterials.static_code(mats.shader("vpbr").code).contains("alb *= v_tint"), "vpbr_static multipliert die Albedo")
	parent.free()
	_cleanup()


''' + anchor
t = t.replace(anchor, new)
open(p, "w", encoding="utf-8").write(t)
print("ok")
