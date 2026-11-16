#!/usr/bin/env bash
# golden.sh – tools/golden.sh check in the worktree with an own absolute XDG_DATA_HOME
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-2
R2=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R2
export XDG_DATA_HOME=$R2/xdg_golden
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME"
cd "$WT" || exit 1
SECONDS=0
nice -n 10 tools/golden.sh check > "$R2/golden.log" 2>&1
code=$?
echo "exit $code after $SECONDS s" >> "$R2/golden.log"
tail -6 "$R2/golden.log"
