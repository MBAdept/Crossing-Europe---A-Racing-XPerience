#!/usr/bin/env python3
"""Prototype of the B2 fix (QA-R4, scratch copy only): the lamps and the low beam light only the diffuse part of the
wet road, not the mirrored sky. road.gdshader of the given tree is patched in place."""
import sys

p = sys.argv[1]
s = open(p, encoding="utf-8").read()


def rep(old, new):
    global s
    assert s.count(old) == 1, ("pattern", old[:60], s.count(old))
    s = s.replace(old, new)


rep("\tfloat reflect = 1.0;\n", "\tfloat reflect = 1.0;\n\tvec3 lit_base = vec3(-1.0);\n")
rep("\t\tasph *= 1.0 - 0.32 * wet;\n",
    "\t\tasph *= 1.0 - 0.32 * wet;\n\t\tvec3 asph_lit = asph;\n\t\tvec3 line_lit = line;\n")
rep("\t\t\tline = mix(line * (1.0 - 0.07 * wet), sky_k, mirror * 0.35);\n",
    "\t\t\tline = mix(line * (1.0 - 0.07 * wet), sky_k, mirror * 0.35);\n"
    "\t\t\tasph_lit *= 1.0 - mirror;\n\t\t\tline_lit *= (1.0 - 0.07 * wet) * (1.0 - mirror * 0.35);\n")
rep("\t\tvec3 surf = mix(asph, line, paint * worn);\n",
    "\t\tif (wet <= 0.0) {\n\t\t\tasph_lit = asph;\n\t\t\tline_lit = line;\n\t\t}\n"
    "\t\tvec3 surf = mix(asph, line, paint * worn);\n\t\tvec3 surf_lit = mix(asph_lit, line_lit, paint * worn);\n")
rep("\t\tbase = mix(side, surf, in_road);\n", "\t\tbase = mix(side, surf, in_road);\n\t\tlit_base = mix(side, surf_lit, in_road);\n")
rep("\tEMISSION = ce_pools_encode(ce_ground_base_lin(base) + ce_pools_to_lin(base) * extra);",
    "\tvec3 lb = base;\n\tif (lit_base.x >= 0.0) {\n"
    "\t\tlb = clamp(lit_base * (tunnel ? 1.0 : 1.0 + night_lift * clamp(ce_night, 0.0, 1.0)), vec3(0.0), vec3(1.0));\n\t}\n"
    "\tEMISSION = ce_pools_encode(ce_ground_base_lin(base) + ce_pools_to_lin(lb) * extra);")
open(p, "w", encoding="utf-8").write(s)
print("patched", p)
