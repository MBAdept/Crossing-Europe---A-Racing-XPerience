"""One-off edit of police3d.py: the glyph outlines as a module function (the truck's side words use them, too)."""
p = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender/ce3d/police3d.py"
s = open(p).read()
a = s.index("    def _glyphs(self, rig, word, size):")
b = s.index("        out.sort(key=lambda e: e[1])\n        return out\n", a) + len("        out.sort(key=lambda e: e[1])\n        return out\n")
method = s[a:b]
# dedent the method body by 4 spaces and turn it into a function
lines = method.split("\n")
func = []
for ln in lines:
    func.append(ln[4:] if ln.startswith("    ") else ln)
func = "\n".join(func)
func = func.replace("def _glyphs(self, rig, word, size):", "def glyph_outlines(rig, word, size, res=None):")
func = func.replace("        cu.resolution_u = WORD_RES", "        cu.resolution_u = WORD_RES if res is None else res")
func = func.replace("    cu.resolution_u = WORD_RES\n", "    cu.resolution_u = WORD_RES if res is None else res\n")
assert "glyph_outlines" in func and "res is None" in func, func[:400]
s = s[:a] + "    def _glyphs(self, rig, word, size):\n        return glyph_outlines(rig, word, size)\n" + s[b:]
anchor = "def _car_len(t):"
s = s.replace(anchor, func + "\n\n" + anchor)
open(p, "w").write(s)
print("ok")
