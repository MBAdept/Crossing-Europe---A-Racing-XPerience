#!/usr/bin/env bash
# QA-R7b: one full run_tests.sh on the package head (nice 10, own XDG_DATA_HOME, memory guard).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-4
mkdir -p $S/xdg_tests $S/gates
while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
cd $W || exit 1
export XDG_DATA_HOME=$S/xdg_tests
START=$(date +%s)
nice -n 10 tools/run_tests.sh "$@" > $S/gates/run_tests${1:+_$1}.log 2>&1
echo "rc=$? sec=$(( $(date +%s) - START ))" >> $S/gates/run_tests${1:+_$1}.log
echo RUN_TESTS_DONE
