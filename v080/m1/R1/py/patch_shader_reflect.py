p = 'assets/shaders/modern/road.gdshader'
s = open(p, encoding='utf-8').read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:70])
    s = s.replace(old, new)


rep('''uniform float paint_reflect = 1.8;                 // low beam on paint against asphalt (Arcade: 1.6 / 0.9)''',
    '''uniform float asphalt_reflect = 0.9;               // how much of the low beam and the light pools a surface throws back
uniform float paint_reflect = 1.6;                 // (Arcade's factors: asphalt 0.9, lines 1.6, hatch and crosswalk 1.4, checker 1.2)''')
rep('''		vec3 surf = mix(asph, line, paint * worn);
		float gloss = paint * worn;
		reflect = mix(1.0, paint_reflect, gloss);''', '''		vec3 surf = mix(asph, line, paint * worn);
		float gloss = paint * worn;
		reflect = mix(asphalt_reflect, paint_reflect, gloss);''')
rep('''			reflect = mix(reflect, mix(0.3, 1.55, chk), on);''', '''			reflect = mix(reflect, 1.2, on);''')
rep('''		vec3 side = col_paved;
		float side_reflect = 0.85;''', '''		vec3 side = col_paved;
		float side_reflect = 1.0;''')
rep('''			side = mix(side, col_snow, 0.9 * snow);
			side_reflect = 0.6;''', '''			side = mix(side, col_snow, 0.9 * snow);
			side_reflect = left ? 0.6 : 0.8;''')
rep('''			side_reflect = mix(0.5, 0.85, paved);''', '''			side_reflect = left ? mix(0.45, 1.0, paved) : 0.8;''')
rep('''		base *= 1.0 - 0.15 * wet;
		reflect = 0.8;''', '''		base *= 1.0 - 0.15 * wet;
		reflect = 1.0;''')
rep('''		base = mix(base, col_snow, (kind == 2 ? 0.6 : 0.2) * snow);
		reflect = 0.9;''', '''		base = mix(base, col_snow, (kind == 2 ? 0.6 : 0.2) * snow);
		reflect = 1.0;''')
rep('''	vec3 extra = ce_pools(v_world) + ce_headlight_light(v_world, reflect);''',
    '''	vec3 extra = ce_pools(v_world) * reflect + ce_headlight_light(v_world, reflect);''')
open(p, 'w', encoding='utf-8').write(s)
print("ok")
