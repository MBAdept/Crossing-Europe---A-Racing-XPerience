W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"


def sub(path, old, new, c=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    assert t.count(old) == c, (path, old[:70], t.count(old))
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)


T = "tests/unit/race3d/test_props.gd"
sub(T, """	# stand-ins: origin on the ground, uniform scale, instance colour = tint; the left one mirrored in the node
	var bl: PackedFloat32Array = (groups["s|%s|1" % sb] as Dictionary)["buf"]
	assert_eq(bl.size(), 16, "Vertretung: Transformation und Farbe")
	assert_near(bl[12], 1.0, 0.01, "Tönung rot")
	assert_near(bl[13], 0.5, 0.01, "Tönung grün")
	var zb := 199.0 * 3.0 + 1.0
	var pb := ctx.local(zb, _x(t, -1, 9.0), ctx.ground(zb, _x(t, -1, 9.0)))
	assert_near((node * _transforms(bl, 16)[0]).origin.distance_to(pb), 0.0, 1.0e-3, "gespiegelte Vertretung steht an ihrem Ort")
	var br: PackedFloat32Array = (groups["s|%s|0" % sb] as Dictionary)["buf"]
	assert_eq(br.size(), 32, "rechts zwei Vertretungen (eine als Ersatz-Set)")
	assert_near(_transforms(br, 16)[1].basis.x.x, 0.5, 1.0e-4, "Ersatz-Set mit fallback_scale")""",
    """	# stand-ins: origin on the ground, uniform scale, instance colour = tint, empty custom data (RINT-M2: see
	# Props.NO_CUSTOM); the left one mirrored in the node
	var bl: PackedFloat32Array = (groups["s|%s|1" % sb] as Dictionary)["buf"]
	assert_eq(bl.size(), 20, "Vertretung: Transformation, Farbe und leere Custom-Daten")
	assert_near(bl[12], 1.0, 0.01, "Tönung rot")
	assert_near(bl[13], 0.5, 0.01, "Tönung grün")
	assert_near(bl[19], 0.0, 1.0e-6, "Custom-Daten a = 0: keine zweite Tönung")
	var zb := 199.0 * 3.0 + 1.0
	var pb := ctx.local(zb, _x(t, -1, 9.0), ctx.ground(zb, _x(t, -1, 9.0)))
	assert_near((node * _transforms(bl, 20)[0]).origin.distance_to(pb), 0.0, 1.0e-3, "gespiegelte Vertretung steht an ihrem Ort")
	var br: PackedFloat32Array = (groups["s|%s|0" % sb] as Dictionary)["buf"]
	assert_eq(br.size(), 40, "rechts zwei Vertretungen (eine als Ersatz-Set)")
	assert_near(_transforms(br, 20)[1].basis.x.x, 0.5, 1.0e-4, "Ersatz-Set mit fallback_scale")""")
sub(T, """	assert_true(models >= 1, "Knoten des Modells gebaut (%d)" % models)
	# the shaders read it: custom data, a > 0.5, multiplied into the albedo""",
    """	assert_true(models >= 1, "Knoten des Modells gebaut (%d)" % models)
	# Godot's Compatibility renderer reads garbage custom data from a MultiMesh with colours but without custom data
	# (measured: a bright green tint): no node of the builder – models, stand-ins, warm-up – may have one
	var mixed := Node3D.new()
	_put(t, 201, {"kind": "prop", "set": _standin_set(), "side": 1, "x": _x(t, 1, 30.0), "scale": 1.0, "tint": "#ff8080"})
	for w: Node in b.warmup_nodes():
		mixed.add_child(w)
	b.commit(ctx, b.build(ctx, b.collect(ctx)), mixed)
	var checked := 0
	var stack: Array[Node] = [mixed]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		stack.append_array(x.get_children())
		if x is MultiMeshInstance3D and (x as MultiMeshInstance3D).multimesh != null:
			var mm := (x as MultiMeshInstance3D).multimesh
			checked += 1
			assert_true(not mm.use_colors or mm.use_custom_data, "MultiMesh mit Farbe trägt auch Custom-Daten (%s)" % x.name)
	assert_true(checked >= 3, "Knoten geprüft (%d)" % checked)
	mixed.free()
	# the shaders read it: custom data, a > 0.5, multiplied into the albedo""")
print("ok")
