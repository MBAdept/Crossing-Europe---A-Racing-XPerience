#!/usr/bin/env bash
# worst case with groups muted: which group drives the master into the limiter
set -u
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-C1
cd "$WT"
run() {
	name=$1; shift
	XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 300 godot --headless --path . -s "$S/worst_case.gd" -- --out="$S/cap/worst_$name.wav" "$@" 2>&1 \
		| grep -E "vor dem Begrenzer" | sed "s/^/$name: /" | cut -c1-200
	python3 "$S/peaks.py" "$S/cap/worst_$name.wav" | head -2 | sed "s/^/$name: /"
}
run ohne_verkehr --mute-bus=MWorld
run ohne_auc1 --mute-bus=MImpact,MRoad,MWind
run ohne_musik --no-music
run nur_auc1 --mute-bus=MWorld,MEngine,MEngineFx,MMusic --no-music
echo "== fertig"
