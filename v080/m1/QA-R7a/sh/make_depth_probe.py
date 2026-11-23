S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/probe/"
s = open(S + "realbuild.gd").read()
s = s.replace('''			r["max_" + cls] = maxf(float(r.get("max_" + cls, 0.0)), w_max - near)
''', '''			r["max_" + cls] = maxf(float(r.get("max_" + cls, 0.0)), w_max - near)
			print("DEPTH %s %.2f %.2f" % [cls, w_max - near, h])
''')
open(S + "realbuild_depth.gd", "w").write(s)
print("ok")
