#!/usr/bin/env bash
# NACH-R6: network scans of QA-R6 (copies kept by FIX-R6: scan_all counts masts) and my start-position probe, headless.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4
cd "$W" || exit 1
export XDG_DATA_HOME=$S/xdg
for g in ${*:-scan_f1 scan_all startdep}; do
	t0=$(date +%s)
	nice -n 10 timeout 3000 godot --headless --path . -s $S/bin/$g.gd > $S/logs/$g.log 2>&1
	echo "$g exit $? $(( $(date +%s) - t0 )) s"
done
