#!/bin/bash
# NACH-R7a: network runs in the scratch tree m3 (HEAD + FIX-RINT + FIX-R7c eb97a98 + patch B), then unpatched
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7a
M=$S/m3
export XDG_DATA_HOME=$S/xdg/fp
cd "$M" || exit 1
memwait() { while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done; }
memwait
nice -n 10 timeout 1500 godot --headless --path . -s res://tests/race3d/props_footprint.gd -- --full > $S/logs/fp_m3B_full.log 2>&1
echo "fp_m3B_full exit=$?"
memwait
nice -n 10 timeout 1500 godot --headless --path . -s res://nach_probe/fp_true.gd -- --full --verbose > $S/logs/fptrue_m3B_full.log 2>&1
echo "fptrue_m3B_full exit=$?"
# unpatched props.gd (FIX-R7c as is) for the comparison
cp scripts/race3d/builders/props.gd $S/props_m3_patched.gd
cp $S/props_m3_unpatched.gd scripts/race3d/builders/props.gd
memwait
nice -n 10 timeout 1500 godot --headless --path . -s res://nach_probe/fp_true.gd -- --full --verbose > $S/logs/fptrue_m3U_full.log 2>&1
echo "fptrue_m3U_full exit=$?"
cp $S/props_m3_patched.gd scripts/race3d/builders/props.gd
echo restored
