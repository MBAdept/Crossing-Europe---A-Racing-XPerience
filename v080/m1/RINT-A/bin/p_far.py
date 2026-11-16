import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:60])
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'assets/shaders/modern/far_ground.gdshader'
rep(p, '''//   debug_flat   1: flat signal colours instead of the ground (--gfx-debug=far: cyan plane, yellow rim – the terrain
//                cover check counts them)
''', '''//   debug_flat   1: flat signal colours instead of the ground (--gfx-debug=far: cyan plane, yellow rim – the terrain
//                cover check counts them)
// Light pools and the player's low beam as on the terrain (inc/pools.gdshaderinc, inc/headlight.gdshaderinc, grass
// reflection 0.45): where the plane shows through a gap of the ribbons near the car it is lit like the ground
// around it. The sectors are on render layer 2 like road and terrain; the material is registered with
// ModernRenderer.add_pool_material().
''')
rep(p, '''#include "res://assets/shaders/modern/inc/ground.gdshaderinc"
''', '''#include "res://assets/shaders/modern/inc/pools.gdshaderinc"
#include "res://assets/shaders/modern/inc/headlight.gdshaderinc"
#include "res://assets/shaders/modern/inc/ground.gdshaderinc"
''')
rep(p, '''	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	if (debug_flat > 0.5) {''', '''	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	EMISSION = ce_pools_encode(ce_pools_to_lin(ALBEDO) * (ce_pools(v_world) * 0.45 + ce_headlight_light(v_world, 0.45)));
	if (debug_flat > 0.5) {''')

p = 'scripts/race3d/layers/far_ground.gd'
rep(p, '''	if flags is Array and (flags as Array).has("far"):
		material.set_shader_parameter("debug_flat", 1.0)
''', '''	if flags is Array and (flags as Array).has("far"):
		material.set_shader_parameter("debug_flat", 1.0)
	if renderer.has_method(&"add_pool_material"):
		renderer.call(&"add_pool_material", material)      # light pools and the low beam like the terrain
''')
rep(p, '''		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.y = TAU * float(i) / float(SECTORS)''', '''		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = GROUND_LAYERS
		mi.rotation.y = TAU * float(i) / float(SECTORS)''')
print('ok')
