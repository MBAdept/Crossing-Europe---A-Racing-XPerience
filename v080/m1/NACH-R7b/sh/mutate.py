#!/usr/bin/env python3
# NACH-R7b: puts the two old R7b defects back into landmark.gdshader (in the worktree, never committed):
#   B01  light layer mixed in linear values (R7b's CE_PICTURE mix)
#   B02  signed projection scale in the glow size (no abs())
# usage: mutate.py <shader path>
import sys

p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old_b01 = ("\tvec3 disp = mix(min(d, vec3(1.0)), min(l.rgb, vec3(1.0)), wl);\n"
           "\tvec3 col = pow((disp + 0.055) / 1.055, vec3(2.4)) + to_lin(base) * headlight_color * v_head * (1.0 - wl);\n")
new_b01 = ("\tvec3 x = pow((min(d, vec3(1.0)) + 0.055) / 1.055, vec3(2.4)) + to_lin(base) * headlight_color * v_head;\n"
           "\tvec3 lit = pow((min(l.rgb, vec3(1.0)) + 0.055) / 1.055, vec3(2.4));\n"
           "\tvec3 col = mix(x, lit, wl);\n")
old_b02 = "float px_per_m = abs(PROJECTION_MATRIX[1][1]) * viewport_h * 0.5 / depth;"
new_b02 = "float px_per_m = PROJECTION_MATRIX[1][1] * viewport_h * 0.5 / depth;"
assert s.count(old_b01) == 1, "B01 anchor not found"
assert s.count(old_b02) == 1, "B02 anchor not found"
s = s.replace(old_b01, new_b01).replace(old_b02, new_b02)
open(p, "w", encoding="utf-8").write(s)
print("mutiert: B01 + B02")
