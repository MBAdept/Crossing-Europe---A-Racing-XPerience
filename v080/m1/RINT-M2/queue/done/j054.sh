f=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/snap_D/scripts/race3d/modern_materials.gd
cp $f $f.orig
python3 - $f <<'PY'
import sys
p=sys.argv[1]; t=open(p).read()
old='''	if cls == "vpbr" and not model.is_empty() and not (str(model.get("kind", "")) in ["vehicle", "heavy"]):
		return VPBR_STATIC'''
assert t.count(old)==1
t=t.replace(old,'''	if false:
		return VPBR_STATIC''')
open(p,'w').write(t)
print("mutation: no VPBR_STATIC")
PY
TO=2700 /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/sh/rc_snap.sh D n6_wald_mut check_instance_budget_wald
cp $f.orig $f
