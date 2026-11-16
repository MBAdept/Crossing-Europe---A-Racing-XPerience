p = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/scripts/race3d/builders/station.gd"
t = open(p, encoding="utf-8").read()


def sub(old, new, c=1):
    global t
    assert t.count(old) == c, (old[:70], t.count(old))
    t = t.replace(old, new)


# move mast_right/mast_left into the job class (an inner class cannot call the outer script's static functions)
a = t.index("## The candidate places of a mast right of the road at zc")
b = t.index("## Main thread: everything the decision of the canopy from r0 to r1 reads")
helpers = t[a:b]
t = t[:a] + t[b:]
helpers = helpers.replace("static func mast_right(", "	static func mast_right(").replace("static func mast_left(", "	static func mast_left(")
lines = []
for ln in helpers.rstrip("\n").split("\n"):
    if ln.startswith("	static func"):
        lines.append(ln)
    elif ln.startswith("##"):
        lines.append("	" + ln)
    elif ln == "":
        lines.append("")
    else:
        lines.append("	" + ln)
helpers = "\n".join(lines).replace("outer_place(", "outer(")
extra = '''
	## outer_place() of the builder (an inner class cannot call the outer script's static functions).
	static func outer(sgns: Array, z0: float, z1: float) -> float:
		var far := PILLAR_X
		for s: Array in sgns:
			if float(s[0]) >= z0 and float(s[0]) <= z1:
				far = maxf(far, float(s[1]) + OUT_GAP + PILLAR_W * 0.5)
		return far

	## _sine() of the builder.
	static func sine(v: Vector2, w: Vector2, lv: float, lw: float) -> float:
		var s := v.cross(w) / maxf(lv * lw, 1.0e-9)
		if v.dot(w) < 0.0:
			return 2.0 if s >= 0.0 else -2.0
		return s

'''
anchor = "	## The decision of canopy_columns() (WORKER THREAD or inline)."
sub(anchor, helpers.rstrip() + "\n" + extra + "\n" + anchor)
# inside the class: use the class's own helpers
cls_a = t.index("class CanopyJob extends RefCounted:")
cls_b = t.index("## Main thread: everything the decision of the canopy from r0 to r1 reads")
body = t[cls_a:cls_b]
body = body.replace("_sine(to_col", "sine(to_col").replace("outer_place(signs", "outer(signs")
t = t[:cls_a] + body + t[cls_b:]
# the outer gather uses the class's helpers
sub("		places.append_array(mast_right(z, e, job.signs, r0, r1))\n		places.append_array(mast_left(left))",
    "		places.append_array(CanopyJob.mast_right(z, e, job.signs, r0, r1))\n		places.append_array(CanopyJob.mast_left(left))")
open(p, "w", encoding="utf-8").write(t)
print("ok")
