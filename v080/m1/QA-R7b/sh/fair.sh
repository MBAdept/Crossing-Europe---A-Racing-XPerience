#!/usr/bin/env bash
# QA-R7b: fairness F1-F3/F7 and the path check, --full, on the package head (headless, nice 10).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-4
G=$S/gates
mkdir -p $G $S/xdg_fair
cd $W || exit 1
for t in modern_sight modern_path_check; do
	f=$G/${t}_full.log
	[ -s $f ] && grep -q '^rc=0' $f && continue
	while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
	T0=$SECONDS
	XDG_DATA_HOME=$S/xdg_fair nice -n 10 timeout 5400 godot --headless --path . -s res://tests/sim/$t.gd -- --full > $f 2>&1
	echo "rc=$? sec=$((SECONDS - T0))" >> $f
done
echo FAIR_DONE
