import sys
wt = sys.argv[1]
p = wt + '/assets/shaders/modern/landmark.gdshader'
s = open(p).read()
old = '''	} else if (ch == 14) {
		emis = alb * flood_light * (w * lights);'''
new = '''	} else if (ch == 14) {
		// Arcade lays its floodlight over the hazed picture: the lit share keeps its light through the haze
		fl_keep = w * lights;
		emis = alb * flood_light * fl_keep;'''
assert old in s; s = s.replace(old, new)
old = '''	float la = 0.0;
	if (ch == 16) {'''
new = '''	float la = 0.0;
	float fl_keep = 0.0;
	if (ch == 16) {'''
assert old in s; s = s.replace(old, new)
old = '''	FOG = vec4(ce_fog_unshow(min(COLOR.rgb * tint * ce_fog_color.rgb * 1.15, vec3(1.0))), haze * (1.0 - la));'''
new = '''	FOG = vec4(ce_fog_unshow(min(COLOR.rgb * tint * ce_fog_color.rgb * 1.15, vec3(1.0))), haze * (1.0 - la) * (1.0 - fl_keep));'''
assert old in s; s = s.replace(old, new)
open(p, 'w').write(s)

p = wt + '/scripts/race3d/builders/landmarks.gd'
s = open(p).read()
# floodlight weights: about Arcade's warm overlay (1.0, 0.8, 0.5) at 0.3 over the facade
s = s.replace('''	kit.set_paint(wall, 0.85, 0.0, 14, 0.55)
	kit.box(Vector3(-32.0, 0.0, -44.0), Vector3(32.0, 30.0, 0.0))''', '''	kit.set_paint(wall, 0.85, 0.0, 14, 0.42)
	kit.box(Vector3(-32.0, 0.0, -44.0), Vector3(32.0, 30.0, 0.0))''')
old = '''	kit.set_paint(dome_d, 0.5, 0.3, -1, 0.0)
	kit.box(Vector3(-0.3, 74.0, dz - 0.3), Vector3(0.3, 80.0, dz + 0.3))
	if cross:
		kit.box(Vector3(-1.6, 77.75, dz - 0.25), Vector3(1.6, 78.25, dz + 0.25))'''
new = '''	kit.set_paint(dome_d, 0.5, 0.3, -1, 0.0)
	kit.box(Vector3(-0.3, 74.0, dz - 0.3), Vector3(0.3, 80.0, dz + 0.3))
	if cross:
		kit.box(Vector3(-1.6, 77.75, dz - 0.25), Vector3(1.6, 78.25, dz + 0.25))
	# Arcade's warm glow round the main dome at night (RoadRenderer._lm_domed: radius 16 m, alpha 0.4)
	kit.glow(Vector3(0.0, 56.0, dz), Color(1.0, 0.82, 0.5), 0.4, 16.0, 4.0, Vector4(0.0, 0.0, 0.0, 0.0))'''
assert old in s; s = s.replace(old, new)
open(p, 'w').write(s)
print("ok")
