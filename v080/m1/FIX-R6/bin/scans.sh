#!/bin/bash
# Network scans after B-01/B-02: QA-R6's scan_all (masts, one-sided roofs, element counts) and scan_f1 (pillars vs signs).
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-3
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6
cd "$W" || exit 1
t0=$(date +%s)
XDG_DATA_HOME=$S/xdg nice -n 10 godot --headless --path . -s $S/bin/scan_f1.gd > $S/logs/scan_f1.log 2>&1
echo "scan_f1 exit $? $(( $(date +%s) - t0 )) s"
t0=$(date +%s)
XDG_DATA_HOME=$S/xdg nice -n 10 godot --headless --path . -s $S/bin/scan_all.gd > $S/logs/scan_all.log 2>&1
echo "scan_all exit $? $(( $(date +%s) - t0 )) s"
