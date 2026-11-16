W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)

P = "scripts/race3d/builders/props.gd"
sub(P, """	var buf: PackedFloat32Array = g["buf"]
	_put(buf, mirror_x(tr) if flipped else tr)
	if not is_model:
		buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
""", """	var buf: PackedFloat32Array = g["buf"]
	_put(buf, mirror_x(tr) if flipped else tr)
	# the placement tint (tint × fallback_tint, white without one): a stand-in carries it as its instance colour, a model
	# as its instance custom data (r, g, b, 1) – RINT-M2 (A-19): baked, vpbr_static, leaves and billboard multiply the
	# albedo by it as Arcade multiplies the sprite; never an instance uniform (the global shader buffer, A-19)
	buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
""")
# commit: model nodes and casters with custom data
sub(P, """					var node := _mmi(mp, buf, n, false, bool(g["mirror"]))
					if bool(g.get("landmark", false)):""", """					var node := _mmi(mp, buf, n, false, bool(g["mirror"]), true)
					if bool(g.get("landmark", false)):""")
sub(P, """					var node := _mmi(mp, buf, n, false, bool(g["mirror"]))
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY""", """					var node := _mmi(mp, buf, n, false, bool(g["mirror"]), true)
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY""")
# warm-up: the models with the same buffer layout as commit() draws them
sub(P, """						var node := _mmi(part, one, 1, false, false)""", """						var node := _mmi(part, one_c, 1, false, false, true)""")
# _mmi
sub(P, """## A MultiMeshInstance3D for one mesh: with_color = the buffer carries an instance colour (stand-ins).
static func _mmi(part: Dictionary, buf: PackedFloat32Array, n: int, with_color: bool, mirrored: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = with_color
""", """## A MultiMeshInstance3D for one mesh: with_color = the buffer carries an instance colour (stand-ins), with_custom =
## instance custom data (models: their placement tint, RINT-M2).
static func _mmi(part: Dictionary, buf: PackedFloat32Array, n: int, with_color: bool, mirrored: bool,
		with_custom: bool = false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = with_color
	mm.use_custom_data = with_custom
""")
sub(P, """		var stride := 16 if with_color else 12
		for i in n:
			var o := i * stride
			var t := Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
				Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			mm.set_instance_transform(i, t * own)
""", """		var stride := 12 + (4 if with_color else 0) + (4 if with_custom else 0)
		for i in n:
			var o := i * stride
			var t := Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
				Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			mm.set_instance_transform(i, t * own)
			if with_color:
				mm.set_instance_color(i, Color(buf[o + 12], buf[o + 13], buf[o + 14], buf[o + 15]))
			if with_custom:
				var c := o + (16 if with_color else 12)
				mm.set_instance_custom_data(i, Color(buf[c], buf[c + 1], buf[c + 2], buf[c + 3]))
""")

# --- shaders
V = "assets/shaders/modern/vpbr.gdshader"
sub(V, """void vertex() {
	if (COLOR.a > 0.8 && COLOR.a < 0.95) {""", """void vertex() {
	// RINT-M2 (A-19): the placement tint of a prop model (MultiMesh custom data r, g, b, 1 – builders/props.gd); white
	// for everything else (a vehicle is no MultiMesh: INSTANCE_CUSTOM is 0 there)
	v_tint = INSTANCE_CUSTOM.a > 0.5 ? INSTANCE_CUSTOM.rgb : vec3(1.0);
	if (COLOR.a > 0.8 && COLOR.a < 0.95) {""")
sub(V, """	coat *= coat_strength * gloss;
	if (coat > 0.0) {""", """	if (!lamp) {
		alb *= v_tint;   // RINT-M2 (A-19): Arcade multiplies the sprite by the placement tint; lamps keep their colour
	}
	coat *= coat_strength * gloss;
	if (coat > 0.0) {""")
import re
t = open(W + V, encoding="utf-8").read()
m = re.search(r"\nvarying [^\n]*\n", t)
assert m
t = t[:m.start()] + "\nvarying vec3 v_tint;     // placement tint of a prop model (RINT-M2, A-19)" + t[m.start():]
open(W + V, "w", encoding="utf-8").write(t)

B = "assets/shaders/modern/baked.gdshader"
sub(B, """#include "res://assets/shaders/modern/inc/fog_law.gdshaderinc"

void fragment() {""", """#include "res://assets/shaders/modern/inc/fog_law.gdshaderinc"

// RINT-M2 (A-19): the placement tint of the model (MultiMesh custom data r, g, b, 1 – builders/props.gd); white without
varying vec3 v_tint;

void vertex() {
	v_tint = INSTANCE_CUSTOM.a > 0.5 ? INSTANCE_CUSTOM.rgb : vec3(1.0);
}

void fragment() {""")
sub(B, """	vec4 a = texture(albedo_tex, UV);
#ifdef CE_CUTOUT""", """	vec4 a = texture(albedo_tex, UV);
	a.rgb *= v_tint;    // Arcade multiplies the sprite by the placement tint (sRGB, as the sprite)
#ifdef CE_CUTOUT""")

L = "assets/shaders/modern/leaves.gdshader"
sub(L, """varying float v_bright;
""", """varying float v_bright;
varying vec3 v_tint;     // RINT-M2 (A-19): placement tint (MultiMesh custom data r, g, b, 1); white without
""")
sub(L, """	v_bright = COLOR.a;
""", """	v_bright = COLOR.a;
	v_tint = INSTANCE_CUSTOM.a > 0.5 ? INSTANCE_CUSTOM.rgb : vec3(1.0);
""")
sub(L, """	ALBEDO = t.rgb * v_bright;        // sRGB-encoded, as the Compatibility renderer expects it""",
"""	ALBEDO = t.rgb * v_bright * v_tint;        // sRGB-encoded, as the Compatibility renderer expects it""")
print("ok")
