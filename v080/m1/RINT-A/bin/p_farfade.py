import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


FADE_DOC = '''// End of the sight (assembly of M1): beyond the end of the depth fog (ce_fog_range.y = the visibility) a prop is
// pure fog colour – a pale silhouette standing in front of the backdrop's own hazy silhouettes (the "bright
// diamonds" at the horizon of S1: impostors of far trees). It fades out with an ordered dither from 0.85 to 1.0 of
// the fog end instead, as Arcade's scenery sprites fade at the end of the sight.
'''
FADE_CODE = '''	float far_keep = 1.0 - smoothstep(ce_fog_range.y * 0.85, ce_fog_range.y, length(VERTEX));
	if (far_keep < 0.999 && fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910))) >= far_keep) {
		discard;
	}
'''

p = 'assets/shaders/modern/billboard.gdshader'
rep(p, '''// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;''', FADE_DOC + '''// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;''')
rep(p, '''global uniform vec2 ce_headlight;
''', '''global uniform vec2 ce_headlight;
global uniform vec2 ce_fog_range;
''')
rep(p, '''	vec4 t = texture(tex, uv_rect.xy + UV * uv_rect.zw);
	if (t.a < scissor || (t.a < shadow_cut && max(t.r, max(t.g, t.b)) < 0.1)) {
		discard;
	}
''', '''	vec4 t = texture(tex, uv_rect.xy + UV * uv_rect.zw);
	if (t.a < scissor || (t.a < shadow_cut && max(t.r, max(t.g, t.b)) < 0.1)) {
		discard;
	}
''' + FADE_CODE)

p = 'assets/shaders/modern/leaves.gdshader'
rep(p, '''// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;''', FADE_DOC + '''// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;''')
rep(p, '''global uniform vec4 ce_wind;
global uniform float ce_time;
''', '''global uniform vec4 ce_wind;
global uniform float ce_time;
global uniform vec2 ce_fog_range;
''')
rep(p, '''	vec4 t = texture(leaf_tex, UV);
	if (t.a < scissor) {
		discard;
	}
''', '''	vec4 t = texture(leaf_tex, UV);
	if (t.a < scissor) {
		discard;
	}
''' + FADE_CODE)
print('ok')
