#!/bin/bash
# AU-R2: a read-only copy of AU-C1's head (4209268) as the "before" tree for the reviewer's capture scripts.
set -e
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-3
MAIN=/home/user/crossing-europe---a-racing-xperience
mkdir -p "$S/before" "$S/xdg" "$S/logs"
cd "$WT"
if [ ! -f "$S/before/project.godot" ]; then
	git archive 4209268f0bad80beb9abc2609d92a74cd7279db1 | tar -x -C "$S/before"
	echo "before exported"
fi
if [ ! -d "$S/before/.godot" ]; then
	cp -a "$MAIN/.godot" "$S/before/.godot"
	echo "before .godot copied"
fi
export XDG_DATA_HOME="$S/xdg"
t0=$(date +%s)
nice -n 19 timeout 1800 godot --headless --path "$S/before" --import > "$S/logs/import_before.log" 2>&1
echo "before import exit $? in $(( $(date +%s) - t0 )) s"
du -sh "$S/before"
