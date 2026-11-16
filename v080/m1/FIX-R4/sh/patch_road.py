import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, ("pattern", old[:70], s.count(old))
    s = s.replace(old, new)
rep("\tfloat reflect = 1.0;\n\n\tif (kind == 0) {",
    "\tfloat reflect = 1.0;\n"
    "\t// FIX-R4 (QA-R4 B2): what the lamps light – the diffuse part of the surface. The sky mirrored in the water film is\n"
    "\t// part of `base` (it shows under the ambient law as the sky's own colour) but is no matte surface: the low beam and\n"
    "\t// the light pools must not light it (they made the wet road in the cone 1.77 × as bright as Arcade and halved the\n"
    "\t// contrast of the lines there). A real wet road gets darker in the headlights, as in Arcade.\n"
    "\tvec3 lit = vec3(-1.0);\n\n\tif (kind == 0) {")
rep("\t\tasph *= 1.0 - 0.32 * wet;\n",
    "\t\tasph *= 1.0 - 0.32 * wet;\n\t\tvec3 asph_lit = asph;\n\t\tvec3 line_lit = line;\n")
rep("\t\t\tasph = mix(asph, sky_k, mirror);\n\t\t\tline = mix(line * (1.0 - 0.07 * wet), sky_k, mirror * 0.35);\n",
    "\t\t\tasph = mix(asph, sky_k, mirror);\n\t\t\tline = mix(line * (1.0 - 0.07 * wet), sky_k, mirror * 0.35);\n"
    "\t\t\tasph_lit *= 1.0 - mirror;\n\t\t\tline_lit *= (1.0 - 0.07 * wet) * (1.0 - mirror * 0.35);\n")
rep("\t\tasph = mix(asph, col_road_snow, 0.3 * snow);\n",
    "\t\tasph = mix(asph, col_road_snow, 0.3 * snow);\n\t\tasph_lit = mix(asph_lit, col_road_snow, 0.3 * snow);\n")
rep("\t\t\tasph = mix(asph, col_snow * (0.96 + grain * 0.1), band * 0.7 * snow);\n",
    "\t\t\tasph = mix(asph, col_snow * (0.96 + grain * 0.1), band * 0.7 * snow);\n"
    "\t\t\tasph_lit = mix(asph_lit, col_snow * (0.96 + grain * 0.1), band * 0.7 * snow);\n")
rep("\t\tvec3 surf = mix(asph, line, paint * worn);\n",
    "\t\tvec3 surf = mix(asph, line, paint * worn);\n\t\tvec3 surf_lit = mix(asph_lit, line_lit, paint * worn);\n")
rep("\t\t\tsurf = mix(surf, mix(vec3(0.08), vec3(1.0), chk) * (1.0 + grain * 0.05), on);\n",
    "\t\t\tsurf = mix(surf, mix(vec3(0.08), vec3(1.0), chk) * (1.0 + grain * 0.05), on);\n"
    "\t\t\tsurf_lit = mix(surf_lit, mix(vec3(0.08), vec3(1.0), chk) * (1.0 + grain * 0.05), on);\n")
rep("\t\tbase = mix(side, surf, in_road);\n",
    "\t\tbase = mix(side, surf, in_road);\n\t\tlit = mix(side, surf_lit, in_road);\n")
rep("\tif (!tunnel) {\n\t\tbase *= 1.0 + night_lift * clamp(ce_night, 0.0, 1.0);\n\t}\n\tbase = clamp(base, vec3(0.0), vec3(1.0));\n",
    "\tif (lit.x < 0.0) {\n\t\tlit = base;\n\t}\n"
    "\tif (!tunnel) {\n\t\tbase *= 1.0 + night_lift * clamp(ce_night, 0.0, 1.0);\n\t\tlit *= 1.0 + night_lift * clamp(ce_night, 0.0, 1.0);\n\t}\n"
    "\tbase = clamp(base, vec3(0.0), vec3(1.0));\n\tlit = clamp(lit, vec3(0.0), vec3(1.0));\n")
rep("\tEMISSION = ce_pools_encode(ce_ground_base_lin(base) + ce_pools_to_lin(base) * extra);",
    "\tEMISSION = ce_pools_encode(ce_ground_base_lin(base) + ce_pools_to_lin(lit) * extra);")
open(p, "w", encoding="utf-8").write(s)
print("patched", p)
