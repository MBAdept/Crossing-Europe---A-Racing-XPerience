#!/usr/bin/env python3
"""FIX-R7b: apply named mutations to the landmark shader of a tree (to prove the render checks catch them).
   mutate.py <tree> <M...>   M16 flood off in CE_ATLAS, M17 flood off in CE_PICTURE, B01 linear light-layer mix,
   B02 signed projection scale in CE_GLOW"""
import sys
tree = sys.argv[1]
path = tree + '/assets/shaders/modern/landmark.gdshader'
s = open(path).read()
MUT = {
    'M16': [('ALBEDO = alb * (1.0 - flood) * wb;', 'ALBEDO = alb * wb;'),
            (' + to_lin(min(alb * flood_color * flood, vec3(1.0))) * wb;', ';')],
    'M17': [('\td = mix(d, base * flood_color, flood);\n', '\n')],
    'B01': [('vec3 disp = mix(min(d, vec3(1.0)), min(l.rgb, vec3(1.0)), wl);\n\tvec3 col = pow((disp + 0.055) / 1.055, vec3(2.4)) + to_lin(base) * headlight_color * v_head * (1.0 - wl);',
             'vec3 col = mix(pow((min(d, vec3(1.0)) + 0.055) / 1.055, vec3(2.4)) + to_lin(base) * headlight_color * v_head, pow((min(l.rgb, vec3(1.0)) + 0.055) / 1.055, vec3(2.4)), wl);')],
    'B02': [('abs(PROJECTION_MATRIX[1][1])', 'PROJECTION_MATRIX[1][1]')],
}
for m in sys.argv[2:]:
    for old, new in MUT[m]:
        if old not in s:
            sys.exit('mutation %s: text not found: %r' % (m, old[:60]))
        s = s.replace(old, new)
    print('applied', m)
open(path, 'w').write(s)
