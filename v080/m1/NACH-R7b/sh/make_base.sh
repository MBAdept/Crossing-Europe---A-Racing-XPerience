#!/usr/bin/env bash
# NACH-R7b: a copy of 2c154bc (R7b head, the base of FIX-R7b) for the "before" pictures – no worktree, no branch.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-9
B=$S/base
rm -rf "$B"
mkdir -p "$B"
git -C "$W" archive 2c154bc | tar -x -C "$B"
cp -a "$W/.godot" "$B/"
cd "$B" && nice -n 10 timeout 900 godot --headless --path . --import . > "$S/import_base.log" 2>&1
echo "import rc=$?"
