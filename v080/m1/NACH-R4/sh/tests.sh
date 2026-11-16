#!/bin/bash
# tests.sh – tools/run_tests.sh (full) once in the head worktree with an absolute XDG_DATA_HOME
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7
mkdir -p $S/xdg/tests
cd "$WT" || exit 2
XDG_DATA_HOME=$S/xdg/tests nice -n 10 tools/run_tests.sh > $S/gates/tests.log 2>&1
r=$?
tail -25 $S/gates/tests.log
exit $r
