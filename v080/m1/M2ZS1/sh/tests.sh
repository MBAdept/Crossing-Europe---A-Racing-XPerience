#!/usr/bin/env bash
# usage: tests.sh <logname> [filter]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2ZS1
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-2
name=$1; shift
mkdir -p "$S/data/tests_$name" "$S/logs"
cd "$W" || exit 1
start=$(date +%s)
XDG_DATA_HOME="$S/data/tests_$name" nice -n 10 tools/run_tests.sh "$@" > "$S/logs/tests_$name.log" 2>&1
code=$?
echo "exit=$code secs=$(( $(date +%s) - start ))" >> "$S/logs/tests_$name.log"
rm -rf "$S/data/tests_$name"
tail -5 "$S/logs/tests_$name.log"
