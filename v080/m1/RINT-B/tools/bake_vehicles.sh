#!/bin/bash
# Bake the six vehicle models (headless Godot) into assets/models; log into scratch. Arg 1: log suffix
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
SUF=${1:-1}
cd "$WT" || exit 1
export XDG_DATA_HOME=$S/xdg_bake
mkdir -p "$XDG_DATA_HOME"
for g in 'player/*' 'traffic/*'; do
	nice -n 10 timeout 900 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" >> "$S/bake_$SUF.log" 2>&1
	echo "bake $g exit=$?"
done
grep -E "ERROR|SCRIPT ERROR|FEHLER" "$S/bake_$SUF.log" | head
