#!/usr/bin/env python3
"""QA-R7a: the one-line change R7a proposes for builders/props.gd (R7c's file), applied ONLY to the scratch copy
m1/QA-R7a/mut: drop_reason() tests the footprint (reach = near edge / crown radius, half_len = half width)."""
p = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/mut/scripts/race3d/builders/props.gd"
s = open(p).read()
old = """	if (decorative or bool(e["veg"])) and not bool(it.get("landmark", false)) and ctx.in_bend_corridor(z, x) \\
			and not cover.has(str(e["set"])):
		return "corridor"
"""
new = """	var fw := float(e["width"]) * float(it.get("scale", 1.0)) * 0.5
	var reach := (absf(x) - absf(float(it.get("x", x)))) if it.has("align") else fw
	if (decorative or bool(e["veg"])) and not bool(it.get("landmark", false)) and ctx.in_bend_corridor(z, x, reach, fw) \\
			and not cover.has(str(e["set"])):
		return "corridor"
"""
assert s.count(old) == 1, s.count(old)
open(p, "w").write(s.replace(old, new))
print("patched")
