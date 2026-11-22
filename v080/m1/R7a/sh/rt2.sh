#!/bin/bash
# R7a: second (last) full tools/run_tests.sh on the final head.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
mkdir -p "$S/xdg/rt2" "$S/tmp"
cd "$WT" || exit 2
echo "head $(git -C "$WT" rev-parse --short HEAD) $(date -u +%H:%M:%S)"
XDG_DATA_HOME=$S/xdg/rt2 TMPDIR=$S/tmp nice -n 10 tools/run_tests.sh
echo "exit=$? $(date -u +%H:%M:%S)"
