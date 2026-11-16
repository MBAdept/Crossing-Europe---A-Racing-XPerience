from patchlib import patch

patch("assets/shaders/modern/billboard.gdshader", [
    ('''uniform float sun_part = 0.55;                // part of the sun that reaches an upright picture on average
uniform float night_energy = 1.5;

global uniform float ce_night;
global uniform vec4 ce_sun_color : source_color;
global uniform vec4 ce_ambient : source_color;
''', '''uniform float sun_min = 0.23;                 // part of the sun on the picture when the sun is behind it ...
uniform float sun_max = 1.03;                 // ... and when it shines from behind the camera
uniform float night_energy = 1.5;

global uniform float ce_night;
global uniform vec4 ce_sun_color : source_color;
global uniform vec4 ce_ambient : source_color;
global uniform vec3 ce_sun_dir;

varying float v_sun;
'''),
    ('''	vec3 wp = origin + cr * (VERTEX.x * sx) + vec3(0.0, VERTEX.y * sy, 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
''', '''	vec3 wp = origin + cr * (VERTEX.x * sx) + vec3(0.0, VERTEX.y * sy, 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	// how much of the sun falls on the side the camera sees (a lit model would show the same)
	float facing = dot(normalize(CAMERA_POSITION_WORLD - origin), normalize(ce_sun_dir)) * 0.5 + 0.5;
	v_sun = mix(sun_min, sun_max, facing);
'''),
    ('''	vec3 light = pow(pow(ce_ambient.rgb, vec3(2.2)) + pow(ce_sun_color.rgb, vec3(2.2)) * sun_part, vec3(0.4545));
	vec3 lit = t.rgb * min(light, vec3(1.3));
''', '''	vec3 light = pow(pow(ce_ambient.rgb, vec3(2.2)) + pow(ce_sun_color.rgb, vec3(2.2)) * v_sun, vec3(0.4545));
	vec3 lit = t.rgb * min(light, vec3(1.4));
'''),
])

patch("tools/blender/ce3d/veg3d.py", [
    ('''OPAQUE = 0.82            # part of a card (from its centre) that counts as silhouette
IMPOSTOR_PX = 256
''', '''OPAQUE = 0.82            # part of a card (from its centre) that counts as silhouette
IMPOSTOR_PX = 256
# The impostor picture is the albedo of the tree times this gain: measured against lod1 in the contact sheet
# (billboard.gdshader then lights it like the leaves shader lights the cards, for the sun in front, beside
# and behind the tree within about 10 %)
IMPOSTOR_GAIN = 1.9
'''),
    ('''        shade = nb.math("MULTIPLY_ADD", sep.outputs[2], 0.15, 0.85)        # 0.7 below .. 1.0 on top''',
     '''        shade = nb.math("MULTIPLY_ADD", sep.outputs[2], 0.15 * IMPOSTOR_GAIN, 0.85 * IMPOSTOR_GAIN)'''),
])
