import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'assets/shaders/modern/vpbr.gdshader'
rep(p, '''// - instance uniform sun = 0 - env_tunnel) - so the paint reflects the sky in every preset and with or without a
// Sky resource on the Environment. Reflections go into EMISSION (not shadowed, fogged like the rest).''', '''// - instance uniform sun = 0 - env_tunnel) - so the paint reflects the sky in every preset and with or without a
// Sky resource on the Environment. Reflections go into EMISSION (not shadowed, fogged like the rest).
// ONE reflection source (assembly of M1, measured with the player car at noon and at dusk, docs/renderer-modern.md
// §12): while the analytic sky is on (env_energy > 0 – the race), the engine's own reflection of the Environment's
// Sky is kept out: SPECULAR 0 and METALLIC 0 for the engine, the diffuse share of a metal taken out of ALBEDO
// (exact in linear light), and light() keeps the true f0 through varyings. Without it (env_energy 0: showroom,
// contact sheet, the neutral checks) the engine reflects its Sky as before.''')
rep(p, '''varying vec3 v_obj;
varying float v_flake_k;''', '''varying vec3 v_obj;
varying float v_flake_k;
varying vec3 v_f0;                    // f0 of the engine's lighting model for light() (linear), whatever ALBEDO says
varying float v_metal;
varying vec3 v_alb_lin;               // linear albedo for the flakes''')
rep(p, '''	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;''', '''	v_alb_lin = to_lin(alb);
	v_f0 = mix(vec3(0.04), v_alb_lin, metal);
	v_metal = metal;
	ROUGHNESS = rough;
	if (env_energy > 0.0) {
		// the analytic sky is the only reflection: no engine reflection (F0 0), a metal's missing diffuse share
		// taken out of ALBEDO in linear light (the engine multiplies the diffuse light by albedo x (1 - metallic))
		ALBEDO = encode(v_alb_lin * (1.0 - metal));
		METALLIC = 0.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = alb;
		METALLIC = metal;
		SPECULAR = 0.5;
	}''')
rep(p, '''	vec3 f0 = mix(vec3(0.04), ALBEDO, METALLIC);
	float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), METALLIC, 1.0);''', '''	vec3 f0 = v_f0;
	float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), v_metal, 1.0);''')
rep(p, '''			SPECULAR_LIGHT += lc * ndl * glint * flake_strength * v_flake_k * (v_metal_paint - 0.3) * ALBEDO;''',
    '''			SPECULAR_LIGHT += lc * ndl * glint * flake_strength * v_flake_k * (v_metal_paint - 0.3) * v_alb_lin;''')

p = 'assets/shaders/modern/glass.gdshader'
rep(p, '''// R3 (wave 1): the mirror image of the environment for the reflection above. The Environment of the race has
// no Sky in every preset (the reflection source of D7 is optional), so the sky the pane mirrors is the analytic
// one of vpbr.gdshader (same uniforms, set by the vehicle layer from the palette), weighted with the look's own
// Fresnel term and `mirror`, added in EMISSION (premultiplied: in full, whatever the opacity). env_energy 0 (the
// default) = only the engine's reflection, as before; the vehicle layer sets the race value.''', '''// R3 (wave 1): the mirror image of the environment for the reflection above. The Environment of the race has
// no Sky in every preset (the reflection source of D7 is optional), so the sky the pane mirrors is the analytic
// one of vpbr.gdshader (same uniforms, set by the vehicle layer from the palette), weighted with the look's own
// Fresnel term and `mirror`, added in EMISSION (premultiplied: in full, whatever the opacity). env_energy 0 (the
// default) = only the engine's reflection, as before; the vehicle layer sets the race value. ONE source (assembly
// of M1, as in vpbr.gdshader): with env_energy > 0 the engine's reflection of the Sky is kept out (SPECULAR 0).''')
rep(p, '''	SPECULAR = mirror * mix(0.25, 1.0, smoothstep(0.08, 0.3, COLOR.a));''', '''	SPECULAR = env_energy > 0.0 ? 0.0 : mirror * mix(0.25, 1.0, smoothstep(0.08, 0.3, COLOR.a));''')
print('ok')
