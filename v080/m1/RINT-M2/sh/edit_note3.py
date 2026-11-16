import sys
W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:60], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)

# vpbr: uniform + light()
sub("assets/shaders/modern/vpbr.gdshader",
"uniform float fill_tunnel = 1.0;\n",
"""uniform float fill_tunnel = 1.0;
// RINT-M2 (A-20): share of the specular lobes of a POSITIONAL light that shines from next to the eye (1 = neutral, the
// race look sets 0). The player's low beam sits 0.66 m above the road on the car's nose below a camera 9 m behind it:
// every face that looks back at the camera sees it under the half vector of its own normal, and the sharp lobes of a
// flat glossy face (a truck's rear doors, a bumper, a number plate, a boot lid) lit the whole face white (FIX-M2 B-05:
// red truck rear at 60 m, 22:00, mean luminance 152 against Arcade's 42). Arcade lights what stands in its cone only
// diffusely. The material takes these lobes out, the light keeps its specular for everything else; the angle between
// the directions to the light and to the eye decides (eye_lamp_cos: full lobes below x, none above y – the low beam is
// inside y from about 20 m in front of the camera on, a street lamp overhead stays far outside).
uniform float eye_lamp_spec = 1.0;
uniform vec2 eye_lamp_cos = vec2(0.90, 0.97);
""")
sub("assets/shaders/modern/vpbr.gdshader",
"""	float cs = LIGHT_IS_DIRECTIONAL ? coat_sun : 1.0;
""",
"""	// … and of a positional light next to the eye the share eye_lamp_spec (RINT-M2, A-20)
	float cs = LIGHT_IS_DIRECTIONAL ? coat_sun
		: mix(1.0, eye_lamp_spec, smoothstep(eye_lamp_cos.x, eye_lamp_cos.y, dot(LIGHT, VIEW)));
""")
# glass
sub("assets/shaders/modern/glass.gdshader",
"uniform float sun_spec = 1.0;\n",
"""uniform float sun_spec = 1.0;
// RINT-M2 (A-20): share of the lobe of a positional light next to the eye – the player's low beam (vpbr.gdshader
// eye_lamp_spec); neutral by default, the race look sets 0
uniform float eye_lamp_spec = 1.0;
uniform vec2 eye_lamp_cos = vec2(0.90, 0.97);
""")
sub("assets/shaders/modern/glass.gdshader",
"""	float ss = LIGHT_IS_DIRECTIONAL ? sun_spec : 1.0;
""",
"""	float ss = LIGHT_IS_DIRECTIONAL ? sun_spec
		: mix(1.0, eye_lamp_spec, smoothstep(eye_lamp_cos.x, eye_lamp_cos.y, dot(LIGHT, VIEW)));
""")
# look
sub("scripts/race3d/modern_materials.gd",
"""	["glass", "env_energy", 2.2], ["glass", "hemi_side", 0.72], ["glass", "hemi_down", 0.5]]
## Extra ambient""",
"""	["glass", "env_energy", 2.2], ["glass", "hemi_side", 0.72], ["glass", "hemi_down", 0.5],
	# RINT-M2 (A-20): no specular lobes of the player's low beam on vehicles and static models (they made flat glossy
	# faces white boxes, FIX-M2 B-05) – through the material; the light keeps its specular (layers/lights.gd)
	["vpbr", "eye_lamp_spec", 0.0], ["glass", "eye_lamp_spec", 0.0]]
## Extra ambient""")
sub("scripts/race3d/modern_materials.gd",
"""	["vpbr", "fill_sheen_tint", 0.0], ["vpbr", "fill_tunnel", 1.0], ["glass", "hemi_side", 1.0], ["glass", "hemi_down", 1.0]]""",
"""	["vpbr", "fill_sheen_tint", 0.0], ["vpbr", "fill_tunnel", 1.0], ["glass", "hemi_side", 1.0], ["glass", "hemi_down", 1.0],
	["vpbr", "eye_lamp_spec", 1.0], ["glass", "eye_lamp_spec", 1.0]]""")
# lights.gd
sub("scripts/race3d/layers/lights.gd",
"""## FIX-M2 (QA-M2-BILD B-05): no specular lobe from the low beam. The lamps sit next to the eye, so on every flat glossy
## face that looks back at the camera (a truck's rear doors, a bumper, a number plate, the clear coat of a boot lid) the
## half vector equals the normal over the whole face, and the sharp coat lobe turned it into a white glowing box:
## truck_red rear at 60 m mean luminance 107 against Arcade's 44 (22:00, measured); without the lobe 48. Arcade lights
## a car in its cone only diffusely. Retro-reflective tape (vpbr channel 15) and signs keep their own cone law.
const SPOT_SPECULAR := 0.0
""",
"""## Specular of the low beam: the engine's default, like the lamp omnis. FIX-M2 (QA-M2-BILD B-05) had set 0: the lamps
## sit next to the eye, so on every flat glossy face that looks back at the camera (a truck's rear doors, a bumper, a
## number plate, the clear coat of a boot lid) the half vector equals the normal over the whole face, and the sharp coat
## lobe turned it into a white glowing box (truck_red rear at 60 m mean luminance 107 against Arcade's 44, 22:00). Since
## RINT-M2 (A-20) the MATERIALS take the lobes of a light next to the eye out (vpbr/glass eye_lamp_spec in the race look,
## ModernMaterials.VEHICLE_LOOK) – not the light for everything. The ground never takes this light (GROUND_LAYERS): the
## road shows the beam through inc/headlight.gdshaderinc, the wet road its own sheen (road.gdshader).
const SPOT_SPECULAR := 0.5
""")
print("ok")
