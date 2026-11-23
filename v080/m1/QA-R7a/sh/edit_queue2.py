S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/sh/"
c = open(S + "common.sh").read()
if "mit_reichweite" not in c:
    c = c.replace('''	[ "$which" = base ] && { wt=$BASE; out=$D/basis; }
''', '''	[ "$which" = base ] && { wt=$BASE; out=$D/basis; }
	[ "$which" = fix ] && { wt=$S/mut; out=$D/mit_reichweite; }
''')
    open(S + "common.sh", "w").write(c)
q = open(S + "queue2.sh").read()
if "3b the look" not in q:
    q = q.replace('''# 4 render checks (gate), modern + arcade''', '''# 3b the look after the merge with the reach test in props.gd (R7c's one line): high, day
for n in T2 S0 Muenchen Hannover Belgrad T4; do
	step "fix_$n" || { shot fix "$n" high; mark "fix_$n"; }
done
# 4 render checks (gate), modern + arcade''')
    open(S + "queue2.sh", "w").write(q)
print("ok")
