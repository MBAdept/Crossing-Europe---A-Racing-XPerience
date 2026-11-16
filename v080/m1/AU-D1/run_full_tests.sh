#!/usr/bin/env bash
# AU-D1: the one full run of tools/run_tests.sh (nice 19, user:// under scratch)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-D1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_158edd89-079-1
cd "$WT" || exit 1
rm -rf "$S/xdg_tests"
mkdir -p "$S/xdg_tests"
export XDG_DATA_HOME="$S/xdg_tests" OMP_NUM_THREADS=1
SECONDS=0
nice -n 19 tools/run_tests.sh > "$S/run_tests_full.log" 2>&1
code=$?
echo "exit $code after $SECONDS s" >> "$S/run_tests_full.log"
