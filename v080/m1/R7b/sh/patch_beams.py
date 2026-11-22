import sys
wt = sys.argv[1]
p = wt + '/assets/shaders/modern/landmark.gdshader'
s = open(p).read()
old = '''#elif defined(CE_GLOW)
varying float v_on;
#endif'''
new = '''#elif defined(CE_GLOW)
varying float v_on;
varying float v_beam;
#endif'''
assert old in s; s = s.replace(old, new)
old = '''#elif defined(CE_GLOW)
	// a camera-facing quad round the point, at least UV2.y pixels across, pulled towards the camera so that the
	// lamp's own geometry does not cut it
	vec4 c = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);'''
new = '''#elif defined(CE_GLOW)
	v_beam = 0.0;
	if (CUSTOM0.x > 2.5) {
		// a lighthouse beam (mode 3): a long flat quad from the lamp, turning about the vertical once in CUSTOM0.y
		// seconds (CUSTOM0.w = its phase), widening along its CUSTOM0.z metres to UV2.x; it faces the camera about
		// its own axis. UV.x = 0 at the lamp .. 1 at the tip, UV.y = -1 .. 1 across.
		float ang = ce_time * 6.2831853 / max(CUSTOM0.y, 0.01) + CUSTOM0.w;
		vec3 dir = normalize(vec3(cos(ang), -0.03, sin(ang)));
		vec3 cam_m = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
		vec3 side = cross(dir, normalize(cam_m - VERTEX));
		side = length(side) > 1.0e-3 ? normalize(side) : vec3(0.0, 1.0, 0.0);
		vec3 p = VERTEX + dir * (UV.x * CUSTOM0.z) + side * (UV.y * (0.4 + UV2.x * UV.x));
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(p, 1.0));
		// brighter while it sweeps across the view than when it points away (Arcade: 0.45 .. 1)
		v_on = mix(0.45, 1.0, 0.5 + 0.5 * dot(dir, normalize(cam_m - VERTEX)));
		v_beam = 1.0;
	} else {
	// a camera-facing quad round the point, at least UV2.y pixels across, pulled towards the camera so that the
	// lamp's own geometry does not cut it
	vec4 c = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);'''
assert old in s; s = s.replace(old, new)
old = '''		on = 0.35 + 0.65 * pow(max(cos(turn - 0.785398), 0.0), 24.0);
	}
	v_on = on;
#endif'''
new = '''		on = 0.35 + 0.65 * pow(max(cos(turn - 0.785398), 0.0), 24.0);
	}
	v_on = on;
	}
#endif'''
assert old in s; s = s.replace(old, new)
old = '''#elif defined(CE_GLOW)
	float r2 = dot(UV, UV);
	if (r2 > 1.0) {
		discard;
	}
	float fall = exp(-r2 * 4.0) + 0.6 * exp(-r2 * 40.0);'''
new = '''#elif defined(CE_GLOW)
	float fall;
	if (v_beam > 0.5) {
		float t = clamp(UV.x, 0.0, 1.0);
		fall = pow(1.0 - t, 1.6) * (1.0 - UV.y * UV.y) * smoothstep(0.0, 0.04, t);
	} else {
		float r2 = dot(UV, UV);
		if (r2 > 1.0) {
			discard;
		}
		fall = exp(-r2 * 4.0) + 0.6 * exp(-r2 * 40.0);
	}'''
assert old in s; s = s.replace(old, new)
old = '''//                phase s); drawn only at night'''
new = '''//                phase s); mode 3 = a lighthouse beam (see vertex()); drawn only at night'''
assert old in s; s = s.replace(old, new)
open(p, 'w').write(s)

p = wt + '/scripts/race3d/builders/landmarks.gd'
s = open(p).read()
old = '''	kit.glow(c + Vector3(0.0, 44.2, 0.0), Color(1.0, 0.95, 0.8), 1.0, 3.0, 4.0, Vector4(2.0, 15.0, 0.0, 0.0))'''
new = '''	kit.glow(c + Vector3(0.0, 44.2, 0.0), Color(1.0, 0.95, 0.8), 1.0, 3.0, 4.0, Vector4(2.0, 15.0, 0.0, 0.0))
	# Arcade's four beams (RoadRenderer.LIGHTHOUSE_BEAM_M 240 m, one revolution in LIGHTHOUSE_PERIOD_S 15 s)
	for i in 4:
		kit.beam(c + Vector3(0.0, 44.2, 0.0), Color(1.0, 0.96, 0.82), 0.22, 240.0 / kit.k, 15.0, float(i) * PI * 0.5)'''
assert old in s; s = s.replace(old, new)
old = '''	func tris() -> int:
		return _i.size() / 3'''
new = '''	## A lighthouse beam (CE_GLOW mode 3): from p, `length_m` long (reference metres), turning once in `period` s.
	func beam(p: Vector3, col: Color, strength: float, length_m: float, period: float, phase: float) -> void:
		_bp.append(p * k)
		_bc.append(Color(col.r, col.g, col.b, strength))
		_bm.append(Vector4(3.0, period, length_m * k, phase))

	func tris() -> int:
		return _i.size() / 3'''
assert old in s; s = s.replace(old, new)
old = '''	var _gm: Array[Vector4] = []
'''
new = '''	var _gm: Array[Vector4] = []
	# lighthouse beams: position, colour + strength, (3, period, length, phase)
	var _bp := PackedVector3Array()
	var _bc := PackedColorArray()
	var _bm: Array[Vector4] = []
'''
assert old in s; s = s.replace(old, new)
old = '''	func glow_mesh() -> ArrayMesh:
		if _gp.is_empty():
			return null'''
new = '''	func glow_mesh() -> ArrayMesh:
		if _gp.is_empty() and _bp.is_empty():
			return null'''
assert old in s; s = s.replace(old, new)
old = '''			idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
			lo = lo.min(_gp[g])
			hi = hi.max(_gp[g])'''
new = '''			idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
			lo = lo.min(_gp[g])
			hi = hi.max(_gp[g])
		for g in _bp.size():
			var b := v.size()
			var m: Vector4 = _bm[g]
			for corner: Vector2 in [Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
				v.append(_bp[g])
				uv.append(corner)
				uv2.append(Vector2(0.07 * m.z, 0.0))
				col.append(_bc[g])
				cu.append_array(PackedFloat32Array([m.x, m.y, m.z, m.w]))
			idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
			lo = lo.min(_bp[g] - Vector3.ONE * m.z)
			hi = hi.max(_bp[g] + Vector3.ONE * m.z)'''
assert old in s; s = s.replace(old, new)
old = '''		var lo := _gp[0]
		var hi := _gp[0]'''
new = '''		var lo := _gp[0] if not _gp.is_empty() else _bp[0]
		var hi := lo'''
assert old in s; s = s.replace(old, new)
open(p, 'w').write(s)
print("ok")
