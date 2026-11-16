def patch(p, pairs):
    s = open(p, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (p, s.count(old), old[:70])
        s = s.replace(old, new)
    open(p, 'w', encoding='utf-8').write(s)


patch('assets/shaders/modern/inc/pools.gdshaderinc', [
    ('''//   pool_count     number of entries in use (0 .. 22)
''', '''//   pool_count     number of entries in use (0 .. 22)
//   pool_ambient   DISPLAY value of the ambient light as Arcade knows it (palette.ambient, inside a tunnel the
//                  tunnel's) – what ce_pools_display_light() adds light to
'''),
    ('''uniform int pool_count = 0;
''', '''uniform int pool_count = 0;
uniform vec3 pool_ambient = vec3(1.0);
'''),
    ('''// The renderer's sRGB -> linear for ALBEDO and EMISSION values …''', '''// Arcade adds light in display values: a surface shows albedo * (ambient + l). The linear light that brightens a
// surface lit by the ambient light of the frame by the display value l (tinted): (ambient + l)^2.2 - ambient^2.2.
// Exact at the bright end; in a dark night a few percent above Arcade (measured, docs/renderer-modern.md).
vec3 ce_pools_display_light(float l, vec3 tint) {
	return pow(pool_ambient + l * tint, vec3(2.2)) - pow(pool_ambient, vec3(2.2));
}

// The renderer's sRGB -> linear for ALBEDO and EMISSION values …'''),
])
patch('assets/shaders/modern/inc/headlight.gdshaderinc', [
    ('''// Use:   #include "res://assets/shaders/modern/inc/headlight.gdshaderinc"
//        … EMISSION = ce_pools_encode(ce_pools_to_lin(ALBEDO) * (ce_pools(v_world) + ce_headlight_light(v_world, 1.0)));
// (ce_pools_encode / ce_pools_to_lin: inc/pools.gdshaderinc.) v_world = origin-relative world position.''',
     '''// Use:   #include "res://assets/shaders/modern/inc/pools.gdshaderinc"       (first: this file builds on it)
//        #include "res://assets/shaders/modern/inc/headlight.gdshaderinc"
//        … EMISSION = ce_pools_encode(ce_pools_to_lin(ALBEDO) * (ce_pools(v_world) + ce_headlight_light(v_world, 1.0)));
// v_world = origin-relative world position.'''),
    ('''//   ce_headlight       x = range in metres, y = intensity: the DISPLAY value Arcade adds at the hot spot
//                      (render.headlight_intensity × the palette's lights; 0 = off)
//   ce_ambient         linear ambient light value (environment rig)
''', '''//   ce_headlight       x = range in metres, y = intensity: the DISPLAY value Arcade adds at the hot spot
//                      (render.headlight_intensity × the palette's lights; 0 = off)
'''),
    ('''// (albedo × (ambient + l)); here the linear light that does the same on top of ce_ambient is returned, so the cone
// has Arcade's size and falloff at every hour. `reflect` scales l: 1 for asphalt, more for retro-reflective paint,
// less for grass.''', '''// (albedo × (ambient + l)); here the linear light that does the same is returned (ce_pools_display_light, with the
// material uniform pool_ambient of inc/pools.gdshaderinc), so the cone has Arcade's size and falloff at every hour.
// `reflect` scales l: Arcade's factors are 0.9 for asphalt, 1.6 for retro-reflective paint, 0.45 for grass.'''),
    ('''global uniform vec2 ce_headlight;
global uniform vec4 ce_ambient;
''', '''global uniform vec2 ce_headlight;
'''),
    ('''	vec3 a = pow(max(ce_ambient.rgb, vec3(0.0)), vec3(0.4545));
	return pow(a + l * vec3(1.0, 0.93, 0.8), vec3(2.2)) - ce_ambient.rgb;
''', '''	return ce_pools_display_light(l, vec3(1.0, 0.93, 0.8));
'''),
])
patch('scripts/race3d/environment_rig.gd', [
    ('''	return {"to_sun": to_sun, "sun": sun_lin, "ambient": amb_lin, "share": share, "moon": moon, "ref": ref,''',
     '''	return {"to_sun": to_sun, "sun": sun_lin, "ambient": amb_lin, "share": share, "moon": moon, "ref": ref, "display": Color(p.r, p.g, p.b),'''),
    ('''## "ambient": linear ambient light value (Color), "share": directed part of the display value on level ground,''',
     '''## "ambient": linear ambient light value (Color), "display": the palette's ambient as Arcade uses it (display
## factors, blended with the tunnel's), "share": directed part of the display value on level ground,'''),
])
patch('scripts/race3d/layers/lights.gd', [
    ('''	var tunnel01 := 1.0 if bool(view.get("camera_in_tunnel", false)) else 0.0
	var ambient := Color(1.0, 1.0, 1.0)
	if env != null:
		var st: Variant = env.get("state")
		if st is Dictionary and not (st as Dictionary).is_empty():
			tunnel01 = float((st as Dictionary).get("tunnel01", tunnel01))
			ambient = (st as Dictionary).get("ambient", ambient)
''', '''	var tunnel01 := 1.0 if bool(view.get("camera_in_tunnel", false)) else 0.0
	# the ambient light as Arcade knows it (display factors): what pools and cones add their light to
	var ambient: Color = Palette.TUNNEL_AMBIENT if tunnel01 > 0.5 else pal.get("ambient", Color.WHITE)
	if env != null:
		var st: Variant = env.get("state")
		if st is Dictionary and not (st as Dictionary).is_empty():
			tunnel01 = float((st as Dictionary).get("tunnel01", tunnel01))
			ambient = (st as Dictionary).get("display", ambient)
	_ambient = Vector3(ambient.r, ambient.g, ambient.b)
'''),
    ('''var _beam := 0.0                    ## intensity of the player's cone this frame (display value)''',
     '''var _beam := 0.0                    ## intensity of the player's cone this frame (display value)
var _ambient := Vector3.ONE         ## display value of the ambient light of this frame (uniform pool_ambient)
var _ambient_sent := Vector3(-1.0, -1.0, -1.0)'''),
    ('''	if _pool_count == 0 and _pools_sent == 0:
		return
	var mats: Array = _renderer.call(&"pool_materials")
	for m: Variant in mats:
		var mat := m as ShaderMaterial
		if mat == null:
			continue
		if _pool_count > 0:''', '''	var lit := _pool_count > 0 or _beam > 0.001
	var mats: Array = _renderer.call(&"pool_materials")
	if lit and (not _ambient.is_equal_approx(_ambient_sent) or mats.size() != _mats_sent):
		_ambient_sent = _ambient
		for m: Variant in mats:
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("pool_ambient", _ambient)
	_mats_sent = mats.size()
	if _pool_count == 0 and _pools_sent == 0:
		return
	for m: Variant in mats:
		var mat := m as ShaderMaterial
		if mat == null:
			continue
		if _pool_count > 0:'''),
    ('''var _pools_sent := 0
''', '''var _pools_sent := 0
var _mats_sent := 0
'''),
    ('''## Linear light that adds the display value `level` (tinted with `colour`) to a surface lit by the linear ambient
## light `ambient` – Arcade adds light in display values (albedo × (ambient + level)).
static func display_to_light(level: float, colour: Color, ambient: Color) -> Color:
	var out := Color.BLACK
	for ch in 3:
		var a := pow(maxf(ambient[ch], 0.0), 0.4545)
		out[ch] = maxf(pow(a + level * colour[ch], 2.2) - ambient[ch], 0.0)
	return out''', '''## Linear light that brightens a surface by the display value `level` (tinted with `colour`) on top of the ambient
## light `ambient` (display factors, as Arcade knows it) – Arcade adds light in display values
## (albedo × (ambient + level)). The law of ce_pools_display_light() in inc/pools.gdshaderinc.
static func display_to_light(level: float, colour: Color, ambient: Color) -> Color:
	var out := Color.BLACK
	for ch in 3:
		var a := maxf(ambient[ch], 0.0)
		out[ch] = maxf(pow(a + level * colour[ch], 2.2) - pow(a, 2.2), 0.0)
	return out'''),
])
print("ok")
