#!/bin/bash
# KRITIK-R: make the two working copies (after = AU-R head, before = AU-C1 head 4209268) – read-only on the sources.
set -e
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
MAIN=/home/user/crossing-europe---a-racing-xperience
WT=$MAIN/.claude/worktrees/wf_5dca29a9-6fb-1
mkdir -p "$K/after" "$K/before"
if [ ! -f "$K/after/project.godot" ]; then
	tar -C "$WT" --exclude=./.godot --exclude=./build --exclude=./.git -cf - . | tar -C "$K/after" -xf -
	echo "after copied"
fi
if [ ! -f "$K/before/project.godot" ]; then
	git -C "$MAIN" archive 4209268f0bad80beb9abc2609d92a74cd7279db1 | tar -x -C "$K/before"
	echo "before exported"
fi
for d in after before; do
	if [ ! -d "$K/$d/.godot" ]; then
		cp -a "$MAIN/.godot" "$K/$d/.godot"
		echo "$d .godot copied"
	fi
done
du -sh "$K/after" "$K/before"
