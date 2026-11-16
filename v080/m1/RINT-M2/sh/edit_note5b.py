W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)
B = "assets/shaders/modern/billboard.gdshader"
sub(B, """varying float v_sun;
varying float v_head;
""", """varying float v_sun;
varying float v_head;
// RINT-M2 (A-19): the placement tint of a MODEL's impostor (MultiMesh custom data r, g, b, 1 – builders/props.gd) times
// COLOR (a stand-in's instance colour); white without either
varying vec3 v_tint;
""")
sub(B, """	vec3 cr = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));""",
"""	v_tint = INSTANCE_CUSTOM.a > 0.5 ? INSTANCE_CUSTOM.rgb : vec3(1.0);
	vec3 cr = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));""")
sub(B, """		vec3 base = mix(t.rgb * COLOR.rgb, vec3(0.75, 0.8, 0.84), 0.15 * clamp(ce_snow, 0.0, 1.0));""",
"""		vec3 tint = COLOR.rgb * v_tint;
		vec3 base = mix(t.rgb * tint, vec3(0.75, 0.8, 0.84), 0.15 * clamp(ce_snow, 0.0, 1.0));""")
sub(B, """			FOG = vec4(ce_fog_unshow(min(t.rgb * COLOR.rgb * ce_fog_color.rgb * 1.15, vec3(1.0))), haze);""",
"""			FOG = vec4(ce_fog_unshow(min(t.rgb * tint * ce_fog_color.rgb * 1.15, vec3(1.0))), haze);""")
sub(B, """			FOG = ce_arcade_fog(t.rgb * COLOR.rgb, dist, ce_fog_color, ce_fog_range);""",
"""			FOG = ce_arcade_fog(t.rgb * tint, dist, ce_fog_color, ce_fog_range);""")
print("ok")
