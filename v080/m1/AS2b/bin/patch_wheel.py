"""One-off edit of truck3d._wheel: radius / tyre width as parameters (the bus has 0.5 m wheels); the truck's calls
give the same numbers as before."""
p = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender/ce3d/truck3d.py"
s = open(p).read()
start = s.index("def _wheel(b, kind, loc, left=False):")
end = s.index("def _arch_block(")
body = s[start:end]
new = body.replace("def _wheel(b, kind, loc, left=False):",
                   "def _wheel(b, kind, loc, left=False, radius=None, tw=None):")
new = new.replace('''    (twin: of the pair)."""''', '''    (twin: of the pair). radius / tw: other wheels than the truck's (the bus: 0.5 m) - the rim scales with the
    radius."""''')
new = new.replace('''    tw = {"front": TW_FRONT, "drive": TW_DRIVE, "trailer": TW_TRAILER}[kind]''',
                  '''    R = RADIUS if radius is None else radius            # noqa: N806 (the module's R for the truck)
    if tw is None:
        tw = {"front": TW_FRONT, "drive": TW_DRIVE, "trailer": TW_TRAILER}[kind]''')
new = new.replace("    r_rim = 0.292\n", "    r_rim = 0.292 * R / RADIUS\n")
assert new != body
s = s[:start] + new + s[end:]
s = s.replace("R = 0.53                            # all wheels\n",
              "R = 0.53                            # all wheels\nRADIUS = R\n")
open(p, "w").write(s)
print("ok")
