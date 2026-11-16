#!/usr/bin/env bash
# FIX-ZS1: tools/golden.sh modern-make with kept pictures, then the old and the new MD5 list side by side
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
export XDG_DATA_HOME=$S/xdg_golden
mkdir -p "$XDG_DATA_HOME"
rm -rf "$S/golden_make_keep"
t0=$SECONDS
KEEP=$S/golden_make_keep nice -n 5 tools/golden.sh modern-make
echo "exit $? ($((SECONDS - t0)) s)"
echo "--- alt"
cat "$S/modern_slice_old.md5"
echo "--- neu"
cat tests/golden/modern_slice.md5
echo "--- Unterschiede"
diff "$S/modern_slice_old.md5" tests/golden/modern_slice.md5
