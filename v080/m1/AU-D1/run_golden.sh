#!/usr/bin/env bash
# AU-D1: the one run of tools/golden.sh check (nice 19, one job)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-D1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_158edd89-079-1
cd "$WT" || exit 1
export JOBS=1 OMP_NUM_THREADS=1
SECONDS=0
nice -n 19 tools/golden.sh check > "$S/golden_check.log" 2>&1
code=$?
echo "exit $code after $SECONDS s" >> "$S/golden_check.log"
