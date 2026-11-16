W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"


def sub(path, old, new, c=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    assert t.count(old) == c, (path, old[:70], t.count(old))
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)


P = "scripts/race3d/builders/props.gd"
sub(P, """	# the placement tint (tint × fallback_tint, white without one): a stand-in carries it as its instance colour, a model
	# as its instance custom data (r, g, b, 1) – RINT-M2 (A-19): baked, vpbr_static, leaves and billboard multiply the
	# albedo by it as Arcade multiplies the sprite; never an instance uniform (the global shader buffer, A-19)
	buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))""", """	# the placement tint (tint × fallback_tint, white without one): a stand-in carries it as its instance colour, a model
	# as its instance custom data (r, g, b, 1) – RINT-M2 (A-19): baked, vpbr_static, leaves and billboard multiply the
	# albedo by it as Arcade multiplies the sprite; never an instance uniform (the global shader buffer, A-19)
	buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
	if not is_model:
		buf.append_array(PackedFloat32Array(NO_CUSTOM))   # see NO_CUSTOM""")
sub(P, """## A MultiMeshInstance3D for one mesh: with_color = the buffer carries an instance colour (stand-ins), with_custom =
## instance custom data (models: their placement tint, RINT-M2).""", """## A MultiMeshInstance3D for one mesh: with_color = the buffer carries an instance colour (stand-ins), with_custom =
## instance custom data (models: their placement tint, RINT-M2). A stand-in passes both (its custom data NO_CUSTOM).""")
sub(P, """			var node := _mmi(s, buf, n, true, bool(g["mirror"]))""", """			var node := _mmi(s, buf, n, true, bool(g["mirror"]), true)""")
sub(P, """					one.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
					var mm := _mmi(pd, one, 1, true, false)""", """					one.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
					one.append_array(PackedFloat32Array(NO_CUSTOM))
					var mm := _mmi(pd, one, 1, true, false, true)""")
sub(P, """				out.append(_mmi(s, one_c, 1, true, false))""", """				var one_cc := one_c.duplicate()
				one_cc.append_array(PackedFloat32Array(NO_CUSTOM))
				out.append(_mmi(s, one_cc, 1, true, false, true))""")
# the constant, next to the other constants of the builder: find a good anchor
t = open(W + P, encoding="utf-8").read()
anchor = "const SHADOW_KEEP_M := 40.0"
i = t.index("\n", t.index(anchor))
const = """
## RINT-M2: the custom data of a stand-in (no tint there: its tint is the instance colour). Godot's Compatibility
## renderer reads INSTANCE_CUSTOM of a MultiMesh with colours but without custom data from the bytes behind the colour
## (measured: (0, 1, 0, 1) – a bright green tint in billboard/vpbr/baked/leaves); with custom data a = 0 the shaders
## leave the albedo as it is. A MultiMesh with neither reads (0, 0, 0, 0), a MeshInstance3D 0 as well.
const NO_CUSTOM := [0.0, 0.0, 0.0, 0.0]"""
t = t[:i] + const + t[i:]
open(W + P, "w", encoding="utf-8").write(t)
print("ok")
