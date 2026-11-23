#!/bin/bash
# NACH-R7a: do the guards catch a broken push-out line? Mutations of the patched props.gd in m3, one at a time.
#  M1 drop_reason tests only the foot (reach/half_len ignored)  -> props_footprint must fail
#  M2 push_out disabled (returns x)                               -> test_props (oracle) must fail
#  M3 push_out without the margin, half the depth                 -> test_props must fail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7a
M=$S/m3
F=$M/scripts/race3d/builders/props.gd
cp $F $S/props_m3_patched_mut_backup.gd
cd $M || exit 1
run() {
	local tag=$1
	XDG_DATA_HOME=$S/xdg/ut nice -n 10 timeout 900 tools/run_tests.sh test_props > $S/logs/mut_${tag}_test_props.log 2>&1
	local a=$?
	XDG_DATA_HOME=$S/xdg/fp nice -n 10 timeout 900 godot --headless --path . -s res://tests/race3d/props_footprint.gd > $S/logs/mut_${tag}_fp.log 2>&1
	local b=$?
	echo "$tag test_props exit=$a ($(grep -E '[0-9]+ Tests, [0-9]+ fehlgeschlagen' $S/logs/mut_${tag}_test_props.log | tail -1)) footprint exit=$b ($(grep 'CHECK props_footprint' $S/logs/mut_${tag}_fp.log))"
}
python3 - "$F" M1 <<'PY'
import sys
p, m = sys.argv[1], sys.argv[2]
s = open(p).read()
old = 'ctx.in_sight_envelope(z, x, reach, half_len) \\'
assert s.count(old) == 1
s = s.replace(old, 'ctx.in_sight_envelope(z, x) \\')
open(p, "w").write(s)
PY
run M1
cp $S/props_m3_patched_mut_backup.gd $F
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '\treturn x + float(side) * (depth + PUSH_MARGIN_M)\n'
assert s.count(old) == 1
s = s.replace(old, '\treturn x\n')
open(p, "w").write(s)
PY
run M2
cp $S/props_m3_patched_mut_backup.gd $F
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '\treturn x + float(side) * (depth + PUSH_MARGIN_M)\n'
assert s.count(old) == 1
s = s.replace(old, '\treturn x + float(side) * depth * 0.5\n')
open(p, "w").write(s)
PY
run M3
cp $S/props_m3_patched_mut_backup.gd $F
cmp $F $S/props_m3_patched.gd && echo "restored patched props.gd"
