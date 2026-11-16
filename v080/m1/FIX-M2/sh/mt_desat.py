#!/usr/bin/env python3
"""FIX-M2: put the B-06 player-paint desaturation (commit c908dcf) into the merged scratch tree mt (R4's versions of
modern_materials.gd and layers/vehicles.gd). usage: mt_desat.py <value>"""
import re
import sys

MT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2/mt"
val = float(sys.argv[1])
p = MT + "/scripts/race3d/modern_materials.gd"
s = open(p).read()
if "VEHICLE_PLAYER_DESAT" not in s:
    s = s.replace("const VEHICLE_PLAYER_FILL := 0.7\n", "const VEHICLE_PLAYER_FILL := 0.7\nconst VEHICLE_PLAYER_DESAT := %.3f\n" % val, 1)
    s = s.replace('''## Clears and forgets the shared instance (leaving the mode "Modern", after ModelDB.release_all()).''',
                  '''static func player_paint(paint: Dictionary) -> Dictionary:
	var out := paint.duplicate()
	for k: String in ["paint", "paint2", "paint3"]:
		if out.has(k) and Color.html_is_valid(str(out[k])):
			var c := Color(str(out[k]))
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			out[k] = "#" + c.lerp(Color(l, l, l), VEHICLE_PLAYER_DESAT).to_html(false)
	return out


## Clears and forgets the shared instance (leaving the mode "Modern", after ModelDB.release_all()).''', 1)
else:
    s = re.sub(r"const VEHICLE_PLAYER_DESAT := [0-9.]+", "const VEHICLE_PLAYER_DESAT := %.3f" % val, s)
open(p, "w").write(s)
p = MT + "/scripts/race3d/layers/vehicles.gd"
s = open(p).read()
if "player_paint" not in s:
    old = '''		if gloss < 1.0:
			gi.set_instance_shader_parameter(&"gloss", gloss)
'''
    assert old in s
    s = s.replace(old, old + '''	if fill > 0.0:
		ModelFactory.apply_paint(n, ModernMaterials.player_paint(ModelDB.resolve(car.set_id).get("paint", {})))
''', 1)
    open(p, "w").write(s)
print("mt desat", val)
