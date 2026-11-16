#!/usr/bin/env bash
# M2ZS1: tools/golden.sh modern-make with the pictures kept (KEEP) – to look at them before the list is committed.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2ZS1
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-2 || exit 1
rm -rf "$S/golden_make_keep"
mkdir -p "$S/golden_make_keep"
t0=$(date +%s)
KEEP="$S/golden_make_keep" nice -n 10 tools/golden.sh modern-make > "$S/logs/golden_modern_make.log" 2>&1
code=$?
echo "== modern-make exit=$code secs=$(( $(date +%s) - t0 ))" | tee -a "$S/logs/golden_modern_make.log"
