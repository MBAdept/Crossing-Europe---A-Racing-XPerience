#!/bin/bash
# mkcopy.sh <rev> <dir>: git archive of rev + .godot cache, then headless import
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-7
REV=$1
DIR=$2
mkdir -p "$DIR" "$S/xdg"
cd "$WT" || exit 1
git archive "$REV" | tar -x -C "$DIR"
cp -a "$WT/.godot" "$DIR/"
cd "$DIR" || exit 1
XDG_DATA_HOME=$S/xdg nice -n 10 timeout 1500 godot --headless --path . --import . > "$DIR.import.log" 2>&1
echo "import exit $?"
grep -ciE "error|fehler" "$DIR.import.log"
