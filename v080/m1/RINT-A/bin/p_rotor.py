import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:70])
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'assets/shaders/modern/vpbr.gdshader'
rep(p, '''//   COLOR.a    paint code: 1.0 fixed colour, 0.0 paint, 0.25 paint2, 0.5 paint3
''', '''//   COLOR.a    paint code: 1.0 fixed colour, 0.0 paint, 0.25 paint2, 0.5 paint3; 0.875 a rotor part (fixed colour
//              that turns about the hub: UV2.y = hub height / 128 m, docs/modelle.md §14 – wind turbine, windmill)
''')
rep(p, '''uniform float flake_near_m = 14.0;            // flakes fade out towards this distance (they would only shimmer)
''', '''uniform float flake_near_m = 14.0;            // flakes fade out towards this distance (they would only shimmer)
// rotors (paint code 0.875): they turn about the model's Z axis through the hub, angle = ce_time x rotor_speed plus a
// phase from the position of the instance – every turbine of a wind farm at its own angle. ce_time is view time:
// the rotors stand still with the paused game.
uniform float rotor_speed = 1.35;             // rad/s
''')
rep(p, '''global uniform float ce_night;
global uniform vec4 ce_ambient;               // linear ambient light (ModernMaterials.light_value), for `fill`
''', '''global uniform float ce_night;
global uniform vec4 ce_ambient;               // linear ambient light (ModernMaterials.light_value), for `fill`
global uniform float ce_time;
''')
rep(p, '''void vertex() {
	v_code = COLOR.a;''', '''void vertex() {
	if (COLOR.a > 0.8 && COLOR.a < 0.95) {
		// rotor part: turn VERTEX and NORMAL about the hub (0, UV2.y x 128 m) in the model's XY plane
		float hub = UV2.y * 128.0;
		vec3 wp0 = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float ang = ce_time * rotor_speed + wp0.x * 0.37 + wp0.z * 0.23;
		float c = cos(ang);
		float s = sin(ang);
		vec2 q = VERTEX.xy - vec2(0.0, hub);
		VERTEX.xy = vec2(c * q.x - s * q.y, s * q.x + c * q.y) + vec2(0.0, hub);
		NORMAL.xy = vec2(c * NORMAL.x - s * NORMAL.y, s * NORMAL.x + c * NORMAL.y);
	}
	v_code = COLOR.a;''')
print('ok')
