#!/usr/bin/env bash
# run_tests_bg.sh <n> [filter]: tools/run_tests.sh, log into gates/run_tests_<n>.log, exit code appended
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA1
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5 || exit 2
N=${1:-1}
shift
mkdir -p "$S/gates"
rm -rf "$S/xdg_tests_$N"
mkdir -p "$S/xdg_tests_$N"
echo "head=$(git rev-parse --short HEAD) dirty=$(git status --porcelain | wc -l) start=$(date -Is) args=$*" > "$S/gates/run_tests_$N.log"
T0=$SECONDS
XDG_DATA_HOME="$S/xdg_tests_$N" nice -n 10 tools/run_tests.sh "$@" >> "$S/gates/run_tests_$N.log" 2>&1
CODE=$?
echo "exit=$CODE dauer=$((SECONDS - T0))s ende=$(date -Is)" >> "$S/gates/run_tests_$N.log"
rm -rf "$S/xdg_tests_$N"
